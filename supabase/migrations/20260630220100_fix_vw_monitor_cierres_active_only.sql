-- El monitor operativo debe listar solo viajes pendientes de cierre, no histórico cerrado.
CREATE OR REPLACE VIEW public.vw_monitor_cierres AS
SELECT
  p.id AS pedido_id,
  p.id,
  p.pescador_id,
  p.capitan_id,
  p.cotizacion_id,
  p.estado,
  p.estado_retorno,
  p.monto_total,
  p.fecha_servicio,
  p.iniciado_at,
  p.finalizado_at,
  p.retorno_confirmado,
  p.viaje_demorado,
  p.cierre_manual_admin,
  p.created_at,
  p.updated_at,
  fn_pedido_fecha_regreso_estimada(p.*) AS fecha_regreso,
  pp.email AS cliente_email,
  COALESCE(pp.nombre, pp.nombre_completo, 'Pescador') AS cliente_nombre,
  COALESCE(pcap.email, 'Capitán') AS capitan_email,
  COALESCE(pcap.nombre, pcap.nombre_completo, 'Capitán') AS capitan_nombre,
  COALESCE(
    cot.descripcion,
    p.contrato_snapshot -> 'viaje' ->> 'descripcion',
    'Viaje sin descripción'
  ) AS descripcion,
  EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0 AS horas_desde_retorno,
  CASE
    WHEN p.estado_retorno = 'cerrado_manual' THEN 'cerrado_manual'
    WHEN p.estado_retorno = 'confirmado' THEN 'confirmado'
    WHEN p.estado_retorno = 'demorado' OR p.viaje_demorado IS TRUE THEN 'demorado'
    WHEN p.estado = 'listo_para_confirmar'
      OR p.estado_retorno = 'listo_para_confirmar' THEN 'listo_confirmar'
    WHEN p.estado = 'en_curso'
      AND fn_pedido_fecha_regreso_estimada(p.*) > NOW() THEN 'en_vuelo'
    WHEN p.estado = 'en_curso'
      AND fn_pedido_fecha_regreso_estimada(p.*) <= NOW() THEN 'reciente_llegada'
    ELSE 'desconocido'
  END AS estado_actual,
  CASE
    WHEN p.viaje_demorado IS TRUE
      OR EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0 >= 24 THEN 'critica'
    WHEN p.estado_retorno = 'demorado'
      OR EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0 >= 12 THEN 'alta'
    WHEN EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0 >= 6 THEN 'media'
    ELSE 'normal'
  END AS nivel_alerta
FROM public.pedidos p
LEFT JOIN public.profiles pp ON pp.user_id = p.pescador_id
LEFT JOIN public.profiles pcap ON pcap.user_id = p.capitan_id
LEFT JOIN public.cotizaciones cot ON cot.id = p.cotizacion_id
WHERE fn_pedido_fecha_regreso_estimada(p.*) IS NOT NULL
  AND p.estado IN ('en_curso', 'listo_para_confirmar')
  AND p.retorno_confirmado IS FALSE
  AND p.estado_retorno NOT IN ('confirmado', 'cerrado_manual');

GRANT SELECT ON public.vw_monitor_cierres TO authenticated;
GRANT SELECT ON public.vw_monitor_cierres TO service_role;
