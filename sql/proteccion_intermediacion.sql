-- Sistema de Protección de Intermediación para evitar puenteo del negocio

-- Crear tabla de alertas de fraude
CREATE TABLE IF NOT EXISTS alertas_fraude (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    cotizacion_id UUID REFERENCES cotizaciones(id) ON DELETE CASCADE,
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE,
    mensaje_id UUID REFERENCES mensajes_chat(id) ON DELETE SET NULL,
    tipo_alerta VARCHAR(50) NOT NULL,
    severidad VARCHAR(20) DEFAULT 'media',
    texto_original TEXT NOT NULL,
    texto_detectado TEXT NOT NULL,
    patron_detectado VARCHAR(100),
    contexto TEXT,
    estado VARCHAR(20) DEFAULT 'pendiente',
    accion_tomada VARCHAR(50),
    advertencias_enviadas INTEGER DEFAULT 0,
    suspension_activa BOOLEAN DEFAULT FALSE,
    suspension_inicio TIMESTAMP WITH TIME ZONE,
    suspension_fin TIMESTAMP WITH TIME ZONE,
    motivo_suspension TEXT,
    datos_adicionales JSONB DEFAULT '{}'::JSONB,
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    revisado_por UUID,
    revision_at TIMESTAMP WITH TIME ZONE
);

