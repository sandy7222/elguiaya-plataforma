-- ESTANDARIZACIÓN DEL FLUJO DE COTIZACIONES
-- Une los dos mundos de cotizaciones en uno solo consistente

-- 1. Asegurar que la tabla cotizaciones tenga todas las columnas necesarias
ALTER TABLE cotizaciones 
ADD COLUMN IF NOT EXISTS presupuesto_base DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS presupuesto_aceptado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS presupuesto_aceptado_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS observaciones TEXT,
ADD COLUMN IF NOT EXISTS punto_partida JSONB,
ADD COLUMN IF NOT EXISTS punto_destino JSONB,
ADD COLUMN IF NOT EXISTS distancia_km DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS distancia_millas DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS duracion_estimada_minutos INTEGER;

-- 2. Actualizar el constraint de estados para que sea inclusivo
ALTER TABLE cotizaciones DROP CONSTRAINT IF EXISTS cotizaciones_estado_check;
ALTER TABLE cotizaciones ADD CONSTRAINT cotizaciones_estado_check 
CHECK (estado IN ('pendiente', 'solicitada', 'presupuestada', 'presupuestado', 'aceptada', 'aceptado', 'rechazada', 'rechazado', 'pagada', 'cancelada', 'adjudicada', 'cerrada'));

-- 3. Sincronizar columnas duplicadas (para retrocompatibilidad)
-- Si presupuesto_monto existe, lo usamos como respaldo de presupuesto_base
UPDATE cotizaciones SET presupuesto_base = presupuesto_monto WHERE presupuesto_base IS NULL AND presupuesto_monto IS NOT NULL;
UPDATE cotizaciones SET presupuesto_monto = presupuesto_base WHERE presupuesto_monto IS NULL AND presupuesto_base IS NOT NULL;

-- 4. Asegurar que el RPC de respuesta esté actualizado para usar las columnas correctas
CREATE OR REPLACE FUNCTION actualizar_cotizacion_con_respuesta(
    p_cotizacion_id UUID,
    p_capitan_id UUID,
    p_presupuesto DECIMAL,
    p_observaciones TEXT DEFAULT NULL
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    cotizacion_id UUID
) AS $$
BEGIN
    -- 1. Actualizar cotización principal (para retrocompatibilidad y estado maestro)
    UPDATE cotizaciones
    SET 
        capitan_id = p_capitan_id,
        presupuesto_base = p_presupuesto,
        presupuesto_monto = p_presupuesto,
        estado = 'presupuestada',
        observaciones = p_observaciones,
        presupuesto_at = NOW(),
        updated_at = NOW()
    WHERE id = p_cotizacion_id;
    
    -- 2. Insertar en la tabla presupuestos para el RADAR de ofertas
    INSERT INTO presupuestos (
        cotizacion_id,
        capitan_id,
        monto,
        detalles,
        estado,
        created_at
    ) VALUES (
        p_cotizacion_id,
        p_capitan_id,
        p_presupuesto,
        p_observaciones,
        'pendiente',
        NOW()
    );
    
    -- 3. Crear notificación para el pescador
    INSERT INTO notificaciones_usuarios (
        user_id, tipo, titulo, mensaje, datos_adicionales, leida, created_at
    ) VALUES (
        (SELECT pescador_id FROM cotizaciones WHERE id = p_cotizacion_id),
        'presupuesto_recibido',
        '¡Nuevo Presupuesto!',
        'Un capitán ha respondido a tu solicitud de cotización.',
        jsonb_build_object(
            'cotizacion_id', p_cotizacion_id,
            'capitan_id', p_capitan_id,
            'presupuesto', p_presupuesto,
            'accion_requerida', 'revisar_presupuesto'
        ),
        FALSE, NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Presupuesto enviado exitosamente', p_cotizacion_id;
END;
$$ LANGUAGE plpgsql;
