import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificacionService {
  // Patrón Singleton
  static final NotificacionService _instance = NotificacionService._internal();

  factory NotificacionService() {
    return _instance;
  }

  NotificacionService._internal();

  // Cliente de Supabase
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Stream en Tiempo Real para escuchar las alertas que le llegan a un usuario específico
  Stream<List<Map<String, dynamic>>> escucharNotificaciones(String usuarioId) {
    try {
      return _supabase
          .from('notificaciones_globales')
          .stream(primaryKey: ['id'])
          .eq('receptor_id', usuarioId)
          .order('created_at', ascending: false);
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al suscribirse al stream de notificaciones: $e');
      return Stream.value([]);
    }
  }

  /// Marca una notificación específica como leída para apagar el indicador visual
  Future<void> marcarComoLeida(String notificacionId) async {
    try {
      // 1. Obtener la notificación para saber receptor y título
      final notif = await _supabase
          .from('notificaciones_globales')
          .select('receptor_id, titulo')
          .eq('id', notificacionId)
          .maybeSingle();

      // 2. Marcar como leída en notificaciones_globales
      await _supabase
          .from('notificaciones_globales')
          .update({'leido': true})
          .eq('id', notificacionId);
      debugPrint('✅ [NotificacionService] Notificación $notificacionId marcada como leída en notificaciones_globales.');

      // 3. Sincronizar con la tabla legada 'notificaciones'
      if (notif != null) {
        final rId = notif['receptor_id'];
        final tit = notif['titulo'];
        if (rId != null && tit != null) {
          await _supabase
              .from('notificaciones')
              .update({'leida': true})
              .eq('usuario_id', rId)
              .eq('titulo', tit)
              .eq('leida', false);
          debugPrint('✅ [NotificacionService] Sincronizada a leída en notificaciones para usuario $rId y título "$tit".');
        }
      }
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al marcar notificación como leída: $e');
      rethrow;
    }
  }

  /// Obtiene el historial de notificaciones globales emitidas por el sistema
  Future<List<Map<String, dynamic>>> obtenerHistorialNotificaciones({int limit = 200}) async {
    try {
      final response = await _supabase
          .from('notificaciones_globales')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al obtener historial de notificaciones: $e');
      return [];
    }
  }


  /// Envía una notificación a un usuario específico
  Future<void> enviarNotificacion(Map<String, dynamic> datos) async {
    try {
      // 1. Escribir en la tabla moderna
      await _supabase.from('notificaciones_globales').insert(datos);
      debugPrint('✅ [NotificacionService] Notificación enviada correctamente a ${datos['receptor_id']}');

      // 2. Sincronizar en la tabla legada para encender la campana visual
      await _supabase.from('notificaciones').insert({
        'usuario_id': datos['receptor_id'],
        'titulo': datos['titulo'],
        'mensaje': datos['contenido'],
        'tipo': datos['categoria'] ?? 'mensaje',
        'leida': false,
        'metadata': datos['payload'] ?? {},
      });
      debugPrint('✅ [NotificacionService] Sincronizada notificación legada para campana.');
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al enviar notificación: $e');
      rethrow;
    }
  }

  /// Envía la misma notificación a una lista de usuarios (Broadcast)
  Future<void> enviarNotificacionMasiva(List<String> receptoresIds, Map<String, dynamic> templateDatos) async {
    try {
      if (receptoresIds.isEmpty) return;

      // 1. Armar la lista de inserts para la tabla moderna 'notificaciones_globales'
      final List<Map<String, dynamic>> lote = receptoresIds.map((id) {
        final notif = Map<String, dynamic>.from(templateDatos);
        notif['receptor_id'] = id;
        return notif;
      }).toList();

      await _supabase.from('notificaciones_globales').insert(lote);
      debugPrint('✅ [NotificacionService] Notificación masiva enviada a ${lote.length} usuarios en notificaciones_globales.');

      // 2. Armar la lista de inserts para la tabla legada 'notificaciones' (sincroniza campana visual)
      final List<Map<String, dynamic>> loteLegado = receptoresIds.map((id) {
        return {
          'usuario_id': id,
          'titulo': templateDatos['titulo'],
          'mensaje': templateDatos['contenido'],
          'tipo': 'mensaje',
          'leida': false,
          'metadata': templateDatos['payload'] ?? {},
        };
      }).toList();

      await _supabase.from('notificaciones').insert(loteLegado);
      debugPrint('✅ [NotificacionService] Sincronizadas ${loteLegado.length} notificaciones legadas para la campana.');
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al enviar notificación masiva: $e');
      rethrow;
    }
  }

  /// Elimina una notificación específica por su ID (ej. al deslizar)
  Future<void> eliminarNotificacion(String notificacionId) async {
    try {
      await _supabase
          .from('notificaciones_globales')
          .delete()
          .eq('id', notificacionId);
      debugPrint('✅ [NotificacionService] Notificación $notificacionId eliminada.');
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al eliminar notificación: $e');
      rethrow;
    }
  }

  /// Marca TODAS las notificaciones de un usuario como leídas
  Future<void> marcarTodasComoLeidas(String usuarioId) async {
    try {
      // 1. En notificaciones_globales
      await _supabase
          .from('notificaciones_globales')
          .update({'leido': true})
          .eq('receptor_id', usuarioId)
          .eq('leido', false);

      // 2. En la tabla legada 'notificaciones'
      await _supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('usuario_id', usuarioId)
          .eq('leida', false);

      debugPrint('✅ [NotificacionService] Todas las notificaciones del usuario $usuarioId marcadas como leídas.');
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al marcar todas como leídas: $e');
      rethrow;
    }
  }

  /// Limpia por completo la bandeja del usuario (elimina todas sus notificaciones)
  Future<void> limpiarBandeja(String usuarioId) async {
    try {
      // 1. Eliminar de notificaciones_globales
      await _supabase
          .from('notificaciones_globales')
          .delete()
          .eq('receptor_id', usuarioId);

      // 2. Eliminar de la tabla legada 'notificaciones'
      await _supabase
          .from('notificaciones')
          .delete()
          .eq('usuario_id', usuarioId);

      debugPrint('✅ [NotificacionService] Bandeja de notificaciones del usuario $usuarioId vaciada.');
    } catch (e) {
      debugPrint('❌ [NotificacionService] Error al limpiar bandeja: $e');
      rethrow;
    }
  }
}
