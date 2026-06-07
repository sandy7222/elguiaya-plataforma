-- Sistema de Intermediación Blindada similar a MercadoLibre

-- Crear tabla de chats asistidos
CREATE TABLE IF NOT EXISTS chats_asistidos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cotizacion_id UUID REFERENCES cotizaciones(id) ON DELETE CASCADE,
    pescador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    estado VARCHAR(20) DEFAULT 'activo',
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    actualizado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de mensajes del chat asistido
CREATE TABLE IF NOT EXISTS mensajes_chat (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chat_id UUID REFERENCES chats_asistidos(id) ON DELETE CASCADE,
    remitente_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    tipo_remitente VARCHAR(20) NOT NULL, -- 'pescador', 'capitan', 'ia'
    mensaje TEXT NOT NULL,
    mensaje_filtrado TEXT, -- Mensaje después de aplicar filtros
    contiene_contacto BOOLEAN DEFAULT FALSE,
    tipo_contacto VARCHAR(50), -- 'telefono', 'email', 'whatsapp'
    bloqueado BOOLEAN DEFAULT FALSE,
    motivo_bloqueo TEXT,
    creado_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    leido_at TIMESTAMP WITH TIME ZONE
);

-- Crear tabla de reputación de capitanes
CREATE TABLE IF NOT EXISTS reputacion_capitanes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    capitan_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    calificacion_promedio DECIMAL(3,2) DEFAULT 0.0,
    total_viajes INTEGER DEFAULT 0,
    viajes_completados INTEGER DEFAULT 0,
    viajes_cancelados INTEGER DEFAULT 0,
    total_calificaciones INTEGER DEFAULT 0,
    calificaciones_5_estrellas INTEGER DEFAULT 0,
    calificaciones_4_estrellas INTEGER DEFAULT 0,
    calificaciones_3_estrellas INTEGER DEFAULT 0,
    calificaciones_2_estrellas INTEGER DEFAULT 0,
    calificaciones_1_estrella INTEGER DEFAULT 0,
    ultima_calificacion TIMESTAMP WITH TIME ZONE,
    nivel_reputacion VARCHAR(20) DEFAULT 'novato', -- 'novato', 'intermedio', 'experto', 'elite'
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear tabla de calificaciones detalladas
CREATE TABLE IF NOT EXISTS calificaciones_viajes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pedido_id UUID REFERENCES pedidos(id) ON DELETE CASCADE,
    calificador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE, -- pescador que califica
    capitán_calificado_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    calificacion INTEGER CHECK (calificacion >= 1 AND calificacion <= 5),
    comentario TEXT,
    aspectos_puntuados JSONB DEFAULT '{}'::JSONB, -- {'puntualidad': 5, 'seguridad': 4, 'comunicacion': 5}
    respuesta_capitan TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Índices para optimización
