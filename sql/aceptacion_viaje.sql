-- Sistema de Aceptación de Viaje y Carga de Datos

-- Actualizar tabla manifiesto_pasajeros con campos adicionales
ALTER TABLE manifiesto_pasajeros 
ADD COLUMN IF NOT EXISTS nombre_pasajero VARCHAR(100),
ADD COLUMN IF NOT EXISTS apellido_pasajero VARCHAR(100),
ADD COLUMN IF NOT EXISTS dni_pasajero VARCHAR(20),
ADD COLUMN IF NOT EXISTS foto_dni_url TEXT,
ADD COLUMN IF NOT EXISTS foto_dni_subida_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN IF NOT EXISTS datos_validados BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS id_viaje UUID REFERENCES cotizaciones(id) ON DELETE SET NULL,
ADD COLUMN IF NOT EXISTS productos_tienda JSONB DEFAULT '[]'::JSONB,
ADD COLUMN IF NOT EXISTS total_bultos INTEGER DEFAULT 0;

-- Actualizar tabla pedidos con campos para productos de tienda
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS productos_tienda JSONB DEFAULT '[]'::JSONB,
ADD COLUMN IF NOT EXISTS total_bultos INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS monto_carrito DECIMAL(10,2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS monto_total_viaje DECIMAL(10,2) DEFAULT 0.0,
ADD COLUMN IF NOT EXISTS contacto_habilitado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS contacto_habilitado_at TIMESTAMP WITH TIME ZONE;

-- Crear tabla de productos_viajes para tracking
CREATE TABLE IF NOT EXISTS productos_viajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    viaje_id UUID REFERENCES cotizaciones(id) ON DELETE CASCADE,
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE,
    producto_id UUID REFERENCES productos(id) ON DELETE SET NULL,
    nombre_producto VARCHAR(200) NOT NULL,
    cantidad INTEGER DEFAULT 1,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    categoria VARCHAR(50),
    entregado BOOLEAN DEFAULT FALSE,
    entregado_at TIMESTAMP WITH TIME ZONE,
    entregado_por UUID REFERENCES profiles(user_id),
    notas TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_manifiesto_pasajeros_id_viaje ON manifiesto_pasajeros(id_viaje);
CREATE INDEX IF NOT EXISTS idx_manifiesto_pasajeros_dni_pasajero ON manifiesto_pasajeros(dni_pasajero);
CREATE INDEX IF NOT EXISTS idx_manifiesto_pasajeros_datos_validados ON manifiesto_pasajeros(datos_validados);
CREATE INDEX IF NOT EXISTS idx_pedidos_contacto_habilitado ON pedidos(contacto_habilitado);
CREATE INDEX IF NOT EXISTS idx_productos_viajes_viaje_id ON productos_viajes(viaje_id);
CREATE INDEX IF NOT EXISTS idx_productos_viajes_entregado ON productos_viajes(entregado);

-- Función para calcular monto total del viaje
CREATE OR REPLACE FUNCTION calcular_monto_total_viaje(p_pedido_id UUID)
RETURNS TABLE (
    monto_cotizacion DECIMAL,
    monto_carrito DECIMAL,
    monto_total DECIMAL,
    total_bultos INTEGER,
    productos_count INTEGER
) AS $$
DECLARE
    pedido_actual RECORD;
    monto_cotizacion_calc DECIMAL := 0.0;
    monto_carrito_calc DECIMAL := 0.0;
    bultos_count INTEGER := 0;
    productos_count INTEGER := 0;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id;
    
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT 0.0, 0.0, 0.0, 0, 0;
        RETURN;
    END IF;
    
    -- Calcular monto de cotización
    SELECT COALESCE(presupuesto_base, 0.0) INTO monto_cotizacion_calc
    FROM cotizaciones
    WHERE id = pedido_actual.cotizacion_id;
    
    -- Calcular monto del carrito
    IF pedido_actual.productos_tienda IS NOT NULL THEN
        SELECT COALESCE(SUM((elem->>'precio')::DECIMAL * (elem->>'cantidad')::INTEGER), 0.0)
        INTO monto_carrito_calc
        FROM jsonb_array_elements(pedido_actual.productos_tienda) elem;
        
        -- Contar productos y bultos
        productos_count := jsonb_array_length(pedido_actual.productos_tienda);
        
        -- Calcular bultos (1 bulto por cada 2 productos o 1 si es impar)
        bultos_count := (productos_count + 1) / 2;
    END IF;
    
    RETURN QUERY 
    SELECT monto_cotizacion_calc, monto_carrito_calc, 
           (monto_cotizacion_calc + monto_carrito_calc), bultos_count, productos_count;
END;
$$ LANGUAGE plpgsql;

-- Función para aceptar viaje y cargar datos
CREATE OR REPLACE FUNCTION aceptar_viaje_y_cargar_datos(
    p_pedido_id UUID,
    p_pescador_id UUID,
    p_lista_pasajeros JSONB,
    p_confirmar_pago BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    pedido_id UUID,
    viaje_id UUID,
    monto_total DECIMAL,
    total_bultos INTEGER,
    pasajeros_cargados INTEGER
) AS $$
DECLARE
    pedido_actual RECORD;
    viaje_actual RECORD;
    monto_calculado RECORD;
    pasajero_data JSONB;
    pasajeros_count INTEGER := 0;
    nuevo_manifiesto_id UUID;
    total_bultos INTEGER := 0;
BEGIN
    -- Obtener datos del pedido
    SELECT * INTO pedido_actual
    FROM pedidos
    WHERE id = p_pedido_id
    AND pescador_id = p_pescador_id;
    
    IF pedido_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pedido no encontrado o no pertenece al pescador', NULL, NULL, 0.0, 0, 0;
        RETURN;
    END IF;
    
    -- Obtener datos del viaje
    SELECT * INTO viaje_actual
    FROM cotizaciones
    WHERE id = pedido_actual.cotizacion_id;
    
    IF viaje_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Viaje no encontrado', NULL, NULL, 0.0, 0, 0;
        RETURN;
    END IF;
    
    -- Calcular monto total
    SELECT * INTO monto_calculado
    FROM calcular_monto_total_viaje(p_pedido_id);
    
    -- Actualizar pedido con montos calculados
    UPDATE pedidos
    SET 
        estado = CASE 
            WHEN p_confirmar_pago = TRUE THEN 'pagado'
            ELSE 'confirmado'
        END,
        monto_carrito = monto_calculado.monto_carrito,
        monto_total_viaje = monto_calculado.monto_total,
        total_bultos = monto_calculado.total_bultos,
        contacto_habilitado = TRUE,
        contacto_habilitado_at = NOW(),
        updated_at = NOW()
    WHERE id = p_pedido_id;
    
    -- Actualizar estado de cotización
    UPDATE cotizaciones
    SET 
        estado = CASE 
            WHEN p_confirmar_pago = TRUE THEN 'pagada'
            ELSE 'aceptada'
        END,
        updated_at = NOW()
    WHERE id = viaje_actual.id;
    
    -- Procesar lista de pasajeros
    IF p_lista_pasajeros IS NOT NULL THEN
        -- Eliminar manifiesto existente para este viaje
        DELETE FROM manifiesto_pasajeros
        WHERE id_viaje = viaje_actual.id;
        
        -- Crear registros de pasajeros
        FOR i IN 0..jsonb_array_length(p_lista_pasajeros) - 1 LOOP
            pasajero_data := p_lista_pasajeros -> i;
            
            INSERT INTO manifiesto_pasajeros (
                cotizacion_id, capitan_id, id_viaje,
                nombre_pasajero, apellido_pasajero, dni_pasajero,
                foto_dni_url, foto_dni_subida_at, datos_validados,
                fecha_salida, fecha_regreso, hora_encuentro, lugar_encuentro,
                productos_tienda, total_bultos, estado, created_at
            ) VALUES (
                viaje_actual.id, viaje_actual.capitan_id, viaje_actual.id,
                pasajero_data->>'nombre', pasajero_data->>'apellido', pasajero_data->>'dni',
                pasajero_data->>'foto_dni_url', NOW(), FALSE,
                pedido_actual.fecha_ida, pedido_actual.fecha_vuelta, 
                pedido_actual.hora_encuentro, pedido_actual.lugar_encuentro,
                pedido_actual.productos_tienda, monto_calculado.total_bultos,
                'preparado', NOW()
            )
            RETURNING id INTO nuevo_manifiesto_id;
            
            pasajeros_count := pasajeros_count + 1;
        END LOOP;
        
        -- Actualizar cantidad de pasajeros en el pedido
        UPDATE pedidos
        SET cantidad_personas = pasajeros_count
        WHERE id = p_pedido_id;
    END IF;
    
    -- Crear registros de productos del viaje
    IF pedido_actual.productos_tienda IS NOT NULL THEN
        -- Eliminar productos existentes para este viaje
        DELETE FROM productos_viajes
        WHERE viaje_id = viaje_actual.id;
        
        -- Insertar nuevos productos
        INSERT INTO productos_viajes (
            viaje_id, pedido_id, producto_id, nombre_producto, cantidad, 
            precio_unitario, subtotal, categoria, created_at
        )
        SELECT 
            viaje_actual.id, p_pedido_id, 
            elem->>'producto_id',
            elem->>'nombre',
            (elem->>'cantidad')::INTEGER,
            (elem->>'precio')::DECIMAL,
            ((elem->>'precio')::DECIMAL * (elem->>'cantidad')::INTEGER),
            elem->>'categoria',
            NOW()
        FROM jsonb_array_elements(pedido_actual.productos_tienda) elem;
    END IF;
    
    -- Enviar notificación al capitán
    INSERT INTO notificaciones_usuarios (
        user_id, tipo, titulo, mensaje, datos_adicionales, leida, created_at
    ) VALUES (
        viaje_actual.capitan_id,
        'viaje_confirmado',
        '🎉 ¡Viaje Confirmado!',
        '¡Viaje confirmado! Tenés ' || monto_calculado.total_bultos::TEXT || ' bultos de la tienda para entregar en el muelle.',
        jsonb_build_object(
            'viaje_id', viaje_actual.id,
            'pedido_id', p_pedido_id,
            'total_bultos', monto_calculado.total_bultos,
            'monto_total', monto_calculado.monto_total,
            'pasajeros', pasajeros_count,
            'accion_requerida', 'preparar_entrega'
        ),
        FALSE, NOW()
    );
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo, descripcion, user_id, cotizacion_id, pedido_id, datos_adicionales, created_at
    ) VALUES (
        'viaje_aceptado',
        'Pescador aceptó viaje y cargó datos',
        p_pescador_id, viaje_actual.id, p_pedido_id,
        jsonb_build_object(
            'monto_total', monto_calculado.monto_total,
            'total_bultos', monto_calculado.total_bultos,
            'pasajeros_cargados', pasajeros_count,
            'pago_confirmado', p_confirmar_pago,
            'timestamp', NOW()
        ),
        NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Viaje aceptado y datos cargados exitosamente', 
           p_pedido_id, viaje_actual.id, monto_calculado.monto_total, 
           monto_calculado.total_bultos, pasajeros_count;
END;
$$ LANGUAGE plpgsql;

-- Función para subir foto de DNI
CREATE OR REPLACE FUNCTION subir_foto_dni_pasajero(
    p_manifiesto_id UUID,
    p_foto_dni_url TEXT,
    p_validado BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    manifiesto_id UUID
) AS $$
BEGIN
    UPDATE manifiesto_pasajeros
    SET 
        foto_dni_url = p_foto_dni_url,
        foto_dni_subida_at = NOW(),
        datos_validados = p_validado,
        updated_at = NOW()
    WHERE id = p_manifiesto_id;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT FALSE, 'Manifiesto no encontrado', NULL::UUID;
        RETURN;
    END IF;
    
    RETURN QUERY SELECT TRUE, 'Foto de DNI subida exitosamente', p_manifiesto_id;
END;
$$ LANGUAGE plpgsql;

-- Función para validar datos de pasajero
CREATE OR REPLACE FUNCTION validar_datos_pasajero(p_manifiesto_id UUID)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    datos_completos BOOLEAN
) AS $$
DECLARE
    pasajero_actual RECORD;
