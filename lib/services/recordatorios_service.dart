

import 'dart:async';


import 'seguridad_service.dart';
import 'supabase_service.dart';
import 'whatsapp_service.dart';
import 'weather_service.dart';

class Recordatorio {
  final String id;
  final String reservaId;
  final String clienteId;
  final String tipo; // '7dias' | '3dias' | '24hs' | '12hs' | '2hs' | 'capitan_24hs' | 'capitan_2hs'
  final DateTime fechaProgramada;
  final DateTime fechaEnvio;
  final String estado; // 'pendiente', 'enviado', 'fallido', 'cancelado'
  final String? mensajeId;

  Recordatorio({
    required this.id,
    required this.reservaId,
    required this.clienteId,
    required this.tipo,
    required this.fechaProgramada,
    required this.fechaEnvio,
    required this.estado,
    this.mensajeId,
  });

  factory Recordatorio.fromSupabase(Map<String, dynamic> data) {
    return Recordatorio(
      id: data['id'].toString(),
      reservaId: data['reserva_id'].toString(),
      clienteId: data['cliente_id'].toString(),
      tipo: data['tipo'] ?? '',
      fechaProgramada: DateTime.parse(data['fecha_programada']),
      fechaEnvio: DateTime.parse(data['fecha_envio']),
      estado: data['estado'] ?? 'pendiente',
      mensajeId: data['mensaje_id'],
    );
  }
}

/// Servicio de gestion de recordatorios automaticos
class RecordatoriosService {
  static Timer? _schedulerTimer;
  static bool _isRunning = false;

