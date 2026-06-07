

import 'dart:async';


import 'seguridad_service.dart';
import 'supabase_service.dart';
import 'whatsapp_service.dart';
import 'weather_service.dart';

class Recordatorio {
  final String id;
  final String reservaId;
  final String clienteId;
  final String tipo; // '24hs', '7dias', '3dias', '1dia'
  final DateTime fechaProgramada;
  final DateTime fechaEnvio;
  final String estado; // 'pendiente', 'enviado', 'fallido'
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
            fechaSalida: DateTime.parse(reserva['fecha_salida']),
            horaSalida: reserva['hora_salida'] ?? '08:00',
            puntoEncuentro: reserva['punto_encuentro'] ?? 'Puerto',
            nombreCapitan: capitan['nombre'] ?? 'Capitan',
            telefonoCapitan: capitan['telefono'] ?? '+5491166789456',
            whatsappCapitan: capitan['telefono'] ?? '+5491166789456',
            pronosticoClima: await _obtenerPronosticoClima(reserva['ubicacion'] ?? 'mar_del_plata'),
          );
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
          response = await _enviarRecordatorio1Dia(
            cliente: cliente,
            reserva: reserva,
            capitan: capitan,
          );
          break;

        default:
          response = WhatsAppResponse(
            success: false,
            messageId: '',
            error: 'Tipo de recordatorio no reconocido',
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

  /// Enviar recordatorio de 7 dias
  static Future<WhatsAppResponse> _enviarRecordatorio7Dias({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final message = WhatsAppMessage(
      to: cliente['telefono'] ?? '+5491166789123',
      templateName: 'recordatorio_semana',
      templateData: {
        'nombre_cliente': cliente['nombre'] ?? 'Cliente',
        'dias_restantes': '7',
        'fecha_salida': _formatDate(DateTime.parse(reserva['fecha_salida'])),
        'nombre_capitan': capitan['nombre'] ?? 'Capitan',
        'tipo_pesca': reserva['tipo_pesca'] ?? 'embarcada',
        'preparativos': 'Protector solar, ropa comoda, camara',
      },
    );

    return await WhatsAppService.enviarMensaje(message);
  }

  /// Enviar recordatorio de 3 dias
  static Future<WhatsAppResponse> _enviarRecordatorio3Dias({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final message = WhatsAppMessage(
      to: cliente['telefono'] ?? '+5491166789123',
      templateName: 'recordatorio_tres_dias',
      templateData: {
        'nombre_cliente': cliente['nombre'] ?? 'Cliente',
        'dias_restantes': '3',
        'fecha_salida': _formatDate(DateTime.parse(reserva['fecha_salida'])),
        'hora_salida': reserva['hora_salida'] ?? '08:00',
        'nombre_capitan': capitan['nombre'] ?? 'Capitan',
        'recordatorio_pago': 'Asegurate de tener el pago confirmado',
      },
    );

    return await WhatsAppService.enviarMensaje(message);
  }

  /// Enviar recordatorio de 1 dia
  static Future<WhatsAppResponse> _enviarRecordatorio1Dia({
    required dynamic cliente,
    required dynamic reserva,
    required dynamic capitan,
  }) async {
    final message = WhatsAppMessage(
      to: cliente['telefono'] ?? '+5491166789123',
      templateName: 'recordatorio_un_dia',
      templateData: {
        'nombre_cliente': cliente['nombre'] ?? 'Cliente',
        'dias_restantes': '1',
        'fecha_salida': _formatDate(DateTime.parse(reserva['fecha_salida'])),
        'hora_salida': reserva['hora_salida'] ?? '08:00',
        'nombre_capitan': capitan['nombre'] ?? 'Capitan',
        'ultimo_recordatorio': '¡Manana es el dia!',
      },
    );

    return await WhatsAppService.enviarMensaje(message);
  }

  /// Crear recordatorios para una nueva reserva
  static Future<void> crearRecordatoriosReserva({
    required String reservaId,
    required String clienteId,
    required DateTime fechaSalida,
  }) async {
    try {
      final recordatorios = [
        // Recordatorio de 7 dias
        {
          'reserva_id': reservaId,
          'cliente_id': clienteId,
          'tipo': '7dias',
          'fecha_programada': fechaSalida.subtract(const Duration(days: 7)).toIso8601String(),
          'fecha_envio': DateTime.now().toIso8601String(),
          'estado': 'pendiente',
        },
        // Recordatorio de 3 dias
        {
          'reserva_id': reservaId,
          'cliente_id': clienteId,
          'tipo': '3dias',
          'fecha_programada': fechaSalida.subtract(const Duration(days: 3)).toIso8601String(),
          'fecha_envio': DateTime.now().toIso8601String(),
          'estado': 'pendiente',
        },
        // Recordatorio de 24 horas
        {
          'reserva_id': reservaId,
          'cliente_id': clienteId,
          'tipo': '24hs',
          'fecha_programada': fechaSalida.subtract(const Duration(hours: 24)).toIso8601String(),
          'fecha_envio': DateTime.now().toIso8601String(),
          'estado': 'pendiente',
        },
        // Recordatorio de 1 dia (mismo dia)
        {
          'reserva_id': reservaId,
          'cliente_id': clienteId,
          'tipo': '1dia',
          'fecha_programada': fechaSalida.subtract(const Duration(hours: 12)).toIso8601String(),
          'fecha_envio': DateTime.now().toIso8601String(),
          'estado': 'pendiente',
        },
      ];

      // Insertar todos los recordatorios
      await SupabaseService.supabase
          .from('recordatorios')
          .insert(recordatorios);

      print('✅ ${recordatorios.length} recordatorios creados para la reserva $reservaId');
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

  /// Obtener reserva
  static Future<Map<String, dynamic>?> _obtenerReserva(String reservaId) async {
    try {
      final response = await SupabaseService.supabase
          .from('reservas')
          .select()
          .eq('id', reservaId)
          .maybeSingle();

      return response;
    } catch (e) {
      return null;
    }
  }

  /// Obtener pronostico del clima real
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
