// Feed de productos para Meta (catálogo de WhatsApp Business). Público y de solo lectura: devuelve el catálogo activo en CSV.
// Sin secretos: usa la URL y la clave ANÓNIMA que Supabase ya inyecta en las funciones.

import { atender } from "./handler.ts";

Deno.serve((req) =>
  atender(req, {
    supabaseUrl: Deno.env.get("SUPABASE_URL") ?? "",
    anonKey: Deno.env.get("SUPABASE_ANON_KEY") ?? "",
  })
);
