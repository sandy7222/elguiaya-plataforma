-- Snapshot público del capitán en presupuestos + RPC seguro para la tarjeta del pescador
-- Ejecutar en Supabase SQL Editor (proyecto ymgsxwfwntbqvguvbhoa)

BEGIN;

ALTER TABLE public.presupuestos
  ADD COLUMN IF NOT EXISTS capitan_nombre TEXT,
  ADD COLUMN IF NOT EXISTS capitan_avatar_url TEXT,
  ADD COLUMN IF NOT EXISTS barco_nombre TEXT,
  ADD COLUMN IF NOT EXISTS embarcacion_url TEXT;

-- Backfill de presupuestos existentes
UPDATE public.presupuestos p
SET
  capitan_nombre = COALESCE(
    NULLIF(TRIM(p.capitan_nombre), ''),
    NULLIF(TRIM(g.nombre), ''),
    NULLIF(TRIM(pr.nombre), ''),
    'Capitán'
  ),
  capitan_avatar_url = COALESCE(
    NULLIF(TRIM(p.capitan_avatar_url), ''),
    NULLIF(TRIM(g.avatar_url), ''),
    NULLIF(TRIM(pr.avatar_url), '')
  ),
  embarcacion_url = COALESCE(
    NULLIF(TRIM(p.embarcacion_url), ''),
    NULLIF(TRIM(g.embarcacion_url), ''),
    NULLIF(TRIM(pr.embarcacion_url), '')
  ),
  barco_nombre = COALESCE(
    NULLIF(TRIM(p.barco_nombre), ''),
    CASE
      WHEN COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), '')) IS NOT NULL
        THEN 'Embarcación de ' || COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), ''))
      ELSE 'Embarcación Principal'
    END
  )
FROM public.profiles pr
LEFT JOIN public.guias g ON g.id = pr.user_id
WHERE pr.user_id = p.capitan_id
  AND (
    p.capitan_avatar_url IS NULL OR TRIM(p.capitan_avatar_url) = ''
    OR p.embarcacion_url IS NULL OR TRIM(p.embarcacion_url) = ''
    OR p.capitan_nombre IS NULL OR TRIM(p.capitan_nombre) = ''
  );

CREATE OR REPLACE FUNCTION public.obtener_datos_capitan_oferta(
  p_capitan_id UUID,
  p_cotizacion_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_autorizado BOOLEAN := FALSE;
  v_nombre TEXT;
  v_avatar TEXT;
  v_embarcacion TEXT;
  v_barco TEXT;
  v_calificacion NUMERIC;
  v_viajes INTEGER;
  v_bio TEXT;
BEGIN
  IF v_uid IS NULL OR p_capitan_id IS NULL THEN
    RETURN NULL;
  END IF;

  IF v_uid = p_capitan_id THEN
    v_autorizado := TRUE;
  ELSIF p_cotizacion_id IS NOT NULL THEN
    SELECT TRUE INTO v_autorizado
    FROM public.cotizaciones c
    JOIN public.presupuestos pr
      ON pr.cotizacion_id = c.id
     AND pr.capitan_id = p_capitan_id
    WHERE c.id = p_cotizacion_id
      AND c.pescador_id = v_uid
    LIMIT 1;
  END IF;

  IF NOT COALESCE(v_autorizado, FALSE) THEN
    RETURN NULL;
  END IF;

  SELECT
    COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), ''), 'Capitán'),
    COALESCE(NULLIF(TRIM(g.avatar_url), ''), NULLIF(TRIM(pr.avatar_url), '')),
    COALESCE(NULLIF(TRIM(g.embarcacion_url), ''), NULLIF(TRIM(pr.embarcacion_url), '')),
    CASE
      WHEN COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), '')) IS NOT NULL
        THEN 'Embarcación de ' || COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), ''))
      ELSE 'Embarcación Principal'
    END,
    rc.calificacion_promedio,
    COALESCE(rc.viajes_completados, rc.total_viajes, 0),
    pr.bio_pescador
  INTO v_nombre, v_avatar, v_embarcacion, v_barco, v_calificacion, v_viajes, v_bio
  FROM public.profiles pr
  LEFT JOIN public.guias g ON g.id = pr.user_id
  LEFT JOIN public.reputacion_capitanes rc ON rc.capitan_id = pr.user_id
  WHERE pr.user_id = p_capitan_id;

  IF v_nombre IS NULL OR v_nombre = 'Capitán' THEN
    SELECT
      COALESCE(NULLIF(TRIM(g.nombre), ''), 'Capitán'),
      NULLIF(TRIM(g.avatar_url), ''),
      NULLIF(TRIM(g.embarcacion_url), ''),
      CASE
        WHEN NULLIF(TRIM(g.nombre), '') IS NOT NULL
          THEN 'Embarcación de ' || NULLIF(TRIM(g.nombre), '')
        ELSE 'Embarcación Principal'
      END
    INTO v_nombre, v_avatar, v_embarcacion, v_barco
    FROM public.guias g
    WHERE g.id = p_capitan_id;
  END IF;

  RETURN jsonb_build_object(
    'nombre', v_nombre,
    'avatar_url', v_avatar,
    'embarcacion_url', v_embarcacion,
    'barco_nombre', v_barco,
    'calificacion_promedio', v_calificacion,
    'viajes_realizados', v_viajes,
    'bio_pescador', v_bio
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_datos_capitan_oferta(UUID, UUID) TO authenticated;

NOTIFY pgrst, 'reload schema';

COMMIT;

SELECT 'OK: snapshot presupuestos + RPC obtener_datos_capitan_oferta' AS resultado;
