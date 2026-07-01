-- Monitor de cierres: columnas en pedidos, vista admin, vigilancia y RPCs
-- Adaptado al esquema remoto (pescador_id, monto_total, notificaciones_globales, billetera).

-- ─── Columnas de cierre en pedidos ───────────────────────────────────────────
ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS fecha_regreso TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS estado_retorno VARCHAR(20) DEFAULT 'pendiente',
  ADD COLUMN IF NOT EXISTS retorno_confirmado BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS retorno_confirmado_por UUID,
  ADD COLUMN IF NOT EXISTS retorno_confirmado_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS viaje_demorado BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS alerta_demora_enviada BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cierre_manual_admin BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS cierre_manual_por UUID,
  ADD COLUMN IF NOT EXISTS cierre_manual_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS admin_observaciones TEXT;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_estado_retorno'
  ) THEN
    ALTER TABLE public.pedidos
      ADD CONSTRAINT chk_estado_retorno
      CHECK (estado_retorno IN (
        'pendiente', 'listo_para_confirmar', 'confirmado', 'demorado', 'cerrado_manual'
      ));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_pedidos_fecha_regreso ON public.pedidos (fecha_regreso);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado_retorno ON public.pedidos (estado_retorno);
CREATE INDEX IF NOT EXISTS idx_pedidos_retorno_confirmado ON public.pedidos (retorno_confirmado);
CREATE INDEX IF NOT EXISTS idx_pedidos_viaje_demorado ON public.pedidos (viaje_demorado);
CREATE INDEX IF NOT EXISTS idx_pedidos_cierre_manual_admin ON public.pedidos (cierre_manual_admin);

-- ─── Derivar fecha_regreso desde cotización / ciclo de viaje ─────────────────
CREATE OR REPLACE FUNCTION public.fn_pedido_fecha_regreso_estimada(p_pedido public.pedidos)
RETURNS TIMESTAMPTZ
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_cot RECORD;
  v_fecha TIMESTAMPTZ;
BEGIN
  IF p_pedido.fecha_regreso IS NOT NULL THEN
    RETURN p_pedido.fecha_regreso;
  END IF;

  IF p_pedido.finalizado_at IS NOT NULL THEN
    RETURN p_pedido.finalizado_at;
  END IF;

  IF p_pedido.cotizacion_id IS NOT NULL THEN
    SELECT fecha_vuelta, hora_encuentro
    INTO v_cot
    FROM cotizaciones
    WHERE id = p_pedido.cotizacion_id;

    IF v_cot.fecha_vuelta IS NOT NULL THEN
      v_fecha := v_cot.fecha_vuelta::date::timestamptz
        + COALESCE(v_cot.hora_encuentro, TIME '18:00');
      RETURN v_fecha;
    END IF;
  END IF;

  RETURN p_pedido.fecha_servicio;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_pedido_cierre_campos()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_fecha TIMESTAMPTZ;
BEGIN
  v_fecha := fn_pedido_fecha_regreso_estimada(NEW);

  IF NEW.estado = 'en_curso' AND NEW.fecha_regreso IS NULL AND v_fecha IS NOT NULL THEN
    NEW.fecha_regreso := v_fecha;
  END IF;

  IF NEW.estado = 'listo_para_confirmar' THEN
    IF NEW.finalizado_at IS NOT NULL AND NEW.fecha_regreso IS NULL THEN
      NEW.fecha_regreso := NEW.finalizado_at;
    END IF;
    IF NEW.estado_retorno = 'pendiente' THEN
      NEW.estado_retorno := 'listo_para_confirmar';
    END IF;
  END IF;

  IF NEW.estado = 'cerrado' AND NEW.retorno_confirmado IS TRUE
     AND NEW.estado_retorno NOT IN ('confirmado', 'cerrado_manual') THEN
    NEW.estado_retorno := 'confirmado';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_pedido_cierre_campos ON public.pedidos;
CREATE TRIGGER trg_pedido_cierre_campos
  BEFORE INSERT OR UPDATE ON public.pedidos
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_pedido_cierre_campos();

-- Backfill suave para viajes activos / pendientes de confirmación
UPDATE public.pedidos p
SET
  fecha_regreso = COALESCE(p.fecha_regreso, p.finalizado_at, fn_pedido_fecha_regreso_estimada(p.*)),
  estado_retorno = CASE
    WHEN p.estado = 'listo_para_confirmar' AND p.estado_retorno = 'pendiente'
      THEN 'listo_para_confirmar'
    ELSE p.estado_retorno
  END,
  updated_at = NOW()
WHERE p.estado IN ('en_curso', 'listo_para_confirmar')
  AND (p.fecha_regreso IS NULL OR p.estado_retorno = 'pendiente');

