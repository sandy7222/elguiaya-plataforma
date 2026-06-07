-- Asegurar que la tabla pedidos tenga los estados necesarios para finalización de viajes
ALTER TABLE pedidos 
ADD CONSTRAINT chk_estado_viaje 
CHECK (estado IN ('pendiente', 'en_curso', 'completado_pendiente_firma', 'liquidado', 'cancelado', 'disputa'));

-- Agregar campos para control de finalización si no existen
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS fecha_pactada TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS fecha_completado TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOTIDES NOT EXISTS cliente_confirmo BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS motivo_disputa TEXT,
ADD COLUMN IF NOT EXISTS saldo_bloqueado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS admin_resolvio_disputa BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS admin_observaciones TEXT;

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_pedidos_estado ON pedidos(estado);
CREATE INDEX IF NOT EXISTS idx_pedidos_capitan_id ON pedidos(capitan_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha_pactada ON pedidos(fecha_pactada);
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha_completado ON pedidos(fecha_completado);
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente_confirmo ON pedidos(cliente_confirmo);
CREATE INDEX IF NOT EXISTS idx_pedidos_saldo_bloqueado ON pedidos(saldo_bloqueado);

-- Función para verificar si un viaje está listo para confirmación
CREATE OR REPLACE FUNCTION verificar_viaje_listo_para_confirmacion(p_pedido_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    pedido_actual RECORD;
    fecha_actual TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    -- Verificar si el pedido existe y está en curso
    IF pedido_actual IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- El viaje está listo para confirmación si:
    -- 1. Está en_curso
    -- 2. La fecha pactada ya pasó
    -- 3. El cliente no ha confirmado aún
    IF pedido_actual.estado = 'en_curso' 
       AND pedido_actual.fecha_pactada IS NOT NULL 
       AND pedido_actual.fecha_pactada < fecha_actual
       AND pedido_actual.cliente_confirmo = FALSE THEN
        RETURN TRUE;
    END IF;
    
    RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- Función para confirmar viaje exitoso
CREATE OR REPLACE FUNCTION confirmar_viaje_exitoso(p_pedido_id UUID, p_cliente_id UUID)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    pedido_id UUID,
    nuevo_estado VARCHAR
) AS $$
DECLARE
    pedido_actual RECORD;
    monto_a_transferir DECIMAL;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    -- Validaciones
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL, NULL;
        RETURN;
    END IF;
    
    IF pedido_actual.cliente_id != p_cliente_id THEN
        RETURN QUERY SELECT FALSE, 'No tienes permiso para confirmar este pedido', NULL, NULL;
        RETURN;
    END IF;
    
    IF pedido_actual.cliente_confirmo = TRUE THEN
        RETURN QUERY SELECT FALSE, 'Este viaje ya fue confirmado', NULL, NULL;
        RETURN;
    END IF;
    
    -- Actualizar pedido
    UPDATE pedidos
    SET 
        estado = 'completado_pendiente_firma',
        cliente_confirmo = TRUE,
        fecha_completado = NOW(),
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    -- Calcular monto a transferir (total - comisión)
    monto_a_transferir := pedido_actual.total * 0.9; -- 90% para el capitán
    
    -- Registrar transacción para el capitán
    INSERT INTO transacciones_capitanes (
        capitan_id,
        pedido_id,
        monto,
        tipo,
        estado,
        created_at
    ) VALUES (
        pedido_actual.capitan_id,
        p_pedido_id,
        monto_a_transferir,
        'ganancia_viaje',
        'pendiente',
        NOW()
    );
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo,
        descripcion,
        user_id,
        pedido_id,
        datos_adicionales,
        created_at
    ) VALUES (
        'viaje_confirmado_cliente',
        'Cliente confirmó viaje exitoso',
        p_cliente_id,
        p_pedido_id,
        jsonb_build_object(
            'monto_transferido', monto_a_transferir,
            'capitan_id', pedido_actual.capitan_id,
            'timestamp', NOW()
        ),
        NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Viaje confirmado exitosamente', p_pedido_id, 'completado_pendiente_firma';
END;
$$ LANGUAGE plpgsql;

-- Función para reportar problema en viaje
CREATE OR REPLACE FUNCTION reportar_problema_viaje(
    p_pedido_id UUID, 
    p_cliente_id UUID, 
    p_motivo TEXT
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    pedido_id UUID,
    nuevo_estado VARCHAR
) AS $$
DECLARE
    pedido_actual RECORD;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    -- Validaciones
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL, NULL;
        RETURN;
    END IF;
    
    IF pedido_actual.cliente_id != p_cliente_id THEN
        RETURN QUERY SELECT FALSE, 'No tienes permiso para reportar este pedido', NULL, NULL;
        RETURN;
    END IF;
    
    IF pedido_actual.estado = 'disputa' THEN
        RETURN QUERY SELECT FALSE, 'Este viaje ya está en disputa', NULL, NULL;
        RETURN;
    END IF;
    
    -- Actualizar pedido a estado de disputa
    UPDATE pedidos
    SET 
        estado = 'disputa',
        motivo_disputa = p_motivo,
        saldo_bloqueado = TRUE,
        fecha_completado = NOW(),
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    -- Crear alerta para administrador
    INSERT INTO alertas_negocio (
        tipo,
        pedido_id,
        cliente_id,
        capitan_id,
        descripcion,
        datos_adicionales,
        notificada,
        created_at
    ) VALUES (
        'viaje_en_disputa',
        p_pedido_id,
        p_cliente_id,
        pedido_actual.capitan_id,
        'Cliente reportó problema en viaje',
        jsonb_build_object(
            'motivo', p_motivo,
            'monto_afectado', pedido_actual.total,
            'timestamp', NOW()
        ),
        FALSE,
        NOW()
    );
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo,
        descripcion,
        user_id,
        pedido_id,
        datos_adicionales,
        created_at
    ) VALUES (
        'viaje_reportado_cliente',
        'Cliente reportó problema en viaje',
        p_cliente_id,
        p_pedido_id,
        jsonb_build_object(
            'motivo', p_motivo,
            'capitan_id', pedido_actual.capitan_id,
            'monto_afectado', pedido_actual.total,
            'timestamp', NOW()
        ),
        NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Problema reportado, el administrador revisará el caso', p_pedido_id, 'disputa';
END;
$$ LANGUAGE plpgsql;

-- Función para obtener saldos del capitán
CREATE OR REPLACE FUNCTION get_saldos_capitan(p_capitan_id UUID)
RETURNS TABLE (
    saldo_a_confirmar DECIMAL,
    saldo_disponible DECIMAL,
    total_viajes INTEGER,
    viajes_pendientes_confirmacion INTEGER,
    ultimo_viaje_confirmado TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    WITH transacciones_capitan AS (
        SELECT 
            tc.monto,
            tc.estado,
            tc.created_at,
            p.estado as estado_pedido,
            p.cliente_confirmo
        FROM transacciones_capitanes tc
        JOIN pedidos p ON tc.pedido_id = p.id
        WHERE tc.capitan_id = p_capitan_id
        AND tc.tipo = 'ganancia_viaje'
    ),
    saldos_calculados AS (
        SELECT 
            COALESCE(SUM(CASE WHEN estado = 'pendiente' THEN monto ELSE 0 END), 0) as saldo_a_confirmar,
            COALESCE(SUM(CASE WHEN estado = 'disponible' THEN monto ELSE 0 END), 0) as saldo_disponible,
            COUNT(*) as total_viajes,
            COUNT(*) FILTER (WHERE estado = 'pendiente') as viajes_pendientes_confirmacion,
            MAX(created_at) FILTER (WHERE estado = 'disponible') as ultimo_viaje_confirmado
        FROM transacciones_capitan
    )
    SELECT 
        sc.saldo_a_confirmar,
        sc.saldo_disponible,
        sc.total_viajes,
        sc.viajes_pendientes_confirmacion,
        sc.ultimo_viaje_confirmado
    FROM saldos_calculados sc;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener viajes en disputa para administrador
CREATE OR REPLACE FUNCTION get_viajes_en_disputa()
RETURNS TABLE (
    pedido_id UUID,
    cliente_id UUID,
    capitan_id UUID,
    monto_total DECIMAL,
    motivo_disputa TEXT,
    fecha_pactada TIMESTAMP WITH TIME ZONE,
    fecha_completado TIMESTAMP WITH TIME ZONE,
    dias_en_disputa INTEGER,
    cliente_nombre VARCHAR,
    capitan_nombre VARCHAR,
    urgencia VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as pedido_id,
        p.cliente_id,
        p.capitan_id,
        p.total as monto_total,
        p.motivo_disputa,
        p.fecha_pactada,
        p.fecha_completado,
        EXTRACT(DAY FROM NOW() - p.fecha_completado)::INTEGER as dias_en_disputa,
        COALESCE(u1.email, 'Cliente sin email') as cliente_nombre,
        COALESCE(u2.email, 'Capitán sin email') as capitan_nombre,
        CASE 
            WHEN EXTRACT(DAY FROM NOW() - p.fecha_completado) >= 7 THEN 'alta'
            WHEN EXTRACT(DAY FROM NOW() - p.fecha_completado) >= 3 THEN 'media'
            ELSE 'baja'
        END as urgencia
    FROM pedidos p
    LEFT JOIN auth.users u1 ON p.cliente_id = u1.id
    LEFT JOIN auth.users u2 ON p.capitan_id = u2.id
    WHERE p.estado = 'disputa'
    AND p.saldo_bloqueado = TRUE
    ORDER BY p.fecha_completado ASC;
END;
$$ LANGUAGE plpgsql;

-- Función para liberar pago manualmente (admin)
CREATE OR REPLACE FUNCTION liberar_pago_manual_admin(
    p_pedido_id UUID,
    p_admin_id UUID,
    p_observaciones TEXT DEFAULT NULL,
    p_favor_capitan BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    monto_liberado DECIMAL
) AS $$
DECLARE
    pedido_actual RECORD;
    monto_a_liberar DECIMAL;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    -- Validaciones
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', 0;
        RETURN;
    END IF;
    
    IF pedido_actual.estado != 'disputa' THEN
        RETURN QUERY SELECT FALSE, 'El pedido no está en disputa', 0;
        RETURN;
    END IF;
    
    -- Calcular monto a liberar
    IF p_favor_capitan THEN
        monto_a_liberar := pedido_actual.total * 0.9; -- 90% para el capitán
    ELSE
        monto_a_liberar := pedido_actual.total; -- 100% reembolso al cliente
    END IF;
    
    -- Actualizar pedido
    UPDATE pedidos
    SET 
        estado = CASE WHEN p_favor_capitan THEN 'liquidado' ELSE 'cancelado' END,
        admin_resolvio_disputa = TRUE,
        admin_observaciones = p_observaciones,
        saldo_bloqueado = FALSE,
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    -- Si es a favor del capitán, crear transacción
    IF p_favor_capitan THEN
        INSERT INTO transacciones_capitanes (
            capitan_id,
            pedido_id,
            monto,
            tipo,
            estado,
            created_at
        ) VALUES (
            pedido_actual.capitan_id,
            p_pedido_id,
            monto_a_liberar,
            'ganancia_viaje',
            'disponible',
            NOW()
        );
    END IF;
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo,
        descripcion,
        user_id,
        pedido_id,
        datos_adicionales,
        created_at
    ) VALUES (
        'disputa_resuelta_admin',
        'Administrador resolvió disputa manualmente',
        p_admin_id,
        p_pedido_id,
        jsonb_build_object(
            'favor_capitan', p_favor_capitan,
            'monto_liberado', monto_a_liberar,
            'observaciones', p_observaciones,
            'timestamp', NOW()
        ),
        NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 
           'Disputa resuelta' || CASE WHEN p_favor_capitan THEN ' a favor del capitán' ELSE ' a favor del cliente' END,
           monto_a_liberar;
END;
$$ LANGUAGE plpgsql;

-- Vista para viajes listos para confirmación
CREATE OR REPLACE VIEW vw_viajes_listos_confirmacion AS
SELECT 
    p.*,
    u.email as cliente_email,
    u.raw_user_meta_data->>'nombre' as cliente_nombre,
    CASE 
        WHEN p.fecha_pactada < NOW() AND p.estado = 'en_curso' AND p.cliente_confirmo = FALSE THEN TRUE
        ELSE FALSE
    END as listo_para_confirmar,
    EXTRACT(DAY FROM NOW() - p.fecha_pactada)::INTEGER as dias_desde_pactada
FROM pedidos p
JOIN auth.users u ON p.cliente_id = u.id
WHERE p.estado = 'en_curso'
AND p.fecha_pactada IS NOT NULL
AND p.fecha_pactada < NOW()
AND p.cliente_confirmo = FALSE;

-- Actualizar algunos datos de ejemplo
UPDATE pedidos 
SET 
    fecha_pactada = NOW() - INTERVAL '2 days',
    estado = 'en_curso'
WHERE id IN (
    SELECT id FROM pedidos 
    WHERE estado = 'pendiente' 
    LIMIT 3
) AND fecha_pactada IS NULL;

-- Políticas de seguridad para confirmación de viajes
CREATE POLICY "Clientes pueden confirmar sus viajes"
ON pedidos FOR UPDATE
USING (
    auth.uid() = cliente_id 
    AND estado = 'en_curso'
    AND fecha_pactada < NOW()
    AND cliente_confirmo = FALSE
);

CREATE POLICY "Clientes pueden reportar problemas en sus viajes"
ON pedidos FOR UPDATE
USING (
    auth.uid() = cliente_id 
    AND estado IN ('en_curso', 'completado_pendiente_firma')
);

-- Políticas para transacciones de capitanes
CREATE POLICY "Capitanes ver sus transacciones"
ON transacciones_capitanes FOR SELECT
USING (auth.uid() = capitan_id);

CREATE POLICY "Admin puede ver todas las transacciones"
ON transacciones_capitanes FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND es_capitan = TRUE 
    AND admin = TRUE
));
