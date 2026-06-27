-- Planilla post-pago del pescador: snapshot JSONB + RPC
-- Ejecutar en Supabase SQL Editor

BEGIN;

ALTER TABLE public.pedidos
  ADD COLUMN IF NOT EXISTS pescador_snapshot JSONB;

CREATE OR REPLACE FUNCTION public.obtener_ficha_pescador(p_pedido_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_pedido RECORD;
  v_snapshot JSONB;
BEGIN
  IF v_uid IS NULL OR p_pedido_id IS NULL THEN
    RETURN NULL;
  END IF;

  SELECT
    pe.id,
    pe.estado,
    pe.monto_total,
    pe.fecha_servicio,
    pe.contacto_habilitado,
    pe.pescador_id,
    pe.capitan_id,
    pe.presupuesto_id,
    pe.cotizacion_id,
    pe.pescador_snapshot
  INTO v_pedido
  FROM public.pedidos pe
  WHERE pe.id = p_pedido_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_uid <> v_pedido.pescador_id AND v_uid <> v_pedido.capitan_id THEN
    RETURN NULL;
  END IF;

  IF v_pedido.estado NOT IN (
    'pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado', 'programado'
  ) THEN
    RETURN NULL;
  END IF;

  IF v_uid = v_pedido.pescador_id
     AND COALESCE(v_pedido.contacto_habilitado, FALSE) = FALSE
     AND v_pedido.estado IN ('programado') THEN
    RETURN NULL;
  END IF;

  v_snapshot := v_pedido.pescador_snapshot;

  RETURN jsonb_build_object(
    'pedido_id', v_pedido.id,
    'estado', v_pedido.estado,
    'monto_total', v_pedido.monto_total,
    'fecha_servicio', v_pedido.fecha_servicio,
    'contacto_habilitado', COALESCE(v_pedido.contacto_habilitado, FALSE),
    'capitan_id', v_pedido.capitan_id,
    'pescador_id', v_pedido.pescador_id,
    'presupuesto_id', v_pedido.presupuesto_id,
    'cotizacion_id', v_pedido.cotizacion_id,
    'pescador_snapshot', v_snapshot
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_ficha_pescador(UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT 'OK: pescador_viaje_snapshot + obtener_ficha_pescador' AS resultado;
