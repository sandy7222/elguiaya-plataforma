// supabase/functions/mp-webhook/index.ts
// Edge Function Deno — Webhook de MercadoPago para CapitanYA
// Desplegá con: supabase functions deploy mp-webhook
//
// Variables de entorno requeridas (configurar en Supabase Dashboard > Edge Functions > Secrets):
//   MP_ACCESS_TOKEN   — Access Token de tu cuenta de MercadoPago
//   MP_WEBHOOK_SECRET — Clave secreta para validar firma HMAC (la configurás en el panel de MP)
//   FCM_SERVER_KEY    — Server Key de Firebase Cloud Messaging (para push notifications)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";

// ─── Constantes ───────────────────────────────────────────────────────────────
const MP_API = "https://api.mercadopago.com";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const MP_ACCESS_TOKEN = Deno.env.get("MP_ACCESS_TOKEN") ?? "";
const MP_WEBHOOK_SECRET = Deno.env.get("MP_WEBHOOK_SECRET") ?? "";
const FCM_SERVER_KEY = Deno.env.get("FCM_SERVER_KEY") ?? "";

// ─── Cliente Supabase con Service Role (bypass RLS) ──────────────────────────
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

// ─── Servidor principal ───────────────────────────────────────────────────────
serve(async (req: Request) => {
  // Solo POST
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const bodyText = await req.text();

  // ── 1. Validar firma HMAC-SHA256 de MercadoPago ────────────────────────────
  // MP envía: x-signature: ts=<timestamp>,v1=<hmac>
  if (MP_WEBHOOK_SECRET) {
    const xSignature = req.headers.get("x-signature") ?? "";
    const xRequestId = req.headers.get("x-request-id") ?? "";

    // Extraer ts y v1 del header
    const parts = Object.fromEntries(
      xSignature.split(",").map((p) => p.split("=") as [string, string])
    );
    const ts = parts["ts"] ?? "";
    const v1 = parts["v1"] ?? "";

    // Construir el manifest que firma MP: id=<id>;request-id=<rid>;ts=<ts>;
    let dataId = "";
    try {
      const bodyJson = JSON.parse(bodyText);
      dataId = bodyJson?.data?.id?.toString() ?? "";
    } catch (_) {}

    const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`;

    // Verificar HMAC-SHA256
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(MP_WEBHOOK_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"]
    );
    const sigBuffer = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(manifest)
    );
    const sigHex = Array.from(new Uint8Array(sigBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (sigHex !== v1) {
      console.warn("[MP-WEBHOOK] ❌ Firma inválida — posible request no autorizado");
      return new Response("Unauthorized", { status: 401 });
    }
  }

  // ── 2. Parsear el body ─────────────────────────────────────────────────────
  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(bodyText);
  } catch (_) {
    return new Response("Bad Request: invalid JSON", { status: 400 });
  }

  const action = payload.action as string | undefined;
  const dataId = (payload.data as Record<string, unknown>)?.id?.toString();

  console.log(`[MP-WEBHOOK] Evento recibido: action=${action}, id=${dataId}`);

  // Solo procesamos eventos de pagos
  if (!action?.startsWith("payment.") || !dataId) {
    // Devolver 200 igual para que MP no reintente
    return new Response(JSON.stringify({ skipped: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ── 3. Consultar detalle del pago en la API de MP ──────────────────────────
  let pagoMP: Record<string, unknown>;
  try {
    const mpRes = await fetch(`${MP_API}/v1/payments/${dataId}`, {
      headers: { Authorization: `Bearer ${MP_ACCESS_TOKEN}` },
    });
    if (!mpRes.ok) throw new Error(`MP API error: ${mpRes.status}`);
    pagoMP = await mpRes.json();
  } catch (err) {
    console.error("[MP-WEBHOOK] Error consultando pago en MP:", err);
    return new Response("Error consultando MP", { status: 502 });
  }

  const status = pagoMP.status as string;
  const externalRef = pagoMP.external_reference as string | undefined;
  const monto = pagoMP.transaction_amount as number;
  const metodoPago = pagoMP.payment_method_id as string;
  const emailPagador = (pagoMP.payer as Record<string, unknown>)?.email as string;
  const fechaAprobacion = pagoMP.date_approved as string | null;

  console.log(`[MP-WEBHOOK] Pago ${dataId}: status=${status}, ref=${externalRef}`);

  if (!externalRef) {
    console.warn("[MP-WEBHOOK] Sin external_reference — no se puede vincular reserva");
    return new Response(JSON.stringify({ skipped: "no_external_ref" }), { status: 200 });
  }

  // ── 4. Mapear estado de MP a estado de reserva ─────────────────────────────
  const estadoReserva = (() => {
    switch (status) {
      case "approved":     return "Confirmada";
      case "pending":
      case "in_process":
      case "authorized":   return "Pendiente";
      case "rejected":
      case "cancelled":    return "Cancelada";
      case "refunded":
      case "charged_back": return "Reembolsada";
      default:             return "Pendiente";
    }
  })();

  // ── 5. Actualizar reserva en Supabase ──────────────────────────────────────
  const { data: reserva, error: errBuscar } = await supabase
    .from("reservas")
    .select("id, capitan_id, pescador_id, estado, monto")
    .eq("id", externalRef)
    .maybeSingle();

  if (errBuscar || !reserva) {
    console.warn(`[MP-WEBHOOK] Reserva no encontrada para ref=${externalRef}`);
    // Loguear pero no fallar — MP no debe reintentar por reservas inexistentes
    await _logWebhook(dataId, externalRef, status, "reserva_no_encontrada", bodyText);
    return new Response(JSON.stringify({ ok: true, note: "reserva_no_encontrada" }), { status: 200 });
  }

  // Evitar actualizar si ya estaba en ese estado (idempotencia)
  if (reserva.estado === estadoReserva) {
    return new Response(JSON.stringify({ ok: true, note: "sin_cambios" }), { status: 200 });
  }

  const { error: errUpdate } = await supabase
    .from("reservas")
    .update({
      estado: estadoReserva,
      payment_id: dataId,
      payment_status: status,
      payment_method_id: metodoPago,
      payment_amount: monto,
      payment_date: new Date().toISOString(),
      email_pagador: emailPagador,
      fecha_pago_aprobado: fechaAprobacion,
      actualizado_at: new Date().toISOString(),
    })
    .eq("id", externalRef);

  if (errUpdate) {
    console.error("[MP-WEBHOOK] Error actualizando reserva:", errUpdate);
    return new Response("Error actualizando reserva", { status: 500 });
  }

  console.log(`[MP-WEBHOOK] ✅ Reserva ${externalRef} → ${estadoReserva}`);

  // ── 6. Push notification al Capitán si el pago fue aprobado ───────────────
  if (status === "approved" && FCM_SERVER_KEY) {
    try {
      await _enviarPushCapitan(reserva.capitan_id, externalRef, monto);
      await _enviarPushPescador(reserva.pescador_id, externalRef, estadoReserva);
    } catch (errPush) {
      console.warn("[MP-WEBHOOK] Error enviando push (no crítico):", errPush);
    }
  }

  // ── 7. Log de auditoría ────────────────────────────────────────────────────
  await _logWebhook(dataId, externalRef, status, "ok", bodyText);

  return new Response(
    JSON.stringify({ ok: true, reserva: externalRef, estado: estadoReserva }),
    { status: 200, headers: { "Content-Type": "application/json" } }
  );
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

async function _logWebhook(
  paymentId: string,
  reservaId: string | undefined,
  status: string,
  result: string,
  body: string
) {
  try {
    await supabase.from("webhook_logs").insert({
      webhook_type: "mercadopago",
      payment_id: paymentId,
      reserva_id: reservaId,
      payment_status: status,
      result,
      request_body: body,
      created_at: new Date().toISOString(),
    });
  } catch (_) {
    // Log no crítico
  }
}

async function _enviarPushCapitan(
  capitanId: string,
  reservaId: string,
  monto: number
) {
  // Obtener FCM token del capitán desde Supabase
  const { data: perfil } = await supabase
    .from("profiles")
    .select("fcm_token, nombre")
    .eq("id", capitanId)
    .maybeSingle();

  if (!perfil?.fcm_token) return;

  await _enviarFCM(
    perfil.fcm_token,
    "💰 ¡Pago recibido!",
    `Tu reserva fue pagada. Monto: $${monto.toLocaleString("es-AR")}`,
    { tipo: "pago_aprobado", reserva_id: reservaId }
  );
}

async function _enviarPushPescador(
  pescadorId: string,
  reservaId: string,
  estado: string
) {
  const { data: perfil } = await supabase
    .from("profiles")
    .select("fcm_token")
    .eq("id", pescadorId)
    .maybeSingle();

  if (!perfil?.fcm_token) return;

  const titulo = estado === "Confirmada"
    ? "✅ ¡Reserva confirmada!"
    : estado === "Cancelada"
    ? "❌ Pago rechazado"
    : "⏳ Pago en proceso";

  const cuerpo = estado === "Confirmada"
    ? "Tu pago fue aprobado. ¡A preparar los aparejos!"
    : estado === "Cancelada"
    ? "El pago no pudo procesarse. Intentá con otro método."
    : "Estamos procesando tu pago, te avisaremos pronto.";

  await _enviarFCM(perfil.fcm_token, titulo, cuerpo, {
    tipo: "estado_pago",
    reserva_id: reservaId,
    estado,
  });
}

async function _enviarFCM(
  token: string,
  titulo: string,
  cuerpo: string,
  data: Record<string, string>
) {
  await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `key=${FCM_SERVER_KEY}`,
    },
    body: JSON.stringify({
      to: token,
      notification: { title: titulo, body: cuerpo, sound: "default" },
      data,
      priority: "high",
    }),
  });
}
