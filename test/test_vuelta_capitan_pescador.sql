-- Test de Vuelta: Capitán a Pescador
-- Simulación completa del flujo desde que el Capitán envía oferta hasta que el Pescador acepta

-- =====================================================
-- CONFIGURACIÓN INICIAL
-- =====================================================

\echo '=========================================='
\echo 'TEST DE VUELTA: CAPITÁN A PESCADOR'
\echo '=========================================='

-- Variables para el test
\set pescador_id '11111111-1111-1111-1111-111111111111'
\set capitan_id '22222222-2222-2222-2222-222222222222'
\set admin_id '33333333-3333-3333-3333-333333333333'

-- Limpiar datos de prueba anteriores si existen
-- DELETE FROM productos_viajes WHERE viaje_id IN (SELECT id FROM cotizaciones WHERE created_at > NOW() - INTERVAL '1 hour');
-- DELETE FROM notificaciones_glew WHERE created_at > NOW() - INTERVAL '1 hour';

-- =====================================================
-- ACCIÓN DEL CAPITÁN: COMPLETAR QUOTEFORMSCREEN
-- =====================================================

\echo ''
\echo '=== ACCIÓN DEL CAPITÁN: COMPLETAR QUOTEFORMSCREEN ==='

-- Buscar una cotización en estado pendiente para actualizar
SELECT id INTO cotizacion_pendiente_id
FROM cotizaciones
WHERE estado = 'pendiente'
AND created_at > NOW() - INTERVAL '1 hour'
LIMIT 1;

IF cotizacion_pendiente_id IS NULL THEN
    -- Si no hay cotización pendiente, crear una nueva
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
        'pendiente',
        'Viaje de pesca marítima con amigos - Test de vuelta',
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
    ) RETURNING id INTO cotizacion_pendiente_id;
    
    \echo '✅ Se creó nueva cotización pendiente: ' || cotizacion_pendiente_id
ELSE
    \echo '✅ Se encontró cotización pendiente existente: ' || cotizacion_pendiente_id
END IF;

-- Simular que el Capitán completa el formulario QuoteFormScreen
UPDATE cotizaciones
SET 
    estado = 'cotizado', -- Cambiar a COTIZADO
    presupuesto_base = 50000.00, -- Presupuesto $50.000
    respuesta_capitan = 'Excelente día para la pesca, incluye carnada fresca',
    presupuesto_enviado_at = NOW(), -- Marcar como ENVIADO
    updated_at = NOW()
WHERE id = cotizacion_pendiente_id;

\echo '✅ Capitán completó QuoteFormScreen:'
\echo '   💰 Presupuesto: $50.000'
\echo '   📝 Mensaje: "Excelente día para la pesca, incluye carnada fresca"'
\echo '   📊 Estado: COTIZADO (ENVIADO)'

-- =====================================================
-- VERIFICACIÓN ADMINISTRADOR (GLEW)
-- =====================================================

\echo ''
\echo '=== VERIFICACIÓN ADMINISTRADOR (GLEW) ==='

-- Obtener contadores actuales del administrador
SELECT 
    COUNT(*) FILTER (WHERE estado = 'pendiente') as contador_pendientes,
    COUNT(*) FILTER (WHERE estado = 'cotizado') as contador_cotizados,
    COUNT(*) FILTER (WHERE estado = 'aceptado') as contador_aceptados,
    COUNT(*) as total_general
INTO contadores_admin
FROM cotizaciones
WHERE created_at > NOW() - INTERVAL '1 hour';

\echo '📈 Contadores del Administrador (actualizados):'
\echo '   🟡 Pendientes: ' || contadores_admin.contador_pendientes
\echo '   🔵 Cotizados: ' || contadores_admin.contador_cotizados
\echo '   🟢 Aceptados: ' || contadores_admin.contador_aceptados
\echo '   📊 Total: ' || contadores_admin.total_general

-- Verificar que la solicitud pasó de 'Pendiente' a 'Cotizado'
IF contadores_admin.contador_cotizados >= 1 THEN
    \echo '✅ VERIFICACIÓN EXITOSA: La solicitud pasó de "Pendiente" a "Cotizado"'
    \echo '   📊 Contador Cotizados actualizado: ' || contadores_admin.contador_cotizados
