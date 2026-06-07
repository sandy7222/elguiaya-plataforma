-- Función para obtener datos de mapa de calor de capitanes
CREATE OR REPLACE FUNCTION get_mapa_calor_capitanes()
RETURNS TABLE (
    capitan_id UUID,
    nombre VARCHAR,
    disponible BOOLEAN,
    centro_lat DECIMAL,
    centro_lon DECIMAL,
    radio_km DECIMAL,
    color_hex VARCHAR,
    opacidad DECIMAL,
    cantidad_cotizaciones INTEGER,
    ultima_actividad TIMESTAMP WITH TIME ZONE
) AS $$
DECLARE
    hoy DATE := CURRENT_DATE;
BEGIN
    RETURN QUERY
    SELECT 
        p.user_id as capitan_id,
        COALESCE(p.telefono_contacto, 'Capitán ' || SUBSTRING(p.user_id::TEXT, 1, 8)) as nombre,
        p.disponible,
        (p.centro_operacion_lat_long->>'lat')::DECIMAL as centro_lat,
        (p.centro_operacion_lat_long->>'lon')::DECIMAL as centro_lon,
        COALESCE(p.radio_operacion_km, 25.0) as radio_km,
        CASE 
            WHEN p.disponible = TRUE THEN '#1565C0'  -- Azul náutico para activos
            ELSE '#64748B'  -- Gris para descanso
        END as color_hex,
        CASE 
            WHEN p.disponible = TRUE THEN 0.7  -- Más opaco para activos
            ELSE 0.3  -- Menos opaco para descanso
        END as opacidad,
        COALESCE(cantidad.cotizaciones_hoy, 0) as cantidad_cotizaciones,
        p.updated_at as ultima_actividad
    FROM profiles p
    LEFT JOIN (
        SELECT 
            capitan_id,
            COUNT(*) as cotizaciones_hoy
        FROM cotizaciones
        WHERE DATE(created_at) = hoy
        AND estado IN ('presupuestado', 'aceptado', 'rechazado')
        GROUP BY capitan_id
    ) cantidad ON p.user_id = cantidad.capitan_id
    WHERE p.es_capitan = TRUE
    AND p.centro_operacion_lat_long IS NOT NULL
    ORDER BY 
        CASE WHEN p.disponible = TRUE THEN 0 ELSE 1 END,
        p.updated_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para registrar cotizaciones huérfanas
CREATE OR REPLACE FUNCTION registrar_cotizacion_huerfana(
    p_cotizacion_id UUID,
    p_pescador_id UUID,
    p_lat_partida DECIMAL,
    p_lon_partida DECIMAL,
    p_descripcion TEXT
)
RETURNS VOID AS $$
DECLARE
    capitanes_cercanos INTEGER;
BEGIN
    -- Contar capitanes disponibles en un radio ampliado (50km)
    SELECT COUNT(*)
    INTO capitanes_cercanos
    FROM profiles
    WHERE es_capitan = TRUE
    AND disponible = TRUE
    AND centro_operacion_lat_long IS NOT NULL
    AND distancia_entre_puntos(
        (centro_operacion_lat_long->>'lat')::DECIMAL,
        (centro_operacion_lat_long->>'lon')::DECIMAL,
        p_lat_partida,
        p_lon_partida
    ) <= 50.0;
    
    -- Si no hay capitanes ni siquiera en 50km, registrar como huérfana
    IF capitanes_cercanos = 0 THEN
        INSERT INTO logs_sistema (
            tipo,
            descripcion,
            user_id,
            cotizacion_id,
            datos_adicionales,
            created_at
        ) VALUES (
            'cotizacion_huerfana',
            'Cotización sin capitanes disponibles en zona amplia',
            p_pescador_id,
            p_cotizacion_id,
            jsonb_build_object(
                'lat_partida', p_lat_partida,
                'lon_partida', p_lon_partida,
                'descripcion', p_descripcion,
                'radio_busqueda_km', 50,
                'capitanes_cercanos', capitanes_cercanos,
                'timestamp', NOW()
            ),
            NOW()
        );
        
        -- También crear alerta de negocio para análisis comercial
        INSERT INTO alertas_negocio (
            tipo,
            cotizacion_id,
            pescador_id,
            descripcion,
            datos_adicionales,
            notificada,
            created_at
        ) VALUES (
            'zona_sin_cobertura',
            p_cotizacion_id,
            p_pescador_id,
            'Zona sin cobertura de capitanes detectada',
            jsonb_build_object(
                'lat_partida', p_lat_partida,
                'lon_partida', p_lon_partida,
                'radio_busqueda_km', 50,
                'analisis_comercial', TRUE
            ),
            FALSE,
            NOW()
        );
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Trigger para detectar cotizaciones huérfanas
CREATE OR REPLACE FUNCTION detectar_cotizaciones_huerfanas()
RETURNS TRIGGER AS $$
DECLARE
    lat_partida DECIMAL;
    lon_partida DECIMAL;
