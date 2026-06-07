-- Agregar campos necesarios para cierre de operaciones en pedidos
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS fecha_regreso TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS estado_retorno VARCHAR(20) DEFAULT 'pendiente',
ADD COLUMN IF NOT EXISTS retorno_confirmado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS retorno_confirmado_por UUID,
ADD COLUMN IF NOT EXISTS retorno_confirmado_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS viaje_demorado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS alerta_demora_enviada BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS cierre_manual_admin BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS cierre_manual_por UUID,
ADD COLUMN IF NOT EXISTS cierre_manual_at TIMESTAMP WITH TIME ZONE;

-- Agregar constraint para estado_retorno
ALTER TABLE pedidos 
ADD CONSTRAINT chk_estado_retorno 
CHECK (estado_retorno IN ('pendiente', 'listo_para_confirmar', 'confirmado', 'demorado', 'cerrado_manual'));

-- Crear índices para optimización de consultas de cierre
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha_regreso ON pedidos(fecha_regreso);
CREATE INDEX IF NOT EXISTS idx_pedidos_estado_retorno ON pedidos(estado_retorno);
CREATE INDEX IF NOT EXISTS idx_pedidos_retorno_confirmado ON pedidos(retorno_confirmado);
CREATE INDEX IF NOT EXISTS idx_pedidos_viaje_demorado ON pedidos(viaje_demorado);
CREATE INDEX IF NOT EXISTS idx_pedidos_cierre_manual_admin ON pedidos(cierre_manual_admin);

-- Función principal de vigilancia para cierre de operaciones
CREATE OR REPLACE FUNCTION vigilancia_cierre_operaciones()
RETURNS TABLE (
    pedidos_procesados INTEGER,
    notificaciones_enviadas INTEGER,
    alertas_demora_creadas INTEGER,
    detalles_procesamiento JSONB
) AS $$
DECLARE
    pedidos_procesados_count INTEGER := 0;
    notificaciones_enviadas_count INTEGER := 0;
    alertas_demora_creadas_count INTEGER := 0;
    detalles JSONB := '[]'::JSONB;
    
    -- Variables para procesamiento
    pedido_actual RECORD;
    horas_desde_retorno DECIMAL;
    hora_actual TIMESTAMP WITH TIME ZONE := NOW();
    
    -- Cursor para pedidos en curso con fecha_regreso
    cursor_pedidos CURSOR FOR 
        SELECT p.*, u.email as cliente_email, u.raw_user_meta_data->>'nombre' as cliente_nombre
        FROM pedidos p
        JOIN auth.users u ON p.cliente_id = u.id
        WHERE p.estado = 'en_curso'
        AND p.fecha_regreso IS NOT NULL
        AND p.estado_retorno != 'cerrado_manual';
