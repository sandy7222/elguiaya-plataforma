// Edge Function: crear preferencia de Mercado Pago (Checkout Pro) en el servidor.
//
// SEGURIDAD: el telefono solo manda el id del pedido. El importe, el titulo y el pagador salen de la
// base de datos; el pedido tiene que pertenecer al usuario autenticado. Lo que el cliente mande como
// "monto" o "titulo" se IGNORA.
//
// Secretos: MP_ACCESS_TOKEN, SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY

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
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;

const supabase = clienteServicio();

// Estados en los que todavia tiene sentido cobrar.
const ESTADOS_COBRABLES = new Set([
  "pendiente_pago",
  "pago_pendiente",
  "pago_rechazado",
  "pago_monto_invalido",
  "programado",
  "pendiente",
  "aceptado",
]);

serve(async (req: Request) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "Method Not Allowed" }, 405);

  try {
    // 1. Usuario real (no alcanza con la clave anonima)
    const user = await usuarioDeLaSesion(req, supabase);
    if (!user) return json(req, { error: "No autorizado" }, 401);

    // 2. Solo se acepta el id del pedido
    const body = await req.json().catch(() => ({})) as Record<string, unknown>;
    const pedidoId = String(body.pedido_id ?? "").trim();
    if (!esUuid(pedidoId)) return json(req, { error: "pedido_id invalido" }, 400);

    // 3. El pedido y su importe, desde la base
    const { data: pedido, error: errPedido } = await supabase
      .from("pedidos")
      .select("id, estado, tipo_checkout, monto_total, total, numero_pedido, pescador_id, usuario_id, cliente_id")
      .eq("id", pedidoId)
      .maybeSingle();
    if (errPedido || !pedido) return json(req, { error: "Pedido no encontrado" }, 404);

    // 4. Tiene que ser del usuario (o un admin)
    if (!esParticipante(pedido, user.id) && !(await esAdmin(supabase, user))) {
      return json(req, { error: "Ese pedido no es tuyo" }, 403);
    }

    if (!ESTADOS_COBRABLES.has(String(pedido.estado))) {
      return json(req, { error: `El pedido no se puede cobrar en estado ${pedido.estado}` }, 409);
    }

    const monto = Number(pedido.monto_total) > 0 ? Number(pedido.monto_total) : Number(pedido.total);
    if (!Number.isFinite(monto) || monto <= 0) {
      return json(req, { error: "El pedido no tiene un total valido" }, 409);
    }

    // 5. Anti-manipulacion: el total no puede ser menor al valor de los productos
    const { data: piso } = await supabase.rpc("total_minimo_pedido", { p_pedido_id: pedidoId });
    if (piso != null && monto + 0.01 < Number(piso)) {
      console.error(`[crear-preferencia] total ${monto} menor al piso ${piso} en pedido ${pedidoId}`);
      return json(req, { error: "El total del pedido no coincide con sus productos" }, 409);
    }

    // Modo (prueba/produccion) y token segun el interruptor del panel de administracion
    const { sandbox, accessToken } = await configMp(supabase);
    const webhookUrl = `${SUPABASE_URL}/functions/v1/mp-webhook`;
    const titulo = pedido.numero_pedido
      ? `Pedido #${pedido.numero_pedido} - El Guia YA`
      : "Compra El Guia YA";
    const email = user.email ?? "comprador@elguiaya.com";

    const preferenceBody = {
      items: [{ title: titulo, quantity: 1, currency_id: "ARS", unit_price: monto }],
      payer: { email },
      external_reference: pedidoId,
      notification_url: webhookUrl,
      back_urls: {
        success: `capitanya://pago/success?pedido_id=${encodeURIComponent(pedidoId)}`,
        failure: `capitanya://pago/failure?pedido_id=${encodeURIComponent(pedidoId)}`,
        pending: `capitanya://pago/pending?pedido_id=${encodeURIComponent(pedidoId)}`,
      },
      statement_descriptor: "El Guia YA",
      payment_methods: { excluded_payment_types: [], installments: 1 },
    };

    const mpRes = await fetch(`${MP_API}/checkout/preferences`, {
      method: "POST",
      headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
      body: JSON.stringify(preferenceBody),
    });
    const mpData = await mpRes.json();
    if (!mpRes.ok) {
      console.error("[crear-preferencia] error de Mercado Pago:", mpRes.status);
      return json(req, { error: "Mercado Pago no pudo crear el cobro" }, 502);
    }

    const preferenceId = mpData.id?.toString() ?? "";
    const initPoint = sandbox
      ? (mpData.sandbox_init_point?.toString() || mpData.init_point?.toString() || "")
      : (mpData.init_point?.toString() || "");

    // Solo se guarda la preferencia si el pedido sigue en un estado cobrable (evita pisar un pago).
    await supabase
      .from("pedidos")
      .update({
        mp_preference_id: preferenceId,
        mp_external_reference: pedidoId,
        updated_at: new Date().toISOString(),
      })
      .eq("id", pedidoId)
      .in("estado", [...ESTADOS_COBRABLES]);

    return json(req, {
      preference_id: preferenceId,
      init_point: mpData.init_point,
      sandbox_init_point: mpData.sandbox_init_point,
      link_pago: initPoint,
      is_sandbox: sandbox,
      monto, // informativo: es el importe que el SERVIDOR calculo
    });
  } catch (err) {
    console.error("[crear-preferencia]", err);
    return json(req, { error: "Error interno" }, 500);
  }
});
