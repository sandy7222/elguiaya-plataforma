// Utilidades compartidas de autenticacion para las Edge Functions de pagos.

import { createClient, SupabaseClient, User } from "https://esm.sh/@supabase/supabase-js@2";

const ORIGENES_WEB_PERMITIDOS = new Set([
  "https://elguiaya.com",
  "https://www.elguiaya.com",
  "https://app.elguiaya.com",
  "http://localhost:3000",
  "http://localhost:8080",
]);

/** CORS: la app movil no envia Origin; la web solo desde los dominios propios. */
export function corsHeaders(req: Request): Record<string, string> {
  const origin = req.headers.get("Origin");
  const permitido = origin && ORIGENES_WEB_PERMITIDOS.has(origin) ? origin : "";
  return {
    ...(permitido ? { "Access-Control-Allow-Origin": permitido, "Vary": "Origin" } : {}),
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
  };
}

export function json(req: Request, body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders(req), "Content-Type": "application/json" },
  });
}

export function clienteServicio(): SupabaseClient {
  return createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );
}

/**
 * Devuelve el usuario REAL de la sesion, o null.
 * verify_jwt acepta tambien la clave anonima (que es publica y va en la app); esa NO identifica a
 * ningun usuario, asi que getUser() falla y se rechaza la llamada.
 */
export async function usuarioDeLaSesion(
  req: Request,
  supabase: SupabaseClient,
): Promise<User | null> {
  const auth = req.headers.get("Authorization") ?? "";
  const token = auth.replace(/^Bearer\s+/i, "").trim();
  if (!token) return null;
  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) return null;
  return data.user;
}

export async function esAdmin(supabase: SupabaseClient, user: User): Promise<boolean> {
  if (String(user.app_metadata?.role ?? "").toLowerCase() === "admin") return true;
  const { data } = await supabase
    .from("profiles")
    .select("admin")
    .eq("user_id", user.id)
    .maybeSingle();
  return data?.admin === true;
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const esUuid = (v: unknown): v is string => typeof v === "string" && UUID.test(v);

/** Quien puede pagar/consultar un pedido: sus propios participantes (o un admin). */
export function esParticipante(pedido: Record<string, unknown>, userId: string): boolean {
  return [pedido.pescador_id, pedido.usuario_id, pedido.cliente_id]
    .map((v) => (v == null ? "" : String(v)))
    .includes(userId);
}
