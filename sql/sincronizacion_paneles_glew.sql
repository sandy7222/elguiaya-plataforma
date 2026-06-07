-- Sistema de Sincronización entre Paneles para Glew
-- Funciones RPC y vistas para el dashboard del Administrador

-- =====================================================
-- FUNCIONES RPC PARA CONTADORES DEL ADMINISTRADOR
-- =====================================================

-- Función principal para obtener contadores del dashboard
CREATE OR REPLACE FUNCTION get_contadores_admin_glew()
RETURNS TABLE (
    pendientes BIGINT,
    cotizados BIGINT,
    aceptados BIGINT,
    rechazados BIGINT,
    confirmados BIGINT,
    pagados BIGINT,
    realizados BIGINT,
    cancelados BIGINT,
    total_general BIGINT,
    ultima_actualizacion TIMESTAMP WITH TIME ZONE,
    tendencias_semanales JSONB,
    alertas_criticas JSONB
) AS $$
DECLARE
    fecha_semana_pasada TIMESTAMP WITH TIME ZONE;
    tendencias JSONB;
    alertas JSONB;
BEGIN
    fecha_semana_pasada := NOW() - INTERVAL '7 days';
    
    -- Calcular tendencias semanales
    tendencias := jsonb_build_object(
        'pendientes_semana_pasada', (
            SELECT COUNT(*) 
            FROM cotizaciones 
            WHERE estado = 'pendiente' 
            AND created_at BETWEEN fecha_semana_pasada AND NOW()
        ),
        'cotizados_semana_pasada', (
            SELECT COUNT(*) 
            FROM cotizaciones 
            WHERE estado = 'cotizado' 
            AND created_at BETWEEN fecha_semana_pasada AND NOW()
        ),
        'aceptados_semana_pasada', (
            SELECT COUNT(*) 
            FROM cotizaciones 
            WHERE estado = 'aceptado' 
            AND created_at BETWEEN fecha_semana_pasada AND NOW()
        ),
        'variacion_pendientes', (
            SELECT 
                CASE 
                    WHEN COUNT(*) FILTER (WHERE created_at >= fecha_semana_pasada) > 0 
                    THEN ((COUNT(*) FILTER (WHERE created_at >= fecha_semana_pasada) - 
                          COUNT(*) FILTER (WHERE created_at < fecha_semana_pasada AND created_at >= fecha_semana_pasada - INTERVAL '7 days'))::DECIMAL / 
                          NULLIF(COUNT(*) FILTER (WHERE created_at < fecha_semana_pasada AND created_at >= fecha_semana_pasada - INTERVAL '7 days'), 0)) * 100
                    ELSE 0
                END
            FROM cotizaciones 
            WHERE estado = 'pendiente' 
            AND created_at >= fecha_semana_pasada - INTERVAL '7 days'
        )
    );
    
    -- Calcular alertas críticas
    alertas := jsonb_build_object(
        'pendientes_sin_respuesta_24h', (
            SELECT COUNT(*) 
            FROM cotizaciones 
            WHERE estado = 'pendiente' 
            AND created_at < NOW() - INTERVAL '24 hours'
        ),
        'cotizados_sin_respuesta_48h', (
            SELECT COUNT(*) 
            FROM cotizaciones 
            WHERE estado = 'cotizado' 
            AND presupuesto_enviado_at < NOW() - INTERVAL '48 hours'
        ),
        'aceptados_sin_pago_72h', (
            SELECT COUNT(*) 
            FROM cotizaciones 
            WHERE estado = 'aceptado' 
            AND updated_at < NOW() - INTERVAL '72 hours'
        ),
        'capitanes_con_baja_tasa_respuesta', (
            SELECT COUNT(DISTINCT capitan_id)
            FROM cotizaciones c
            JOIN profiles p ON c.capitan_id = p.user_id
            WHERE c.created_at > NOW() - INTERVAL '7 days'
            AND p.calificacion_promedio < 3.0
        )
    );
    
    RETURN QUERY
    SELECT 
        COUNT(*) FILTER (WHERE estado = 'pendiente') as pendientes,
        COUNT(*) FILTER (WHERE estado = 'cotizado') as cotizados,
        COUNT(*) FILTER (WHERE estado = 'aceptado') as aceptados,
        COUNT(*) FILTER (WHERE estado = 'rechazado') as rechazados,
        COUNT(*) FILTER (WHERE estado = 'confirmado') as confirmados,
        COUNT(*) FILTER (WHERE estado = 'pagado') as pagados,
        COUNT(*) FILTER (WHERE estado = 'realizado') as realizados,
        COUNT(*) FILTER (WHERE estado = 'cancelado') as cancelados,
        COUNT(*) as total_general,
        NOW() as ultima_actualizacion,
        tendencias as tendencias_semanales,
        alertas as alertas_criticas
    FROM cotizaciones
    WHERE created_at > NOW() - INTERVAL '30 days';
