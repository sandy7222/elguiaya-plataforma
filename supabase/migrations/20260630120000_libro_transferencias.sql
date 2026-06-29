-- Libro de transferencias: auditoría de retiros con comprobante MP + ticket adjunto

-- Helper admin reutilizable
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT
    (auth.jwt() -> 'user_metadata' ->> 'role') = 'admin'
    OR (auth.jwt() ->> 'email') = 'admin@capitanya.com'
    OR EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.user_id = auth.uid()
        AND p.admin = true
    );
$$;

-- Columnas extra en liquidaciones
ALTER TABLE public.liquidaciones
  ADD COLUMN IF NOT EXISTS comprobante_storage_path TEXT,
  ADD COLUMN IF NOT EXISTS admin_procesador_id UUID;

-- Libro append-only
CREATE TABLE IF NOT EXISTS public.libro_transferencias (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  liquidacion_id           UUID NOT NULL REFERENCES public.liquidaciones(id),
  capitan_id               UUID NOT NULL,
  admin_id                 UUID NOT NULL,
  monto                    NUMERIC(12,2) NOT NULL,
  cbu_destino              TEXT NOT NULL DEFAULT '',
  numero_comprobante       TEXT NOT NULL,
  comprobante_storage_path TEXT NOT NULL,
  procesado_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_libro_transferencias_procesado_at
  ON public.libro_transferencias (procesado_at DESC);

CREATE INDEX IF NOT EXISTS idx_libro_transferencias_numero_comprobante
  ON public.libro_transferencias (numero_comprobante);

CREATE INDEX IF NOT EXISTS idx_libro_transferencias_capitan_id
  ON public.libro_transferencias (capitan_id);

CREATE INDEX IF NOT EXISTS idx_libro_transferencias_admin_id
  ON public.libro_transferencias (admin_id);

CREATE INDEX IF NOT EXISTS idx_libro_transferencias_liquidacion_id
  ON public.libro_transferencias (liquidacion_id);

ALTER TABLE public.libro_transferencias ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admin lee libro transferencias" ON public.libro_transferencias;
CREATE POLICY "Admin lee libro transferencias"
ON public.libro_transferencias
FOR SELECT
USING (public.is_admin_user());

-- Sin INSERT/UPDATE/DELETE directo desde cliente; solo vía RPC SECURITY DEFINER

-- Reemplazar RPC completar_retiro_billetera (nueva firma con path de comprobante)
DROP FUNCTION IF EXISTS public.completar_retiro_billetera(UUID, UUID, NUMERIC, TEXT);

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
  v_cbu := COALESCE(v_liq.cbu, '');

  IF p_monto_depositado IS NULL OR p_monto_depositado <= 0 THEN
    RETURN QUERY SELECT FALSE, 'Monto depositado inválido', v_capitan_id, 0::NUMERIC;
    RETURN;
  END IF;

  IF ROUND(p_monto_depositado, 2) <> ROUND(v_monto, 2) THEN
    RETURN QUERY SELECT FALSE, 'El monto depositado debe coincidir con el solicitado', v_capitan_id, v_monto;
    RETURN;
  END IF;

  UPDATE liquidaciones SET
    estado                    = 'completado',
    procesado_at              = NOW(),
    comprobante               = trim(p_comprobante),
    comprobante_storage_path  = trim(p_comprobante_storage_path),
    admin_procesador_id       = p_admin_id,
    descripcion               = COALESCE(descripcion, 'Transferencia solicitada por el capitán')
                                || ' — confirmada por admin'
  WHERE id = p_liquidacion_id;

  UPDATE billetera_capitanes bc SET
    saldo_retenido = GREATEST(0, bc.saldo_retenido - v_monto),
    updated_at     = NOW()
  WHERE bc.capitan_id = v_capitan_id;

  UPDATE movimientos_billetera mb SET
    tipo        = 'retiro_completado',
    estado      = 'completado',
    liberado_at = NOW(),
    descripcion = 'Transferencia completada — ref: ' || trim(p_comprobante)
  WHERE mb.liquidacion_id = p_liquidacion_id
    AND mb.tipo = 'retiro_solicitado';

  INSERT INTO libro_transferencias (
    liquidacion_id,
    capitan_id,
    admin_id,
    monto,
    cbu_destino,
    numero_comprobante,
    comprobante_storage_path,
    procesado_at
  ) VALUES (
    p_liquidacion_id,
    v_capitan_id,
    p_admin_id,
    v_monto,
    v_cbu,
    trim(p_comprobante),
    trim(p_comprobante_storage_path),
    NOW()
  );

  INSERT INTO logs_sistema (tipo, descripcion, user_id, datos_adicionales, created_at)
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

GRANT EXECUTE ON FUNCTION public.completar_retiro_billetera(UUID, UUID, NUMERIC, TEXT, TEXT) TO authenticated;

-- Listado paginado del libro para admin
CREATE OR REPLACE FUNCTION public.list_libro_transferencias_admin(
  p_limit INTEGER DEFAULT 50,
  p_offset INTEGER DEFAULT 0,
  p_desde TIMESTAMPTZ DEFAULT NULL,
  p_hasta TIMESTAMPTZ DEFAULT NULL,
  p_busqueda TEXT DEFAULT NULL
)
RETURNS TABLE (
  id UUID,
  liquidacion_id UUID,
  capitan_id UUID,
  capitan_nombre TEXT,
  admin_id UUID,
  admin_nombre TEXT,
  monto NUMERIC,
  cbu_enmascarado TEXT,
  numero_comprobante TEXT,
  comprobante_storage_path TEXT,
  procesado_at TIMESTAMPTZ,
  total_count BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit INTEGER := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 200);
  v_offset INTEGER := GREATEST(COALESCE(p_offset, 0), 0);
  v_busqueda TEXT := NULLIF(trim(COALESCE(p_busqueda, '')), '');
BEGIN
  IF NOT public.is_admin_user() THEN
    RETURN;
  END IF;

  RETURN QUERY
  WITH filtered AS (
    SELECT
      lt.*,
      pc.nombre AS cap_nombre,
      pa.nombre AS adm_nombre,
      CASE
        WHEN length(regexp_replace(COALESCE(lt.cbu_destino, ''), '[\s\-]', '', 'g')) >= 8 THEN
          left(regexp_replace(lt.cbu_destino, '[\s\-]', '', 'g'), 4)
          || '...'
          || right(regexp_replace(lt.cbu_destino, '[\s\-]', '', 'g'), 4)
        ELSE 'Sin CBU'
      END AS cbu_mask
    FROM libro_transferencias lt
    LEFT JOIN profiles pc ON pc.user_id = lt.capitan_id
    LEFT JOIN profiles pa ON pa.user_id = lt.admin_id
    WHERE (p_desde IS NULL OR lt.procesado_at >= p_desde)
      AND (p_hasta IS NULL OR lt.procesado_at <= p_hasta)
      AND (
        v_busqueda IS NULL
        OR lt.numero_comprobante ILIKE '%' || v_busqueda || '%'
        OR pc.nombre ILIKE '%' || v_busqueda || '%'
      )
  ),
  counted AS (
    SELECT COUNT(*)::BIGINT AS cnt FROM filtered
  )
  SELECT
    f.id,
    f.liquidacion_id,
    f.capitan_id,
    COALESCE(f.cap_nombre, 'Capitán') AS capitan_nombre,
    f.admin_id,
    COALESCE(f.adm_nombre, 'Admin') AS admin_nombre,
    f.monto,
    f.cbu_mask AS cbu_enmascarado,
    f.numero_comprobante,
    f.comprobante_storage_path,
    f.procesado_at,
    c.cnt AS total_count
  FROM filtered f
  CROSS JOIN counted c
  ORDER BY f.procesado_at DESC
  LIMIT v_limit
  OFFSET v_offset;
END;
$$;

GRANT EXECUTE ON FUNCTION public.list_libro_transferencias_admin(INTEGER, INTEGER, TIMESTAMPTZ, TIMESTAMPTZ, TEXT) TO authenticated;

-- Storage: comprobantes de liquidaciones (bucket privado)
DROP POLICY IF EXISTS "Admin sube comprobantes liquidaciones" ON storage.objects;
CREATE POLICY "Admin sube comprobantes liquidaciones"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (
  bucket_id = 'documentacion_privada'
  AND (storage.foldername(name))[1] = 'liquidaciones'
  AND public.is_admin_user()
);

DROP POLICY IF EXISTS "Admin lee comprobantes liquidaciones" ON storage.objects;
CREATE POLICY "Admin lee comprobantes liquidaciones"
ON storage.objects FOR SELECT TO authenticated
USING (
  bucket_id = 'documentacion_privada'
  AND (storage.foldername(name))[1] = 'liquidaciones'
  AND public.is_admin_user()
);

DROP POLICY IF EXISTS "Admin actualiza comprobantes liquidaciones" ON storage.objects;
CREATE POLICY "Admin actualiza comprobantes liquidaciones"
ON storage.objects FOR UPDATE TO authenticated
USING (
  bucket_id = 'documentacion_privada'
  AND (storage.foldername(name))[1] = 'liquidaciones'
  AND public.is_admin_user()
);

NOTIFY pgrst, 'reload schema';
