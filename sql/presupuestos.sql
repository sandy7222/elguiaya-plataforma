-- Tabla para presupuestos (ofertas de capitanes a cotizaciones)
-- Soporta el sistema de subasta competitiva (múltiples presupuestos por cotización)

CREATE TABLE IF NOT EXISTS presupuestos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cotizacion_id UUID NOT NULL REFERENCES cotizaciones(id) ON DELETE CASCADE,
    capitan_id UUID NOT NULL REFERENCES profiles(user_id) ON DELETE CASCADE,
    monto DECIMAL(10,2) NOT NULL,
    detalles TEXT,
    fecha_hora_viaje TIMESTAMP WITH TIME ZONE,
    estado VARCHAR(20) DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aceptado', 'rechazado', 'cancelado', 'vencido')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_presupuestos_cotizacion_id ON presupuestos(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_presupuestos_capitan_id ON presupuestos(capitan_id);
CREATE INDEX IF NOT EXISTS idx_presupuestos_estado ON presupuestos(estado);

-- RLS
ALTER TABLE presupuestos ENABLE ROW LEVEL SECURITY;

-- Pescadores pueden ver presupuestos de sus cotizaciones
CREATE POLICY "Pescadores ver presupuestos de sus cotizaciones"
ON presupuestos FOR SELECT
USING (EXISTS (
    SELECT 1 FROM cotizaciones 
    WHERE cotizaciones.id = presupuestos.cotizacion_id 
    AND cotizaciones.pescador_id = auth.uid()
));

-- Capitanes pueden ver sus propios presupuestos
CREATE POLICY "Capitanes ver sus propios presupuestos"
ON presupuestos FOR SELECT
USING (auth.uid() = capitan_id);

-- Capitanes pueden insertar presupuestos
CREATE POLICY "Capitanes insertar presupuestos"
ON presupuestos FOR INSERT
WITH CHECK (auth.uid() = capitan_id);

-- Capitanes pueden actualizar sus presupuestos (ej. cancelar)
CREATE POLICY "Capitanes actualizar sus presupuestos"
ON presupuestos FOR UPDATE
USING (auth.uid() = capitan_id);

-- Trigger para updated_at
CREATE TRIGGER set_presupuestos_timestamp
    BEFORE UPDATE ON presupuestos
    FOR EACH ROW
    EXECUTE FUNCTION trigger_set_timestamp();
