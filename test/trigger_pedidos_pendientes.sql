-- Trigger para habilitar reembolso en pedidos pendientes > 24hs
-- CapitánYA - Motor de Seguridad y Reintegros

-- 1. Crear función para verificar si han pasado 24hs
CREATE OR REPLACE FUNCTION verificar_pedido_pendiente_24hs()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el pedido está en estado 'Pendiente' y han pasado más de 24hs
    IF NEW.estado = 'Pendiente' AND 
       EXTRACT(EPOCH FROM (NOW() - NEW.created_at)) > 86400 THEN
        -- Habilitar opción de reembolso
        NEW.puede_solicitar_reembolso = true;
        NEW.fecha_habilitacion_reembolso = NOW();
        
        -- Log del cambio
        INSERT INTO auditoria_reembolsos (
            pedido_id,
            estado_anterior,
            estado_nuevo,
            motivo,
            created_at
        ) VALUES (
            NEW.id,
            'Pendiente',
            'Pendiente_con_reembolso',
            'Habilitado automáticamente por trigger 24hs',
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Crear trigger que se ejecute en cada UPDATE de pedidos
CREATE TRIGGER trigger_pedido_pendiente_24hs
    BEFORE UPDATE ON pedidos
    FOR EACH ROW
    EXECUTE FUNCTION verificar_pedido_pendiente_24hs();

-- 3. Crear tabla de auditoría de reembolsos
CREATE TABLE IF NOT EXISTS auditoria_reembolsos (
    id SERIAL PRIMARY KEY,
    pedido_id VARCHAR(255) NOT NULL,
    estado_anterior VARCHAR(50),
    estado_nuevo VARCHAR(50),
    motivo TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (pedido_id) REFERENCES pedidos(id)
);

-- 4. Crear función para solicitudes de reembolso
CREATE OR REPLACE FUNCTION solicitar_reembolso(
    p_pedido_id VARCHAR(255),
    p_motivo TEXT,
    p_monto_solicitado DECIMAL(10,2)
)
RETURNS JSON AS $$
DECLARE
    v_pedido RECORD;
    v_monto_devolver DECIMAL(10,2);
    v_productos_consumidos DECIMAL(10,2);
BEGIN
    -- Obtener información del pedido
    SELECT * INTO v_pedido FROM pedidos WHERE id = p_pedido_id;
    
    -- Verificar si puede solicitar reembolso
    IF NOT v_pedido.puede_solicitar_reembolso THEN
        RETURN json_build_object(
            'success', false,
            'error', 'No se puede solicitar reembolso para este pedido',
            'motivo', 'El pedido no cumple las condiciones para reembolso'
        );
    END IF;
    
    -- Calcular monto a devolver (restando productos consumidos)
    v_productos_consumidos := COALESCE(
        (SELECT COALESCE(SUM(subtotal), 0) 
         FROM pedido_items 
         WHERE pedido_id = p_pedido_id AND consumido = true), 
        0
    );
    
    v_monto_devolver := v_pedido.total - v_productos_consumidos;
    
    -- No permitir devolver más del monto solicitado
    IF p_monto_solicitado < v_monto_devolver THEN
        v_monto_devolver := p_monto_solicitado;
    END IF;
    
    -- Actualizar estado del pedido
    UPDATE pedidos SET 
        estado = 'Reembolso_solicitado',
        fecha_solicitud_reembolso = NOW(),
        monto_reembolso_solicitado = v_monto_devolver,
        motivo_reembolso = p_motivo
    WHERE id = p_pedido_id;
    
    -- Registrar en auditoría
    INSERT INTO auditoria_reembolsos (
        pedido_id,
        estado_anterior,
        estado_nuevo,
        motivo,
        monto_reembolso,
        created_at
    ) VALUES (
        p_pedido_id,
        'Pendiente_con_reembolso',
        'Reembolso_solicitado',
        p_motivo,
        v_monto_devolver,
        NOW()
    );
    
    RETURN json_build_object(
        'success', true,
        'mensaje', 'Reembolso solicitado exitosamente',
        'monto_devolver', v_monto_devolver,
        'pedido_id', p_pedido_id,
        'productos_consumidos', v_productos_consumidos
    );
END;
$$ LANGUAGE plpgsql;

-- 5. Agregar columnas necesarias a la tabla pedidos
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS puede_solicitar_reembolso BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS fecha_habilitacion_reembolso TIMESTAMP,
ADD COLUMN IF NOT EXISTS fecha_solicitud_reembolso TIMESTAMP,
ADD COLUMN IF NOT EXISTS monto_reembolso_solicitado DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS motivo_reembolso TEXT;

-- 6. Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_pedidos_estado_fecha ON pedidos(estado, created_at);
CREATE INDEX IF NOT EXISTS idx_auditoria_reembolsos_pedido_id ON auditoria_reembolsos(pedido_id);

-- 7. Probar el trigger con un pedido de prueba
-- INSERT INTO pedidos (id, estado, total, created_at) VALUES 
-- ('test_pedido_001', 'Pendiente', 68500.00, NOW() - INTERVAL '25 hours');
-- UPDATE pedidos SET estado = 'Pendiente' WHERE id = 'test_pedido_001';
-- SELECT * FROM pedidos WHERE id = 'test_pedido_001';
