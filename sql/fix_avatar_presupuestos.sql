-- Fix avatar en presupuestos: sincronizar fuentes y re-backfill
-- Ejecutar en Supabase SQL Editor (proyecto ymgsxwfwntbqvguvbhoa)

BEGIN;

-- 1) Sincronizar avatar entre profiles y guias (ambos sentidos)
UPDATE public.profiles pr
SET avatar_url = g.avatar_url
FROM public.guias g
WHERE g.id = pr.user_id
  AND (pr.avatar_url IS NULL OR TRIM(pr.avatar_url) = '')
  AND g.avatar_url IS NOT NULL
  AND TRIM(g.avatar_url) <> '';

UPDATE public.guias g
SET avatar_url = pr.avatar_url
FROM public.profiles pr
WHERE pr.user_id = g.id
  AND (g.avatar_url IS NULL OR TRIM(g.avatar_url) = '')
  AND pr.avatar_url IS NOT NULL
  AND TRIM(pr.avatar_url) <> '';

-- 2) Completar avatar desde documentos_usuarios si existe la tabla
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'documentos_usuarios'
  ) THEN
    UPDATE public.profiles pr
    SET avatar_url = du.url_storage
    FROM (
      SELECT DISTINCT ON (usuario_id)
        usuario_id,
        url_storage
      FROM public.documentos_usuarios
      WHERE tipo_doc IN ('avatar', 'perfil')
        AND url_storage IS NOT NULL
        AND TRIM(url_storage) <> ''
      ORDER BY usuario_id, created_at DESC
    ) du
    WHERE pr.user_id::text = du.usuario_id::text
      AND (pr.avatar_url IS NULL OR TRIM(pr.avatar_url) = '');

    UPDATE public.guias g
    SET avatar_url = pr.avatar_url
    FROM public.profiles pr
    WHERE pr.user_id = g.id
      AND (g.avatar_url IS NULL OR TRIM(g.avatar_url) = '')
      AND pr.avatar_url IS NOT NULL
      AND TRIM(pr.avatar_url) <> '';
  END IF;
END $$;

-- 3) Re-backfill solo avatar en presupuestos existentes
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'documentos_usuarios'
  ) THEN
    UPDATE public.presupuestos p
    SET capitan_avatar_url = COALESCE(
      NULLIF(TRIM(p.capitan_avatar_url), ''),
      NULLIF(TRIM(g.avatar_url), ''),
      NULLIF(TRIM(pr.avatar_url), ''),
      (
        SELECT du.url_storage
        FROM public.documentos_usuarios du
        WHERE du.usuario_id::text = p.capitan_id::text
          AND du.tipo_doc IN ('avatar', 'perfil')
          AND du.url_storage IS NOT NULL
          AND TRIM(du.url_storage) <> ''
        ORDER BY du.created_at DESC
        LIMIT 1
      )
    )
    FROM public.profiles pr
    LEFT JOIN public.guias g ON g.id = pr.user_id
    WHERE pr.user_id = p.capitan_id
      AND (p.capitan_avatar_url IS NULL OR TRIM(p.capitan_avatar_url) = '');
  ELSE
    UPDATE public.presupuestos p
    SET capitan_avatar_url = COALESCE(
      NULLIF(TRIM(p.capitan_avatar_url), ''),
      NULLIF(TRIM(g.avatar_url), ''),
      NULLIF(TRIM(pr.avatar_url), '')
    )
    FROM public.profiles pr
    LEFT JOIN public.guias g ON g.id = pr.user_id
    WHERE pr.user_id = p.capitan_id
      AND (p.capitan_avatar_url IS NULL OR TRIM(p.capitan_avatar_url) = '');
  END IF;
END $$;

-- 4) RPC: más fuentes para avatar
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
  v_doc_avatar TEXT;
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

  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'documentos_usuarios'
  ) THEN
    SELECT du.url_storage INTO v_doc_avatar
    FROM public.documentos_usuarios du
    WHERE du.usuario_id::text = p_capitan_id::text
      AND du.tipo_doc IN ('avatar', 'perfil')
      AND du.url_storage IS NOT NULL
      AND TRIM(du.url_storage) <> ''
    ORDER BY du.created_at DESC
    LIMIT 1;
  END IF;

  SELECT
    COALESCE(NULLIF(TRIM(g.nombre), ''), NULLIF(TRIM(pr.nombre), ''), 'Capitán'),
    COALESCE(
      NULLIF(TRIM(g.avatar_url), ''),
      NULLIF(TRIM(pr.avatar_url), ''),
      NULLIF(TRIM(v_doc_avatar), '')
    ),
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
      COALESCE(NULLIF(TRIM(g.avatar_url), ''), NULLIF(TRIM(v_doc_avatar), '')),
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

SELECT 'OK: avatar sincronizado y presupuestos actualizados' AS resultado;
