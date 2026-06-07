-- Asegurar que la tabla pedidos tenga todos los campos necesarios para el PescadorDashboard
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS localidad_partida VARCHAR(100),
ADD COLUMN IF NOT EXISTS provincia_partida VARCHAR(100),
ADD COLUMN IF NOT EXISTS localidad_destino VARCHAR(100),
ADD COLUMN IF NOT EXISTS provincia_destino VARCHAR(100),
ADD COLUMN IF NOT EXISTS lugar_encuentro VARCHAR(200),
ADD COLUMN IF NOT EXISTS fecha_ida TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS fecha_vuelta TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS hora_encuentro TIME,
ADD COLUMN IF NOT EXISTS cantidad_personas INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS distancia_km DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS distancia_millas DECIMAL(10,2),
ADD COLUMN IF NOT EXISTS coordenadas_partida JSONB,
ADD COLUMN IF NOT EXISTS coordenadas_destino JSONB,
ADD COLUMN IF NOT EXISTS estado_cotizacion VARCHAR(20) DEFAULT 'solicitada',
ADD COLUMN IF NOT EXISTS presupuesto_aceptado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS presupuesto_aceptado_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS productos_adicionales JSONB DEFAULT '[]'::JSONB,
ADD COLUMN IF NOT EXISTS logistica_retiro_lancha BOOLEAN DEFAULT FALSE;

-- Agregar constraint para estado_cotizacion
ALTER TABLE pedidos 
ADD CONSTRAINT chk_estado_cotizacion 
CHECK (estado_cotizacion IN ('solicitada', 'presupuestada', 'aceptada', 'pagada', 'cancelada'));

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_pedidos_estado_cotizacion ON pedidos(estado_cotizacion);
CREATE INDEX IF NOT EXISTS idx_pedidos_pescador_id ON pedidos(pescador_id);
CREATE INDEX IF NOT EXISTS idx_pedidos_fecha_ida ON pedidos(fecha_ida);
CREATE INDEX IF NOT EXISTS idx_pedidos_cantidad_personas ON pedidos(cantidad_personas);
CREATE INDEX IF NOT EXISTS idx_pedidos_presupuesto_aceptado ON pedidos(presupuesto_aceptado);

-- Función para calcular distancia entre dos puntos (Haversine)
CREATE OR REPLACE FUNCTION calcular_distancia_km(
    p_lat1 DECIMAL, p_lon1 DECIMAL, 
    p_lat2 DECIMAL, p_lon2 DECIMAL
)
RETURNS DECIMAL AS $$
DECLARE
    lat1_rad DECIMAL;
    lat2_rad DECIMAL;
    delta_lat DECIMAL;
    delta_lon DECIMAL;
    a DECIMAL;
    c DECIMAL;
    radio_km DECIMAL := 6371; -- Radio de la Tierra en km
BEGIN
    -- Convertir a radianes
    lat1_rad := RADIANS(p_lat1);
    lat2_rad := RADIANS(p_lat2);
    delta_lat := RADIANS(p_lat2 - p_lat1);
    delta_lon := RADIANS(p_lon2 - p_lon1);
    
    -- Fórmula de Haversine
    a := SIN(delta_lat/2)^2 + COS(lat1_rad) * COS(lat2_rad) * SIN(delta_lon/2)^2;
    c := 2 * ATAN2(SQRT(a), SQRT(1-a));
    
    RETURN radio_km * c;
END;
$$ LANGUAGE plpgsql;