CREATE INDEX IF NOT EXISTS idx_chats_asistidos_cotizacion_id ON chats_asistidos(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_chats_asistidos_pescador_id ON chats_asistidos(pescador_id);
CREATE INDEX IF NOT EXISTS idx_chats_asistidos_capitan_id ON chats_asistidos(capitan_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_chat_chat_id ON mensajes_chat(chat_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_chat_remitente_id ON mensajes_chat(remitente_id);
CREATE INDEX IF NOT EXISTS idx_mensajes_chat_creado_at ON mensajes_chat(creado_at);
CREATE INDEX IF NOT EXISTS idx_reputacion_capitanes_capitan_id ON reputacion_capitanes(capitan_id);
CREATE INDEX IF NOT EXISTS idx_reputacion_capitanes_calificacion_promedio ON reputacion_capitanes(calificacion_promedio);
CREATE INDEX IF NOT EXISTS idx_calificaciones_viajes_pedido_id ON calificaciones_viajes(pedido_id);
CREATE INDEX IF NOT EXISTS idx_calificaciones_viajes_capitán_calificado_id ON calificaciones_viajes(capitán_calificado_id);

-- Constraints
ALTER TABLE chats_asistidos 
ADD CONSTRAINT chk_estado_chat 
CHECK (estado IN ('activo', 'cerrado', 'bloqueado'));

ALTER TABLE mensajes_chat 
ADD CONSTRAINT chk_tipo_remitente 
CHECK (tipo_remitente IN ('pescador', 'capitan', 'ia'));

ALTER TABLE reputacion_capitanes 
ADD CONSTRAINT chk_nivel_reputacion 
CHECK (nivel_reputacion IN ('novato', 'intermedio', 'experto', 'elite'));

-- Función para filtrar mensajes y detectar información de contacto
CREATE OR REPLACE FUNCTION filtrar_mensaje_contacto(p_mensaje TEXT)
RETURNS TABLE (
    mensaje_filtrado TEXT,
    contiene_contacto BOOLEAN,
    tipo_contacto VARCHAR(50),
    contacto_detectado TEXT,
    motivo_bloqueo TEXT
) AS $$
DECLARE
    mensaje_limpio TEXT := p_mensaje;
    telefono_encontrado TEXT := '';
    email_encontrado TEXT := '';
    whatsapp_encontrado TEXT := '';
    motivo TEXT := '';
BEGIN
    -- Detectar números telefónicos (patrones argentinos y generales)
    IF mensaje_limpio ~ '(?:\+?54)?(?:11|[23]\d{2}|9\d{2})?\d{7,8}' OR
       mensaje_limpio ~ '\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b' OR
       mensaje_limpio ~ '\b\d{2}[-.\s]?\d{4}[-.\s]?\d{4}\b' OR
       mensaje_limpio ~ '\b\d{10,11}\b' THEN
        telefono_encontrado := substring(mensaje_limpio, '(?:\+?54)?(?:11|[23]\d{2}|9\d{2})?\d{7,8}');
        motivo := 'Número telefónico detectado';
    END IF;
    
    -- Detectar correos electrónicos
    IF mensaje_limpio ~ '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}' THEN
        email_encontrado := substring(mensaje_limpio, '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}');
        IF motivo = '' THEN
            motivo := 'Correo electrónico detectado';
        ELSE
            motivo := motivo || ' y correo electrónico';
        END IF;
    END IF;
    
    -- Detectar menciones de WhatsApp
    IF mensaje_limpio ~ '(?i)whatsapp|wp|wsp' THEN
        whatsapp_encontrado := 'WhatsApp';
        IF motivo = '' THEN
            motivo := 'Mención de WhatsApp detectada';
        ELSE
            motivo := motivo || ' y mención de WhatsApp';
        END IF;
    END IF;
    
    -- Detectar patrones de evasión
    IF mensaje_limpio ~ '(?i)llamame al|contactame al|mi numero es|mi cel es|mi tel es|escribime a|mail me|email me' THEN
        IF motivo = '' THEN
            motivo := 'Patrón de evasión de contacto detectado';
        ELSE
            motivo := motivo || ' y patrón de evasión';
        END IF;
    END IF;
    
    -- Si se detectó contacto, marcar como bloqueado
    IF motivo != '' THEN
        -- Ocultar información detectada
        mensaje_filtrado := regexp_replace(
            regexp_replace(
                regexp_replace(
                    mensaje_limpio,
                    '(?:\+?54)?(?:11|[23]\d{2}|9\d{2})?\d{7,8}',
                    '[TELÉFONO OCULTO]',
                    'g'
                ),
                '[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
                '[EMAIL OCULTO]',
                'g'
            ),
            '(?i)whatsapp|wp|wsp',
            '[WHATSAPP OCULTO]',
            'g'
        );
        
        RETURN QUERY SELECT mensaje_filtrado, TRUE, 
            CASE 
                WHEN telefono_encontrado != '' THEN 'telefono'
                WHEN email_encontrado != '' THEN 'email'
                WHEN whatsapp_encontrado != '' THEN 'whatsapp'
                ELSE 'desconocido'
            END,
            COALESCE(telefono_encontrado, email_encontrado, whatsapp_encontrado),
            motivo;
    ELSE
        RETURN QUERY SELECT mensaje_limpio, FALSE, NULL, NULL, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para crear chat asistido
CREATE OR REPLACE FUNCTION crear_chat_asistido(p_cotizacion_id UUID, p_pescador_id UUID, p_capitan_id UUID)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    chat_id UUID
) AS $$
DECLARE
    chat_existente UUID;
    nuevo_chat_id UUID;
BEGIN
    -- Verificar si ya existe un chat para esta cotización
    SELECT id INTO chat_existente
    FROM chats_asistidos
    WHERE cotizacion_id = p_cotizacion_id;
    
    IF chat_existente IS NOT NULL THEN
        RETURN QUERY SELECT TRUE, 'Chat ya existe para esta cotización', chat_existente;
        RETURN;
    END IF;
    
    -- Crear nuevo chat
    INSERT INTO chats_asistidos (
        cotizacion_id, pescador_id, capitan_id, creado_at
    ) VALUES (
        p_cotizacion_id, p_pescador_id, p_capitan_id, NOW()
    )
    RETURNING id INTO nuevo_chat_id;
    
    -- Enviar mensaje de bienvenida de la IA
    INSERT INTO mensajes_chat (
        chat_id, remitente_id, tipo_remitente, mensaje, mensaje_filtrado, 
        contiene_contacto, bloqueado, creado_at
    ) VALUES (
        nuevo_chat_id, NULL, 'ia',
        '¡Hola! Soy el asistente de CapitánYA. Estoy aquí para ayudarte con tus consultas sobre este viaje. Por seguridad, no puedo compartir información de contacto directo hasta que el viaje sea confirmado. ¿En qué puedo ayudarte?',
        '¡Hola! Soy el asistente de CapitánYA. Estoy aquí para ayudarte con tus consultas sobre este viaje. Por seguridad, no puedo compartir información de contacto directo hasta que el viaje sea confirmado. ¿En qué puedo ayudarte?',
        FALSE, FALSE, NOW()
    );
    
    RETURN QUERY SELECT TRUE, 'Chat asistido creado exitosamente', nuevo_chat_id;
END;
$$ LANGUAGE plpgsql;

-- Función para enviar mensaje en chat asistido
CREATE OR REPLACE FUNCTION enviar_mensaje_chat(
    p_chat_id UUID,
    p_remitente_id UUID,
    p_tipo_remitente VARCHAR(20),
    p_mensaje TEXT
)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    mensaje_id UUID,
    bloqueado BOOLEAN,
    motivo_bloqueo TEXT
) AS $$
DECLARE
    mensaje_filtrado_resultado RECORD;
    nuevo_mensaje_id UUID;
    respuesta_ia TEXT;
BEGIN
    -- Filtrar mensaje para detectar información de contacto
    SELECT * INTO mensaje_filtrado_resultado
    FROM filtrar_mensaje_contacto(p_mensaje);
    
    -- Determinar si el mensaje debe ser bloqueado
    IF mensaje_filtrado_resultado.contiene_contacto = TRUE THEN
        -- Insertar mensaje bloqueado
        INSERT INTO mensajes_chat (
            chat_id, remitente_id, tipo_remitente, mensaje, mensaje_filtrado,
            contiene_contacto, tipo_contacto, bloqueado, motivo_bloqueo, creado_at
        ) VALUES (
            p_chat_id, p_remitente_id, p_tipo_remitente, p_mensaje, 
            mensaje_filtrado_resultado.mensaje_filtrado,
            TRUE, mensaje_filtrado_resultado.tipo_contacto, TRUE, 
            mensaje_filtrado_resultado.motivo_bloqueo, NOW()
        )
        RETURNING id INTO nuevo_mensaje_id;
        
        -- Enviar respuesta de la IA
        respuesta_ia := '⚠️ Por seguridad, no puedo permitir compartir información de contacto directo. Esto protege tanto a pescadores como a capitanes. Una vez que el viaje sea confirmado, podrán contactarse libremente. ¿Hay algo más sobre el viaje que pueda ayudarte a resolver?';
        
        INSERT INTO mensajes_chat (
            chat_id, remitente_id, tipo_remitente, mensaje, mensaje_filtrado,
            contiene_contacto, bloqueado, creado_at
        ) VALUES (
            p_chat_id, NULL, 'ia', respuesta_ia, respuesta_ia,
            FALSE, FALSE, NOW()
        );
        
        RETURN QUERY SELECT FALSE, 'Mensaje bloqueado por seguridad', nuevo_mensaje_id, TRUE, mensaje_filtrado_resultado.motivo_bloqueo;
    ELSE
        -- Insertar mensaje permitido
        INSERT INTO mensajes_chat (
            chat_id, remitente_id, tipo_remitente, mensaje, mensaje_filtrado,
            contiene_contacto, bloqueado, creado_at
        ) VALUES (
            p_chat_id, p_remitente_id, p_tipo_remitente, p_mensaje, 
            mensaje_filtrado_resultado.mensaje_filtrado,
            FALSE, FALSE, NOW()
        )
        RETURNING id INTO nuevo_mensaje_id;
        
        -- Generar respuesta de la IA si es un mensaje de pescador
        IF p_tipo_remitente = 'pescador' THEN
            respuesta_ia := generar_respuesta_ia_chat(p_mensaje);
            
            INSERT INTO mensajes_chat (
                chat_id, remitente_id, tipo_remitente, mensaje, mensaje_filtrado,
                contiene_contacto, bloqueado, creado_at
            ) VALUES (
                p_chat_id, NULL, 'ia', respuesta_ia, respuesta_ia,
                FALSE, FALSE, NOW()
            );
        END IF;
        
        RETURN QUERY SELECT TRUE, 'Mensaje enviado exitosamente', nuevo_mensaje_id, FALSE, NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para generar respuesta de la IA del chat
CREATE OR REPLACE FUNCTION generar_respuesta_ia_chat(p_mensaje TEXT)
RETURNS TEXT AS $$
DECLARE
    mensaje_lower TEXT := LOWER(p_mensaje);
    respuesta TEXT;
BEGIN
    -- Respuestas basadas en patrones comunes
    IF mensaje_lower ~ '(?i)horario|horarios|cuando|a que hora|que hora' THEN
        respuesta := 'Los horarios del viaje están detallados en la cotización. Si necesitas información específica sobre el horario de encuentro, puedo ayudarte a revisar los detalles. ¿Hay algo específico del horario que te preocupe?';
    ELSIF mensaje_lower ~ '(?i)precio|cuanto cuesta|costo|valor|tarifa' THEN
        respuesta := 'El presupuesto está visible en la tarjeta de la cotización. Este precio incluye todos los servicios básicos del viaje. Si tienes dudas sobre qué está incluido, puedo aclararlo. ¿Te gustaría saber más sobre los servicios incluidos?';
    ELSIF mensaje_lower ~ '(?i)lugar|donde|ubicacion|punto|encuentro' THEN
        respuesta := 'El punto de encuentro está especificado en los detalles del viaje. Por seguridad, no puedo compartir direcciones exactas aquí, pero puedes verlo en el mapa de la cotización. ¿Necesitas ayuda para encontrar el lugar?';
    ELSIF mensaje_lower ~ '(?i)capitan|quien es|experiencia|antiguedad' THEN
        respuesta := 'Puedo ver que el capitán tiene experiencia verificada en nuestra plataforma. Una vez que aceptes la cotización, podrás ver su perfil completo, incluyendo su experiencia y calificaciones. ¿Te interesa conocer su reputación?';
    ELSIF mensaje_lower ~ '(?i)seguridad|seguro|equipamiento|chaleco' THEN
        respuesta := 'La seguridad es nuestra prioridad. Todos los capitanes verificados deben contar con equipo de seguridad básico. Si tienes preocupaciones específicas sobre seguridad, puedo ayudarte a verificar qué equipo estará disponible. ¿Hay algún aspecto de seguridad que te preocupe?';
    ELSIF mensaje_lower ~ '(?i)cancelar|devolucion|reembolso' THEN
        respuesta := 'Las políticas de cancelación están definidas en los términos del servicio. Generalmente, las cancelaciones con anticipación tienen reembolso parcial. ¿Te gustaría conocer las condiciones específicas para este viaje?';
    ELSIF mensaje_lower ~ '(?i)gracias|ok|perfecto|excelente' THEN
        respuesta := '¡De nada! Estoy aquí para ayudarte. Si tienes más preguntas sobre el viaje o necesitas asistencia con cualquier otro aspecto, no dudes en consultarme.';
    ELSE
        respuesta := 'Entiendo tu consulta. Para darte la mejor respuesta, ¿podrías ser más específico sobre qué aspecto del viaje te interesa conocer? Puedo ayudarte con información sobre horarios, precios, seguridad, ubicación y otros detalles del viaje.';
    END IF;
    
    RETURN respuesta;
END;
$$ LANGUAGE plpgsql;

-- Función para obtener perfil blindado del capitán
CREATE OR REPLACE FUNCTION get_perfil_capitan_blindado(p_capitan_id UUID, p_cotizacion_id UUID)
RETURNS TABLE (
    user_id UUID,
    nombre TEXT,
    foto_url TEXT,
    calificacion_promedio DECIMAL,
    total_viajes INTEGER,
    nivel_reputacion VARCHAR,
    contacto_visible BOOLEAN,
    telefono TEXT,
    email TEXT,
    apellido TEXT
) AS $$
DECLARE
    estado_cotizacion VARCHAR;
    perfil_datos RECORD;
    reputacion_datos RECORD;
BEGIN
    -- Obtener estado de la cotización
    SELECT estado INTO estado_cotizacion
    FROM cotizaciones
    WHERE id = p_cotizacion_id;
    
    -- Obtener datos del perfil
    SELECT * INTO perfil_datos
    FROM profiles
    WHERE user_id = p_capitan_id;
    
    -- Obtener datos de reputación
    SELECT * INTO reputacion_datos
    FROM reputacion_capitanes
    WHERE capitan_id = p_capitan_id;
    
    -- Determinar si el contacto es visible
    IF estado_cotizacion IN ('aceptada', 'pagada', 'completado_pendiente_firma', 'liquidado') THEN
        RETURN QUERY 
        SELECT 
            perfil_datos.user_id,
            perfil_datos.nombre || ' ' || COALESCE(perfil_datos.apellido, ''),
            perfil_datos.foto_url,
            COALESCE(reputacion_datos.calificacion_promedio, 0.0),
            COALESCE(reputacion_datos.total_viajes, 0),
            COALESCE(reputacion_datos.nivel_reputacion, 'novato'),
            TRUE,
            perfil_datos.telefono_contacto,
            perfil_datos.email,
            perfil_datos.apellido;
    ELSE
        RETURN QUERY 
        SELECT 
            perfil_datos.user_id,
            perfil_datos.nombre,
            perfil_datos.foto_url,
            COALESCE(reputacion_datos.calificacion_promedio, 0.0),
            COALESCE(reputacion_datos.total_viajes, 0),
            COALESCE(reputacion_datos.nivel_reputacion, 'novato'),
            FALSE,
            NULL,
            NULL,
            NULL;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Función para actualizar reputación del capitán
CREATE OR REPLACE FUNCTION actualizar_reputacion_capitan(p_capitan_id UUID, p_calificacion INTEGER)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    nueva_calificacion_promedio DECIMAL,
    nuevo_nivel VARCHAR
) AS $$
DECLARE
    reputacion_actual RECORD;
    nueva_calificacion DECIMAL;
    nuevo_nivel_reputacion VARCHAR;
