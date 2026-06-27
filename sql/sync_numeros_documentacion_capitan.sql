-- Sincroniza N° carnet y N° póliza desde guias → profiles (excluye URLs de storage)
-- Ejecutar una vez en Supabase SQL Editor tras contrato_viaje_snapshot.sql

BEGIN;

UPDATE public.profiles pr
SET
  numero_carnet = COALESCE(
    NULLIF(TRIM(pr.numero_carnet), ''),
    NULLIF(TRIM(g.carnet_timonel), '')
  ),
  numero_poliza = COALESCE(
    NULLIF(TRIM(pr.numero_poliza), ''),
    NULLIF(TRIM(g.poliza_seguro), '')
  ),
  updated_at = NOW()
FROM public.guias g
WHERE g.id = pr.user_id
  AND pr.es_capitan = TRUE
  AND (
    (pr.numero_carnet IS NULL OR TRIM(pr.numero_carnet) = '')
    OR (pr.numero_poliza IS NULL OR TRIM(pr.numero_poliza) = '')
  )
  AND (
    (
      g.carnet_timonel IS NOT NULL
      AND TRIM(g.carnet_timonel) <> ''
      AND g.carnet_timonel NOT ILIKE 'http%'
    )
    OR (
      g.poliza_seguro IS NOT NULL
      AND TRIM(g.poliza_seguro) <> ''
      AND g.poliza_seguro NOT ILIKE 'http%'
    )
  );

-- Limpiar perfiles que tengan URLs guardadas por error en numero_carnet / numero_poliza
UPDATE public.profiles
SET
  numero_carnet = NULL,
  updated_at = NOW()
WHERE numero_carnet ILIKE 'http%';

UPDATE public.profiles
SET
  numero_poliza = NULL,
  updated_at = NOW()
WHERE numero_poliza ILIKE 'http%';

COMMIT;

SELECT 'OK: sync_numeros_documentacion_capitan' AS resultado;
