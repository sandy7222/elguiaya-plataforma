-- Dispara push FCM (Edge Function send-push-notification) al insertar campanita.
-- Requiere extension pg_net (habilitada en Supabase).

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.fn_push_notificacion_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
DECLARE
  req_body jsonb;
BEGIN
  req_body := jsonb_build_object(
    'type', 'INSERT',
    'table', 'notificaciones_globales',
    'record', jsonb_build_object(
      'id', NEW.id,
      'receptor_id', NEW.receptor_id,
      'titulo', NEW.titulo,
      'contenido', NEW.contenido,
      'payload', COALESCE(NEW.payload, '{}'::jsonb)
    )
  );

  PERFORM net.http_post(
    url := 'https://ymgsxwfwntbqvguvbhoa.supabase.co/functions/v1/send-push-notification',
    headers := jsonb_build_object('Content-Type', 'application/json'),
    body := req_body
  );

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'fn_push_notificacion_insert: %', SQLERRM;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_notificaciones_globales ON public.notificaciones_globales;

CREATE TRIGGER trg_push_notificaciones_globales
AFTER INSERT ON public.notificaciones_globales
FOR EACH ROW
EXECUTE FUNCTION public.fn_push_notificacion_insert();