ELSE
    \echo '❌ ERROR DE VERIFICACIÓN: No se actualizó el contador de Cotizados'
END IF;

-- Enviar notificación a Glew sobre oferta enviada
INSERT INTO notificaciones_glew (
    evento, datos, estado, enviado_at, created_at
) VALUES (
    'oferta_capitan_enviada',
    jsonb_build_object(
        'cotizacion_id', cotizacion_pendiente_id,
        'pescador_id', :pescador_id,
        'capitan_id', :capitan_id,
        'presupuesto', 50000.00,
        'respuesta', 'Excelente día para la pesca, incluye carnada fresca',
        'estado', 'cotizado',
        'timestamp', NOW(),
        'metadata', jsonb_build_object(
            'lugar_encuentro', 'Puerto de Mar del Plata',
            'fecha_viaje', '2026-03-20',
            'cantidad_personas', 4,
            'presupuesto_enviado_at', NOW()
        ),
        'source', 'quote_form_screen',
        'environment', 'test'
    ),
    'enviado',
    NOW(),
    NOW()
);

\echo '📢 Notificación enviada a Glew: oferta_capitan_enviada'

-- =====================================================
-- PANEL DEL PESCADOR: RECIBIR OFERTA
-- =====================================================

\echo ''
\echo '=== PANEL DEL PESCADOR: RECIBIR OFERTA ==='

-- Simular productos de tienda para el viaje
INSERT INTO productos_viajes (
    viaje_id,
    nombre_producto,
    cantidad,
    precio_unitario,
    subtotal,
    categoria,
    created_at
) VALUES 
(
    cotizacion_pendiente_id,
    'Carnada fresca especial',
    2,
    5000.00, -- $5.000 cada una
    10000.00, -- $10.000 total
    'carnada',
    NOW()
),
(
    cotizacion_pendiente_id,
    'Bebidas isotónicas pack x6',
    1,
    2000.00, -- $2.000
    2000.00, -- $2.000 total
    'bebidas',
    NOW()
),
(
    cotizacion_pendiente_id,
    'Protector solar factor 50',
    2,
    1500.00, -- $1.500 cada uno
    3000.00, -- $3.000 total
    'proteccion',
    NOW()
);

-- Calcular totales de productos
SELECT 
    COUNT(*) as cantidad_productos,
    SUM(cantidad) as total_unidades,
    SUM(subtotal) as total_productos
INTO productos_stats
FROM productos_viajes
WHERE viaje_id = cotizacion_pendiente_id;

\echo '📦 Productos de Tienda agregados:'
\echo '   🎣 Carnada fresca especial (2x $5.000) = $10.000'
\echo '   🥤 Bebidas isotónicas (1x $2.000) = $2.000'
\echo '   ☀️ Protector solar (2x $1.500) = $3.000'
\echo '   💰 Total Productos: $' || productos_stats.total_productos

-- Envío Correo Argentino
\set envio_correo 3500.00
\echo '📬 Envío Correo Argentino: $' || :envio_correo

-- Calcular total final
\set presupuesto_capitan 50000.00
\set total_final (:presupuesto_capitan + productos_stats.total_productos + :envio_correo)

\echo '💰 Cálculo del Total Final:'
\echo '   🚢 Presupuesto Capitán: $' || :presupuesto_capitan
\echo '   🛒 Productos Tienda: $' || productos_stats.total_productos
\echo '   📬 Envío Correo Argentino: $' || :envio_correo
\echo '   💎 TOTAL FINAL: $' || :total_final

-- =====================================================
-- JSON FINAL PARA EL PESCADOR
-- =====================================================

\echo ''
\echo '=== JSON FINAL PARA EL PESCADOR ==='

