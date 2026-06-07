-- Sistema de Independencia Logística - Doble Check-out y Gestión Separada

-- Crear tabla de pedidos_tienda (independiente de cotizaciones)
CREATE TABLE IF NOT EXISTS pedidos_tienda (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pescador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    carrito_id UUID,
    estado VARCHAR(20) DEFAULT 'carrito', -- 'carrito', 'pagado', 'despachado', 'entregado', 'cancelado'
    subtotal DECIMAL(10,2) DEFAULT 0.0,
    costo_envio DECIMAL(10,2) DEFAULT 0.0,
    total DECIMAL(10,2) DEFAULT 0.0,
    metodo_pago VARCHAR(50),
    pago_confirmado BOOLEAN DEFAULT FALSE,
    pago_confirmado_at TIMESTAMP WITH TIME ZONE,
    productos JSONB DEFAULT '[]'::JSONB,
    direccion_entrega JSONB DEFAULT '{}'::JSONB, -- Solo campos de texto
    tipo_entrega VARCHAR(20) DEFAULT 'domicilio', -- 'domicilio', 'retiro_tienda'
    bloqueo_embarque_aplicado BOOLEAN DEFAULT FALSE,
    disclaimer_aceptado BOOLEAN DEFAULT FALSE,
    disclaimer_aceptado_at TIMESTAMP WITH TIME ZONE,
    tracking_codigo VARCHAR(50),
    tracking_url TEXT,
    tracking_cargado_at TIMESTAMP WITH TIME ZONE,
    tracking_cargado_por UUID REFERENCES profiles(user_id),
    despachado BOOLEAN DEFAULT FALSE,
    despachado_at TIMESTAMP WITH TIME ZONE,
    despachado_por UUID REFERENCES profiles(user_id),
    entregado BOOLEAN DEFAULT FALSE,
    entregado_at TIMESTAMP WITH TIME ZONE,
    entregado_por UUID REFERENCES profiles(user_id),
    notas_admin TEXT,
    datos_pago JSONB DEFAULT '{}'::JSONB,
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de reservas_viajes (independiente de pedidos_tienda)
CREATE TABLE IF NOT EXISTS reservas_viajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pescador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    cotizacion_id UUID REFERENCES cotizaciones(id) ON DELETE CASCADE,
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE SET NULL,
    estado VARCHAR(20) DEFAULT 'reservado', -- 'reservado', 'confirmado', 'pagado', 'realizado', 'cancelado', 'liquidado'
    monto_cotizacion DECIMAL(10,2) DEFAULT 0.0,
    monto_adicional DECIMAL(10,2) DEFAULT 0.0,
    monto_total DECIMAL(10,2) DEFAULT 0.0,
    metodo_pago VARCHAR(50),
    pago_confirmado BOOLEAN DEFAULT FALSE,
    pago_confirmado_at TIMESTAMP WITH TIME ZONE,
    datos_pasajeros JSONB DEFAULT '[]'::JSONB,
    manifiesto_id UUID,
    productos_tienda JSONB DEFAULT '[]'::JSONB, -- Referencia a productos del pedido_tienda
    total_bultos INTEGER DEFAULT 0,
    contacto_habilitado BOOLEAN DEFAULT FALSE,
    contacto_habilitado_at TIMESTAMP WITH TIME ZONE,
    realizado BOOLEAN DEFAULT FALSE,
    realizado_at TIMESTAMP WITH TIME ZONE,
    realizado_por UUID REFERENCES profiles(user_id),
    liquidado BOOLEAN DEFAULT FALSE,
    liquidado_at TIMESTAMP WITH TIME ZONE,
    liquidado_por UUID REFERENCES profiles(user_id),
    notas_admin TEXT,
    datos_pago JSONB DEFAULT '{}'::JSONB,
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Tabla de vinculación entre pedidos_tienda y reservas_viajes
CREATE TABLE IF NOT EXISTS vinculo_logistico (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_tienda_id UUID REFERENCES pedidos_tienda(id) ON DELETE CASCADE,
    reserva_viaje_id UUID REFERENCES reservas_viajes(id) ON DELETE CASCADE,
    pescador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    tipo_vinculo VARCHAR(20) DEFAULT 'combinado', -- 'combinado', 'separado'
    estado VARCHAR(20) DEFAULT 'activo', -- 'activo', 'inactivo'
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(pedido_tienda_id, reserva_viaje_id)
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_pedidos_tienda_pescador_id ON pedidos_tienda(pescador_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_tienda_estado ON pedidos_tienda(estado);
CREATE INDEX IF NOT EXISTS idx_pedidos_tienda_tracking_codigo ON pedidos_tienda(tracking_codigo);
CREATE INDEX IF NOT EXISTS idx_reservas_viajes_pescador_id ON reservas_viajes(pescador_id);
CREATE INDEX IF NOT EXISTS idx_reservas_viajes_estado ON reservas_viajes(estado);
CREATE INDEX IF NOT EXISTS idx_reservas_viajes_cotizacion_id ON reservas_viajes(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_vinculo_logistico_pedido_tienda_id ON vinculo_logistico(pedido_tienda_id);
CREATE INDEX IF NOT EXISTS idx_vinculo_logistico_reserva_viaje_id ON vinculo_logistico(reserva_viaje_id);

-- Constraints
ALTER TABLE pedidos_tienda 
ADD CONSTRAINT chk_estado_pedido_tienda 
CHECK (estado IN ('carrito', 'pagado', 'despachado', 'entregado', 'cancelado'));

ALTER TABLE pedidos_tienda 
ADD CONSTRAINT chk_tipo_entrega_tienda 
CHECK (tipo_entrega IN ('domicilio', 'retiro_tienda'));

ALTER TABLE reservas_viajes 
ADD CONSTRAINT chk_estado_reserva_viaje 
CHECK (estado IN ('reservado', 'confirmado', 'pagado', 'realizado', 'cancelado', 'liquidado'));

ALTER TABLE vinculo_logistico 
ADD CONSTRAINT chk_tipo_vinculo 
CHECK (tipo_vinculo IN ('combinado', 'separado'));

-- Función para validar dirección solo con campos de texto
CREATE OR REPLACE FUNCTION validar_direccion_texto(p_direccion JSONB)
RETURNS TABLE (
    valida BOOLEAN,
    mensaje TEXT,
    direccion_corregida JSONB
) AS $$
DECLARE
    calle TEXT;
    numero TEXT;
    codigo_postal TEXT;
    localidad TEXT;
    provincia TEXT;
    direccion_completa TEXT;
BEGIN
    -- Extraer campos de texto
    calle := COALESCE(p_direccion->>'calle', '');
    numero := COALESCE(p_direccion->>'numero', '');
    codigo_postal := COALESCE(p_direccion->>'codigo_postal', '');
    localidad := COALESCE(p_direccion->>'localidad', '');
    provincia := COALESCE(p_direccion->>'provincia', '');
    
    -- Validar campos obligatorios
    IF calle = '' OR localidad = '' OR codigo_postal = '' THEN
        RETURN QUERY SELECT FALSE, 
            'La calle, localidad y código postal son obligatorios', 
            p_direccion;
        RETURN;
    END IF;
    
    -- Validar que no haya coordenadas (bloquear mapa)
    IF p_direccion ? 'latitud' OR p_direccion ? 'longitud' OR p_direccion ? 'coordenadas' THEN
        RETURN QUERY SELECT FALSE, 
            'No se permiten coordenadas de mapa. Use campos de texto para la dirección.', 
            jsonb_build_object(
                'calle', calle,
                'numero', numero,
                'codigo_postal', codigo_postal,
                'localidad', localidad,
                'provincia', provincia
            );
        RETURN;
    END IF;
    
    -- Validar formato de código postal argentino
    IF codigo_postal !~ '^\d{4}$' AND codigo_postal !~ '^[A-Z]\d{4}[A-Z]{3}$' THEN
        RETURN QUERY SELECT FALSE, 
            'El código postal debe tener 4 dígitos (ej: 1000) o formato CPO (ej: C1000AAA)', 
            p_direccion;
        RETURN;
    END IF;
    
    -- Validar que no sea un punto de embarque
    direccion_completa := lower(calle || ' ' || numero || ' ' || localidad);
    IF direccion_completa ~* '(?i)puerto|muelle|embarcadero|terminal|aeropuerto|estación' THEN
        RETURN QUERY SELECT FALSE, 
            'Los productos se envían únicamente a domicilios particulares o comerciales urbanos. No se realizan entregas en puntos de embarque.', 
            p_direccion;
        RETURN;
    END IF;
    
    -- Dirección válida
    RETURN QUERY SELECT TRUE, 'Dirección válida', 
        jsonb_build_object(
            'calle', calle,
            'numero', numero,
            'codigo_postal', codigo_postal,
            'localidad', localidad,
            'provincia', provincia,
            'direccion_completa', trim(calle || ' ' || numero || ', ' || localidad || ', ' || provincia)
        );
END;
$$ LANGUAGE plpgsql;

-- Función para crear pedido_tienda
CREATE OR REPLACE FUNCTION crear_pedido_tienda(
    p_pescador_id UUID,
    p_productos JSONB,
    p_direccion JSONB,
    p_tipo_entrega VARCHAR DEFAULT 'domicilio',
    p_disclaimer_aceptado BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    pedido_tienda_id UUID
) AS $$
DECLARE
    validacion_direccion RECORD;
    nuevo_pedido_id UUID;
    subtotal_calculado DECIMAL := 0.0;
BEGIN
    -- Validar dirección
    SELECT * INTO validacion_direccion
    FROM validar_direccion_texto(p_direccion);
    
    IF validacion_direccion.valida = FALSE THEN
        RETURN QUERY SELECT FALSE, validacion_direccion.mensaje, NULL::UUID;
        RETURN;
    END IF;
    
    -- Calcular subtotal
    SELECT COALESCE(SUM((elem->>'precio')::DECIMAL * (elem->>'cantidad')::INTEGER), 0.0)
    INTO subtotal_calculado
    FROM jsonb_array_elements(p_productos) elem;
    
    -- Crear pedido_tienda
    INSERT INTO pedidos_tienda (
        pescador_id, productos, direccion_entrega, tipo_entrega,
        subtotal, total, disclaimer_aceptado, creado_at
    ) VALUES (
        p_pescador_id, p_productos, validacion_direccion.direccion_corregida, p_tipo_entrega,
        subtotal_calculado, subtotal_calculado, p_disclaimer_aceptado, NOW()
    )
    RETURNING id INTO nuevo_pedido_id;
    
    RETURN QUERY SELECT TRUE, 'Pedido de tienda creado exitosamente', nuevo_pedido_id;
END;
$$ LANGUAGE plpgsql;

-- Función para crear reserva_viaje
CREATE OR REPLACE FUNCTION crear_reserva_viaje(
    p_pescador_id UUID,
    p_cotizacion_id UUID,
    p_datos_pasajeros JSONB,
    p_productos_tienda JSONB DEFAULT '[]'::JSONB
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    reserva_viaje_id UUID
) AS $$
DECLARE
    cotizacion_actual RECORD;
    nueva_reserva_id UUID;
    total_bultos INTEGER := 0;
BEGIN
    -- Obtener datos de cotización
    SELECT * INTO cotizacion_actual
    FROM cotizaciones
    WHERE id = p_cotizacion_id;
    
    IF cotizacion_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Cotización no encontrada', NULL::UUID;
        RETURN;
    END IF;
    
    -- Calcular bultos
    total_bultos := (jsonb_array_length(p_productos_tienda) + 1) / 2;
    
    -- Crear reserva_viaje
    INSERT INTO reservas_viajes (
        pescador_id, cotizacion_id, capitan_id, estado,
        monto_cotizacion, datos_pasajeros, productos_tienda,
        total_bultos, creado_at
    ) VALUES (
        p_pescador_id, p_cotizacion_id, cotizacion_actual.capitan_id, 'reservado',
        cotizacion_actual.presupuesto_base, p_datos_pasajeros, p_productos_tienda,
        total_bultos, NOW()
    )
    RETURNING id INTO nueva_reserva_id;
    
    RETURN QUERY SELECT TRUE, 'Reserva de viaje creada exitosamente', nueva_reserva_id;
END;
$$ LANGUAGE plpgsql;

-- Función para vincular pedido_tienda con reserva_viaje
CREATE OR REPLACE FUNCTION vincular_pedido_reserva(
    p_pedido_tienda_id UUID,
    p_reserva_viaje_id UUID,
    p_pescador_id UUID,
    p_tipo_vinculo VARCHAR DEFAULT 'combinado'
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    vinculo_id UUID
) AS $$
DECLARE
    nuevo_vinculo_id UUID;
BEGIN
    -- Crear vínculo
    INSERT INTO vinculo_logistico (
        pedido_tienda_id, reserva_viaje_id, pescador_id, tipo_vinculo, creado_at
    ) VALUES (
        p_pedido_tienda_id, p_reserva_viaje_id, p_pescador_id, p_tipo_vinculo, NOW()
    )
    RETURNING id INTO nuevo_vinculo_id;
    
    RETURN QUERY SELECT TRUE, 'Vínculo creado exitosamente', nuevo_vinculo_id;
END;
$$ LANGUAGE plpgsql;

-- Función para cargar tracking y enviar correo automático
CREATE OR REPLACE FUNCTION cargar_tracking_y_notificar(
    p_pedido_tienda_id UUID,
    p_tracking_codigo VARCHAR,
    p_admin_id UUID
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    tracking_url TEXT,
    correo_enviado BOOLEAN
) AS $$
DECLARE
    pedido_actual RECORD;
    pescador_datos RECORD;
    tracking_url_generada TEXT;
    correo_enviado_result BOOLEAN := FALSE;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos_tienda
    WHERE id = p_pedido_tienda_id;
    
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado', NULL, FALSE;
        RETURN;
    END IF;
    
    -- Generar URL de tracking
    tracking_url_generada := 'https://www.correoargentino.com.ar/formularios/consulta-envio?codigo=' || p_tracking_codigo;
    
    -- Actualizar pedido con tracking
    UPDATE pedidos_tienda
    SET 
        tracking_codigo = p_tracking_codigo,
        tracking_url = tracking_url_generada,
        tracking_cargado_at = NOW(),
        tracking_cargado_por = p_admin_id,
        estado = 'despachado',
        despachado = TRUE,
        despachado_at = NOW(),
        despachado_por = p_admin_id,
        actualizado_at = NOW()
    WHERE id = p_pedido_tienda_id;
    
    -- Obtener datos del pescador para enviar correo
    SELECT * INTO pescador_datos
    FROM profiles
    WHERE user_id = pedido_actual.pescador_id;
    
    -- Enviar notificación (aquí se integraría con servicio de correo)
    -- Por ahora, creamos una notificación interna
    INSERT INTO notificaciones_usuarios (
        user_id, tipo, titulo, mensaje, datos_adicionales, leida, created_at
    ) VALUES (
        pedido_actual.pescador_id,
        'tracking_disponible',
        '📦 Código de Tracking Disponible',
        'Tu pedido ha sido despachado. Código: ' || p_tracking_codigo,
        jsonb_build_object(
            'pedido_tienda_id', p_pedido_tienda_id,
            'tracking_codigo', p_tracking_codigo,
            'tracking_url', tracking_url_generada,
            'direccion_entrega', pedido_actual.direccion_entrega,
            'accion_requerida', 'seguir_envio'
        ),
        FALSE, NOW()
    );
    
    -- Marcar como correo enviado (simulado)
    correo_enviado_result := TRUE;
    
    RETURN QUERY SELECT TRUE, 'Tracking cargado y notificación enviada', 
        tracking_url_generada, correo_enviado_result;
END;
$$ LANGUAGE plpgsql;

-- Vista para gestión logística del administrador
CREATE OR REPLACE VIEW vw_gestion_logistica_admin AS
SELECT 
    pt.id as pedido_tienda_id,
    pt.estado as estado_pedido,
    pt.total as total_pedido,
    pt.tracking_codigo,
    pt.tracking_url,
    pt.despachado as pedido_despachado,
    pt.entregado as pedido_entregado,
    rv.id as reserva_viaje_id,
    rv.estado as estado_reserva,
    rv.monto_total as monto_reserva,
    rv.realizado as viaje_realizado,
    rv.liquidado as viaje_liquidado,
    p.nombre as pescador_nombre,
    p.email as pescador_email,
    vl.tipo_vinculo,
    CASE 
        WHEN pt.despachado = TRUE AND rv.realizado = TRUE THEN '✅ Completo'
        WHEN pt.despachado = TRUE THEN '📦 Pedido Despachado'
        WHEN rv.realizado = TRUE THEN '🚢 Viaje Realizado'
        ELSE '⏳ Pendiente'
    END as estado_general,
    CASE 
        WHEN pt.despachado = TRUE AND rv.realizado = TRUE THEN '#10B981'
        WHEN pt.despachado = TRUE THEN '#3B82F6'
        WHEN rv.realizado = TRUE THEN '#F59E0B'
        ELSE '#6B7280'
    END as color_general
FROM pedidos_tienda pt
LEFT JOIN vinculo_logistico vl ON pt.id = vl.pedido_tienda_id
LEFT JOIN reservas_viajes rv ON vl.reserva_viaje_id = rv.id
LEFT JOIN profiles p ON pt.pescador_id = p.user_id
ORDER BY pt.creado_at DESC;

-- Vista para seguimiento del pescador
CREATE OR REPLACE VIEW vw_seguimiento_pescador AS
SELECT 
    pt.id,
    pt.estado,
    pt.total,
    pt.tracking_codigo,
    pt.tracking_url,
    pt.direccion_entrega,
    pt.tipo_entrega,
    pt.despachado,
    pt.despachado_at,
    pt.entregado,
    pt.entregado_at,
    CASE 
        WHEN pt.estado = 'entregado' THEN '✅ Entregado'
        WHEN pt.estado = 'despachado' THEN '📦 Despachado'
        WHEN pt.estado = 'pagado' THEN '💳 Pagado'
        WHEN pt.estado = 'carrito' THEN '🛒 Carrito'
        ELSE '❓ Desconocido'
    END as estado_formateado,
    CASE 
        WHEN pt.estado = 'entregado' THEN '#10B981'
        WHEN pt.estado = 'despachado' THEN '#3B82F6'
        WHEN pt.estado = 'pagado' THEN '#F59E0B'
        WHEN pt.estado = 'carrito' THEN '#6B7280'
        ELSE '#EF4444'
    END as color_estado,
    vl.reserva_viaje_id,
    rv.estado as estado_reserva,
    rv.realizado as viaje_realizado
FROM pedidos_tienda pt
LEFT JOIN vinculo_logistico vl ON pt.id = vl.pedido_tienda_id
LEFT JOIN reservas_viajes rv ON vl.reserva_viaje_id = rv.id
WHERE pt.pescador_id = auth.uid()
ORDER BY pt.creado_at DESC;

-- Función para obtener gestión logística del administrador
CREATE OR REPLACE FUNCTION get_gestion_logistica_admin()
RETURNS TABLE (
    pedido_tienda_id UUID,
    estado_pedido VARCHAR,
    total_pedido DECIMAL,
    tracking_codigo VARCHAR,
    tracking_url TEXT,
    pedido_despachado BOOLEAN,
    pedido_entregado BOOLEAN,
    reserva_viaje_id UUID,
    estado_reserva VARCHAR,
    monto_reserva DECIMAL,
    viaje_realizado BOOLEAN,
    viaje_liquidado BOOLEAN,
    pescador_nombre TEXT,
    pescador_email TEXT,
    tipo_vinculo VARCHAR,
    estado_general TEXT,
    color_general TEXT
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM vw_gestion_logistica_admin;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener seguimiento del pescador
CREATE OR REPLACE FUNCTION get_seguimiento_pescador()
RETURNS TABLE (
    id UUID,
    estado VARCHAR,
    total DECIMAL,
    tracking_codigo VARCHAR,
    tracking_url TEXT,
    direccion_entrega JSONB,
    tipo_entrega VARCHAR,
    despachado BOOLEAN,
    despachado_at TIMESTAMP WITH TIME ZONE,
    entregado BOOLEAN,
    entregado_at TIMESTAMP WITH TIME ZONE,
    estado_formateado TEXT,
    color_estado TEXT,
    reserva_viaje_id UUID,
    estado_reserva VARCHAR,
    viaje_realizado BOOLEAN
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM vw_seguimiento_pescador;
END;
$$ LANGUAGE plpgsql;

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

CREATE POLICY "Usuarios pueden crear pedidos_tienda"
ON pedidos_tienda FOR INSERT
WITH CHECK (pescador_id = auth.uid());

CREATE POLICY "Usuarios pueden crear reservas_viajes"
ON reservas_viajes FOR INSERT
WITH CHECK (pescador_id = auth.uid());

CREATE POLICY "Admin puede actualizar tracking"
ON pedidos_tienda FOR UPDATE
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
))
AND (tracking_codigo IS NOT NULL OR despachado IS NOT NULL);

-- Crear datos de ejemplo
INSERT INTO avisos_legales (tipo_aviso, titulo, contenido, obligatorio) VALUES 
(
    'domicilio_urbano',
    'Restricción de Entrega en Domicilio',
    'Acepto que la entrega de productos es exclusiva en domicilios urbanos y los tiempos son responsabilidad del correo.',
    TRUE
),
(
    'coordenadas_bloqueadas',
    'Prohibición de Coordenadas',
    'No se permiten coordenadas de mapa para envíos. Use campos de texto para especificar la dirección.',
    TRUE
)
ON CONFLICT DO NOTHING;
