# Plan del día del viaje (borrador, 2026-10-08)

> Un día entero dedicado a perfeccionar la experiencia del viaje, con el celular por cable USB (como hicimos con el asistente): el dueño usa la app, la IA mira el
> registro y la memoria en vivo, mide, arregla y vuelve a probar. Este plan es **borrador**: lo ajusta el dueño antes de arrancar.

## Qué es "el viaje" en la app (mapa del recorrido, sacado del código)

| Paso | Quién | Pantallas | Servicio / función |
|---|---|---|---|
| 1. Pedir cotización | Pescador | `cotizaciones_formulario_screen` | cotizaciones |
| 2. Ver cotizaciones y elegir | Pescador | `cotizacion_screen`, `directorio_capitanes_screen` | — |
| 3. Enviar presupuesto | Capitán | `cotizaciones_capitan_screen`, `inbox_capitan_screen` | `ViajeLifecycleService.enviarPresupuesto` |
| 4. Aceptar presupuesto (nace el pedido) | Pescador | `resumen_reserva_screen` | `aceptarPresupuesto` (crea el pedido con `pescador_id`) |
| 5. Pagar | Pescador | `checkout_*`, `smart_checkout_screen`, `hybrid_checkout_screen` | `crear-preferencia` → Mercado Pago → `confirmarPagoPedido` |
| 6. Viaje confirmado y contacto habilitado | Ambos | `viaje_confirmado_screen`, `chat_*` | `liberar contacto` |
| 7. Iniciar el viaje y seguimiento | Capitán | `capitan_tracker_screen`, `viajes_programados_screen` | `iniciarViaje`, `viaje_tracking_service` (track_log) |
| 8. Finalizar y confirmar retorno | Capitán / pescador | `capitan_panel_screen`, `mis_viajes_screen` | `finalizarViaje`, retorno |
| 9. Calificar | Ambos | — | `calificarPescador`, `calificarCapitan` |
| 10. Cierre y cobro del capitán | Capitán / admin | `billetera_capitan_screen`, `capitan_saldos_screen`, `admin_detalle_viaje_screen` | `cerrarViaje`, acreditación |

## Dos roles a la vez (idea del dueño)

El dueño hace de **cliente** y la IA de **capitán**, y después se invierten. Es posible: un rol en el celular por cable USB (la IA toca, escribe y captura pantalla vía adb y mira el registro) y el
otro en `app.elguiaya.com` en la computadora (la IA lo maneja con el navegador integrado, o lo maneja el dueño). Reglas que no se saltan: **el dueño inicia sesión y crea las cuentas** (la IA no
escribe contraseñas ni crea cuentas); **la IA no paga** ni acepta condiciones de pago; con "No molestar" en el celular para que no se vean notificaciones de otras apps (la IA no las lee). Los viajes
de prueba quedan en la base real: usar nombres reconocibles ("Viaje de prueba 1") y limpiarlos después con OK del dueño. Lo que solo existe en el APK (seguimiento por GPS, push) se prueba en el celular.

## Antes de arrancar el día (lo prepara el dueño)

1. **Dos cuentas de prueba**, una de pescador y una de capitán (si no hay, crearlas; las contraseñas las escribe el dueño en el celular, nunca en el chat).
2. **Mercado Pago está en producción: no hacer pagos reales.** Decidir una de dos: (a) pasar a modo prueba (sandbox) con credenciales de prueba, o (b) probar todo menos el pago y simular la confirmación con el administrador.
3. **Dos celulares si se puede** (uno para cada rol); si hay uno solo, se alternan las sesiones y yo miro el registro del que está por cable.
4. Un **APK de prueba** hecho ese día con `DIAG_MEM=true` (lo compilo yo) y el cable USB con la depuración autorizada.
5. Decidir el **orden de prioridad**: qué dolor es el más grande para los usuarios reales (¿pedir cotización? ¿pagar? ¿el seguimiento?).

## Cómo se trabaja ese día (el método que ya funcionó)

- **Una pantalla o paso por vez.** El dueño hace el recorrido; yo miro `logcat` (errores, tiempos, excepciones) y la memoria en vivo.
- **Medir antes de arreglar:** tiempo de cada pantalla, errores en el registro, cantidad de toques para completar el paso, memoria.
- **Test primero** donde se pueda (lógica de estados, permisos de la base), y arreglo después. Cada arreglo, un commit chico y reversible.
- **Prueba de permisos:** en la base, cada paso se prueba con el rol que corresponde (pescador, capitán, administrador) y con una persona ajena, como hicimos con las migraciones de seguridad.
- Al final del día: informe con lo medido, lo arreglado y lo que quedó, y `docs/ESTADO.md` al día.

## Ya sabemos (pendientes que entran al día)

- **Seguridad de pagos:** hoy la app del cliente marca el pedido como pagado (`confirmarPagoPedido`) y el webhook de Mercado Pago nunca procesó nada (`webhook_logs` vacío).
  Cerrarlo es el punto más importante de la parte de pagos: mover la confirmación al servidor.
- **Cambios de permisos del 7–8 de octubre** (pedidos, ítems, pagos, direcciones, productos): confirmar en la app real que ningún paso del viaje se rompió.
- **Pedido sin `usuario_id`:** los viajes se crean con `pescador_id`; revisar que las pantallas que filtran por `usuario_id` los encuentren.
- **Código muerto en `pago_service.dart`:** guarda pagos con una columna que no existe (`cliente_id` en `pagos`).
- **Errores de columnas:** el registro mostró `Could not find the 'referido' column of 'pescadores'` (código que escribe una columna inexistente).
- **Posible punto frágil:** el asistente flotante y el chat usan el mismo router; verificar que durante el viaje el Guía no interrumpa pantallas críticas (pago, seguimiento).

## Qué medimos para saber si mejoró

- Tiempo desde "quiero un viaje" hasta "presupuesto recibido".
- Toques y pantallas hasta pagar (en sandbox).
- Errores en el registro por recorrido (meta: cero excepciones no controladas).
- Memoria y cierres de la app durante un viaje largo con seguimiento (meta: sin cierres, por debajo de 400 MB).
- Batería del seguimiento: consumo en 30 minutos de viaje con la pantalla apagada.

## Entregables del día

1. Recorrido completo probado por cable, con el registro guardado.
2. Lista de problemas encontrados, ordenada por gravedad, y lo arreglado (commits).
3. Informe corto en `docs/` y `docs/ESTADO.md` actualizado.
4. Lista de lo que queda para el siguiente día.
