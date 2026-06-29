-- ══════════════════════════════════════════════════════════════════════════════
-- FIX TRIGGER PUSH NOTIFICACIONES GLOBALES
-- ══════════════════════════════════════════════════════════════════════════════
-- Conecta la tabla 'notificaciones_globales' directamente con la Edge Function 'enviar-push-fcm'
-- para que los mensajes lleguen al celular inmediatamente con la app cerrada.

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.fn_push_notificacion_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  fcm_token text;
  req_body jsonb;
BEGIN
  -- 1. Buscar el token FCM activo del usuario receptor
  SELECT token INTO fcm_token
  FROM public.fcm_tokens
  WHERE usuario_id = NEW.receptor_id
  LIMIT 1;

  -- 2. Si el usuario tiene token registrado, disparar la Edge Function enviar-push-fcm
  IF fcm_token IS NOT NULL AND fcm_token <> '' THEN
    req_body := jsonb_build_object(
      'token', fcm_token,
      'titulo', NEW.titulo,
      'cuerpo', NEW.contenido,
      'tipo', COALESCE(NEW.categoria, 'alerta'),
      'sonido', 'default'
    );

    PERFORM net.http_post(
      url := 'https://ymgsxwfwntbqvguvbhoa.supabase.co/functions/v1/enviar-push-fcm',
      headers := jsonb_build_object(
        'Content-Type', 'application/json'
      ),
      body := req_body
    );
  END IF;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'fn_push_notificacion_insert: %', SQLERRM;
    RETURN NEW;
END;
$$;

-- Vincular el trigger a notificaciones_globales
DROP TRIGGER IF EXISTS trg_push_notificaciones_globales ON public.notificaciones_globales;

CREATE TRIGGER trg_push_notificaciones_globales
AFTER INSERT ON public.notificaciones_globales
FOR EACH ROW
EXECUTE FUNCTION public.fn_push_notificacion_insert();
