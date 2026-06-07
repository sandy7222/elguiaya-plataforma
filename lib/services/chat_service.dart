

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class Mensaje {
  final String id;
  final String reservaId;
  final String emisorId;
  final String texto;
  final String tipoEmisor; // 'pescador', 'capitan', 'admin'
  final bool leido;
  final DateTime creadoAt;
  final DateTime actualizadoAt;
  final String? emisorEmail;
  final String? emisorNombre;
  final String? emisorRol;

  Mensaje({
    required this.id,
    required this.reservaId,
    required this.emisorId,
    required this.texto,
    required this.tipoEmisor,
    required this.leido,
    required this.creadoAt,
    required this.actualizadoAt,
    this.emisorEmail,
    this.emisorNombre,
    this.emisorRol,
  });

  factory Mensaje.fromSupabase(Map<String, dynamic> data) {
    return Mensaje(
      id: data['id'].toString(),
      reservaId: data['reserva_id'].toString(),
      emisorId: data['emisor_id'].toString(),
      texto: data['texto'] ?? '',
      tipoEmisor: data['tipo_emisor'] ?? '',
      leido: data['leido'] ?? false,
      creadoAt: DateTime.parse(data['creado_at']),
      actualizadoAt: DateTime.parse(data['actualizado_at']),
      emisorEmail: data['emisor_email'],
      emisorNombre: data['emisor_nombre'],
      emisorRol: data['emisor_rol'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'reserva_id': reservaId,
      'emisor_id': emisorId,
      'texto': texto,
      'tipo_emisor': tipoEmisor,
      'leido': leido,
    };
  }
}

/// Servicio para manejar el chat entre usuarios
class ChatService {
  static final SupabaseClient _supabase = SupabaseService.supabase;

  /// Obtiene el stream de mensajes para una reserva especifica
  static Stream<List<Mensaje>> getMensajesStream(String reservaId) {
    return _supabase
        .from('vista_mensajes_con_emisor')
        .stream(primaryKey: ['id'])
        .eq('reserva_id', reservaId)
        .order('creado_at', ascending: true)
        .map((event) => event.map((msg) => Mensaje.fromSupabase(msg)).toList());
  }

  /// Envia un mensaje a una reserva
  static Future<bool> enviarMensaje({
    required String reservaId,
    required String texto,
    required String tipoEmisor,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final mensajeData = {
        'reserva_id': reservaId,
        'emisor_id': user.id,
        'texto': texto.trim(),
        'tipo_emisor': tipoEmisor,
        'leido': false,
      };

      await _supabase.from('mensajes').insert(mensajeData);
      return true;
    } catch (e) {
      throw Exception('Error al enviar mensaje: $e');
    }
  }

  /// Marca mensajes como leidos para una reserva
  static Future<int> marcarMensajesLeidos(String reservaId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase.rpc('marcar_mensajes_leidos', params: {
        'p_reserva_id': reservaId,
        'p_usuario_id': user.id,
      });

      return response ?? 0;
    } catch (e) {
      throw Exception('Error al marcar mensajes como leidos: $e');
    }
  }

  /// Obtiene el conteo de mensajes no leidos del usuario actual
  static Future<int> contarMensajesNoLeidos() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase.rpc('contar_mensajes_no_leidos', params: {
        'p_usuario_id': user.id,
      });

      return response ?? 0;
    } catch (e) {
      throw Exception('Error al contar mensajes no leidos: $e');
    }
  }

  /// Obtiene el stream de conteo de mensajes no leidos
  static Stream<int> getMensajesNoLeidosStream() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return Stream.value(0);
    }

    return _supabase
        .from('mensajes')
        .stream(primaryKey: ['id'])
        .eq('leido', false)
        .map((event) {
          // Filtrar mensajes no leidos donde el emisor NO sea el usuario actual
          final filtrados = event.where((msg) => msg['emisor_id'] != user.id).toList();
          return filtrados.length;
        });
  }

  /// Elimina un mensaje (solo el emisor puede eliminar)
  static Future<bool> eliminarMensaje(String mensajeId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      await _supabase
          .from('mensajes')
          .delete()
          .eq('id', mensajeId)
          .eq('emisor_id', user.id);

      return true;
    } catch (e) {
      throw Exception('Error al eliminar mensaje: $e');
    }
  }

  /// Obtiene informacion de una reserva para el chat
  static Future<Map<String, dynamic>?> getInfoReserva(String reservaId) async {
    try {
      final response = await _supabase
          .from('reservas')
          .select('''
            *,
            servicios!inner(
              id,
              nombre,
              descripcion
            ),
            perfiles!inner(
              id,
              nombre,
              email,
              telefono
            )
          ''')
          .eq('id', reservaId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Error al obtener informacion de reserva: $e');
    }
  }

  /// Obtiene el rol del usuario actual para el tipo de emisor
  static String getTipoEmisorActual() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return 'pescador'; // Default
    }

    // Obtener el rol desde metadata del usuario
    final userMetadata = user.userMetadata;
    final rol = userMetadata?['rol']?.toString().toLowerCase();

    switch (rol) {
      case 'capitan':
        return 'capitan';
      case 'admin':
        return 'admin';
      case 'pescador':
      default:
        return 'pescador';
    }
  }

  /// Verifica si el usuario actual puede participar en el chat de una reserva
  static Future<bool> puedeParticiparEnChat(String reservaId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        return false;
      }

      final response = await _supabase
          .from('reservas')
          .select('pescador_id, capitan_id')
          .eq('id', reservaId)
          .maybeSingle();

      if (response == null) {
        return false;
      }

      final pescadorId = response['pescador_id']?.toString();
      final capitanId = response['capitan_id']?.toString();

      return user.id == pescadorId || user.id == capitanId;
    } catch (e) {
      return false;
    }
  }

  /// Obtiene el ultimo mensaje de una reserva
  static Future<Mensaje?> getUltimoMensaje(String reservaId) async {
    try {
      final response = await _supabase
          .from('vista_mensajes_con_emisor')
          .select('*')
          .eq('reserva_id', reservaId)
          .order('creado_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response != null ? Mensaje.fromSupabase(response) : null;
    } catch (e) {
      throw Exception('Error al obtener ultimo mensaje: $e');
    }
  }

  /// Busca mensajes por texto en una reserva
  static Future<List<Mensaje>> buscarMensajes(
    String reservaId, 
    String query
  ) async {
    try {
      final response = await _supabase
          .from('vista_mensajes_con_emisor')
          .select('*')
          .eq('reserva_id', reservaId)
          .ilike('texto', '%$query%')
          .order('creado_at', ascending: false);

      return response.map((msg) => Mensaje.fromSupabase(msg)).toList();
    } catch (e) {
      throw Exception('Error al buscar mensajes: $e');
    }
  }

  /// Obtiene estadisticas del chat para una reserva
  static Future<Map<String, dynamic>> getEstadisticasChat(String reservaId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Total de mensajes
      final totalResponse = await _supabase
          .from('mensajes')
          .select('id')
          .eq('reserva_id', reservaId);

      // Mensajes no leidos del usuario
      final noLeidosResponse = await _supabase
          .from('mensajes')
          .select('id')
          .eq('reserva_id', reservaId)
          .eq('leido', false)
          .neq('emisor_id', user.id);

      // Mensajes por tipo de emisor
      final porTipoResponse = await _supabase
          .from('mensajes')
          .select('tipo_emisor')
          .eq('reserva_id', reservaId);

      final mensajesPorTipo = <String, int>{};
      for (final msg in porTipoResponse) {
        final tipo = msg['tipo_emisor'] as String;
        mensajesPorTipo[tipo] = (mensajesPorTipo[tipo] ?? 0) + 1;
      }

      return {
        'total_mensajes': totalResponse.length,
        'no_leidos': noLeidosResponse.length,
        'mensajes_por_tipo': mensajesPorTipo,
        'ultima_actividad': totalResponse.isNotEmpty 
            ? totalResponse.last['creado_at'] 
            : null,
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas: $e');
    }
  }
}
