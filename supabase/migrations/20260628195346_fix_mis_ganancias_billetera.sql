-- Reparar Mis Ganancias: unificar lectura/escritura en billetera virtual (10% / 90%)

-- Evitar acreditaciones duplicadas por pedido
CREATE UNIQUE INDEX IF NOT EXISTS idx_movimientos_billetera_pedido_ingreso
  ON movimientos_billetera (pedido_id)
  WHERE pedido_id IS NOT NULL AND tipo = 'ingreso_viaje';

-- ─── Acreditar viaje cerrado (SECURITY DEFINER, bypass RLS) ───────────────────
CREATE OR REPLACE FUNCTION public.acreditar_billetera_viaje_cerrado(
  p_pedido_id UUID,
  p_capitan_id UUID DEFAULT NULL
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  movimiento_id UUID,
  monto_neto NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedido RECORD;
  v_capitan_id UUID;
  v_monto_total NUMERIC(12,2);
  v_comision NUMERIC(12,2);
  v_monto_neto NUMERIC(12,2);
  v_cerrado_at TIMESTAMPTZ;
  v_disponible_desde TIMESTAMPTZ;
  v_mov_id UUID;
BEGIN
  SELECT id, capitan_id, monto_total, cerrado_at, estado
  INTO v_pedido
  FROM pedidos
  WHERE id = p_pedido_id;

  IF v_pedido IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  IF v_pedido.estado NOT IN ('cerrado', 'completado_pendiente_firma', 'completado') THEN
    RETURN QUERY SELECT FALSE, 'Pedido no está cerrado', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  v_capitan_id := COALESCE(p_capitan_id, v_pedido.capitan_id);
  IF v_capitan_id IS NULL OR v_capitan_id <> v_pedido.capitan_id THEN
    RETURN QUERY SELECT FALSE, 'Capitán no coincide con el pedido', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  IF EXISTS (
    SELECT 1 FROM movimientos_billetera
    WHERE pedido_id = p_pedido_id AND tipo = 'ingreso_viaje'
  ) THEN
    RETURN QUERY SELECT TRUE, 'Ya acreditado', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  v_monto_total := COALESCE(v_pedido.monto_total, 0);
  IF v_monto_total <= 0 THEN
    RETURN QUERY SELECT FALSE, 'Monto total inválido', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  v_comision   := ROUND(v_monto_total * 0.10, 2);
  v_monto_neto := v_monto_total - v_comision;
  v_cerrado_at := COALESCE(v_pedido.cerrado_at, NOW());
  v_disponible_desde := v_cerrado_at + INTERVAL '48 hours';

  INSERT INTO movimientos_billetera (
    capitan_id, pedido_id, tipo,
    monto_bruto, comision, monto_neto,
    estado, disponible_desde, descripcion, created_at
  ) VALUES (
    v_capitan_id, p_pedido_id, 'ingreso_viaje',
    v_monto_total, v_comision, v_monto_neto,
    'pendiente', v_disponible_desde,
    'Viaje cerrado — período de disputa 48hs',
    NOW()
  )
  RETURNING id INTO v_mov_id;

  INSERT INTO billetera_capitanes (
    capitan_id, saldo_disponible, saldo_pendiente, saldo_retenido, total_cobrado, updated_at
  ) VALUES (
    v_capitan_id, 0, v_monto_neto, 0, 0, NOW()
  )
  ON CONFLICT (capitan_id) DO UPDATE SET
    saldo_pendiente = billetera_capitanes.saldo_pendiente + EXCLUDED.saldo_pendiente,
    updated_at = NOW();

  RETURN QUERY SELECT TRUE, 'Acreditado en billetera', v_mov_id, v_monto_neto;
END;
$$;

-- ─── Backfill: pedidos cerrados sin movimiento ────────────────────────────────
CREATE OR REPLACE FUNCTION public.backfill_billetera_capitan(p_capitan_id UUID)
RETURNS TABLE (
  pedido_id UUID,
  exito BOOLEAN,
  mensaje TEXT,
  monto_neto NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_pedido RECORD;
  v_result RECORD;
BEGIN
  FOR v_pedido IN
    SELECT p.id
    FROM pedidos p
    WHERE p.capitan_id = p_capitan_id
      AND p.estado IN ('cerrado', 'completado_pendiente_firma', 'completado')
      AND COALESCE(p.monto_total, 0) > 0
      AND NOT EXISTS (
        SELECT 1 FROM movimientos_billetera m
        WHERE m.pedido_id = p.id AND m.tipo = 'ingreso_viaje'
      )
  LOOP
    SELECT * INTO v_result
    FROM acreditar_billetera_viaje_cerrado(v_pedido.id, p_capitan_id);

    pedido_id := v_pedido.id;
    exito := v_result.exito;
    mensaje := v_result.mensaje;
    monto_neto := v_result.monto_neto;
    RETURN NEXT;
  END LOOP;
END;
$$;

-- ─── Solicitar transferencia (SECURITY DEFINER) ───────────────────────────────
CREATE OR REPLACE FUNCTION public.solicitar_transferencia_billetera(
  p_capitan_id UUID,
  p_monto NUMERIC,
  p_cbu TEXT,
  p_alias TEXT DEFAULT NULL,
  p_banco TEXT DEFAULT NULL
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  liquidacion_id UUID
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_cbu TEXT;
  v_saldo NUMERIC(12,2);
  v_liq_id UUID;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_capitan_id THEN
    RETURN QUERY SELECT FALSE, 'No autorizado', NULL::UUID;
    RETURN;
  END IF;

  v_cbu := regexp_replace(COALESCE(p_cbu, ''), '[\s\-]', '', 'g');
  IF length(v_cbu) NOT IN (20, 22) THEN
    RETURN QUERY SELECT FALSE, 'CBU/CVU inválido', NULL::UUID;
    RETURN;
  END IF;

  IF p_monto < 100 THEN
    RETURN QUERY SELECT FALSE, 'Monto mínimo $100', NULL::UUID;
    RETURN;
  END IF;

  SELECT COALESCE(saldo_disponible, 0) INTO v_saldo
  FROM billetera_capitanes
  WHERE capitan_id = p_capitan_id;

  IF v_saldo IS NULL OR p_monto > v_saldo THEN
    RETURN QUERY SELECT FALSE, 'Saldo insuficiente', NULL::UUID;
    RETURN;
  END IF;

  INSERT INTO liquidaciones (
    capitan_id, monto, cbu, alias, banco, estado, descripcion, created_at
  ) VALUES (
    p_capitan_id, p_monto, v_cbu, p_alias, p_banco,
    'solicitado', 'Transferencia solicitada por el capitán', NOW()
  )
  RETURNING id INTO v_liq_id;

  UPDATE billetera_capitanes SET
    saldo_disponible = GREATEST(0, saldo_disponible - p_monto),
    saldo_retenido   = saldo_retenido + p_monto,
    updated_at       = NOW()
  WHERE capitan_id = p_capitan_id;

  INSERT INTO movimientos_billetera (
    capitan_id, tipo, monto_bruto, comision, monto_neto,
    estado, liquidacion_id, descripcion, created_at
  ) VALUES (
    p_capitan_id, 'retiro_solicitado', p_monto, 0, p_monto,
    'procesando', v_liq_id,
    'Transferencia a CBU ' || left(v_cbu, 4) || '...' || right(v_cbu, 4),
    NOW()
  );

  RETURN QUERY SELECT TRUE, 'Solicitud registrada', v_liq_id;
END;
$$;

-- ─── get_saldos_capitan: leer billetera nueva ─────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_saldos_capitan(p_capitan_id UUID)
RETURNS TABLE (
  saldo_a_confirmar NUMERIC,
  saldo_disponible NUMERIC,
  total_viajes INTEGER,
  viajes_pendientes_confirmacion INTEGER,
  ultimo_viaje_confirmado TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  SELECT
    COALESCE(b.saldo_pendiente, 0)::NUMERIC AS saldo_a_confirmar,
    COALESCE(b.saldo_disponible, 0)::NUMERIC AS saldo_disponible,
    (
      SELECT COUNT(*)::INTEGER
      FROM movimientos_billetera m
      WHERE m.capitan_id = p_capitan_id AND m.tipo = 'ingreso_viaje'
    ) AS total_viajes,
    (
      SELECT COUNT(*)::INTEGER
      FROM movimientos_billetera m
      WHERE m.capitan_id = p_capitan_id
        AND m.tipo = 'ingreso_viaje'
        AND m.estado = 'pendiente'
    ) AS viajes_pendientes_confirmacion,
    (
      SELECT MAX(m.liberado_at)
      FROM movimientos_billetera m
      WHERE m.capitan_id = p_capitan_id
        AND m.tipo = 'ingreso_viaje'
        AND m.estado = 'disponible'
    ) AS ultimo_viaje_confirmado
  FROM billetera_capitanes b
  WHERE b.capitan_id = p_capitan_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT 0::NUMERIC, 0::NUMERIC, 0, 0, NULL::TIMESTAMPTZ;
  END IF;
END;
$$;

-- ─── cierre_manual_admin: acreditar billetera en lugar de transacciones viejas ─
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

-- Permisos RPC para clientes autenticados
GRANT EXECUTE ON FUNCTION public.acreditar_billetera_viaje_cerrado(UUID, UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.backfill_billetera_capitan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.solicitar_transferencia_billetera(UUID, NUMERIC, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_saldos_capitan(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.liberar_pendientes_vencidos() TO authenticated;

-- Scheduler 48hs (pg_cron)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
    IF NOT EXISTS (
      SELECT 1 FROM cron.job WHERE jobname = 'liberar-billeteras-48hs'
    ) THEN
      PERFORM cron.schedule(
        'liberar-billeteras-48hs',
        '0 * * * *',
        'SELECT liberar_pendientes_vencidos()'
      );
    END IF;
  END IF;
END $$;

-- Backfill campanita@gmail.com (2 viajes cerrados sin acreditación)
SELECT * FROM backfill_billetera_capitan('1e89e24f-57ef-4f95-aacc-84668456c3a6'::UUID);