BEGIN
    -- Solo para cotizaciones sin capitán asignado
    IF NEW.capitan_id IS NULL AND NEW.punto_partida IS NOT NULL THEN
        lat_partida := (NEW.punto_partida->>'lat')::DECIMAL;
        lon_partida := (NEW.punto_partida->>'lon')::DECIMAL;
        
        -- Registrar como huérfana si corresponde
        PERFORM registrar_cotizacion_huerfana(
            NEW.id,
            NEW.pescador_id,
            lat_partida,
            lon_partida,
            NEW.descripcion
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para detectar cotizaciones huérfanas
CREATE TRIGGER trigger_detectar_cotizaciones_huerfanas
    AFTER INSERT ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION detectar_cotizaciones_huerfanas();

-- Vista para análisis de cobertura
CREATE OR REPLACE VIEW vw_analisis_cobertura AS
SELECT 
    DATE(created_at) as fecha,
    COUNT(*) as total_cotizaciones,
    COUNT(*) FILTER (WHERE capitan_id IS NOT NULL) as cotizaciones_asignadas,
    COUNT(*) FILTER (WHERE capitan_id IS NULL) as cotizaciones_huerfanas,
    CASE 
        WHEN COUNT(*) > 0 THEN 
            (COUNT(*) FILTER (WHERE capitan_id IS NOT NULL) * 100.0 / COUNT(*))
        ELSE 0 
    END as porcentaje_asignacion
FROM cotizaciones
WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
GROUP BY DATE(created_at)
ORDER BY fecha DESC;

-- Función para obtener estadísticas de cobertura en tiempo real
CREATE OR REPLACE FUNCTION get_estadisticas_cobertura_tiempo_real()
RETURNS TABLE (
    total_capitanes INTEGER,
    capitanes_activos INTEGER,
    capitanes_en_descanso INTEGER,
    cobertura_total_km2 DECIMAL,
    zonas_con_cobertura INTEGER,
    cotizaciones_hoy INTEGER,
    cotizaciones_huerfanas_hoy INTEGER,
    porcentaje_cobertura DECIMAL
) AS $$
DECLARE
    hoy DATE := CURRENT_DATE;
BEGIN
    RETURN QUERY
    WITH capitanes_con_radio AS (
        SELECT 
            user_id,
            disponible,
            COALESCE(radio_operacion_km, 25.0) as radio,
            centro_operacion_lat_long
        FROM profiles
        WHERE es_capitan = TRUE
        AND centro_operacion_lat_long IS NOT NULL
    ),
    zonas_cubiertas AS (
        SELECT 
            COUNT(DISTINCT user_id) as zonas_con_cobertura
        FROM capitanes_con_radio
    ),
    cotizaciones_hoy AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE capitan_id IS NULL) as huerfanas
        FROM cotizaciones
        WHERE DATE(created_at) = hoy
    )
    SELECT 
        COUNT(*) as total_capitanes,
        COUNT(*) FILTER (WHERE disponible = TRUE) as capitanes_activos,
        COUNT(*) FILTER (WHERE disponible = FALSE) as capitanes_en_descanso,
        COALESCE(SUM(PI() * POWER(radio, 2)), 0) as cobertura_total_km2,
        (SELECT zonas_con_cobertura FROM zonas_cubiertas) as zonas_con_cobertura,
        (SELECT total FROM cotizaciones_hoy) as cotizaciones_hoy,
        (SELECT huerfanas FROM cotizaciones_hoy) as cotizaciones_huerfanas_hoy,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                (COUNT(*) FILTER (WHERE disponible = TRUE) * 100.0 / COUNT(*))
            ELSE 0 
        END as porcentaje_cobertura
    FROM capitanes_con_radio;