BEGIN
    -- Obtener reputación actual o crear nueva
    SELECT * INTO reputacion_actual
    FROM reputacion_capitanes
    WHERE capitan_id = p_capitan_id;
    
    IF reputacion_actual IS NULL THEN
        -- Crear nuevo registro de reputación
        INSERT INTO reputacion_capitanes (
            capitan_id, calificacion_promedio, total_calificaciones, 
            total_viajes, viajes_completados,
            calificaciones_5_estrellas, calificaciones_4_estrellas, 
            calificaciones_3_estrellas, calificaciones_2_estrellas, calificaciones_1_estrella,
            created_at, updated_at
        ) VALUES (
            p_capitan_id, p_calificacion::DECIMAL, 1, 1, 1,
            CASE WHEN p_calificacion = 5 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 4 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 3 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 2 THEN 1 ELSE 0 END,
            CASE WHEN p_calificacion = 1 THEN 1 ELSE 0 END,
            NOW(), NOW()
        );
        
        nueva_calificacion := p_calificacion::DECIMAL;
    ELSE
        -- Actualizar reputación existente
        UPDATE reputacion_capitanes SET
            total_calificaciones = total_calificaciones + 1,
            total_viajes = total_viajes + 1,
            viajes_completados = viajes_completados + 1,
            calificaciones_5_estrellas = calificaciones_5_estrellas + CASE WHEN p_calificacion = 5 THEN 1 ELSE 0 END,
            calificaciones_4_estrellas = calificaciones_4_estrellas + CASE WHEN p_calificacion = 4 THEN 1 ELSE 0 END,
            calificaciones_3_estrellas = calificaciones_3_estrellas + CASE WHEN p_calificacion = 3 THEN 1 ELSE 0 END,
            calificaciones_2_estrellas = calificaciones_2_estrellas + CASE WHEN p_calificacion = 2 THEN 1 ELSE 0 END,
            calificaciones_1_estrella = calificaciones_1_estrella + CASE WHEN p_calificacion = 1 THEN 1 ELSE 0 END,
            ultima_calificacion = NOW(),
            updated_at = NOW()
        WHERE capitan_id = p_capitan_id;
        
        -- Calcular nueva calificación promedio
        SELECT (
            (calificaciones_5_estrellas * 5 + calificaciones_4_estrellas * 4 + 
             calificaciones_3_estrellas * 3 + calificaciones_2_estrellas * 2 + 
             calificaciones_1_estrella * 1) / NULLIF(total_calificaciones, 0)
        )::DECIMAL(3,2) INTO nueva_calificacion
        FROM reputacion_capitanes
        WHERE capitan_id = p_capitan_id;
        
        -- Actualizar calificación promedio
        UPDATE reputacion_capitanes
        SET calificacion_promedio = nueva_calificacion
        WHERE capitan_id = p_capitan_id;
    END IF;
    
    -- Determinar nuevo nivel de reputación
    IF nueva_calificacion >= 4.8 AND reputacion_actual.total_viajes >= 50 THEN
        nuevo_nivel_reputacion := 'elite';
    ELSIF nueva_calificacion >= 4.5 AND reputacion_actual.total_viajes >= 20 THEN
        nuevo_nivel_reputacion := 'experto';
    ELSIF nueva_calificacion >= 4.0 AND reputacion_actual.total_viajes >= 10 THEN
        nuevo_nivel_reputacion := 'intermedio';
    ELSE
        nuevo_nivel_reputacion := 'novato';
    END IF;
    
    -- Actualizar nivel
    UPDATE reputacion_capitanes
    SET nivel_reputacion = nuevo_nivel_reputacion
    WHERE capitan_id = p_capitan_id;
    
    RETURN QUERY 
    SELECT TRUE, 'Reputación actualizada exitosamente', nueva_calificacion, nuevo_nivel_reputacion;
