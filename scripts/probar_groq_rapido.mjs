// Paso 1.5: mide, contra la Edge Function ia-proxy YA DESPLEGADA con los cambios,
// si `reasoning_effort: low` + `max_completion_tokens: 600` hacen más rápido a Groq
// (gpt-oss-120b) y si alguna respuesta queda cortada (finish_reason "length" o vacía).
//
// Uso (PowerShell), con las dos variables cargadas en tu sesión, SIN pegarlas en el chat:
//   $env:SUPABASE_URL = "https://<ref>.supabase.co"
//   $env:SUPABASE_ANON_KEY = "<anon key del proyecto>"
//   node scripts/probar_groq_rapido.mjs [pedidos por modo, por defecto 12]
//
// Gasta cuota de Groq. El proxy limita a 30 pedidos cada 10 minutos por clave: con
// 12 por modo son 24 y entra justo; no lo corras dos veces seguidas.
// Los pedidos van intercalados (base, rápido, base, rápido...) para que la hora del
// día no favorezca a un modo.

const url = process.env.SUPABASE_URL;
const clave = process.env.SUPABASE_ANON_KEY;
if (!url || !clave) {
  console.error("Faltan SUPABASE_URL y/o SUPABASE_ANON_KEY en el entorno.");
  process.exit(1);
}
const porModo = Math.min(14, Math.max(2, Number(process.argv[2] ?? 12)));

const preguntas = [
  "¿Cómo se hace el nudo palomar? Contestá en tres oraciones.",
  "¿Qué carnada conviene para el dorado en el Paraná?",
  "Explicame para qué sirve una boya de pique.",
  "¿Cómo se prepara una masa casera para boga?",
  "¿Qué diferencia hay entre monofilamento y multifilamento?",
  "Dame tres consejos para pescar pejerrey en laguna.",
  "¿Cuándo conviene salir a pescar surubí?",
  "¿Cómo cuido una caña de pescar después de usarla?",
];

const sistema = "Sos El Guía, un baqueano de pesca del río Paraná. Contestá en castellano rioplatense, breve y claro.";

async function pedir(pregunta, rapido) {
  const cuerpo = {
    provider: "groq",
    model: "openai/gpt-oss-120b",
    temperature: 0.7,
    messages: [
      { role: "system", content: sistema },
      { role: "user", content: pregunta },
    ],
    ...(rapido ? { reasoning_effort: "low", max_completion_tokens: 600 } : {}),
  };
  const t0 = performance.now();
  const r = await fetch(`${url}/functions/v1/ia-proxy`, {
    method: "POST",
    headers: { "Content-Type": "application/json", Authorization: `Bearer ${clave}`, apikey: clave },
    body: JSON.stringify(cuerpo),
  });
  const ms = performance.now() - t0;
  let envoltorio = {};
  try {
    envoltorio = await r.json();
  } catch {
    // respuesta no JSON
  }
  const status = envoltorio.status ?? r.status;
  const cuerpoGroq = envoltorio.body ?? {};
  const eleccion = cuerpoGroq.choices?.[0];
  const texto = (eleccion?.message?.content ?? "").trim();
  return {
    ms,
    status,
    finish: eleccion?.finish_reason ?? "?",
    vacia: texto.length === 0,
    tokens: cuerpoGroq.usage?.completion_tokens ?? null,
    error: status === 200 ? null : (cuerpoGroq.error?.message ?? envoltorio.error ?? "sin detalle"),
  };
}

function percentil(valores, p) {
  const v = [...valores].sort((a, b) => a - b);
  return v[Math.min(v.length - 1, Math.ceil(v.length * p) - 1)];
}

const resultados = { base: [], rapido: [] };
for (let i = 0; i < porModo; i++) {
  for (const modo of ["base", "rapido"]) {
    const r = await pedir(preguntas[i % preguntas.length], modo === "rapido");
    resultados[modo].push(r);
    process.stdout.write(modo === "rapido" ? "r" : "b");
  }
}
console.log("\n");

let rechazoParametros = false;
for (const modo of ["base", "rapido"]) {
  const rs = resultados[modo];
  const ok = rs.filter((r) => r.status === 200);
  const cortadas = ok.filter((r) => r.finish === "length" || r.vacia).length;
  const tokens = ok.map((r) => r.tokens).filter((t) => t != null);
  console.log(`── ${modo === "base" ? "BASE (como hoy)" : "RÁPIDO (low + 600)"} ──`);
  console.log(`  pedidos: ${rs.length}  ok: ${ok.length}  con error: ${rs.length - ok.length}`);
  if (ok.length) {
    console.log(`  p50: ${Math.round(percentil(ok.map((r) => r.ms), 0.5))} ms   p95: ${Math.round(percentil(ok.map((r) => r.ms), 0.95))} ms`);
    console.log(`  respuestas cortadas (length o vacías): ${cortadas}`);
    if (tokens.length) console.log(`  tokens de salida promedio: ${Math.round(tokens.reduce((a, b) => a + b, 0) / tokens.length)}`);
  }
  const errores = [...new Set(rs.filter((r) => r.status !== 200).map((r) => `${r.status}: ${r.error}`))];
  if (errores.length) console.log(`  errores: ${errores.join(" | ")}`);
  if (modo === "rapido" && rs.some((r) => r.status === 400)) rechazoParametros = true;
}

console.log("");
if (rechazoParametros) {
  console.log("⚠ Groq (o el proxy) rechazó los parámetros con 400: el cliente cae solo al pedido normal.");
}
const b = resultados.base.filter((r) => r.status === 200);
const f = resultados.rapido.filter((r) => r.status === 200);
if (b.length && f.length) {
  const p50b = percentil(b.map((r) => r.ms), 0.5);
  const p50f = percentil(f.map((r) => r.ms), 0.5);
  const cortadas = f.filter((r) => r.finish === "length" || r.vacia).length;
  console.log(`p50 rápido ${Math.round(p50f)} ms vs base ${Math.round(p50b)} ms → ${p50f < p50b ? "MÁS RÁPIDO ✔" : "NO es más rápido ✘"}`);
  console.log(`cortadas en modo rápido: ${cortadas} → ${cortadas === 0 ? "0 ✔" : "HAY CORTADAS ✘ (el cliente las reintenta, pero conviene subir el tope)"}`);
}