BEGIN
    OPEN cursor_pedidos;
    
    LOOP
        FETCH cursor_pedidos INTO pedido_actual;
        EXIT WHEN NOT FOUND;
        
        pedidos_procesados_count := pedidos_procesados_count + 1;
        
        -- Calcular horas desde fecha de retorno
        horas_desde_retorno := EXTRACT(EPOCH FROM (hora_actual - pedido_actual.fecha_regreso)) / 3600;
        
        -- Caso 1: Han pasado más de 2 horas desde el retorno
        IF horas_desde_retorno >= 2 AND pedido_actual.estado_retorno = 'pendiente' THEN
            -- Actualizar estado a listo para confirmar
            UPDATE pedidos
            SET 
                estado_retorno = 'listo_para_confirmar',
                updated_at = hora_actual
            WHERE id = pedido_actual.id;
            
            -- Crear notificación para el pescador
            INSERT INTO notificaciones_usuarios (
                user_id,
                tipo,
                titulo,
                mensaje,
                datos_adicionales,
                leida,
                created_at
            ) VALUES (
                pedido_actual.cliente_id,
                'retorno_listo_confirmar',
                '¡Viaje Completado!',
                'Confirma tu regreso para liberar el pago al capitán.',
                jsonb_build_object(
                    'pedido_id', pedido_actual.id,
                    'fecha_regreso', pedido_actual.fecha_regreso,
                    'horas_desde_retorno', horas_desde_retorno,
                    'monto', pedido_actual.total,
                    'accion_requerida', 'confirmar_retorno'
                ),
                FALSE,
                hora_actual
            );
            
            notificaciones_enviadas_count := notificaciones_enviadas_count + 1;
            
            -- Agregar a detalles
            detalles := detalles || jsonb_build_object(
                'pedido_id', pedido_actual.id,
                'accion', 'notificacion_enviada',
                'horas_desde_retorno', horas_desde_retorno,
                'timestamp', hora_actual
            );
            
        -- Caso 2: Han pasado más de 12 horas y sigue en curso (alerta de demora)
        ELSIF horas_desde_retorno >= 12 AND pedido_actual.estado_retorno IN ('pendiente', 'listo_para_confirmar') AND NOT pedido_actual.viaje_demorado THEN
            -- Marcar como demorado
            UPDATE pedidos
            SET 
                estado_retorno = 'demorado',
                viaje_demorado = TRUE,
                alerta_demora_enviada = TRUE,
                updated_at = hora_actual
            WHERE id = pedido_actual.id;
            
            -- Crear alerta de alta prioridad para administrador
            INSERT INTO alertas_negocio (
                tipo,
                pedido_id,
                cliente_id,
                capitan_id,
                descripcion,
                datos_adicionales,
                prioridad,
                notificada,
                created_at
            ) VALUES (
                'viaje_demorado',
                pedido_actual.id,
                pedido_actual.cliente_id,
                pedido_actual.capitan_id,
                'Viaje demorado - Sin confirmación de retorno',
                jsonb_build_object(
                    'horas_demora', horas_desde_retorno,
                    'fecha_regreso', pedido_actual.fecha_regreso,
                    'monto_afectado', pedido_actual.total,
                    'cliente_nombre', pedido_actual.cliente_nombre,
                    'cliente_email', pedido_actual.cliente_email,
                    'urgencia', 'alta'
                ),
                'alta',
                FALSE,
                hora_actual
            );
            
            alertas_demora_creadas_count := alertas_demora_creadas_count + 1;
            
            -- Agregar a detalles
            detalles := detalles || jsonb_build_object(
                'pedido_id', pedido_actual.id,
                'accion', 'alerta_demora_creada',
                'horas_demora', horas_desde_retorno,
                'prioridad', 'alta',
                'timestamp', hora_actual
            );
            
        -- Caso 3: Viaje demorado hace más de 24 horas (alerta crítica)
        ELSIF horas_desde_retorno >= 24 AND pedido_actual.viaje_demorado THEN
            -- Actualizar alerta a crítica
            UPDATE alertas_negocio
            SET 
                prioridad = 'critica',
                datos_adicionales = jsonb_set(
                    datos_adicionales,
                    '{urgencia_actualizada}',
                    '"critica"'
                ),
                updated_at = hora_actual
            WHERE pedido_id = pedido_actual.id
            AND tipo = 'viaje_demorado'
            AND prioridad != 'critica';
            
            -- Agregar a detalles
            detalles := detalles || jsonb_build_object(
                'pedido_id', pedido_actual.id,
                'accion', 'alerta_actualizada_critica',
                'horas_demora', horas_desde_retorno,
                'prioridad', 'critica',
                'timestamp', hora_actual
            );
        END IF;
        
    END LOOP;
    
    CLOSE cursor_pedidos;
    
    -- Retornar resultados
    RETURN QUERY 
    SELECT pedidos_procesados_count, notificaciones_enviadas_count, 
           alertas_demora_creadas_count, detalles;
END;
$$ LANGUAGE plpgsql;

