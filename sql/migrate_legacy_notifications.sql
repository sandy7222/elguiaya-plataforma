-- ══════════════════════════════════════════════════════════════════════════════
-- MIGRACIÓN DE NOTIFICACIONES HISTÓRICAS
-- ══════════════════════════════════════════════════════════════════════════════
-- Este script copia todas las notificaciones de la tabla legada 'notificaciones'
-- a la nueva tabla 'notificaciones_globales' para que los capitanes y pescadores
-- recuperen su historial de alertas y no vean el centro de notificaciones vacío.

INSERT INTO public.notificaciones_globales (
  id,
  created_at,
  emisor_id,
  receptor_id,
  tipo_actor,
  categoria,
  prioridad,
  titulo,
  contenido,
  leido,
  payload
)
SELECT 
  id,
  created_at,
  NULL as emisor_id,
  usuario_id as receptor_id,
  'sistema' as tipo_actor,
  CASE 
    WHEN tipo IN ('viaje', 'cotizacion', 'pago') OR tipo LIKE 'viaje_%' OR tipo LIKE 'presupuesto_%' OR tipo LIKE 'pago_%' THEN 'comercial'
    WHEN tipo IN ('fraude', 'disputa') THEN 'seguridad'
    WHEN tipo = 'sistema' THEN 'logistica'
    ELSE 'informativa'
  END as categoria,
  'informativa' as prioridad,
  titulo,
  mensaje as contenido,
  leida as leido,
  COALESCE(metadata, '{}'::jsonb) as payload
FROM public.notificaciones
ON CONFLICT (id) DO NOTHING;

-- Notificar recarga del esquema
notify pgrst, 'reload schema';