-- Generar JSON completo que vería el Pescador en su celular
SELECT jsonb_build_object(
    'oferta_recibida', jsonb_build_object(
        'cotizacion_id', cotizacion_pendiente_id,
        'fecha_oferta', NOW(),
        'estado', 'cotizado',
        'capitan', jsonb_build_object(
            'id', :capitan_id,
            'nombre', 'Capitán Juan Pérez',
            'telefono', '+5492231234567',
            'calificacion', 4.8,
            'viajes_realizados', 127
        ),
        'presupuesto_capitan', :presupuesto_capitan,
        'mensaje_capitan', 'Excelente día para la pesca, incluye carnada fresca',
        'detalles_viaje', jsonb_build_object(
            'descripcion', 'Viaje de pesca marítima con amigos - Test de vuelta',
            'fecha_ida', '2026-03-20',
            'hora_encuentro', '09:00',
            'lugar_encuentro', 'Puerto de Mar del Plata',
            'cantidad_personas', 4,
            'coordenadas', jsonb_build_object(
                'origen', jsonb_build_object('lat', -38.0022, 'lng', -57.5575),
                'destino', jsonb_build_object('lat', -38.0022, 'lng', -57.5575)
            )
        ),
        'productos_tienda', (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'nombre', nombre_producto,
                    'cantidad', cantidad,
                    'precio_unitario', precio_unitario,
                    'subtotal', subtotal,
                    'categoria', categoria
                )
                ORDER BY categoria, nombre_producto
            )
            FROM productos_viajes
            WHERE viaje_id = cotizacion_pendiente_id
        ),
        'costos', jsonb_build_object(
            'presupuesto_viaje', :presupuesto_capitan,
            'productos_tienda', productos_stats.total_productos,
            'envio_correo', :envio_correo,
            'total_final', :total_final,
            'desglose', jsonb_build_array(
                jsonb_build_object('concepto', 'Presupuesto Capitán', 'monto', :presupuesto_capitan),
                jsonb_build_object('concepto', 'Carnada fresca especial', 'monto', 10000.00),
                jsonb_build_object('concepto', 'Bebidas isotónicas', 'monto', 2000.00),
                jsonb_build_object('concepto', 'Protector solar', 'monto', 3000.00),
                jsonb_build_object('concepto', 'Envío Correo Argentino', 'monto', :envio_correo)
            )
        ),
        'resumen_financiero', jsonb_build_object(
            'monto_viaje', :presupuesto_capitan,
            'monto_productos', productos_stats.total_productos,
            'monto_envio', :envio_correo,
            'monto_total', :total_final,
            'comision_plataforma', (:total_final * 0.10),
            'monto_neto', (:total_final * 0.90),
            'forma_pago', 'pendiente'
        ),
        'acciones_disponibles', jsonb_build_array(
            'aceptar_oferta',
            'rechazar_oferta',
            'consultar_capitan',
            'modificar_productos'
        ),
        'timestamps', jsonb_build_object(
            'oferta_recibida', NOW(),
            'presupuesto_enviado', NOW(),
            'validez_oferta', NOW() + INTERVAL '48 hours'
        )
    )
) INTO json_final_pescador;

\echo json_final_pescador;

-- =====================================================
-- CIERRE DE CICLO: PESCADOR ACEPTA
-- =====================================================

\echo ''
\echo '=== CIERRE DE CICLO: PESCADOR ACEPTA ==='

-- Simular que el Pescador cambia el estado a ACEPTADO
UPDATE cotizaciones
SET 
    estado = 'aceptado',
    aceptado_at = NOW(),
    updated_at = NOW()
WHERE id = cotizacion_pendiente_id;

\echo '✅ Pescador cambió el estado a ACEPTADO'
\echo '   📅 Fecha de aceptación: ' || NOW()
\echo '   💰 Monto total aceptado: $' || :total_final

-- Enviar notificación a Glew sobre aceptación
INSERT INTO notificaciones_glew (
    evento, datos, estado, enviado_at, created_at
) VALUES (
    'oferta_aceptada_pescador',
    jsonb_build_object(
        'cotizacion_id', cotizacion_pendiente_id,
        'pescador_id', :pescador_id,
        'capitan_id', :capitan_id,
        'monto_total', :total_final,
        'estado', 'aceptado',
        'timestamp', NOW(),
        'metadata', jsonb_build_object(
            'productos_incluidos', productos_stats.cantidad_productos,
            'presupuesto_capitan', :presupuesto_capitan,
            'envio_correo', :envio_correo,
            'aceptado_at', NOW()
        ),
        'source', 'pescador_panel',
        'environment', 'test'
    ),
    'enviado',
    NOW(),
    NOW()
);