-- Crear tabla de suspensiones de capitanes
CREATE TABLE IF NOT EXISTS suspensiones_capitanes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    alerta_fraude_id UUID REFERENCES alertas_fraude(id) ON DELETE SET NULL,
    tipo_suspension VARCHAR(20) NOT NULL,
    motivo TEXT NOT NULL,
    duracion_dias INTEGER DEFAULT 7,
    inicio_suspension TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    fin_suspension TIMESTAMP WITH TIME ZONE,
    estado VARCHAR(20) DEFAULT 'activa',
    advertencias_previas INTEGER DEFAULT 0,
    datos_adicionales JSONB DEFAULT '{}'::JSONB,
    creado_por UUID REFERENCES profiles(user_id),
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de advertencias a capitanes
CREATE TABLE IF NOT EXISTS advertencias_capitanes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    alerta_fraude_id UUID REFERENCES alertas_fraude(id) ON DELETE SET NULL,
    tipo_advertencia VARCHAR(50) NOT NULL,
    mensaje TEXT NOT NULL,
    estado VARCHAR(20) DEFAULT 'enviada',
    leida BOOLEAN DEFAULT FALSE,
    leida_at TIMESTAMP WITH TIME ZONE,
    creado_por UUID REFERENCES profiles(user_id),
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_alertas_fraude_capitan_id ON alertas_fraude(capitan_id);
CREATE INDEX IF NOT EXISTS idx_alertas_fraude_cotizacion_id ON alertas_fraude(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_alertas_fraude_pedido_id ON alertas_fraude(pedido_id);
CREATE INDEX IF NOT EXISTS idx_alertas_fraude_mensaje_id ON alertas_fraude(mensaje_id);
CREATE INDEX IF NOT EXISTS idx_alertas_fraude_estado ON alertas_fraude(estado);
CREATE INDEX IF NOT EXISTS idx_alertas_fraude_severidad ON alertas_fraude(severidad);
CREATE INDEX IF NOT EXISTS idx_alertas_fraude_creado_at ON alertas_fraude(creado_at);
CREATE INDEX IF NOT EXISTS idx_suspensiones_capitanes_capitan_id ON suspensiones_capitanes(capitan_id);
CREATE INDEX IF NOT EXISTS idx_suspensiones_capitanes_estado ON suspensiones_capitanes(estado);
CREATE INDEX IF NOT EXISTS idx_advertencias_capitanes_capitan_id ON advertencias_capitanes(capitan_id);
CREATE INDEX IF NOT EXISTS idx_advertencias_capitanes_estado ON advertencias_capitanes(estado);

-- Constraints
ALTER TABLE alertas_fraude 
ADD CONSTRAINT chk_tipo_alerta 
CHECK (tipo_alerta IN ('telefono', 'email', 'whatsapp', 'enlace_externo', 'patron_evasion', 'contacto_directo'));

ALTER TABLE alertas_fraude 
ADD CONSTRAINT chk_severidad 
CHECK (severidad IN ('baja', 'media', 'alta', 'critica'));

ALTER TABLE alertas_fraude 
ADD CONSTRAINT chk_estado_alerta 
CHECK (estado IN ('pendiente', 'revisada', 'resuelta', 'ignorada'));

ALTER TABLE suspensiones_capitanes 
ADD CONSTRAINT chk_tipo_suspension 
CHECK (tipo_suspension IN ('temporal', 'permanente', 'investigacion'));

ALTER TABLE suspensiones_capitanes 
ADD CONSTRAINT chk_estado_suspension 
CHECK (estado IN ('activa', 'finalizada', 'cancelada'));

ALTER TABLE advertencias_capitanes 
ADD CONSTRAINT chk_estado_advertencia 
CHECK (estado IN ('enviada', 'leida', 'ignorada'));

-- Algoritmo de detección avanzado
CREATE OR REPLACE FUNCTION detectar_patrones_fraude(p_texto TEXT, p_capitan_id UUID, p_contexto VARCHAR DEFAULT 'general')
RETURNS TABLE (
    contiene_fraude BOOLEAN,
    tipo_alerta VARCHAR(50),
    severidad VARCHAR(20),
    texto_detectado TEXT,
    patron_detectado VARCHAR(100),
    posicion INTEGER,
    contexto_adicional TEXT
) AS $$
DECLARE
    texto_lower TEXT := LOWER(p_texto);
    resultado BOOLEAN := FALSE;
    tipo_alerta_encontrada VARCHAR(50);
    severidad_alerta VARCHAR(20) := 'media';
    texto_encontrado TEXT := '';
    patron_encontrado VARCHAR(100);
    posicion_encontrada INTEGER := 0;
    contexto_extra TEXT := '';
BEGIN
    -- Patrones telefónicos avanzados
    IF texto_lower ~ '(?:\+?54)?(?:11|[23]\d{2}|9\d{2})?\d{7,8}' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'telefono';
        severidad_alerta := 'alta';
        texto_encontrado := substring(p_texto, '(?:\+?54)?(?:11|[23]\d{2}|9\d{2})?\d{7,8}');
        patron_encontrado := 'telefono_argentino';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    ELSIF texto_lower ~ '\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'telefono';
        severidad_alerta := 'alta';
        texto_encontrado := substring(p_texto, '\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b');
        patron_encontrado := 'telefono_formato_3_3_4';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    ELSIF texto_lower ~ '\b\d{2}[-.\s]?\d{4}[-.\s]?\d{4}\b' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'telefono';
        severidad_alerta := 'alta';
        texto_encontrado := substring(p_texto, '\b\d{2}[-.\s]?\d{4}[-.\s]?\d{4}\b');
        patron_encontrado := 'telefono_formato_2_4_4';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    ELSIF texto_lower ~ '\b\d{10,11}\b' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'telefono';
        severidad_alerta := 'alta';
        texto_encontrado := substring(p_texto, '\b\d{10,11}\b');
        patron_encontrado := 'telefono_largo';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    
    -- Patrones de email
    ELSIF texto_lower ~ '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'email';
        severidad_alerta := 'alta';
        texto_encontrado := substring(p_texto, '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
        patron_encontrado := 'email_estandar';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    
    -- Patrones de WhatsApp
    ELSIF texto_lower ~ '(?i)whatsapp|wp|wsp|whats' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'whatsapp';
        severidad_alerta := 'media';
        texto_encontrado := substring(p_texto, '(?i)whatsapp|wp|wsp|whats');
        patron_encontrado := 'mencion_whatsapp';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    
    -- Patrones de enlaces externos
    ELSIF texto_lower ~ 'https?://[^\s]+' OR texto_lower ~ 'www\.[^\s]+' OR texto_lower ~ '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[^\s]*' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'enlace_externo';
        severidad_alerta := 'critica';
        texto_encontrado := CASE 
            WHEN texto_lower ~ 'https?://[^\s]+' THEN substring(p_texto, 'https?://[^\s]+')
            WHEN texto_lower ~ 'www\.[^\s]+' THEN substring(p_texto, 'www\.[^\s]+')
            ELSE substring(p_texto, '[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/[^\s]*')
        END;
        patron_encontrado := 'enlace_externo';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    
    -- Patrones de evasión de contacto
    ELSIF texto_lower ~ '(?i)llamame al|contactame al|mi numero es|mi cel es|mi tel es|escribime a|mail me|email me|hablame al|comunicate con|contacto directo' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'patron_evasion';
        severidad_alerta := 'alta';
        texto_encontrado := substring(p_texto, '(?i)llamame al|contactame al|mi numero es|mi cel es|mi tel es|escribime a|mail me|email me|hablame al|comunicate con|contacto directo');
        patron_encontrado := 'evasion_contacto';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    
    -- Patrones de redes sociales
    ELSIF texto_lower ~ '(?i)facebook|instagram|twitter|tiktok|youtube|telegram|signal|viber|wechat|line|discord|skype' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'enlace_externo';
        severidad_alerta := 'media';
        texto_encontrado := substring(p_texto, '(?i)facebook|instagram|twitter|tiktok|youtube|telegram|signal|viber|wechat|line|discord|skype');
        patron_encontrado := 'red_social';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    
    -- Patrones de contacto directo
    ELSIF texto_lower ~ '(?i)fuera de la plataforma|fuera de la app|evitar comision|sin intermediario|directo conmigo|pago directo|transferencia directa|efectivo|mercado pago|paypal' THEN
        resultado := TRUE;
        tipo_alerta_encontrada := 'contacto_directo';
        severidad_alerta := 'critica';
        texto_encontrado := substring(p_texto, '(?i)fuera de la plataforma|fuera de la app|evitar comision|sin intermediario|directo conmigo|pago directo|transferencia directa|efectivo|mercado pago|paypal');
        patron_encontrado := 'contacto_directo_plataforma';
        posicion_encontrada := position(texto_encontrado IN p_texto);
    END IF;
    
    -- Ajustar severidad según historial del capitán
    IF resultado AND p_capitan_id IS NOT NULL THEN
        DECLARE
            alertas_previas INTEGER;
            suspensiones_previas INTEGER;
        BEGIN
            SELECT COUNT(*) INTO alertas_previas
            FROM alertas_fraude
            WHERE capitan_id = p_capitan_id
            AND estado != 'ignorada';
            
            SELECT COUNT(*) INTO suspensiones_previas
            FROM suspensiones_capitanes
            WHERE capitan_id = p_capitan_id
            AND estado = 'activa';
            
            IF suspensiones_previas > 0 THEN
                severidad_alerta := 'critica';
            ELSIF alertas_previas >= 3 THEN
                severidad_alerta := 'critica';
            ELSIF alertas_previas >= 1 THEN
                severidad_alerta := 'alta';
            END IF;
            
            contexto_extra := 'Alertas previas: ' || alertas_previas || ', Suspensiones: ' || suspensiones_previas;
        END;
    END IF;
    
    RETURN QUERY 
    SELECT resultado, tipo_alerta_encontrada, severidad_alerta, texto_encontrado, 
           patron_encontrado, posicion_encontrada, contexto_extra;
END;
$$ LANGUAGE plpgsql;

-- Función para escanear mensajes del capitán
CREATE OR REPLACE FUNCTION escanear_mensajes_capitan(p_capitan_id UUID)
RETURNS TABLE (
    alertas_creadas INTEGER,
    mensajes_escaneados INTEGER,
    detalles_alertas JSONB
) AS $$
DECLARE
    mensaje_actual RECORD;
    alerta_count INTEGER := 0;
    mensajes_count INTEGER := 0;
    detalles JSONB := '[]'::JSONB;
    resultado_deteccion RECORD;
    nueva_alerta_id UUID;
BEGIN
    -- Escanear mensajes del chat
    FOR mensaje_actual IN 
        SELECT mc.id, mc.mensaje, mc.chat_id, ca.cotizacion_id, ca.pedido_id
        FROM mensajes_chat mc
        JOIN chats_asistidos ca ON mc.chat_id = ca.id
        WHERE ca.capitan_id = p_capitan_id
        AND mc.tipo_remitente = 'capitan'
        AND mc.id NOT IN (
            SELECT mensaje_id FROM alertas_fraude 
            WHERE mensaje_id IS NOT NULL
        )
        AND mc.creado_at > NOW() - INTERVAL '30 days'
    LOOP
        mensajes_count := mensajes_count + 1;
        
        -- Detectar patrones de fraude
        SELECT * INTO resultado_deteccion
        FROM detectar_patrones_fraude(mensaje_actual.mensaje, p_capitan_id, 'mensaje_chat');
        
        -- Si se detecta fraude, crear alerta
        IF resultado_deteccion.contiene_fraude = TRUE THEN
            INSERT INTO alertas_fraude (
                capitan_id, cotizacion_id, pedido_id, mensaje_id,
                tipo_alerta, severidad, texto_original, texto_detectado,
                patron_detectado, contexto, estado, datos_adicionales, creado_at
            ) VALUES (
                p_capitan_id, mensaje_actual.cotizacion_id, mensaje_actual.pedido_id, mensaje_actual.id,
                resultado_deteccion.tipo_alerta, resultado_deteccion.severidad,
                mensaje_actual.mensaje, resultado_deteccion.texto_detectado,
                resultado_deteccion.patron_detectado, resultado_deteccion.contexto_adicional,
                'pendiente', jsonb_build_object(
                    'posicion', resultado_deteccion.posicion,
                    'chat_id', mensaje_actual.chat_id,
                    'escaneado_at', NOW()
                ), NOW()
            )
            RETURNING id INTO nueva_alerta_id;
            
            alerta_count := alerta_count + 1;
            
            -- Agregar detalles
            detalles := detalles || jsonb_build_object(
                'alerta_id', nueva_alerta_id,
                'tipo_alerta', resultado_deteccion.tipo_alerta,
                'severidad', resultado_deteccion.severidad,
                'texto_detectado', resultado_deteccion.texto_detectado,
                'mensaje_id', mensaje_actual.id,
                'creado_at', NOW()
            );
        END IF;
    END LOOP;
    
    -- Escanear cotizaciones y notas adicionales
    FOR mensaje_actual IN 
        SELECT id, descripcion, NULL as chat_id, id as cotizacion_id, NULL as pedido_id
        FROM cotizaciones
        WHERE capitan_id = p_capitan_id
        AND descripcion IS NOT NULL
        AND id NOT IN (
            SELECT cotizacion_id FROM alertas_fraude 
            WHERE cotizacion_id IS NOT NULL
            AND mensaje_id IS NULL
        )
        AND updated_at > NOW() - INTERVAL '30 days'
    LOOP
        mensajes_count := mensajes_count + 1;
        
        -- Detectar patrones de fraude
        SELECT * INTO resultado_deteccion
        FROM detectar_patrones_fraude(mensaje_actual.descripcion, p_capitan_id, 'cotizacion_descripcion');
        
        -- Si se detecta fraude, crear alerta
        IF resultado_deteccion.contiene_fraude = TRUE THEN
            INSERT INTO alertas_fraude (
                capitan_id, cotizacion_id, pedido_id, mensaje_id,
                tipo_alerta, severidad, texto_original, texto_detectado,
                patron_detectado, contexto, estado, datos_adicionales, creado_at
            ) VALUES (
                p_capitan_id, mensaje_actual.cotizacion_id, mensaje_actual.pedido_id, NULL,
                resultado_deteccion.tipo_alerta, resultado_deteccion.severidad,
                mensaje_actual.descripcion, resultado_deteccion.texto_detectado,
                resultado_deteccion.patron_detectado, resultado_deteccion.contexto_adicional,
                'pendiente', jsonb_build_object(
                    'posicion', resultado_deteccion.posicion,
                    'tipo_contexto', 'cotizacion_descripcion',
                    'escaneado_at', NOW()
                ), NOW()
            )
            RETURNING id INTO nueva_alerta_id;
            
            alerta_count := alerta_count + 1;
            
            -- Agregar detalles
            detalles := detalles || jsonb_build_object(
                'alerta_id', nueva_alerta_id,
                'tipo_alerta', resultado_deteccion.tipo_alerta,
                'severidad', resultado_deteccion.severidad,
                'texto_detectado', resultado_deteccion.texto_detectado,
                'cotizacion_id', mensaje_actual.cotizacion_id,
                'creado_at', NOW()
            );
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT alerta_count, mensajes_count, detalles;
END;
$$ LANGUAGE plpgsql;

-- Función para enviar advertencia a capitán
CREATE OR REPLACE FUNCTION enviar_advertencia_capitan(
    p_alerta_id UUID,
    p_admin_id UUID,
    p_mensaje_advertencia TEXT DEFAULT NULL
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    advertencia_id UUID
) AS $$
DECLARE
    alerta_datos RECORD;
    nueva_advertencia_id UUID;
    mensaje_defecto TEXT;
BEGIN
    -- Obtener datos de la alerta
    SELECT * INTO alerta_datos
    FROM alertas_fraude
    WHERE id = p_alerta_id;
    
    IF alerta_datos IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Alerta no encontrada', NULL::UUID;
        RETURN;
    END IF;
    
    -- Mensaje por defecto si no se proporciona
    IF p_mensaje_advertencia IS NULL OR p_mensaje_advertencia = '' THEN
        mensaje_defecto := '⚠️ ADVERTENCIA OFICIAL - CapitánYA\n\n'
            'Hemos detectado actividad sospechosa en tus mensajes que podría violar nuestros términos de servicio.\n\n'
            'Tipo de infracción: ' || alerta_datos.tipo_alerta || '\n'
            'Severidad: ' || alerta_datos.severidad || '\n'
            'Texto detectado: "' || alerta_datos.texto_detectado || '"\n\n'
            'Por favor, evita compartir información de contacto directo o enlaces externos. '
            'Continuar con esta conducta podría resultar en la suspensión de tu cuenta.\n\n'
            'Si tienes preguntas, contacta a soporte@capitanya.com';
    ELSE
        mensaje_defecto := p_mensaje_advertencia;
    END IF;
    
    -- Crear advertencia
    INSERT INTO advertencias_capitanes (
        capitan_id, alerta_fraude_id, tipo_advertencia, mensaje,
        estado, creado_por, creado_at
    ) VALUES (
        alerta_datos.capitan_id, p_alerta_id, 'oficial', mensaje_defecto,
        'enviada', p_admin_id, NOW()
    )
    RETURNING id INTO nueva_advertencia_id;
    
    -- Actualizar advertencias enviadas en la alerta
    UPDATE alertas_fraude
    SET 
        advertencias_enviadas = advertencias_enviadas + 1,
        actualizado_at = NOW()
    WHERE id = p_alerta_id;
    
    -- Crear notificación para el capitán
    INSERT INTO notificaciones_usuarios (
        user_id, tipo, titulo, mensaje, datos_adicionales, leida, created_at
    ) VALUES (
        alerta_datos.capitan_id,
        'advertencia_oficial',
        '⚠️ Advertencia Oficial',
        'Has recibido una advertencia oficial de CapitánYA',
        jsonb_build_object(
            'advertencia_id', nueva_advertencia_id,
            'alerta_fraude_id', p_alerta_id,
            'tipo_alerta', alerta_datos.tipo_alerta,
            'accion_requerida', 'leer_terminos'
        ),
        FALSE, NOW()
    );
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo, descripcion, user_id, alerta_fraude_id, datos_adicionales, created_at
    ) VALUES (
        'advertencia_enviada',
        'Administrador envió advertencia oficial a capitán',
        p_admin_id, p_alerta_id,
        jsonb_build_object(
            'capitan_id', alerta_datos.capitan_id,
            'advertencia_id', nueva_advertencia_id,
            'timestamp', NOW()
        ),
        NOW()
    );
    
    RETURN QUERY SELECT TRUE, 'Advertencia enviada exitosamente', nueva_advertencia_id;
END;
$$ LANGUAGE plpgsql;

-- Función para suspender capitán
CREATE OR REPLACE FUNCTION suspender_capitan(
    p_alerta_id UUID,
    p_admin_id UUID,
    p_tipo_suspension VARCHAR DEFAULT 'temporal',
    p_duracion_dias INTEGER DEFAULT 7,
    p_motivo TEXT DEFAULT NULL
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    suspension_id UUID
) AS $$
DECLARE
    alerta_datos RECORD;
    nueva_suspension_id UUID;
    fin_suspension TIMESTAMP WITH TIME ZONE;
    motivo_defecto TEXT;
BEGIN
    -- Obtener datos de la alerta
    SELECT * INTO alerta_datos
    FROM alertas_fraude
    WHERE id = p_alerta_id;
    
    IF alerta_datos IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Alerta no encontrada', NULL::UUID;
        RETURN;
    END IF;
    
    -- Calcular fecha de fin de suspensión
    fin_suspension := NOW() + (p_duracion_dias || ' days')::INTERVAL;
    
    -- Motivo por defecto si no se proporciona
    IF p_motivo IS NULL OR p_motivo = '' THEN
        motivo_defecto := 'Suspensión por violación de términos de servicio - ' || alerta_datos.tipo_alerta;
    ELSE
        motivo_defecto := p_motivo;
    END IF;
    
    -- Crear suspensión
    INSERT INTO suspensiones_capitanes (
        capitan_id, alerta_fraude_id, tipo_suspension, motivo,
        duracion_dias, inicio_suspension, fin_suspension, estado,
        advertencias_previas, creado_por, creado_at
    ) VALUES (
        alerta_datos.capitan_id, p_alerta_id, p_tipo_suspension, motivo_defecto,
        p_duracion_dias, NOW(), fin_suspension, 'activa',
        alerta_datos.advertencias_enviadas, p_admin_id, NOW()
    )
    RETURNING id INTO nueva_suspension_id;
    
    -- Actualizar estado del capitán (inhabilitar)
    UPDATE profiles
    SET 
        disponible = FALSE,
        suspendido = TRUE,
        suspension_razon = motivo_defecto,
        suspension_hasta = fin_suspension,
        updated_at = NOW()
    WHERE user_id = alerta_datos.capitan_id;
    
    -- Actualizar alerta
    UPDATE alertas_fraude
    SET 
        estado = 'resuelta',
        accion_tomada = 'suspension',
        suspension_activa = TRUE,
        suspension_inicio = NOW(),
        suspension_fin = fin_suspension,
        motivo_suspension = motivo_defecto,
        actualizado_at = NOW(),
        revisado_por = p_admin_id,
        revision_at = NOW()
    WHERE id = p_alerta_id;
    
    -- Crear notificación para el capitán
    INSERT INTO notificaciones_usuarios (
        user_id, tipo, titulo, mensaje, datos_adicionales, leida, created_at
    ) VALUES (
        alerta_datos.capitan_id,
        'suspension_cuenta',
        '🚫 Cuenta Suspendida',
        'Tu cuenta ha sido suspendida temporalmente',
        jsonb_build_object(
            'suspension_id', nueva_suspension_id,
            'alerta_fraude_id', p_alerta_id,
            'tipo_suspension', p_tipo_suspension,
            'fin_suspension', fin_suspension.toIso8601String(),
            'accion_requerida', 'contactar_soporte'
        ),
        FALSE, NOW()
    );
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo, descripcion, user_id, alerta_fraude_id, datos_adicionales, created_at
    ) VALUES (
        'capitan_suspendido',
        'Administrador suspendió cuenta de capitán',
        p_admin_id, p_alerta_id,
        jsonb_build_object(
            'capitan_id', alerta_datos.capitan_id,
            'suspension_id', nueva_suspension_id,
            'tipo_suspension', p_tipo_suspension,
            'duracion_dias', p_duracion_dias,
            'timestamp', NOW()
        ),
        NOW()
    );
    
    RETURN QUERY SELECT TRUE, 'Capitán suspendido exitosamente', nueva_suspension_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger para escanear automáticamente mensajes de capitanes