BEGIN
    SELECT * INTO pasajero_actual
    FROM manifiesto_pasajeros
    WHERE id = p_manifiesto_id;
    
    IF pasajero_actual IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Pasajero no encontrado', FALSE;
        RETURN;
    END IF;
    
    -- Verificar que todos los datos estén completos
    IF pasajero_actual.nombre_pasajero IS NOT NULL 
       AND pasajero_actual.apellido_pasajero IS NOT NULL
       AND pasajero_actual.dni_pasajero IS NOT NULL
       AND pasajero_actual.foto_dni_url IS NOT NULL THEN
        
        UPDATE manifiesto_pasajeros
        SET datos_validados = TRUE, updated_at = NOW()
        WHERE id = p_manifiesto_id;
        
        RETURN QUERY SELECT TRUE, 'Datos validados exitosamente', TRUE;
    ELSE
        RETURN QUERY SELECT FALSE, 'Faltan datos por completar', FALSE;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Vista para manifiesto completo
CREATE OR REPLACE VIEW vw_manifiesto_completo AS
SELECT 
    mp.*,
    c.descripcion as viaje_descripcion,
    c.fecha_ida,
    c.fecha_vuelta,
    c.hora_encuentro,
    c.lugar_encuentro,
    p.nombre as capitan_nombre,
    p.telefono_contacto as capitan_telefono,
    p.foto_url as capitan_foto,
    ped.estado as estado_pedido,
    ped.contacto_habilitado,
    ped.monto_total_viaje,
    ped.total_bultos,
    CASE 
        WHEN mp.datos_validados = TRUE THEN '✅ Completos'
        WHEN mp.foto_dni_url IS NOT NULL THEN '📷 Foto subida'
        WHEN mp.dni_pasajero IS NOT NULL THEN '📄 DNI cargado'
        ELSE '❌ Incompletos'
    END as estado_datos,
    CASE 
        WHEN mp.datos_validados = TRUE THEN '#10B981'
        WHEN mp.foto_dni_url IS NOT NULL THEN '#F59E0B'
        WHEN mp.dni_pasajero IS NOT NULL THEN '#6366F1'
        ELSE '#EF4444'
    END as color_estado
