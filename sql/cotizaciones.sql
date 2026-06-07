-- Crear tabla cotizaciones para el motor de cotización en tiempo real
CREATE TABLE IF NOT EXISTS cotizaciones (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    pescador_id UUID NOT NULL,
    capitan_id UUID NOT NULL,
    descripcion TEXT NOT NULL,
    presupuesto_monto DECIMAL(10,2),
    estado VARCHAR(20) DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'presupuestado', 'aceptado', 'rechazado')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    presupuesto_at TIMESTAMP WITH TIME ZONE,
    respuesta_at TIMESTAMP WITH TIME ZONE
);

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_cotizaciones_pescador_id ON cotizaciones(pescador_id);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_capitan_id ON cotizaciones(capitan_id);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_estado ON cotizaciones(estado);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_created_at ON cotizaciones(created_at);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_pendientes ON cotizaciones(capitan_id, estado) WHERE estado = 'pendiente';

-- Crear trigger para actualizar updated_at automáticamente
CREATE TRIGGER set_cotizaciones_timestamp
    BEFORE UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();

-- Crear trigger para actualizar timestamps de respuesta
CREATE OR REPLACE FUNCTION update_cotizacion_timestamps()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.estado = 'presupuestado' AND OLD.estado != 'presupuestado' THEN
        NEW.presupuesto_at = NOW();
    END IF;
    
    IF NEW.estado IN ('aceptado', 'rechazado') AND OLD.estado NOT IN ('aceptado', 'rechazado') THEN
        NEW.respuesta_at = NOW();
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_cotizacion_response_timestamps
    BEFORE UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION update_cotizacion_timestamps();

-- Insertar cotizaciones de ejemplo
INSERT INTO cotizaciones (pescador_id, capitan_id, descripcion, presupuesto_monto, estado) VALUES
(
    '11111111-1111-1111-1111-111111111111',
    '22222222-2222-2222-2222-222222222222',
    'Necesito alquiler de lancha para pesca de 4 horas con equipo completo',
    150.00,
    'pendiente'
),
(
    '33333333-3333-3333-3333-333333333333',
    '22222222-2222-2222-2222-222222222222',
    'Viaje de pesca nocturna para 2 personas, incluye carnada y guías',
    280.00,
    'presupuestado'
),
(
    '44444444-4444-4444-4444-444444444444',
    '22222222-2222-2222-2222-222222222222',
    'Expedición de pesca deportiva de 8 horas en laguna',
    450.00,
    'aceptado'
);

-- Política de seguridad (RLS)
ALTER TABLE cotizaciones ENABLE ROW LEVEL SECURITY;

-- Política para que pescadores vean sus cotizaciones
CREATE POLICY "Pescadores ver sus cotizaciones"
ON cotizaciones FOR SELECT
USING (auth.uid() = pescador_id);

-- Política para que capitanes vean sus cotizaciones
CREATE POLICY "Capitanes ver sus cotizaciones"
ON cotizaciones FOR SELECT
USING (auth.uid() = capitan_id);

-- Política para que pescadores creen cotizaciones
CREATE POLICY "Pescadores crear cotizaciones"
ON cotizaciones FOR INSERT
WITH CHECK (auth.uid() = pescador_id);

-- Política para que capitanes actualicen sus cotizaciones
CREATE POLICY "Capitanes actualizar cotizaciones"
ON cotizaciones FOR UPDATE
USING (auth.uid() = capitan_id);

-- Política para que pescadores acepten/rechacen presupuestos
CREATE POLICY "Pescadores responder cotizaciones"
ON cotizaciones FOR UPDATE
USING (auth.uid() = pescador_id AND NEW.estado IN ('aceptado', 'rechazado'));

-- Función para obtener cotizaciones pendientes de un capitán
CREATE OR REPLACE FUNCTION get_cotizaciones_pendientes(p_capitan_id UUID)
RETURNS TABLE (
    id UUID,
    pescador_id UUID,
    descripcion TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT c.id, c.pescador_id, c.descripcion, c.created_at
    FROM cotizaciones c
    WHERE c.capitan_id = p_capitan_id AND c.estado = 'pendiente'
    ORDER BY c.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Función para calcular tiempo de respuesta promedio de un capitán
CREATE OR REPLACE FUNCTION tiempo_respuesta_promedio(p_capitan_id UUID)
RETURNS INTERVAL AS $$
DECLARE
    tiempo_total INTERVAL;
    cantidad_cotizaciones INTEGER;
BEGIN
    SELECT 
        AVG(respuesta_at - created_at),
        COUNT(*)
    INTO tiempo_total, cantidad_cotizaciones
    FROM cotizaciones
    WHERE capitan_id = p_capitan_id 
    AND estado IN ('aceptado', 'rechazado')
    AND respuesta_at IS NOT NULL;
    
    IF cantidad_cotizaciones = 0 THEN
        RETURN INTERVAL '0 minutes';
    END IF;
    
    RETURN tiempo_total;
END;
$$ LANGUAGE plpgsql;
