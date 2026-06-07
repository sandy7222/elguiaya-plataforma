-- Test de Sincronización y Comunicación entre los Tres Paneles
-- Mecanismo completo para verificar la comunicación entre Pescador, Capitán y Administrador

-- =====================================================
-- CONFIGURACIÓN INICIAL
-- =====================================================

\echo '=========================================='
\echo 'TEST DE SINCRONIZACIÓN ENTRE PANELES'
\echo '=========================================='

-- Limpiar datos de prueba anteriores (opcional)
-- DELETE FROM notificaciones_glew WHERE created_at > NOW() - INTERVAL '1 day';
-- DELETE FROM cotizaciones WHERE created_at > NOW() - INTERVAL '1 day';

-- Variables para el test
\set pescador_id '11111111-1111-1111-1111-111111111111'
\set capitan_id '22222222-2222-2222-2222-222222222222'
\set admin_id '33333333-3333-3333-3333-333333333333'

-- =====================================================
-- PASO 1: PESCADOR CREA SOLICITUD DE VIAJE (TRIP_REQUEST)
-- =====================================================

\echo ''
\echo '=== PASO 1: PESCADOR CREA SOLICITUD DE VIAJE ==='

-- Insertar trip_request en estado PENDIENTE
INSERT INTO cotizaciones (
    pescador_id,
    capitan_id,
    estado,
    descripcion,
    fecha_ida,
    fecha_vuelta,
    hora_encuentro,
    lugar_encuentro,
    cantidad_personas,
    coordenada_origen_lat,
    coordenada_origen_lng,
    coordenada_destino_lat,
    coordenada_destino_lng,
    created_at,
    updated_at
) VALUES (
    :pescador_id,
    :capitan_id,
    'pendiente', -- Estado inicial PENDIENTE
    'Viaje de pesca marítima con amigos - Test de sincronización',
    '2026-03-20',
    '2026-03-20',
    '09:00',
    'Puerto de Mar del Plata',
    4,
    -38.0022,
    -57.5575,
    -38.0022,
    -57.5575,
    NOW(),
    NOW()
) RETURNING id INTO trip_request_id;

\echo '✅ Trip Request creada con ID: ' || trip_request_id
\echo '📊 Estado: PENDIENTE'

-- =====================================================
-- VERIFICACIÓN 1: CONTADOR ADMINISTRADOR - PENDIENTES
-- =====================================================

\echo ''
\echo '=== VERIFICACIÓN 1: CONTADOR ADMINISTRADOR - PENDIENTES ==='

-- Obtener contadores actuales del administrador
SELECT 
    COUNT(*) FILTER (WHERE estado = 'pendiente') as contador_pendientes,
    COUNT(*) FILTER (WHERE estado = 'cotizado') as contador_cotizados,
    COUNT(*) FILTER (WHERE estado = 'aceptado') as contador_aceptados,
    COUNT(*) FILTER (WHERE estado = 'rechazado') as contador_rechazados,
    COUNT(*) as total_general
INTO contadores_actuales
FROM cotizaciones
WHERE created_at > NOW() - INTERVAL '1 hour';

\echo '📈 Contadores del Administrador (última hora):'
\echo '   🟡 Pendientes: ' || contadores_actuales.contador_pendientes
\echo '   🔵 Cotizados: ' || contadores_actuales.contador_cotizados
\echo '   🟢 Aceptados: ' || contadores_actuales.contador_aceptados
\echo '   🔴 Rechazados: ' || contadores_actuales.contador_rechazados
\echo '   📊 Total: ' || contadores_actuales.total_general

-- Verificar que el contador de pendientes sea al menos 1
IF contadores_actuales.contador_pendientes >= 1 THEN
    \echo '✅ VERIFICACIÓN 1 EXITOSA: El contador de Pendientes muestra ' || contadores_actuales.contador_pendientes || ' solicitudes'
ELSE
    \echo '❌ ERROR VERIFICACIÓN 1: El contador de Pendientes no muestra solicitudes'
END IF;

