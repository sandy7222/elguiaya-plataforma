-- Remedia rls_disabled_in_public sobre public.spatial_ref_sys (alerta crítica
-- de Security Advisor / email de Supabase).
--
-- spatial_ref_sys es una tabla de catálogo de PostGIS, owned by supabase_admin.
-- Desde el rol postgres NO se puede ENABLE ROW LEVEL SECURITY ni REVOKE de
-- anon/authenticated (los GRANT los hizo supabase_admin). La remediación
-- soportada es sacar PostGIS del schema public (expuesto a PostgREST) y
-- recrearlo en `extensions`, que no forma parte de la Data API ni del lint 0013.
--
-- Única dependencia de usuario: public.cotizaciones_mapa.ubicacion (geometry).
-- Se respalda en EWKT, se recrea la columna y se restaura en la misma transacción.

CREATE TABLE public._backup_cotizaciones_mapa_ubicacion AS
SELECT id, ST_AsEWKT(ubicacion) AS ewkt
FROM public.cotizaciones_mapa;

ALTER TABLE public.cotizaciones_mapa DROP COLUMN ubicacion;

DROP EXTENSION postgis;

CREATE EXTENSION postgis WITH SCHEMA extensions;

SET search_path = public, extensions;

ALTER TABLE public.cotizaciones_mapa
  ADD COLUMN ubicacion geometry(Point, 4326);

UPDATE public.cotizaciones_mapa AS m
SET ubicacion = ST_GeomFromEWKT(b.ewkt)
FROM public._backup_cotizaciones_mapa_ubicacion AS b
WHERE m.id = b.id
  AND b.ewkt IS NOT NULL;

DO $$
DECLARE
  missing integer;
  total_backup integer;
  total_restored integer;
BEGIN
  SELECT COUNT(*) INTO total_backup FROM public._backup_cotizaciones_mapa_ubicacion;
  SELECT COUNT(*) INTO total_restored
  FROM public.cotizaciones_mapa
  WHERE ubicacion IS NOT NULL;
  SELECT COUNT(*) INTO missing
  FROM public._backup_cotizaciones_mapa_ubicacion b
  LEFT JOIN public.cotizaciones_mapa m ON m.id = b.id
  WHERE b.ewkt IS NOT NULL AND m.ubicacion IS NULL;

  IF missing <> 0 THEN
    RAISE EXCEPTION 'No se restauraron % filas de cotizaciones_mapa.ubicacion', missing;
  END IF;
  IF total_restored <> total_backup THEN
    RAISE EXCEPTION 'Conteo inconsistente al restaurar ubicacion: backup=% restored=%', total_backup, total_restored;
  END IF;
END
$$;

DROP TABLE public._backup_cotizaciones_mapa_ubicacion;

-- Cerrar API roles si postgres queda como owner. Si no, el schema extensions
-- igual queda fuera de PostgREST y del lint 0013.
DO $$
BEGIN
  REVOKE ALL ON TABLE extensions.spatial_ref_sys FROM anon;
  REVOKE ALL ON TABLE extensions.spatial_ref_sys FROM authenticated;
  REVOKE ALL ON TABLE extensions.spatial_ref_sys FROM PUBLIC;
  ALTER TABLE extensions.spatial_ref_sys ENABLE ROW LEVEL SECURITY;
EXCEPTION
  WHEN insufficient_privilege THEN
    RAISE NOTICE 'No se pudieron ajustar grants/RLS de extensions.spatial_ref_sys; el schema no está expuesto a la API.';
  WHEN undefined_table THEN
    RAISE NOTICE 'spatial_ref_sys no quedó en extensions.';
  WHEN OTHERS THEN
    RAISE NOTICE 'Ajuste opcional de extensions.spatial_ref_sys: %', SQLERRM;
END
$$;

NOTIFY pgrst, 'reload schema';
