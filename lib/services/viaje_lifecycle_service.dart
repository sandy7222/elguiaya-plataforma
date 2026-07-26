import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/tipo_checkout.dart';
import 'billetera_virtual_service.dart';
import 'disponibilidad_service_final.dart';
import 'mercado_pago_service.dart';
import 'notificacion_helper.dart';
import 'recordatorios_service.dart';
import 'supabase_service.dart';
import 'viaje_gps_coordinator.dart';
import 'despacho_pna_service.dart';

class ViajeLifecycleService {
  static final _supabase = Supabase.instance.client;

  /// Estados en los que el viaje ya fue abonado y se habilita contacto/chat.
  static bool esEstadoPagado(String? estado) {
    if (estado == null) return false;
    final e = estado.toLowerCase();
    return e == 'pagado' || e == 'confirmado';
  }

  /// Estados en los que el pescador aún debe completar el pago.
  static bool requierePago(String? estado) {
    if (estado == null) return true;
    final e = estado.toLowerCase();
    return e == 'programado' ||
        e == 'pendiente_pago' ||
        e == 'pago_pendiente' ||
        e == 'pendiente' ||
        e == 'cotizado';
  }

  static String _estadoPedidoDesdePago(EstadoReservaMP estado) {
    switch (estado) {
      case EstadoReservaMP.aprobado:
        return 'pagado';
      case EstadoReservaMP.pendiente:
        return 'pago_pendiente';
      case EstadoReservaMP.rechazado:
        return 'cancelado';
    }
  }

