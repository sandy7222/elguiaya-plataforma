import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔔 HELPER CENTRALIZADO DE NOTIFICACIONES
///
/// Todas las notificaciones de la app pasan por aquí.
/// Escribe en:
///   - notificaciones_globales (campanita moderna + activa el trigger de push)
///   - notificaciones (tabla legacy para la campana visual)
///
/// El trigger de BD dispara send-push-notification automáticamente al INSERT.
/// Este helper también llama a send-push-notification como segunda capa de
/// garantía, en caso de que el trigger falle o haya latencia.
class NotificacionHelper {
  static final _supabase = Supabase.instance.client;

  /// Envía una notificación in-app (campanita) + push FCM real a un usuario.
  /// El push FCM se dispara automáticamente via trigger de BD al INSERT en
  /// notificaciones_globales → Edge Function send-push-notification.
  static Future<void> enviar({
    required String usuarioId,
    required String titulo,
    required String mensaje,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 1. Categorizar
      String categoriaNueva = 'informativa';
      if (tipo == 'viaje' || tipo == 'cotizacion' || tipo == 'pago' || tipo.startsWith('viaje_') || tipo.startsWith('presupuesto_') || tipo.startsWith('pago_')) {
        categoriaNueva = 'comercial';
      } else if (tipo == 'fraude' || tipo == 'disputa') {
        categoriaNueva = 'seguridad';
      } else if (tipo == 'sistema') {
        categoriaNueva = 'logistica';
      }

      // 2. Escribir en notificaciones_globales
      //    → activa automáticamente trg_push_notificaciones_globales
      //      que llama a send-push-notification (push FCM).
      await _supabase.from('notificaciones_globales').insert({
        'receptor_id': usuarioId,
        'tipo_actor': 'sistema',
        'categoria': categoriaNueva,
        'prioridad': 'informativa',
        'titulo': titulo,
        'contenido': mensaje,
        'leido': false,
        'payload': metadata ?? {},
      });

      // 3. Escribir en la tabla legada 'notificaciones' (campana visual legacy)
      await _supabase.from('notificaciones').insert({
        'usuario_id': usuarioId,
        'titulo': titulo,
        'mensaje': mensaje,
        'tipo': tipo,
        'leida': false,
        'created_at': DateTime.now().toIso8601String(),
        if (metadata != null) 'metadata': metadata,
      });
    } catch (e) {
      // Las notificaciones nunca deben romper el flujo principal
      print('⚠️ [NotificacionHelper] Error enviando notificación ($tipo): $e');
    }
  }