-- Función para confirmar retorno y liberar pago
CREATE OR REPLACE FUNCTION confirmar_retorno_y_liberar_pago(
    p_pedido_id UUID,
    p_cliente_id UUID
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    pedido_id UUID,
    nuevo_estado VARCHAR,
    monto_liberado DECIMAL
) AS $$
DECLARE
    pedido_actual RECORD;
    monto_a_liberar DECIMAL;
    hora_actual TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    -- Validaciones
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL, NULL, 0;
        RETURN;
    END IF;
    
    IF pedido_actual.cliente_id != p_cliente_id THEN
        RETURN QUERY SELECT FALSE, 'No tienes permiso para confirmar este pedido', NULL, NULL, 0;
        RETURN;
    END IF;
    
    IF pedido_actual.estado != 'en_curso' THEN
        RETURN QUERY SELECT FALSE, 'El pedido no está en curso', NULL, NULL, 0;
        RETURN;
    END IF;
    
    IF pedido_actual.retorno_confirmado = TRUE THEN
        RETURN QUERY SELECT FALSE, 'El retorno ya fue confirmado', NULL, NULL, 0;
        RETURN;
    END IF;
    
    -- Calcular monto a liberar (90% para el capitán)
    monto_a_liberar := pedido_actual.total * 0.9;
    
    -- Actualizar pedido
    UPDATE pedidos
    SET 
        estado_retorno = 'confirmado',
        retorno_confirmado = TRUE,
        retorno_confirmado_por = p_cliente_id,
        retorno_confirmado_at = hora_actual,
        estado = 'completado_pendiente_firma',
        updated_at = hora_actual
    WHERE id = p_pedido_id;
    
    -- Crear transacción para el capitán
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
        hora_actual
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
        'retorno_confirmado_pago_liberado',
        'Cliente confirmó retorno y pago liberado',
        p_cliente_id,
        p_pedido_id,
        jsonb_build_object(
            'monto_liberado', monto_a_liberar,
            'capitan_id', pedido_actual.capitan_id,
            'confirmado_at', hora_actual
        ),
        hora_actual
    );
    
    -- Crear notificación para el capitán
    INSERT INTO notificaciones_usuarios (
        user_id,
        tipo,
        titulo,
        mensaje,
        datos_adicionales,
        leida,
        created_at
    ) VALUES (
        pedido_actual.capitan_id,
        'pago_liberado',
        '¡Pago Liberado!',
        'El cliente confirmó tu regreso. Tu pago ya está disponible.',
        jsonb_build_object(
            'pedido_id', p_pedido_id,
            'monto', monto_a_liberar,
            'estado', 'disponible'
        ),
        FALSE,
        hora_actual
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Retorno confirmado y pago liberado exitosamente', 
           p_pedido_id, 'completado_pendiente_firma', monto_a_liberar;
END;
$$ LANGUAGE plpgsql;

-- Función para cierre manual por administrador
CREATE OR REPLACE FUNCTION cierre_manual_admin(
    p_pedido_id UUID,
    p_admin_id UUID,
    p_observaciones TEXT DEFAULT NULL,
    p_liberar_pago BOOLEAN DEFAULT TRUE
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    pedido_id UUID,
    nuevo_estado VARCHAR,
    monto_afectado DECIMAL
) AS $$
DECLARE
    pedido_actual RECORD;
    monto_a_liberar DECIMAL;
    hora_actual TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    -- Validaciones
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL, NULL, 0;
        RETURN;
    END IF;
    
    -- Calcular monto a liberar si se requiere
    IF p_liberar_pago THEN
        monto_a_liberar := pedido_actual.total * 0.9;
    ELSE
        monto_a_liberar := 0;
    END IF;
    
    -- Actualizar pedido
    UPDATE pedidos
    SET 
        estado_retorno = 'cerrado_manual',
        cierre_manual_admin = TRUE,
        cierre_manual_por = p_admin_id,
        cierre_manual_at = hora_actual,
        admin_observaciones = p_observaciones,
        updated_at = hora_actual
    WHERE id = p_pedido_id;
    
    -- Si se libera pago, crear transacción
    IF p_liberar_pago THEN
        UPDATE pedidos
        SET estado = 'completado_pendiente_firma'
        WHERE id = p_pedido_id;
        
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
            hora_actual
        );
    ELSE
        UPDATE pedidos
        SET estado = 'cancelado'
        WHERE id = p_pedido_id;
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
        'cierre_manual_admin',
        'Administrador realizó cierre manual',
        p_admin_id,
        p_pedido_id,
        jsonb_build_object(
            'liberar_pago', p_liberar_pago,
            'monto_afectado', monto_a_liberar,
            'observaciones', p_observaciones,
            'cerrado_at', hora_actual
        ),
        hora_actual
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Cierre manual realizado exitosamente', 
           p_pedido_id, pedido_actual.estado, monto_a_liberar;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener viajes listos para confirmar retorno
