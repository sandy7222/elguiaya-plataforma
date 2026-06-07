

import 'dart:async';

import 'seguridad_service.dart';
import 'supabase_service.dart';
import 'whatsapp_service.dart';
import 'mercado_pago_service.dart';

class Pago {
  final String id;
  final String reservaId;
  final String clienteId;
  final double monto;
  final String metodoPago;
  final DateTime fechaPago;
  final String estado; // 'pendiente', 'confirmado', 'fallido'
  final String? transaccionId;
  final String? codigoAcceso;

  Pago({
    required this.id,
    required this.reservaId,
    required this.clienteId,
    required this.monto,
    required this.metodoPago,
    required this.fechaPago,
    required this.estado,
    this.transaccionId,
    this.codigoAcceso,
  });

  factory Pago.fromSupabase(Map<String, dynamic> data) {
    return Pago(
      id: data['id'].toString(),
      reservaId: data['reserva_id'].toString(),
      clienteId: data['cliente_id'].toString(),
      monto: (data['monto'] as num).toDouble(),
      metodoPago: data['metodo_pago'] ?? '',
      fechaPago: DateTime.parse(data['fecha_pago']),
      estado: data['estado'] ?? 'pendiente',
      transaccionId: data['transaccion_id'],
      codigoAcceso: data['codigo_acceso'],
    );
  }
}

/// Modelo de reserva para confirmacion
class ReservaConfirmacion {
  final String id;
  final String clienteId;
  final String capitanId;
  final DateTime fechaSalida;
  final String horaSalida;
  final String puntoEncuentro;
  final double precio;
  final String estado;

  ReservaConfirmacion({
    required this.id,
    required this.clienteId,
    required this.capitanId,
    required this.fechaSalida,
    required this.horaSalida,
    required this.puntoEncuentro,
    required this.precio,
    required this.estado,
  });
}

/// Servicio de procesamiento de pagos con confirmacion instantanea
class PagoService {
  static const Duration _timeoutConfirmacion = Duration(seconds: 30);

