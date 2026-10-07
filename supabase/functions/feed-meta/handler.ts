// Atiende el pedido del feed de Meta. Separado de index.ts para poder probarlo sin Deno ni red.

import { csvMeta, OPCIONES_POR_DEFECTO, type ProductoFila } from "./feed_meta.ts";

export interface Entorno {
  supabaseUrl: string;
  anonKey: string;
}

const COLUMNAS = "id,nombre,descripcion,especificaciones,precio,stock,rubro,imagen_url,galeria_urls,activo";

const cabeceras = {
  "Content-Type": "text/csv; charset=utf-8",
  // Meta lo relee todos los días: una hora de caché alcanza y cuida el consumo de Supabase.
  "Cache-Control": "public, max-age=3600",
  "X-Content-Type-Options": "nosniff",
  "Content-Disposition": 'inline; filename="catalogo_meta.csv"',
};

function texto(cuerpo: string, status: number) {
  return new Response(cuerpo, { status, headers: { "Content-Type": "text/plain; charset=utf-8" } });
}

export async function atender(req: Request, entorno: Entorno, buscar: typeof fetch = fetch): Promise<Response> {
  if (req.method !== "GET" && req.method !== "HEAD") return texto("Method Not Allowed", 405);
  if (!entorno.supabaseUrl || !entorno.anonKey) return texto("Servicio sin configurar", 500);

  const url = `${entorno.supabaseUrl}/rest/v1/productos?select=${COLUMNAS}&activo=eq.true&order=nombre.asc&limit=5000`;
  let filas: ProductoFila[];
  try {
    // Con la clave anónima: se aplican las reglas de lectura pública de la tabla; no se usa la clave de servicio.
    const r = await buscar(url, { headers: { apikey: entorno.anonKey, Authorization: `Bearer ${entorno.anonKey}` } });
    if (!r.ok) return texto("No se pudo leer el catálogo", 502);
    filas = await r.json();
  } catch {
    return texto("No se pudo leer el catálogo", 502);
  }
  if (!Array.isArray(filas)) return texto("No se pudo leer el catálogo", 502);

  const csv = csvMeta(filas, OPCIONES_POR_DEFECTO);
  return new Response(req.method === "HEAD" ? null : csv, { status: 200, headers: cabeceras });
}
