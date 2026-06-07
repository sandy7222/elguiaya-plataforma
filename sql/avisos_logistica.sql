-- Sistema de Avisos de Responsabilidad Logística en Carrito de Compras

-- Actualizar tabla pedidos con campos de logística
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS tipo_entrega VARCHAR(20) DEFAULT 'domicilio', -- 'domicilio', 'embarque'
ADD COLUMN IF NOT EXISTS direccion_entrega TEXT,
ADD COLUMN IF NOT EXISTS codigo_postal_entrega VARCHAR(10),
ADD COLUMN IF NOT EXISTS ciudad_entrega VARCHAR(100),
ADD COLUMN IF NOT EXISTS provincia_entrega VARCHAR(100),
ADD COLUMN IF NOT EXISTS tracking_codigo VARCHAR(50),
ADD COLUMN IF NOT EXISTS tracking_url TEXT,
ADD COLUMN IF NOT EXISTS tracking_cargado_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS tracking_cargado_por UUID REFERENCES profiles(user_id),
ADD COLUMN IF NOT EXISTS producto_entregado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS producto_entregado_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS viaje_realizado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS viaje_realizado_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS disclaimer_aceptado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS disclaimer_aceptado_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS bloqueo_embarque_aplicado BOOLEAN DEFAULT FALSE;

