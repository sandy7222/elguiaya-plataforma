

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class DisponibilidadFinal {
  final String id;
  final String capitanId;
  final DateTime fecha;
  final String tipo; // 'reserva' o 'bloqueo_manual'
  final DateTime createdAt;
  final String? capitanNombre;
  final String? capitanEmail;
  final String? capitanCbu; // cbu en minusculas

  DisponibilidadFinal({
    required this.id,
    required this.capitanId,
    required this.fecha,
    required this.tipo,
    required this.createdAt,
    this.capitanNombre,
    this.capitanEmail,
    this.capitanCbu,
  });

  factory DisponibilidadFinal.fromSupabase(Map<String, dynamic> data) {
    return DisponibilidadFinal(
      id: data['id'].toString(),
      capitanId: data['capitan_id'].toString(),
      fecha: DateTime.parse(data['fecha']),
      tipo: data['tipo'] ?? 'bloqueo_manual',
      createdAt: DateTime.parse(data['created_at']),
      capitanNombre: data['capitan_nombre'],
      capitanEmail: data['capitan_email'],
      capitanCbu: data['cbu'], // cbu en minusculas
    );
  }

  /// Verifica si es un bloqueo manual
  bool get esBloqueoManual => tipo == 'bloqueo_manual';
  
  /// Verifica si es una reserva
  bool get esReserva => tipo == 'reserva';
  
  /// Verifica si el dia esta no disponible
  bool get noDisponible => esBloqueoManual || esReserva;
}

/// Servicio final de disponibilidad con validacion de infalibilidad
class DisponibilidadServiceFinal {
  static final SupabaseClient _supabase = SupabaseService.supabase;

