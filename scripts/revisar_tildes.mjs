// Paso 1.2c, parte 1: revisa las tildes de los textos de RESPUESTA de assets/elguia/.
//
// El motor de voz pone el acento según la ortografía: si falta una tilde lo pone mal
// ("rio" en vez de "río", "estas" en vez de "estás"). Este script corre en la PC (no
// es parte de la app) y NO toca los activadores, las palabras clave, las preguntas
// canónicas ni los identificadores: esos van sin tilde a propósito, para que
// "rio" y "río" encuentren lo mismo.
//
//   node scripts/revisar_tildes.mjs                 → informe (no escribe nada)
//   node scripts/revisar_tildes.mjs --aplicar       → corrige los casos SIN ambigüedad
//   node scripts/revisar_tildes.mjs --informe f.txt → además guarda el informe en un archivo
//
// Dos listas:
//   · SIN AMBIGÜEDAD (río, surubí, Paraná, también, tenés...): la forma sin tilde no es
//     una palabra del castellano, así que se corrige sola con --aplicar.
//   · AMBIGUAS (estas/estás, mas/más, como/cómo, que/qué, llama/llamá...): la forma sin
//     tilde TAMBIÉN es una palabra. Se listan con el contexto y una sugerencia para
//     revisarlas a mano; el script nunca las cambia.
//
// Meta del plan: 0 casos sin ambigüedad pendientes en las respuestas.

import { readdirSync, readFileSync, statSync, writeFileSync } from "node:fs";
import { join, relative } from "node:path";

const raiz = new URL("../assets/elguia/", import.meta.url).pathname.replace(/^\/([A-Za-z]:)/, "$1");
const aplicar = process.argv.includes("--aplicar");
const iInforme = process.argv.indexOf("--informe");
const archivoInforme = iInforme >= 0 ? process.argv[iInforme + 1] : null;

// ── Qué campos NO son de respuesta ──────────────────────────────────────────
const noEsRespuesta = /^(activadores.*|keywords?|palabras_clave|sinonimos.*|alias.*|intent|intencion|intents|gif|tipos|id|ruta.*|nombre|indicativo|localidad|pantalla|icono|clave.*|preguntas?|revisar|prioridad|fuente.*|nombre_cientifico|cientifico|taxon.*)$/i;

// ── Sin ambigüedad: la forma sin tilde no existe en castellano ──────────────
const sinAmbiguedad = {
  // Los del plan.
  rio: "río", rios: "ríos", surubi: "surubí", surubies: "surubíes", pati: "patí", pacu: "pacú", parana: "Paraná",
  yarara: "yarará", yararas: "yararás", tambien: "también", despues: "después", dia: "día", dias: "días",
  tenes: "tenés", podes: "podés", queres: "querés",
  // Palabras que aparecen sin tilde en las respuestas y no existen así en castellano.
  sabalo: "sábalo", sabalos: "sábalos", aqui: "aquí", ahi: "ahí", alli: "allí", asi: "así",
  informacion: "información", accion: "acción", atencion: "atención", corazon: "corazón", pais: "país",
  util: "útil", utiles: "útiles", facil: "fácil", dificil: "difícil", rapido: "rápido", rapidamente: "rápidamente",
  tamano: "tamaño", tamanos: "tamaños", linea: "línea", lineas: "líneas", ultimo: "último", ultima: "última",
  proximo: "próximo", proxima: "próxima", unico: "único", unica: "única", telefono: "teléfono", pagina: "página",
  musica: "música", camara: "cámara", razon: "razón", conexion: "conexión", ubicacion: "ubicación",
  direccion: "dirección", posicion: "posición", maximo: "máximo", minimo: "mínimo", area: "área",
  basico: "básico", electrico: "eléctrico", tecnico: "técnico", tecnica: "técnica", nautico: "náutico",
  nautica: "náutica", maritimo: "marítimo", metodo: "método", angulo: "ángulo", frio: "frío",
  humedo: "húmedo", plastico: "plástico", metalico: "metálico", maquina: "máquina", helice: "hélice",
  bateria: "batería", energia: "energía", categoria: "categoría", garantia: "garantía",
  // Revisadas a mano: palabras que el propio corpus ya escribe con tilde en otros textos.
  barbaro: "bárbaro", debil: "débil", esferico: "esférico", friccion: "fricción", guia: "guía", guias: "guías",
  lider: "líder", mediodia: "mediodía", precision: "precisión", pronostico: "pronóstico", segun: "según",
  union: "unión", clasico: "clásico", diametro: "diámetro", electrica: "eléctrica", lechon: "lechón",
  presion: "presión", rapida: "rápida", arboles: "árboles", carbon: "carbón", comun: "común", vibora: "víbora",
  atras: "atrás", mantene: "mantené", tene: "tené",
  capitan: "capitán", salio: "salió", bambu: "bambú", versatil: "versátil", constelacion: "constelación",
};

