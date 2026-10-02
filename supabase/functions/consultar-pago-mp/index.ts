// Edge Function: consultar el estado de un pago de Mercado Pago sin exponer el token al cliente.
//
// SEGURIDAD: solo se puede consultar un pago que pertenezca a un pedido propio (o ser admin).
// Antes cualquier usuario con la clave publica podia consultar cualquier pago o referencia.
// Ademas se devuelve solo lo necesario (no el JSON completo de Mercado Pago, que incluye datos
// personales del pagador).

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import {
  clienteServicio,
  corsHeaders,
  esAdmin,
  esParticipante,
  esUuid,
  json,
  usuarioDeLaSesion,
} from "../_shared/auth.ts";
import { configMp } from "../_shared/mp_config.ts";

const MP_API = "https://api.mercadopago.com";

const supabase = clienteServicio();

/** Solo los campos que la app necesita. */
function recortarPago(pago: Record<string, unknown>) {
  return {
    id: pago.id,
    status: pago.status,
    status_detail: pago.status_detail,
    transaction_amount: pago.transaction_amount,
    external_reference: pago.external_reference,
    payment_method_id: pago.payment_method_id,
    date_approved: pago.date_approved,
  };
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "Method Not Allowed" }, 405);

  try {
    const user = await usuarioDeLaSesion(req, supabase);
    if (!user) return json(req, { error: "No autorizado" }, 401);
    const admin = await esAdmin(supabase, user);

    const body = await req.json().catch(() => ({})) as {
      external_reference?: string;
      payment_id?: string | number;
    };

    const { accessToken: token } = await configMp(supabase);
    let pago: Record<string, unknown> | null = null;

    if (body.payment_id != null && String(body.payment_id).trim() !== "") {
      const paymentId = String(body.payment_id).trim();
      if (!/^\d{4,20}$/.test(paymentId)) return json(req, { error: "payment_id invalido" }, 400);
      const res = await fetch(`${MP_API}/v1/payments/${paymentId}`, {
        headers: { Authorization: `Bearer ${token}` },
      });
      if (res.ok) pago = await res.json();
    } else if (esUuid(body.external_reference)) {
      const ref = encodeURIComponent(body.external_reference);
      const res = await fetch(
        `${MP_API}/v1/payments/search?external_reference=${ref}&sort=date_created&criteria=desc`,
        { headers: { Authorization: `Bearer ${token}` } },
      );
      if (res.ok) {
        const data = await res.json();
        const results = data.results as Record<string, unknown>[] | undefined;
        if (results && results.length > 0) pago = results[0];
      }
    } else {
      return json(req, { error: "external_reference (uuid) o payment_id requerido" }, 400);
    }

    if (!pago) return json(req, { pago: null });

    // Autorizacion: el pago tiene que ser de un pedido del usuario
    const pedidoId = String(pago.external_reference ?? "");
    if (!admin) {
      if (!esUuid(pedidoId)) return json(req, { error: "No autorizado" }, 403);
      const { data: pedido } = await supabase
        .from("pedidos")
        .select("pescador_id, usuario_id, cliente_id")
        .eq("id", pedidoId)
        .maybeSingle();
      if (!pedido || !esParticipante(pedido, user.id)) {
        return json(req, { error: "No autorizado" }, 403);
      }
    }

    return json(req, { pago: recortarPago(pago) });
  } catch (err) {
    console.error("[consultar-pago-mp]", err);
    return json(req, { error: "Error interno" }, 500);
  }
});
