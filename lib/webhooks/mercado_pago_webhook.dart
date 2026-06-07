

import 'dart:convert';


import 'package:shelf/shelf.dart';

import 'package:shelf_router/shelf_router.dart';

import '../services/mercado_pago_webhook_service.dart';

class MercadoPagoWebhookEndpoint {
  
  /// Maneja las solicitudes del webhook
  static Future<Response> handleWebhook(Request request) async {
    try {
      // Solo aceptar POST
      if (request.method != 'POST') {
        return Response(405, body: 'Method not allowed');
      }

      // Obtener el cuerpo de la solicitud
      final body = await request.readAsString();
      final webhookData = json.decode(body);

      // Validar firma (opcional, recomendado para produccion)
      final signature = request.headers['x-signature'] ?? '';
      final secretKey = 'TU_SECRET_KEY'; // Configurar en entorno
      
      if (!MercadoPagoWebhookService.validarFirmaWebhook(body, signature, secretKey)) {
        return Response(401, body: 'Invalid signature');
      }

      // Procesar el webhook
      final result = await MercadoPagoWebhookService.procesarWebhook(webhookData);

      // Registrar log para auditoria
      await MercadoPagoWebhookService.registrarLogWebhook({
        'action': webhookData['action'] ?? '',
        'payment_id': webhookData['data']?['id']?.toString() ?? '',
        'reserva_id': result['reserva_id'] ?? '',
        'request_body': webhookData,
        'response_body': result,
        'status': result['success'] ? 'success' : 'error',
        'error_message': result['success'] ? null : result['message'],
      });

      // Retornar respuesta exitosa
      return Response(
        200,
        body: json.encode({
          'status': 'processed',
          'message': result['message'],
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'content-type': 'application/json'},
      );

    } catch (e) {
      // Registrar error
      await MercadoPagoWebhookService.registrarLogWebhook({
        'action': 'error',
        'payment_id': '',
        'reserva_id': '',
        'request_body': await request.readAsString(),
        'response_body': {'error': e.toString()},
        'status': 'error',
        'error_message': e.toString(),
      });

      return Response(
        500,
        body: json.encode({
          'status': 'error',
          'message': 'Internal server error',
          'error': e.toString(),
          'timestamp': DateTime.now().toIso8601String(),
        }),
        headers: {'content-type': 'application/json'},
      );
    }
  }



  /// Configura las rutas del webhook para produccion
  static Handler setupRoutes() {
    final router = Router();
    
    // Endpoint principal del webhook
    router.post('/webhooks/mercadopago', handleWebhook);
    
    // Endpoint de健康检查
    router.get('/webhooks/mercadopago/health', (Request request) {
      return Response(200, body: json.encode({
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'service': 'mercadopago-webhook',
      }), headers: {'content-type': 'application/json'});
    });

    return router.call;
  }
}
