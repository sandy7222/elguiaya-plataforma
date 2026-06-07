

import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import 'disponibilidad_service_final.dart';

class CotizacionesService {
  static final supabase = Supabase.instance.client;

  // Estados de cotizacion
  static const List<String> estadosValidos = [
    'pendiente', 
    'solicitada',
    'presupuestada', 
    'aceptada', 
    'rechazada', 
    'vencido'
  ];
  
  /// Obtener cotizaciones del capitan desde Supabase
  static Future<List<Map<String, dynamic>>> obtenerCotizacionesCapitan({
    String? capitanId,
    int limite = 50,
    int offset = 0,
  }) async {
    try {
      final userId = capitanId ?? supabase.auth.currentUser?.id;
      if (userId == null) return [];

      // Consultar cotizaciones donde el capitán está asignado 
      // O cotizaciones 'solicitada'/'pendiente' que están en su zona (para que pueda ofertar)
      final response = await supabase
          .from('cotizaciones')
          .select('*, profiles:pescador_id(nombre_completo, foto_url, telefono, email)')
          .or('capitan_id.eq.$userId,estado.in.(solicitada,pendiente)')
          .order('created_at', ascending: false)
          .range(offset, offset + limite - 1);

      // Mapear para compatibilidad con la UI
      return List<Map<String, dynamic>>.from(response.map((item) {
        final profile = item['profiles'] as Map<String, dynamic>?;
        final estado = item['estado'] as String?;
        final esRevelable = estado == 'aceptado' || estado == 'pagado';

        return {
          ...item,
          'status': item['estado'], // Compatibilidad de nombre
          'monto_total': (item['presupuesto_monto'] ?? 0).toDouble(),
          'fecha_solicitud': item['created_at'],
          'titulo': item['observaciones'] ?? item['descripcion'] ?? 'Solicitud de Viaje',
          'pescador_nombre': profile?['nombre_completo'] ?? 'Pescador',
          'pescador_email': esRevelable ? (profile?['email'] ?? 'N/A') : 'Bloqueado hasta aceptar',
          'pescador_telefono': esRevelable ? (profile?['telefono'] ?? 'N/A') : 'Bloqueado hasta aceptar',
          'viaje_nombre': 'Recorrido en ${item['localidad_partida'] ?? 'Zona'}',
          'viaje_fecha_salida': 'Ver detalle',
          'viaje_fecha_llegada': '',
          'distancia_km': (item['distancia_km'] ?? 0.0).toDouble(),
          'coordenadas_partida': item['coordenadas_partida'],
          'coordenadas_destino': item['coordenadas_destino'],
        };
      }));
    } catch (e) {
      print('Error en obtenerCotizacionesCapitan: $e');
      return [];
    }
  }
  