  /// Envía la misma notificación a múltiples usuarios (Broadcast).
  /// El push FCM se dispara automáticamente via trigger de BD por cada INSERT.
  static Future<void> enviarAVarios({
    required List<String> usuarioIds,
    required String titulo,
    required String mensaje,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    final ahora = DateTime.now().toIso8601String();
    final validIds = usuarioIds.where((id) => id.isNotEmpty).toList();
    if (validIds.isEmpty) return;

    try {
      // 1. Categorizar
      String categoriaNueva = 'informativa';
      if (tipo == 'viaje' || tipo == 'cotizacion' || tipo == 'pago' || tipo.startsWith('viaje_') || tipo.startsWith('presupuesto_') || tipo.startsWith('pago_')) {
        categoriaNueva = 'comercial';
      } else if (tipo == 'fraude' || tipo == 'disputa') {
        categoriaNueva = 'seguridad';
      } else if (tipo == 'sistema') {
        categoriaNueva = 'logistica';
      }

      // 2. notificaciones_globales (el trigger dispara push FCM por cada INSERT)
      final loteGlobal = validIds.map((id) => {
        'receptor_id': id,
        'tipo_actor': 'sistema',
        'categoria': categoriaNueva,
        'prioridad': 'informativa',
        'titulo': titulo,
        'contenido': mensaje,
        'leido': false,
        'payload': metadata ?? {},
      }).toList();

      await _supabase.from('notificaciones_globales').insert(loteGlobal);

      // 3. Tabla legacy
      final registros = validIds
          .map((id) => {
                'usuario_id': id,
                'titulo': titulo,
                'mensaje': mensaje,
                'tipo': tipo,
                'leida': false,
                'created_at': ahora,
                if (metadata != null) 'metadata': metadata,
              })
          .toList();

      await _supabase.from('notificaciones').insert(registros);
    } catch (e) {
      print('⚠️ [NotificacionHelper] Error enviando notificación masiva ($tipo): $e');
    }
  }

  // ── Helpers semánticos por evento ──────────────────────────────────────────

  static Future<void> viajeIniciado(String pescadorId, String pedidoId) async {
    final codigo = _codigo(pedidoId);
    await enviar(
      usuarioId: pescadorId,
      titulo: '⛵ ¡Tu Viaje ha Comenzado!',
      mensaje: 'El capitán activó el viaje $codigo. ¡Buen viento y buena pesca!',
      tipo: 'viaje_iniciado',
      metadata: {'pedido_id': pedidoId},
    );
  }

  static Future<void> viajeFinalizado(String pescadorId, String pedidoId) async {
    final codigo = _codigo(pedidoId);
    await enviar(
      usuarioId: pescadorId,
      titulo: '✅ ¡Viaje Finalizado! Calificá tu Experiencia',
      mensaje: 'El capitán finalizó el viaje $codigo. Confirmá y calificá tu experiencia.',
      tipo: 'viaje_finalizado',
      metadata: {'pedido_id': pedidoId},
    );
  }

  static Future<void> viajeConfirmado(String capitanId, String pedidoId, double monto) async {
    await enviar(
      usuarioId: capitanId,
      titulo: '⚓ ¡Viaje Confirmado!',
      mensaje: 'El pescador aceptó tu cotización de \$$monto. ¡Preparate para zarpar!',
      tipo: 'viaje_confirmado',
      metadata: {'pedido_id': pedidoId, 'monto': monto},
    );
  }

  static Future<void> viajeConfirmadoConDatos(
    String capitanId,
    String pedidoId,
    double monto,
    String nombrePescador,
    int cantidadPersonas,
  ) async {
    final personas = cantidadPersonas == 1 ? '1 persona' : '$cantidadPersonas personas';
    await enviar(
      usuarioId: capitanId,
      titulo: '⚓ ¡Viaje Confirmado!',
      mensaje: '$nombrePescador aceptó tu cotización de \$$monto · $personas en total. ¡Preparate para zarpar!',
      tipo: 'viaje_confirmado',
      metadata: {
        'pedido_id': pedidoId,
        'monto': monto,
        'nombre_pescador': nombrePescador,
        'cantidad_personas': cantidadPersonas,
      },
    );
  }

  static Future<void> presupuestoRecibido(
      String pescadorId, String cotizacionId, double monto, String descripcion) async {
    await enviar(
      usuarioId: pescadorId,
      titulo: '💵 ¡Nuevo Presupuesto Recibido!',
      mensaje: 'Un capitán cotizó tu salida "$descripcion" por \$$monto.',
      tipo: 'presupuesto_recibido',
      metadata: {'cotizacion_id': cotizacionId, 'monto': monto},
    );
  }

  static Future<void> calificacionRecibidaCapitan(
      String capitanId, String pedidoId, int estrellas) async {
    final codigo = _codigo(pedidoId);
    await enviar(
      usuarioId: capitanId,
      titulo: '⭐ Calificación Recibida',
      mensaje: 'El pescador te calificó con $estrellas/5 anclas en el viaje $codigo.',
      tipo: 'calificacion_recibida',
      metadata: {'pedido_id': pedidoId, 'estrellas': estrellas},
    );
  }

  static Future<void> calificacionRecibidaPescador(
      String pescadorId, String pedidoId, int estrellas) async {
    final codigo = _codigo(pedidoId);
    await enviar(
      usuarioId: pescadorId,
      titulo: '⭐ El Capitán te Calificó',
      mensaje: 'Recibiste $estrellas/5 anclas en el viaje $codigo.',
      tipo: 'calificacion_recibida',
      metadata: {'pedido_id': pedidoId, 'estrellas': estrellas},
    );
  }

  static Future<void> viajeCerrado(
      String pescadorId, String capitanId, String pedidoId) async {
    final codigo = _codigo(pedidoId);
    await enviarAVarios(
      usuarioIds: [pescadorId, capitanId],
      titulo: '🔒 Viaje Cerrado',
      mensaje: 'El viaje $codigo quedó cerrado. ¡Gracias por usar El Guia YA!',
      tipo: 'viaje_cerrado',
      metadata: {'pedido_id': pedidoId},
    );
  }

  static Future<void> viajeCancelado(
      String destinatarioId, String pedidoId, String quienCancelo) async {
    final codigo = _codigo(pedidoId);
    await enviar(
      usuarioId: destinatarioId,
      titulo: '❌ Viaje Cancelado',
      mensaje: '$quienCancelo canceló el viaje $codigo.',
      tipo: 'viaje_cancelado',
      metadata: {'pedido_id': pedidoId},
    );
  }

  static Future<void> pagoConfirmado(
      String pescadorId, String capitanId, String pedidoId, double monto) async {
    final codigo = _codigo(pedidoId);
    await enviarAVarios(
      usuarioIds: [pescadorId, capitanId],
      titulo: '💳 Pago Confirmado',
      mensaje: 'El pago de \$$monto para el viaje $codigo fue confirmado.',
      tipo: 'pago_confirmado',
      metadata: {'pedido_id': pedidoId, 'monto': monto},
    );
  }

  // ── Notificaciones de pedidos de tienda (Fase 1 / 4) ───────────────────────

  static Future<void> pedidoTiendaConfirmado(
    String compradorId,
    String pedidoId,
    String? numeroPedido,
  ) async {
    final codigo = numeroPedido ?? _codigo(pedidoId);
    await enviar(
      usuarioId: compradorId,
      titulo: '✅ ¡Compra Confirmada!',
      mensaje: 'Tu pedido $codigo fue pagado y ya está en preparación para el despacho.',
      tipo: 'pedido_tienda_confirmado',
      metadata: {'pedido_id': pedidoId, 'numero_pedido': numeroPedido, 'es_pedido_tienda': true},
    );
  }

  static Future<void> pedidoDespachado(
    String compradorId,
    String pedidoId,
    String? numeroPedido, {
    String? trackingCodigo,
    String? trackingTransportista,
  }) async {
    final codigo = numeroPedido ?? _codigo(pedidoId);
    final detalleTracking = trackingCodigo != null && trackingCodigo.isNotEmpty
        ? ' Seguimiento: $trackingCodigo${trackingTransportista != null && trackingTransportista.isNotEmpty ? ' ($trackingTransportista)' : ''}.'
        : '';
    await enviar(
      usuarioId: compradorId,
      titulo: '📦 ¡Tu pedido fue despachado!',
      mensaje: 'Tu pedido $codigo salió hacia tu domicilio.$detalleTracking',
      tipo: 'pedido_tienda_despachado',
      metadata: {
        'pedido_id': pedidoId,
        'numero_pedido': numeroPedido,
        'tracking_codigo': trackingCodigo,
        'tracking_transportista': trackingTransportista,
        'es_pedido_tienda': true,
      },
    );
  }

  static Future<void> pedidoEntregado(
    String compradorId,
    String pedidoId,
    String? numeroPedido,
  ) async {
    final codigo = numeroPedido ?? _codigo(pedidoId);
    await enviar(
      usuarioId: compradorId,
      titulo: '🎉 ¡Pedido Entregado!',
      mensaje: 'Tu pedido $codigo fue entregado. ¡Gracias por tu compra en El Guia YA!',
      tipo: 'pedido_tienda_entregado',
      metadata: {'pedido_id': pedidoId, 'numero_pedido': numeroPedido, 'es_pedido_tienda': true},
    );
  }

  static Future<void> perfilAprobado(String capitanId) async {
    await enviar(
      usuarioId: capitanId,
      titulo: '🎉 ¡Perfil Aprobado!',
      mensaje: '¡Felicitaciones! Tu perfil fue aprobado. Ya podés recibir viajes en El Guia YA.',
      tipo: 'perfil_aprobado',
    );
  }

  static Future<void> perfilRechazado(String capitanId, String motivo) async {
    await enviar(
      usuarioId: capitanId,
      titulo: '⚠️ Perfil Pendiente de Corrección',
      mensaje: 'Tu perfil necesita ajustes para ser aprobado. Motivo: $motivo.',
      tipo: 'perfil_rechazado',
      metadata: {'motivo': motivo},
    );
  }

  // ── Utilidades internas ────────────────────────────────────────────────────

  static String _codigo(String pedidoId) {
    if (pedidoId.isEmpty) return '#VJ-????';
    final limpio = pedidoId.replaceAll('-', '').toUpperCase();
    return '#VJ-${limpio.substring(0, 4)}';
  }
}