END;
$$ LANGUAGE plpgsql;

-- Vista para cotizaciones con reputación de capitanes
CREATE OR REPLACE VIEW vw_cotizaciones_con_reputacion AS
SELECT 
    c.*,
    rc.calificacion_promedio,
    rc.total_viajes,
    rc.nivel_reputacion,
    rc.viajes_completados,
    rc.total_calificaciones,
    CASE 
        WHEN rc.nivel_reputacion = 'elite' THEN '⭐⭐⭐⭐⭐ Élite'
        WHEN rc.nivel_reputacion = 'experto' THEN '⭐⭐⭐⭐ Experto'
        WHEN rc.nivel_reputacion = 'intermedio' THEN '⭐⭐⭐ Intermedio'
        ELSE '⭐⭐ Novato'
    END as nivel_formateado,
    CASE 
        WHEN rc.nivel_reputacion = 'elite' THEN '#FFD700'
        WHEN rc.nivel_reputacion = 'experto' THEN '#C0C0C0'
        WHEN rc.nivel_reputacion = 'intermedio' THEN '#CD7F32'
        ELSE '#808080'
    END as color_nivel,
    -- Contacto visible solo si está aceptada
    CASE 
        WHEN c.estado IN ('aceptada', 'pagada', 'completado_pendiente_firma', 'liquidado') THEN TRUE
        ELSE FALSE
    END as contacto_visible