  /// Sincroniza un pedido de viaje existente que ahora también incluye
  /// productos de tienda (checkout híbrido).
  ///
  /// - Actualiza `tipo_checkout` del pedido.
  /// - Inserta en `pedido_items` los productos de tienda que aún no estén
  ///   registrados (idempotente por producto/variante).
  static Future<void> sincronizarPedidoConCarrito({
    required String pedidoId,
    required TipoCheckout tipoCheckout,
    required double montoViaje,
    required List<Map<String, dynamic>> itemsTienda,
  }) async {
    if (pedidoId.isEmpty) return;
    try {
      await _supabase.from('pedidos').update({
        'tipo_checkout': tipoCheckout.valor,
        'estado_logistico': 'pendiente_pago',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', pedidoId);

      for (final item in itemsTienda) {
        final productoId = item['producto_id']?.toString();
        if (productoId == null || productoId.isEmpty) continue;

        final existente = await _supabase
            .from('pedido_items')
            .select('id')
            .eq('pedido_id', pedidoId)
            .eq('producto_id', productoId)
            .maybeSingle();

        if (existente == null) {
          await _supabase.from('pedido_items').insert({
            'pedido_id': pedidoId,
            'producto_id': productoId,
            'cantidad': item['cantidad'],
            'precio_unitario': item['precio_unitario'],
            'subtotal': item['subtotal'],
            'created_at': DateTime.now().toIso8601String(),
          });
        }
      }
    } catch (e) {
      debugPrint('⚠️ sincronizarPedidoConCarrito falló para $pedidoId: $e');
    }
  }

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

      final snapshot = await SupabaseService.obtenerSnapshotCapitanParaPresupuesto(capitanId);
      await SupabaseService.sincronizarDocumentacionContractualCapitan(capitanId);
      final contratoSnapshot = await SupabaseService.buildContratoSnapshot(
        capitanId: capitanId,
        cotizacionId: cotizacionId,
        monto: monto,
        detalles: detalles,
        presupuestoVisual: snapshot,
      );

      final payload = {
        'cotizacion_id': cotizacionId,
        'capitan_id': capitanId,
        'monto': monto,
        'detalles': detalles,
        'estado': 'pendiente',
        'created_at': DateTime.now().toIso8601String(),
        'capitan_nombre': snapshot['capitan_nombre'],
        'capitan_avatar_url': snapshot['capitan_avatar_url'],
        'embarcacion_url': snapshot['embarcacion_url'],
        'barco_nombre': snapshot['barco_nombre'],
        'contrato_snapshot': contratoSnapshot,
      };

      try {
        await _supabase.from('presupuestos').insert(payload);
      } catch (_) {
        await _supabase.from('presupuestos').insert({
          'cotizacion_id': cotizacionId,
          'capitan_id': capitanId,
          'monto': monto,
          'detalles': detalles,
          'estado': 'pendiente',
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      // Marcar la cotización como presupuestada para el radar del pescador
      try {
        await _supabase.from('cotizaciones').update({
          'estado': 'presupuestada',
          'presupuesto_monto': monto,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', cotizacionId);
      } catch (e) {
        print('Error al actualizar estado de cotización tras presupuesto: $e');
      }

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

      // Verificar si ya existe un pedido para este presupuesto
      final existingResponse = await _supabase
          .from('pedidos')
          .select('id')
          .eq('presupuesto_id', presupuesto['id'])
          .maybeSingle();

      if (existingResponse != null) {
        print('✅ Pedido ya existente para este presupuesto: ${existingResponse['id']}');
        return existingResponse['id'] as String;
      }

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
        print('⚠️ Advertencia: El capitán no tiene disponibilidad en el calendario para este horario ($fechaHoraViaje), procediendo de todos modos.');
      }

      // B. Crear el Pedido (Viaje Programado)
      final contratoSnapshot = presupuesto['contrato_snapshot'] ??
          await SupabaseService.buildContratoSnapshot(
            capitanId: presupuesto['capitan_id']?.toString() ?? '',
            cotizacionId: presupuesto['cotizacion_id']?.toString() ?? '',
            monto: (presupuesto['monto'] as num?)?.toDouble() ?? 0,
            detalles: presupuesto['detalles']?.toString() ?? '',
          );

      final pedidoPayload = {
            'presupuesto_id': presupuesto['id'],
            'pescador_id': pescadorId,
            'capitan_id': presupuesto['capitan_id'],
            'monto_total': presupuesto['monto'],
            'estado': 'programado',
            'fecha_servicio': fechaHoraViaje,
            'contrato_snapshot': contratoSnapshot,
            'created_at': DateTime.now().toIso8601String(),
          };

      dynamic response;
      try {
        response = await _supabase.from('pedidos').insert(pedidoPayload).select().single();
      } catch (_) {
        final fallback = Map<String, dynamic>.from(pedidoPayload)..remove('contrato_snapshot');
        response = await _supabase.from('pedidos').insert(fallback).select().single();
      }

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

        // 🔔 Notificar al PESCADOR que su reserva fue enviada al capitán
        if (pescadorId.isNotEmpty) {
          await NotificacionHelper.enviar(
            usuarioId: pescadorId,
            titulo: '⛵ ¡Reserva Enviada al Capitán!',
            mensaje:
                'Tu reserva fue aceptada y el capitán fue notificado. Completá el pago para confirmar tu lugar.',
            tipo: 'reserva_enviada',
            metadata: {
              'pedido_id': response['id'],
              'presupuesto_id': presupuesto['id'],
            },
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
          .select('pescador_id, presupuesto_id')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido != null && pedido['pescador_id'] != null) {
        await NotificacionHelper.viajeIniciado(pedido['pescador_id'] as String, pedidoId);
      }

      // Auto-corrección de seguridad: Asegurarse de que el presupuesto y cotización vinculados queden marcados
      if (pedido != null && pedido['presupuesto_id'] != null) {
        try {
          final presId = pedido['presupuesto_id'];
          final presResponse = await _supabase
              .from('presupuestos')
              .select('cotizacion_id')
              .eq('id', presId)
              .maybeSingle();
          if (presResponse != null) {
            await _supabase.from('presupuestos').update({'estado': 'aceptado'}).eq('id', presId);
            final cotId = presResponse['cotizacion_id'];
            if (cotId != null) {
              await _supabase.from('cotizaciones').update({'estado': 'cerrada'}).eq('id', cotId);
            }
          }
        } catch (e) {
          print('⚠️ [AUTO-HEAL] Error al auto-corregir estados de cotización/presupuesto en iniciarViaje: $e');
        }
      }

      await ViajeGpsCoordinator().startForTrip(
        pedidoId: pedidoId,
        userId: capitanId,
        rol: ViajeGpsRol.capitan,
        requestPermissionIfNeeded: false,
      );

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

      await ViajeGpsCoordinator().stopForTrip();

      print('✅ Viaje $pedidoId finalizado por capitán $capitanId');
    } catch (e) {
      throw Exception('Error al finalizar viaje: $e');
    }
  }

  /// 7a. CALIFICAR PESCADOR: El Capitán punta al pescador tras el viaje
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
        'pedido_id':          pedidoId,
        'calificador_id':     capitanId,
        'calificador_rol':    'capitan',
        'calificado_id':      pescadorId,
        'calificacion':       calificacion,
        'comentario':         comentario,
        'aspectos_puntuados': {'etiquetas': etiquetas},
        'created_at':         DateTime.now().toIso8601String(),
      });

      await _supabase
          .from('pedidos')
          .update({'capitan_califico': true})
          .eq('id', pedidoId);

      // Notificar al pescador que fue calificado
      try {
        await NotificacionHelper.calificacionRecibidaPescador(
            pescadorId, pedidoId, calificacion);
      } catch (_) {}

      // CIERRE AUTOMATICO: si el pescador ya califico, cerrar el viaje
      final pedido = await _supabase
          .from('pedidos')
          .select('pescador_califico')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido != null && pedido['pescador_califico'] == true) {
        await cerrarViaje(pedidoId);
      }

      // Actualizar reputación del pescador en reputacion_pescadores
      try {
        await SupabaseService.actualizarReputacionPescador(
            pescadorId, calificacion);
      } catch (_) {}

      print('Capitan $capitanId califico al pescador $pescadorId con $calificacion anzuelos');
    } catch (e) {
      throw Exception('Error al calificar pescador: $e');
    }
  }

