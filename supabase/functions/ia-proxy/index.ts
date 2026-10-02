// Proxy autenticado para proveedores de IA. No registra prompts ni secretos.

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const maxRequestBytes = 256 * 1024;
const maxRequestsPerWindow = 30;
const windowMs = 10 * 60 * 1000;
const buckets = new Map<string, number[]>();

const groqModelAliases: Record<string, string> = {
  "llama-3.3-70b-versatile": "openai/gpt-oss-120b",
};
const allowedGroqModels = new Set(["openai/gpt-oss-120b", "llama-3.3-70b-versatile"]);
const allowedGeminiModels = new Set(["gemini-2.5-flash"]);

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function allowedRequest(req: Request) {
  const key = req.headers.get("authorization") ?? "anonymous";
  const now = Date.now();
  const recent = (buckets.get(key) ?? []).filter((time) => now - time < windowMs);
  if (recent.length >= maxRequestsPerWindow) return false;
  recent.push(now);
  buckets.set(key, recent);
  return true;
}

async function providerResponse(response: Response) {
  const text = await response.text();
  let body: unknown = { error: { message: "Respuesta no JSON del proveedor" } };
  try {
    body = JSON.parse(text);
  } catch {
    // No devolvemos ni registramos texto inesperado del proveedor.
  }
  return json({ status: response.status, body });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST") return json({ error: "Method Not Allowed" }, 405);
  if (!allowedRequest(req)) return json({ error: "Límite temporal alcanzado" }, 429);

  const contentLength = Number(req.headers.get("content-length") ?? "0");
  if (contentLength > maxRequestBytes) return json({ error: "Solicitud demasiado grande" }, 413);

  let input: Record<string, unknown>;
  try {
    input = await req.json();
  } catch {
    return json({ error: "JSON inválido" }, 400);
  }
  if (JSON.stringify(input).length > maxRequestBytes) return json({ error: "Solicitud demasiado grande" }, 413);

  const provider = input.provider;
  const model = input.model;
  if (typeof model !== "string") return json({ error: "Modelo inválido" }, 400);

  if (provider === "groq") {
    if (!allowedGroqModels.has(model) || !Array.isArray(input.messages)) {
      return json({ error: "Solicitud Groq inválida" }, 400);
    }
    const apiKey = Deno.env.get("GROQ_API_KEY_LIBRERIA3");
    if (!apiKey) return json({ error: "Proveedor no configurado" }, 503);
    const modeloReal = groqModelAliases[model] ?? model;
    const response = await fetch("https://api.groq.com/openai/v1/chat/completions", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: modeloReal,
        messages: input.messages,
        temperature: typeof input.temperature === "number" ? input.temperature : 0.7,
      }),
    });
    console.log("[ia-proxy] groq_status:", response.status);
    return providerResponse(response);
  }

  if (provider === "gemini") {
    if (!allowedGeminiModels.has(model) || !input.body || typeof input.body !== "object") {
      return json({ error: "Solicitud Gemini inválida" }, 400);
    }
    const apiKey = Deno.env.get("GEMINI_API_KEY");
    if (!apiKey) return json({ error: "Proveedor no configurado" }, 503);
    const response = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent?key=${encodeURIComponent(apiKey)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(input.body),
      },
    );
    return providerResponse(response);
  }

  return json({ error: "Proveedor inválido" }, 400);
});
