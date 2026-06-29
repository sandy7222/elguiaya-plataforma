// ═══════════════════════════════════════════════════════════════════════════
// Edge Function: enviar-push-fcm
// Recibe { token, titulo, cuerpo, tipo, sonido } y lo envía via FCM HTTP v1
// ═══════════════════════════════════════════════════════════════════════════
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

// ── Tipos ─────────────────────────────────────────────────────────────────
interface PushPayload {
  token: string;
  titulo: string;
  cuerpo?: string;
  tipo?: string;
  sonido?: string;
}

// ── Helpers OAuth2 para FCM v1 ────────────────────────────────────────────
async function obtenerAccessToken(serviceAccount: Record<string, string>): Promise<string> {
  const jwtHeader = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const now = Math.floor(Date.now() / 1000);
  const jwtClaim = btoa(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now,
  })).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  // Importar clave privada RSA
  const privateKey = serviceAccount.private_key
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\n/g, "");

  const keyData = Uint8Array.from(atob(privateKey), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyData,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signingInput = `${jwtHeader}.${jwtClaim}`;
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput)
  );

  const jwtSignature = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");

  const jwt = `${signingInput}.${jwtSignature}`;

  // Intercambiar JWT por access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    throw new Error(`OAuth2 falló: ${JSON.stringify(tokenData)}`);
  }
  return tokenData.access_token;
}

// ── Handler principal ─────────────────────────────────────────────────────
serve(async (req: Request) => {
  // CORS para Supabase
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, content-type",
      },
    });
  }

  try {
    // Leer service account desde los secretos de Supabase
    const serviceAccountRaw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountRaw) {
      throw new Error("FIREBASE_SERVICE_ACCOUNT no configurado en los secretos de Supabase.");
    }
    const serviceAccount = JSON.parse(serviceAccountRaw);
    const projectId: string = serviceAccount.project_id;

    // Parsear payload de la request
    const body: PushPayload = await req.json();
    const { token, titulo, cuerpo, tipo = "alerta", sonido = "default" } = body;

    if (!token || !titulo) {
      return new Response(JSON.stringify({ error: "token y titulo son requeridos" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Obtener access token OAuth2
    const accessToken = await obtenerAccessToken(serviceAccount);

    // Construir mensaje FCM v1
    // El sonido en background lo controla el canal Android (elguia_alertas_v4)
    const fcmMessage = {
      message: {
        token: token,
        notification: {
          title: titulo,
          body: cuerpo ?? "",
        },
        android: {
          priority: "high",
          notification: {
            channel_id: "elguia_alertas_v4",  // ← Canal correcto registrado en la app
            sound: "elguia_alertas",            // ← Sonido WAV en res/raw/
            notification_priority: "PRIORITY_MAX",
            visibility: "PUBLIC",
            icon: "ic_launcher",                // ← Usar icono estándar del lanzador para compatibilidad garantizada en Android
            color: "#1B4F72",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
        },
        data: {
          tipo: tipo,
          sonido: sonido,
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
      },
    };

    // Enviar a FCM HTTP v1
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
    const fcmRes = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(fcmMessage),
    });

    const fcmData = await fcmRes.json();

    if (!fcmRes.ok) {
      console.error(`[FCM] Error al enviar push:`, JSON.stringify(fcmData));
      return new Response(JSON.stringify({ error: "FCM rechazó el mensaje", detalle: fcmData }), {
        status: 502,
        headers: { "Content-Type": "application/json" },
      });
    }

    console.log(`[FCM] ✅ Push enviado. MessageID: ${fcmData.name}`);
    return new Response(JSON.stringify({ ok: true, messageId: fcmData.name }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });

  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[FCM] Error inesperado:", message);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
