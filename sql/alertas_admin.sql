-- Crear tabla de alertas para administrador
CREATE TABLE IF NOT EXISTS alertas_admin (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tipo VARCHAR(50) NOT NULL,
    cotizacion_id UUID REFERENCES cotizaciones(id) ON DELETE CASCADE,
    pescador_id UUID REFERENCES profiles(user_id) ON DELETE CASCADE,
    descripcion TEXT NOT NULL,
    datos_adicionales JSONB DEFAULT '{}'::JSONB,
    prioridad VARCHAR(20) DEFAULT 'media',
    leida BOOLEAN DEFAULT FALSE,
    leida_at TIMESTAMP WITH TIME ZONE,
    resuelta BOOLEAN DEFAULT FALSE,
    resuelta_at TIMESTAMP WITH TIME ZONE,
    resuelta_por UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Crear índices para optimización
CREATE INDEX IF NOT EXISTS idx_alertas_admin_tipo ON alertas_admin(tipo);
CREATE INDEX IF NOT EXISTS idx_alertas_admin_cotizacion_id ON alertas_admin(cotizacion_id);
CREATE INDEX IF NOT EXISTS idx_alertas_admin_pescador_id ON alertas_admin(pescador_id);
CREATE INDEX IF NOT EXISTS idx_alertas_admin_prioridad ON alertas_admin(prioridad);
CREATE INDEX IF NOT EXISTS idx_alertas_admin_leida ON alertas_admin(leida);
CREATE INDEX IF NOT EXISTS idx_alertas_admin_created_at ON alertas_admin(created_at);

-- Agregar constraint para prioridad
ALTER TABLE alertas_admin 
ADD CONSTRAINT chk_prioridad 
CHECK (prioridad IN ('baja', 'media', 'alta', 'critica'));

-- Función para enviar notificación Realtime a capitanes filtrados por radio
CREATE OR REPLACE FUNCTION enviar_notificacion_realtime_capitanes(
    p_cotizacion_id UUID,
    p_lat_partida DECIMAL,
    p_lon_partida DECIMAL
)
RETURNS TABLE (
    capitanes_notificados INTEGER,
    notificaciones_enviadas INTEGER,
    detalles_envio JSONB
) AS $$
DECLARE
    capitanes_filtrados RECORD;
    notificaciones_count INTEGER := 0;
    detalles JSONB := '[]'::JSONB;
    hora_actual TIMESTAMP WITH TIME ZONE := NOW();
BEGIN
    -- Obtener capitanes disponibles que cubren el punto de partida
    FOR capitanes_filtrados IN 
        SELECT 
            p.user_id as capitan_id,
            p.telefono_contacto as capitan_nombre,
            (p.centro_operacion_lat_long->>'lat')::DECIMAL as centro_lat,
            (p.centro_operacion_lat_long->>'lon')::DECIMAL as centro_lon,
            COALESCE(p.radio_operacion_km, 25.0) as radio_km,
            distancia_entre_puntos(
                (p.centro_operacion_lat_long->>'lat')::DECIMAL,
                (p.centro_operacion_lat_long->>'lon')::DECIMAL,
                p_lat_partida,
                p_lon_partida
            ) as distancia_km
        FROM profiles p
        WHERE p.es_capitan = TRUE
        AND p.disponible = TRUE
        AND p.centro_operacion_lat_long IS NOT NULL
        AND distancia_entre_puntos(
            (p.centro_operacion_lat_long->>'lat')::DECIMAL,
            (p.centro_operacion_lat_long->>'lon')::DECIMAL,
            p_lat_partida,
            p_lon_partida
        ) <= COALESCE(p.radio_operacion_km, 25.0)
        ORDER BY distancia_km ASC
    LOOP
        -- Crear notificación para cada capitán
        INSERT INTO notificaciones_usuarios (
            user_id,
            tipo,
            titulo,
            mensaje,
            datos_adicionales,
            leida,
            created_at
        ) VALUES (
            capitanes_filtrados.capitan_id,
            'nueva_cotizacion',
            '¡Nueva Solicitud de Viaje!',
            'Un pescador necesita tus servicios para un viaje.',
            jsonb_build_object(
                'cotizacion_id', p_cotizacion_id,
                'lat_partida', p_lat_partida,
                'lon_partida', p_lon_partida,
                'distancia_km', capitanes_filtrados.distancia_km,
                'accion_requerida', 'presupuestar'
            ),
            FALSE,
            hora_actual
        );
        
        notificaciones_count := notificaciones_count + 1;
        
        -- Agregar detalles de envío
        detalles := detalles || jsonb_build_object(
            'capitan_id', capitanes_filtrados.capitan_id,
            'capitan_nombre', capitanes_filtrados.capitan_nombre,
            'distancia_km', capitanes_filtrados.distancia_km,
            'enviado_at', hora_actual
        );
        
        -- Registrar en logs
        INSERT INTO logs_sistema (
            tipo,
            descripcion,
            user_id,
            cotizacion_id,
            datos_adicionales,
            created_at
        ) VALUES (
            'notificacion_realtime_enviada',
            'Notificación Realtime enviada a capitán',
            capitanes_filtrados.capitan_id,
            p_cotizacion_id,
            jsonb_build_object(
                'distancia_km', capitanes_filtrados.distancia_km,
                'enviado_at', hora_actual
            ),
            hora_actual
        );
    END LOOP;
    
    RETURN QUERY 
    SELECT COUNT(*), notificaciones_count, detalles
    FROM jsonb_array_elements(detalles);
END;
$$ LANGUAGE plpgsql;

-- Trigger automático para enviar notificaciones al crear cotización
CREATE OR REPLACE FUNCTION trigger_enviar_notificaciones_cotizacion()
RETURNS TRIGGER AS $$
DECLARE
    cotizacion_creada RECORD;
    lat_partida DECIMAL;
    lon_partida DECIMAL;
BEGIN
    -- Obtener datos de la cotización creada
    SELECT * INTO cotizacion_creada
    FROM cotizaciones
    WHERE id = NEW.id;
    
    -- Extraer coordenadas del punto de partida
    lat_partida := (cotizacion_creada.punto_partida->>'lat')::DECIMAL;
    lon_partida := (cotizacion_creada.punto_partida->>'lon')::DECIMAL;
    
    -- Enviar notificaciones a capitanes filtrados
    PERFORM * FROM enviar_notificacion_realtime_capitanes(NEW.id, lat_partida, lon_partida);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para notificaciones automáticas
CREATE TRIGGER trigger_enviar_notificaciones_cotizacion
    AFTER INSERT ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION trigger_enviar_notificaciones_cotizacion();

-- Función vigilante para cotizaciones pendientes (+15 minutos)
CREATE OR REPLACE FUNCTION vigilante_cotizaciones_pendientes()
RETURNS TABLE (
    cotizaciones_procesadas INTEGER,
    alertas_creadas INTEGER,
    notificaciones_admin_enviadas INTEGER,
    detalles_procesamiento JSONB
) AS $$
DECLARE
    cotizacion_pendiente RECORD;
    minutos_antiguedad INTEGER;
    cotizaciones_count INTEGER := 0;
    alertas_count INTEGER := 0;
    notificaciones_count INTEGER := 0;
    detalles JSONB := '[]'::JSONB;
    hora_actual TIMESTAMP WITH TIME ZONE := NOW();
    
    -- Cursor para cotizaciones pendientes
    cursor_cotizaciones CURSOR FOR 
        SELECT c.*, u.email as pescador_email, u.raw_user_meta_data->>'nombre' as pescador_nombre
        FROM cotizaciones c
        JOIN auth.users u ON c.pescador_id = u.id
        WHERE c.estado = 'solicitada'
        AND c.created_at < hora_actual - INTERVAL '15 minutes'
        AND c.id NOT IN (
            SELECT cotizacion_id FROM alertas_admin 
            WHERE tipo = 'cotizacion_pendiente_larga'
            AND created_at > hora_actual - INTERVAL '24 hours'
        );
BEGIN
    OPEN cursor_cotizaciones;
    
    LOOP
        FETCH cursor_cotizaciones INTO cotizacion_pendiente;
        EXIT WHEN NOT FOUND;
        
        cotizaciones_count := cotizaciones_count + 1;
        minutos_antiguedad := EXTRACT(EPOCH FROM (hora_actual - cotizacion_pendiente.created_at)) / 60;
        
        -- Crear alerta para administrador
        INSERT INTO alertas_admin (
            tipo,
            cotizacion_id,
            pescador_id,
            descripcion,
            datos_adicionales,
            prioridad,
            created_at
        ) VALUES (
            'cotizacion_pendiente_larga',
            cotizacion_pendiente.id,
            cotizacion_pendiente.pescador_id,
            'Cotización pendiente sin respuesta',
            jsonb_build_object(
                'minutos_antiguedad', minutos_antiguedad,
                'pescador_nombre', cotizacion_pendiente.pescador_nombre,
                'pescador_email', cotizacion_pendiente.pescador_email,
                'descripcion', cotizacion_pendiente.descripcion,
                'created_at', cotizacion_pendiente.created_at,
                'urgencia', CASE 
                    WHEN minutos_antiguedad >= 60 THEN 'critica'
                    WHEN minutos_antiguedad >= 30 THEN 'alta'
                    ELSE 'media'
                END
            ),
            CASE 
                WHEN minutos_antiguedad >= 60 THEN 'critica'
                WHEN minutos_antiguedad >= 30 THEN 'alta'
                ELSE 'media'
            END,
            hora_actual
        );
        
        alertas_count := alertas_count + 1;
        
        -- Enviar notificación push al administrador
        INSERT INTO notificaciones_usuarios (
            user_id,
            tipo,
            titulo,
            mensaje,
            datos_adicionales,
            leida,
            created_at
        ) VALUES (
            (SELECT user_id FROM profiles WHERE admin = TRUE LIMIT 1),
            'alerta_admin',
            '⚠️ Cotización Pendiente',
            'Una cotización lleva más de 15 minutos sin respuesta de capitanes.',
            jsonb_build_object(
                'cotizacion_id', cotizacion_pendiente.id,
                'minutos_antiguedad', minutos_antiguedad,
                'pescador_nombre', cotizacion_pendiente.pescador_nombre,
                'accion_requerida', 'revisar_cotizacion'
            ),
            FALSE,
            hora_actual
        );
        
        notificaciones_count := notificaciones_count + 1;
        
        -- Agregar detalles
        detalles := detalles || jsonb_build_object(
            'cotizacion_id', cotizacion_pendiente.id,
            'minutos_antiguedad', minutos_antiguedad,
            'prioridad', CASE 
                WHEN minutos_antiguedad >= 60 THEN 'critica'
                WHEN minutos_antiguedad >= 30 THEN 'alta'
                ELSE 'media'
            END,
            'alerta_creada', hora_actual
        );
        
        -- Registrar en logs
        INSERT INTO logs_sistema (
            tipo,
            descripcion,
            cotizacion_id,
            datos_adicionales,
            created_at
        ) VALUES (
            'cotizacion_pendiente_detectada',
            'Vigilante detectó cotización pendiente larga',
            cotizacion_pendiente.id,
            jsonb_build_object(
                'minutos_antiguedad', minutos_antiguedad,
                'alerta_admin_creada', TRUE,
                'notificacion_admin_enviada', TRUE,
                'timestamp', hora_actual
            ),
            hora_actual
        );
    END LOOP;
    
    CLOSE cursor_cotizaciones;
    
    RETURN QUERY 
    SELECT cotizaciones_count, alertas_count, notificaciones_count, detalles;
END;
$$ LANGUAGE plpgsql;

-- Función para vincular cotización aceptada con manifiesto
CREATE OR REPLACE FUNCTION vincular_cotizacion_con_manifiesto(p_cotizacion_id UUID)
RETURNS TABLE (
    exito BOOLEAN,
    mensaje TEXT,
    manifiesto_id UUID,
    pasajeros_creados INTEGER
) AS $$
DECLARE
    cotizacion_aceptada RECORD;
    pedido_existente RECORD;
    manifiesto_id UUID;
    pasajeros_count INTEGER := 0;
    pasajero_data JSONB;
BEGIN
    -- Obtener datos de la cotización aceptada
    SELECT c.*, p.* INTO cotizacion_aceptada
    FROM cotizaciones c
    LEFT JOIN pedidos p ON c.id = p.cotizacion_id
    WHERE c.id = p_cotizacion_id
    AND c.estado = 'aceptada';
    
    IF cotizacion_aceptada IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Cotización no encontrada o no está aceptada', NULL, 0;
        RETURN;
    END IF;
    
    -- Verificar si ya existe un manifiesto para esta cotización
    SELECT * INTO pedido_existente
    FROM manifiesto_pasajeros
    WHERE cotizacion_id = p_cotizacion_id
    LIMIT 1;
    
    IF pedido_existente IS NOT NULL THEN
        RETURN QUERY SELECT TRUE, 'Manifiesto ya existe para esta cotización', pedido_existente.id, 0;
        RETURN;
    END IF;
    
    -- Crear manifiesto principal
    INSERT INTO manifiesto_pasajeros (
        cotizacion_id,
        capitan_id,
        fecha_salida,
        fecha_regreso,
        hora_encuentro,
        lugar_encuentro,
        estado,
        created_at
    ) VALUES (
        p_cotizacion_id,
        cotizacion_aceptada.capitan_id,
        cotizacion_aceptada.fecha_ida,
        cotizacion_aceptada.fecha_vuelta,
        cotizacion_aceptada.hora_encuentro,
        cotizacion_aceptada.lugar_encuentro,
        'preparado',
        NOW()
    )
    RETURNING id INTO manifiesto_id;
    
    -- Crear registros de pasajeros precargados
    FOR i IN 1..cotizacion_aceptada.cantidad_personas LOOP
        -- Datos del pasajero (pueden ser actualizados después)
        pasajero_data := jsonb_build_object(
            'nombre', 'Pasajero ' || i,
            'dni', 'Pendiente',
            'telefono', 'Pendiente',
            'email', 'Pendiente',
            'precargado', TRUE,
            'posicion', i
        );
        
        INSERT INTO manifiesto_pasajeros (
            cotizacion_id,
            capitan_id,
            nombre_pasajero,
            dni_pasajero,
            telefono_pasajero,
            email_pasajero,
            fecha_salida,
            fecha_regreso,
            hora_encuentro,
            lugar_encuentro,
            estado,
            datos_adicionales,
            created_at
        ) VALUES (
            p_cotizacion_id,
            cotizacion_aceptada.capitan_id,
            'Pasajero ' || i,
            'Pendiente',
            'Pendiente',
            'Pendiente',
            cotizacion_aceptada.fecha_ida,
            cotizacion_aceptada.fecha_vuelta,
            cotizacion_aceptada.hora_encuentro,
            cotizacion_aceptada.lugar_encuentro,
            'preparado',
            pasajero_data,
            NOW()
        );
        
        pasajeros_count := pasajeros_count + 1;
    END LOOP;
    
    -- Actualizar estado del manifiesto principal
    UPDATE manifiesto_pasajeros
    SET 
        total_pasajeros = pasajeros_count,
        datos_adicionales = jsonb_set(
            datos_adicionales,
            '{pasajeros_precargados}',
            pasajeros_count::TEXT::JSONB
        ),
        updated_at = NOW()
    WHERE id = manifiesto_id;
    
    -- Registrar en logs
    INSERT INTO logs_sistema (
        tipo,
        descripcion,
        cotizacion_id,
        datos_adicionales,
        created_at
    ) VALUES (
            'manifiesto_vinculado',
            'Manifiesto vinculado automáticamente a cotización aceptada',
            p_cotizacion_id,
            jsonb_build_object(
                'manifiesto_id', manifiesto_id,
                'pasajeros_creados', pasajeros_count,
                'capitan_id', cotizacion_aceptada.capitan_id,
                'fecha_salida', cotizacion_aceptada.fecha_ida,
                'fecha_regreso', cotizacion_aceptada.fecha_vuelta,
                'timestamp', NOW()
            ),
            NOW()
    );
    
    -- Notificar al capitán
    INSERT INTO notificaciones_usuarios (
        user_id,
        tipo,
        titulo,
        mensaje,
        datos_adicionales,
        leida,
        created_at
    ) VALUES (
        cotizacion_aceptada.capitan_id,
        'manifiesto_preparado',
        '📋 Manifiesto Preparado',
        'Se ha preparado un manifiesto con los datos de tu cotización aceptada.',
        jsonb_build_object(
            'manifiesto_id', manifiesto_id,
            'cotizacion_id', p_cotizacion_id,
            'total_pasajeros', pasajeros_count,
            'accion_requerida', 'completar_datos_pasajeros'
        ),
        FALSE,
        NOW()
    );
    
    RETURN QUERY 
    SELECT TRUE, 'Manifiesto vinculado exitosamente', manifiesto_id, pasajeros_count;
END;
$$ LANGUAGE plpgsql;

-- Trigger automático para vincular cotización aceptada con manifiesto
CREATE OR REPLACE FUNCTION trigger_vincular_cotizacion_aceptada()
RETURNS TRIGGER AS $$
DECLARE
    resultado_vinculacion RECORD;
BEGIN
    -- Solo vincular si el estado cambia a 'aceptada'
    IF OLD.estado != 'aceptada' AND NEW.estado = 'aceptada' THEN
        -- Vincular con manifiesto
        SELECT * INTO resultado_vinculacion
        FROM vincular_cotizacion_con_manifiesto(NEW.id);
        
        -- Si no se pudo vincular, registrar en logs
        IF resultado_vinculacion.exito = FALSE THEN
            INSERT INTO logs_sistema (
                tipo,
                descripcion,
                cotizacion_id,
                datos_adicionales,
                created_at
            ) VALUES (
                'error_vinculacion_manifiesto',
                'Error al vincular cotización con manifiesto',
                NEW.id,
                jsonb_build_object(
                    'mensaje', resultado_vinculacion.mensaje,
                    'timestamp', NOW()
                ),
                NOW()
            );
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear trigger para vinculación automática
CREATE TRIGGER trigger_vincular_cotizacion_aceptada
    AFTER UPDATE ON cotizaciones
    FOR EACH ROW
    EXECUTE FUNCTION trigger_vincular_cotizacion_aceptada();

-- Vista para Monitor de Administrador con estadísticas completas
CREATE OR REPLACE VIEW vw_monitor_admin AS
SELECT 
    -- Estadísticas del día
    (SELECT COUNT(*) FROM cotizaciones WHERE DATE(created_at) = CURRENT_DATE) as cotizaciones_hoy,
    (SELECT COUNT(*) FROM cotizaciones WHERE estado = 'solicitada' AND DATE(created_at) = CURRENT_DATE) as cotizaciones_pendientes_hoy,
    (SELECT COUNT(*) FROM cotizaciones WHERE estado = 'presupuestada' AND DATE(created_at) = CURRENT_DATE) as cotizaciones_presupuestadas_hoy,
    (SELECT COUNT(*) FROM cotizaciones WHERE estado = 'aceptada' AND DATE(created_at) = CURRENT_DATE) as cotizaciones_aceptadas_hoy,
    
    -- Tiempo promedio de respuesta de capitanes
    COALESCE(
        (SELECT AVG(EXTRACT(EPOCH FROM (presupuesto_at - created_at)) / 60)::INTEGER
         FROM cotizaciones 
         WHERE estado IN ('presupuestada', 'aceptada') 
         AND presupuesto_at IS NOT NULL
         AND DATE(created_at) = CURRENT_DATE), 0
    ) as tiempo_promedio_respuesta_minutos,
    
    -- Estadísticas de capitanes activos
    (SELECT COUNT(*) FROM profiles WHERE es_capitan = TRUE AND disponible = TRUE) as capitanes_activos,
    (SELECT COUNT(*) FROM profiles WHERE es_capitan = TRUE AND disponible = FALSE) as capitanes_en_descanso,
    (SELECT COUNT(*) FROM profiles WHERE es_capitan = TRUE) as total_capitanes,
    
    -- Alertas del administrador
    (SELECT COUNT(*) FROM alertas_admin WHERE leida = FALSE) as alertas_pendientes,
    (SELECT COUNT(*) FROM alertas_admin WHERE prioridad = 'critica' AND leida = FALSE) as alertas_criticas,
    (SELECT COUNT(*) FROM alertas_admin WHERE tipo = 'cotizacion_pendiente_larga' AND leida = FALSE) as cotizaciones_pendientes_largas,
    
    -- Estadísticas de manifiestos
    (SELECT COUNT(*) FROM manifiesto_pasajeros WHERE DATE(created_at) = CURRENT_DATE) as manifiestos_hoy,
    (SELECT COUNT(*) FROM manifiesto_pasajeros WHERE estado = 'preparado') as manifiestos_preparados,
    (SELECT COUNT(*) FROM manifiesto_pasajeros WHERE estado = 'completado') as manifiestos_completados,
    
    -- Métricas de rendimiento
    COALESCE(
        (SELECT (COUNT(*) FILTER (WHERE estado = 'aceptada') * 100.0 / NULLIF(COUNT(*), 0))::DECIMAL(5,2)
         FROM cotizaciones 
         WHERE DATE(created_at) = CURRENT_DATE), 0
    ) as tasa_conversion_porcentaje,
    
    COALESCE(
        (SELECT AVG(total) FROM pedidos WHERE DATE(created_at) = CURRENT_DATE), 0
    ) as monto_promedio_viajes,
    
    -- Timestamp de última actualización
    NOW() as ultima_actualizacion;

-- Función para obtener estadísticas detalladas del Monitor de Administrador
CREATE OR REPLACE FUNCTION get_monitor_admin_detalles()
RETURNS TABLE (
    cotizaciones_hoy INTEGER,
    cotizaciones_pendientes_hoy INTEGER,
    cotizaciones_presupuestadas_hoy INTEGER,
    cotizaciones_aceptadas_hoy INTEGER,
    tiempo_promedio_respuesta_minutos INTEGER,
    capitanes_activos INTEGER,
    capitanes_en_descanso INTEGER,
    total_capitanes INTEGER,
    alertas_pendientes INTEGER,
    alertas_criticas INTEGER,
    cotizaciones_pendientes_largas INTEGER,
    manifiestos_hoy INTEGER,
    manifiestos_preparados INTEGER,
    manifiestos_completados INTEGER,
    tasa_conversion_porcentaje DECIMAL,
    monto_promedio_viajes DECIMAL,
    ultima_actualizacion TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM vw_monitor_admin;
END;
$$ LANGUAGE plpgsql;

-- Función para ejecutar el vigilante de cotizaciones pendientes
CREATE OR REPLACE FUNCTION ejecutar_vigilante_cotizaciones()
RETURNS TABLE (
    cotizaciones_procesadas INTEGER,
    alertas_creadas INTEGER,
    notificaciones_admin_enviadas INTEGER,
    detalles_procesamiento JSONB
) AS $$
BEGIN
    RETURN QUERY SELECT * FROM vigilante_cotizaciones_pendientes();
END;
$$ LANGUAGE plpgsql;

-- Crear algunas alertas de ejemplo
INSERT INTO alertas_admin (
    tipo,
    descripcion,
    datos_adicionales,
    prioridad,
    created_at
) VALUES 
('sistema', 'Sistema de alertas administrador activado', '{"version": "1.0"}', 'baja', NOW()),
('info', 'Monitor de cotizaciones funcionando', '{"estado": "activo"}', 'media', NOW());

-- Actualizar algunas cotizaciones de ejemplo para pruebas
UPDATE cotizaciones 
SET estado = 'aceptada', presupuesto_at = NOW() - INTERVAL '30 minutes'
WHERE estado = 'presupuestada'
LIMIT 3;

-- Crear cotizaciones pendientes largas para pruebas
INSERT INTO cotizaciones (
    pescador_id, descripcion, punto_partida, punto_destino, estado, created_at
) VALUES 
('11111111-1111-1111-1111-111111111111', 'Viaje de prueba antiguo', 
 '{"lat": -34.6037, "lon": -58.3816}', '{"lat": -34.9011, "lon": -57.9230}', 
'solicitada', NOW() - INTERVAL '20 minutes');

-- Políticas de seguridad para alertas administrador
CREATE POLICY "Admin puede ver alertas"
ON alertas_admin FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede actualizar alertas"
ON alertas_admin FOR UPDATE
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

CREATE POLICY "Admin puede crear alertas"
ON alertas_admin FOR INSERT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));

-- Políticas de seguridad para vista de monitor
CREATE POLICY "Admin puede ver monitor"
ON vw_monitor_admin FOR SELECT
USING (EXISTS (
    SELECT 1 FROM profiles 
    WHERE user_id = auth.uid() 
    AND admin = TRUE
));
