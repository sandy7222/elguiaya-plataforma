// Feed de productos para el catálogo de Meta (Commerce Manager / catálogo de WhatsApp Business).
// Las mismas reglas están en lib/services/exportacion_meta.dart (el Excel del administrador). Los dos se prueban con
// test/fixtures/feed_meta_casos.json: si cambia una regla, cambia en los dos lados.
// Correr: node --test supabase/functions/feed-meta/feed_meta.test.ts

export const ENCABEZADOS = [
  "id", "title", "description", "availability", "condition", "price", "link", "image_link", "additional_image_link", "brand", "product_type",
] as const;

export type FilaMeta = Record<(typeof ENCABEZADOS)[number], string>;

export interface ProductoFila {
  id: string;
  nombre?: string | null;
  descripcion?: string | null;
  especificaciones?: string | null;
  precio?: number | string | null;
  stock?: number | string | null;
  rubro?: string | null;
  imagen_url?: string | null;
  galeria_urls?: string[] | string | null;
  activo?: boolean | null;
}

export interface OpcionesMeta {
  marca: string;
  urlProducto: string;
  moneda: string;
}

export const OPCIONES_POR_DEFECTO: OpcionesMeta = {
  marca: "El Guía YA",
  urlProducto: "https://elguiaya.com/tienda",
  moneda: "ARS",
};

const MAX_TITULO = 200;
const MAX_ADICIONALES = 10;
// Separador interno que usa la app para guardar descripción y especificaciones en una sola columna.
const MARCADOR_SPECS = "\n\n<!--ESPECIFICACIONES-->\n\n";

function numero(v: unknown): number {
  const n = typeof v === "number" ? v : Number(v);
  return Number.isFinite(n) ? n : 0;
}

function galeria(v: ProductoFila["galeria_urls"]): string[] {
  if (Array.isArray(v)) return v.filter((u): u is string => typeof u === "string");
  if (typeof v === "string") {
    try {
      const j = JSON.parse(v);
      return Array.isArray(j) ? j.filter((u): u is string => typeof u === "string") : [];
    } catch {
      return [];
    }
  }
  return [];
}

export function imagenes(p: ProductoFila): string[] {
  const todas = [(p.imagen_url ?? "").trim(), ...galeria(p.galeria_urls).map((u) => u.trim())].filter((u) => u.length > 0);
  return todas.filter((u, i) => todas.indexOf(u) === i);
}

function descripcion(p: ProductoFila, titulo: string): string {
  let desc = p.descripcion ?? "";
  let specs = p.especificaciones ?? "";
  const i = desc.indexOf(MARCADOR_SPECS);
  if (i >= 0) {
    if (specs.trim() === "") specs = desc.slice(i + MARCADOR_SPECS.length);
    desc = desc.slice(0, i);
  }
  const partes = [desc.trim(), specs.trim()].filter((t) => t.length > 0);
  return partes.length === 0 ? titulo : partes.join("\n\n");
}

/** Enlace del producto: con `{id}` se reemplaza; si termina en `/` se le suma el id; si no, es un enlace fijo para todos. */
export function enlace(base: string, id: string): string {
  if (base.includes("{id}")) return base.replaceAll("{id}", id);
  if (base.endsWith("/")) return `${base}${id}`;
  return base;
}

/** Una fila del feed de Meta. */
export function filaMeta(p: ProductoFila, opciones: OpcionesMeta = OPCIONES_POR_DEFECTO): FilaMeta {
  const nombre = (p.nombre ?? "").trim();
  const titulo = nombre.length > MAX_TITULO ? nombre.slice(0, MAX_TITULO) : nombre;
  const imgs = imagenes(p);
  const agotado = p.activo === false || numero(p.stock) <= 0;
  return {
    id: p.id,
    title: titulo,
    description: descripcion(p, nombre),
    availability: agotado ? "out of stock" : "in stock",
    condition: "new",
    price: `${numero(p.precio).toFixed(2)} ${opciones.moneda}`,
    link: enlace(opciones.urlProducto, p.id),
    image_link: imgs.length === 0 ? "" : imgs[0],
    additional_image_link: imgs.slice(1, 1 + MAX_ADICIONALES).join(","),
    brand: opciones.marca,
    product_type: p.rubro ?? "",
  };
}

/** ¿Va en el feed? Solo productos activos y con imagen (Meta rechaza los que no la tienen). */
export function publicable(p: ProductoFila): boolean {
  return p.activo !== false && imagenes(p).length > 0;
}

function celda(v: string): string {
  return `"${v.replaceAll('"', '""')}"`;
}

/** CSV (UTF-8, comillas dobles, saltos CRLF) con el encabezado y una fila por producto publicable. */
export function csvMeta(productos: ProductoFila[], opciones: OpcionesMeta = OPCIONES_POR_DEFECTO): string {
  const lineas = [ENCABEZADOS.map(celda).join(",")];
  for (const p of productos.filter(publicable)) {
    const f = filaMeta(p, opciones);
    lineas.push(ENCABEZADOS.map((c) => celda(f[c])).join(","));
  }
  return lineas.join("\r\n") + "\r\n";
}
