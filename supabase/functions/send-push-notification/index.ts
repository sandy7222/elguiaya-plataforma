// supabase/functions/send-push-notification/index.ts
// Envía push FCM (Android) al insertar en notificaciones_globales.
//
// Desplegar:
//   supabase functions deploy send-push-notification --no-verify-jwt
//
// Secretos (Dashboard > Edge Functions > Secrets):
//   FCM_SERVICE_ACCOUNT_JSON — JSON completo de cuenta de servicio Firebase
//
// Database Webhook (Dashboard > Database > Webhooks):
//   Tabla: notificaciones_globales
//   Evento: INSERT
//   URL: https://<project-ref>.supabase.co/functions/v1/send-push-notification
//   Headers: Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleAuth } from "npm:google-auth-library@9";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const FCM_SERVICE_ACCOUNT_JSON = Deno.env.get("FCM_SERVICE_ACCOUNT_JSON") ?? "";

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

const ANDROID_CHANNEL = "elguia_alertas_v4";
const ANDROID_SOUND = "elguia_alertas";
const ANDROID_ICON = "ic_stat_elguia";
const ANDROID_COLOR = "#1B4F72";

// FCM con bloque `notification`: Android muestra banner fuera de la app (como cuando funcionó).
// El canal v4 se crea nativamente al abrir la app, con sonido custom en res/raw/.

interface NotificacionRecord {
  id?: string;
  receptor_id: string;
  titulo: string;
  contenido: string;
  payload?: Record<string, unknown> | null;
}

interface WebhookBody {
  type?: string;
  table?: string;
  record?: NotificacionRecord;
  // Invocación directa (fallback)
  receptor_id?: string;
  titulo?: string;
  contenido?: string;
  payload?: Record<string, unknown> | null;
}

function esTokenSimulado(token: string): boolean {
  // Tokens viejos generados por generarTokenFCMFiel en la app
  return /^f[a-f0-9]{6}:APA91b/i.test(token);
}

async function obtenerAccessTokenFcm(): Promise<{ token: string; projectId: string }> {
  if (!FCM_SERVICE_ACCOUNT_JSON) {
    throw new Error("FCM_SERVICE_ACCOUNT_JSON no configurado");
  }

  const credentials = JSON.parse(FCM_SERVICE_ACCOUNT_JSON);
  const projectId = credentials.project_id as string;
  if (!projectId) {
    throw new Error("project_id ausente en FCM_SERVICE_ACCOUNT_JSON");
  }

  const auth = new GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });

  const client = await auth.getClient();
  const tokenResponse = await client.getAccessToken();
  const token = tokenResponse.token;
  if (!token) {
    throw new Error("No se pudo obtener access token de Google");
  }

  return { token, projectId };
}

async function enviarFcmV1(
  deviceToken: string,
  titulo: string,
  cuerpo: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const { token, projectId } = await obtenerAccessTokenFcm();

  const message = {
    message: {
      token: deviceToken,
      notification: {
        title: titulo,
        body: cuerpo,
      },
      android: {
        priority: "HIGH",
        notification: {
          channel_id: ANDROID_CHANNEL,
          sound: ANDROID_SOUND,
          default_sound: false,
          default_vibrate_timings: true,
          notification_priority: "PRIORITY_MAX",
          visibility: "PUBLIC",
          icon: ANDROID_ICON,
          color: ANDROID_COLOR,
        },
      },
      data: {
        title: titulo,
        body: cuerpo,
        payload: JSON.stringify(payload ?? {}),
        click_action: "FLUTTER_NOTIFICATION_CLICK",
      },
    },
  };

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${token}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    },
  );

  if (!res.ok) {
    const errText = await res.text();
    throw new Error(`FCM v1 error ${res.status}: ${errText}`);
  }
}

function normalizarRecord(body: WebhookBody): NotificacionRecord | null {
  if (body.record?.receptor_id) {
    return body.record;
  }
  if (body.receptor_id && body.titulo) {
    return {
      receptor_id: body.receptor_id,
      titulo: body.titulo,
      contenido: body.contenido ?? "",
      payload: body.payload ?? {},
    };
  }
  return null;
}

serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const body = (await req.json()) as WebhookBody;
    const record = normalizarRecord(body);

    if (!record?.receptor_id) {
      return new Response(JSON.stringify({ ok: false, reason: "sin receptor_id" }), {
        status: 400,
        headers: { "Content-Type": "application/json" },
      });
    }

    const { data: tokenRow, error: tokenError } = await supabase
      .from("fcm_tokens")
      .select("token")
      .eq("usuario_id", record.receptor_id)
      .maybeSingle();

    if (tokenError) {
      throw new Error(`Error leyendo fcm_tokens: ${tokenError.message}`);
    }

    const deviceToken = tokenRow?.token?.toString() ?? "";
    if (!deviceToken || esTokenSimulado(deviceToken)) {
      return new Response(
        JSON.stringify({ ok: false, reason: "sin token FCM real" }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }

    const payload =
      record.payload && typeof record.payload === "object"
        ? record.payload
        : {};

    await enviarFcmV1(
      deviceToken,
      record.titulo ?? "El Guia YA",
      record.contenido ?? "",
      payload as Record<string, unknown>,
    );

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    console.error("send-push-notification:", e);
    return new Response(
      JSON.stringify({ ok: false, error: String(e) }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }
});