  /// Bloquea una fecha especifica para el capitan
  static Future<bool> bloquearFecha(DateTime fecha, String motivo) async {
    try {
      final capitanId = getCapitanIdActual();
      if (capitanId == null) {
        throw Exception('Usuario no es un capitan o no esta autenticado');
      }

      final response = await _supabase.rpc('bloquear_fecha', params: {
        'p_capitan_id': capitanId,
        'p_fecha': fecha.toIso8601String().split('T')[0], // Solo fecha YYYY-MM-DD
        'p_motivo': motivo,
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al bloquear fecha: $e');
    }
  }

  /// Desbloquea una fecha especifica
  static Future<bool> desbloquearFecha(DateTime fecha) async {
    try {
      final capitanId = getCapitanIdActual();
      if (capitanId == null) {
        throw Exception('Usuario no es un capitan o no esta autenticado');
      }

      final response = await _supabase.rpc('desbloquear_fecha', params: {
        'p_capitan_id': capitanId,
        'p_fecha': fecha.toIso8601String().split('T')[0],
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al desbloquear fecha: $e');
    }
  }

  /// Marca una fecha como reservada
  static Future<bool> marcarFechaReservada(DateTime fecha) async {
    try {
      final response = await _supabase.rpc('marcar_fecha_reservada', params: {
        'p_capitan_id': getCapitanIdActual(),
        'p_fecha': fecha.toIso8601String().split('T')[0],
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al marcar fecha como reservada: $e');
    }
  }

  /// Marca una fecha como reservada para un capitán específico
  static Future<bool> marcarFechaReservadaConCapitan(DateTime fecha, String capitanId) async {
    try {
      final response = await _supabase.rpc('marcar_fecha_reservada', params: {
        'p_capitan_id': capitanId,
        'p_fecha': fecha.toIso8601String().split('T')[0],
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al marcar fecha como reservada: $e');
    }
  }

  /// Libera una fecha reservada
  static Future<bool> liberarFechaReservada(DateTime fecha) async {
    try {
      final response = await _supabase.rpc('liberar_fecha_reservada', params: {
        'p_capitan_id': getCapitanIdActual(),
        'p_fecha': fecha.toIso8601String().split('T')[0],
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al liberar fecha reservada: $e');
    }
  }

  /// Libera una fecha reservada para un capitán específico
  static Future<bool> liberarFechaReservadaConCapitan(DateTime fecha, String capitanId) async {
    try {
      final response = await _supabase.rpc('liberar_fecha_reservada', params: {
        'p_capitan_id': capitanId,
        'p_fecha': fecha.toIso8601String().split('T')[0],
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al liberar fecha reservada: $e');
    }
  }

  /// Obtiene el stream de fechas bloqueadas para un capitan en tiempo real
  static Stream<List<DisponibilidadFinal>> getFechasBloqueadasStream(String capitanId) {
    return _supabase
        .from('vista_disponibilidad_capitanes')
        .stream(primaryKey: ['id'])
        .map((event) {
          final filtered = event.where((disp) => 
            disp['capitan_id'] == capitanId && 
            disp['tipo'] == 'bloqueo_manual'
          ).toList();
          
          // Ordenar en memoria ya que .order() tampoco es confiable en stream() directo
          filtered.sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));
          
          return filtered.map((disp) => DisponibilidadFinal.fromSupabase(disp)).toList();
        });
  }

  /// Obtiene el stream completo de disponibilidad (bloqueos y reservas)
  static Stream<List<DisponibilidadFinal>> getDisponibilidadCompletaStream(String capitanId) {
    return _supabase
        .from('vista_disponibilidad_capitanes')
        .stream(primaryKey: ['id'])
        .map((event) {
          final filtered = event.where((disp) => disp['capitan_id'] == capitanId).toList();
          
          filtered.sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));
          
          return filtered.map((disp) => DisponibilidadFinal.fromSupabase(disp)).toList();
        });
  }

  /// Validacion de Ultimo Segundo antes de procesar pago
  static Future<Map<String, dynamic>> validarDisponibilidadUltimoSegundo({
    required String capitanId,
    required DateTime fechaReserva,
  }) async {
    try {
      final response = await _supabase.rpc('validar_disponibilidad_ultimo_segundo', params: {
        'p_capitan_id': capitanId,
        'p_fecha_reserva': fechaReserva.toIso8601String().split('T')[0],
      });

      if (response.isEmpty) {
        throw Exception('No se pudo validar la disponibilidad');
      }

      return response.first;
    } catch (e) {
      throw Exception('Error en validacion de ultimo segundo: $e');
    }
  }

  /// Verifica si una fecha esta disponible
  static Future<bool> estaDisponible(String capitanId, DateTime fecha) async {
    try {
      final response = await _supabase.rpc('verificar_disponibilidad_fecha', params: {
        'p_capitan_id': capitanId,
        'p_fecha': fecha.toIso8601String().split('T')[0],
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al verificar disponibilidad: $e');
    }
  }

  /// Obtiene fechas bloqueadas en un rango
  static Future<List<Map<String, dynamic>>> getFechasBloqueadas(
    String capitanId, {
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      final response = await _supabase.rpc('obtener_fechas_bloqueadas', params: {
        'p_capitan_id': capitanId,
        'p_fecha_inicio': fechaInicio?.toIso8601String().split('T')[0],
        'p_fecha_fin': fechaFin?.toIso8601String().split('T')[0],
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener fechas bloqueadas: $e');
    }
  }

  /// Genera un mapa de disponibilidad para un mes completo
  static Future<Map<String, bool>> generarCalendarioMensual(
    String capitanId,
    int ano,
    int mes,
  ) async {
    try {
      final primerDia = DateTime(ano, mes, 1);
      final ultimoDia = DateTime(ano, mes + 1, 0);
      
      final disponibilidad = await getFechasBloqueadas(
        capitanId,
        fechaInicio: primerDia,
        fechaFin: ultimoDia,
      );

      final calendario = <String, bool>{};
      
      // Marcar dias bloqueados como no disponibles
      for (final bloqueo in disponibilidad) {
        final fecha = DateTime.parse(bloqueo['fecha']);
        calendario[fecha.day.toString()] = false;
      }

      // Los dias no bloqueados estan disponibles por defecto
      for (int dia = 1; dia <= ultimoDia.day; dia++) {
        if (!calendario.containsKey(dia.toString())) {
          calendario[dia.toString()] = true;
        }
      }

      return calendario;
    } catch (e) {
      throw Exception('Error al generar calendario mensual: $e');
    }
  }

  /// Obtiene estadisticas de disponibilidad
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
          'dias_reservados': 0,
          'dias_disponibles': 0,
          'porcentaje_disponibilidad': 0.0,
        };
      }

      return response.first;
    } catch (e) {
      throw Exception('Error al obtener estadisticas: $e');
    }
  }

  /// Verifica si el usuario actual es un capitan
  static bool esCapitanActual() {
    return getCapitanIdActual() != null;
  }

  /// Obtiene el ID del capitan actual
  static String? getCapitanIdActual() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      return null;
    }

    // Obtener el rol desde metadata del usuario
    final userMetadata = user.userMetadata;
    final rol = userMetadata?['rol']?.toString().toLowerCase();

    if (rol == 'capitan') {
      return user.id;
    }

    return null;
  }

  /// Verifica si el usuario actual puede modificar la disponibilidad
  static Future<bool> puedeModificarDisponibilidad(String capitanId) async {
    final capitanIdActual = getCapitanIdActual();
    if (capitanIdActual == null) {
      return false;
    }

    // Solo el capitan dueno puede modificar su disponibilidad
    return capitanIdActual == capitanId;
  }

  /// Obtiene disponibilidad para multiples capitanes (para comparacion)
  static Future<Map<String, Map<String, bool>>> getDisponibilidadMultipleCapitanes(
    List<String> capitanIds,
    DateTime fecha,
  ) async {
    try {
      final fechaString = fecha.toIso8601String().split('T')[0];
      
      final response = await _supabase
          .from('disponibilidad')
          .select('capitan_id, tipo')
          .eq('fecha', fechaString)
          .inFilter('capitan_id', capitanIds);

      final disponibilidad = <String, Map<String, bool>>{};
      
      // Inicializar todos como disponibles
      for (final capitanId in capitanIds) {
        disponibilidad[capitanId] = {'disponible': true, 'bloqueado': false, 'reservado': false};
      }

      // Actualizar con los datos reales
      for (final registro in response) {
        final capitanId = registro['capitan_id'].toString();
        final tipo = registro['tipo'] ?? 'bloqueo_manual';
        
        if (!disponibilidad.containsKey(capitanId)) {
          disponibilidad[capitanId] = {'disponible': true, 'bloqueado': false, 'reservado': false};
        }

        if (tipo == 'bloqueo_manual') {
          disponibilidad[capitanId]!['disponible'] = false;
          disponibilidad[capitanId]!['bloqueado'] = true;
        } else if (tipo == 'reserva') {
          disponibilidad[capitanId]!['disponible'] = false;
          disponibilidad[capitanId]!['reservado'] = true;
        }
      }

      return disponibilidad;
    } catch (e) {
      throw Exception('Error al obtener disponibilidad multiple: $e');
    }
  }

  /// Sincronizacion masiva de disponibilidad
  static Future<bool> sincronizarDisponibilidadMasiva(
    String capitanId,
    Map<DateTime, String> calendario, // DateTime -> tipo ('disponible', 'bloqueo_manual', 'reserva')
  ) async {
    try {
      if (!await puedeModificarDisponibilidad(capitanId)) {
        throw Exception('No tienes permisos para modificar esta disponibilidad');
      }

      // Preparar datos para upsert
      final datos = calendario.entries.where((entry) => entry.value != 'disponible').map((entry) => {
        'capitan_id': capitanId,
        'fecha': entry.key.toIso8601String().split('T')[0],
        'tipo': entry.value,
      }).toList();

      // Eliminar registros existentes para el mes
      final primerDia = calendario.keys.first;
      final ultimoDia = calendario.keys.last;
      
      await _supabase
          .from('disponibilidad')
          .delete()
          .eq('capitan_id', capitanId)
          .gte('fecha', primerDia.toIso8601String().split('T')[0])
          .lte('fecha', ultimoDia.toIso8601String().split('T')[0]);

      // Insertar nuevos registros
      if (datos.isNotEmpty) {
        await _supabase.from('disponibilidad').insert(datos);
      }
      
      return true;
    } catch (e) {
      throw Exception('Error al sincronizar disponibilidad masiva: $e');
    }
  }

  /// Exporta disponibilidad a formato CSV
  static Future<String> exportarDisponibilidadCSV(
    String capitanId,
    int ano,
    int mes,
  ) async {
    try {
      final disponibilidad = await getFechasBloqueadas(
        capitanId,
        fechaInicio: DateTime(ano, mes, 1),
        fechaFin: DateTime(ano, mes + 1, 0),
      );

      final csv = <String>[];
      csv.add('Fecha,Tipo,Creado en');
      
      for (final bloqueo in disponibilidad) {
        final fecha = DateTime.parse(bloqueo['fecha']);
        final tipo = bloqueo['tipo'] ?? 'bloqueo_manual';
        final creadoEn = bloqueo['created_at'] ?? '';
        
        csv.add('${fecha.toIso8601String().split('T')[0]},$tipo,$creadoEn');
      }

      return csv.join('\n');
    } catch (e) {
      throw Exception('Error al exportar disponibilidad: $e');
    }
  }
}
