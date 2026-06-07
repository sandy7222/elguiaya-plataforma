-- Actualizar tabla profiles para incluir configuración de capitán
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS limite_respuesta_minutos INTEGER DEFAULT 15;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS es_capitan BOOLEAN DEFAULT FALSE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS telefono_contacto VARCHAR(30);

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_profiles_capitanes ON profiles(es_capitan) WHERE es_capitan = TRUE;
CREATE INDEX IF NOT EXISTS idx_profiles_limite_respuesta ON profiles(limite_respuesta_minutos);

-- Actualizar tabla cotizaciones para incluir nuevos estados y métricas
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS tiempo_real_respuesta_minutos INTEGER;
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS limite_respuesta_minutos INTEGER;
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS riesgo_notificado BOOLEAN DEFAULT FALSE;
ALTER TABLE cotizaciones ADD COLUMN IF NOT EXISTS pescador_telefono VARCHAR(30);

-- Actualizar CHECK constraint para incluir nuevo estado
DROP CONSTRAINT IF EXISTS cotizaciones_estado_check ON cotizaciones;
ALTER TABLE cotizaciones ADD CONSTRAINT cotizaciones_estado_check 
CHECK (estado IN ('pendiente', 'presupuestado', 'aceptado', 'rechazado', 'en_riesgo'));

-- Crear trigger para actualizar tiempo real de respuesta
CREATE OR REPLACE FUNCTION actualizar_tiempo_real_respuesta()
RETURNS TRIGGER AS $$
BEGIN
    -- Calcular tiempo real de respuesta cuando cambia el estado
    IF NEW.estado IN ('presupuestado', 'aceptado', 'rechazado') AND 
       OLD.estado NOT IN ('presupuestado', 'aceptado', 'rechazado') THEN
        NEW.tiempo_real_respuesta_minutos = EXTRACT(EPOCH FROM (NEW.updated_at - NEW.created_at)) / 60;
    END IF;
    
    -- Establecer límite de respuesta desde el perfil del capitán
    IF NEW.estado = 'pendiente' AND NEW.limite_respuesta_minutos IS NULL THEN
        SELECT limite_respuesta_minutos INTO NEW.limite_respuesta_minutos
        FROM profiles 
        WHERE user_id = NEW.capitan_id AND es_capitan = TRUE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_actualizar_tiempo_real_respuesta
    BEFORE UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_tiempo_real_respuesta();

-- Función para marcar cotizaciones en riesgo
CREATE OR REPLACE FUNCTION marcar_cotizaciones_en_riesgo()
RETURNS TABLE (
    cotizacion_id UUID,
    capitan_id UUID,
    pescador_id UUID,
    pescador_telefono VARCHAR(30),
    tiempo_transcurrido INTEGER,
    limite_respuesta INTEGER
) AS $$
DECLARE
    cotizaciones_riesgo RECORD;
BEGIN
    -- Actualizar cotizaciones pendientes que superaron su límite
    FOR cotizaciones_riesgo IN 
        SELECT 
            c.id,
            c.capitan_id,
            c.pescador_id,
            p.telefono_contacto as pescador_telefono,
            EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60 as tiempo_transcurrido,
            COALESCE(c.limite_respuesta_minutos, 15) as limite_respuesta
        FROM cotizaciones c
        LEFT JOIN profiles p ON c.pescador_id = p.user_id
        WHERE c.estado = 'pendiente'
        AND c.estado != 'en_riesgo'
        AND EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60 > COALESCE(c.limite_respuesta_minutos, 15)
        AND c.riesgo_notificado = FALSE
    LOOP
        -- Marcar como en riesgo
        UPDATE cotizaciones 
        SET estado = 'en_riesgo', 
            riesgo_notificado = TRUE,
            updated_at = NOW()
        WHERE id = cotizaciones_riesgo.id;
        
        -- Retornar para notificación
        cotizacion_id := cotizaciones_riesgo.id;
        capitan_id := cotizaciones_riesgo.capitan_id;
        pescador_id := cotizaciones_riesgo.pescador_id;
        pescador_telefono := cotizaciones_riesgo.pescador_telefono;
        tiempo_transcurrido := cotizaciones_riesgo.tiempo_transcurrido;
        limite_respuesta := cotizaciones_riesgo.limite_respuesta;
        
        RETURN NEXT;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener métricas de cumplimiento mensual