  /// Procesar pago con confirmacion instantanea
  static Future<Map<String, dynamic>> procesarPago({
    required String reservaId,
    required String clienteId,
    required double monto,
    required String metodoPago,
    required String numeroTarjeta, // Ultimos 4 digitos
    required String nombreTitular,
  }) async {
    try {
      // 1. Validar datos de entrada
      _validarDatosPago(monto, metodoPago, numeroTarjeta, nombreTitular);

      // 2. Obtener detalles de la reserva
      final reserva = await _obtenerReserva(reservaId);
      if (reserva == null) {
        throw Exception('Reserva no encontrada');
      }

      // 3. Verificar que el cliente sea el dueno de la reserva
      if (reserva.clienteId != clienteId) {
        throw Exception('No autorizado para procesar este pago');
      }

      // 4. Simular procesamiento de pago (en produccion integrar con pasarela)
      final resultadoPago = await _procesarPasarelaPago(
        monto: monto,
        metodoPago: metodoPago,
        numeroTarjeta: numeroTarjeta,
        nombreTitular: nombreTitular,
      );

      if (!resultadoPago['aprobado']) {
        return {
          'success': false,
          'error': resultadoPago['mensaje_error'] ?? 'Pago rechazado',
          'estado': 'fallido',
        };
      }

      // 5. Guardar pago en base de datos
      final pago = await _guardarPago(
        reservaId: reservaId,
        clienteId: clienteId,
        monto: monto,
        metodoPago: metodoPago,
        transaccionId: resultadoPago['transaccion_id'],
        estado: 'confirmado',
      );

      // 6. Generar codigo de acceso
      final codigoAcceso = _generarCodigoAcceso();

      // 7. Actualizar estado de la reserva
      await _actualizarEstadoReserva(reservaId, 'pagada');

      // 8. Obtener datos del cliente y capitan
      final cliente = await SeguridadService.getUsuarioPorId(clienteId);
      final capitan = await SeguridadService.getUsuarioPorId(reserva.capitanId);

      // 9. Enviar confirmacion instantanea por WhatsApp
      await _enviarConfirmacionInstantanea(
        pago: pago,
        reserva: reserva,
        cliente: cliente,
        capitan: capitan,
        codigoAcceso: codigoAcceso,
      );

      // 10. Programar recordatorio automatico
      await _programarRecordatorio(reserva, cliente);

      return {
        'success': true,
        'pago_id': pago.id,
        'transaccion_id': resultadoPago['transaccion_id'],
        'codigo_acceso': codigoAcceso,
        'estado': 'confirmado',
        'mensaje': 'Pago procesado exitosamente',
      };

    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'estado': 'fallido',
      };
    }
  }

  /// Validar datos de pago
  static void _validarDatosPago(
    double monto,
    String metodoPago,
    String numeroTarjeta,
    String nombreTitular,
  ) {
    if (monto <= 0) {
      throw Exception('El monto debe ser mayor a cero');
    }

    if (monto > 100000) {
      throw Exception('El monto excede el limite permitido');
    }

    final metodosValidos = ['tarjeta_credito', 'tarjeta_debito', 'transferencia', 'mercado_pago'];
    if (!metodosValidos.contains(metodoPago)) {
      throw Exception('Metodo de pago no valido');
    }

    if (numeroTarjeta.length != 4 || !RegExp(r'^\d{4}$').hasMatch(numeroTarjeta)) {
      throw Exception('Numero de tarjeta invalido');
    }

    if (nombreTitular.trim().isEmpty) {
      throw Exception('El nombre del titular es requerido');
    }
  }

  /// Obtener detalles de reserva
  static Future<ReservaConfirmacion?> _obtenerReserva(String reservaId) async {
    try {
      // En produccion, consultar Supabase
      final response = await SupabaseService.supabase
          .from('reservas')
          .select()
          .eq('id', reservaId)
          .maybeSingle();

      if (response == null) return null;

      return ReservaConfirmacion(
        id: response['id'].toString(),
        clienteId: response['cliente_id'].toString(),
        capitanId: response['capitan_id'].toString(),
        fechaSalida: DateTime.parse(response['fecha_salida']),
        horaSalida: response['hora_salida'] ?? '08:00',
        puntoEncuentro: response['punto_encuentro'] ?? 'Puerto',
        precio: (response['precio'] as num).toDouble(),
        estado: response['estado'] ?? 'pendiente',
      );
    } catch (e) {
      return null;
    }
  }

  /// Simular procesamiento de pasarela de pago
  static Future<Map<String, dynamic>> _procesarPasarelaPago({
    required double monto,
    required String metodoPago,
    required String numeroTarjeta,
    required String nombreTitular,
  }) async {
    // Simular delay de procesamiento
    await Future.delayed(const Duration(seconds: 2));

    // Simular validacion de tarjeta (90% de aprobacion)
    final random = DateTime.now().millisecond % 100;
    final aprobado = random < 90;

    if (aprobado) {
      return {
        'aprobado': true,
        'transaccion_id': 'TXN_${DateTime.now().millisecondsSinceEpoch}',
        'autorizacion': random.toString().padLeft(6, '0'),
        'mensaje': 'Transaccion aprobada',
      };
    } else {
      return {
        'aprobado': false,
        'mensaje_error': random < 95 
            ? 'Fondos insuficientes' 
            : 'Tarjeta rechazada por el banco emisor',
      };
    }
  }

  /// Guardar pago en base de datos
  static Future<Pago> _guardarPago({
    required String reservaId,
    required String clienteId,
    required double monto,
    required String metodoPago,
    required String transaccionId,
    required String estado,
  }) async {
    try {
      final response = await SupabaseService.supabase
          .from('pagos')
          .insert({
            'reserva_id': reservaId,
            'cliente_id': clienteId,
            'monto': monto,
            'metodo_pago': metodoPago,
            'fecha_pago': DateTime.now().toIso8601String(),
            'transaccion_id': transaccionId,
            'estado': estado,
          })
          .select()
          .single();

      return Pago.fromSupabase(response);
    } catch (e) {
      throw Exception('Error al guardar pago: $e');
    }
  }

  /// Generar codigo de acceso unico
  static String _generarCodigoAcceso() {
    final random = DateTime.now().millisecondsSinceEpoch;
    final codigo = (random % 1000000).toString().padLeft(6, '0');
    return 'CYA_$codigo';
  }

  /// Actualizar estado de reserva
  static Future<void> _actualizarEstadoReserva(String reservaId, String estado) async {
    try {
      await SupabaseService.supabase
          .from('reservas')
          .update({'estado': estado})
          .eq('id', reservaId);
    } catch (e) {
      throw Exception('Error al actualizar reserva: $e');
    }
  }

  /// Enviar confirmacion instantanea por WhatsApp
  static Future<void> _enviarConfirmacionInstantanea({
    required Pago pago,
    required ReservaConfirmacion reserva,
    required dynamic cliente,
    required dynamic capitan,
    required String codigoAcceso,
  }) async {
    try {
      final response = await WhatsAppService.enviarConfirmacionPago(
        telefonoCliente: cliente?.telefono ?? '+5491166789123',
        nombreCliente: cliente?.nombre ?? 'Cliente',
        codigoReserva: reserva.id,
        monto: pago.monto,
        fechaPago: pago.fechaPago,
        metodoPago: pago.metodoPago,
        nombreCapitan: capitan?.nombre ?? 'Capitan',
        fechaSalida: reserva.fechaSalida,
        horaSalida: reserva.horaSalida,
        puntoEncuentro: reserva.puntoEncuentro,
        codigoAcceso: codigoAcceso,
      );

      if (!response.success) {
        print('Error enviando confirmacion WhatsApp: ${response.error}');
      }
    } catch (e) {
      print('Excepcion enviando confirmacion: $e');
    }
  }

  /// Programar recordatorio automatico
  static Future<void> _programarRecordatorio(
    ReservaConfirmacion reserva,
    dynamic cliente,
  ) async {
    try {
      // Programar recordatorio para 24 horas antes
      final fechaRecordatorio = reserva.fechaSalida.subtract(const Duration(hours: 24));
      
      // En produccion, usar un sistema de colas como Redis o Firebase Cloud Functions
      // Por ahora, simulamos programacion
      print('Recordatorio programado para ${fechaRecordatorio.toString()}');
      
      // Tambien programamos recordatorios adicionales
      await _programarRecordatoriosAdicionales(reserva, cliente);
    } catch (e) {
      print('Error programando recordatorio: $e');
    }
  }

  /// Programar recordatorios adicionales
  static Future<void> _programarRecordatoriosAdicionales(
    ReservaConfirmacion reserva,
    dynamic cliente,
  ) async {
    // Recordatorio de 7 dias antes
    final recordatorio7Dias = reserva.fechaSalida.subtract(const Duration(days: 7));
    if (recordatorio7Dias.isAfter(DateTime.now())) {
      print('Recordatorio de 7 dias programado: ${recordatorio7Dias.toString()}');
    }

    // Recordatorio de 3 dias antes
    final recordatorio3Dias = reserva.fechaSalida.subtract(const Duration(days: 3));
    if (recordatorio3Dias.isAfter(DateTime.now())) {
      print('Recordatorio de 3 dias programado: ${recordatorio3Dias.toString()}');
    }

    // Recordatorio de 1 dia antes (ya programado arriba)
    final recordatorio1Dia = reserva.fechaSalida.subtract(const Duration(days: 1));
    if (recordatorio1Dia.isAfter(DateTime.now())) {
      print('Recordatorio de 1 dia programado: ${recordatorio1Dia.toString()}');
    }
  }

  /// Obtener historial de pagos de un cliente
  static Future<List<Pago>> obtenerHistorialPagos(String clienteId) async {
    try {
      final response = await SupabaseService.supabase
          .from('pagos')
          .select()
          .eq('cliente_id', clienteId)
          .order('fecha_pago', ascending: false);

      return response.map((pago) => Pago.fromSupabase(pago)).toList();
    } catch (e) {
      throw Exception('Error al obtener historial de pagos: $e');
    }
  }

  /// Obtener detalles de un pago especifico
  static Future<Pago?> obtenerPago(String pagoId) async {
    try {
      final response = await SupabaseService.supabase
          .from('pagos')
          .select()
          .eq('id', pagoId)
          .maybeSingle();

      if (response == null) return null;
      return Pago.fromSupabase(response);
    } catch (e) {
      throw Exception('Error al obtener pago: $e');
    }
  }

  /// Solicitar reembolso
  static Future<Map<String, dynamic>> solicitarReembolso({
    required String pagoId,
    required String motivo,
  }) async {
    try {
      final pago = await obtenerPago(pagoId);
      if (pago == null) {
        throw Exception('Pago no encontrado');
      }

      if (pago.estado != 'confirmado') {
        throw Exception('Solo se pueden reembolsar pagos confirmados');
      }

      // Verificar politica de reembolso (ej: hasta 48hs antes)
      final reserva = await _obtenerReserva(pago.reservaId);
      if (reserva != null) {
        final tiempoParaSalida = reserva.fechaSalida.difference(DateTime.now());
        if (tiempoParaSalida.inHours < 48) {
          return {
            'success': false,
            'error': 'No se puede reembolsar: falta menos de 48 horas para la salida',
          };
        }
      }

      // Procesar reembolso real si es de Mercado Pago
      if (pago.metodoPago == 'mercado_pago' && pago.transaccionId != null && pago.transaccionId!.isNotEmpty) {
        final refundResult = await MercadoPagoService.reembolsarPago(
          paymentId: pago.transaccionId!,
          amount: pago.monto,
        );
        if (refundResult['success'] != true) {
          throw Exception('La pasarela de Mercado Pago rechazó el reembolso.');
        }
      } else {
        // Procesar reembolso (simulado para otros métodos)
        await Future.delayed(const Duration(seconds: 1));
      }

      // Actualizar estado del pago
      await SupabaseService.supabase
          .from('pagos')
          .update({'estado': 'reembolsado'})
          .eq('id', pagoId);

      // Actualizar estado de reserva
      await _actualizarEstadoReserva(pago.reservaId, 'cancelada');

      // Registrar log en el sistema
      await SupabaseService.registrarLogSistema(
        tipo: 'reembolso_pago_exito',
        descripcion: 'Reembolso procesado para pago ID $pagoId. Monto: \$${pago.monto}. Motivo: $motivo',
        datosAdicionales: {
          'pago_id': pagoId,
          'reserva_id': pago.reservaId,
          'metodo_pago': pago.metodoPago,
          'transaccion_id': pago.transaccionId,
          'monto': pago.monto,
          'motivo': motivo,
        },
      );

      // Notificar al pescador sobre su reembolso (Sincronización Automática con Motivo Dinámico)
      if (reserva != null && reserva.clienteId.isNotEmpty) {
        await SupabaseService.enviarNotificacion(
          usuarioId: reserva.clienteId,
          titulo: 'Reembolso en Proceso 💸',
          mensaje: 'Se ha procesado el reembolso de \$${pago.monto} por la cancelación de tu salida. Motivo: $motivo',
          tipo: 'comercial',
        );
      }

      return {
        'success': true,
        'mensaje': 'Reembolso procesado exitosamente',
        'monto_reembolsado': pago.monto,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Obtener estadisticas de pagos
  static Future<Map<String, dynamic>> obtenerEstadisticasPagos() async {
    try {
      final hoy = DateTime.now();
      final inicioMes = DateTime(hoy.year, hoy.month, 1);

      // Pagos del mes actual
      final response = await SupabaseService.supabase
          .from('pagos')
          .select()
          .gte('fecha_pago', inicioMes.toIso8601String())
          .lte('fecha_pago', hoy.toIso8601String());

      final pagos = response.map((pago) => Pago.fromSupabase(pago)).toList();

      final totalPagos = pagos.length;
      final montoTotal = pagos.fold<double>(0, (sum, pago) => sum + pago.monto);
      final pagosConfirmados = pagos.where((p) => p.estado == 'confirmado').length;
      final pagosFallidos = pagos.where((p) => p.estado == 'fallido').length;

      return {
        'total_pagos_mes': totalPagos,
        'monto_total_mes': montoTotal,
        'pagos_confirmados': pagosConfirmados,
        'pagos_fallidos': pagosFallidos,
        'tasa_aprobacion': totalPagos > 0 ? pagosConfirmados / totalPagos : 0,
        'promedio_monto': totalPagos > 0 ? montoTotal / totalPagos : 0,
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas: $e');
    }
  }

  /// Verificar estado de un pago
  static Future<String> verificarEstadoPago(String transaccionId) async {
    try {
      final response = await SupabaseService.supabase
          .from('pagos')
          .select('estado')
          .eq('transaccion_id', transaccionId)
          .maybeSingle();

      return response?['estado'] ?? 'no_encontrado';
    } catch (e) {
      return 'error';
    }
  }

  /// Formatear monto para display
  static String formatearMonto(double monto) {
    return '\$${monto.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  /// Obtener metodo de pago formateado
  static String formatearMetodoPago(String metodo) {
    switch (metodo) {
      case 'tarjeta_credito':
        return 'Tarjeta de Credito';
      case 'tarjeta_debito':
        return 'Tarjeta de Debito';
      case 'transferencia':
        return 'Transferencia Bancaria';
      case 'mercado_pago':
        return 'Mercado Pago';
      default:
        return metodo.toUpperCase();
    }
  }
}
