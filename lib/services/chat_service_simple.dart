

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class MensajeChat {
  final String id;
  final String reservaId;
  final String emisorId;
  final String receptorId;
  final String contenido;
  final DateTime createdAt;
  final String? emisorNombre;
  final String? emisorEmail;
  final String? emisorRol;
  final String? receptorNombre;
  final String? receptorEmail;
  final String? receptorRol;

  MensajeChat({
    required this.id,
    required this.reservaId,
    required this.emisorId,
    required this.receptorId,
    required this.contenido,
    required this.createdAt,
    this.emisorNombre,
    this.emisorEmail,
    this.emisorRol,
    this.receptorNombre,
    this.receptorEmail,
    this.receptorRol,
  });

  factory MensajeChat.fromSupabase(Map<String, dynamic> data) {
    return MensajeChat(
      id: data['id'].toString(),
      reservaId: data['reserva_id'].toString(),
      emisorId: data['emisor_id'].toString(),
      receptorId: data['receptor_id'].toString(),
      contenido: data['contenido'] ?? '',
      createdAt: DateTime.parse(data['created_at']),
      emisorNombre: data['emisor_nombre'],
      emisorEmail: data['emisor_email'],
      emisorRol: data['emisor_rol'],
      receptorNombre: data['receptor_nombre'],
      receptorEmail: data['receptor_email'],
      receptorRol: data['receptor_rol'],
    );
  }

  /// Verifica si el mensaje es del usuario actual
  bool esMio() {
    final currentUser = Supabase.instance.client.auth.currentUser;
    return currentUser?.id == emisorId;
  }

  /// Obtiene el nombre del emisor para mostrar
  String get nombreEmisor {
    return emisorNombre ?? emisorEmail ?? 'Usuario';
  }

  /// Obtiene el nombre del receptor para mostrar
  String get nombreReceptor {
    return receptorNombre ?? receptorEmail ?? 'Usuario';
  }
}

/// Servicio simplificado para manejar el chat entre usuarios
class ChatServiceSimple {
  static final SupabaseClient _supabase = SupabaseService.supabase;

  /// Obtiene el stream de mensajes para una reserva especifica
  static Stream<List<MensajeChat>> getMensajesStream(String reservaId) {
    return _supabase
        .from('vista_mensajes_chat')
        .stream(primaryKey: ['id'])
        .eq('reserva_id', reservaId)
        .order('created_at', ascending: true)
        .map((event) => event.map((msg) => MensajeChat.fromSupabase(msg)).toList());
  }

  /// Envia un mensaje a una reserva
  static Future<bool> enviarMensaje({
    required String reservaId,
    required String contenido,
    required String receptorId,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final mensajeData = {
        'reserva_id': reservaId,
        'emisor_id': user.id,
        'receptor_id': receptorId,
        'contenido': contenido.trim(),
      };

      await _supabase.from('mensajes').insert(mensajeData);
      return true;
    } catch (e) {
      throw Exception('Error al enviar mensaje: $e');
    }
  }

  /// Obtiene el ID del receptor para una reserva
  static Future<String?> getReceptorId(String reservaId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      // Obtener informacion de la reserva
      final response = await _supabase
          .from('reservas')
          .select('pescador_id, capitan_id')
          .eq('id', reservaId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Reserva no encontrada');
      }

      final pescadorId = response['pescador_id']?.toString();
      final capitanId = response['capitan_id']?.toString();

      // Si el usuario actual es el pescador, el receptor es el capitan
      if (user.id == pescadorId) {
        return capitanId;
      }
      // Si el usuario actual es el capitan, el receptor es el pescador
      else if (user.id == capitanId) {
        return pescadorId;
      }

      return null;
    } catch (e) {
      throw Exception('Error obteniendo ID del receptor: $e');
    }
  }

  /// Envia mensaje automaticamente detectando el receptor
  static Future<bool> enviarMensajeAutomatico({
    required String reservaId,
    required String contenido,
  }) async {
    try {
      final receptorId = await getReceptorId(reservaId);
      if (receptorId == null) {
        throw Exception('No se pudo determinar el receptor');
      }

      return await enviarMensaje(
        reservaId: reservaId,
        contenido: contenido,
        receptorId: receptorId,
      );
    } catch (e) {
      throw Exception('Error al enviar mensaje automatico: $e');
    }
  }

  /// Obtiene informacion de la reserva para el chat
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
  static Future<MensajeChat?> getUltimoMensaje(String reservaId) async {
    try {
      final response = await _supabase
          .from('vista_mensajes_chat')
          .select('*')
          .eq('reserva_id', reservaId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      return response != null ? MensajeChat.fromSupabase(response) : null;
    } catch (e) {
      throw Exception('Error al obtener ultimo mensaje: $e');
    }
  }

  /// Busca mensajes por texto en una reserva
  static Future<List<MensajeChat>> buscarMensajes(
    String reservaId, 
    String query
  ) async {
    try {
      final response = await _supabase
          .from('vista_mensajes_chat')
          .select('*')
          .eq('reserva_id', reservaId)
          .ilike('contenido', '%$query%')
          .order('created_at', ascending: false);

      return response.map((msg) => MensajeChat.fromSupabase(msg)).toList();
    } catch (e) {
      throw Exception('Error al buscar mensajes: $e');
    }
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

  /// Obtiene el rol del usuario actual
  static String getRolActual() {
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

  /// Obtiene estadisticas basicas del chat para una reserva
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

      // Mensajes enviados por el usuario actual
      final enviadosResponse = await _supabase
          .from('mensajes')
          .select('id')
          .eq('reserva_id', reservaId)
          .eq('emisor_id', user.id);

      // Mensajes recibidos por el usuario actual
      final recibidosResponse = await _supabase
          .from('mensajes')
          .select('id')
          .eq('reserva_id', reservaId)
          .eq('receptor_id', user.id);

      return {
        'total_mensajes': totalResponse.length,
        'mensajes_enviados': enviadosResponse.length,
        'mensajes_recibidos': recibidosResponse.length,
        'ultimo_mensaje': totalResponse.isNotEmpty ? true : false,
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas: $e');
    }
  }
}
