-- Crear tabla logs_sistema para registrar eventos del sistema
CREATE TABLE IF NOT EXISTS logs_sistema (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tipo VARCHAR(50) NOT NULL,
    descripcion TEXT NOT NULL,
    user_id UUID,
    cotizacion_id UUID,
    datos_adicionales JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_logs_sistema_tipo ON logs_sistema(tipo);
CREATE INDEX IF NOT EXISTS idx_logs_sistema_user_id ON logs_sistema(user_id);
CREATE INDEX IF NOT EXISTS idx_logs_sistema_cotizacion_id ON logs_sistema(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_logs_sistema_created_at ON logs_sistema(created_at);

-- Política de seguridad (RLS)
ALTER TABLE logs_sistema ENABLE ROW LEVEL SECURITY;

-- Política para que administradores vean todos los logs
CREATE POLICY "Admins ver todos los logs"
ON logs_sistema FOR SELECT
USING (auth.jwt() ->> 'role' = 'admin');

-- Política para que usuarios vean sus propios logs
CREATE POLICY "Usuarios ver sus logs"
ON logs_sistema FOR SELECT
USING (auth.uid() = user_id);

-- Política para que el sistema pueda insertar logs (sin autenticación)
CREATE POLICY "Sistema insertar logs"
ON logs_sistema FOR INSERT
USING (true);

-- Tipos de logs comunes
COMMENT ON COLUMN logs_sistema.tipo IS 'Tipos: cotizacion_creada, cotizacion_presupuestada, cotizacion_aceptada, cotizacion_rechazada, capitán_respuesta, sistema_error';

-- Función para obtener logs de tiempo de respuesta de capitanes
CREATE OR REPLACE FUNCTION get_logs_tiempo_respuesta(p_capitan_id UUID, p_fecha_inicio TIMESTAMP WITH TIME ZONE, p_fecha_fin TIMESTAMP WITH TIME ZONE)
RETURNS TABLE (
    cotizacion_id UUID,
    tiempo_respuesta INTERVAL,
    created_at TIMESTAMP WITH TIME ZONE,
    respuesta_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id as cotizacion_id,
        c.respuesta_at - c.created_at as tiempo_respuesta,
        c.created_at,
        c.respuesta_at
    FROM cotizaciones c
    WHERE c.capitan_id = p_capitan_id
    AND c.estado IN ('aceptado', 'rechazado')
    AND c.created_at BETWEEN p_fecha_inicio AND p_fecha_fin
    AND c.respuesta_at IS NOT NULL
    ORDER BY c.created_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener estadísticas de tiempo de respuesta
CREATE OR REPLACE FUNCTION get_estadisticas_tiempo_respuesta(p_capitan_id UUID)
RETURNS TABLE (
    tiempo_promedio INTERVAL,
    tiempo_minimo INTERVAL,
    tiempo_maximo INTERVAL,
    total_cotizaciones INTEGER,
    cotizaciones_hoy INTEGER,
    cotizaciones_pendientes INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        AVG(respuesta_at - created_at) as tiempo_promedio,
        MIN(respuesta_at - created_at) as tiempo_minimo,
        MAX(respuesta_at - created_at) as tiempo_maximo,
        COUNT(*) as total_cotizaciones,
        COUNT(*) FILTER (WHERE created_at::date = CURRENT_DATE) as cotizaciones_hoy,
        (SELECT COUNT(*) FROM cotizaciones WHERE capitan_id = p_capitan_id AND estado = 'pendiente') as cotizaciones_pendientes
    FROM cotizaciones
    WHERE capitan_id = p_capitan_id
    AND estado IN ('aceptado', 'rechazado')
    AND respuesta_at IS NOT NULL;
END;
$$ LANGUAGE plpgsql;