END;
$$ LANGUAGE plpgsql;

-- Función para optimizar matchmaking con pulso de tiempo real
CREATE OR REPLACE FUNCTION matchmaking_con_pulso(
    p_pescador_id UUID,
    p_descripcion TEXT,
    p_punto_partida JSONB,
    p_punto_destino JSONB DEFAULT NULL
)
RETURNS TABLE (
    cotizacion_id UUID,
    capitan_asignado UUID,
    asignacion_exitosa BOOLEAN,
    mensaje TEXT,
    pulso_enviado BOOLEAN
) AS $$
DECLARE
    nueva_cotizacion_id UUID;
    resultado_asignacion RECORD;
    capitan_asignado_id UUID;
    lat_partida DECIMAL;
    lon_partida DECIMAL;
BEGIN
    -- Extraer coordenadas
    lat_partida := (p_punto_partida->>'lat')::DECIMAL;
    lon_partida := (p_punto_destino->>'lon')::DECIMAL;
    
    -- Crear cotización
    INSERT INTO cotizaciones (
        pescador_id, descripcion, punto_partida, punto_destino, estado
    )
    VALUES (p_pescador_id, p_descripcion, p_punto_partida, p_punto_destino, 'pendiente')
    RETURNING id INTO nueva_cotizacion_id;
    
    -- Realizar matchmaking
    SELECT *
    INTO resultado_asignacion
    FROM asignar_capitan_a_cotizacion(nueva_cotizacion_id);
    
    capitan_asignado_id := resultado_asignacion.capitan_asignado;
    
    -- Si hay capitán asignado, enviar pulso de tiempo real
    IF capitan_asignado_id IS NOT NULL THEN
        -- Registrar pulso enviado
        INSERT INTO logs_sistema (
            tipo,
            descripcion,
            user_id,
            cotizacion_id,
            datos_adicionales,
            created_at
        ) VALUES (
            'pulso_matchmaking',
            'Pulso de tiempo real enviado a capitán',
            capitan_asignado_id,
            nueva_cotizacion_id,
            jsonb_build_object(
                'pescador_id', p_pescador_id,
                'lat_partida', lat_partida,
                'lon_partida', lon_partida,
                'timestamp', NOW()
            ),
            NOW()
        );
        
        RETURN QUERY 
        SELECT 
            nueva_cotizacion_id,
            capitan_asignado_id,
            TRUE,
            'Capitán asignado y notificado',
            TRUE;
    ELSE
        -- No hay capitán disponible, registrar como huérfana
        PERFORM registrar_cotizacion_huerfana(
            nueva_cotizacion_id, p_pescador_id, lat_partida, lon_partida, p_descripcion
        );
        
        RETURN QUERY 
        SELECT 
            nueva_cotizacion_id,
            NULL,
            FALSE,
            'No hay capitanes disponibles en la zona',
            FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Actualizar función principal para usar matchmaking con pulso
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
BEGIN
    RETURN QUERY
    SELECT *
    FROM matchmaking_con_pulso(p_pescador_id, p_descripcion, p_punto_partida, p_punto_destino);
END;
$$ LANGUAGE plpgsql;
