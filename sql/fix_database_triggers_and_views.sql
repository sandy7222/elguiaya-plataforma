-- 1. Eliminar dinámicamente cualquier trigger obsoleto en la tabla 'profiles'
-- Esto evitará el error de conversión de tipo al actualizar 'zona_lat' y 'zona_lng'.
DO $$
DECLARE
    trig RECORD;
BEGIN
    FOR trig IN 
        SELECT tgname 
        FROM pg_trigger 
        JOIN pg_class ON pg_class.oid = tgrelid 
        WHERE relname = 'profiles' 
          AND tgname NOT IN ('set_profiles_timestamp', 'trigger_actualizar_disponibilidad_timestamp')
          AND tgisinternal = false
    LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || quote_ident(trig.tgname) || ' ON profiles;';
        RAISE NOTICE 'Dropped trigger % on profiles', trig.tgname;
    END LOOP;
END;
$$;

-- Asegurar que la columna 'limite_respuesta_minutos' exista en profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS limite_respuesta_minutos INTEGER DEFAULT 15;

-- 2. Eliminar vistas obsoletas de forma segura para recrearlas
DROP VIEW IF EXISTS pescadores_puntos CASCADE;
DROP VIEW IF EXISTS capitanes_zonas CASCADE;
DROP VIEW IF EXISTS vw_capitanes_disponibles CASCADE;

-- 3. Recrear la vista de pescadores para el mapa usando 'zona_lat' y 'zona_lng'
CREATE OR REPLACE VIEW pescadores_puntos AS
SELECT 
    user_id as id,
    TRUE as activo,
    jsonb_build_object('lat', zona_lat, 'lon', zona_lng) as ubicacion_actual,
    COALESCE(nombre, COALESCE(telefono, 'Pescador')) as nombre
FROM profiles
WHERE (es_capitan = FALSE OR es_capitan IS NULL)
  AND zona_lat IS NOT NULL;

-- 4. Recrear la vista de zonas de capitanes usando 'zona_lat' y 'zona_lng'
CREATE OR REPLACE VIEW capitanes_zonas AS
SELECT 
    user_id as id,
    disponible as activo,
    jsonb_build_object('lat', zona_lat, 'lon', zona_lng) as centro_operaciones,
    zona_radio_km as radio_cobertura_km,
    COALESCE(nombre, COALESCE(telefono, 'Capitán')) as nombre
FROM profiles
WHERE es_capitan = TRUE 
  AND zona_lat IS NOT NULL;

-- 5. Recrear la vista de capitanes disponibles
CREATE OR REPLACE VIEW vw_capitanes_disponibles AS
SELECT 
    p.user_id,
    COALESCE(p.nombre, COALESCE(p.telefono, 'Capitán ' || SUBSTRING(p.user_id::TEXT, 1, 8))) as nombre,
    p.disponible,
    p.zona_radio_km,
    jsonb_build_object('lat', p.zona_lat, 'lon', p.zona_lng) as centro_operacion_lat_long,
    p.limite_respuesta_minutos,
    p.telefono as telefono_contacto,
    CASE 
        WHEN p.zona_lat IS NULL THEN 'Sin configurar'
        WHEN NOT p.disponible THEN 'No disponible'
        ELSE 'Disponible'
    END as estado_operativo,
    CASE 
        WHEN p.zona_lat IS NULL THEN 'grey'
        WHEN NOT p.disponible THEN 'red'
        ELSE 'green'
    END as color_estado
FROM profiles p
WHERE p.es_capitan = TRUE;

-- 6. Garantizar permisos de lectura
GRANT SELECT ON pescadores_puntos TO authenticated, anon;
GRANT SELECT ON capitanes_zonas TO authenticated, anon;
GRANT SELECT ON vw_capitanes_disponibles TO authenticated, anon;

-- 7. Forzar recarga del Schema Cache de PostgREST
NOTIFY pgrst, 'reload schema';