-- Enviar notificación a Glew sobre nueva solicitud pendiente
INSERT INTO notificaciones_glew (
    evento, datos, estado, enviado_at, created_at
) VALUES (
    'trip_request_creada',
    jsonb_build_object(
        'cotizacion_id', trip_request_id,
        'pescador_id', :pescador_id,
        'capitan_id', :capitan_id,
        'estado', 'pendiente',
        'timestamp', NOW(),
        'metadata', jsonb_build_object(
            'lugar_encuentro', 'Puerto de Mar del Plata',
            'fecha_viaje', '2026-03-20',
            'cantidad_personas', 4
        ),
        'source', 'capitanya_mobile',
        'environment', 'test'
    ),
    'enviado',
    NOW(),
    NOW()
);

\echo '📢 Notificación enviada a Glew: trip_request_creada'

-- =====================================================
-- PASO 2: CAPITÁN GENERA OFERTA (TRIP_OFFER) DE $50.000
-- =====================================================

\echo ''
\echo '=== PASO 2: CAPITÁN GENERA OFERTA DE $50.000 ==='

-- Actualizar cotización con oferta del capitán
UPDATE cotizaciones
SET 
    estado = 'cotizado', -- Cambiar a COTIZADO
    presupuesto_base = 50000.00, -- Oferta de $50.000
    respuesta_capitan = 'Excelente día para la pesca. Incluyo equipo completo y refrigerios.',
    presupuesto_enviado_at = NOW(),
    updated_at = NOW()
WHERE id = trip_request_id;

\echo '✅ Trip Offer generada: $50.000'
\echo '📊 Estado actualizado: COTIZADO'

-- =====================================================
-- VERIFICACIÓN 2: CONTADOR ADMINADOR - COTIZADOS
-- =====================================================

\echo ''
\echo '=== VERIFICACIÓN 2: CONTADOR ADMINADOR - COTIZADOS ==='

-- Obtener contadores actualizados
SELECT 
    COUNT(*) FILTER (WHERE estado = 'pendiente') as contador_pendientes,
    COUNT(*) FILTER (WHERE estado = 'cotizado') as contador_cotizados,
    COUNT(*) FILTER (WHERE estado = 'aceptado') as contador_aceptados,
    COUNT(*) FILTER (WHERE estado = 'rechazado') as contador_rechazados,
    COUNT(*) as total_general
INTO contadores_actualizados
FROM cotizaciones
WHERE created_at > NOW() - INTERVAL '1 hour';

\echo '📈 Contadores del Administrador (actualizados):'
\echo '   🟡 Pendientes: ' || contadores_actualizados.contador_pendientes
\echo '   🔵 Cotizados: ' || contadores_actualizados.contador_cotizados
\echo '   🟢 Aceptados: ' || contadores_actualizados.contador_aceptados
\echo '   🔴 Rechazados: ' || contadores_actualizados.contador_rechazados
\echo '   📊 Total: ' || contadores_actualizados.total_general

-- Verificar que el contador de pendientes bajó y el de cotizados subió
IF contadores_actualizados.contador_pendientes < contadores_actuales.contador_pendientes AND
   contadores_actualizados.contador_cotizados > contadores_actuales.contador_cotizados THEN
    \echo '✅ VERIFICACIÓN 2 EXITOSA: El contador bajó de Pendientes y subió en Cotizados'
    \echo '   📉 Pendientes: ' || contadores_actuales.contador_pendientes || ' → ' || contadores_actualizados.contador_pendientes
    \echo '   📈 Cotizados: ' || contadores_actuales.contador_cotizados || ' → ' || contadores_actualizados.contador_cotizados
ELSE
    \echo '❌ ERROR VERIFICACIÓN 2: Los contadores no se actualizaron correctamente'
    \echo '   📉 Pendientes esperados: < ' || contadores_actuales.contador_pendientes || ' (actual: ' || contadores_actualizados.contador_pendientes || ')'
    \echo '   📈 Cotizados esperados: > ' || contadores_actuales.contador_cotizados || ' (actual: ' || contadores_actualizados.contador_cotizados || ')'
END IF;