  /// Actualizar estado de cotizacion en Supabase
  static Future<Map<String, dynamic>> actualizarEstadoCotizacion({
    required String cotizacionId,
    required String nuevoEstado,
    String? motivo,
    String? usuarioId,
  }) async {
    try {
      // Si el nuevo estado es rechazado, limpiar presupuestos y liberar calendario
      if (nuevoEstado == 'rechazado' || nuevoEstado == 'rechazada') {
        try {
          final cot = await supabase
              .from('cotizaciones')
              .select('fecha_ida, capitan_id')
              .eq('id', cotizacionId)
              .maybeSingle();

          await supabase
              .from('presupuestos')
              .update({
                'estado': 'cancelado',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('cotizacion_id', cotizacionId);

          if (cot != null && cot['fecha_ida'] != null && cot['capitan_id'] != null) {
            final DateTime? fecha = DateTime.tryParse(cot['fecha_ida'].toString());
            final String capId = cot['capitan_id'].toString();
            if (fecha != null) {
              await DisponibilidadServiceFinal.liberarFechaReservadaConCapitan(fecha, capId);
            }
          }
        } catch (e) {
          print('Error en limpieza de rechazo de cotización: $e');
        }
      }

      final response = await supabase
          .from('cotizaciones')
          .update({
            'estado': nuevoEstado,
            'observaciones': motivo,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cotizacionId)
          .select()
          .single();

      return {
        'success': true,
        'cotizacion': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  /// Crear nueva cotizacion real
  static Future<Map<String, dynamic>> crearCotizacion({
    required String pescadorId,
    required String capitanId,
    required String viajeId,
    required String titulo,
    required String descripcion,
    required double montoTotal,
    required Map<String, dynamic> detalles,
    int vigenciaDias = 7,
  }) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .insert({
            'pescador_id': pescadorId,
            'capitan_id': capitanId,
            'descripcion': descripcion,
            'presupuesto_monto': montoTotal,
            'estado': 'pendiente',
            'observaciones': titulo, // Usamos observaciones para el titulo si no hay columna
          })
          .select()
          .single();

      return {
        'success': true,
        'cotizacion': response,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // Funcion para agregar mensaje a cotizacion
  static Future<Map<String, dynamic>> agregarMensajeCotizacion({
    required String cotizacionId,
    required String remitenteId,
    required String mensaje,
    required String tipoMensaje, // 'solicitud', 'respuesta', 'aclaracion'
  }) async {
    // Simular llamada a Supabase
    await Future.delayed(const Duration(milliseconds: 300));
    
    final nuevoMensaje = {
      'id': 'msg-${Random().nextInt(1000).toString().padLeft(3, '0')}',
      'cotizacion_id': cotizacionId,
      'remitente_id': remitenteId,
      'mensaje': mensaje,
      'tipo_mensaje': tipoMensaje,
      'leido': false,
      'created_at': DateTime.now().toIso8601String(),
    };
    
    print('✅ Mensaje agregado a cotizacion $cotizacionId: $tipoMensaje');
    
    return {
      'success': true,
      'mensaje': nuevoMensaje,
    };
  }
  
  /// Obtener cotización por ID real
  static Future<Map<String, dynamic>?> obtenerCotizacionPorId(String cotizacionId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('*, profiles:pescador_id(nombre_completo)')
          .eq('id', cotizacionId)
          .single();
      return Map<String, dynamic>.from(response);
    } catch (e) {
      return null;
    }
  }
  
  // Funcion para obtener mensajes de cotizacion
  static List<Map<String, dynamic>> obtenerMensajesCotizacion(String cotizacionId) {
    // Simular mensajes (en produccion vendrian de Supabase)
    return [
      {
        'id': 'msg-001',
        'cotizacion_id': cotizacionId,
        'remitente_id': 'pescador-001',
        'mensaje': 'Hola, me gustaria confirmar si incluye transporte desde Buenos Aires.',
        'tipo_mensaje': 'solicitud',
        'leido': false,
        'created_at': '2024-05-15T10:35:00Z',
      },
      {
        'id': 'msg-002',
        'cotizacion_id': cotizacionId,
        'remitente_id': 'capitan-001',
        'mensaje': '¡Hola! Si, incluimos transporte desde Capital. El precio ya contempla el traslado.',
        'tipo_mensaje': 'respuesta',
        'leido': true,
        'created_at': '2024-05-15T11:20:00Z',
      },
    ];
  }
  
  // Funcion para marcar mensajes como leidos
  static Future<Map<String, dynamic>> marcarMensajesLeidos({
    required String cotizacionId,
    required String usuarioId,
  }) async {
    // Simular llamada a Supabase
    await Future.delayed(const Duration(milliseconds: 200));
    
    print('✅ Mensajes de cotizacion $cotizacionId marcados como leidos por $usuarioId');
    
    return {
      'success': true,
      'mensajes_marcados': 3,
    };
  }
  
  /// Obtener estadísticas reales del capitán
  static Future<Map<String, dynamic>> obtenerEstadisticasCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('estado, presupuesto_monto')
          .eq('capitan_id', capitanId);

      final cotizaciones = List<Map<String, dynamic>>.from(response);
      
      final pendientes = cotizaciones.where((cot) => cot['estado'] == 'pendiente').length;
      final aceptados = cotizaciones.where((cot) => cot['estado'] == 'aceptado').length;
      final rechazados = cotizaciones.where((cot) => cot['estado'] == 'rechazado').length;
      
      final montoTotal = cotizaciones
          .where((cot) => cot['estado'] == 'aceptado')
          .fold<double>(0, (sum, cot) => sum + (cot['presupuesto_monto'] ?? 0.0));

      return {
        'total_cotizaciones': cotizaciones.length,
        'pendientes': pendientes,
        'aceptados': aceptados,
        'rechazados': rechazados,
        'monto_total_aceptados': montoTotal,
        'tasa_conversion': cotizaciones.isNotEmpty ? (aceptados / cotizaciones.length * 100) : 0,
      };
    } catch (e) {
      return {
        'total_cotizaciones': 0,
        'pendientes': 0,
        'aceptados': 0,
        'rechazados': 0,
        'monto_total_aceptados': 0.0,
        'tasa_conversion': 0.0,
      };
    }
  }

  /// Buscar cotizaciones reales
  static Future<List<Map<String, dynamic>>> buscarCotizaciones({
    required String termino,
    String? capitanId,
  }) async {
    try {
      final query = supabase
          .from('cotizaciones')
          .select('*, profiles:pescador_id(nombre_completo)')
          .ilike('descripcion', '%$termino%');

      if (capitanId != null) {
        query.eq('capitan_id', capitanId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Obtener cotizaciones por estado real
  static Future<List<Map<String, dynamic>>> obtenerCotizacionesPorEstado({
    required String estado,
    String? capitanId,
  }) async {
    try {
      final query = supabase
          .from('cotizaciones')
          .select('*, profiles:pescador_id(nombre_completo)')
          .eq('estado', estado);

      if (capitanId != null) {
        query.eq('capitan_id', capitanId);
      }

      final response = await query;
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  static String calcularVigencia(String? fechaVigencia) {
    if (fechaVigencia == null) return 'N/A';
    final vigencia = DateTime.parse(fechaVigencia);
    final ahora = DateTime.now();
    final diferencia = vigencia.difference(ahora);
    
    if (diferencia.isNegative) return 'Vencido';
    if (diferencia.inDays == 0) return 'Vence hoy';
    return 'Vence en ${diferencia.inDays} días';
  }
}