// ── Ambiguas: la forma sin tilde también es una palabra ─────────────────────
const interrogativas = ["que", "como", "cual", "cuales", "quien", "quienes", "donde", "cuando", "cuanto", "cuanta", "cuantos", "cuantas"];
// Estas se listan SIEMPRE: sin tilde son otra palabra y suenan distinto.
const siempreAmbiguas = ["mas", "llama", "llamas", "mira", "miras", "tomas", "sabes", "canas", "cana"];
// "esta/estas" son correctas como demostrativos ("esta boya"): solo se listan donde parecen el verbo estar.
const reEstarVerbo = new RegExp(
  `(?:\\b(?:si|donde|que|y|no|ya|como|cuando|aun|todavia|ahora)\\s+)(esta|estas)(?![A-Za-zÁÉÍÓÚáéíóúÑñ])`,
  "gi",
);
// Las interrogativas solo se listan cuando el contexto sugiere que son interrogativas:
// después de "¿", o de "sé / saber / decime / preguntar / explicame / contame".
const reInterrogativa = new RegExp(
  `(?:[¿]\\s*|\\b(?:se|saber|decime|dime|preguntar|preguntame|explicame|contame|averiguar)\\s+)(${interrogativas.join("|")})(?![A-Za-zÁÉÍÓÚáéíóúÑñ])`,
  "gi",
);
// Qué tilde probablemente corresponde según el contexto (solo es una SUGERENCIA).
const sugerencias = [
  { re: /\b(estas)\s+(cerca|lejos|bien|mal|en|por|seguro|listo|a punto|con|sin|ahi|aqui)\b/gi, nota: "\"estás\" (verbo estar)" },
  { re: /\b(mas)\s+(de|que|o menos|cerca|lejos|grande|chico|largo|corto|fuerte|facil|rapido|lento|importante|tiempo|veces)\b/gi, nota: "\"más\" (cantidad)" },
  { re: /\b(llama)\s+(a|ya|al|ahora)\b/gi, nota: "\"llamá\" (imperativo voseo) si es una orden" },
  { re: /\b(mira)\s+(que|chamigo|che|cheirai|como|ahi|esto|el|la)\b/gi, nota: "\"mirá\" (imperativo voseo)" },
  { re: /\b(esta)\s+(cerca|lejos|bien|mal|en|por|seguro|listo|a punto|con|sin|ahi|aqui)\b/gi, nota: "\"está\" (verbo estar) si no es \"esta cosa\"" },
];

// ── Lector de JSON que conserva el texto original ───────────────────────────
// Recorre el texto crudo y devuelve cada string con su posición, si es una clave y
// el nombre de la clave del objeto que lo contiene (para saber si es de respuesta).
function* cadenas(texto) {
  const pila = []; // cada elemento: { tipo: "obj"|"arr", clave: string|null, esperaClave: bool }
  let i = 0;
  while (i < texto.length) {
    const c = texto[i];
    if (c === "{") pila.push({ tipo: "obj", clave: null, esperaClave: true });
    else if (c === "[") pila.push({ tipo: "arr", clave: null, esperaClave: false });
    else if (c === "}" || c === "]") pila.pop();
    else if (c === ",") {
      const t = pila[pila.length - 1];
      if (t?.tipo === "obj") t.esperaClave = true;
    } else if (c === '"') {
      let j = i + 1;
      while (j < texto.length && texto[j] !== '"') j += texto[j] === "\\" ? 2 : 1;
      const literal = texto.slice(i, j + 1);
      const t = pila[pila.length - 1];
      const esClave = t?.tipo === "obj" && t.esperaClave;
      let valor;
      try {
        valor = JSON.parse(literal);
      } catch {
        valor = null;
      }
      if (esClave) {
        t.clave = valor;
        t.esperaClave = false;
      }
      // La clave "vigente" es la del objeto más cercano que tenga una.
      let clave = null;
      for (let k = pila.length - 1; k >= 0; k--) {
        if (pila[k].tipo === "obj" && pila[k].clave != null) {
          clave = pila[k].clave;
          break;
        }
      }
      yield { inicio: i, fin: j + 1, esClave, valor, clave, literal };
      i = j;
    }
    i++;
  }
}

