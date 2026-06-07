-- Vistas para alimentar el Comando Operativo (Mapa) en tiempo real

-- 1. Vista para Capitanes (requiere 'es_capitan' = true)
CREATE OR REPLACE VIEW capitanes_zonas AS
SELECT 
    user_id as id,
    disponible as activo,
    jsonb_build_object('lat', zona_lat, 'lon', zona_lng) as centro_operaciones,
    zona_radio_km as radio_cobertura_km,
    telefono_contacto as nombre
FROM profiles
WHERE es_capitan = TRUE 
  AND zona_lat IS NOT NULL;

-- 2. Vista para Pescadores
-- Muestra a los usuarios que NO son capitanes y tienen una ubicación configurada
CREATE OR REPLACE VIEW pescadores_puntos AS
SELECT 
    user_id as id,
    TRUE as activo,
    centro_operacion_lat_long as ubicacion_actual,
    COALESCE(telefono_contacto, 'Pescador') as nombre
FROM profiles
WHERE (es_capitan = FALSE OR es_capitan IS NULL)
  AND centro_operacion_lat_long IS NOT NULL;

-- 3. Vista para Cotizaciones en el Mapa
-- Muestra las cotizaciones que tienen un punto de partida geográfico
CREATE OR REPLACE VIEW cotizaciones_mapa AS
SELECT 
    id,
    punto_partida as ubicacion,
    estado,
    presupuesto_monto as monto,
    descripcion as descripcion_corta,
    pescador_id
FROM cotizaciones
WHERE punto_partida IS NOT NULL;

-- Asegurar que los clientes puedan leer estas vistas de forma pública/autenticada
GRANT SELECT ON capitanes_zonas TO authenticated, anon;
GRANT SELECT ON pescadores_puntos TO authenticated, anon;
GRANT SELECT ON cotizaciones_mapa TO authenticated, anon;