-- ─── Vista del monitor admin ─────────────────────────────────────────────────
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
    WHEN p.estado_retorno = 'confirmado' OR p.estado = 'cerrado' THEN 'confirmado'
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
  AND p.estado IN ('en_curso', 'listo_para_confirmar', 'cerrado', 'cancelado');

GRANT SELECT ON public.vw_monitor_cierres TO authenticated;
GRANT SELECT ON public.vw_monitor_cierres TO service_role;

-- ─── Vigilancia automática de cierres ────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.vigilancia_cierre_operaciones()
RETURNS TABLE (
  pedidos_procesados INTEGER,
  notificaciones_enviadas INTEGER,
  alertas_demora_creadas INTEGER,
  detalles_procesamiento JSONB
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedidos_procesados INTEGER := 0;
  v_notificaciones INTEGER := 0;
  v_alertas INTEGER := 0;
  v_detalles JSONB := '[]'::JSONB;
  v_pedido RECORD;
  v_horas NUMERIC;
  v_ahora TIMESTAMPTZ := NOW();
  v_fecha_regreso TIMESTAMPTZ;
BEGIN
  FOR v_pedido IN
    SELECT
      p.*,
      COALESCE(pr.nombre, pr.nombre_completo, pr.email, 'Pescador') AS pescador_nombre
    FROM pedidos p
    LEFT JOIN profiles pr ON pr.user_id = p.pescador_id
    WHERE p.estado IN ('en_curso', 'listo_para_confirmar')
      AND p.estado_retorno <> 'cerrado_manual'
      AND p.retorno_confirmado IS FALSE
      AND fn_pedido_fecha_regreso_estimada(p.*) IS NOT NULL
  LOOP
    v_pedidos_procesados := v_pedidos_procesados + 1;
    v_fecha_regreso := fn_pedido_fecha_regreso_estimada(v_pedido.*);
    v_horas := EXTRACT(EPOCH FROM (v_ahora - v_fecha_regreso)) / 3600.0;

    IF v_horas >= 2
       AND v_pedido.estado_retorno = 'pendiente'
       AND v_pedido.estado IN ('en_curso', 'listo_para_confirmar') THEN

      UPDATE pedidos
      SET
        estado_retorno = 'listo_para_confirmar',
        fecha_regreso = COALESCE(fecha_regreso, v_fecha_regreso),
        updated_at = v_ahora
      WHERE id = v_pedido.id;

      IF v_pedido.pescador_id IS NOT NULL THEN
        INSERT INTO notificaciones_globales (
          receptor_id, tipo_actor, categoria, prioridad,
          titulo, contenido, leido, payload, created_at
        ) VALUES (
          v_pedido.pescador_id,
          'sistema',
          'logistica',
          'informativa',
          '¡Viaje completado!',
          'Confirmá tu regreso para liberar el pago al capitán.',
          FALSE,
          jsonb_build_object(
            'pedido_id', v_pedido.id,
            'tipo', 'retorno_listo_confirmar',
            'fecha_regreso', v_fecha_regreso,
            'horas_desde_retorno', v_horas,
            'monto', v_pedido.monto_total,
            'accion_requerida', 'confirmar_retorno'
          ),
          v_ahora
        );
        v_notificaciones := v_notificaciones + 1;
      END IF;

      v_detalles := v_detalles || jsonb_build_object(
        'pedido_id', v_pedido.id,
        'accion', 'notificacion_enviada',
        'horas_desde_retorno', v_horas,
        'timestamp', v_ahora
      );

    ELSIF v_horas >= 12
      AND v_pedido.estado_retorno IN ('pendiente', 'listo_para_confirmar')
      AND v_pedido.viaje_demorado IS FALSE THEN

      UPDATE pedidos
      SET
        estado_retorno = 'demorado',
        viaje_demorado = TRUE,
        alerta_demora_enviada = TRUE,
        updated_at = v_ahora
      WHERE id = v_pedido.id;

      v_alertas := v_alertas + 1;
      v_detalles := v_detalles || jsonb_build_object(
        'pedido_id', v_pedido.id,
        'accion', 'alerta_demora_creada',
        'horas_demora', v_horas,
        'prioridad', 'alta',
        'timestamp', v_ahora
      );

    ELSIF v_horas >= 24 AND v_pedido.viaje_demorado IS TRUE THEN
      v_detalles := v_detalles || jsonb_build_object(
        'pedido_id', v_pedido.id,
        'accion', 'alerta_critica',
        'horas_demora', v_horas,
        'prioridad', 'critica',
        'timestamp', v_ahora
      );
    END IF;
  END LOOP;

  RETURN QUERY
  SELECT v_pedidos_procesados, v_notificaciones, v_alertas, v_detalles;
END;
$$;

CREATE OR REPLACE FUNCTION public.ejecutar_vigilancia_cierres()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM vigilancia_cierre_operaciones();
END;
$$;

-- ─── Confirmar retorno (pescador) + acreditación billetera ───────────────────
CREATE OR REPLACE FUNCTION public.confirmar_retorno_y_liberar_pago(
  p_pedido_id UUID,
  p_cliente_id UUID
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  pedido_id UUID,
  nuevo_estado VARCHAR,
  monto_liberado NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedido RECORD;
  v_acred RECORD;
  v_ahora TIMESTAMPTZ := NOW();
BEGIN
  SELECT * INTO v_pedido FROM pedidos WHERE id = p_pedido_id;

  IF v_pedido IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL::UUID, NULL::VARCHAR, 0::NUMERIC;
    RETURN;
  END IF;

  IF v_pedido.pescador_id IS DISTINCT FROM p_cliente_id THEN
    RETURN QUERY SELECT FALSE, 'No tenés permiso para confirmar este pedido', NULL::UUID, NULL::VARCHAR, 0::NUMERIC;
    RETURN;
  END IF;

  IF v_pedido.estado NOT IN ('en_curso', 'listo_para_confirmar') THEN
    RETURN QUERY SELECT FALSE, 'El pedido no está pendiente de confirmación', NULL::UUID, NULL::VARCHAR, 0::NUMERIC;
    RETURN;
  END IF;

  IF v_pedido.retorno_confirmado IS TRUE THEN
    RETURN QUERY SELECT FALSE, 'El retorno ya fue confirmado', NULL::UUID, NULL::VARCHAR, 0::NUMERIC;
    RETURN;
  END IF;

  UPDATE pedidos
  SET
    estado_retorno = 'confirmado',
    retorno_confirmado = TRUE,
    retorno_confirmado_por = p_cliente_id,
    retorno_confirmado_at = v_ahora,
    estado = 'cerrado',
    cerrado_at = COALESCE(cerrado_at, v_ahora),
    updated_at = v_ahora
  WHERE id = p_pedido_id;

  SELECT * INTO v_acred
  FROM acreditar_billetera_viaje_cerrado(p_pedido_id, v_pedido.capitan_id);

  IF v_pedido.capitan_id IS NOT NULL THEN
    INSERT INTO notificaciones_globales (
      receptor_id, tipo_actor, categoria, prioridad,
      titulo, contenido, leido, payload, created_at
    ) VALUES (
      v_pedido.capitan_id,
      'sistema',
      'comercial',
      'informativa',
      '¡Pago en proceso!',
      'El pescador confirmó el regreso. Tu ganancia quedó registrada en la billetera.',
      FALSE,
      jsonb_build_object(
        'pedido_id', p_pedido_id,
        'tipo', 'pago_liberado',
        'monto', COALESCE(v_acred.monto_neto, 0)
      ),
      v_ahora
    );
  END IF;

  INSERT INTO logs_sistema (tipo, descripcion, user_id, pedido_id, datos_adicionales, created_at)
  VALUES (
    'retorno_confirmado_pago_liberado',
    'Pescador confirmó retorno y viaje cerrado',
    p_cliente_id,
    p_pedido_id,
    jsonb_build_object(
      'monto_liberado', COALESCE(v_acred.monto_neto, 0),
      'capitan_id', v_pedido.capitan_id,
      'confirmado_at', v_ahora
    ),
    v_ahora
  );

  RETURN QUERY SELECT
    COALESCE(v_acred.exito, TRUE),
    COALESCE(v_acred.mensaje, 'Retorno confirmado'),
    p_pedido_id,
    'cerrado'::VARCHAR,
    COALESCE(v_acred.monto_neto, 0::NUMERIC);
END;
$$;

-- ─── Cierre manual admin (billetera) ───────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cierre_manual_admin(
  p_pedido_id UUID,
  p_admin_id UUID,
  p_observaciones TEXT DEFAULT NULL,
  p_liberar_pago BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  pedido_id UUID,
  nuevo_estado VARCHAR,
  monto_afectado NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedido RECORD;
  v_monto_afectado NUMERIC := 0;
  v_hora TIMESTAMPTZ := NOW();
  v_acred RECORD;
BEGIN
  SELECT * INTO v_pedido FROM pedidos WHERE id = p_pedido_id;

  IF v_pedido IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL::UUID, NULL::VARCHAR, 0::NUMERIC;
    RETURN;
  END IF;

  IF p_liberar_pago THEN
    UPDATE pedidos SET
      estado = 'cerrado',
      cerrado_at = COALESCE(cerrado_at, v_hora),
      estado_retorno = 'cerrado_manual',
      cierre_manual_admin = TRUE,
      cierre_manual_por = p_admin_id,
      cierre_manual_at = v_hora,
      admin_observaciones = p_observaciones,
      updated_at = v_hora
    WHERE id = p_pedido_id;

    SELECT * INTO v_acred
    FROM acreditar_billetera_viaje_cerrado(p_pedido_id, v_pedido.capitan_id);

    v_monto_afectado := COALESCE(v_acred.monto_neto, 0);
  ELSE
    UPDATE pedidos SET
      estado = 'cancelado',
      estado_retorno = 'cerrado_manual',
      cierre_manual_admin = TRUE,
      cierre_manual_por = p_admin_id,
      cierre_manual_at = v_hora,
      admin_observaciones = p_observaciones,
      updated_at = v_hora
    WHERE id = p_pedido_id;
  END IF;

  INSERT INTO logs_sistema (tipo, descripcion, user_id, pedido_id, datos_adicionales, created_at)
  VALUES (
    'cierre_manual_admin',
    'Administrador realizó cierre manual',
    p_admin_id,
    p_pedido_id,
    jsonb_build_object(
      'liberar_pago', p_liberar_pago,
      'monto_afectado', v_monto_afectado,
      'observaciones', p_observaciones
    ),
    v_hora
  );

  RETURN QUERY SELECT
    TRUE,
    CASE WHEN p_liberar_pago THEN COALESCE(v_acred.mensaje, 'Cierre con acreditación')
         ELSE 'Pedido cancelado' END,
    p_pedido_id,
    CASE WHEN p_liberar_pago THEN 'cerrado'::VARCHAR ELSE 'cancelado'::VARCHAR END,
    v_monto_afectado;
END;
$$;

-- ─── Consultas auxiliares ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_viajes_listos_confirmar_retorno(p_cliente_id UUID)
RETURNS TABLE (
  pedido_id UUID,
  descripcion TEXT,
  monto_total NUMERIC,
  fecha_regreso TIMESTAMPTZ,
  horas_desde_retorno NUMERIC,
  estado_retorno VARCHAR,
  capitan_nombre VARCHAR,
  urgencia VARCHAR
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.id,
    COALESCE(cot.descripcion, p.contrato_snapshot -> 'viaje' ->> 'descripcion', 'Viaje')::TEXT,
    p.monto_total,
    fn_pedido_fecha_regreso_estimada(p.*),
    EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0,
    p.estado_retorno::VARCHAR,
    COALESCE(pcap.nombre, pcap.nombre_completo, pcap.email, 'Capitán')::VARCHAR,
    CASE
      WHEN EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0 >= 24 THEN 'critica'
      WHEN EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0 >= 12 THEN 'alta'
      WHEN EXTRACT(EPOCH FROM (NOW() - fn_pedido_fecha_regreso_estimada(p.*))) / 3600.0 >= 6 THEN 'media'
      ELSE 'baja'
    END::VARCHAR
  FROM pedidos p
  LEFT JOIN cotizaciones cot ON cot.id = p.cotizacion_id
  LEFT JOIN profiles pcap ON pcap.user_id = p.capitan_id
  WHERE p.pescador_id = p_cliente_id
    AND p.estado IN ('en_curso', 'listo_para_confirmar')
    AND fn_pedido_fecha_regreso_estimada(p.*) IS NOT NULL
    AND p.estado_retorno IN ('listo_para_confirmar', 'demorado')
    AND p.retorno_confirmado IS FALSE
  ORDER BY fn_pedido_fecha_regreso_estimada(p.*) ASC;
END;
$$;

CREATE OR REPLACE FUNCTION public.verificar_viaje_listo_confirmar_retorno(p_pedido_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedido RECORD;
  v_horas NUMERIC;
BEGIN
  SELECT * INTO v_pedido FROM pedidos WHERE id = p_pedido_id;

  IF v_pedido IS NULL THEN
    RETURN FALSE;
  END IF;

  v_horas := EXTRACT(EPOCH FROM (
    NOW() - fn_pedido_fecha_regreso_estimada(v_pedido.*)
  )) / 3600.0;

  RETURN v_horas >= 2
    AND v_pedido.estado IN ('en_curso', 'listo_para_confirmar')
    AND v_pedido.retorno_confirmado IS FALSE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.vigilancia_cierre_operaciones() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ejecutar_vigilancia_cierres() TO authenticated;
GRANT EXECUTE ON FUNCTION public.confirmar_retorno_y_liberar_pago(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cierre_manual_admin(UUID, UUID, TEXT, BOOLEAN) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_viajes_listos_confirmar_retorno(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.verificar_viaje_listo_confirmar_retorno(UUID) TO authenticated;

-- Cron horario (si pg_cron está disponible)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'vigilancia-cierres-viajes') THEN
      PERFORM cron.schedule(
        'vigilancia-cierres-viajes',
        '*/15 * * * *',
        'SELECT public.vigilancia_cierre_operaciones()'
      );
    END IF;
  END IF;
END $$;
