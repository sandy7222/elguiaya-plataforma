

import 'package:uuid/uuid.dart';

class PaymentService {
  static const String MERCADO_PAGO_API_URL = 'https://api.mercadopago.com/v1/payments';
  static const String WEBHOOK_URL = 'https://api.El Guia YA.com/webhooks/mercadopago'; // Produccion
  static const String WEBHOOK_URL_DEV = 'http://localhost:8080/webhooks/mercadopago'; // Desarrollo
  
  static Map<String, dynamic> generatePaymentData({
    required String supabaseId,
    required String tripOfferId,
    required double total,
    required Map<String, double> taxes,
    String? cbu,
    String? description,
    bool isDevelopment = false,
  }) {
    final externalReference = '${supabaseId}_${tripOfferId}_${const Uuid().v4()}';
    final webhookUrl = isDevelopment ? WEBHOOK_URL_DEV : WEBHOOK_URL;
    
    return {
      'transaction_amount': total,
      'description': description ?? 'El Guia YA - Viaje de Pesca',
      'payment_method_id': 'visa', // Por defecto, puede ser dinamico
      'external_reference': externalReference,
      'payer': {
        'email': 'test@example.com', // Deberia venir del usuario logueado
        'identification': {
          'type': 'CBU',
          'number': cbu ?? '0000000000000000000000000', // CBU del perfil del pescador
        },
      },
      'metadata': {
        'supabase_id': supabaseId,
        'trip_offer_id': tripOfferId,
        'taxes': taxes,
        'cbu': cbu, // Campo CBU recuperado de Supabase
        'platform': 'El Guia YA_mobile',
        'created_at': DateTime.now().toIso8601String(),
        'webhook_url': webhookUrl,
      },
      'notification_url': webhookUrl,
      'binary_mode': true, // Para recibir notificaciones sincronas
    };
  }
  
  static Map<String, dynamic> prepareInvoiceForPayment({
    required Map<String, dynamic> invoice,
    required String supabaseId,
  }) {
    final paymentData = generatePaymentData(
      supabaseId: supabaseId,
      tripOfferId: invoice['tripOfferId'],
      total: invoice['total'],
      taxes: invoice['taxes'],
      description: 'El Guia YA - Viaje ID: ${invoice['tripOfferId']}',
    );
    
    return {
      'invoice': invoice,
      'payment_data': paymentData,
      'status': 'pending_payment',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
  
  static Future<bool> validatePaymentData(Map<String, dynamic> paymentData) async {
    try {
      // Validaciones basicas
      if (paymentData['transaction_amount'] <= 0) return false;
      if (paymentData['external_reference'] == null || paymentData['external_reference'].toString().isEmpty) return false;
      if (paymentData['payer'] == null || paymentData['payer']['email'] == null) return false;
      
      // Validar que los impuestos sumen correctamente
      final total = paymentData['transaction_amount'] as double;
      final metadata = paymentData['metadata'];
      if (metadata['taxes'] != null) {
        final taxes = metadata['taxes'] as Map<String, dynamic>;
        final calculatedTotal = (taxes['netoGravado'] ?? 0.0) + 
                               (taxes['iva'] ?? 0.0) + 
                               (taxes['iibb'] ?? 0.0);
        
        // Permitir pequena diferencia por redondeo
        if ((total - calculatedTotal).abs() > 0.01) return false;
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
}