CREATE OR REPLACE FUNCTION get_viajes_listos_confirmar_retorno(p_cliente_id UUID)
RETURNS TABLE (
    pedido_id UUID,
    descripcion TEXT,
    monto_total DECIMAL,
    fecha_regreso TIMESTAMP WITH TIME ZONE,
    horas_desde_retorno DECIMAL,
    estado_retorno VARCHAR,
    capitan_nombre VARCHAR,
    urgencia VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as pedido_id,
        p.descripcion,
        p.total as monto_total,
        p.fecha_regreso,
        EXTRACT(EPOCH FROM (NOW() - p.fecha_regreso)) / 3600 as horas_desde_retorno,
        p.estado_retorno,
        COALESCE(u.email, 'Capitán sin email') as capitan_nombre,
        CASE 
            WHEN EXTRACT(EPOCH FROM (NOW() - p.fecha_regreso)) / 3600 >= 24 THEN 'critica'
            WHEN EXTRACT(EPOCH FROM (NOW() - p.fecha_regreso)) / 3600 >= 12 THEN 'alta'
            WHEN EXTRACT(EPOCH FROM (NOW() - p.fecha_regreso)) / 3600 >= 6 THEN 'media'
            ELSE 'baja'
        END as urgencia
    FROM pedidos p
    JOIN auth.users u ON p.capitan_id = u.id
    WHERE p.cliente_id = p_cliente_id
    AND p.estado = 'en_curso'
    AND p.fecha_regreso IS NOT NULL
    AND p.estado_retorno IN ('listo_para_confirmar', 'demorado')
    AND p.retorno_confirmado = FALSE
    ORDER BY p.fecha_regreso ASC;
END;
$$ LANGUAGE plpgsql;

-- Vista para monitoreo de cierres
CREATE OR REPLACE VIEW vw_monitor_cierres AS
SELECT 
    p.*,
    u1.email as cliente_email,
    u1.raw_user_meta_data->>'nombre' as cliente_nombre,
    u2.email as capitan_email,
    u2.raw_user_meta_data->>'nombre' as capitan_nombre,
    EXTRACT(EPOCH FROM (NOW() - p.fecha_regreso)) / 3600 as horas_desde_retorno,
    CASE 
        WHEN p.estado_retorno = 'pendiente' AND p.fecha_regreso > NOW() THEN 'en_vuelo'
        WHEN p.estado_retorno = 'pendiente' AND p.fecha_regreso <= NOW() THEN 'reciente_llegada'
        WHEN p.estado_retorno = 'listo_para_confirmar' THEN 'listo_confirmar'
        WHEN p.estado_retorno = 'confirmado' THEN 'confirmado'
        WHEN p.estado_retorno = 'demorado' THEN 'demorado'
        WHEN p.estado_retorno = 'cerrado_manual' THEN 'cerrado_manual'
        ELSE 'desconocido'
    END as estado_actual,
    CASE 
        WHEN p.viaje_demorado = TRUE THEN 'alta'
        WHEN p.estado_retorno = 'demorado' THEN 'media'
        ELSE 'normal'
    END as nivel_alerta
FROM pedidos p
JOIN auth.users u1 ON p.cliente_id = u1.id
JOIN auth.users u2 ON p.capitan_id = u2.id
WHERE p.fecha_regreso IS NOT NULL
AND p.estado IN ('en_curso', 'completado_pendiente_firma', 'cancelado')
ORDER BY p.fecha_regreso DESC;

-- Trigger para ejecutar vigilancia cada 5 minutos (mediante función programada)
CREATE OR REPLACE FUNCTION ejecutar_vigilancia_cierres()
RETURNS VOID AS $$
BEGIN
    PERFORM vigilancia_cierre_operaciones();
END;
$$ LANGUAGE plpgsql;

-- Actualizar datos de ejemplo en pedidos
UPDATE pedidos 
SET 
    fecha_regreso = NOW() + INTERVAL '3 hours',
    estado_retorno = 'pendiente'
WHERE estado = 'en_curso' 
AND fecha_regreso IS NULL
LIMIT 5;

-- Crear algunos pedidos de ejemplo ya listos para confirmar
UPDATE pedidos 
SET 
    fecha_regreso = NOW() - INTERVAL '3 hours',
    estado_retorno = 'listo_para_confirmar'
WHERE estado = 'en_curso' 
AND id IN (
    SELECT id FROM pedidos 
    WHERE estado = 'en_curso' 
    LIMIT 3
);

-- Políticas de seguridad para operaciones de cierre
CREATE POLICY "Clientes pueden confirmar sus retornos"
ON pedidos FOR UPDATE
USING (
    auth.uid() = cliente_id 
    AND estado = 'en_curso'
    AND fecha_regreso <= NOW()
    AND retorno_confirmado = FALSE
);

CREATE POLICY "Admin puede realizar cierre manual"
ON pedidos FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM profiles 
        WHERE user_id = auth.uid() 
        AND es_capitan = TRUE 
        AND admin = TRUE
    )
    AND estado = 'en_curso'
);

-- Función para verificar si un viaje está listo para confirmar retorno
CREATE OR REPLACE FUNCTION verificar_viaje_listo_confirmar_retorno(p_pedido_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    pedido_actual RECORD;
    horas_desde_retorno DECIMAL;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    -- Verificar si está listo para confirmar
    IF pedido_actual IS NULL THEN
        RETURN FALSE;
    END IF;
    
    -- Calcular horas desde retorno
    horas_desde_retorno := EXTRACT(EPOCH FROM (NOW() - pedido_actual.fecha_regreso)) / 3600;
    
    -- Está listo si han pasado 2 horas y no está confirmado
    RETURN horas_desde_retorno >= 2 
           AND pedido_actual.estado = 'en_curso'
           AND pedido_actual.retorno_confirmado = FALSE;
END;
$$ LANGUAGE plpgsql;
