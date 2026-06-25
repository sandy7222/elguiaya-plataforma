import 'package:supabase_flutter/supabase_flutter.dart';
import 'disponibilidad_service_final.dart';
import 'notificacion_helper.dart';

class ViajeLifecycleService {
  static final _supabase = Supabase.instance.client;

  /// 1. MÓDULO DE OFERTA: El Capitán envía un presupuesto
  static Future<void> enviarPresupuesto({
    required String cotizacionId,
    required String capitanId,
    required double monto,
    required String detalles,
  }) async {
    try {
      // Evitar envíos duplicados del mismo capitán para la misma cotización
      final yaExiste = await _supabase
          .from('presupuestos')
          .select('id')
          .eq('cotizacion_id', cotizacionId)
          .eq('capitan_id', capitanId)
          .maybeSingle();

      if (yaExiste != null) {
        throw Exception('Ya has enviado una propuesta para esta cotización.');
      }

      await _supabase.from('presupuestos').insert({
        'cotizacion_id': cotizacionId,
        'capitan_id': capitanId,
        'monto': monto,
        'detalles': detalles,
        'estado': 'pendiente',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Reservar fecha en el calendario del capitán
      try {
        final cotResponse = await _supabase
            .from('cotizaciones')
            .select('fecha_ida')
            .eq('id', cotizacionId)
            .maybeSingle();
        if (cotResponse != null && cotResponse['fecha_ida'] != null) {
          final DateTime? fecha = DateTime.tryParse(cotResponse['fecha_ida'].toString());
          if (fecha != null) {
            await DisponibilidadServiceFinal.marcarFechaReservadaConCapitan(fecha, capitanId);
          }
        }
      } catch (e) {
        print('Error al marcar fecha como reservada en enviarPresupuesto: $e');
      }

      // Notificar al pescador en la campanita
      try {
        final cotResponse = await _supabase
            .from('cotizaciones')
            .select('pescador_id, descripcion')
            .eq('id', cotizacionId)
            .single();
        final pescadorId = cotResponse['pescador_id'] as String?;
        final descripcion = cotResponse['descripcion'] ?? 'Salida de Pesca';
        if (pescadorId != null) {
          await NotificacionHelper.presupuestoRecibido(
            pescadorId, cotizacionId, monto, descripcion);
        }
      } catch (e) {
        print('Error al notificar al pescador sobre nuevo presupuesto: $e');
      }

      print('✅ Presupuesto enviado con éxito');
    } catch (e) {
      throw Exception('Error al enviar presupuesto: $e');
    }
  }

  /// 2. ACEPTACIÓN Y PROGRAMACIÓN: El Pescador acepta y se genera el Pedido/Viaje
  static Future<String> aceptarPresupuesto({
    required Map<String, dynamic> presupuesto,
    required String pescadorId,
  }) async {
    try {
      // Iniciamos una transacción lógica (RPC en Supabase sería ideal, pero aquí lo haremos secuencial)

      // A. Validar que el capitán siga disponible (Simulación de Lock)
      String? fechaHoraViaje = presupuesto['fecha_hora_viaje']?.toString();
      
      if (fechaHoraViaje == null || fechaHoraViaje.isEmpty) {
        final cotResponse = await _supabase
            .from('cotizaciones')
            .select('fecha_ida, hora_encuentro')
            .eq('id', presupuesto['cotizacion_id'])
            .maybeSingle();

        if (cotResponse != null && cotResponse['fecha_ida'] != null) {
          final fechaIda = cotResponse['fecha_ida'].toString().split('T').first;
          final hora = cotResponse['hora_encuentro']?.toString() ?? '08:00';
          fechaHoraViaje = '${fechaIda}T$hora';
        } else {
          fechaHoraViaje = DateTime.now().toIso8601String();
        }
      }

      final disponibilidad = await _verificarDisponibilidad(
        presupuesto['capitan_id'],
        fechaHoraViaje,
      );

      if (!disponibilidad) {
        throw Exception(
          'El EL GUIA YA no tiene disponibilidad para este horario.',
        );
      }

      // B. Crear el Pedido (Viaje Programado)
      final response = await _supabase
          .from('pedidos')
          .insert({
            'presupuesto_id': presupuesto['id'],
            'pescador_id': pescadorId,
            'capitan_id': presupuesto['capitan_id'],
            'monto_total': presupuesto['monto'],
            'estado': 'programado', // No 'pagado' todavía
            'fecha_servicio': fechaHoraViaje,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // C. Marcar presupuesto como aceptado
      await _supabase
          .from('presupuestos')
          .update({'estado': 'aceptado'})
          .eq('id', presupuesto['id']);

      // D. Marcar cotización como cerrada
      await _supabase
          .from('cotizaciones')
          .update({'estado': 'cerrada'})
          .eq('id', presupuesto['cotizacion_id']);

      // Notificar al capitán en la campanita con datos del pescador
      try {
        final capitanId = presupuesto['capitan_id'] as String?;
        final monto = (presupuesto['monto'] as num?)?.toDouble() ?? 0.0;
        if (capitanId != null) {
          // Leer nombre del pescador para enriquecer la notificación
          String nombrePescador = 'Un pescador';
          int cantidadPersonas = 1;
          try {
            final pescadorProfile = await _supabase
                .from('profiles')
                .select('nombre, dni')
                .eq('user_id', pescadorId)
                .maybeSingle();
            if (pescadorProfile != null) {
              nombrePescador = pescadorProfile['nombre']?.toString() ?? 'Un pescador';
            }
            // Leer cantidad de personas de la cotización
            final cotData = await _supabase
                .from('cotizaciones')
                .select('cantidad_personas')
                .eq('id', presupuesto['cotizacion_id'])
                .maybeSingle();
            if (cotData != null) {
              cantidadPersonas = (cotData['cantidad_personas'] as num?)?.toInt() ?? 1;
            }
          } catch (_) {}

          await NotificacionHelper.viajeConfirmadoConDatos(
            capitanId,
            response['id'],
            monto,
            nombrePescador,
            cantidadPersonas,
          );
        }
      } catch (e) {
        print('Error al notificar al capitán sobre aceptación de presupuesto: $e');
      }

      return response['id'];
    } catch (e) {
      throw Exception('Error al procesar aceptación: $e');
    }
  }

  /// 3. VALIDACIÓN DE DISPONIBILIDAD: Evita solapamientos
  static Future<bool> _verificarDisponibilidad(
    String capitanId,
    String fechaHora,
  ) async {
    final response = await _supabase
        .from('pedidos')
        .select()
        .eq('capitan_id', capitanId)
        .eq('fecha_servicio', fechaHora)
        .neq('estado', 'cancelado');

    if ((response as List).isNotEmpty) {
      return false;
    }

    // Validar en el almanaque si el capitán bloqueó el día
    try {
      final fecha = DateTime.parse(fechaHora);
      final estaDisponible = await DisponibilidadServiceFinal.estaDisponible(capitanId, fecha);
      if (!estaDisponible) {
        return false;
      }
    } catch (e) {
      print('Error al verificar disponibilidad en almanaque: $e');
    }

    return true;
  }

  /// 4. STREAM DE ACTUALIZACIONES: Para que el Pescador vea ofertas en vivo
  static Stream<List<Map<String, dynamic>>> streamPresupuestos(
    String cotizacionId,
  ) {
    return _supabase
        .from('presupuestos')
        .stream(primaryKey: ['id'])
        .eq('cotizacion_id', cotizacionId)
        .order('monto', ascending: true);
  }

  /// 5. INICIAR VIAJE: El Capitán activa el modo en curso
  static Future<void> iniciarViaje({
    required String pedidoId,
    required String capitanId,
  }) async {
    try {
      await _supabase
          .from('pedidos')
          .update({
            'estado': 'en_curso',
            'iniciado_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId)
          .eq('capitan_id', capitanId);

      // Notificar al pescador
      final pedido = await _supabase
          .from('pedidos')
          .select('pescador_id')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido != null && pedido['pescador_id'] != null) {
        await NotificacionHelper.viajeIniciado(pedido['pescador_id'] as String, pedidoId);
      }
      print('✅ Viaje $pedidoId iniciado por capitán $capitanId');
    } catch (e) {
      throw Exception('Error al iniciar viaje: $e');
    }
  }

  /// 6. FINALIZAR VIAJE: El Capitán cierra el servicio y espera confirmación
  static Future<void> finalizarViaje({
    required String pedidoId,
    required String capitanId,
  }) async {
    try {
      await _supabase
          .from('pedidos')
          .update({
            'estado': 'listo_para_confirmar',
            'finalizado_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId)
          .eq('capitan_id', capitanId);

      final pedido = await _supabase
          .from('pedidos')
          .select('pescador_id')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido != null && pedido['pescador_id'] != null) {
        await NotificacionHelper.viajeFinalizado(pedido['pescador_id'] as String, pedidoId);
      }
      print('✅ Viaje $pedidoId finalizado por capitán $capitanId');
    } catch (e) {
      throw Exception('Error al finalizar viaje: $e');
    }
  }

  /// 7. CALIFICAR PESCADOR: El Capitán punta al pescador tras el viaje
  static Future<void> calificarPescador({
    required String pedidoId,
    required String capitanId,
    required String pescadorId,
    required int calificacion,
    String comentario = '',
    List<String> etiquetas = const [],
  }) async {
    try {
      final yaExiste = await _supabase
          .from('calificaciones_viaje')
          .select('id')
          .eq('pedido_id', pedidoId)
          .eq('calificador_id', capitanId)
          .maybeSingle();

      if (yaExiste != null) throw Exception('Ya calificaste este viaje.');

      await _supabase.from('calificaciones_viaje').insert({
        'pedido_id': pedidoId,
        'calificador_id': capitanId,
        'calificador_rol': 'capitan',
        'calificado_id': pescadorId,
        'calificacion': calificacion,
        'comentario': comentario,
        'aspectos_puntuados': {'etiquetas': etiquetas},
        'created_at': DateTime.now().toIso8601String(),
      });

      // Marcar que el capitán calificó
      await _supabase
          .from('pedidos')
          .update({'capitan_califico': true})
          .eq('id', pedidoId);

      // Verificar si ambos calificaron para cerrar el viaje automáticamente
      final pedido = await _supabase
          .from('pedidos')
          .select('pescador_califico, pescador_id')
          .eq('id', pedidoId)
          .maybeSingle();

      // Notificar al pescador que fue calificado por el capitán
      if (pedido != null && pedido['pescador_id'] != null) {
        await NotificacionHelper.calificacionRecibidaPescador(
            pedido['pescador_id'] as String, pedidoId, calificacion);
      }

      if (pedido != null && pedido['pescador_califico'] == true) {
        await cerrarViaje(pedidoId);
      }
      print('✅ Capitán $capitanId calificó al pescador $pescadorId con $calificacion anclas');
    } catch (e) {
      throw Exception('Error al calificar pescador: $e');
    }
  }

  /// 8. CERRAR VIAJE: Se cierra el ciclo cuando ambas partes calificaron
  static Future<void> cerrarViaje(String pedidoId) async {
    try {
      await _supabase
          .from('pedidos')
          .update({'estado': 'cerrado', 'cerrado_at': DateTime.now().toIso8601String()})
          .eq('id', pedidoId);

      // Notificar a ambas partes que el viaje quedó cerrado
      try {
        final pedido = await _supabase
            .from('pedidos')
            .select('pescador_id, capitan_id')
            .eq('id', pedidoId)
            .maybeSingle();
        if (pedido != null &&
            pedido['pescador_id'] != null &&
            pedido['capitan_id'] != null) {
          await NotificacionHelper.viajeCerrado(
            pedido['pescador_id'] as String,
            pedido['capitan_id'] as String,
            pedidoId,
          );
        }
      } catch (_) {}

      print('🔒 Viaje $pedidoId cerrado correctamente');
    } catch (e) {
      print('⚠️ Error al cerrar viaje $pedidoId: $e');
    }
  }
}
