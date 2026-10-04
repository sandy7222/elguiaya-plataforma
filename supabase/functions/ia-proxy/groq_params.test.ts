// Paso 1.5: lista blanca de los parámetros de velocidad que el proxy deja pasar a Groq.
// Correr: node --test supabase/functions/ia-proxy/groq_params.test.ts
import test from "node:test";
import assert from "node:assert/strict";
import { sanitizarParamsGroq } from "./groq_params.ts";

const gptOss = "openai/gpt-oss-120b";

test("deja pasar reasoning_effort low y medium", () => {
  assert.deepEqual(sanitizarParamsGroq({ reasoning_effort: "low" }, gptOss), { reasoning_effort: "low" });
  assert.deepEqual(sanitizarParamsGroq({ reasoning_effort: "medium" }, gptOss), { reasoning_effort: "medium" });
});

test("descarta valores fuera de la lista blanca", () => {
  for (const v of ["high", "LOW", "", "none", 3, null, {}, ["low"]]) {
    assert.deepEqual(sanitizarParamsGroq({ reasoning_effort: v }, gptOss), {}, `valor ${JSON.stringify(v)}`);
  }
});

test("max_completion_tokens: enteros entre 64 y 2000", () => {
  assert.deepEqual(sanitizarParamsGroq({ max_completion_tokens: 600 }, gptOss), { max_completion_tokens: 600 });
  assert.deepEqual(sanitizarParamsGroq({ max_completion_tokens: 64 }, gptOss), { max_completion_tokens: 64 });
  assert.deepEqual(sanitizarParamsGroq({ max_completion_tokens: 2000 }, gptOss), { max_completion_tokens: 2000 });
});

test("max_completion_tokens: lo demás se descarta (no se acomoda)", () => {
  for (const v of [63, 2001, 0, -5, 600.5, "600", null, NaN, Infinity, {}]) {
    assert.deepEqual(sanitizarParamsGroq({ max_completion_tokens: v }, gptOss), {}, `valor ${JSON.stringify(v)}`);
  }
});

test("los dos juntos", () => {
  assert.deepEqual(
    sanitizarParamsGroq({ reasoning_effort: "low", max_completion_tokens: 600 }, gptOss),
    { reasoning_effort: "low", max_completion_tokens: 600 },
  );
});

test("solo con modelos gpt-oss: otro modelo no recibe nada", () => {
  assert.deepEqual(
    sanitizarParamsGroq({ reasoning_effort: "low", max_completion_tokens: 600 }, "llama-3.3-70b-versatile"),
    {},
  );
});

test("no deja pasar campos ajenos", () => {
  const r = sanitizarParamsGroq(
    { reasoning_effort: "low", stream: true, tools: [1], max_tokens: 999999, model: "x", messages: [] },
    gptOss,
  );
  assert.deepEqual(r, { reasoning_effort: "low" });
});

test("sin parámetros devuelve vacío", () => {
  assert.deepEqual(sanitizarParamsGroq({}, gptOss), {});
});