FROM manifiesto_pasajeros mp
JOIN cotizaciones c ON mp.id_viaje = c.id
LEFT JOIN profiles p ON c.capitan_id = p.user_id
LEFT JOIN pedidos ped ON c.id = ped.cotizacion_id
WHERE mp.id_viaje IS NOT NULL
ORDER BY mp.created_at ASC;

-- Función para obtener manifiesto de un viaje
CREATE OR REPLACE FUNCTION get_manifiesto_viaje(p_viaje_id UUID)
RETURNS TABLE (
    id UUID,
    nombre_pasajero TEXT,
    apellido_pasajero TEXT,
    dni_pasajero TEXT,
    foto_dni_url TEXT,
    foto_dni_subida_at TIMESTAMP WITH TIME ZONE,
    datos_validados BOOLEAN,
    estado_datos TEXT,
    color_estado TEXT,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        mp.id,
        mp.nombre_pasajero,
        mp.apellido_pasajero,
        mp.dni_pasajero,
        mp.foto_dni_url,
        mp.foto_dni_subida_at,
        mp.datos_validados,
        CASE 
            WHEN mp.datos_validados = TRUE THEN '✅ Completos'
            WHEN mp.foto_dni_url IS NOT NULL THEN '📷 Foto subida'
            WHEN mp.dni_pasajero IS NOT NULL THEN '📄 DNI cargado'
            ELSE '❌ Incompletos'
        END as estado_datos,
        CASE 
            WHEN mp.datos_validados = TRUE THEN '#10B981'
            WHEN mp.foto_dni_url IS NOT NULL THEN '#F59E0B'
            WHEN mp.dni_pasajero IS NOT NULL THEN '#6366F1'
            ELSE '#EF4444'
        END as color_estado,
        mp.created_at
    FROM vw_manifiesto_completo mp
    WHERE mp.id_viaje = p_viaje_id
    ORDER BY mp.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener productos de un viaje
CREATE OR REPLACE FUNCTION get_productos_viaje(p_viaje_id UUID)
RETURNS TABLE (
    id UUID,
    nombre_producto TEXT,
    cantidad INTEGER,
    precio_unitario DECIMAL,
    subtotal DECIMAL,
    categoria TEXT,
    entregado BOOLEAN,
    entregado_at TIMESTAMP WITH TIME ZONE,
    notas TEXT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        pv.id,
        pv.nombre_producto,
        pv.cantidad,
        pv.precio_unitario,
        pv.subtotal,
        pv.categoria,
        pv.entregado,
        pv.entregado_at,
        pv.notas
    FROM productos_viajes pv
    WHERE pv.viaje_id = p_viaje_id
    ORDER BY pv.created_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Trigger para actualizar estado de contacto
CREATE OR REPLACE FUNCTION trigger_actualizar_contacto_habilitado()
RETURNS TRIGGER AS $$
BEGIN
    -- Habilitar contacto cuando el estado es 'confirmado' o 'pagado'
    IF NEW.estado IN ('confirmado', 'pagado') AND OLD.estado NOT IN ('confirmado', 'pagado') THEN
        UPDATE pedidos
        SET 
            contacto_habilitado = TRUE,
            contacto_habilitado_at = NOW(),
            updated_at = NOW()
        WHERE id = NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para actualización automática
CREATE TRIGGER trigger_actualizar_contacto_habilitado
    AFTER UPDATE ON pedidos
    FOR EACH ROW
    EXECUTE FUNCTION trigger_actualizar_contacto_habilitado();

-- Crear datos de ejemplo
UPDATE pedidos
SET 
    productos_tienda = '[
        {
            "producto_id": "550e8400-e29b-41d4-a716-446655440000",
            "nombre": "Carnada fresca",
            "precio": 500.0,
            "cantidad": 2,
            "categoria": "carnada"
        },
        {
            "producto_id": "550e8400-e29b-41d4-a716-446655440001",
            "nombre": "Bebidas pack x6",
            "precio": 800.0,
            "cantidad": 1,
            "categoria": "bebidas"
        }
    ]'::JSONB
WHERE estado = 'pendiente'
LIMIT 5;

-- Políticas de seguridad
CREATE POLICY "Usuarios pueden ver su manifiesto"
ON vw_manifiesto_completo FOR SELECT
USING (pescador_id = auth.uid() OR capitan_id = auth.uid());

CREATE POLICY "Usuarios pueden actualizar su manifiesto"
ON manifiesto_pasajeros FOR UPDATE
USING (pescador_id = auth.uid() OR capitan_id = auth.uid());

CREATE POLICY "Usuarios pueden ver productos de su viaje"
ON productos_viajes FOR SELECT
USING (EXISTS (
    SELECT 1 FROM cotizaciones c 
    WHERE c.id = productos_viajes.viaje_id 
    AND (c.pescador_id = auth.uid() OR c.capitan_id = auth.uid())
));

CREATE POLICY "Pescadores pueden aceptar sus viajes"
ON pedidos FOR UPDATE
USING (pescador_id = auth.uid())
AND (estado = 'pendiente' OR estado = 'cotizado');

CREATE POLICY "Capitanes pueden ver productos entregables"
ON productos_viajes FOR UPDATE
USING (EXISTS (
    SELECT 1 FROM cotizaciones c 
    WHERE c.id = productos_viajes.viaje_id 
    AND c.capitan_id = auth.uid()
));
