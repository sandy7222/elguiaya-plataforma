-- Agregar campos de geofencing y disponibilidad a la tabla profiles
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS radio_operacion_km DECIMAL(8,2) DEFAULT 25.0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS centro_operacion_lat_long JSONB;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS disponible BOOLEAN DEFAULT TRUE;

-- Crear índices para optimización geográfica
CREATE INDEX IF NOT EXISTS idx_profiles_es_capitan ON profiles(es_capitan) WHERE es_capitan = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_disponibles ON profiles(disponible, es_capitan) WHERE disponible = TRUE AND es_capitan = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_centro_operacion ON profiles USING GIN (centro_operacion_lat_long) WHERE centro_operacion_lat_long IS NOT NULL;

-- Función para calcular distancia entre dos puntos (reutilizando la existente)
CREATE OR REPLACE FUNCTION distancia_entre_puntos(
    lat1 DECIMAL, lon1 DECIMAL, lat2 DECIMAL, lon2 DECIMAL
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    earth_radius_km DECIMAL := 6371.0;
    dlat DECIMAL;
    dlon DECIMAL;
    a DECIMAL;
    c DECIMAL;
    distance_km DECIMAL;
BEGIN
    dlat := RADIANS(lat2 - lat1);
    dlon := RADIANS(lon2 - lon1);
    
    a := SIN(dlat / 2) * SIN(dlat / 2) + 
         COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * 
         SIN(dlon / 2) * SIN(dlon / 2);
    
    c := 2 * ATAN2(SQRT(a), SQRT(1 - a));
    distance_km := earth_radius_km * c;
    
    RETURN ROUND(distance_km, 2);
END;
$$ LANGUAGE plpgsql;

-- Función para verificar si un capitán cubre un punto
CREATE OR REPLACE FUNCTION capitán_cubre_punto(
    p_capitan_id UUID,
    p_lat DECIMAL,
    p_lon DECIMAL
)
RETURNS BOOLEAN AS $$
DECLARE
    centro_lat DECIMAL;
    centro_lon DECIMAL;
    radio_km DECIMAL;
    distancia_km DECIMAL;
BEGIN
    -- Obtener centro y radio de operación del capitán
    SELECT 
        (centro_operacion_lat_long->>'lat')::DECIMAL,
        (centro_operacion_lat_long->>'lon')::DECIMAL,
        COALESCE(radio_operacion_km, 25.0)
    INTO centro_lat, centro_lon, radio_km
    FROM profiles
    WHERE user_id = p_capitan_id 
    AND es_capitan = TRUE 
    AND disponible = TRUE
    AND centro_operacion_lat_long IS NOT NULL;
    
    -- Si no se encuentra el capitán o no tiene configuración, retornar falso
    IF centro_lat IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Calcular distancia desde el centro hasta el punto
    distancia_km := distancia_entre_puntos(centro_lat, centro_lon, p_lat, p_lon);
    
    -- Verificar si el punto está dentro del radio de operación
    RETURN distancia_km <= radio_km;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener capitanes disponibles para una cotización
CREATE OR REPLACE FUNCTION get_capitanes_disponibles_para_cotizacion(
    p_lat_partida DECIMAL,
    p_lon_partida DECIMAL
)
RETURNS TABLE (
    capitan_id UUID,
    nombre_completo VARCHAR,
    telefono_contacto VARCHAR,
    distancia_km DECIMAL,
    radio_operacion_km DECIMAL,
    centro_operacion JSONB,
    limite_respuesta_minutos INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.user_id as capitan_id,
        COALESCE(p.telefono_contacto, 'Capitán sin nombre') as nombre_completo,
        p.telefono_contacto,
        distancia_entre_puntos(
            (p.centro_operacion_lat_long->>'lat')::DECIMAL,
            (p.centro_operacion_lat_long->>'lon')::DECIMAL,
            p_lat_partida,
            p_lon_partida
        ) as distancia_km,
        p.radio_operacion_km,
        p.centro_operacion_lat_long as centro_operacion,
        p.limite_respuesta_minutos
    FROM profiles p
    WHERE p.es_capitan = TRUE
    AND p.disponible = TRUE
    AND p.centro_operacion_lat_long IS NOT NULL
    AND distancia_entre_puntos(
        (p.centro_operacion_lat_long->>'lat')::DECIMAL,
        (p.centro_operacion_lat_long->>'lon')::DECIMAL,
        p_lat_partida,
        p_lon_partida
    ) <= COALESCE(p.radio_operacion_km, 25.0)
    ORDER BY distancia_km ASC;
END;
$$ LANGUAGE plpgsql;

-- Función para asignar automáticamente capitán a cotización
CREATE OR REPLACE FUNCTION asignar_capitan_a_cotizacion(
    p_cotizacion_id UUID
)
RETURNS TABLE (
    capitan_asignado UUID,
    distancia_km DECIMAL,
    asignacion_exitosa BOOLEAN,
    mensaje TEXT
) AS $$
DECLARE
    cotizacion_data RECORD;
    capitanes_disponibles RECORD;
    capitan_seleccionado UUID;
BEGIN
    -- Obtener datos de la cotización
    SELECT *
    INTO cotizacion_data
    FROM cotizaciones
    WHERE id = p_cotizacion_id;
    
    -- Si no hay punto de partida, no se puede asignar
    IF cotizacion_data.punto_partida IS NULL THEN
        RETURN QUERY SELECT NULL, 0.0, FALSE, 'Sin punto de partida definido';
        RETURN;
    END IF;
    
    -- Buscar capitanes disponibles
    SELECT *
    INTO capitanes_disponibles
    FROM get_capitanes_disponibles_para_cotizacion(
        (cotizacion_data.punto_partida->>'lat')::DECIMAL,
        (cotizacion_data.punto_partida->>'lon')::DECIMAL
    )
    LIMIT 1;
    
    -- Si no hay capitanes disponibles
    IF capitanes_disponibles IS NULL THEN
        RETURN QUERY SELECT NULL, 0.0, FALSE, 'No hay capitanes disponibles en esta zona';
        RETURN;
    END IF;
    
    -- Asignar capitán a la cotización
    UPDATE cotizaciones
    SET capitan_id = capitanes_disponibles.capitan_id,
        updated_at = NOW()
    WHERE id = p_cotizacion_id;
    
    -- Retornar resultado exitoso
    RETURN QUERY 
    SELECT 
        capitanes_disponibles.capitan_id,
        capitanes_disponibles.distancia_km,
        TRUE,
        'Capitán asignado exitosamente';
END;
$$ LANGUAGE plpgsql;

-- Función para crear cotización con asignación automática
CREATE OR REPLACE FUNCTION crear_cotizacion_con_asignacion(
    p_pescador_id UUID,
    p_descripcion TEXT,
    p_punto_partida JSONB,
    p_punto_destino JSONB DEFAULT NULL
)
RETURNS TABLE (
    cotizacion_id UUID,
    capitan_asignado UUID,
    asignacion_exitosa BOOLEAN,
    mensaje TEXT
) AS $$
DECLARE
    nueva_cotizacion_id UUID;
    resultado_asignacion RECORD;
BEGIN
    -- Crear cotización sin capitán asignado
    INSERT INTO cotizaciones (
        pescador_id,
        descripcion,
        punto_partida,
        punto_destino,
        estado
    )
    VALUES (
        p_pescador_id,
        p_descripcion,
        p_punto_partida,
        p_punto_destino,
        'pendiente'
    )
    RETURNING id INTO nueva_cotizacion_id;
    
    -- Intentar asignar capitán automáticamente
    SELECT *
    INTO resultado_asignacion
    FROM asignar_capitan_a_cotizacion(nueva_cotizacion_id);
    
    -- Retornar resultado
    RETURN QUERY 
    SELECT 
        nueva_cotizacion_id,
        resultado_asignacion.capitan_asignado,
        resultado_asignacion.asignacion_exitosa,
        resultado_asignacion.mensaje;
END;
$$ LANGUAGE plpgsql;

-- Vista para monitorear capitanes disponibles
CREATE OR REPLACE VIEW vw_capitanes_disponibles AS
SELECT 
    p.user_id,
    COALESCE(p.telefono_contacto, 'Capitán ' || SUBSTRING(p.user_id::TEXT, 1, 8)) as nombre,
    p.disponible,
    p.radio_operacion_km,
    p.centro_operacion_lat_long,
    p.limite_respuesta_minutos,
    p.telefono_contacto,
    CASE 
        WHEN p.centro_operacion_lat_long IS NULL THEN 'Sin configurar'
        WHEN NOT p.disponible THEN 'No disponible'
        ELSE 'Disponible'
    END as estado_operativo,
    CASE 
        WHEN p.centro_operacion_lat_long IS NULL THEN 'grey'
        WHEN NOT p.disponible THEN 'red'
        ELSE 'green'
    END as color_estado
FROM profiles p
WHERE p.es_capitan = TRUE;

-- Trigger para actualizar timestamps de disponibilidad
CREATE OR REPLACE FUNCTION actualizar_disponibilidad_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_disponibilidad_timestamp
    BEFORE UPDATE ON profiles
    FOR EACH ROW
    WHEN (OLD.disponible IS DISTINCT FROM NEW.disponible)
    EXECUTE FUNCTION actualizar_disponibilidad_timestamp();

-- Insertar datos de ejemplo para capitanes con geofencing
UPDATE profiles 
SET 
    radio_operacion_km = 30.0,
    centro_operacion_lat_long = '{"lat": -34.6037, "lon": -58.3816, "nombre": "Buenos Aires"}',
    disponible = TRUE
WHERE user_id = '22222222-2222-2222-2222-222222222222' AND es_capitan = TRUE;

-- Crear un segundo capitán de ejemplo
INSERT INTO profiles (
    user_id, es_capitan, radio_operacion_km, centro_operacion_lat_long, 
    disponible, telefono_contacto, dni, telefono
) VALUES (
    '55555555-5555-5555-5555-555555555555', 
    TRUE, 
    25.0, 
    '{"lat": -34.9011, "lon": -57.9250, "nombre": "La Plata"}',
    TRUE,
    '+54911-2222-3333',
    '99999999',
    '+54911-2222-3333'
) ON CONFLICT (user_id) DO UPDATE SET
    es_capitan = TRUE,
    radio_operacion_km = EXCLUDED.radio_operacion_km,
    centro_operacion_lat_long = EXCLUDED.centro_operacion_lat_long,
    disponible = EXCLUDED.disponible;

-- Políticas de seguridad para geofencing
CREATE POLICY "Capitanes configurar su geofencing"
ON profiles FOR UPDATE
USING (auth.uid() = user_id AND es_capitan = TRUE);

CREATE POLICY "Publicar capitanes disponibles"
ON profiles FOR SELECT
USING (es_capitan = TRUE AND disponible = TRUE);

-- Función para obtener estadísticas de cobertura
CREATE OR REPLACE FUNCTION get_estadisticas_cobertura()
RETURNS TABLE (
    total_capitanes INTEGER,
    capitanes_disponibles INTEGER,
    capitanes_con_geofencing INTEGER,
    cobertura_total_km DECIMAL,
    radio_promedio_km DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_capitanes,
        COUNT(*) FILTER (WHERE disponible = TRUE) as capitanes_disponibles,
        COUNT(*) FILTER (WHERE centro_operacion_lat_long IS NOT NULL) as capitanes_con_geofencing,
        COALESCE(SUM(radio_operacion_km), 0) as cobertura_total_km,
        COALESCE(AVG(radio_operacion_km), 0) as radio_promedio_km
    FROM profiles
    WHERE es_capitan = TRUE;
END;
$$ LANGUAGE plpgsql;
