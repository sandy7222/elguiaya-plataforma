// Configuracion de Mercado Pago compartida por las Edge Functions de pagos.
//
// El MODO (prueba o produccion) lo define el interruptor "Modo Sandbox" del panel de administracion
// (config_sistema.is_sandbox). Segun el modo se elige el token:
//
//   modo PRUEBA      -> secreto MP_ACCESS_TOKEN_TEST   (si no existe, el token cargado en el panel)
//   modo PRODUCCION  -> secreto MP_ACCESS_TOKEN        (si no existe, el token cargado en el panel)
//
// Asi se puede pasar de produccion a prueba desde el panel sin tocar secretos, y a futuro mover el
// token de produccion a un secreto del servidor (que es lo recomendado) sin romper el interruptor.
//
// Webhook: la clave de firma tambien depende del modo:
//   modo PRUEBA      -> MP_WEBHOOK_SECRET_TEST (si no existe, MP_WEBHOOK_SECRET)
//   modo PRODUCCION  -> MP_WEBHOOK_SECRET

import { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export interface ConfigMp {
  sandbox: boolean;
  accessToken: string;
}

/** Modo y token vigentes. Lanza si no hay ningun token configurado. */
export async function configMp(supabase: SupabaseClient): Promise<ConfigMp> {
  const { data } = await supabase
    .from("config_sistema")
    .select("is_sandbox, mp_access_token")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();

  // Si no se puede leer el modo se asume PRUEBA: ante la duda no se cobra de verdad.
  const sandbox = data?.is_sandbox !== false;
  const deSecreto = sandbox
    ? Deno.env.get("MP_ACCESS_TOKEN_TEST")
    : Deno.env.get("MP_ACCESS_TOKEN");
  const deTabla = data?.mp_access_token?.toString() ?? "";

  const accessToken = (deSecreto && deSecreto.trim()) || deTabla;
  if (!accessToken) {
    throw new Error(`Falta el access token de Mercado Pago para el modo ${sandbox ? "prueba" : "produccion"}`);
  }
  if (!deSecreto) {
    console.warn(
      `[mp_config] usando el token guardado en el panel (modo ${sandbox ? "prueba" : "produccion"}). ` +
        "Recomendado: cargarlo como secreto de la funcion.",
    );
  }
  return { sandbox, accessToken };
}

/** Clave de firma del webhook segun el modo, o "" si no esta configurada. */
export function claveWebhook(sandbox: boolean): string {
  const prod = Deno.env.get("MP_WEBHOOK_SECRET") ?? "";
  if (!sandbox) return prod;
  return Deno.env.get("MP_WEBHOOK_SECRET_TEST") || prod;
}

/** Modo vigente (para el webhook, que necesita la clave antes de consultar el pago). */
export async function modoSandbox(supabase: SupabaseClient): Promise<boolean> {
  const { data } = await supabase
    .from("config_sistema")
    .select("is_sandbox")
    .order("updated_at", { ascending: false })
    .limit(1)
    .maybeSingle();
  return data?.is_sandbox !== false;
}
