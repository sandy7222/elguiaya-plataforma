import 'package:supabase_flutter/supabase_flutter.dart';

/// 🔔 HELPER CENTRALIZADO DE NOTIFICACIONES
///
/// Todas las notificaciones de la app pasan por aquí.
/// Hoy escribe en la tabla `notificaciones` (campanita in-app).
/// Cuando conectemos FCM real, solo hay que agregar el push aquí.
///
/// Uso:
///   await NotificacionHelper.enviar(
///     usuarioId: pescadorId,
///     titulo: '⛵ ¡Viaje Iniciado!',
///     mensaje: 'El capitán arrancó el viaje #VJ-XXXX.',
///     tipo: 'viaje_iniciado',
///     metadata: {'pedido_id': pedidoId},
///   );
class NotificacionHelper {
  static final _supabase = Supabase.instance.client;

  /// Envía una notificación in-app (campanita) a un usuario.
  /// En el futuro también disparará el push FCM real.
  static Future<void> enviar({
    required String usuarioId,
    required String titulo,
    required String mensaje,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    try {
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

  /// Envía la misma notificación a múltiples usuarios a la vez.
  static Future<void> enviarAVarios({
    required List<String> usuarioIds,
    required String titulo,
    required String mensaje,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    final ahora = DateTime.now().toIso8601String();
    final registros = usuarioIds
        .where((id) => id.isNotEmpty)
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

    if (registros.isEmpty) return;

    try {
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
