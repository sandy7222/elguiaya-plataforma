import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';
import 'package:http/http.dart' as http;

class MercadoPagoWebhookService {
  
  /// Procesa notificaciones de Mercado Pago
  static Future<Map<String, dynamic>> procesarWebhook(Map<String, dynamic> webhookData) async {
    try {
      final action = webhookData['action'] ?? '';
      final data = webhookData['data'] ?? {};
      final id = data['id']?.toString();

      if (id == null || id.isEmpty) {
        throw Exception('ID de pago no proporcionado');
      }

      // Obtener detalles del pago desde Mercado Pago
      final paymentDetails = await _obtenerDetallesPago(id);
      
      // Procesar segun el tipo de accion
      switch (action) {
        case 'payment.created':
          return await _procesarPagoCreado(paymentDetails);
        case 'payment.updated':
          return await _procesarPagoActualizado(paymentDetails);
        default:
          throw Exception('Accion no soportada: $action');
      }
    } catch (e) {
      throw Exception('Error procesando webhook: $e');
    }
  }

  /// Obtiene detalles del pago desde API de Mercado Pago
  static Future<Map<String, dynamic>> _obtenerDetallesPago(String paymentId) async {
    try {
      // En produccion, usar access token real
      final accessToken = 'TEST_ACCESS_TOKEN'; // Reemplazar con token real
      
      final response = await http.get(
        Uri.parse('https://api.mercadopago.com/v1/payments/$paymentId'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Error obteniendo detalles del pago: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error en API de Mercado Pago: $e');
    }
  }

  /// Procesa pago creado
  static Future<Map<String, dynamic>> _procesarPagoCreado(Map<String, dynamic> paymentDetails) async {
    try {
      final status = paymentDetails['status'] ?? '';
      final externalReference = paymentDetails['external_reference']?.toString() ?? '';
      
      if (externalReference.isEmpty) {
        throw Exception('External reference no proporcionado');
      }

      // Buscar reserva correspondiente
      final reserva = await _buscarReservaPorExternalReference(externalReference);
      
      if (reserva == null) {
        throw Exception('Reserva no encontrada para external_reference: $externalReference');
      }

      // Actualizar estado segun el pago
      final nuevoEstado = _determinarEstadoReserva(status);
      
      await _actualizarEstadoReserva(reserva['id'], nuevoEstado, paymentDetails);

      return {
        'success': true,
        'message': 'Pago creado procesado',
        'reserva_id': reserva['id'],
        'estado_actualizado': nuevoEstado,
        'payment_status': status,
      };
    } catch (e) {
      throw Exception('Error procesando pago creado: $e');
    }
  }

  /// Procesa pago actualizado
  static Future<Map<String, dynamic>> _procesarPagoActualizado(Map<String, dynamic> paymentDetails) async {
    try {
      final status = paymentDetails['status'] ?? '';
      final externalReference = paymentDetails['external_reference']?.toString() ?? '';
      
      if (externalReference.isEmpty) {
        throw Exception('External reference no proporcionado');
      }

      // Buscar reserva correspondiente
      final reserva = await _buscarReservaPorExternalReference(externalReference);
      
      if (reserva == null) {
        throw Exception('Reserva no encontrada para external_reference: $externalReference');
      }

      // Actualizar estado segun el pago
      final nuevoEstado = _determinarEstadoReserva(status);
      
      await _actualizarEstadoReserva(reserva['id'], nuevoEstado, paymentDetails);

      return {
        'success': true,
        'message': 'Pago actualizado procesado',
        'reserva_id': reserva['id'],
        'estado_actualizado': nuevoEstado,
        'payment_status': status,
      };
    } catch (e) {
      throw Exception('Error procesando pago actualizado: $e');
    }
  }

  /// Busca reserva por external_reference
  static Future<Map<String, dynamic>?> _buscarReservaPorExternalReference(String externalReference) async {
    try {
      // El external_reference puede tener formato: supabaseId_tripOfferId_uuid
      // O puede ser directamente el pedidoId (UUID)
      String idToQuery = externalReference;
      final parts = externalReference.split('_');
      if (parts.length >= 2) {
        idToQuery = parts[1];
      }
      
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(idToQuery);

      if (isUuid) {
        final response = await SupabaseService.supabase
            .from('pedidos')
            .select('*')
            .eq('id', idToQuery)
            .maybeSingle();
        return response;
      } else {
        final parsedId = int.tryParse(idToQuery);
        if (parsedId == null) {
          throw Exception('Formato de id invalido para tabla reservas: $idToQuery');
        }
        final response = await SupabaseService.supabase
            .from('reservas')
            .select('*')
            .eq('id', parsedId)
            .maybeSingle();
        return response;
      }
    } catch (e) {
      throw Exception('Error buscando reserva/pedido por external_reference: $e');
    }
  }

  /// Determina el estado de la reserva segun el estado del pago
  static String _determinarEstadoReserva(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'approved':
        return 'Confirmada';
      case 'pending':
        return 'Pendiente';
      case 'rejected':
      case 'cancelled':
        return 'Cancelada';
      case 'refunded':
        return 'Reembolsada';
      case 'in_process':
        return 'Procesando';
      default:
        return 'Pendiente';
    }
  }

  /// Actualiza el estado de la reserva en Supabase
  static Future<void> _actualizarEstadoReserva(
    String id, 
    String nuevoEstado, 
    Map<String, dynamic> paymentDetails
  ) async {
    try {
      final isUuid = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(id);

      if (isUuid) {
        // Map to lowercase status for pedidos table
        final estadoPedido = nuevoEstado.toLowerCase() == 'confirmada' || nuevoEstado.toLowerCase() == 'aprobado'
            ? 'confirmado'
            : nuevoEstado.toLowerCase() == 'pendiente'
                ? 'pendiente'
                : 'cancelado';

        final updateData = {
          'estado': estadoPedido,
          'updated_at': DateTime.now().toIso8601String(),
          'mp_payment_id': paymentDetails['id']?.toString(),
          'mp_preference_id': paymentDetails['preference_id']?.toString(),
          'mp_external_reference': paymentDetails['external_reference']?.toString(),
          'metodo_pago': paymentDetails['payment_method_id'],
          'monto_total': (paymentDetails['transaction_amount'] as num?)?.toDouble() ?? 0.0,
          'mp_raw_response': paymentDetails,
        };

        await SupabaseService.supabase
            .from('pedidos')
            .update(updateData)
            .eq('id', id);

        // Also attempt to update the linked reservas table if there is a reserva_id
        try {
          final res = await SupabaseService.supabase
              .from('pedidos')
              .select('reserva_id')
              .eq('id', id)
              .maybeSingle();
              
          if (res != null && res['reserva_id'] != null) {
            final rId = res['reserva_id'];
            final estadoReserva = nuevoEstado.toLowerCase() == 'confirmada' || nuevoEstado.toLowerCase() == 'aprobado'
                ? 'PAGADA'
                : nuevoEstado.toLowerCase() == 'pendiente'
                    ? 'PAGO_PENDIENTE'
                    : 'PAGO_RECHAZADO';
                    
            if (rId is int) {
              await SupabaseService.supabase
                  .from('reservas')
                  .update({
                    'estado': estadoReserva,
                  })
                  .eq('id', rId);
            } else {
              final parsedId = int.tryParse(rId.toString());
              if (parsedId != null) {
                await SupabaseService.supabase
                    .from('reservas')
                    .update({
                      'estado': estadoReserva,
                    })
                    .eq('id', parsedId);
              }
            }
          }
        } catch (e2) {
          print('⚠️ Error al actualizar reserva vinculada desde webhook: $e2');
        }
      } else {
        final parsedId = int.tryParse(id);
        if (parsedId == null) {
          throw Exception('Formato de id invalido para tabla reservas: $id');
        }

        final updateData = {
          'estado': nuevoEstado,
        };

        await SupabaseService.supabase
            .from('reservas')
            .update(updateData)
            .eq('id', parsedId);
      }
    } catch (e) {
      throw Exception('Error actualizando reserva/pedido: $e');
    }
  }

  /// Valida la firma HMAC-SHA256 del webhook de MercadoPago.
  /// Replica el mismo algoritmo que usa la Edge Function en el servidor.
  ///
  /// [manifest] — cadena con formato: "id:<id>;request-id:<rid>;ts:<ts>;"
  /// [v1]       — hash hex enviado por MP en el header x-signature
  /// [secretKey]— MP_WEBHOOK_SECRET configurado en el panel de MP
  static bool validarFirmaWebhook(String manifest, String v1, String secretKey) {
    try {
      final key = utf8.encode(secretKey);
      final bytes = utf8.encode(manifest);
      final hmac = Hmac(sha256, key);
      final digest = hmac.convert(bytes);
      // Comparación en tiempo constante para evitar timing attacks
      final calculado = digest.toString();
      if (calculado.length != v1.length) return false;
      int diff = 0;
      for (int i = 0; i < calculado.length; i++) {
        diff |= calculado.codeUnitAt(i) ^ v1.codeUnitAt(i);
      }
      return diff == 0;
    } catch (e) {
      return false;
    }
  }

  /// Registra log de webhook para auditoria
  static Future<void> registrarLogWebhook(Map<String, dynamic> logData) async {
    try {
      await SupabaseService.supabase
          .from('webhook_logs')
          .insert({
            'webhook_type': 'mercadopago',
            'action': logData['action'],
            'payment_id': logData['payment_id'],
            'reserva_id': logData['reserva_id'],
            'request_body': json.encode(logData['request_body']),
            'response_body': json.encode(logData['response_body']),
            'status': logData['status'],
            'error_message': logData['error_message'],
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      // No lanzar error para no interrumpir el flujo principal
      print('Error registrando log de webhook: $e');
    }
  }
}