FROM cotizaciones c
LEFT JOIN reputacion_capitanes rc ON c.capitan_id = rc.capitan_id
WHERE c.estado IN ('presupuestada', 'aceptada', 'pagada');

-- Función para obtener mensajes de un chat
CREATE OR REPLACE FUNCTION get_mensajes_chat(p_chat_id UUID)
RETURNS TABLE (
    id UUID,
    remitente_id UUID,
    tipo_remitente VARCHAR(20),
    mensaje TEXT,
    mensaje_filtrado TEXT,
    contiene_contacto BOOLEAN,
    bloqueado BOOLEAN,
    motivo_bloqueo TEXT,
    creado_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        mc.id,
        mc.remitente_id,
        mc.tipo_remitente,
        mc.mensaje,
        mc.mensaje_filtrado,
        mc.contiene_contacto,
        mc.bloqueado,
        mc.motivo_bloqueo,
        mc.creado_at
    FROM mensajes_chat mc
    WHERE mc.chat_id = p_chat_id
    ORDER BY mc.creado_at ASC;
END;
$$ LANGUAGE plpgsql;

-- Trigger para crear chat automáticamente cuando se presupuesta una cotización
CREATE OR REPLACE FUNCTION trigger_crear_chat_presupuestado()
RETURNS TRIGGER AS $$
DECLARE
    chat_resultado RECORD;
BEGIN
    -- Crear chat asistido cuando se presupuesta
    SELECT * INTO chat_resultado
    FROM crear_chat_asistido(NEW.id, NEW.pescador_id, NEW.capitan_id);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger
CREATE TRIGGER trigger_crear_chat_presupuestado
    AFTER UPDATE ON cotizaciones
    FOR EACH ROW
    WHEN (OLD.estado != 'presupuestada' AND NEW.estado = 'presupuestada')
    EXECUTE FUNCTION trigger_crear_chat_presupuestado();

-- Crear datos de ejemplo
INSERT INTO reputacion_capitanes (capitan_id, calificacion_promedio, total_viajes, viajes_completados, total_calificaciones, calificaciones_5_estrellas, calificaciones_4_estrellas, nivel_reputacion)
SELECT 
    user_id,
    (random() * 2 + 3)::DECIMAL(3,2), -- Calificación entre 3.0 y 5.0
    (random() * 50 + 10)::INTEGER, -- Viajes entre 10 y 60
    (random() * 45 + 8)::INTEGER, -- Completados entre 8 y 53
    (random() * 30 + 5)::INTEGER, -- Calificaciones entre 5 y 35
    (random() * 20)::INTEGER, -- 5 estrellas
    (random() * 10)::INTEGER, -- 4 estrellas
    (random() * 5)::INTEGER, -- 3 estrellas
    (random() * 3)::INTEGER, -- 2 estrellas
    (random() * 2)::INTEGER, -- 1 estrella
    CASE 
        WHEN (random() * 2 + 3)::DECIMAL(3,2) >= 4.8 AND (random() * 50 + 10)::INTEGER >= 50 THEN 'elite'
        WHEN (random() * 2 + 3)::DECIMAL(3,2) >= 4.5 AND (random() * 50 + 10)::INTEGER >= 20 THEN 'experto'
        WHEN (random() * 2 + 3)::DECIMAL(3,2) >= 4.0 AND (random() * 50 + 10)::INTEGER >= 10 THEN 'intermedio'
        ELSE 'novato'
    END
FROM profiles
WHERE es_capitan = TRUE
LIMIT 10;

-- Políticas de seguridad
CREATE POLICY "Usuarios pueden ver chats donde participan"
ON chats_asistidos FOR SELECT
USING (pescador_id = auth.uid() OR capitan_id = auth.uid());

CREATE POLICY "Usuarios pueden ver sus mensajes"
ON mensajes_chat FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM chats_asistidos ca 
        WHERE ca.id = chat_id 
        AND (ca.pescador_id = auth.uid() OR ca.capitan_id = auth.uid())
    )
);

CREATE POLICY "Usuarios pueden enviar mensajes"
ON mensajes_chat FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM chats_asistidos ca 
        WHERE ca.id = chat_id 
        AND (ca.pescador_id = auth.uid() OR ca.capitan_id = auth.uid())
    )
    AND tipo_remitente IN ('pescador', 'capitan')
);

CREATE POLICY "Usuarios pueden ver reputación de capitanes"
ON reputacion_capitanes FOR SELECT
USING (TRUE);

CREATE POLICY "Usuarios pueden ver cotizaciones con reputación"
ON vw_cotizaciones_con_reputacion FOR SELECT
USING (pescador_id = auth.uid() OR es_capitan = TRUE);