-- Crear tabla de envíos logísticos
CREATE TABLE IF NOT EXISTS envios_logisticos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE,
    tipo_envio VARCHAR(20) NOT NULL, -- 'domicilio', 'embarque'
    estado_envio VARCHAR(20) DEFAULT 'preparando', -- 'preparando', 'despachado', 'en_transito', 'entregado'
    tracking_codigo VARCHAR(50),
    tracking_url TEXT,
    transportista VARCHAR(50) DEFAULT 'correo_argentino',
    fecha_despacho TIMESTAMP WITH TIME ZONE,
    fecha_estimada_entrega TIMESTAMP WITH TIME ZONE,
    fecha_entrega_real TIMESTAMP WITH TIME ZONE,
    direccion_entrega TEXT,
    codigo_postal VARCHAR(10),
    ciudad VARCHAR(100),
    provincia VARCHAR(100),
    costo_envio DECIMAL(10,2) DEFAULT 0.0,
    seguro_envio BOOLEAN DEFAULT FALSE,
    notas TEXT,
    creado_por UUID REFERENCES profiles(user_id),
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de avisos legales
CREATE TABLE IF NOT EXISTS avisos_legales (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo_aviso VARCHAR(50) NOT NULL,
    titulo TEXT NOT NULL,
    contenido TEXT NOT NULL,
    version INTEGER DEFAULT 1,
    activo BOOLEAN DEFAULT TRUE,
    obligatorio BOOLEAN DEFAULT FALSE,
    creado_por UUID REFERENCES profiles(user_id),
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de aceptaciones de avisos
CREATE TABLE IF NOT EXISTS aceptaciones_avisos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    aviso_legal_id UUID REFERENCES avisos_legales(id) ON DELETE CASCADE,
    user_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE,
    ip_address INET,
    user_agent TEXT,
    aceptado BOOLEAN DEFAULT TRUE,
    aceptado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_pedidos_tipo_entrega ON pedidos(tipo_entrega);
CREATE INDEX IF NOT EXISTS idx_pedidos_tracking_codigo ON pedidos(tracking_codigo);
CREATE INDEX IF NOT EXISTS idx_pedidos_producto_entregado ON pedidos(producto_entregado);
CREATE INDEX IF NOT EXISTS idx_pedidos_viaje_realizado ON pedidos(viaje_realizado);
CREATE INDEX IF NOT EXISTS idx_envios_logisticos_pedido_id ON envios_logisticos(pedido_id);
CREATE INDEX IF NOT EXISTS idx_envios_logisticos_estado_envio ON envios_logisticos(estado_envio);
CREATE INDEX IF NOT EXISTS idx_envios_logisticos_tracking_codigo ON envios_logisticos(tracking_codigo);
CREATE INDEX IF NOT EXISTS idx_avisos_legales_tipo_aviso ON avisos_legales(tipo_aviso);
CREATE INDEX IF NOT EXISTS idx_aceptaciones_avisos_user_id ON aceptaciones_avisos(user_id);
CREATE INDEX IF NOT EXISTS idx_aceptaciones_avisos_pedido_id ON aceptaciones_avisos(pedido_id);

-- Constraints
ALTER TABLE pedidos 
ADD CONSTRAINT chk_tipo_entrega 
CHECK (tipo_entrega IN ('domicilio', 'embarque', 'retiro_tienda'));

ALTER TABLE envios_logisticos 
ADD CONSTRAINT chk_tipo_envio 
CHECK (tipo_envio IN ('domicilio', 'embarque', 'retiro_tienda'));

ALTER TABLE envios_logisticos 
ADD CONSTRAINT chk_estado_envio 
CHECK (estado_envio IN ('preparando', 'despachado', 'en_transito', 'entregado', 'devuelto', 'perdido'));

-- Función para validar dirección de entrega
CREATE OR REPLACE FUNCTION validar_direccion_entrega(p_tipo_entrega VARCHAR, p_direccion TEXT)
RETURNS TABLE (
    valida BOOLEAN,
    mensaje TEXT,
    permite_embarque BOOLEAN
) AS $$
BEGIN
    -- Bloquear envíos a puntos de embarque
    IF p_tipo_entrega = 'embarque' THEN
        RETURN QUERY SELECT FALSE, 
            'Los productos se envían únicamente a domicilios particulares o comerciales urbanos. No se realizan entregas en puntos de embarque.', 
            FALSE;
    END IF;
    
    -- Validar dirección para domicilio
    IF p_tipo_entrega = 'domicilio' THEN
        IF p_direccion IS NULL OR p_direccion = '' THEN
            RETURN QUERY SELECT FALSE, 'La dirección de entrega es obligatoria', TRUE;
        ELSIF p_direccion ~* '(?i)puerto|muelle|embarcadero|terminal|aeropuerto|estación' THEN
            RETURN QUERY SELECT FALSE, 
                'Los productos se envían únicamente a domicilios particulares o comerciales urbanos. No se realizan entregas en puntos de embarque.', 
                FALSE;
        ELSE
            RETURN QUERY SELECT TRUE, 'Dirección válida', TRUE;
        END IF;
    END IF;
    
    RETURN QUERY SELECT TRUE, 'Tipo de entrega válido', TRUE;
END;
$$ LANGUAGE plpgsql;

-- Función para crear envío logístico
CREATE OR REPLACE FUNCTION crear_envio_logistico(
    p_pedido_id UUID,
    p_tipo_envio VARCHAR,
    p_direccion TEXT,
    p_codigo_postal VARCHAR,
    p_ciudad VARCHAR,
    p_provincia VARCHAR,
    p_costo_envio DECIMAL DEFAULT 0.0,
    p_seguro BOOLEAN DEFAULT FALSE,
    p_notas TEXT DEFAULT NULL
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    envio_id UUID
) AS $$
DECLARE
    validacion_direccion RECORD;
    nuevo_envio_id UUID;
    pedido_actual RECORD;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL::UUID;
        RETURN;
    END IF;
    
    -- Validar dirección
    SELECT * INTO validacion_direccion
    FROM validar_direccion_entrega(p_tipo_envio, p_direccion);
    
    IF validacion_direccion.valida = FALSE THEN
        -- Marcar bloqueo de embarque si aplica
        IF validacion_direccion.permite_embarque = FALSE THEN
            UPDATE pedidos
            SET bloqueo_embarque_aplicado = TRUE,
                updated_at = NOW()
            WHERE id = p_pedido_id;
        END IF;
        
        RETURN QUERY SELECT FALSE, validacion_direccion.mensaje, NULL::UUID;
        RETURN;
    END IF;
    
    -- Crear envío logístico
    INSERT INTO envios_logisticos (
        pedido_id, tipo_envio, estado_envio, direccion_entrega,
        codigo_postal, ciudad, provincia, costo_envio, seguro_envio,
        notas, creado_por, creado_at
    ) VALUES (
        p_pedido_id, p_tipo_envio, 'preparando', p_direccion,
        p_codigo_postal, p_ciudad, p_provincia, p_costo_envio, p_seguro,
        p_notas, pedido_actual.pescador_id, NOW()
    )
    RETURNING id INTO nuevo_envio_id;
    
    -- Actualizar pedido
    UPDATE pedidos
    SET 
        tipo_entrega = p_tipo_envio,
        direccion_entrega = p_direccion,
        codigo_postal_entrega = p_codigo_postal,
        ciudad_entrega = p_ciudad,
        provincia_entrega = p_provincia,
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    RETURN QUERY SELECT TRUE, 'Envío logístico creado exitosamente', nuevo_envio_id;
END;
$$ LANGUAGE plpgsql;

-- Función para cargar tracking de envío
CREATE OR REPLACE FUNCTION cargar_tracking_envio(
    p_envio_id UUID,
    p_tracking_codigo VARCHAR,
    p_admin_id UUID
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    tracking_url TEXT
) AS $$
DECLARE
    envio_actual RECORD;
    tracking_url_generada TEXT;
BEGIN
    -- Obtener datos del envío
    SELECT * INTO envio_actual
    FROM envios_logisticos
    WHERE id = p_envio_id;
    
    IF envio_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Envío no encontrado', NULL;
        RETURN;
    END IF;
    
    -- Generar URL de tracking de Correo Argentino
    tracking_url_generada := 'https://www.correoargentino.com.ar/formularios/consulta-envio?codigo=' || p_tracking_codigo;
    
    -- Actualizar envío con tracking
    UPDATE envios_logisticos
    SET 
        tracking_codigo = p_tracking_codigo,
        tracking_url = tracking_url_generada,
        estado_envio = 'despachado',
        fecha_despacho = NOW(),
        actualizado_at = NOW()
    WHERE id = p_envio_id;
    
    -- Actualizar pedido con tracking
    UPDATE pedidos
    SET 
        tracking_codigo = p_tracking_codigo,
        tracking_url = tracking_url_generada,
        tracking_cargado_at = NOW(),
        tracking_cargado_por = p_admin_id,
        updated_at = NOW()
    WHERE id = envio_actual.pedido_id;
    
    -- Enviar notificación al pescador
    INSERT INTO notificaciones_usuarios (
        user_id, tipo, titulo, mensaje, datos_adicionales, leida, created_at
    ) VALUES (
        envio_actual.pedido_id, -- Asumimos que el pescador está en el pedido
        'tracking_disponible',
        '📦 Código de Tracking Disponible',
        'Tu pedido ha sido despachado. Podés seguirlo con el código: ' || p_tracking_codigo,
        jsonb_build_object(
            'envio_id', p_envio_id,
            'tracking_codigo', p_tracking_codigo,
            'tracking_url', tracking_url_generada,
            'accion_requerida', 'seguir_envio'
        ),
        FALSE, NOW()
    );
    
    RETURN QUERY SELECT TRUE, 'Tracking cargado exitosamente', tracking_url_generada;
END;
$$ LANGUAGE plpgsql;

-- Función para marcar producto como entregado
CREATE OR REPLACE FUNCTION marcar_producto_entregado(p_pedido_id UUID, p_admin_id UUID)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    liquidacion_habilitada BOOLEAN
) AS $$
DECLARE
    pedido_actual RECORD;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', FALSE;
        RETURN;
    END IF;
    
    -- Marcar producto como entregado
    UPDATE pedidos
    SET 
        producto_entregado = TRUE,
        producto_entregado_at = NOW(),
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    -- Actualizar envío
    UPDATE envios_logisticos
    SET 
        estado_envio = 'entregado',
        fecha_entrega_real = NOW(),
        actualizado_at = NOW()
    WHERE pedido_id = p_pedido_id;
    
    -- Verificar si la liquidación está habilitada (independiente del viaje)
    -- La liquidación depende solo del viaje realizado, no del producto entregado
    DECLARE
        liquidacion_permite BOOLEAN := FALSE;
    BEGIN
        IF pedido_actual.viaje_realizado = TRUE THEN
            liquidacion_permite := TRUE;
        END IF;
        
        RETURN QUERY SELECT TRUE, 'Producto marcado como entregado', liquidacion_permite;
    END;