  /// 7b. CALIFICAR CAPITAN: El Pescador punta al capitan tras el viaje
  /// Metodo simetrico que faltaba para cerrar el ciclo.
  static Future<void> calificarCapitan({
    required String pedidoId,
    required String pescadorId,
    required String capitanId,
    required int calificacion,
    String comentario = '',
    List<String> etiquetas = const [],
  }) async {
    try {
      final yaExiste = await _supabase
          .from('calificaciones_viaje')
          .select('id')
          .eq('pedido_id', pedidoId)
          .eq('calificador_id', pescadorId)
          .maybeSingle();

      if (yaExiste != null) throw Exception('Ya calificaste este viaje.');

      await _supabase.from('calificaciones_viaje').insert({
        'pedido_id':          pedidoId,
        'calificador_id':     pescadorId,
        'calificador_rol':    'pescador',
        'calificado_id':      capitanId,
        'calificacion':       calificacion,
        'comentario':         comentario,
        'aspectos_puntuados': {'etiquetas': etiquetas},
        'created_at':         DateTime.now().toIso8601String(),
      });

      await _supabase
          .from('pedidos')
          .update({'pescador_califico': true})
          .eq('id', pedidoId);

      // Notificar al capitan que fue calificado
      try {
        await NotificacionHelper.calificacionRecibidaCapitan(
            capitanId, pedidoId, calificacion);
      } catch (_) {}

      // CIERRE AUTOMATICO: si el capitan ya califico, cerrar el viaje
      final pedido = await _supabase
          .from('pedidos')
          .select('capitan_califico')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido != null && pedido['capitan_califico'] == true) {
        await cerrarViaje(pedidoId);
      }

      // Actualizar reputación del capitán en tabla reputacion_capitanes
      try {
        await SupabaseService.actualizarReputacionCapitan(capitanId, calificacion);
      } catch (_) {}

      print('Pescador $pescadorId califico al capitan $capitanId con $calificacion anclas');
    } catch (e) {
      throw Exception('Error al calificar capitan: $e');
    }
  }

  /// 8. CERRAR VIAJE: Se ejecuta cuando AMBAS partes calificaron.
  ///    Una vez cerrado, AUTOMATICAMENTE:
  ///      a) Marca el pedido como 'cerrado' con timestamp
  ///      b) Notifica a ambas partes
  ///      c) ACREDITA el monto neto en la BILLETERA VIRTUAL del capitan
  ///         (en saldo_pendiente, disponible a las 48hs)
  static Future<void> cerrarViaje(String pedidoId) async {
    try {
      final ahora = DateTime.now();

      await _supabase
          .from('pedidos')
          .update({
            'estado':     'cerrado',
            'cerrado_at': ahora.toIso8601String(),
          })
          .eq('id', pedidoId);

      // Obtener datos del pedido
      final pedido = await _supabase
          .from('pedidos')
          .select('pescador_id, capitan_id, monto_total, presupuesto_id')
          .eq('id', pedidoId)
          .maybeSingle();

      final capitanId  = pedido?['capitan_id']?.toString()  ?? '';
      final pescadorId = pedido?['pescador_id']?.toString() ?? '';
      final presId     = pedido?['presupuesto_id'];

      // Auto-corrección de seguridad al cerrar el viaje
      if (presId != null) {
        try {
          final presResponse = await _supabase
              .from('presupuestos')
              .select('cotizacion_id')
              .eq('id', presId)
              .maybeSingle();
          if (presResponse != null) {
            await _supabase.from('presupuestos').update({'estado': 'aceptado'}).eq('id', presId);
            final cotId = presResponse['cotizacion_id'];
            if (cotId != null) {
              await _supabase.from('cotizaciones').update({'estado': 'cerrada'}).eq('id', cotId);
            }
          }
        } catch (e) {
          print('⚠️ [AUTO-HEAL] Error al auto-corregir estados de cotización/presupuesto en cerrarViaje: $e');
        }
      }

      // Notificar a ambas partes que el viaje quedo cerrado
      if (capitanId.isNotEmpty && pescadorId.isNotEmpty) {
        try {
          await NotificacionHelper.viajeCerrado(pescadorId, capitanId, pedidoId);
        } catch (_) {}
      }

      // ACREDITAR EN BILLETERA - esto es AUTOMATICO al cierre
      if (capitanId.isNotEmpty) {
        await BilleteraVirtualService.acreditarPorViajeCerrado(
          pedidoId:  pedidoId,
          capitanId: capitanId,
        );

        // Notificar al capitan que el dinero esta en su billetera en modo pendiente
        final montoTotal = (pedido?['monto_total'] as num?)?.toDouble() ?? 0.0;
        final neto = montoTotal * (1 - BilleteraVirtualService.comisionPorcentaje);
        final disponibleEn = ahora.add(
          const Duration(hours: BilleteraVirtualService.horasDisputas));

        final diaDisp = disponibleEn.day.toString().padLeft(2, '0');
        final mesDisp = disponibleEn.month.toString().padLeft(2, '0');
        final horDisp = disponibleEn.hour.toString().padLeft(2, '0');
        final minDisp = disponibleEn.minute.toString().padLeft(2, '0');

        try {
          await NotificacionHelper.enviar(
            usuarioId: capitanId,
            titulo: 'Dinero en camino a tu billetera',
            mensaje:
                'Se acreditaron en tu billetera virtual. '
                'Estaran disponibles para retirar el '
                '$diaDisp/$mesDisp a las $horDisp:$minDisp hs '
                '(periodo de disputa de ${BilleteraVirtualService.horasDisputas}hs).',
            tipo: 'billetera_pendiente',
            metadata: {
              'pedido_id':        pedidoId,
              'monto_neto':       neto,
              'disponible_desde': disponibleEn.toIso8601String(),
            },
          );
        } catch (_) {}
      }

      print('Viaje $pedidoId cerrado. Billetera del capitan actualizada automaticamente.');
    } catch (e) {
      print('Error al cerrar viaje $pedidoId: $e');
    }
  }

  /// SCHEDULER: Liberar saldos pendientes cuyo periodo de disputa vencio.
  /// Llamar cada hora desde el scheduler del sistema.
  static Future<void> schedulerLiberarPendientes() async {
    print('Billetera: verificando pendientes vencidos...');
    await BilleteraVirtualService.liberarPendientesVencidos();
  }

  /// 9. CONFIRMAR PAGO: Actualiza el pedido tras MP (real o simulado).
  /// Retorna `true` solo si el pedido existió y se persistió el cambio.
  static Future<bool> confirmarPagoPedido({
    required String pedidoId,
    required EstadoPagoMP pago,
    required EstadoReservaMP estado,
    String? preferenceId,
    String? dniPagador,
    double? montoFallback,
  }) async {
    if (pedidoId.isEmpty) return false;

    try {
      final estadoPedido = _estadoPedidoDesdePago(estado);
      final ahora = DateTime.now().toIso8601String();

      final updateData = <String, dynamic>{
        'estado': estadoPedido,
        'mp_payment_id': pago.id,
        'metodo_pago': pago.paymentMethodId,
        'monto_total': pago.transactionAmount,
        'mp_preference_id': preferenceId,
        'mp_external_reference': pedidoId,
        'mp_raw_response': {
          'id': pago.id,
          'status': pago.status,
          'status_detail': pago.statusDetail,
          'transaction_amount': pago.transactionAmount,
          'payment_method_id': pago.paymentMethodId,
          'date_approved': pago.dateApproved?.toIso8601String(),
        },
        'updated_at': ahora,
      };

      if (estado == EstadoReservaMP.aprobado) {
        updateData['contacto_habilitado'] = true;
        updateData['contacto_habilitado_at'] = ahora;
      }

      final updated = await _supabase
          .from('pedidos')
          .update(updateData)
          .eq('id', pedidoId)
          .select('id, capitan_id, pescador_id, monto_total, fecha_servicio')
          .maybeSingle();

      if (updated == null) {
        debugPrint('⚠️ confirmarPagoPedido: pedido $pedidoId no encontrado');
        return false;
      }

      if (estado == EstadoReservaMP.aprobado) {
        await SupabaseService.sincronizarContratoSnapshotEnPedido(pedidoId);
        await SupabaseService.guardarPescadorSnapshotEnPedido(pedidoId);
      }

      // Tabla reservas legada (si existe vínculo)
      try {
        final res = await _supabase
            .from('pedidos')
            .select('reserva_id')
            .eq('id', pedidoId)
            .maybeSingle();

        if (res != null && res['reserva_id'] != null) {
          final rId = res['reserva_id'];
          final estadoReserva = estado == EstadoReservaMP.aprobado
              ? 'PAGADA'
              : estado == EstadoReservaMP.pendiente
                  ? 'PAGO_PENDIENTE'
                  : 'PAGO_RECHAZADO';

          if (rId is int) {
            await _supabase
                .from('reservas')
                .update({'estado': estadoReserva})
                .eq('id', rId);
          } else {
            final parsedId = int.tryParse(rId.toString());
            if (parsedId != null) {
              await _supabase
                  .from('reservas')
                  .update({'estado': estadoReserva})
                  .eq('id', parsedId);
            }
          }
        }
      } catch (e2) {
        debugPrint('⚠️ No se pudo actualizar tabla reservas: $e2');
      }

      if (dniPagador != null && dniPagador.isNotEmpty) {
        try {
          final currentUser = _supabase.auth.currentUser;
          if (currentUser != null) {
            await _supabase
                .from('profiles')
                .update({'dni': dniPagador})
                .eq('user_id', currentUser.id);
          }
        } catch (_) {}
      }

      if (estado == EstadoReservaMP.aprobado) {
        try {
          await SupabaseService.liberarContactoAlConfirmarPago(pedidoId);
        } catch (eLib) {
          debugPrint('⚠️ liberarContactoAlConfirmarPago: $eLib');
        }

        final capitanId = updated['capitan_id']?.toString() ?? '';
        final pescadorId = updated['pescador_id']?.toString() ??
            _supabase.auth.currentUser?.id ??
            '';
        final monto = (updated['monto_total'] as num?)?.toDouble() ??
            montoFallback ??
            pago.transactionAmount;

        if (capitanId.isNotEmpty && pescadorId.isNotEmpty) {
          try {
            await NotificacionHelper.pagoConfirmado(
              pescadorId,
              capitanId,
              pedidoId,
              monto,
            );
          } catch (eNotif) {
            debugPrint('⚠️ Error enviando notificaciones de pago: $eNotif');
          }

          try {
            await DespachoPnaService.notificarCapitanDocumentacion(
              pedidoId: pedidoId,
              escenario: 'pago_confirmado',
            );
          } catch (eDoc) {
            debugPrint('⚠️ Error aviso documentación PNA post-pago: $eDoc');
          }
        }

        try {
          final fechaRaw = updated['fecha_servicio']?.toString();
          final fechaServicio = fechaRaw != null
              ? DateTime.tryParse(fechaRaw)
              : null;
          if (fechaServicio != null && pescadorId.isNotEmpty) {
            await RecordatoriosService.crearRecordatoriosReserva(
              reservaId: pedidoId,
              clienteId: pescadorId,
              fechaSalida: fechaServicio,
            );
            debugPrint('🗓️ Recordatorios creados para viaje $pedidoId');
          }
        } catch (eRec) {
          debugPrint('⚠️ Error creando recordatorios: $eRec');
        }
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ confirmarPagoPedido falló para $pedidoId: $e');
      return false;
    }
  }
}

