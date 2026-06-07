-- Schema para el Portal del Capitán - Sistema de Cotizaciones
-- CapitánYA - Mecanización de Comunicación de Cotizaciones

-- 1. Tabla de Cotizaciones
CREATE TABLE IF NOT EXISTS cotizaciones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pescador_id UUID NOT NULL REFERENCES perfiles(id),
    capitan_id UUID REFERENCES perfiles(id),
    viaje_id UUID REFERENCES viajes(id),
    
    -- Información de la solicitud
    titulo VARCHAR(255) NOT NULL,
    descripcion TEXT,
    fecha_solicitud TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    fecha_respuesta TIMESTAMP WITH TIME ZONE,
    fecha_vigencia TIMESTAMP WITH TIME ZONE,
    
    -- Estado de la cotización
    status VARCHAR(20) NOT NULL DEFAULT 'pendiente' CHECK (status IN ('pendiente', 'enviado', 'aceptado', 'rechazado', 'vencido')),
    
    -- Montos y detalles
    monto_total DECIMAL(10,2) NOT NULL,
    moneda VARCHAR(3) DEFAULT 'ARS',
    detalles JSONB NOT NULL DEFAULT '{}',
    
    -- Archivos adjuntos
    archivos_adjuntos JSONB DEFAULT '[]',
    
    -- Auditoría
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Índices
    CONSTRAINT cotizaciones_status_check CHECK (status IN ('pendiente', 'enviado', 'aceptado', 'rechazado', 'vencido'))
);

