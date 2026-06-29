-- Retiros capitán → admin: completar / rechazar transferencias (billetera virtual)

-- Columnas de auditoría en liquidaciones (compat legacy)
ALTER TABLE public.liquidaciones
  ADD COLUMN IF NOT EXISTS comprobante TEXT,
  ADD COLUMN IF NOT EXISTS procesado_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cbu TEXT,
  ADD COLUMN IF NOT EXISTS alias TEXT,
  ADD COLUMN IF NOT EXISTS banco TEXT,
  ADD COLUMN IF NOT EXISTS descripcion TEXT;

-- ─── Admin confirma retiro manual (MP fuera de la app) ────────────────────────
CREATE OR REPLACE FUNCTION public.completar_retiro_billetera(
  p_liquidacion_id UUID,
  p_admin_id UUID,
  p_monto_depositado NUMERIC,
  p_comprobante TEXT DEFAULT NULL
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  capitan_id UUID,
  monto NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_liq RECORD;
  v_capitan_id UUID;
  v_monto NUMERIC(12,2);
BEGIN
  SELECT * INTO v_liq
  FROM liquidaciones
  WHERE id = p_liquidacion_id
  FOR UPDATE;

  IF v_liq IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Liquidación no encontrada', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  IF v_liq.estado NOT IN ('solicitado', 'procesando', 'pendiente') THEN
    RETURN QUERY SELECT FALSE, 'La liquidación no está pendiente de pago', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  v_capitan_id := v_liq.capitan_id;
  v_monto := COALESCE(v_liq.monto, 0);

  IF p_monto_depositado IS NULL OR p_monto_depositado <= 0 THEN
    RETURN QUERY SELECT FALSE, 'Monto depositado inválido', v_capitan_id, 0::NUMERIC;
    RETURN;
  END IF;

  IF ROUND(p_monto_depositado, 2) <> ROUND(v_monto, 2) THEN
    RETURN QUERY SELECT FALSE, 'El monto depositado debe coincidir con el solicitado', v_capitan_id, v_monto;
    RETURN;
  END IF;

  UPDATE liquidaciones SET
    estado       = 'completado',
    procesado_at = NOW(),
    comprobante  = NULLIF(trim(p_comprobante), ''),
    descripcion  = COALESCE(descripcion, 'Transferencia solicitada por el capitán')
                   || ' — confirmada por admin'
  WHERE id = p_liquidacion_id;

  UPDATE billetera_capitanes SET
    saldo_retenido = GREATEST(0, saldo_retenido - v_monto),
    updated_at     = NOW()
  WHERE capitan_id = v_capitan_id;

  UPDATE movimientos_billetera SET
    tipo        = 'retiro_completado',
    estado      = 'completado',
    liberado_at = NOW(),
    descripcion = 'Transferencia completada'
                  || CASE WHEN p_comprobante IS NOT NULL AND trim(p_comprobante) <> ''
                     THEN ' — ref: ' || trim(p_comprobante) ELSE '' END
  WHERE liquidacion_id = p_liquidacion_id
    AND tipo = 'retiro_solicitado';

  BEGIN
    INSERT INTO historial_pagos (admin_id, usuario_id, monto, fecha, cbu_destino, created_at)
    VALUES (
      p_admin_id,
      v_capitan_id,
      v_monto,
      NOW(),
      COALESCE(v_liq.cbu, ''),
      NOW()
    );
  EXCEPTION WHEN undefined_table THEN
    INSERT INTO logs_sistema (tipo, descripcion, user_id, datos_adicionales, created_at)
    VALUES (
      'retiro_completado',
      'Admin confirmó retiro de $' || v_monto::TEXT,
      v_capitan_id,
      jsonb_build_object(
        'admin_id', p_admin_id,
        'liquidacion_id', p_liquidacion_id,
        'monto', v_monto,
        'comprobante', p_comprobante
      ),
      NOW()
    );
  END;

  RETURN QUERY SELECT TRUE, 'Retiro completado', v_capitan_id, v_monto;
END;
$$;

-- ─── Admin rechaza retiro: devuelve saldo a disponible ─────────────────────────
CREATE OR REPLACE FUNCTION public.rechazar_retiro_billetera(
  p_liquidacion_id UUID,
  p_admin_id UUID,
  p_motivo TEXT DEFAULT NULL
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  capitan_id UUID,
  monto NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_liq RECORD;
  v_capitan_id UUID;
  v_monto NUMERIC(12,2);
BEGIN
  SELECT * INTO v_liq
  FROM liquidaciones
  WHERE id = p_liquidacion_id
  FOR UPDATE;

  IF v_liq IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Liquidación no encontrada', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  IF v_liq.estado NOT IN ('solicitado', 'procesando', 'pendiente') THEN
    RETURN QUERY SELECT FALSE, 'La liquidación no puede rechazarse en este estado', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  v_capitan_id := v_liq.capitan_id;
  v_monto := COALESCE(v_liq.monto, 0);

  UPDATE liquidaciones SET
    estado       = 'fallido',
    procesado_at = NOW(),
    descripcion  = COALESCE(descripcion, '')
                   || CASE WHEN p_motivo IS NOT NULL AND trim(p_motivo) <> ''
                      THEN ' — Rechazado: ' || trim(p_motivo) ELSE ' — Rechazado por admin' END
  WHERE id = p_liquidacion_id;

  UPDATE billetera_capitanes SET
    saldo_retenido   = GREATEST(0, saldo_retenido - v_monto),
    saldo_disponible = saldo_disponible + v_monto,
    updated_at       = NOW()
  WHERE capitan_id = v_capitan_id;

  UPDATE movimientos_billetera SET
    tipo        = 'retiro_fallido',
    estado      = 'fallido',
    descripcion = COALESCE(descripcion, 'Retiro rechazado')
                  || CASE WHEN p_motivo IS NOT NULL AND trim(p_motivo) <> ''
                     THEN ' — ' || trim(p_motivo) ELSE '' END
  WHERE liquidacion_id = p_liquidacion_id
    AND tipo = 'retiro_solicitado';

  INSERT INTO logs_sistema (tipo, descripcion, user_id, datos_adicionales, created_at)
  VALUES (
    'retiro_rechazado',
    'Admin rechazó retiro de $' || v_monto::TEXT,
    v_capitan_id,
    jsonb_build_object(
      'admin_id', p_admin_id,
      'liquidacion_id', p_liquidacion_id,
      'monto', v_monto,
      'motivo', p_motivo
    ),
    NOW()
  );

  RETURN QUERY SELECT TRUE, 'Retiro rechazado, saldo devuelto', v_capitan_id, v_monto;
END;
$$;

GRANT EXECUTE ON FUNCTION public.completar_retiro_billetera(UUID, UUID, NUMERIC, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rechazar_retiro_billetera(UUID, UUID, TEXT) TO authenticated;
