

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class Disponibilidad {
  final String id;
  final String capitanId;
  final DateTime fecha;
  final bool estaBloqueado;
  final String? motivoBloqueo;
  final DateTime creadoAt;
  final DateTime actualizadoAt;
  final String? capitanNombre;
  final String? capitanEmail;
  final String? capitanRol;

  Disponibilidad({
    required this.id,
    required this.capitanId,
    required this.fecha,
    required this.estaBloqueado,
    this.motivoBloqueo,
    required this.creadoAt,
    required this.actualizadoAt,
    this.capitanNombre,
    this.capitanEmail,
    this.capitanRol,
  });

  factory Disponibilidad.fromSupabase(Map<String, dynamic> data) {
    return Disponibilidad(
      id: data['id'].toString(),
      capitanId: data['capitan_id'].toString(),
      fecha: DateTime.parse(data['fecha']),
      estaBloqueado: data['esta_bloqueado'] ?? false,
      motivoBloqueo: data['motivo_bloqueo'],
      creadoAt: DateTime.parse(data['creado_at']),
      actualizadoAt: DateTime.parse(data['actualizado_at']),
      capitanNombre: data['capitan_nombre'],
      capitanEmail: data['capitan_email'],
      capitanRol: data['capitan_rol'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'capitan_id': capitanId,
      'fecha': fecha.toIso8601String().split('T')[0], // Solo fecha YYYY-MM-DD
      'esta_bloqueado': estaBloqueado,
      'motivo_bloqueo': motivoBloqueo,
    };
  }
}

/// Servicio para manejar la disponibilidad de capitanes
class DisponibilidadService {
  static final SupabaseClient _supabase = SupabaseService.supabase;

  /// Obtiene el stream de disponibilidad de un capitan
  static Stream<List<Disponibilidad>> getDisponibilidadStream(String capitanId) {
    return _supabase
        .from('vista_disponibilidad_capitanes')
        .stream(primaryKey: ['id'])
        .eq('capitan_id', capitanId)
        .order('fecha', ascending: true)
        .map((event) => event.map((disp) => Disponibilidad.fromSupabase(disp)).toList());
  }

  /// Obtiene la disponibilidad de un capitan para un rango de fechas
  static Future<List<Map<String, dynamic>>> getDisponibilidadRango(
    String capitanId,
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await _supabase.rpc('verificar_disponibilidad_rango', params: {
        'p_capitan_id': capitanId,
        'p_fecha_inicio': fechaInicio.toIso8601String().split('T')[0],
        'p_fecha_fin': fechaFin.toIso8601String().split('T')[0],
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener disponibilidad: $e');
    }
  }

  /// Obtiene los dias bloqueados de un capitan
  static Future<List<Map<String, dynamic>>> getDiasBloqueados(
    String capitanId, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final response = await _supabase.rpc('obtener_dias_bloqueados', params: {
        'p_capitan_id': capitanId,
        'p_fecha_inicio': fechaInicio?.toIso8601String().split('T')[0],
        'p_fecha_fin': fechaFin?.toIso8601String().split('T')[0],
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener dias bloqueados: $e');
    }
  }

  /// Bloquea o desbloquea una fecha especifica
  static Future<bool> actualizarDisponibilidad({
    required String capitanId,
    required DateTime fecha,
    required bool estaBloqueado,
    String? motivoBloqueo,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final disponibilidadData = {
        'capitan_id': capitanId,
        'fecha': fecha.toIso8601String().split('T')[0], // Solo fecha YYYY-MM-DD
        'esta_bloqueado': estaBloqueado,
        'motivo_bloqueo': motivoBloqueo,
      };

      await _supabase.from('disponibilidad').upsert(disponibilidadData);
      return true;
    } catch (e) {
      throw Exception('Error al actualizar disponibilidad: $e');
    }
  }

  /// Bloquea multiples fechas a la vez
  static Future<int> bloquearFechasMultiples({
    required String capitanId,
    required List<DateTime> fechas,
    String? motivo,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final fechasString = fechas
          .map((fecha) => fecha.toIso8601String().split('T')[0])
          .toList();

      final response = await _supabase.rpc('bloquear_fechas_multiples', params: {
        'p_capitan_id': capitanId,
        'p_fechas': fechasString,
        'p_motivo': motivo,
      });

      return response ?? 0;
    } catch (e) {
      throw Exception('Error al bloquear fechas multiples: $e');
    }
  }

  /// Desbloquea multiples fechas a la vez
  static Future<int> desbloquearFechasMultiples({
    required String capitanId,
    required List<DateTime> fechas,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      final fechasString = fechas
          .map((fecha) => fecha.toIso8601String().split('T')[0])
          .toList();

      final response = await _supabase.rpc('desbloquear_fechas_multiples', params: {
        'p_capitan_id': capitanId,
        'p_fechas': fechasString,
      });

      return response ?? 0;
    } catch (e) {
      throw Exception('Error al desbloquear fechas multiples: $e');
    }
  }

  /// Verifica si una fecha especifica esta disponible
  static Future<bool> estaDisponible(String capitanId, DateTime fecha) async {
    try {
      final response = await _supabase
          .from('disponibilidad')
          .select('esta_bloqueado')
          .eq('capitan_id', capitanId)
          .eq('fecha', fecha.toIso8601String().split('T')[0])
          .maybeSingle();

      // Si no hay registro, la fecha esta disponible por defecto
      if (response == null) {
        return true;
      }

      return !(response['esta_bloqueado'] ?? false);
    } catch (e) {
      throw Exception('Error al verificar disponibilidad: $e');
    }
  }

  /// Obtiene estadisticas de disponibilidad de un capitan
  static Future<Map<String, dynamic>> getEstadisticasDisponibilidad(
    String capitanId, {
    int? mes,
    int? anio,
  }) async {
    try {
      final mesActual = mes ?? DateTime.now().month;
      final anioActual = anio ?? DateTime.now().year;

      final response = await _supabase.rpc('obtener_estadisticas_disponibilidad', params: {
        'p_capitan_id': capitanId,
        'p_mes': mesActual,
        'p_anio': anioActual,
      });

      if (response.isEmpty) {
        return {
          'total_dias': 0,
          'dias_bloqueados': 0,
          'dias_disponibles': 0,
          'porcentaje_disponibilidad': 0.0,
        };
      }

      return response.first;
    } catch (e) {
      throw Exception('Error al obtener estadisticas: $e');
    }
  }

  /// Genera un calendario de disponibilidad para un mes
  static Future<Map<String, bool>> generarCalendarioMensual(
    String capitanId,
    int anio,
    int mes,
  ) async {
    try {
      final primerDia = DateTime(anio, mes, 1);
      final ultimoDia = DateTime(anio, mes + 1, 0);
      
      final disponibilidad = await getDisponibilidadRango(
        capitanId,
        primerDia,
        ultimoDia,
      );

      final calendario = <String, bool>{};
      
      for (final dia in disponibilidad) {
        final fecha = DateTime.parse(dia['fecha']);
        final disponible = dia['disponible'] ?? true;
        calendario[fecha.day.toString()] = disponible;
      }

      // Marcar como disponibles los dias que no estan en la respuesta
      for (int dia = 1; dia <= ultimoDia.day; dia++) {
        if (!calendario.containsKey(dia.toString())) {
          calendario[dia.toString()] = true;
        }
      }

      return calendario;
    } catch (e) {
      throw Exception('Error al generar calendario: $e');
    }
  }

  /// Obtiene el ID del capitan actual
  static String? getCapitanIdActual() {
    return SupabaseService.capitanIdActual;
  }

  /// Verifica si el usuario actual es un capitan
  static bool esCapitanActual() {
    return getCapitanIdActual() != null;
  }

  /// Elimina un registro de disponibilidad
  static Future<bool> eliminarDisponibilidad(String disponibilidadId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      await _supabase
          .from('disponibilidad')
          .delete()
          .eq('id', disponibilidadId)
          .eq('capitan_id', user.id);

      return true;
    } catch (e) {
      throw Exception('Error al eliminar disponibilidad: $e');
    }
  }

  /// Obtiene disponibilidad de multiples capitanes para una fecha
  static Future<Map<String, bool>> getDisponibilidadCapitanesPorFecha(
    DateTime fecha,
    List<String> capitanIds,
  ) async {
    try {
      final response = await _supabase
          .from('disponibilidad')
          .select('capitan_id, esta_bloqueado')
          .eq('fecha', fecha.toIso8601String().split('T')[0])
          .filter('capitan_id', 'in', capitanIds);

      final disponibilidad = <String, bool>{};
      
      // Por defecto, todos estan disponibles
      for (final capitanId in capitanIds) {
        disponibilidad[capitanId] = true;
      }

      // Actualizar con los datos reales
      for (final registro in response) {
        final capitanId = registro['capitan_id'].toString();
        final estaBloqueado = registro['esta_bloqueado'] ?? false;
        disponibilidad[capitanId] = !estaBloqueado;
      }

      return disponibilidad;
    } catch (e) {
      throw Exception('Error al obtener disponibilidad de capitanes: $e');
    }
  }

  /// Sincroniza disponibilidad masiva (para importacion/exportacion)
  static Future<bool> sincronizarDisponibilidadMasiva(
    String capitanId,
    Map<DateTime, bool> calendario,
  ) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('Usuario no autenticado');
      }

      if (user.id != capitanId) {
        throw Exception('No tienes permiso para modificar esta disponibilidad');
      }

      // Preparar datos para upsert
      final datos = calendario.entries.map((entry) => {
        'capitan_id': capitanId,
        'fecha': entry.key.toIso8601String().split('T')[0],
        'esta_bloqueado': !entry.value,
      }).toList();

      // Realizar upsert masivo
      await _supabase.from('disponibilidad').upsert(datos);
      
      return true;
    } catch (e) {
      throw Exception('Error al sincronizar disponibilidad: $e');
    }
  }
}