END;
$$ LANGUAGE plpgsql;

-- Función para marcar viaje como realizado
CREATE OR REPLACE FUNCTION marcar_viaje_realizado(p_pedido_id UUID, p_admin_id UUID)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    liquidacion_habilitada BOOLEAN
) AS $$
DECLARE
    pedido_actual RECORD;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', FALSE;
        RETURN;
    END IF;
    
    -- Marcar viaje como realizado
    UPDATE pedidos
    SET 
        viaje_realizado = TRUE,
        viaje_realizado_at = NOW(),
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    -- Actualizar cotización
    UPDATE cotizaciones
    SET 
        estado = 'liquidado',
        updated_at = NOW()
    WHERE id = pedido_actual.cotizacion_id;
    
    -- La liquidación está habilitada porque el viaje está realizado
    -- (independientemente de si el producto fue entregado)
    RETURN QUERY SELECT TRUE, 'Viaje marcado como realizado', TRUE;
END;
$$ LANGUAGE plpgsql;

-- Función para registrar aceptación de disclaimer
CREATE OR REPLACE FUNCTION registrar_aceptacion_disclaimer(
    p_user_id UUID,
    p_pedido_id UUID,
    p_ip_address INET DEFAULT NULL,
    p_user_agent TEXT DEFAULT NULL
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    aceptacion_id UUID
) AS $$
DECLARE
    aviso_legal_id UUID;
    nueva_aceptacion_id UUID;
