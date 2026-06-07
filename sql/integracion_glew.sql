-- Sistema de Integración con Glew para Notificaciones Administrativas

-- Crear tabla para registrar notificaciones enviadas a Glew
CREATE TABLE IF NOT EXISTS notificaciones_glew (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    evento VARCHAR(50) NOT NULL, -- 'presupuesto_enviado', 'cotizacion_aceptada', 'viaje_realizado', etc.
    datos JSONB NOT NULL, -- Payload completo enviado a Glew
    estado VARCHAR(20) DEFAULT 'enviado', -- 'enviado', 'fallido', 'reenviado', 'pendiente'
    enviado_at TIMESTAMP WITH TIME ZONE,
    error TEXT, -- Mensaje de error si falló
    reintentos INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_notificaciones_glew_evento ON notificaciones_glew(evento);
CREATE INDEX IF NOT EXISTS idx_notificaciones_glew_estado ON notificaciones_glew(estado);
CREATE INDEX IF NOT EXISTS idx_notificaciones_glew_enviado_at ON notificaciones_glew(enviado_at);
CREATE INDEX IF NOT EXISTS idx_notificaciones_glew_datos_cotizacion_id ON notificaciones_glew USING GIN ((datos->'cotizacion_id'));
CREATE INDEX IF NOT EXISTS idx_notificaciones_glew_datos_capitan_id ON notificaciones_glew USING GIN ((datos->'capitan_id'));

-- Constraints
ALTER TABLE notificaciones_glew 
ADD CONSTRAINT chk_estado_notificacion_glew 
CHECK (estado IN ('enviado', 'fallido', 'reenviado', 'pendiente'));

ALTER TABLE notificaciones_glew 
ADD CONSTRAINT chk_reintentos_notificacion_glew 
CHECK (reintentos >= 0 AND reintentos <= 5);

-- Función para registrar notificación enviada a Glew
CREATE OR REPLACE FUNCTION registrar_notificacion_glew(
    p_evento VARCHAR,
    p_datos JSONB,
    p_estado VARCHAR DEFAULT 'enviado'
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    notificacion_id UUID
) AS $$
DECLARE
    nueva_notificacion_id UUID;
BEGIN
    -- Insertar registro de notificación
    INSERT INTO notificaciones_glew (
        evento, datos, estado, enviado_at, created_at
    ) VALUES (
        p_evento, p_datos, p_estado, 
        CASE WHEN p_estado = 'enviado' THEN NOW() ELSE NULL END,
        NOW()
    )
    RETURNING id INTO nueva_notificacion_id;
    
    RETURN QUERY SELECT TRUE, 'Notificación registrada exitosamente', nueva_notificacion_id;
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar estado de notificación Glew
CREATE OR REPLACE FUNCTION actualizar_estado_notificacion_glew(
    p_notificacion_id UUID,
    p_nuevo_estado VARCHAR,
    p_error TEXT DEFAULT NULL
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT
) AS $$
BEGIN
    UPDATE notificaciones_glew
    SET 
        estado = p_nuevo_estado,
        error = p_error,
        reintentos = CASE 
            WHEN p_nuevo_estado = 'fallido' THEN reintentos + 1
            ELSE reintentos
        END,
        updated_at = NOW()
    WHERE id = p_notificacion_id;
    
    RETURN QUERY SELECT TRUE, 'Estado actualizado exitosamente';
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas de notificaciones Glew
CREATE OR REPLACE FUNCTION get_estadisticas_notificaciones_glew(
    p_fecha_desde TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    p_fecha_hasta TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
    total_enviadas BIGINT,
    total_exitosas BIGINT,
    total_fallidas BIGINT,
    tasa_exito DECIMAL,
    eventos_mas_comunes JSONB,
    errores_frecuentes JSONB,
    promedio_reintentos DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    WITH estadisticas AS (
        SELECT 
            COUNT(*) as total,
            COUNT(*) FILTER (WHERE estado = 'enviado') as exitosas,
            COUNT(*) FILTER (WHERE estado = 'fallido') as fallidas,
            AVG(reintentos) as avg_reintentos
        FROM notificaciones_glew
        WHERE created_at BETWEEN p_fecha_desde AND p_fecha_hasta
    ),
    eventos AS (
        SELECT 
            evento,
            COUNT(*) as cantidad
        FROM notificaciones_glew
        WHERE created_at BETWEEN p_fecha_desde AND p_fecha_hasta
        GROUP BY evento
        ORDER BY cantidad DESC
        LIMIT 5
    ),
    errores AS (
        SELECT 
            error,
            COUNT(*) as cantidad
        FROM notificaciones_glew
        WHERE created_at BETWEEN p_fecha_desde AND p_fecha_hasta
        AND error IS NOT NULL
        GROUP BY error
        ORDER BY cantidad DESC
        LIMIT 5
    )
    SELECT 
        s.total,
        s.exitosas,
        s.fallidas,
        CASE 
            WHEN s.total > 0 THEN (s.exitosas::DECIMAL / s.total::DECIMAL) * 100
            ELSE 0
        END as tasa_exito,
        COALESCE(jsonb_agg(jsonb_build_object('evento', evento, 'cantidad', cantidad)), '[]'::jsonb) as eventos_mas_comunes,
        COALESCE(jsonb_agg(jsonb_build_object('error', error, 'cantidad', cantidad)), '[]'::jsonb) as errores_frecuentes,
        COALESCE(s.avg_reintentos, 0) as promedio_reintentos
    FROM estadisticas s
    LEFT JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('evento', evento, 'cantidad', cantidad)) as eventos_mas_comunes FROM eventos) e ON true
    LEFT JOIN LATERAL (SELECT jsonb_agg(jsonb_build_object('error', error, 'cantidad', cantidad)) as errores_frecuentes FROM errores) err ON true;
