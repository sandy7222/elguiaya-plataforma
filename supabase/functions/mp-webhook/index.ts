// supabase/functions/mp-webhook/index.ts
// Webhook MercadoPago → confirma pedidos vía RPC idempotente.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { crypto } from "https://deno.land/std@0.168.0/crypto/mod.ts";
import { claveWebhook, configMp, modoSandbox } from "../_shared/mp_config.ts";

const MP_API = "https://api.mercadopago.com";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const bodyText = await req.text();

  // La clave de firma depende del modo (prueba/produccion) que fija el panel de administracion.
  const MP_WEBHOOK_SECRET = claveWebhook(await modoSandbox(supabase));
  if (!MP_WEBHOOK_SECRET) {
    console.error("[MP-WEBHOOK] clave de firma no configurada para el modo actual; se rechaza el evento.");
    return new Response("Webhook no configurado", { status: 503 });
  }
  {
    const xSignature = req.headers.get("x-signature") ?? "";
    const xRequestId = req.headers.get("x-request-id") ?? "";
    const parts = Object.fromEntries(
      xSignature.split(",").map((p) => p.split("=") as [string, string]),
    );
    const ts = parts["ts"] ?? "";
    const timestamp = Number(ts);
    if (!Number.isFinite(timestamp) || Math.abs(Date.now() / 1000 - timestamp) > 300) {
      return new Response("Firma vencida", { status: 401 });
    }
    const v1 = parts["v1"] ?? "";

    // Mercado Pago firma con el data.id de la URL (en minusculas); el del cuerpo es el respaldo.
    let dataId = new URL(req.url).searchParams.get("data.id") ?? "";
    if (!dataId) {
      try {
        const bodyJson = JSON.parse(bodyText);
        dataId = bodyJson?.data?.id?.toString() ?? "";
      } catch (_) {
        /* ignore */
      }
    }
    dataId = dataId.toLowerCase();

    const manifest = `id:${dataId};request-id:${xRequestId};ts:${ts};`;
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(MP_WEBHOOK_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const sigBuffer = await crypto.subtle.sign(
      "HMAC",
      key,
      new TextEncoder().encode(manifest),
    );
    const sigHex = Array.from(new Uint8Array(sigBuffer))
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    if (!iguales(sigHex, v1)) {
      console.warn("[MP-WEBHOOK] Firma inválida");
      return new Response("Unauthorized", { status: 401 });
    }
  }

  let payload: Record<string, unknown>;
  try {
    payload = JSON.parse(bodyText);
  } catch (_) {
    return new Response("Bad Request", { status: 400 });
  }

  const action = payload.action as string | undefined;
  const dataId = (payload.data as Record<string, unknown>)?.id?.toString();

  if (!action?.startsWith("payment.") || !dataId) {
    return new Response(JSON.stringify({ skipped: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  let pagoMP: Record<string, unknown>;
  try {
    const { accessToken: token } = await configMp(supabase);
    const mpRes = await fetch(`${MP_API}/v1/payments/${dataId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!mpRes.ok) throw new Error(`MP API ${mpRes.status}`);
    pagoMP = await mpRes.json();
  } catch (err) {
    console.error("[MP-WEBHOOK] Error consultando MP:", err);
    await logWebhook(dataId, null, "error_mp_api", bodyText, String(err));
    return new Response("Error consultando MP", { status: 502 });
  }

  const status = pagoMP.status as string;
  const externalRef = pagoMP.external_reference as string | undefined;
  const preferenceId = pagoMP.preference_id?.toString();

  if (!externalRef) {
    await logWebhook(dataId, null, "sin_external_ref", bodyText, null);
    return new Response(JSON.stringify({ skipped: "no_external_ref" }), { status: 200 });
  }

  // external_reference = UUID de pedidos (flujo actual)
  if (!UUID.test(externalRef)) {
    await logWebhook(dataId, null, "external_ref_invalida", bodyText, null);
    return new Response(JSON.stringify({ skipped: "external_ref_invalida" }), { status: 200 });
  }
  const pedidoId = externalRef;

  const { data: rpcResult, error: rpcError } = await supabase.rpc(
    "confirmar_pago_pedido_mp",
    {
      p_pedido_id: pedidoId,
      p_mp_payment_id: dataId,
      p_status: status,
      p_status_detail: pagoMP.status_detail?.toString() ?? null,
      p_transaction_amount: (pagoMP.transaction_amount as number) ?? null,
      p_payment_method_id: pagoMP.payment_method_id?.toString() ?? "mercado_pago",
      p_preference_id: preferenceId ?? null,
      p_date_approved: pagoMP.date_approved?.toString() ?? null,
      p_raw: pagoMP,
    },
  );

  if (rpcError) {
    console.error("[MP-WEBHOOK] RPC error:", rpcError);
    await logWebhook(dataId, pedidoId, "rpc_error", bodyText, rpcError.message);
    return new Response("Error RPC", { status: 500 });
  }

  const result = rpcResult as Record<string, unknown>;
  console.log(`[MP-WEBHOOK] Pedido ${pedidoId} → ${JSON.stringify(result)}`);

  // Legacy: intentar actualizar reservas si el ID es numérico
  const reservaIdInt = parseInt(pedidoId, 10);
  if (!isNaN(reservaIdInt)) {
    try {
      const estadoReserva = status === "approved"
        ? "Confirmada"
        : status === "pending" || status === "in_process"
        ? "Pendiente"
        : "Cancelada";
      await supabase.from("reservas").update({
        estado: estadoReserva,
        payment_id: dataId,
        payment_status: status,
        actualizado_at: new Date().toISOString(),
      }).eq("id", reservaIdInt);
    } catch (_) {
      /* tabla legacy opcional */
    }
  }

  await logWebhook(dataId, pedidoId, result.ok ? "ok" : "rpc_fail", bodyText, JSON.stringify(result));

  return new Response(JSON.stringify({ ok: true, result }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

/** Comparacion en tiempo constante (evita filtrar la firma por diferencias de tiempo). */
function iguales(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

async function logWebhook(
  paymentId: string,
  pedidoId: string | null,
  status: string,
  body: string,
  error: string | null,
) {
  try {
    await supabase.from("webhook_logs").insert({
      webhook_type: "mercadopago",
      payment_id: paymentId,
      pedido_id: pedidoId,
      reserva_id: pedidoId,
      status,
      request_body: JSON.parse(body),
      error_message: error,
    });
  } catch (e) {
    console.warn("[MP-WEBHOOK] log error:", e);
  }
}