-- 2. Tabla de Historial de Cambios de Estado
CREATE TABLE IF NOT EXISTS cotizaciones_estado_historial (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cotizacion_id UUID NOT NULL REFERENCES cotizaciones(id) ON DELETE CASCADE,
    estado_anterior VARCHAR(20),
    estado_nuevo VARCHAR(20) NOT NULL,
    motivo_cambio TEXT,
    usuario_id UUID REFERENCES perfiles(id),
    fecha_cambio TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. Tabla de Mensajes de Cotización
CREATE TABLE IF NOT EXISTS cotizaciones_mensajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cotizacion_id UUID NOT NULL REFERENCES cotizaciones(id) ON DELETE CASCADE,
    remitente_id UUID NOT NULL REFERENCES perfiles(id),
    mensaje TEXT NOT NULL,
    tipo_mensaje VARCHAR(20) NOT NULL CHECK (tipo_mensaje IN ('solicitud', 'respuesta', 'aclaracion')),
    leido BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Tabla de Plantillas de Cotización
CREATE TABLE IF NOT EXISTS cotizaciones_plantillas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID NOT NULL REFERENCES perfiles(id),
    nombre VARCHAR(255) NOT NULL,
    descripcion TEXT,
    detalles_plantilla JSONB NOT NULL DEFAULT '{}',
    activa BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Función para actualizar estado con historial
CREATE OR REPLACE FUNCTION actualizar_estado_cotizacion(
    p_cotizacion_id UUID,
    p_nuevo_estado VARCHAR(20),
    p_motivo TEXT DEFAULT NULL,
    p_usuario_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
    v_estado_actual VARCHAR(20);
BEGIN
    -- Obtener estado actual
    SELECT status INTO v_estado_actual FROM cotizaciones WHERE id = p_cotizacion_id;
    
    -- Verificar que exista y que el estado sea diferente
    IF v_estado_actual IS NULL THEN
        RAISE EXCEPTION 'Cotización no encontrada';
    END IF;
    
    IF v_estado_actual = p_nuevo_estado THEN
        RETURN TRUE; -- No hay cambio, pero consideramos exitoso
    END IF;
    
    -- Registrar en historial
    INSERT INTO cotizaciones_estado_historial (
        cotizacion_id,
        estado_anterior,
        estado_nuevo,
        motivo_cambio,
        usuario_id
    ) VALUES (
        p_cotizacion_id,
        v_estado_actual,
        p_nuevo_estado,
        p_motivo,
        p_usuario_id
    );
    
    -- Actualizar estado principal
    UPDATE cotizaciones 
    SET 
        status = p_nuevo_estado,
        updated_at = NOW()
    WHERE id = p_cotizacion_id;
    
    -- Si es aceptado, actualizar fecha de respuesta
    IF p_nuevo_estado = 'aceptado' THEN
        UPDATE cotizaciones 
        SET fecha_respuesta = NOW()
        WHERE id = p_cotizacion_id;
    END IF;
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- 6. Trigger para actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION actualizar_timestamp_cotizacion()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cotizaciones_updated_at
    BEFORE UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION actualizar_timestamp_cotizacion();

-- 7. Índices para optimización
CREATE INDEX IF NOT EXISTS idx_cotizaciones_status ON cotizaciones(status);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_pescador ON cotizaciones(pescador_id);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_capitan ON cotizaciones(capitan_id);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_fecha_solicitud ON cotizaciones(fecha_solicitud);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_mensajes_cotizacion ON cotizaciones_mensajes(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_historial_cotizacion ON cotizaciones_estado_historial(cotizacion_id);

-- 8. Vista de Cotizaciones Activas para el Capitán
CREATE OR REPLACE VIEW vista_cotizaciones_activas AS
SELECT 
    c.id,
    c.titulo,
    c.status,
    c.fecha_solicitud,
    c.fecha_respuesta,
    c.fecha_vigencia,
    c.monto_total,
    p.nombre as pescador_nombre,
    p.email as pescador_email,
    p.telefono as pescador_telefono,
    v.nombre as viaje_nombre,
    v.fecha_salida as viaje_fecha_salida,
    v.fecha_llegada as viaje_fecha_llegada,
    CASE 
        WHEN c.status = 'pendiente' THEN '⏳ Esperando respuesta'
        WHEN c.status = 'enviado' THEN '📤 Enviado al cliente'
        WHEN c.status = 'aceptado' THEN '✅ Aceptado'
        WHEN c.status = 'rechazado' THEN '❌ Rechazado'
        WHEN c.status = 'vencido' THEN '⏰ Vencido'
        ELSE c.status
    END as estado_descripcion,
    CASE 
        WHEN c.fecha_vigencia < NOW() AND c.status = 'pendiente' THEN TRUE
        ELSE FALSE
    END as vencido
FROM cotizaciones c
LEFT JOIN perfiles p ON c.pescador_id = p.id
LEFT JOIN viajes v ON c.viaje_id = v.id
WHERE c.status IN ('pendiente', 'enviado')
ORDER BY c.fecha_solicitud DESC;

-- 9. Función para obtener cotizaciones del Capitán
CREATE OR REPLACE FUNCTION obtener_cotizaciones_capitan(
    p_capitan_id UUID,
    p_limite INTEGER DEFAULT 50,
    p_offset INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    titulo VARCHAR,
    status VARCHAR,
    fecha_solicitud TIMESTAMP WITH TIME ZONE,
    monto_total DECIMAL,
    pescador_nombre VARCHAR,
    pescador_email VARCHAR,
    estado_descripcion VARCHAR,
    vencido BOOLEAN,
    mensajes_no_leidos INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        c.id,
        c.titulo,
        c.status,
        c.fecha_solicitud,
        c.monto_total,
        p.nombre as pescador_nombre,
        p.email as pescador_email,
        CASE 
            WHEN c.status = 'pendiente' THEN '⏳ Esperando respuesta'
            WHEN c.status = 'enviado' THEN '📤 Enviado al cliente'
            WHEN c.status = 'aceptado' THEN '✅ Aceptado'
            WHEN c.status = 'rechazado' THEN '❌ Rechazado'
            WHEN c.status = 'vencido' THEN '⏰ Vencido'
            ELSE c.status
        END as estado_descripcion,
        CASE 
            WHEN c.fecha_vigencia < NOW() AND c.status = 'pendiente' THEN TRUE
            ELSE FALSE
        END as vencido,
        (SELECT COUNT(*) FROM cotizaciones_mensajes cm 
         WHERE cm.cotizacion_id = c.id AND cm.tipo_mensaje = 'solicitud' AND cm.leido = FALSE) as mensajes_no_leidos
    FROM cotizaciones c
    LEFT JOIN perfiles p ON c.pescador_id = p.id
    WHERE c.capitan_id = p_capitan_id
    ORDER BY c.fecha_solicitud DESC
    LIMIT p_limite OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

-- 10. Datos de ejemplo para testing
INSERT INTO cotizaciones (
    id,
    pescador_id,
    capitan_id,
    viaje_id,
    titulo,
    descripcion,
    status,
    monto_total,
    detalles,
    fecha_vigencia
) VALUES 
    (
        gen_random_uuid(),
        (SELECT id FROM perfiles WHERE email = 'pescador@ejemplo.com' LIMIT 1),
        (SELECT id FROM perfiles WHERE email = 'capitan@ejemplo.com' LIMIT 1),
        (SELECT id FROM viajes WHERE titulo = 'Viaje a Puerto Pirámides' LIMIT 1),
        'Cotización Viaje Puerto Pirámides - 2 Personas',
        'Viaje completo para 2 pescadores con equipo completo incluido. Salida 06:00, regreso 18:00.',
        'pendiente',
        85000.00,
        '{
            "items": [
                {"descripcion": "Servicio de capitán", "cantidad": 1, "precio_unitario": 50000.00},
                {"descripcion": "Alquiler de equipo completo", "cantidad": 2, "precio_unitario": 15000.00},
                {"descripcion": "Carnada fresca", "cantidad": 2, "precio_unitario": 5000.00}
            ],
            "incluye": ["equipo", "carnada", "seguro", "permisos"],
            "no_incluye": ["transporte", "almuerzo"]
        }'::jsonb,
        NOW() + INTERVAL '7 days'
    ),
    (
        gen_random_uuid(),
        (SELECT id FROM perfiles WHERE email = 'pescador2@ejemplo.com' LIMIT 1),
        (SELECT id FROM perfiles WHERE email = 'capitan@ejemplo.com' LIMIT 1),
        (SELECT id FROM viajes WHERE titulo = 'Viaje a San Clemente' LIMIT 1),
        'Cotización San Clemente - Grupo 4 Personas',
        'Viaje para grupo de 4 personas. Incluye guía especializada en pesca de tiburón.',
        'enviado',
        120000.00,
        '{
            "items": [
                {"descripcion": "Guía especializada", "cantidad": 1, "precio_unitario": 80000.00},
                {"descripcion": "Equipo premium", "cantidad": 4, "precio_unitario": 10000.00}
            ],
            "especialidad": "pesca de tiburón",
            "experiencia": "guía con 10 años de experiencia"
        }'::jsonb,
        NOW() + INTERVAL '5 days'
    );

-- 11. Políticas de seguridad (RLS)
ALTER TABLE cotizaciones ENABLE ROW LEVEL SECURITY;

-- Solo el capitán puede ver sus cotizaciones
CREATE POLICY politica_cotizaciones_capitan ON cotizaciones
    FOR ALL USING (capitan_id = auth.uid());

-- Solo el pescador puede ver sus solicitudes
CREATE POLICY politica_cotizaciones_pescador ON cotizaciones
    FOR ALL USING (pescador_id = auth.uid());

-- Todos pueden crear cotizaciones (el sistema las crea automáticamente)
CREATE POLICY politica_cotizaciones_insert ON cotizaciones
    FOR INSERT WITH CHECK (true);

-- Solo los involucrados pueden actualizar
CREATE POLICY politica_cotizaciones_update ON cotizaciones
    FOR UPDATE USING (capitan_id = auth.uid() OR pescador_id = auth.uid());

COMMIT;
