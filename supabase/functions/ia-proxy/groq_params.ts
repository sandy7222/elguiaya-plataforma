// Lista blanca de los parámetros de velocidad que el cliente puede pedir a Groq.
// Solo valen para los modelos gpt-oss (son los que razonan); cualquier otro valor
// o campo se descarta en silencio, no se corrige.

export const reasoningEffortPermitidos = new Set(["low", "medium"]);
export const minMaxCompletionTokens = 64;
export const maxMaxCompletionTokens = 2000;

export function sanitizarParamsGroq(
  input: Record<string, unknown>,
  modeloReal: string,
): { reasoning_effort?: string; max_completion_tokens?: number } {
  const salida: { reasoning_effort?: string; max_completion_tokens?: number } = {};
  if (!modeloReal.startsWith("openai/gpt-oss")) return salida;

  const esfuerzo = input.reasoning_effort;
  if (typeof esfuerzo === "string" && reasoningEffortPermitidos.has(esfuerzo)) {
    salida.reasoning_effort = esfuerzo;
  }

  const tope = input.max_completion_tokens;
  if (
    typeof tope === "number" &&
    Number.isInteger(tope) &&
    tope >= minMaxCompletionTokens &&
    tope <= maxMaxCompletionTokens
  ) {
    salida.max_completion_tokens = tope;
  }
  return salida;
}