  /// Iniciar el scheduler de recordatorios
  static Future<void> iniciarScheduler() async {
    if (_isRunning) return;

    _isRunning = true;
    print('📅 Iniciando scheduler de recordatorios...');

    // Ejecutar inmediatamente una vez
    await _procesarRecordatoriosPendientes();

    // Configurar timer para ejecutar cada 5 minutos
    _schedulerTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _procesarRecordatoriosPendientes();
    });
  }

  /// Detener el scheduler
  static void detenerScheduler() {
    _schedulerTimer?.cancel();
    _schedulerTimer = null;
    _isRunning = false;
    print('📅 Scheduler de recordatorios detenido');
  }

  /// Procesar recordatorios pendientes
  static Future<void> _procesarRecordatoriosPendientes() async {
    try {
      print('📅 Procesando recordatorios pendientes...');

      // Obtener recordatorios pendientes que deben enviarse ahora
      final ahora = DateTime.now();
      final limite = ahora.add(const Duration(minutes: 5)); // Margen de 5 minutos

      final response = await SupabaseService.supabase
          .from('recordatorios')
          .select()
          .eq('estado', 'pendiente')
          .lte('fecha_programada', limite.toIso8601String())
          .order('fecha_programada', ascending: true);

      final recordatorios = response.map((r) => Recordatorio.fromSupabase(r)).toList();

      if (recordatorios.isEmpty) {
        print('📅 No hay recordatorios pendientes para procesar');
        return;
      }

      print('📅 Procesando ${recordatorios.length} recordatorios');

      // Procesar cada recordatorio
      for (final recordatorio in recordatorios) {
        await _enviarRecordatorio(recordatorio);
      }
    } catch (e) {
      print('❌ Error procesando recordatorios: $e');
    }
  }

  /// Enviar un recordatorio especifico
  static Future<void> _enviarRecordatorio(Recordatorio recordatorio) async {
    try {
      // Obtener detalles de la reserva
      final reserva = await _obtenerReserva(recordatorio.reservaId);
      if (reserva == null) {
        await _actualizarEstadoRecordatorio(recordatorio.id, 'fallido', 'Reserva no encontrada');
        return;
      }

      // Obtener datos del cliente y capitan
      final cliente = await SeguridadService.getUsuarioPorId(recordatorio.clienteId) as Map<String, dynamic>?;
      final capitan = await SeguridadService.getUsuarioPorId(reserva['capitan_id'].toString()) as Map<String, dynamic>?;

      if (cliente == null || capitan == null) {
        await _actualizarEstadoRecordatorio(recordatorio.id, 'fallido', 'Usuario no encontrado');
        return;
      }

      // Enviar recordatorio segun el tipo
      WhatsAppResponse response;

      switch (recordatorio.tipo) {
        case '24hs':
          response = await WhatsAppService.enviarRecordatorioSalida(
            telefonoCliente: cliente['telefono'] ?? '+5491166789123',
            nombreCliente: cliente['nombre'] ?? 'Cliente',
            fechaSalida: DateTime.parse(reserva['fecha_servicio'] ?? reserva['created_at']),
            horaSalida: reserva['hora_encuentro'] ?? '08:00',
            puntoEncuentro: reserva['lugar_encuentro'] ?? reserva['localidad_partida'] ?? 'Puerto',
            nombreCapitan: capitan['nombre'] ?? 'Capitán',
            telefonoCapitan: capitan['telefono'] ?? '',
            whatsappCapitan: capitan['telefono'] ?? '',
            pronosticoClima: await _obtenerPronosticoClimaDeReserva(reserva),
          );

          // ─── INVITACIÓN AL DESPERTADOR ────────────────────────────────────
          // Enviamos un segundo WhatsApp separado (más ligero, informal)
          // invitando al cliente a pedir al Guia que lo despierte mañana.
          if (response.success) {
            final hora = reserva['hora_encuentro']?.toString() ?? '08:00';
            final nombre = cliente['nombre']?.toString() ?? 'pescador';
            await WhatsAppService.enviarMensaje(WhatsAppMessage(
              to: cliente['telefono'] ?? '',
              templateName: 'invitacion_despertador',
              templateData: {
                'nombre_cliente': nombre,
                'hora_encuentro': hora,
                'instruccion_1': '"Guia, despertame a las 5"',
                'instruccion_2': '"poneme alarma a las 6:30"',
                'instruccion_cancelar': '"cancelá el despertador"',
                'mensaje':
                    '💡 *¿Querés que El Guia te despierte mañana?*\n'
                    'Si no querés quedarte dormido antes de tu viaje de las $hora, '
                    'podés pedirle a El Guia que te programe un despertador directo '
                    'en tu teléfono.\n\n'
                    'Solo abrí la app y en el chat con El Guia escribí:\n'
                    '👉 *"Guia, despertame a las 5"*\n'
                    'o\n'
                    '👉 *"poneme alarma a las 6:30"*\n\n'
                    'El Guia lo programa solo — suena aunque tengas la pantalla apagada. '
                    'Para cancelarlo: *"cancelá el despertador"*.\n\n'
                    '¡Que descanses, $nombre! 🌙⛵',
              },
            ));
          }
          break;


        case '7dias':
          response = await _enviarRecordatorio7Dias(
            cliente: cliente,
            reserva: reserva,
            capitan: capitan,
          );
          break;

        case '3dias':
          response = await _enviarRecordatorio3Dias(
            cliente: cliente,
            reserva: reserva,
            capitan: capitan,
          );
          break;

        case '1dia':
        case '12hs':
          response = await _enviarRecordatorio1Dia(
            cliente: cliente,
            reserva: reserva,
            capitan: capitan,
          );
          break;

        // ─── NUEVO: 2 horas antes (pescador) ─────────────────────────────────
        case '2hs':
          response = await _enviarRecordatorio2Horas(
            cliente: cliente,
            reserva: reserva,
            capitan: capitan,
          );
          break;

        // ─── NUEVO: 24hs antes (capitán) ─────────────────────────────────
        case 'capitan_24hs':
          response = await _enviarRecordatorioCapitan24hs(
            cliente: cliente,
            reserva: reserva,
            capitan: capitan,
          );
          break;

        // ─── NUEVO: 2hs antes (capitán) ─────────────────────────────────
        case 'capitan_2hs':
          response = await _enviarRecordatorioCapitan2hs(
            cliente: cliente,
            reserva: reserva,
            capitan: capitan,
          );
          break;

        default:
          response = WhatsAppResponse(
            success: false,
            messageId: '',
            error: 'Tipo de recordatorio no reconocido: ${recordatorio.tipo}',
            timestamp: DateTime.now(),
          );
      }

      // Actualizar estado del recordatorio
      if (response.success) {
        await _actualizarEstadoRecordatorio(
          recordatorio.id,
          'enviado',
          null,
          messageId: response.messageId,
        );
        // print('✅ Recordatorio ${recordatorio.tipo} enviado a ${cliente['nombre']}');
      } else {
        await _actualizarEstadoRecordatorio(
          recordatorio.id,
          'fallido',
          response.error,
        );
        print('❌ Error enviando recordatorio: ${response.error}');
      }
    } catch (e) {
      await _actualizarEstadoRecordatorio(
        recordatorio.id,
        'fallido',
        e.toString(),
      );
      print('❌ Excepcion enviando recordatorio: $e');
    }
  }

  /// Recordatorio de 7 dias
  static Future<WhatsAppResponse> _enviarRecordatorio7Dias({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final fechaSalidaStr = reserva['fecha_servicio']?.toString() ?? reserva['created_at']?.toString() ?? DateTime.now().toIso8601String();
    final message = WhatsAppMessage(
      to: cliente['telefono'] ?? '+5491166789123',
      templateName: 'recordatorio_semana',
      templateData: {
        'nombre_cliente': cliente['nombre'] ?? 'Cliente',
        'dias_restantes': '7',
        'fecha_salida': _formatDate(DateTime.parse(fechaSalidaStr)),
        'nombre_capitan': capitan['nombre'] ?? 'Capitán',
        'tipo_pesca': reserva['descripcion'] ?? 'pesca embarcada',
        'preparativos': 'Protector solar, ropa cómoda, cámara de fotos',
      },
    );
    return await WhatsAppService.enviarMensaje(message);
  }

  /// Recordatorio de 3 dias
  static Future<WhatsAppResponse> _enviarRecordatorio3Dias({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final fechaSalidaStr = reserva['fecha_servicio']?.toString() ?? reserva['created_at']?.toString() ?? DateTime.now().toIso8601String();
    final hora = reserva['hora_encuentro']?.toString() ?? '08:00';
    final message = WhatsAppMessage(
      to: cliente['telefono'] ?? '+5491166789123',
      templateName: 'recordatorio_tres_dias',
      templateData: {
        'nombre_cliente': cliente['nombre'] ?? 'Cliente',
        'dias_restantes': '3',
        'fecha_salida': _formatDate(DateTime.parse(fechaSalidaStr)),
        'hora_salida': hora,
        'nombre_capitan': capitan['nombre'] ?? 'Capitán',
        'recordatorio': 'Revisá que tus documentos y los de tus acompañantes estén al día',
      },
    );
    return await WhatsAppService.enviarMensaje(message);
  }

  /// Recordatorio de 1 dia
  static Future<WhatsAppResponse> _enviarRecordatorio1Dia({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final fechaSalidaStr = reserva['fecha_servicio']?.toString() ?? reserva['created_at']?.toString() ?? DateTime.now().toIso8601String();
    final hora = reserva['hora_encuentro']?.toString() ?? '08:00';
    final lugar = reserva['lugar_encuentro']?.toString() ?? reserva['localidad_partida']?.toString() ?? 'el punto de encuentro';
    final message = WhatsAppMessage(
      to: cliente['telefono'] ?? '+5491166789123',
      templateName: 'recordatorio_un_dia',
      templateData: {
        'nombre_cliente': cliente['nombre'] ?? 'Cliente',
        'fecha_salida': _formatDate(DateTime.parse(fechaSalidaStr)),
        'hora_salida': hora,
        'lugar': lugar,
        'nombre_capitan': capitan['nombre'] ?? 'Capitán',
        'telefono_capitan': capitan['telefono'] ?? '',
        'mensaje': '¡Prepará todo esta noche! Mañana es el gran día.',
      },
    );
    return await WhatsAppService.enviarMensaje(message);
  }

  // ─── NUEVOS RECORDATORIOS ────────────────────────────────────────────────

  /// 2 horas antes — para el PESCADOR
  /// Es el más crítico: el cliente está saliendo de su casa.
  static Future<WhatsAppResponse> _enviarRecordatorio2Horas({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final hora   = reserva['hora_encuentro']?.toString() ?? '08:00';
    final lugar  = reserva['lugar_encuentro']?.toString() ?? reserva['localidad_partida']?.toString() ?? 'el punto acordado';
    final telCap = capitan['telefono']?.toString() ?? '';
    final nombre = cliente['nombre']?.toString() ?? 'Pescador';
    final nomCap = capitan['nombre']?.toString() ?? 'Tu capitán';
    final pronostico = await _obtenerPronosticoClimaDeReserva(reserva);

    final message = WhatsAppMessage(
      to: cliente['telefono'] ?? '',
      templateName: 'recordatorio_2hs',
      templateData: {
        'nombre_cliente':   nombre,
        'hora_encuentro':   hora,
        'lugar_encuentro':  lugar,
        'nombre_capitan':   nomCap,
        'telefono_capitan': telCap,
        'pronostico':       pronostico,
        'mensaje': '¡Es hora de salir! No olvides tu DNI y el de tus acompañantes.',
      },
    );
    return await WhatsAppService.enviarMensaje(message);
  }

  /// 24 horas antes — para el CAPITÁN
  /// Le avisa que mañana tiene un viaje y le da los datos del cliente.
  static Future<WhatsAppResponse> _enviarRecordatorioCapitan24hs({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final hora       = reserva['hora_encuentro']?.toString() ?? '08:00';
    final lugar      = reserva['lugar_encuentro']?.toString() ?? reserva['localidad_partida']?.toString() ?? '—';
    final personas   = reserva['cantidad_personas']?.toString() ?? '1';
    final nombreCliente = cliente['nombre']?.toString() ?? 'el pescador';
    final telCliente = cliente['telefono']?.toString() ?? '';
    final pronostico = await _obtenerPronosticoClimaDeReserva(reserva);

    final message = WhatsAppMessage(
      to: capitan['telefono'] ?? '',
      templateName: 'capitan_recordatorio_24hs',
      templateData: {
        'nombre_capitan':    capitan['nombre']?.toString() ?? 'Capitán',
        'hora_encuentro':    hora,
        'lugar_encuentro':   lugar,
        'nombre_cliente':    nombreCliente,
        'telefono_cliente':  telCliente,
        'cantidad_personas': personas,
        'pronostico':        pronostico,
        'mensaje': 'Verificá que la embarcación y los servicios prometidos estén listos.',
      },
    );
    return await WhatsAppService.enviarMensaje(message);
  }

  /// 2 horas antes — para el CAPITÁN
  /// Le envía la foto + DNI del pescador titular para reconocerlo.
  static Future<WhatsAppResponse> _enviarRecordatorioCapitan2hs({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final hora       = reserva['hora_encuentro']?.toString() ?? '08:00';
    final lugar      = reserva['lugar_encuentro']?.toString() ?? reserva['localidad_partida']?.toString() ?? '—';
    final nombreCliente = cliente['nombre']?.toString() ?? 'el pescador';
    final telCliente = cliente['telefono']?.toString() ?? '';
    final dniCliente = cliente['dni']?.toString() ?? '—';

    final message = WhatsAppMessage(
      to: capitan['telefono'] ?? '',
      templateName: 'capitan_recordatorio_2hs',
      templateData: {
        'nombre_capitan':   capitan['nombre']?.toString() ?? 'Capitán',
        'hora_encuentro':   hora,
        'lugar_encuentro':  lugar,
        'nombre_cliente':   nombreCliente,
        'telefono_cliente': telCliente,
        'dni_cliente':      dniCliente,
        'mensaje': '¡Es hora de prepararse! El cliente ya está en camino.',
      },
    );
    return await WhatsAppService.enviarMensaje(message);
  }

  /// Crear todos los recordatorios para un viaje confirmado
  /// Incluye recordatorios para el PESCADOR y para el CAPITÁN
  static Future<void> crearRecordatoriosReserva({
    required String reservaId,
    required String clienteId,
    required DateTime fechaSalida,
  }) async {
    try {
      final ahora = DateTime.now();

      /// Helper: solo agrega si la fecha programada es futura
      Map<String, dynamic>? _rec(String tipo, DateTime cuando, {String? destinatarioId}) {
        if (cuando.isBefore(ahora)) return null; // ya pasó, no tiene sentido
        return {
          'reserva_id':       reservaId,
          'cliente_id':       destinatarioId ?? clienteId,
          'tipo':             tipo,
          'fecha_programada': cuando.toIso8601String(),
          'fecha_envio':      ahora.toIso8601String(),
          'estado':           'pendiente',
        };
      }

      // ─── RECORDATORIOS PARA EL PESCADOR (cliente) ─────────────────────────
      final todos = <Map<String, dynamic>>[];

      final r7d   = _rec('7dias',  fechaSalida.subtract(const Duration(days: 7)));
      final r3d   = _rec('3dias',  fechaSalida.subtract(const Duration(days: 3)));
      final r24h  = _rec('24hs',   fechaSalida.subtract(const Duration(hours: 24)));
      final r12h  = _rec('12hs',   fechaSalida.subtract(const Duration(hours: 12)));
      final r2h   = _rec('2hs',    fechaSalida.subtract(const Duration(hours: 2)));   // ← NUEVO

      if (r7d  != null) todos.add(r7d);
      if (r3d  != null) todos.add(r3d);
      if (r24h != null) todos.add(r24h);
      if (r12h != null) todos.add(r12h);
      if (r2h  != null) todos.add(r2h);

      // ─── RECORDATORIOS PARA EL CAPITÁN ───────────────────────────────────
      // Obtenemos el capitanId del pedido para saber a quién notificar
      try {
        final pedido = await SupabaseService.supabase
            .from('pedidos')
            .select('capitan_id')
            .eq('id', reservaId)
            .maybeSingle();

        final capitanId = pedido?['capitan_id']?.toString();
        if (capitanId != null && capitanId.isNotEmpty) {
          final rc24h = _rec('capitan_24hs', fechaSalida.subtract(const Duration(hours: 24)),
              destinatarioId: capitanId);
          final rc2h  = _rec('capitan_2hs',  fechaSalida.subtract(const Duration(hours: 2)),
              destinatarioId: capitanId);
          if (rc24h != null) todos.add(rc24h);
          if (rc2h  != null) todos.add(rc2h);
        }
      } catch (_) {
        // Si no encontramos el capitán, continuamos con los del pescador
      }

      if (todos.isEmpty) {
        print('⚠️ No se crearon recordatorios: el viaje es inminente o ya pasó');
        return;
      }

      await SupabaseService.supabase
          .from('recordatorios')
          .insert(todos);

      print('✅ ${todos.length} recordatorios creados para el viaje $reservaId');
      print('   Pescador: ${todos.where((r) => !r['tipo'].toString().startsWith('capitan')).length} recordatorios');
      print('   Capitán:  ${todos.where((r) => r['tipo'].toString().startsWith('capitan')).length} recordatorios');
    } catch (e) {
      print('❌ Error creando recordatorios: $e');
    }
  }

  /// Cancelar recordatorios de una reserva
  static Future<void> cancelarRecordatoriosReserva(String reservaId) async {
    try {
      await SupabaseService.supabase
          .from('recordatorios')
          .update({'estado': 'cancelado'})
          .eq('reserva_id', reservaId)
          .eq('estado', 'pendiente');

      print('✅ Recordatorios cancelados para la reserva $reservaId');
    } catch (e) {
      print('❌ Error cancelando recordatorios: $e');
    }
  }

  /// Actualizar estado de un recordatorio
  static Future<void> _actualizarEstadoRecordatorio(
    String recordatorioId,
    String estado,
    String? error, {
    String? messageId,
  }) async {
    try {
      final updateData = {
        'estado': estado,
        'fecha_envio': DateTime.now().toIso8601String(),
      };

      if (messageId != null) {
        updateData['mensaje_id'] = messageId;
      }

      if (error != null) {
        updateData['error'] = error;
      }

      await SupabaseService.supabase
          .from('recordatorios')
          .update(updateData)
          .eq('id', recordatorioId);
    } catch (e) {
      print('❌ Error actualizando estado del recordatorio: $e');
    }
  }

  /// Obtener datos del pedido (antes buscaba en tabla 'reservas' que no existe)
  static Future<Map<String, dynamic>?> _obtenerReserva(String pedidoId) async {
    try {
      // El pedido incluye la cotización para tener hora_encuentro, lugar_encuentro, etc.
      final pedido = await SupabaseService.supabase
          .from('pedidos')
          .select('*, cotizaciones(descripcion, hora_encuentro, lugar_encuentro, '
                  'localidad_partida, fecha_ida, cantidad_personas)')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido == null) return null;

      // Aplanar los datos de la cotización para fácil acceso
      final cot = pedido['cotizaciones'] as Map<String, dynamic>?;
      if (cot != null) {
        pedido['hora_encuentro']   ??= cot['hora_encuentro'];
        pedido['lugar_encuentro']  ??= cot['lugar_encuentro'];
        pedido['localidad_partida']??= cot['localidad_partida'];
        pedido['fecha_servicio']   ??= cot['fecha_ida'];
        pedido['cantidad_personas']??= cot['cantidad_personas'];
        pedido['descripcion']      ??= cot['descripcion'];
      }

      return Map<String, dynamic>.from(pedido);
    } catch (e) {
      print('⚠️ Error obteniendo pedido $pedidoId: $e');
      return null;
    }
  }

  /// Obtener pronóstico del clima desde las coordenadas del pedido
  static Future<String> _obtenerPronosticoClimaDeReserva(Map<String, dynamic> reserva) async {
    try {
      // Intentar usar coordenadas reales del pedido
      double lat = -34.6037; // Buenos Aires por defecto
      double lon = -58.3816;

      final cot = reserva['cotizaciones'] as Map<String, dynamic>?;
      final coordStr = cot?['coordenadas_partida'];
      if (coordStr is Map) {
        lat = (coordStr['lat'] as num?)?.toDouble() ?? lat;
        lon = (coordStr['lng'] as num?)?.toDouble() ?? lon;
      }

      final weather = await WeatherService.fetchMarineWeather(lat, lon);
      return '🌤️ ${weather.descripcion}. '
             'Temp: ${weather.temperatura.toStringAsFixed(1)}°C, '
             'Viento: ${weather.velocidadViento.toStringAsFixed(0)}km/h, '
             'Olas: ${weather.alturaOlas.toStringAsFixed(1)}m.';
    } catch (_) {
      return '☀️ Consultá el clima antes de salir.';
    }
  }

  /// Obtener pronóstico del clima por nombre de ubicación (legacy)
  static Future<String> _obtenerPronosticoClima(String ubicacion) async {
    double lat = -34.442;
    double lon = -58.558;

    switch (ubicacion.toLowerCase().replaceAll(' ', '_')) {
      case 'mar_del_plata':
        lat = -38.005;
        lon = -57.542;
        break;
      case 'puerto_madryn':
        lat = -42.769;
        lon = -65.038;
        break;
      case 'san_clemente':
        lat = -36.357;
        lon = -56.721;
        break;
      case 'tigre':
      case 'san_fernando':
        lat = -34.442;
        lon = -58.558;
        break;
    }

    try {
      final weather = await WeatherService.fetchMarineWeather(lat, lon);
      return '🌤️ ${weather.descripcion}. Temp: ${weather.temperatura.toStringAsFixed(1)}°C, viento: ${weather.velocidadViento.toStringAsFixed(1)}km/h, olas: ${weather.alturaOlas.toStringAsFixed(1)}m. Humedad: ${weather.humedad}%, Presión: ${weather.presion.toStringAsFixed(0)} hPa.';
    } catch (e) {
      return '☀️ Buen tiempo para la pesca. Temperatura agradable.';
    }
  }

  /// Formatear fecha
  static String _formatDate(DateTime date) {
    final dias = ['Lunes', 'Martes', 'Miercoles', 'Jueves', 'Viernes', 'Sabado', 'Domingo'];
    final meses = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 
                   'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    
    return '${dias[date.weekday - 1]} ${date.day} de ${meses[date.month - 1]}';
  }

  /// Obtener recordatorios de un cliente
  static Future<List<Recordatorio>> obtenerRecordatoriosCliente(String clienteId) async {
    try {
      final response = await SupabaseService.supabase
          .from('recordatorios')
          .select()
          .eq('cliente_id', clienteId)
          .order('fecha_programada', ascending: false);

      return response.map((r) => Recordatorio.fromSupabase(r)).toList();
    } catch (e) {
      throw Exception('Error obteniendo recordatorios del cliente: $e');
    }
  }

  /// Obtener estadisticas de recordatorios
  static Future<Map<String, dynamic>> obtenerEstadisticasRecordatorios() async {
    try {
      final hoy = DateTime.now();
      final inicioMes = DateTime(hoy.year, hoy.month, 1);

      final response = await SupabaseService.supabase
          .from('recordatorios')
          .select()
          .gte('fecha_envio', inicioMes.toIso8601String())
          .lte('fecha_envio', hoy.toIso8601String());

      final recordatorios = response.map((r) => Recordatorio.fromSupabase(r)).toList();

      final enviados = recordatorios.where((r) => r.estado == 'enviado').length;
      final fallidos = recordatorios.where((r) => r.estado == 'fallido').length;
      final pendientes = recordatorios.where((r) => r.estado == 'pendiente').length;

      return {
        'total_mes': recordatorios.length,
        'enviados': enviados,
        'fallidos': fallidos,
        'pendientes': pendientes,
        'tasa_exito': recordatorios.isNotEmpty ? enviados / recordatorios.length : 0,
      };
    } catch (e) {
      throw Exception('Error obteniendo estadisticas: $e');
    }
  }

  /// Reenviar recordatorio fallido
  static Future<bool> reenviarRecordatorio(String recordatorioId) async {
    try {
      final response = await SupabaseService.supabase
          .from('recordatorios')
          .select()
          .eq('id', recordatorioId)
          .single();

      final recordatorio = Recordatorio.fromSupabase(response);

      if (recordatorio.estado != 'fallido') {
        return false;
      }

      // Resetear a pendiente y procesar nuevamente
      await SupabaseService.supabase
          .from('recordatorios')
          .update({
            'estado': 'pendiente',
            'fecha_envio': DateTime.now().toIso8601String(),
            'error': null,
          })
          .eq('id', recordatorioId);

      // Procesar inmediatamente
      await _enviarRecordatorio(recordatorio);

      return true;
    } catch (e) {
      print('❌ Error reenviando recordatorio: $e');
      return false;
    }
  }

  /// Verificar estado del scheduler
  static bool isSchedulerRunning() => _isRunning;

  /// Obtener proximos recordatorios
  static Future<List<Recordatorio>> obtenerProximosRecordatorios() async {
    try {
      final ahora = DateTime.now();
      final response = await SupabaseService.supabase
          .from('recordatorios')
          .select()
          .eq('estado', 'pendiente')
          .gte('fecha_programada', ahora.toIso8601String())
          .order('fecha_programada', ascending: true)
          .limit(10);

      return response.map((r) => Recordatorio.fromSupabase(r)).toList();
    } catch (e) {
      throw Exception('Error obteniendo proximos recordatorios: $e');
    }
  }
}
