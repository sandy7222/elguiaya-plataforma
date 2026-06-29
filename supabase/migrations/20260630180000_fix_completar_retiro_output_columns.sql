-- Fix definitivo: columnas de salida capitan_id/monto chocan con columnas de tablas
-- en INSERT/UPDATE dentro de PL/pgSQL (error 42702 ambiguous).

DROP FUNCTION IF EXISTS public.completar_retiro_billetera(UUID, UUID, NUMERIC, TEXT, TEXT);
DROP FUNCTION IF EXISTS public.rechazar_retiro_billetera(UUID, UUID, TEXT);

CREATE OR REPLACE FUNCTION public.completar_retiro_billetera(
  p_liquidacion_id UUID,
  p_admin_id UUID,
  p_monto_depositado NUMERIC,
  p_comprobante TEXT,
  p_comprobante_storage_path TEXT
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  ret_capitan_id UUID,
  ret_monto NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_liq RECORD;
  v_capitan_id UUID;
  v_monto NUMERIC(12,2);
  v_cbu TEXT;
BEGIN
  IF NOT public.is_admin_user() THEN
    RETURN QUERY SELECT FALSE, 'No autorizado', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  IF p_comprobante IS NULL OR trim(p_comprobante) = '' THEN
    RETURN QUERY SELECT FALSE, 'El número de comprobante MP es obligatorio', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  IF p_comprobante_storage_path IS NULL OR trim(p_comprobante_storage_path) = '' THEN
    RETURN QUERY SELECT FALSE, 'Debe adjuntar el ticket de transferencia', NULL::UUID, 0::NUMERIC;
    RETURN;
  END IF;

  SELECT * INTO v_liq
  FROM public.liquidaciones
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
  v_cbu := COALESCE(v_liq.cbu, '');

  IF p_monto_depositado IS NULL OR p_monto_depositado <= 0 THEN
    RETURN QUERY SELECT FALSE, 'Monto depositado inválido', v_capitan_id, 0::NUMERIC;
    RETURN;
  END IF;

  IF ROUND(p_monto_depositado, 2) <> ROUND(v_monto, 2) THEN
    RETURN QUERY SELECT FALSE, 'El monto depositado debe coincidir con el solicitado', v_capitan_id, v_monto;
    RETURN;
  END IF;

  UPDATE public.liquidaciones SET
    estado                    = 'completado',
    procesado_at              = NOW(),
    comprobante               = trim(p_comprobante),
    comprobante_storage_path  = trim(p_comprobante_storage_path),
    admin_procesador_id       = p_admin_id,
    descripcion               = COALESCE(descripcion, 'Transferencia solicitada por el capitán')
                                || ' — confirmada por admin'
  WHERE id = p_liquidacion_id;

  UPDATE public.billetera_capitanes bc SET
    saldo_retenido = GREATEST(0, bc.saldo_retenido - v_monto),
    updated_at     = NOW()
  WHERE bc.capitan_id = v_capitan_id;

  UPDATE public.movimientos_billetera mb SET
    tipo        = 'retiro_completado',
    estado      = 'completado',
    liberado_at = NOW(),
    descripcion = 'Transferencia completada — ref: ' || trim(p_comprobante)
  WHERE mb.liquidacion_id = p_liquidacion_id
    AND mb.tipo = 'retiro_solicitado';

  INSERT INTO public.libro_transferencias (
    liquidacion_id,
    capitan_id,
    admin_id,
    monto,
    cbu_destino,
    numero_comprobante,
    comprobante_storage_path,
    procesado_at
  )
  SELECT
    p_liquidacion_id,
    v_capitan_id,
    p_admin_id,
    v_monto,
    v_cbu,
    trim(p_comprobante),
    trim(p_comprobante_storage_path),
    NOW();

  INSERT INTO public.logs_sistema (tipo, descripcion, user_id, datos_adicionales, created_at)
  VALUES (
    'retiro_completado',
    'Admin confirmó retiro de $' || v_monto::TEXT || ' — ref: ' || trim(p_comprobante),
    v_capitan_id,
    jsonb_build_object(
      'admin_id', p_admin_id,
      'liquidacion_id', p_liquidacion_id,
      'monto', v_monto,
      'comprobante', trim(p_comprobante),
      'comprobante_storage_path', trim(p_comprobante_storage_path)
    ),
    NOW()
  );

  RETURN QUERY SELECT TRUE, 'Retiro completado', v_capitan_id, v_monto;
END;
$$;

CREATE OR REPLACE FUNCTION public.rechazar_retiro_billetera(
  p_liquidacion_id UUID,
  p_admin_id UUID,
  p_motivo TEXT DEFAULT NULL
)
RETURNS TABLE (
  exito BOOLEAN,
  mensaje TEXT,
  ret_capitan_id UUID,
  ret_monto NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
DECLARE
  v_liq RECORD;
  v_capitan_id UUID;
  v_monto NUMERIC(12,2);
BEGIN
  SELECT * INTO v_liq
  FROM public.liquidaciones
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

  UPDATE public.liquidaciones SET
    estado       = 'fallido',
    procesado_at = NOW(),
    descripcion  = COALESCE(descripcion, '')
                   || CASE WHEN p_motivo IS NOT NULL AND trim(p_motivo) <> ''
                      THEN ' — Rechazado: ' || trim(p_motivo) ELSE ' — Rechazado por admin' END
  WHERE id = p_liquidacion_id;

  UPDATE public.billetera_capitanes bc SET
    saldo_retenido   = GREATEST(0, bc.saldo_retenido - v_monto),
    saldo_disponible = bc.saldo_disponible + v_monto,
    updated_at       = NOW()
  WHERE bc.capitan_id = v_capitan_id;

  UPDATE public.movimientos_billetera mb SET
    tipo        = 'retiro_fallido',
    estado      = 'fallido',
    descripcion = COALESCE(mb.descripcion, 'Retiro rechazado')
                  || CASE WHEN p_motivo IS NOT NULL AND trim(p_motivo) <> ''
                     THEN ' — ' || trim(p_motivo) ELSE '' END
  WHERE mb.liquidacion_id = p_liquidacion_id
    AND mb.tipo = 'retiro_solicitado';

  INSERT INTO public.logs_sistema (tipo, descripcion, user_id, datos_adicionales, created_at)
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

GRANT EXECUTE ON FUNCTION public.completar_retiro_billetera(UUID, UUID, NUMERIC, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.rechazar_retiro_billetera(UUID, UUID, TEXT) TO authenticated;

NOTIFY pgrst, 'reload schema';