BEGIN
    -- Obtener disclaimer activo
    SELECT id INTO aviso_legal_id
    FROM avisos_legales
    WHERE tipo_aviso = 'tiempos_entrega'
    AND activo = TRUE
    ORDER BY version DESC
    LIMIT 1;
    
    IF aviso_legal_id IS NULL THEN
        RETURN QUERY SELECT FALSE, 'No hay disclaimer activo', NULL::UUID;
        RETURN;
    END IF;
    
    -- Crear registro de aceptación
    INSERT INTO aceptaciones_avisos (
        aviso_legal_id, user_id, pedido_id, ip_address, user_agent, aceptado, aceptado_at
    ) VALUES (
        aviso_legal_id, p_user_id, p_pedido_id, p_ip_address, p_user_agent, TRUE, NOW()
    )
    RETURNING id INTO nueva_aceptacion_id;
    
    -- Actualizar pedido
    UPDATE pedidos
    SET 
        disclaimer_aceptado = TRUE,
        disclaimer_aceptado_at = NOW(),
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    RETURN QUERY SELECT TRUE, 'Aceptación registrada exitosamente', nueva_aceptacion_id;
END;
$$ LANGUAGE plpgsql;

-- Vista para seguimiento de envíos del pescador
CREATE OR REPLACE VIEW vw_seguimiento_pescador AS
SELECT 
    e.*,
    p.id as pedido_id,
    p.pescador_id,
    p.created_at as pedido_fecha,
    p.total as pedido_total,
    p.estado as pedido_estado,
    CASE 
        WHEN e.tracking_url IS NOT NULL THEN e.tracking_url
        ELSE NULL
    END as enlace_seguimiento,
    CASE 
        WHEN e.estado_envio = 'entregado' THEN '✅ Entregado'
        WHEN e.estado_envio = 'en_transito' THEN '🚚 En Tránsito'
        WHEN e.estado_envio = 'despachado' THEN '📦 Despachado'
        WHEN e.estado_envio = 'preparando' THEN '🔄 Preparando'
        ELSE '❓ Desconocido'
    END as estado_formateado,
    CASE 
        WHEN e.estado_envio = 'entregado' THEN '#10B981'
        WHEN e.estado_envio = 'en_transito' THEN '#F59E0B'
        WHEN e.estado_envio = 'despachado' THEN '#3B82F6'
        WHEN e.estado_envio = 'preparando' THEN '#6B7280'
        ELSE '#EF4444'
    END as color_estado
FROM envios_logisticos e
JOIN pedidos p ON e.pedido_id = p.id
WHERE e.tipo_envio = 'domicilio'
ORDER BY e.creado_at DESC;

-- Vista para gestión logística del administrador
CREATE OR REPLACE VIEW vw_gestion_logistica_admin AS
SELECT 
    e.*,
    p.id as pedido_id,
    p.pescador_id,
    pe.nombre as pescador_nombre,
    pe.email as pescador_email,
    p.total as pedido_total,
    p.estado as pedido_estado,
    p.producto_entregado,
    p.viaje_realizado,
    CASE 
        WHEN p.producto_entregado = TRUE AND p.viaje_realizado = TRUE THEN '✅ Completo'
        WHEN p.producto_entregado = TRUE THEN '📦 Producto Entregado'
        WHEN p.viaje_realizado = TRUE THEN '🚢 Viaje Realizado'
        ELSE '⏳ Pendiente'
    END as estado_general,
    CASE 
        WHEN p.producto_entregado = TRUE AND p.viaje_realizado = TRUE THEN '#10B981'
        WHEN p.producto_entregado = TRUE THEN '#3B82F6'
        WHEN p.viaje_realizado = TRUE THEN '#F59E0B'
        ELSE '#6B7280'
    END as color_general,
    CASE 
        WHEN p.producto_entregado = TRUE AND p.viaje_realizado = TRUE THEN TRUE
        ELSE FALSE
    END as liquidacion_posible