CREATE OR REPLACE FUNCTION trigger_escanear_mensaje_capitan()
RETURNS TRIGGER AS $$
DECLARE
    resultado_escaneo RECORD;
BEGIN
    -- Solo escanear mensajes de capitanes
    IF NEW.tipo_remitente = 'capitan' THEN
        -- Detectar patrones de fraude
        SELECT * INTO resultado_escaneo
        FROM detectar_patrones_fraude(NEW.mensaje, NEW.remitente_id, 'mensaje_chat');
        
        -- Si se detecta fraude, crear alerta automáticamente
        IF resultado_escaneo.contiene_fraude = TRUE THEN
            INSERT INTO alertas_fraude (
                capitan_id, mensaje_id, tipo_alerta, severidad,
                texto_original, texto_detectado, patron_detectado,
                contexto, estado, datos_adicionales, creado_at
            ) VALUES (
                NEW.remitente_id, NEW.id, resultado_escaneo.tipo_alerta,
                resultado_escaneo.severidad, NEW.mensaje,
                resultado_escaneo.texto_detectado, resultado_escaneo.patron_detectado,
                resultado_escaneo.contexto_adicional, 'pendiente',
                jsonb_build_object(
                    'posicion', resultado_escaneo.posicion,
                    'chat_id', NEW.chat_id,
                    'auto_detectado', TRUE,
                    'timestamp', NOW()
                ),
                NOW()
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para escaneo automático
CREATE TRIGGER trigger_escanear_mensaje_capitan
    AFTER INSERT ON mensajes_chat
    FOR EACH ROW
    EXECUTE FUNCTION trigger_escanear_mensaje_capitan();

-- Vista para alertas de seguridad del administrador
CREATE OR REPLACE VIEW vw_alertas_seguridad_admin AS
SELECT 
    af.*,
    p.nombre as capitan_nombre,
    p.email as capitan_email,
    p.telefono_contacto as capitan_telefono,
    p.foto_url as capitan_foto,
    c.descripcion as cotizacion_descripcion,
    mc.mensaje as mensaje_original,
    ca.id as chat_id,
    -- Estadísticas del capitán
    (SELECT COUNT(*) FROM alertas_fraude WHERE capitan_id = af.capitan_id) as total_alertas,
    (SELECT COUNT(*) FROM suspensiones_capitanes WHERE capitan_id = af.capitan_id AND estado = 'activa') as suspensiones_activas,
    (SELECT COUNT(*) FROM advertencias_capitanes WHERE capitan_id = af.capitan_id) as total_advertencias,
    CASE 
        WHEN af.severidad = 'critica' THEN '🔴 Crítica'
        WHEN af.severidad = 'alta' THEN '🟠 Alta'
        WHEN af.severidad = 'media' THEN '🟡 Media'
        ELSE '🟢 Baja'
    END as severidad_formateada,
    CASE 
        WHEN af.severidad = 'critica' THEN '#DC2626'
        WHEN af.severidad = 'alta' THEN '#F59E0B'
        WHEN af.severidad = 'media' THEN '#10B981'
        ELSE '#6B7280'
    END as color_severidad
FROM alertas_fraude af
LEFT JOIN profiles p ON af.capitan_id = p.user_id
LEFT JOIN cotizaciones c ON af.cotizacion_id = c.id
LEFT JOIN mensajes_chat mc ON af.mensaje_id = mc.id
LEFT JOIN chats_asistidos ca ON mc.chat_id = ca.id
WHERE af.estado = 'pendiente'
ORDER BY af.creado_at DESC;

-- Función para obtener alertas de seguridad
CREATE OR REPLACE FUNCTION get_alertas_seguridad()
RETURNS TABLE (
    id UUID,
    capitan_id UUID,
    capitan_nombre TEXT,
    capitan_email TEXT,
    capitan_foto TEXT,
    tipo_alerta VARCHAR,
    severidad VARCHAR,
    severidad_formateada TEXT,
    color_severidad TEXT,
    texto_original TEXT,
    texto_detectado TEXT,
    patron_detectado VARCHAR,
    contexto TEXT,
    estado VARCHAR,
    total_alertas INTEGER,
    suspensiones_activas INTEGER,
    total_advertencias INTEGER,
    creado_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM vw_alertas_seguridad_admin;
END;
$$ LANGUAGE plpgsql;

-- Función para liberar datos de contacto solo al aceptar
CREATE OR REPLACE FUNCTION liberar_contacto_al_aceptar()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo liberar si el estado cambia a 'aceptada'
    IF OLD.estado != 'aceptada' AND NEW.estado = 'aceptada' THEN
        -- Actualizar pedido para liberar datos de contacto
        UPDATE pedidos
        SET 
            contacto_liberado = TRUE,
            contacto_liberado_at = NOW(),
            updated_at = NOW()
        WHERE id = NEW.id;
        
        -- Registrar en logs
        INSERT INTO logs_sistema (
            tipo, descripcion, cotizacion_id, pedido_id, datos_adicionales, created_at
        ) VALUES (
            'contacto_liberado',
            'Datos de contacto liberados al aceptar cotización',
            NEW.id, NEW.id,
            jsonb_build_object(
                'estado_anterior', OLD.estado,
                'estado_nuevo', NEW.estado,
                'liberado_at', NOW()
            ),
            NOW()
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para liberación de contacto
CREATE TRIGGER trigger_liberar_contacto_al_aceptar
    AFTER UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION liberar_contacto_al_aceptar();

-- Asegurar que la tabla pedidos tenga el campo contacto_liberado
ALTER TABLE pedidos 
ADD COLUMN IF NOT EXISTS contacto_liberado BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS contacto_liberado_at TIMESTAMP WITH TIME ZONE;

-- Asegurar que la tabla profiles tenga campos de suspensión
ALTER TABLE profiles 
ADD COLUMN IF NOT EXISTS suspendido BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS suspension_razon TEXT,
ADD COLUMN IF NOT EXISTS suspension_hasta TIMESTAMP WITH TIME ZONE;

-- Crear datos de ejemplo para pruebas
INSERT INTO alertas_fraude (
    capitan_id, tipo_alerta, severidad, texto_original, texto_detectado,
    patron_detectado, contexto, estado, creado_at
) VALUES 
(
    '22222222-2222-2222-2222-222222222222',
    'telefono',
    'alta',
    'Llamame al 11-1234-5678 para coordinar',
    '11-1234-5678',
    'telefono_formato_3_3_4',
    'Mensaje de chat',
    'pendiente',
    NOW()
),
(
    '22222222-2222-2222-2222-222222222222',
    'email',
    'alta',
    'Contactame a pescador@email.com',
    'pescador@email.com',
    'email_estandar',
    'Descripción de cotización',
    'pendiente',
    NOW()
),
(
    '22222222-2222-2222-2222-222222222222',
    'contacto_directo',
    'critica',
    'Hagamos todo fuera de la plataforma para evitar comisiones',
    'fuera de la plataforma',
    'contacto_directo_plataforma',
    'Mensaje de chat',
    'pendiente',
    NOW()
);

-- Políticas de seguridad
CREATE POLICY "Admin puede ver alertas de fraude"
ON alertas_fraude FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede actualizar alertas de fraude"
ON alertas_fraude FOR UPDATE
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede ver suspensiones"
ON suspensiones_capitanes FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede ver advertencias"
ON advertencias_capitanes FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede ver vista de alertas de seguridad"
ON vw_alertas_seguridad_admin FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));