END;
$$ LANGUAGE plpgsql;

-- Vista para monitoreo de notificaciones Glew
CREATE OR REPLACE VIEW vw_monitoreo_glew AS
SELECT 
    id,
    evento,
    estado,
    enviado_at,
    error,
    reintentos,
    datos->'cotizacion_id' as cotizacion_id,
    datos->'capitan_id' as capitan_id,
    datos->'pescador_id' as pescador_id,
    datos->'presupuesto' as presupuesto,
    datos->'respuesta' as respuesta,
    datos->'metadata' as metadata,
    datos->'source' as source,
    datos->'environment' as environment,
    created_at,
    updated_at,
    CASE 
        WHEN estado = 'enviado' THEN '✅ Enviado'
        WHEN estado = 'fallido' THEN '❌ Fallido'
        WHEN estado = 'reenviado' THEN '🔄 Reenviado'
        WHEN estado = 'pendiente' THEN '⏳ Pendiente'
        ELSE '❓ Desconocido'
    END as estado_formateado,
    CASE 
        WHEN estado = 'enviado' THEN '#10B981'
        WHEN estado = 'fallido' THEN '#EF4444'
        WHEN estado = 'reenviado' THEN '#F59E0B'
        WHEN estado = 'pendiente' THEN '#6B7280'
        ELSE '#9CA3AF'
    END as color_estado,
    CASE 
        WHEN reintentos = 0 THEN 'Sin reintentos'
        WHEN reintentos = 1 THEN '1 reintento'
        ELSE CONCAT(reintentos, ' reintentos')
    END as reintentos_formateado
FROM notificaciones_glew
ORDER BY created_at DESC;