END;
$$ LANGUAGE plpgsql;

-- Función para obtener detalles de cotizaciones por estado
CREATE OR REPLACE FUNCTION get_cotizaciones_por_estado_glew(
    p_estado VARCHAR DEFAULT NULL,
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    pescador_id UUID,
    capitan_id UUID,
    estado VARCHAR,
    descripcion TEXT,
    fecha_ida DATE,
    lugar_encuentro TEXT,
    cantidad_personas INTEGER,
    presupuesto_base DECIMAL,
    respuesta_capitan TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE,
    presupuesto_enviado_at TIMESTAMP WITH TIME ZONE,
    pescador_nombre TEXT,
    capitan_nombre TEXT,
    tiempo_en_estado INTERVAL,
    prioridad VARCHAR,
    color_estado TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.pescador_id,
        c.capitan_id,
        c.estado,
        c.descripcion,
        c.fecha_ida,
        c.lugar_encuentro,
        c.cantidad_personas,
        c.presupuesto_base,
        c.respuesta_capitan,
        c.created_at,
        c.updated_at,
        c.presupuesto_enviado_at,
        p.nombre as pescador_nombre,
        cap.nombre as capitan_nombre,
        CASE 
            WHEN c.estado = 'pendiente' THEN NOW() - c.created_at
            WHEN c.estado = 'cotizado' AND c.presupuesto_enviado_at IS NOT NULL THEN NOW() - c.presupuesto_enviado_at
            WHEN c.estado = 'cotizado' AND c.presupuesto_enviado_at IS NULL THEN NOW() - c.updated_at
            WHEN c.estado = 'aceptado' THEN NOW() - c.updated_at
            WHEN c.estado = 'confirmado' THEN NOW() - c.updated_at
            WHEN c.estado = 'pagado' THEN NOW() - c.updated_at
            ELSE NOW() - c.updated_at
        END as tiempo_en_estado,
        CASE 
            WHEN c.estado = 'pendiente' AND c.created_at < NOW() - INTERVAL '24 hours' THEN 'alta'
            WHEN c.estado = 'cotizado' AND c.presupuesto_enviado_at < NOW() - INTERVAL '48 hours' THEN 'alta'
            WHEN c.estado = 'aceptado' AND c.updated_at < NOW() - INTERVAL '72 hours' THEN 'alta'
            WHEN c.estado = 'pendiente' AND c.created_at < NOW() - INTERVAL '12 hours' THEN 'media'
            WHEN c.estado = 'cotizado' AND c.presupuesto_enviado_at < NOW() - INTERVAL '24 hours' THEN 'media'
            ELSE 'baja'
        END as prioridad,
        CASE 
            WHEN c.estado = 'pendiente' THEN '#F59E0B'
            WHEN c.estado = 'cotizado' THEN '#3B82F6'
            WHEN c.estado = 'aceptado' THEN '#10B981'
            WHEN c.estado = 'rechazado' THEN '#EF4444'
            WHEN c.estado = 'confirmado' THEN '#8B5CF6'
            WHEN c.estado = 'pagado' THEN '#06B6D4'
            WHEN c.estado = 'realizado' THEN '#059669'
            WHEN c.estado = 'cancelado' THEN '#6B7280'
            ELSE '#9CA3AF'
        END as color_estado
    FROM cotizaciones c
    LEFT JOIN profiles p ON c.pescador_id = p.user_id
    LEFT JOIN profiles cap ON c.capitan_id = cap.user_id
    WHERE (p_estado IS NULL OR c.estado = p_estado)
    ORDER BY 
        CASE 
            WHEN c.estado = 'pendiente' AND c.created_at < NOW() - INTERVAL '24 hours' THEN 1
            WHEN c.estado = 'cotizado' AND c.presupuesto_enviado_at < NOW() - INTERVAL '48 hours' THEN 1
            WHEN c.estado = 'aceptado' AND c.updated_at < NOW() - INTERVAL '72 hours' THEN 1
            WHEN c.estado = 'pendiente' THEN 2
            WHEN c.estado = 'cotizado' THEN 3
            ELSE 4
        END,
        c.created_at DESC
    LIMIT p_limite
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener métricas de tiempo de respuesta
CREATE OR REPLACE FUNCTION get_metricas_tiempo_respuesta_glew(
    p_fecha_desde TIMESTAMP WITH TIME ZONE DEFAULT NOW() - INTERVAL '30 days',
    p_fecha_hasta TIMESTAMP WITH TIME ZONE DEFAULT NOW()
)
RETURNS TABLE (
    metrica VARCHAR,
    valor_promedio DECIMAL,
    valor_mediano DECIMAL,
    valor_minimo DECIMAL,
    valor_maximo DECIMAL,
    total_registros BIGINT,
    tendencia VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH tiempos AS (
        SELECT 
            'pendiente_a_cotizado' as metrica,
            EXTRACT(EPOCH FROM (presupuesto_enviado_at - created_at)) / 3600 as horas
        FROM cotizaciones
        WHERE estado IN ('cotizado', 'aceptado', 'confirmado', 'pagado', 'realizado')
        AND presupuesto_enviado_at IS NOT NULL
        AND created_at BETWEEN p_fecha_desde AND p_fecha_hasta
        
        UNION ALL
        
        SELECT 
            'cotizado_a_aceptado' as metrica,
            EXTRACT(EPOCH FROM (updated_at - presupuesto_enviado_at)) / 3600 as horas
        FROM cotizaciones
        WHERE estado IN ('aceptado', 'confirmado', 'pagado', 'realizado')
        AND presupuesto_enviado_at IS NOT NULL
        AND updated_at > presupuesto_enviado_at
        AND presupuesto_enviado_at BETWEEN p_fecha_desde AND p_fecha_hasta
        
        UNION ALL
        
        SELECT 
            'aceptado_a_pagado' as metrica,
            EXTRACT(EPOCH FROM (updated_at - created_at)) / 3600 as horas
        FROM cotizaciones
        WHERE estado IN ('pagado', 'realizado')
        AND updated_at > created_at
        AND created_at BETWEEN p_fecha_desde AND p_fecha_hasta
    )
    SELECT 
        metrica,
        AVG(horas) as valor_promedio,
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY horas) as valor_mediano,
        MIN(horas) as valor_minimo,
        MAX(horas) as valor_maximo,
        COUNT(*) as total_registros,
        CASE 
            WHEN AVG(horas) < 2 THEN 'excelente'
            WHEN AVG(horas) < 6 THEN 'bueno'
            WHEN AVG(horas) < 12 THEN 'regular'
            ELSE 'lento'
        END as tendencia
    FROM tiempos
    GROUP BY metrica
    ORDER BY metrica;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- VISTAS PARA DASHBOARD DE GLEW
-- =====================================================

-- Vista principal para el dashboard del administrador
CREATE OR REPLACE VIEW vw_dashboard_admin_glew AS
SELECT 
    -- Contadores principales
    (SELECT COUNT(*) FILTER (WHERE estado = 'pendiente') FROM cotizaciones WHERE created_at > NOW() - INTERVAL '30 days') as pendientes,
    (SELECT COUNT(*) FILTER (WHERE estado = 'cotizado') FROM cotizaciones WHERE created_at > NOW() - INTERVAL '30 days') as cotizados,
    (SELECT COUNT(*) FILTER (WHERE estado = 'aceptado') FROM cotizaciones WHERE created_at > NOW() - INTERVAL '30 days') as aceptados,
    (SELECT COUNT(*) FILTER (WHERE estado = 'pagado') FROM cotizaciones WHERE created_at > NOW() - INTERVAL '30 days') as pagados,
    
    -- Métricas financieras
    (SELECT COALESCE(SUM(presupuesto_base), 0) FROM cotizaciones WHERE estado = 'pagado' AND created_at > NOW() - INTERVAL '30 days') as ingresos_totales,
    (SELECT COALESCE(AVG(presupuesto_base), 0) FROM cotizaciones WHERE estado IN ('cotizado', 'aceptado', 'pagado') AND created_at > NOW() - INTERVAL '30 days') as presupuesto_promedio,
    
    -- Tiempos de respuesta
    (SELECT COALESCE(AVG(EXTRACT(EPOCH FROM (presupuesto_enviado_at - created_at)) / 3600), 0) FROM cotizaciones WHERE estado IN ('cotizado', 'aceptado', 'pagado') AND presupuesto_enviado_at IS NOT NULL AND created_at > NOW() - INTERVAL '30 days') as tiempo_respuesta_promedio_horas,
    
    -- Alertas
    (SELECT COUNT(*) FROM cotizaciones WHERE estado = 'pendiente' AND created_at < NOW() - INTERVAL '24 hours') as alertas_pendientes_criticas,
    (SELECT COUNT(*) FROM cotizaciones WHERE estado = 'cotizado' AND presupuesto_enviado_at < NOW() - INTERVAL '48 hours') as alertas_cotizados_criticas,
    
    -- Timestamps
    NOW() as ultima_actualizacion,
    NOW() - INTERVAL '30 days' as periodo_inicio;

-- Vista para cotizaciones pendientes con prioridad
CREATE OR REPLACE VIEW vw_cotizaciones_pendientes_glew AS
SELECT 
    c.id,
    c.pescador_id,
    c.capitan_id,
    c.descripcion,
    c.fecha_ida,
    c.lugar_encuentro,
    c.cantidad_personas,
    c.created_at,
    p.nombre as pescador_nombre,
    cap.nombre as capitan_nombre,
    EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 3600 as horas_pendiente,
    CASE 
        WHEN c.created_at < NOW() - INTERVAL '24 hours' THEN 'crítica'
        WHEN c.created_at < NOW() - INTERVAL '12 hours' THEN 'alta'
        WHEN c.created_at < NOW() - INTERVAL '6 hours' THEN 'media'
        ELSE 'baja'
    END as prioridad,
    CASE 
        WHEN c.created_at < NOW() - INTERVAL '24 hours' THEN '#DC2626'
        WHEN c.created_at < NOW() - INTERVAL '12 hours' THEN '#F59E0B'
        WHEN c.created_at < NOW() - INTERVAL '6 hours' THEN '#3B82F6'
        ELSE '#10B981'
    END as color_prioridad
FROM cotizaciones c
LEFT JOIN profiles p ON c.pescador_id = p.user_id
LEFT JOIN profiles cap ON c.capitan_id = cap.user_id
WHERE c.estado = 'pendiente'
ORDER BY 
    CASE 
        WHEN c.created_at < NOW() - INTERVAL '24 hours' THEN 1
        WHEN c.created_at < NOW() - INTERVAL '12 hours' THEN 2
        WHEN c.created_at < NOW() - INTERVAL '6 hours' THEN 3
        ELSE 4
    END,
    c.created_at DESC;

-- Vista para cotizaciones cotizadas sin respuesta
CREATE OR REPLACE VIEW vw_cotizaciones_cotizadas_glew AS
SELECT 
    c.id,
    c.pescador_id,
    c.capitan_id,
    c.descripcion,
    c.presupuesto_base,
    c.respuesta_capitan,
    c.presupuesto_enviado_at,
    c.fecha_ida,
    c.lugar_encuentro,
    c.cantidad_personas,
    p.nombre as pescador_nombre,
    cap.nombre as capitan_nombre,
    EXTRACT(EPOCH FROM (NOW() - c.presupuesto_enviado_at)) / 3600 as horas_espera_respuesta,
    CASE 
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '48 hours' THEN 'crítica'
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '24 hours' THEN 'alta'
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '12 hours' THEN 'media'
        ELSE 'baja'
    END as prioridad,
    CASE 
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '48 hours' THEN '#DC2626'
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '24 hours' THEN '#F59E0B'
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '12 hours' THEN '#3B82F6'
        ELSE '#10B981'
    END as color_prioridad
FROM cotizaciones c
LEFT JOIN profiles p ON c.pescador_id = p.user_id
LEFT JOIN profiles cap ON c.capitan_id = cap.user_id
WHERE c.estado = 'cotizado'
AND c.presupuesto_enviado_at IS NOT NULL
ORDER BY 
    CASE 
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '48 hours' THEN 1
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '24 hours' THEN 2
        WHEN c.presupuesto_enviado_at < NOW() - INTERVAL '12 hours' THEN 3
        ELSE 4
    END,
    c.presupuesto_enviado_at DESC;

-- =====================================================
-- TRIGGERS PARA SINCRONIZACIÓN AUTOMÁTICA
-- =====================================================

-- Función para notificar cambios de estado a Glew
CREATE OR REPLACE FUNCTION notificar_cambio_estado_glew()
RETURNS TRIGGER AS $$
DECLARE
    notificacion_data JSONB;
BEGIN
    -- Construir datos de notificación
    notificacion_data := jsonb_build_object(
        'cotizacion_id', NEW.id,
        'pescador_id', NEW.pescador_id,
        'capitan_id', NEW.capitan_id,
        'estado_anterior', COALESCE(OLD.estado, 'nuevo'),
        'estado_nuevo', NEW.estado,
        'presupuesto', NEW.presupuesto_base,
        'respuesta', NEW.respuesta_capitan,
        'timestamp', NOW(),
        'metadata', jsonb_build_object(
            'lugar_encuentro', NEW.lugar_encuentro,
            'fecha_viaje', NEW.fecha_ida,
            'cantidad_personas', NEW.cantidad_personas,
            'cambiado_por', current_setting('app.current_user_id', true)
        ),
        'source', 'database_trigger',
        'environment', current_setting('app.environment', true)
    );
    
    -- Determinar el evento
    IF TG_OP = 'INSERT' THEN
        INSERT INTO notificaciones_glew (evento, datos, estado, enviado_at, created_at)
        VALUES ('cotizacion_creada', notificacion_data, 'enviado', NOW(), NOW());
    ELSIF TG_OP = 'UPDATE' AND OLD.estado != NEW.estado THEN
        INSERT INTO notificaciones_glew (evento, datos, estado, enviado_at, created_at)
        VALUES ('estado_actualizado', notificacion_data, 'enviado', NOW(), NOW());
    ELSIF TG_OP = 'UPDATE' AND OLD.presupuesto_base IS DISTINCT FROM NEW.presupuesto_base THEN
        INSERT INTO notificaciones_glew (evento, datos, estado, enviado_at, created_at)
        VALUES ('presupuesto_actualizado', notificacion_data, 'enviado', NOW(), NOW());
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para sincronización automática
CREATE TRIGGER trigger_notificar_cambio_estado_glew
    AFTER INSERT OR UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION notificar_cambio_estado_glew();

-- =====================================================
-- FUNCIONES DE MANTENIMIENTO
-- =====================================================

-- Función para limpiar notificaciones antiguas
CREATE OR REPLACE FUNCTION limpiar_notificaciones_glew(
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
    AND estado IN ('enviado', 'reenviado');
    
    GET DIAGNOSTICS cantidad_eliminada = ROW_COUNT;
    
    RETURN QUERY SELECT cantidad_eliminada, 
        CONCAT('Notificaciones antiguas eliminadas: ', cantidad_eliminada);
END;
$$ LANGUAGE plpgsql;

-- Función para verificar integridad de sincronización
CREATE OR REPLACE FUNCTION verificar_integridad_sincronizacion()
RETURNS TABLE (
    tabla VARCHAR,
    registros_total BIGINT,
    registros_no_sincronizados BIGINT,
    porcentaje_no_sincronizados DECIMAL,
    estado VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    WITH sincronizacion AS (
        SELECT 
            'cotizaciones' as tabla,
            COUNT(*) as registros_total,
            COUNT(*) FILTER (
                WHERE estado = 'pendiente' 
                AND created_at < NOW() - INTERVAL '24 hours'
            ) as registros_no_sincronizados
        FROM cotizaciones
        WHERE created_at > NOW() - INTERVAL '7 days'
        
        UNION ALL
        
        SELECT 
            'notificaciones_glew' as tabla,
            COUNT(*) as registros_total,
            COUNT(*) FILTER (WHERE estado = 'fallido') as registros_no_sincronizados
        FROM notificaciones_glew
        WHERE created_at > NOW() - INTERVAL '7 days'
    )
    SELECT 
        tabla,
        registros_total,
        registros_no_sincronizados,
        CASE 
            WHEN registros_total > 0 
            THEN (registros_no_sincronizados::DECIMAL / registros_total::DECIMAL) * 100
            ELSE 0
        END as porcentaje_no_sincronizados,
        CASE 
            WHEN registros_no_sincronizados = 0 THEN 'ok'
            WHEN (registros_no_sincronizados::DECIMAL / NULLIF(registros_total, 0)) * 100 < 5 THEN 'advertencia'
            ELSE 'crítico'
        END as estado
    FROM sincronizacion;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- ÍNDICES DE OPTIMIZACIÓN
-- =====================================================

-- Índices para consultas del dashboard
CREATE INDEX IF NOT EXISTS idx_cotizaciones_estado_created_at ON cotizaciones(estado, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_presupuesto_enviado_at ON cotizaciones(presupuesto_enviado_at DESC) WHERE presupuesto_enviado_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_cotizaciones_pendientes_criticas ON cotizaciones(created_at) WHERE estado = 'pendiente';

-- Índices para notificaciones Glew
CREATE INDEX IF NOT EXISTS idx_notificaciones_glew_evento_created_at ON notificaciones_glew(evento, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notificaciones_glew_estado_enviado_at ON notificaciones_glew(estado, enviado_at DESC);

-- =====================================================
-- POLÍTICAS DE SEGURIDAD
-- =====================================================

-- Políticas para vistas de Glew
CREATE POLICY "Admin puede ver dashboard Glew"
ON vw_dashboard_admin_glew FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede ver cotizaciones pendientes Glew"
ON vw_cotizaciones_pendientes_glew FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede ver cotizaciones cotizadas Glew"
ON vw_cotizaciones_cotizadas_glew FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

-- Políticas para funciones RPC
GRANT EXECUTE ON FUNCTION get_contadores_admin_glew() TO authenticated;
GRANT EXECUTE ON FUNCTION get_cotizaciones_por_estado_glew(VARCHAR, INTEGER, INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION get_metricas_tiempo_respuesta_glew(TIMESTAMP WITH TIME ZONE, TIMESTAMP WITH TIME ZONE) TO authenticated;
GRANT EXECUTE ON FUNCTION limpiar_notificaciones_glew(INTEGER) TO authenticated;
GRANT EXECUTE ON FUNCTION verificar_integridad_sincronizacion() TO authenticated;

-- Solo administradores pueden ejecutar funciones de mantenimiento
CREATE POLICY "Solo admin puede ejecutar mantenimiento Glew"
ON notificaciones_glew FOR ALL
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));
