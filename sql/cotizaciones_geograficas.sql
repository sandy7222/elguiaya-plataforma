-- Agregar columnas geográficas a la tabla cotizaciones
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS punto_partida JSONB;
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS punto_destino JSONB;
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS distancia_km DECIMAL(10,2);
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS distancia_millas DECIMAL(10,2);
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS duracion_estimada_minutos INTEGER;

-- Crear índices para optimización geográfica
CREATE INDEX IF NOT EXISTS idx_cotizaciones_punto_partida ON cotizaciones USING GIN (punto_partida);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_punto_destino ON cotizaciones USING GIN (punto_destino);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_distancia_km ON cotizaciones(distancia_km);

-- Función para calcular distancia entre dos puntos usando la fórmula de Haversine
CREATE OR REPLACE FUNCTION calcular_distancia_km(
    lat1 DECIMAL, 
    lon1 DECIMAL, 
    lat2 DECIMAL, 
    lon2 DECIMAL
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    earth_radius_km DECIMAL := 6371.0; -- Radio de la Tierra en kilómetros
    dlat DECIMAL;
    dlon DECIMAL;
    a DECIMAL;
    c DECIMAL;
    distance_km DECIMAL;
BEGIN
    -- Convertir a radianes
    dlat := RADIANS(lat2 - lat1);
    dlon := RADIANS(lon2 - lon1);
    
    -- Fórmula de Haversine
    a := SIN(dlat / 2) * SIN(dlat / 2) + 
         COS(RADIANS(lat1)) * COS(RADIANS(lat2)) * 
         SIN(dlon / 2) * SIN(dlon / 2);
    
    c := 2 * ATAN2(SQRT(a), SQRT(1 - a));
    distance_km := earth_radius_km * c;
    
    RETURN ROUND(distance_km, 2);
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar distancia y duración de una cotización
CREATE OR REPLACE FUNCTION actualizar_datos_geograficos()
RETURNS TRIGGER AS $$
DECLARE
    partida_lat DECIMAL;
    partida_lon DECIMAL;
    destino_lat DECIMAL;
    destino_lon DECIMAL;
    distancia_km_calculada DECIMAL;
    velocidad_promedio_kmh DECIMAL := 20.0; -- Velocidad promedio de lancha en km/h
BEGIN
    -- Extraer coordenadas si existen ambos puntos
    IF NEW.punto_partida IS NOT NULL AND NEW.punto_destino IS NOT NULL THEN
        -- Obtener coordenadas de punto_partida
        partida_lat := (NEW.punto_partida->>'lat')::DECIMAL;
        partida_lon := (NEW.punto_partida->>'lon')::DECIMAL;
        
        -- Obtener coordenadas de punto_destino
        destino_lat := (NEW.punto_destino->>'lat')::DECIMAL;
        destino_lon := (NEW.punto_destino->>'lon')::DECIMAL;
        
        -- Calcular distancia en kilómetros
        distancia_km_calculada := calcular_distancia_km(partida_lat, partida_lon, destino_lat, destino_lon);
        
        -- Actualizar campos
        NEW.distancia_km := distancia_km_calculada;
        NEW.distancia_millas := ROUND(distancia_km_calculada * 0.621371, 2); -- Convertir a millas
        NEW.duracion_estimada_minutos := ROUND((distancia_km_calculada / velocidad_promedio_kmh) * 60, 0);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para actualizar datos geográficos automáticamente
CREATE TRIGGER trigger_actualizar_datos_geograficos
    BEFORE INSERT OR UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_datos_geograficos();

-- Función para calcular presupuesto base basado en distancia
CREATE OR REPLACE FUNCTION calcular_presupuesto_base(p_distancia_km DECIMAL)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    base_fijo DECIMAL := 50.0; -- Cargo base fijo
    costo_por_km DECIMAL := 8.0; -- $8 por kilómetro
    presupuesto_calculado DECIMAL;
BEGIN
    presupuesto_calculado := base_fijo + (p_distancia_km * costo_por_km);
    RETURN ROUND(presupuesto_calculado, 2);
END;
$$ LANGUAGE plpgsql;

-- Función para obtener cotizaciones con datos geográficos
CREATE OR REPLACE FUNCTION get_cotizaciones_con_geografia(p_capitan_id UUID)
RETURNS TABLE (
    cotizacion_id UUID,
    descripcion TEXT,
    estado VARCHAR(20),
    punto_partida JSONB,
    punto_destino JSONB,
    distancia_km DECIMAL,
    distancia_millas DECIMAL,
    duracion_estimada_minutos INTEGER,
    presupuesto_base DECIMAL,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.descripcion,
        c.estado,
        c.punto_partida,
        c.punto_destino,
        c.distancia_km,
        c.distancia_millas,
        c.duracion_estimada_minutos,
        calcular_presupuesto_base(c.distancia_km) as presupuesto_base,
        c.created_at
    FROM cotizaciones c
    WHERE c.capitan_id = p_capitan_id
    AND c.punto_partida IS NOT NULL
    AND c.punto_destino IS NOT NULL
    ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas geográficas del capitán
CREATE OR REPLACE FUNCTION get_estadisticas_geograficas(p_capitan_id UUID)
RETURNS TABLE (
    total_viajes INTEGER,
    distancia_total_km DECIMAL,
    distancia_promedio_km DECIMAL,
    viaje_mas_largo_km DECIMAL,
    viaje_mas_corto_km DECIMAL,
    tiempo_total_estimado_horas DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_viajes,
        COALESCE(SUM(distancia_km), 0) as distancia_total_km,
        COALESCE(AVG(distancia_km), 0) as distancia_promedio_km,
        COALESCE(MAX(distancia_km), 0) as viaje_mas_largo_km,
        COALESCE(MIN(distancia_km), 0) as viaje_mas_corto_km,
        COALESCE(SUM(duracion_estimada_minutos) / 60.0, 0) as tiempo_total_estimado_horas
    FROM cotizaciones
    WHERE capitan_id = p_capitan_id
    AND estado IN ('presupuestado', 'aceptado')
    AND distancia_km IS NOT NULL
    AND punto_partida IS NOT NULL
    AND punto_destino IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Vista para cotizaciones con información geográfica completa
CREATE OR REPLACE VIEW vw_cotizaciones_geograficas AS
SELECT 
    c.*,
    calcular_presupuesto_base(c.distancia_km) as presupuesto_sugerido,
    CASE 
        WHEN c.distancia_km <= 10 THEN 'Corto'
        WHEN c.distancia_km <= 30 THEN 'Medio'
        WHEN c.distancia_km <= 60 THEN 'Largo'
        ELSE 'Muy Largo'
    END as categoria_viaje,
    CASE 
        WHEN c.distancia_km <= 10 THEN '#4CAF50'
        WHEN c.distancia_km <= 30 THEN '#FF9800'
        WHEN c.distancia_km <= 60 THEN '#FF5722'
        ELSE '#F44336'
    END as color_categoria
FROM cotizaciones c
WHERE c.punto_partida IS NOT NULL 
AND c.punto_destino IS NOT NULL;

-- Actualizar cotizaciones existentes con datos de ejemplo
UPDATE cotizaciones 
SET 
    punto_partida = '{"lat": -34.6037, "lon": -58.3816, "nombre": "Buenos Aires"}',
    punto_destino = '{"lat": -34.9011, "lon": -57.9250, "nombre": "La Plata"}'
WHERE id = '11111111-1111-1111-1111-111111111111' AND punto_partida IS NULL;

UPDATE cotizaciones 
SET 
    punto_partida = '{"lat": -34.6037, "lon": -58.3816, "nombre": "Buenos Aires"}',
    punto_destino = '{"lat": -34.9205, "lon": -57.9536, "nombre": "Ensenada"}'
WHERE id = '33333333-3333-3333-3333-333333333333' AND punto_partida IS NULL;

-- Políticas de seguridad para datos geográficos
CREATE POLICY "Capitanes ver datos geográficos"
ON cotizaciones FOR SELECT
USING (auth.uid() = capitan_id);

CREATE POLICY "Pescadores ver sus datos geográficos"
ON cotizaciones FOR SELECT
USING (auth.uid() = pescador_id);

CREATE POLICY "Pescadores crear datos geográficos"
ON cotizaciones FOR INSERT
WITH CHECK (auth.uid() = pescador_id);