-- Función para obtener notificaciones recientes para admin
CREATE OR REPLACE FUNCTION get_notificaciones_recientes_glew(
    p_limite INTEGER DEFAULT 50,
    p_evento_filtro VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    id UUID,
    evento VARCHAR,
    estado VARCHAR,
    estado_formateado TEXT,
    color_estado TEXT,
    cotizacion_id UUID,
    presupuesto DECIMAL,
    enviado_at TIMESTAMP WITH TIME ZONE,
    reintentos INTEGER,
    error TEXT,
    metadata JSONB
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ng.id,
        ng.evento,
        ng.estado,
        CASE 
            WHEN ng.estado = 'enviado' THEN '✅ Enviado'
            WHEN ng.estado = 'fallido' THEN '❌ Fallido'
            WHEN ng.estado = 'reenviado' THEN '🔄 Reenviado'
            WHEN ng.estado = 'pendiente' THEN '⏳ Pendiente'
            ELSE '❓ Desconocido'
        END as estado_formateado,
        CASE 
            WHEN ng.estado = 'enviado' THEN '#10B981'
            WHEN ng.estado = 'fallido' THEN '#EF4444'
            WHEN ng.estado = 'reenviado' THEN '#F59E0B'
            WHEN ng.estado = 'pendiente' THEN '#6B7280'
            ELSE '#9CA3AF'
        END as color_estado,
        ng.datos->>'cotizacion_id' as cotizacion_id,
        (ng.datos->>'presupuesto')::DECIMAL as presupuesto,
        ng.enviado_at,
        ng.reintentos,
        ng.error,
        ng.datos->'metadata' as metadata
    FROM notificaciones_glew ng
    WHERE (p_evento_filtro IS NULL OR ng.evento = p_evento_filtro)
    ORDER BY ng.created_at DESC
    LIMIT p_limite;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar timestamp automáticamente
CREATE OR REPLACE FUNCTION trigger_actualizar_timestamp_notificacion_glew()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_timestamp_notificacion_glew
    BEFORE UPDATE ON notificaciones_glew
    FOR EACH ROW
    EXECUTE FUNCTION trigger_actualizar_timestamp_notificacion_glew();

-- Función para limpiar notificaciones antiguas
CREATE OR REPLACE FUNCTION limpiar_notificaciones_antiguas_glew(
    p_dias INTEGER DEFAULT 90
)
RETURNS TABLE (
    eliminados INTEGER,
    mensaje TEXT
) AS $$
DECLARE
    cantidad_eliminada INTEGER;
BEGIN
    DELETE FROM notificaciones_glew
    WHERE created_at < NOW() - INTERVAL '1 day' * p_dias
    AND estado IN ('enviado', 'reenviado'); -- Solo limpiar las exitosas
    
    GET DIAGNOSTICS cantidad_eliminada = ROW_COUNT;
    
    RETURN QUERY SELECT cantidad_eliminada, 
        CONCAT('Notificaciones antiguas eliminadas: ', cantidad_eliminada);
END;
$$ LANGUAGE plpgsql;

-- Insertar datos de ejemplo
INSERT INTO notificaciones_glew (
    evento, datos, estado, enviado_at, created_at
) VALUES 
(
    'presupuesto_enviado',
    jsonb_build_object(
        'cotizacion_id', '11111111-1111-1111-1111-111111111111',
        'capitan_id', '22222222-2222-2222-2222-222222222222',
        'pescador_id', '33333333-3333-3333-3333-333333333333',
        'presupuesto', 50000.00,
        'respuesta', 'Excelente día para la pesca',
        'timestamp', NOW(),
        'metadata', jsonb_build_object('lugar', 'Puerto de Mar del Plata', 'personas', 4),
        'source', 'capitanya_mobile',
        'environment', 'development'
    ),
    'enviado',
    NOW(),
    NOW()
),
(
    'presupuesto_enviado',
    jsonb_build_object(
        'cotizacion_id', '44444444-4444-4444-4444-444444444444',
        'capitan_id', '22222222-2222-2222-2222-222222222222',
        'pescador_id', '55555555-5555-5555-5555-555555555555',
        'presupuesto', 75000.00,
        'respuesta', 'Viaje completo con equipo',
        'timestamp', NOW() - INTERVAL '1 hour',
        'metadata', jsonb_build_object('lugar', 'Puerto Quequén', 'personas', 6),
        'source', 'capitanya_mobile',
        'environment', 'development'
    ),
    'enviado',
    NOW() - INTERVAL '1 hour',
    NOW() - INTERVAL '1 hour'
),
(
    'presupuesto_enviado',
    jsonb_build_object(
        'cotizacion_id', '66666666-6666-6666-6666-666666666666',
        'capitan_id', '22222222-2222-2222-2222-222222222222',
        'pescador_id', '77777777-7777-7777-7777-777777777777',
        'presupuesto', 45000.00,
        'respuesta', 'Aventura inolvidable garantizada',
        'timestamp', NOW() - INTERVAL '2 hours',
        'metadata', jsonb_build_object('lugar', 'Bahía Blanca', 'personas', 3),
        'source', 'capitanya_mobile',
        'environment', 'development'
    ),
    'fallido',
    NULL,
    NOW() - INTERVAL '2 hours'
)
ON CONFLICT DO NOTHING;

-- Políticas de seguridad
CREATE POLICY "Admin puede ver todas las notificaciones Glew"
ON notificaciones_glew FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede insertar notificaciones Glew"
ON notificaciones_glew FOR INSERT
WITH CHECK (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede actualizar notificaciones Glew"
ON notificaciones_glew FOR UPDATE
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede ver vista de monitoreo Glew"
ON vw_monitoreo_glew FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));