CREATE OR REPLACE FUNCTION metricas_cumplimiento_mensual(
    p_capitan_id UUID,
    p_anio INTEGER,
    p_mes INTEGER
)
RETURNS TABLE (
    total_cotizaciones INTEGER,
    respondidas_a_tiempo INTEGER,
    respondidas_fuera_tiempo INTEGER,
    porcentaje_cumplimiento DECIMAL(5,2),
    tiempo_promedio_respuesta INTERVAL,
    tiempo_limite_promedio INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        COUNT(*) as total_cotizaciones,
        COUNT(*) FILTER (WHERE tiempo_real_respuesta_minutos <= limite_respuesta_minutos) as respondidas_a_tiempo,
        COUNT(*) FILTER (WHERE tiempo_real_respuesta_minutos > limite_respuesta_minutos) as respondidas_fuera_tiempo,
        CASE 
            WHEN COUNT(*) > 0 THEN 
                (COUNT(*) FILTER (WHERE tiempo_real_respuesta_minutos <= limite_respuesta_minutos) * 100.0 / COUNT(*))
            ELSE 0 
        END as porcentaje_cumplimiento,
        AVG(tiempo_real_respuesta_minutos || ' minutes')::INTERVAL as tiempo_promedio_respuesta,
        AVG(limite_respuesta_minutos) as tiempo_limite_promedio
    FROM cotizaciones
    WHERE capitan_id = p_capitan_id
    AND estado IN ('presupuestado', 'aceptado', 'rechazado')
    AND EXTRACT(YEAR FROM created_at) = p_anio
    AND EXTRACT(MONTH FROM created_at) = p_mes
    AND tiempo_real_respuesta_minutos IS NOT NULL;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener cotizaciones pendientes con tiempo restante
CREATE OR REPLACE FUNCTION cotizaciones_pendientes_con_tiempo(p_capitan_id UUID)
RETURNS TABLE (
    cotizacion_id UUID,
    descripcion TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    tiempo_transcurrido INTEGER,
    limite_respuesta INTEGER,
    tiempo_restante INTEGER,
    porcentaje_tiempo_usado DECIMAL(5,2),
    estado_actual VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.descripcion,
        c.created_at,
        EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60 as tiempo_transcurrido,
        COALESCE(c.limite_respuesta_minutos, 15) as limite_respuesta,
        GREATEST(0, COALESCE(c.limite_respuesta_minutos, 15) - EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60) as tiempo_restante,
        CASE 
            WHEN COALESCE(c.limite_respuesta_minutos, 15) > 0 THEN
                (EXTRACT(EPOCH FROM (NOW() - c.created_at)) / 60 * 100.0 / COALESCE(c.limite_respuesta_minutos, 15))
            ELSE 0 
        END as porcentaje_tiempo_usado,
        c.estado
    FROM cotizaciones c
    WHERE c.capitan_id = p_capitan_id
    AND c.estado IN ('pendiente', 'en_riesgo')
    ORDER BY c.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Crear tabla para alertas de negocio
CREATE TABLE IF NOT EXISTS alertas_negocio (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    tipo VARCHAR(50) NOT NULL,
    cotizacion_id UUID NOT NULL,
    capitan_id UUID NOT NULL,
    pescador_id UUID NOT NULL,
    pescador_telefono VARCHAR(30),
    descripcion TEXT NOT NULL,
    tiempo_transcurrido INTEGER NOT NULL,
    limite_respuesta INTEGER NOT NULL,
    notificada BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resuelta_at TIMESTAMP WITH TIME ZONE,
    
    FOREIGN KEY (cotizacion_id) REFERENCES cotizaciones(id)
);

-- Crear índices para alertas
CREATE INDEX IF NOT EXISTS idx_alertas_negocio_tipo ON alertas_negocio(tipo);
CREATE INDEX IF NOT EXISTS idx_alertas_negocio_notificada ON alertas_negocio(notificada);
CREATE INDEX IF NOT EXISTS idx_alertas_negocio_created_at ON alertas_negocio(created_at);

-- Política de seguridad para alertas
ALTER TABLE alertas_negocio ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Admins ver todas las alertas"
ON alertas_negocio FOR SELECT
USING (auth.jwt() ->> 'role' = 'admin');

-- Insertar datos de ejemplo para capitanes
INSERT INTO profiles (user_id, es_capitan, limite_respuesta_minutos, telefono_contacto, dni, telefono) VALUES
('22222222-2222-2222-2222-222222222222', TRUE, 15, '+54911-1234-5678', '12345678', '+54911-1234-5678')
ON CONFLICT (user_id) DO UPDATE SET
    es_capitan = TRUE,
    limite_respuesta_minutos = EXCLUDED.limite_respuesta_minutos,
    telefono_contacto = EXCLUDED.telefono_contacto;

-- Insertar datos de ejemplo para pescadores
INSERT INTO profiles (user_id, es_capitan, telefono_contacto, dni, telefono) VALUES
('11111111-1111-1111-1111-111111111111', FALSE, NULL, '+54911-9876-5432', '87654321', '+54911-9876-5432'),
('33333333-3333-3333-3333-333333333333', FALSE, NULL, '+54911-5555-6666', '55556666', '+54911-5555-6666')
ON CONFLICT (user_id) DO UPDATE SET
    es_capitan = FALSE,
    telefono_contacto = EXCLUDED.telefono_contacto;

-- Actualizar cotizaciones existentes con datos de contacto
UPDATE cotizaciones c
SET pescador_telefono = p.telefono_contacto,
    limite_respuesta_minutos = pr.limite_respuesta_minutos
FROM profiles p
LEFT JOIN profiles pr ON c.capitan_id = pr.user_id
WHERE c.pescador_id = p.user_id;