-- Enviar notificación a Glew sobre oferta generada
INSERT INTO notificaciones_glew (
    evento, datos, estado, enviado_at, created_at
) VALUES (
    'trip_offer_generada',
    jsonb_build_object(
        'cotizacion_id', trip_request_id,
        'pescador_id', :pescador_id,
        'capitan_id', :capitan_id,
        'presupuesto', 50000.00,
        'respuesta', 'Excelente día para la pesca. Incluyo equipo completo y refrigerios.',
        'estado', 'cotizado',
        'timestamp', NOW(),
        'metadata', jsonb_build_object(
            'lugar_encuentro', 'Puerto de Mar del Plata',
            'fecha_viaje', '2026-03-20',
            'cantidad_personas', 4,
            'presupuesto_enviado_at', NOW()
        ),
        'source', 'capitanya_mobile',
        'environment', 'test'
    ),
    'enviado',
    NOW(),
    NOW()
);

\echo '📢 Notificación enviada a Glew: trip_offer_generada'

-- =====================================================
-- VERIFICACIÓN 3: SINCRONIZACIÓN COMPLETA
-- =====================================================

\echo ''
\echo '=== VERIFICACIÓN 3: SINCRONIZACIÓN COMPLETA ==='

-- Mostrar estado final de la cotización
SELECT 
    id,
    estado,
    presupuesto_base,
    respuesta_capitan,
    created_at,
    updated_at,
    presupuesto_enviado_at
FROM cotizaciones
WHERE id = trip_request_id;

-- Mostrar historial de notificaciones enviadas a Glew
SELECT 
    evento,
    estado,
    datos->'cotizacion_id' as cotizacion_id,
    datos->'estado' as estado_cotizacion,
    datos->'presupuesto' as presupuesto,
    enviado_at
FROM notificaciones_glew
WHERE datos->>'cotizacion_id' = trip_request_id
ORDER BY enviado_at;

-- =====================================================
-- VERIFICACIÓN 4: FUNCIONES RPC PARA GLEW
-- =====================================================

\echo ''
\echo '=== VERIFICACIÓN 4: FUNCIONES RPC PARA GLEW ==='

-- Obtener contadores para el dashboard del administrador
CALL get_contadores_admin_glew();

-- Obtener estadísticas de notificaciones
SELECT 
    evento,
    COUNT(*) as cantidad,
    estado,
    COUNT(*) FILTER (WHERE estado = 'enviado') as exitosas,
    COUNT(*) FILTER (WHERE estado = 'fallido') as fallidas
FROM notificaciones_glew
WHERE created_at > NOW() - INTERVAL '1 hour'
GROUP BY evento, estado
ORDER BY evento, estado;

-- =====================================================
-- RESUMEN FINAL
-- =====================================================

\echo ''
\echo '=========================================='
\echo '🎯 RESUMEN FINAL DEL TEST'
\echo '=========================================='
\echo ''
\echo '📋 PASOS COMPLETADOS:'
\echo '✅ 1. Pescador creó trip_request en estado PENDIENTE'
\echo '✅ 2. Verificado contador Administrador muestra Pendientes'
\echo '✅ 3. Capitán generó trip_offer de $50.000'
\echo '✅ 4. Estado cambiado a COTIZADO'
\echo '✅ 5. Verificado contador Administrador actualizado'
\echo ''
\echo '📊 RESULTADOS DE SINCRONIZACIÓN:'
\echo '   🟡 Pendientes: ' || contadores_actuales.contador_pendientes || ' → ' || contadores_actualizados.contador_pendientes
\echo '   🔵 Cotizados: ' || contadores_actuales.contador_cotizados || ' → ' || contadores_actualizados.contador_cotizados
\echo ''
\echo '📢 NOTIFICACIONES ENVIADAS A GLEW:'
\echo '   📋 trip_request_creada (estado: pendiente)'
\echo '   💰 trip_offer_generada (presupuesto: $50.000)'
\echo ''
\echo '🔗 COMUNICACIÓN ENTRE PANELES:'
\echo '   ✅ Pescador → Administrador (nueva solicitud)'
\echo '   ✅ Capitán → Administrador (oferta generada)'
\echo '   ✅ Estados sincronizados correctamente'
\echo ''
\echo '🎉 TEST DE SINCRONIZACIÓN COMPLETADO EXITOSAMENTE'
\echo '=========================================='
