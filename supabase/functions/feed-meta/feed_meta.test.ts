// Feed de Meta: reglas de cada fila (casos compartidos con Dart) y comportamiento del servidor.
// Correr: node --test supabase/functions/feed-meta/feed_meta.test.ts
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { csvMeta, ENCABEZADOS, filaMeta, publicable } from "./feed_meta.ts";
import { atender } from "./handler.ts";

const casos = JSON.parse(readFileSync(new URL("../../../test/fixtures/feed_meta_casos.json", import.meta.url), "utf8")).casos;

for (const c of casos) {
  test(`paridad con Dart: ${c.nombre_caso}`, () => {
    assert.deepEqual(filaMeta(c.row), c.esperado);
  });
}

test("el encabezado son las 11 columnas del feed de Meta", () => {
  assert.deepEqual([...ENCABEZADOS], [
    "id", "title", "description", "availability", "condition", "price", "link", "image_link", "additional_image_link", "brand", "product_type",
  ]);
});

test("el CSV tiene encabezado y una línea por producto publicable, con comillas escapadas y saltos CRLF", () => {
  const csv = csvMeta(casos.map((c: { row: never }) => c.row));
  const lineas = csv.split("\r\n");
  assert.equal(lineas[0], ENCABEZADOS.map((c) => `"${c}"`).join(","));
  const caso8 = casos.find((c: { nombre_caso: string }) => c.nombre_caso.startsWith("descripción con comillas"));
  assert.ok(csv.includes('"Set ""Matero"", completo"'), "las comillas se duplican");
  assert.ok(csv.includes(caso8.esperado.description.replaceAll('"', '""')), "los saltos de línea quedan dentro de la celda");
  assert.ok(csv.endsWith("\r\n"));
});

test("no se publican productos inactivos ni sin imagen", () => {
  assert.equal(publicable({ id: "a", activo: false, imagen_url: "https://x/a.jpg" }), false);
  assert.equal(publicable({ id: "a", activo: true, imagen_url: "", galeria_urls: [] }), false);
  assert.equal(publicable({ id: "a", activo: true, imagen_url: "", galeria_urls: ["https://x/b.jpg"] }), true);
  const csv = csvMeta([{ id: "i", nombre: "Pausado", activo: false, imagen_url: "https://x/a.jpg", precio: 1, stock: 1 }]);
  assert.equal(csv.split("\r\n").length, 2, "solo encabezado + salto final");
});

test("precio y stock que llegan como texto (numeric de Postgres) se entienden", () => {
  const f = filaMeta({ id: "z", nombre: "N", precio: "20280.00", stock: "5", activo: true, imagen_url: "https://x/a.jpg" });
  assert.equal(f.price, "20280.00 ARS");
  assert.equal(f.availability, "in stock");
});

test("galería que llega como texto JSON se entiende", () => {
  const f = filaMeta({ id: "z", nombre: "N", precio: 1, stock: 1, activo: true, imagen_url: "https://x/a.jpg", galeria_urls: '["https://x/b.jpg"]' });
  assert.equal(f.additional_image_link, "https://x/b.jpg");
});

const entorno = { supabaseUrl: "https://proyecto.supabase.co", anonKey: "clave-anonima-de-prueba" };
const filasFalsas = casos.map((c: { row: never }) => c.row);
function buscarFalso(status = 200, cuerpo: unknown = filasFalsas) {
  const llamadas: { url: string; headers: Record<string, string> }[] = [];
  const f = (async (url: string, init: { headers: Record<string, string> }) => {
    llamadas.push({ url, headers: init.headers });
    return new Response(JSON.stringify(cuerpo), { status });
  }) as unknown as typeof fetch;
  return { f, llamadas };
}

test("GET devuelve el CSV con el tipo correcto y caché de una hora", async () => {
  const { f } = buscarFalso();
  const r = await atender(new Request("https://x/feed-meta"), entorno, f);
  assert.equal(r.status, 200);
  assert.match(r.headers.get("content-type") ?? "", /text\/csv/);
  assert.equal(r.headers.get("cache-control"), "public, max-age=3600");
  const t = await r.text();
  assert.ok(t.startsWith('"id","title"'));
});

test("HEAD no devuelve cuerpo", async () => {
  const { f } = buscarFalso();
  const r = await atender(new Request("https://x/feed-meta", { method: "HEAD" }), entorno, f);
  assert.equal(r.status, 200);
  assert.equal(await r.text(), "");
});

test("solo GET y HEAD (POST, PUT, DELETE → 405)", async () => {
  for (const m of ["POST", "PUT", "DELETE", "PATCH"]) {
    const { f, llamadas } = buscarFalso();
    const r = await atender(new Request("https://x/feed-meta", { method: m }), entorno, f);
    assert.equal(r.status, 405, m);
    assert.equal(llamadas.length, 0, "ni siquiera consulta la base");
  }
});

test("lee solo productos activos, con la clave anónima (nunca la de servicio) y sin mandar datos de quien pregunta", async () => {
  const { f, llamadas } = buscarFalso();
  await atender(new Request("https://x/feed-meta?marca=Otra&x=1", { headers: { authorization: "Bearer secreto-del-que-pregunta" } }), entorno, f);
  assert.equal(llamadas.length, 1);
  assert.match(llamadas[0].url, /\/rest\/v1\/productos\?/);
  assert.match(llamadas[0].url, /activo=eq\.true/);
  assert.equal(llamadas[0].headers.apikey, "clave-anonima-de-prueba");
  assert.equal(llamadas[0].headers.Authorization, "Bearer clave-anonima-de-prueba");
  assert.ok(!JSON.stringify(llamadas[0]).includes("secreto-del-que-pregunta"));
});

test("los parámetros de la dirección no cambian la marca ni el enlace (nadie de afuera los pisa)", async () => {
  const { f } = buscarFalso();
  const r = await atender(new Request("https://x/feed-meta?marca=Falsa&base=https://malo.com/"), entorno, f);
  const t = await r.text();
  assert.ok(!t.includes("Falsa"));
  assert.ok(!t.includes("malo.com"));
  assert.ok(t.includes("El Guía YA"));
});

test("si la base falla, 502 con un mensaje fijo (sin detalles internos)", async () => {
  const { f } = buscarFalso(500, { message: "detalle interno que no debe salir", hint: "x" });
  const r = await atender(new Request("https://x/feed-meta"), entorno, f);
  assert.equal(r.status, 502);
  assert.ok(!(await r.text()).includes("detalle interno"));
});

test("si fetch lanza una excepción, 502", async () => {
  const roto = (async () => { throw new Error("sin red"); }) as unknown as typeof fetch;
  const r = await atender(new Request("https://x/feed-meta"), entorno, roto);
  assert.equal(r.status, 502);
});

test("sin configuración, 500 y no consulta nada", async () => {
  const { f, llamadas } = buscarFalso();
  const r = await atender(new Request("https://x/feed-meta"), { supabaseUrl: "", anonKey: "" }, f);
  assert.equal(r.status, 500);
  assert.equal(llamadas.length, 0);
});