FROM envios_logisticos e
JOIN pedidos p ON e.pedido_id = p.id
LEFT JOIN profiles pe ON p.pescador_id = pe.user_id
ORDER BY e.creado_at DESC;

-- Función para obtener seguimiento de envíos del pescador
CREATE OR REPLACE FUNCTION get_seguimiento_pescador(p_pescador_id UUID)
RETURNS TABLE (
    envio_id UUID,
    pedido_id UUID,
    estado_envio VARCHAR,
    estado_formateado TEXT,
    color_estado TEXT,
    tracking_codigo VARCHAR,
    tracking_url TEXT,
    enlace_seguimiento TEXT,
    direccion_entrega TEXT,
    fecha_despacho TIMESTAMP WITH TIME ZONE,
    fecha_estimada_entrega TIMESTAMP WITH TIME ZONE,
    transportista VARCHAR
) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        e.id,
        e.pedido_id,
        e.estado_envio,
        CASE 
            WHEN e.estado_envio = 'entregado' THEN '✅ Entregado'
            WHEN e.estado_envio = 'en_transito' THEN '🚚 En Tránsito'
            WHEN e.estado_envio = 'despachado' THEN '📦 Despachado'
            WHEN e.estado_envio = 'preparando' THEN '🔄 Preparando'
            ELSE '❓ Desconocido'
        END as estado_formateado,
        CASE 
            WHEN e.estado_envio = 'entregado' THEN '#10B981'
            WHEN e.estado_envio = 'en_transito' THEN '#F59E0B'
            WHEN e.estado_envio = 'despachado' THEN '#3B82F6'
            WHEN e.estado_envio = 'preparando' THEN '#6B7280'
            ELSE '#EF4444'
        END as color_estado,
        e.tracking_codigo,
        e.tracking_url,
        CASE 
            WHEN e.tracking_url IS NOT NULL THEN e.tracking_url
            ELSE NULL
        END as enlace_seguimiento,
        e.direccion_entrega,
        e.fecha_despacho,
        e.fecha_estimada_entrega,
        e.transportista
    FROM vw_seguimiento_pescador e
    WHERE e.pescador_id = p_pescador_id
    ORDER BY e.creado_at DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener gestión logística del administrador
CREATE OR REPLACE FUNCTION get_gestion_logistica_admin()
RETURNS TABLE (
    envio_id UUID,
    pedido_id UUID,
    pescador_id UUID,
    pescador_nombre TEXT,
    pescador_email TEXT,
    estado_envio VARCHAR,
    tracking_codigo VARCHAR,
    tracking_url TEXT,
    pedido_total DECIMAL,
    pedido_estado VARCHAR,
    producto_entregado BOOLEAN,
    viaje_realizado BOOLEAN,
    estado_general TEXT,
    color_general TEXT,
    liquidacion_posible BOOLEAN,
    direccion_entrega TEXT,
    fecha_despacho TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM vw_gestion_logistica_admin;
END;
$$ LANGUAGE plpgsql;

-- Insertar avisos legales por defecto
INSERT INTO avisos_legales (tipo_aviso, titulo, contenido, obligatorio) VALUES 
(
    'bloqueo_embarque',
    'Restricción de Entrega en Puntos de Embarque',
    'Los productos se envían únicamente a domicilios particulares o comerciales urbanos. No se realizan entregas en puntos de embarque, muelles, puertos o terminales.',
    TRUE
),
(
    'tiempos_entrega',
    'Tiempos de Entrega',
    'CapitánYA no gestiona los tiempos de entrega finales. Una vez despachado, el servicio queda sujeto a los plazos de Correo Argentino.',
    TRUE
)
ON CONFLICT DO NOTHING;

-- Políticas de seguridad
CREATE POLICY "Pescadores pueden ver su seguimiento"
ON vw_seguimiento_pescador FOR SELECT
USING (pescador_id = auth.uid());

CREATE POLICY "Admin puede ver gestión logística"
ON vw_gestion_logistica_admin FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Usuarios pueden crear envíos"
ON envios_logisticos FOR INSERT
WITH CHECK (creado_por = auth.uid());

CREATE POLICY "Admin puede actualizar envíos"
ON envios_logisticos FOR UPDATE
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Usuarios pueden registrar aceptaciones"
ON aceptaciones_avisos FOR INSERT
WITH CHECK (user_id = auth.uid());