// ── Reglas de reemplazo ─────────────────────────────────────────────────────
const letras = "A-Za-zÁÉÍÓÚáéíóúÑñÜü";
const reGlobalSinAmb = new RegExp(`(?<![${letras}])(${Object.keys(sinAmbiguedad).join("|")})(?![${letras}])`, "gi");

function conservarMayusculas(original, corregida) {
  if (corregida[0] === corregida[0].toUpperCase() && corregida[0] !== corregida[0].toLowerCase()) {
    // Nombre propio ("Paraná"): siempre con mayúscula, salvo que esté todo en mayúsculas.
    return original === original.toUpperCase() && original.length > 1 ? corregida.toUpperCase() : corregida;
  }
  if (original === original.toUpperCase() && original.length > 1) return corregida.toUpperCase();
  if (original[0] === original[0].toUpperCase()) return corregida[0].toUpperCase() + corregida.slice(1);
  return corregida;
}

function corregir(texto) {
  const hechos = [];
  const nuevo = texto.replace(reGlobalSinAmb, (m) => {
    const buena = sinAmbiguedad[m.toLowerCase()];
    if (!buena) return m;
    const r = conservarMayusculas(m, buena);
    if (r !== m) hechos.push([m, r]);
    return r;
  });
  return { nuevo, hechos };
}

function ambiguos(texto) {
  const salida = [];
  const contexto = (idx, largo) => texto.slice(Math.max(0, idx - 28), idx + largo + 28).replace(/\s+/g, " ");
  const re = new RegExp(`(?<![${letras}])(${siempreAmbiguas.join("|")})(?![${letras}])`, "gi");
  for (const m of texto.matchAll(re)) {
    let sugerencia = "";
    for (const s of sugerencias) {
      s.re.lastIndex = 0;
      for (const h of texto.matchAll(s.re)) {
        if (h.index <= m.index + 1 && m.index <= h.index + h[0].length) sugerencia = s.nota;
      }
    }
    salida.push({ palabra: m[1], contexto: contexto(m.index, m[1].length), sugerencia });
  }
  for (const m of texto.matchAll(reEstarVerbo)) {
    salida.push({ palabra: m[1], contexto: contexto(m.index, m[0].length), sugerencia: "\"está/estás\" (verbo estar)" });
  }
  for (const m of texto.matchAll(reInterrogativa)) {
    salida.push({ palabra: m[1], contexto: contexto(m.index, m[0].length), sugerencia: "interrogativa → con tilde" });
  }
  return salida;
}

// ── Recorrido ───────────────────────────────────────────────────────────────
function jsons(dir) {
  const r = [];
  for (const nombre of readdirSync(dir)) {
    const ruta = join(dir, nombre);
    if (statSync(ruta).isDirectory()) r.push(...jsons(ruta));
    else if (nombre.endsWith(".json")) r.push(ruta);
  }
  return r;
}

const quitarTildes = (w) => w.normalize("NFD").replace(/[̀-ͯ]/g, "");
const conteoPalabras = new Map(); // palabra (tal cual) → cantidad, solo en campos de respuesta
const lineas = [];
const porPalabra = {};
const porClave = {};
const ambPorPalabra = {};
let archivosCambiados = 0;
let cambios = 0;
const ambiguosLista = [];