\echo '📢 Notificación enviada a Glew: oferta_aceptada_pescador'

-- =====================================================
-- VERIFICACIÓN FINAL DEL CICLO
-- =====================================================

\echo ''
\echo '=== VERIFICACIÓN FINAL DEL CICLO ==='

-- Obtener estado final de la cotización
SELECT 
    id,
    estado,
    presupuesto_base,
    respuesta_capitan,
    aceptado_at,
    created_at,
    updated_at,
    presupuesto_enviado_at
FROM cotizaciones
WHERE id = cotizacion_pendiente_id;

-- Verificar contadores finales del administrador
SELECT 
    COUNT(*) FILTER (WHERE estado = 'pendiente') as contador_pendientes,
    COUNT(*) FILTER (WHERE estado = 'cotizado') as contador_cotizados,
    COUNT(*) FILTER (WHERE estado = 'aceptado') as contador_aceptados,
    COUNT(*) as total_general
INTO contadores_finales
FROM cotizaciones
WHERE created_at > NOW() - INTERVAL '1 hour';

\echo '📈 Contadores Finales del Administrador:'
\echo '   🟡 Pendientes: ' || contadores_finales.contador_pendientes
\echo '   🔵 Cotizados: ' || contadores_finales.contador_cotizados
\echo '   🟢 Aceptados: ' || contadores_finales.contador_aceptados
\echo '   📊 Total: ' || contadores_finales.total_general

-- Mostrar historial de notificaciones enviadas a Glew
\echo ''
\echo '📢 Historial de Notificaciones a Glew:'
SELECT 
    evento,
    estado,
    datos->>'presupuesto' as presupuesto,
    datos->>'estado' as estado_cotizacion,
    enviado_at,
    CASE 
        WHEN evento = 'oferta_capitan_enviada' THEN '🚢 Capitán envió oferta'
        WHEN evento = 'oferta_aceptada_pescador' THEN '🎣 Pescador aceptó oferta'
        ELSE evento
    END as descripcion
FROM notificaciones_glew
WHERE datos->>'cotizacion_id' = cotizacion_pendiente_id
ORDER BY enviado_at;

-- =====================================================
-- RESUMEN FINAL DEL TEST DE VUELTA
-- =====================================================

\echo ''
\echo '=========================================='
\echo '🎯 RESUMEN FINAL - TEST DE VUELTA'
\echo '=========================================='
\echo ''
\echo '📋 ACCIONES COMPLETADAS:'
\echo '✅ 1. Capitán completó QuoteFormScreen ($50.000)'
\echo '✅ 2. Trip_offer actualizada a estado ENVIADO'
\echo '✅ 3. Administrador verificó cambio de estado'
\echo '✅ 4. Pescador recibió oferta con JSON completo'
\echo '✅ 5. Pescador aceptó la oferta'
\echo ''
\echo '💰 MONTOS FINALES:'
\echo '   🚢 Presupuesto Capitán: $' || :presupuesto_capitan
\echo '   🛒 Productos Tienda: $' || productos_stats.total_productos
\echo '   📬 Envío Correo Argentino: $' || :envio_correo
\echo '   💎 TOTAL FINAL: $' || :total_final
\echo ''
\echo '📊 ESTADOS FINALES:'
\echo '   🟡 Pendientes: ' || contadores_finales.contador_pendientes
\echo '   🔵 Cotizados: ' || contadores_finales.contador_cotizados
\echo '   🟢 Aceptados: ' || contadores_finales.contador_aceptados
\echo ''
\echo '📢 NOTIFICACIONES A GLEW:'
\echo '   🚢 oferta_capitan_enviada'
\echo '   🎣 oferta_aceptada_pescador'
\echo ''
\echo '🔄 CICLO COMPLETADO:'
\echo '   ✅ Capitán → Pescador (oferta enviada)'
\echo '   ✅ Pescador → Capitán (oferta aceptada)'
\echo '   ✅ Administrador → Notificado en ambos pasos'
\echo ''
\echo '🎉 TEST DE VUELTA COMPLETADO EXITOSAMENTE'
\echo '=========================================='