-- Función para crear cotización con datos técnicos completos
CREATE OR REPLACE FUNCTION crear_cotizacion_tecnica(
    p_pescador_id UUID,
    p_descripcion TEXT,
    p_coordenadas_partida JSONB,
    p_coordenadas_destino JSONB,
    p_localidad_partida VARCHAR(100),
    p_provincia_partida VARCHAR(100),
    p_localidad_destino VARCHAR(100),
    p_provincia_destino VARCHAR(100),
    p_lugar_encuentro VARCHAR(200),
    p_fecha_ida TIMESTAMP WITH TIME ZONE,
    p_fecha_vuelta TIMESTAMP WITH TIME ZONE,
    p_hora_encuentro TIME,
    p_cantidad_personas INTEGER DEFAULT 1
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    cotizacion_id UUID,
    pedido_id UUID
) AS $$
DECLARE
    nueva_cotizacion_id UUID;
    nuevo_pedido_id UUID;
    lat_partida DECIMAL;
    lon_partida DECIMAL;
    lat_destino DECIMAL;
    lon_destino DECIMAL;
    distancia_km_calculada DECIMAL;
    distancia_millas_calculada DECIMAL;
BEGIN
    -- Extraer coordenadas
    lat_partida := (p_coordenadas_partida->>'lat')::DECIMAL;
    lon_partida := (p_coordenadas_partida->>'lon')::DECIMAL;
    lat_destino := (p_coordenadas_destino->>'lat')::DECIMAL;
    lon_destino := (p_coordenadas_destino->>'lon')::DECIMAL;
    
    -- Calcular distancias
    distancia_km_calculada := calcular_distancia_km(lat_partida, lon_partida, lat_destino, lon_destino);
    distancia_millas_calculada := distancia_km_calculada * 0.621371; -- Conversión a millas
    
    -- Crear cotización
    INSERT INTO cotizaciones (
        pescador_id, descripcion, punto_partida, punto_destino, 
        distancia_km, distancia_millas, duracion_estimada_minutos, estado, created_at
    ) VALUES (
        p_pescador_id, p_descripcion, p_coordenadas_partida, p_coordenadas_destino,
        distancia_km_calculada, distancia_millas_calculada,
        -- Estimar duración: 1 hora por cada 50 km + 30 minutos base
        (distancia_km_calculada / 50 * 60 + 30)::INTEGER,
        'solicitada', NOW()
    )
    RETURNING id INTO nueva_cotizacion_id;
    
    -- Crear pedido con datos técnicos
    INSERT INTO pedidos (
        cotizacion_id, pescador_id, descripcion, localidad_partida, provincia_partida,
        localidad_destino, provincia_destino, lugar_encuentro, fecha_ida, fecha_vuelta,
        hora_encuentro, cantidad_personas, distancia_km, distancia_millas,
        coordenadas_partida, coordenadas_destino, estado_cotizacion,
        fecha_regreso, estado, created_at
    ) VALUES (
        nueva_cotizacion_id, p_pescador_id, p_descripcion,
        p_localidad_partida, p_provincia_partida, p_localidad_destino, p_provincia_destino,
        p_lugar_encuentro, p_fecha_ida, p_fecha_vuelta, p_hora_encuentro, p_cantidad_personas,
        distancia_km_calculada, distancia_millas_calculada, p_coordenadas_partida, p_coordenadas_destino,
        'solicitada', p_fecha_vuelta, 'pendiente', NOW()
    )
    RETURNING id INTO nuevo_pedido_id;
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo, descripcion, user_id, cotizacion_id, pedido_id, datos_adicionales, created_at
    ) VALUES (
        'cotizacion_tecnica_creada',
        'Pescador creó cotización con datos técnicos',
        p_pescador_id, nueva_cotizacion_id, nuevo_pedido_id,
        jsonb_build_object(
            'distancia_km', distancia_km_calculada,
            'cantidad_personas', p_cantidad_personas,
            'fecha_ida', p_fecha_ida,
            'lugar_encuentro', p_lugar_encuentro
        ),
        NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Cotización técnica creada exitosamente', nueva_cotizacion_id, nuevo_pedido_id;
END;
$$ LANGUAGE plpgsql;

-- Función para aceptar presupuesto y crear pedido
CREATE OR REPLACE FUNCTION aceptar_presupuesto_y_crear_pedido(
    p_cotizacion_id UUID,
    p_pescador_id UUID,
    p_capitan_id UUID,
    p_productos_adicionales JSONB DEFAULT '[]'::JSONB,
    p_logistica_retiro_lancha BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    pedido_id UUID,
    monto_total DECIMAL
) AS $$
DECLARE
    cotizacion_actual RECORD;
    pedido_existente RECORD;
    monto_productos DECIMAL := 0;
    monto_final DECIMAL;
BEGIN
    -- Obtener datos de la cotización
    SELECT * INTO cotizacion_actual
    FROM cotizaciones
    WHERE id = p_cotizacion_id AND pescador_id = p_pescador_id;
    
    -- Validar cotización
    IF cotizacion_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Cotización no encontrada', NULL, 0;
        RETURN;
    END IF;
    
    -- Verificar si ya existe un pedido
    SELECT * INTO pedido_existente
    FROM pedidos
    WHERE cotizacion_id = p_cotizacion_id;
    
    IF pedido_existente IS NOT NULL THEN
        RETURN QUERY SELECT FALSE, 'Ya existe un pedido para esta cotización', pedido_existente.id, pedido_existente.total;
        RETURN;
    END IF;
    
    -- Calcular monto de productos adicionales
    IF p_productos_adicionales IS NOT NULL AND jsonb_array_length(p_productos_adicionales) > 0 THEN
        SELECT COALESCE(SUM(precio * cantidad), 0)
        INTO monto_productos
        FROM jsonb_to_recordset(p_productos_adicionales) 
        AS productos(producto_id UUID, nombre TEXT, precio DECIMAL, cantidad INTEGER);
    END IF;
    
    -- Calcular monto final
    monto_final := cotizacion_actual.presupuesto_base + monto_productos;
    
    -- Actualizar cotización
    UPDATE cotizaciones
    SET 
        capitan_id = p_capitan_id,
        estado = 'aceptada',
        presupuesto_aceptado = TRUE,
        presupuesto_aceptado_at = NOW()
    WHERE id = p_cotizacion_id;
    
    -- Actualizar pedido existente o crear nuevo
    IF pedido_existente IS NOT NULL THEN
        UPDATE pedidos
        SET 
            capitan_id = p_capitan_id,
            estado_cotizacion = 'aceptada',
            presupuesto_aceptado = TRUE,
            presupuesto_aceptado_at = NOW(),
            productos_adicionales = p_productos_adicionales,
            logistica_retiro_lancha = p_logistica_retiro_lancha,
            total = monto_final,
            updated_at = NOW()
        WHERE id = pedido_existente.id;
        
        RETURN QUERY SELECT TRUE, 'Presupuesto aceptado y pedido actualizado', pedido_existente.id, monto_final;
    ELSE
        -- Crear nuevo pedido
        INSERT INTO pedidos (
            cotizacion_id, pescador_id, capitan_id, descripcion,
            localidad_partida, provincia_partida, localidad_destino, provincia_destino,
            lugar_encuentro, fecha_ida, fecha_vuelta, hora_encuentro, cantidad_personas,
            distancia_km, distancia_millas, coordenadas_partida, coordenadas_destino,
            estado_cotizacion, presupuesto_aceptado, presupuesto_aceptado_at,
            productos_adicionales, logistica_retiro_lancha, total,
            fecha_regreso, estado, created_at
        ) VALUES (
            p_cotizacion_id, p_pescador_id, p_capitan_id, cotizacion_actual.descripcion,
            cotizacion_actual.localidad_partida, cotizacion_actual.provincia_partida,
            cotizacion_actual.localidad_destino, cotizacion_actual.provincia_destino,
            cotizacion_actual.lugar_encuentro, cotizacion_actual.fecha_ida, cotizacion_actual.fecha_vuelta,
            cotizacion_actual.hora_encuentro, cotizacion_actual.cantidad_personas,
            cotizacion_actual.distancia_km, cotizacion_actual.distancia_millas,
            cotizacion_actual.punto_partida, cotizacion_actual.punto_destino,
            'aceptada', TRUE, NOW(),
            p_productos_adicionales, p_logistica_retiro_lancha, monto_final,
            cotizacion_actual.fecha_vuelta, 'pendiente', NOW()
        )
        RETURNING id INTO pedido_existente;
        
        RETURN QUERY SELECT TRUE, 'Presupuesto aceptado y pedido creado', pedido_existente.id, monto_final;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Vista para cotizaciones del pescador con datos técnicos
CREATE OR REPLACE VIEW vw_cotizaciones_pescador_tecnica AS
SELECT 
    c.*,
    p.localidad_partida,
    p.provincia_partida,
    p.localidad_destino,
    p.provincia_destino,
    p.lugar_encuentro,
    p.fecha_ida,
    p.fecha_vuelta,
    p.hora_encuentro,
    p.cantidad_personas,
    p.estado_cotizacion,
    p.presupuesto_aceptado,
    p.presupuesto_aceptado_at,
    p.productos_adicionales,
    p.logistica_retiro_lancha,
    pr.nombre as capitan_nombre,
    pr.telefono_contacto as capitan_telefono,
    pr.foto_url as capitan_foto,
    CASE 
        WHEN c.estado = 'solicitada' THEN 'Solicitada'
        WHEN c.estado = 'presupuestada' THEN 'Presupuestada'
        WHEN c.estado = 'aceptada' THEN 'Aceptada'
        WHEN c.estado = 'pagada' THEN 'Pagada'
        WHEN c.estado = 'cancelada' THEN 'Cancelada'
        ELSE 'Desconocido'
    END as estado_formateado,
    CASE 
        WHEN c.estado = 'solicitada' THEN 'orange'
        WHEN c.estado = 'presupuestada' THEN 'blue'
        WHEN c.estado = 'aceptada' THEN 'green'
        WHEN c.estado = 'pagada' THEN 'green'
        WHEN c.estado = 'cancelada' THEN 'red'
        ELSE 'grey'
    END as estado_color
FROM cotizaciones c
LEFT JOIN pedidos p ON c.id = p.cotizacion_id
LEFT JOIN profiles pr ON c.capitan_id = pr.user_id
WHERE c.pescador_id IS NOT NULL
ORDER BY c.created_at DESC;

-- Función para obtener productos recomendados para venta cruzada
CREATE OR REPLACE FUNCTION get_productos_recomendados(
    p_cantidad_personas INTEGER,
    p_distancia_km DECIMAL,
    p_duracion_horas INTEGER
)
RETURNS TABLE (
    producto_id UUID,
    nombre VARCHAR,
    descripcion TEXT,
    precio DECIMAL,
    stock_actual INTEGER,
    categoria VARCHAR,
    recomendacion VARCHAR,
    cantidad_sugerida INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.id as producto_id,
        p.nombre,
        p.descripcion,
        p.precio,
        p.stock_actual,
        p.categoria,
        CASE 
            WHEN p.categoria = 'carnada' AND p_duracion_horas >= 4 THEN 'Recomendado para viaje largo'
            WHEN p.categoria = 'bebidas' AND p_cantidad_personas >= 3 THEN 'Ideal para grupo'
            WHEN p.categoria = 'equipos' AND p_distancia_km >= 20 THEN 'Recomendado para distancia larga'
            WHEN p.categoria = 'seguridad' THEN 'Siempre recomendado'
            ELSE 'Opcional'
        END as recomendacion,
        CASE 
            WHEN p.categoria = 'carnada' THEN GREATEST(1, p_cantidad_personas / 2)
            WHEN p.categoria = 'bebidas' THEN p_cantidad_personas
            WHEN p.categoria = 'equipos' THEN 1
            ELSE 1
        END as cantidad_sugerida
    FROM productos p
    WHERE p.activo = TRUE
    AND p.stock_actual > 0
    AND (
        -- Carnada para viajes largos
        (p.categoria = 'carnada' AND p_duracion_horas >= 2)
        OR
        -- Bebidas para grupos
        (p.categoria = 'bebidas' AND p_cantidad_personas >= 2)
        OR
        -- Equipos para distancias largas
        (p.categoria = 'equipos' AND p_distancia_km >= 10)
        OR
        -- Seguridad siempre
        (p.categoria = 'seguridad')
    )
    ORDER BY 
        CASE 
            WHEN p.categoria = 'seguridad' THEN 1
            WHEN p.categoria = 'carnada' THEN 2
            WHEN p.categoria = 'bebidas' THEN 3
            WHEN p.categoria = 'equipos' THEN 4
            ELSE 5
        END,
        p.precio DESC;
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar cotización con respuesta de capitán
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
    -- Actualizar cotización con respuesta del capitán
    UPDATE cotizaciones
    SET 
        capitan_id = p_capitan_id,
        presupuesto_base = p_presupuesto,
        estado = 'presupuestada',
        observaciones = p_observaciones,
        presupuesto_at = NOW(),
        updated_at = NOW()
    WHERE id = p_cotizacion_id
    AND estado = 'solicitada';
    
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
        FALSE,
        NOW()
    );
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo, descripcion, user_id, cotizacion_id, datos_adicionales, created_at
    ) VALUES (
        'cotizacion_presupuestada',
        'Capitán envió presupuesto',
        p_capitan_id, p_cotizacion_id,
        jsonb_build_object(
            'presupuesto', p_presupuesto,
            'observaciones', p_observaciones,
            'timestamp', NOW()
        ),
        NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Presupuesto enviado exitosamente', p_cotizacion_id;
END;
$$ LANGUAGE plpgsql;

-- Actualizar algunas cotizaciones de ejemplo con datos técnicos
UPDATE cotizaciones c
SET 
    localidad_partida = 'Mar del Plata',
    provincia_partida = 'Buenos Aires',
    localidad_destino = 'Isla Marta',
    provincia_destino = 'Buenos Aires',
    lugar_encuentro = 'Muelle municipal de Mar del Plata',
    fecha_ida = NOW() + INTERVAL '2 days',
    fecha_vuelta = NOW() + INTERVAL '4 days',
    hora_encuentro = '06:00:00',
    cantidad_personas = 3,
    estado_cotizacion = 'presupuestada'
WHERE estado = 'solicitada'
LIMIT 5;

-- Políticas de seguridad para el PescadorDashboard
CREATE POLICY "Pescadores pueden ver sus cotizaciones técnicas"
ON vw_cotizaciones_pescador_tecnica FOR SELECT
USING (auth.uid() = pescador_id);

CREATE POLICY "Pescadores pueden crear cotizaciones técnicas"
ON cotizaciones FOR INSERT
USING (auth.uid() = pescador_id);

CREATE POLICY "Pescadores pueden aceptar sus presupuestos"
ON cotizaciones FOR UPDATE
USING (auth.uid() = pescador_id AND estado = 'presupuestada');

-- Trigger para notificar cuando se actualice una cotización
CREATE OR REPLACE FUNCTION trigger_notificar_cotizacion_actualizada()
RETURNS TRIGGER AS $$
BEGIN
    -- Si el estado cambió a presupuestada, notificar al pescador
    IF OLD.estado != NEW.estado AND NEW.estado = 'presupuestada' THEN
        INSERT INTO notificaciones_usuarios (
            user_id, tipo, titulo, mensaje, datos_adicionales, leida, created_at
        ) VALUES (
            NEW.pescador_id,
            'cotizacion_actualizada',
            'Cotización Actualizada',
            'Tu cotización ha sido actualizada por un capitán.',
            jsonb_build_object(
                'cotizacion_id', NEW.id,
                'estado_nuevo', NEW.estado,
                'presupuesto', NEW.presupuesto_base
            ),
            FALSE,
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_notificar_cotizacion_actualizada
    AFTER UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION trigger_notificar_cotizacion_actualizada();