for (const ruta of jsons(raiz)) {
  // Las tablas de sinónimos son de BÚSQUEDA (van sin tilde a propósito), no de respuesta.
  if (/sinonimos/i.test(ruta)) continue;
  const original = readFileSync(ruta, "utf8");
  const trozos = [];
  let ultimo = 0;
  let cambio = false;
  for (const c of cadenas(original)) {
    if (c.esClave || typeof c.valor !== "string") continue;
    if (c.clave && noEsRespuesta.test(c.clave)) continue;
    if (c.valor.split(/\s+/).length < 2) continue; // una palabra suelta es un nombre o un valor interno
    const { nuevo, hechos } = corregir(c.valor);
    for (const w of c.valor.match(new RegExp(`[${letras}]{3,}`, "g")) ?? []) {
      conteoPalabras.set(w, (conteoPalabras.get(w) ?? 0) + 1);
    }
    if (hechos.length) porClave[c.clave] = (porClave[c.clave] ?? 0) + hechos.length;
    for (const [de, a] of hechos) {
      const k = `${de.toLowerCase()} → ${a.toLowerCase()}`;
      porPalabra[k] = (porPalabra[k] ?? 0) + 1;
    }
    if (hechos.length) {
      cambios += hechos.length;
      cambio = true;
      trozos.push(original.slice(ultimo, c.inicio), JSON.stringify(nuevo));
      ultimo = c.fin;
    }
    for (const a of ambiguos(nuevo)) {
      const k = a.palabra.toLowerCase();
      ambPorPalabra[k] = (ambPorPalabra[k] ?? 0) + 1;
      ambiguosLista.push({ archivo: relative(raiz, ruta).replaceAll("\\", "/"), clave: c.clave, ...a });
    }
  }
  if (cambio) {
    archivosCambiados++;
    if (aplicar) writeFileSync(ruta, trozos.join("") + original.slice(ultimo), "utf8");
  }
}

// ── Informe ─────────────────────────────────────────────────────────────────
lineas.push(`Tildes en assets/elguia/ (${aplicar ? "APLICADO" : "solo informe"})`);
lineas.push("");
lineas.push(`SIN AMBIGÜEDAD: ${cambios} casos en ${archivosCambiados} archivos ${aplicar ? "corregidos" : "por corregir (usar --aplicar)"}`);
for (const [k, n] of Object.entries(porPalabra).sort((a, b) => b[1] - a[1])) lineas.push(`  ${String(n).padStart(4)}  ${k}`);
lineas.push("");
lineas.push("Por campo: " + Object.entries(porClave).sort((a, b) => b[1] - a[1]).map(([k, n]) => `${k}=${n}`).join(", "));
lineas.push("");
// Palabras que aparecen SIN tilde y que el propio corpus escribe CON tilde en otro lado:
// candidatas para sumar a la lista sin ambigüedad (previa revisión).
const otras = [];
const variantes = new Map();
for (const [w, n] of conteoPalabras) {
  const base = quitarTildes(w.toLowerCase());
  if (!variantes.has(base)) variantes.set(base, { sin: 0, con: new Map() });
  const v = variantes.get(base);
  if (w.toLowerCase() === base) v.sin += n;
  else v.con.set(w.toLowerCase(), (v.con.get(w.toLowerCase()) ?? 0) + n);
}
const yaCubiertas = new Set([...Object.keys(sinAmbiguedad), ...siempreAmbiguas, ...interrogativas, "esta", "estas"]);
for (const [base, v] of variantes) {
  // Las formas verbales (dejás, llegó, ajustá) no entran: la forma sin tilde es otra persona del verbo.
  const conVerbal = [...v.con.keys()].every((k) => /[áéíó]s?$/.test(k));
  if (v.sin > 0 && v.con.size > 0 && !yaCubiertas.has(base) && !conVerbal) {
    otras.push(`${String(v.sin).padStart(4)} sin tilde  "${base}"  vs  ${[...v.con].map(([k, n]) => `${k} (${n})`).join(", ")}`);
  }
}
lineas.push(`POSIBLES nuevas sin ambigüedad (${otras.length}): sin tilde acá, con tilde en otro lado del corpus. Revisar y sumar a mano.`);
for (const o of otras.sort()) lineas.push("  " + o);
lineas.push("");
lineas.push(`AMBIGUAS (a mano): ${ambiguosLista.length} ocurrencias`);
for (const [k, n] of Object.entries(ambPorPalabra).sort((a, b) => b[1] - a[1])) lineas.push(`  ${String(n).padStart(4)}  ${k}`);
lineas.push("");
for (const a of ambiguosLista) lineas.push(`  [${a.archivo}] ...${a.contexto}...${a.sugerencia ? "  → " + a.sugerencia : ""}`);

const texto = lineas.join("\n");
console.log(texto);
if (archivoInforme) writeFileSync(archivoInforme, texto + "\n", "utf8");
