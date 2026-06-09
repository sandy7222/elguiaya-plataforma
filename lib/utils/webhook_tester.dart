

import 'dart:convert';

import 'package:http/http.dart' as http;


class WebhookTester {
  
  /// Simula un webhook de payment.created
  static Future<void> testPaymentCreated() async {
    final webhookData = {
      'action': 'payment.created',
      'data': {
        'id': '1234567890',
      },
      'date_created': '2025-01-01T12:00:00Z',
      'type': 'payment',
      'version': 'v1',
    };

    await _sendWebhookTest(webhookData);
  }

  /// Simula un webhook de payment.updated (aprobado)
  static Future<void> testPaymentApproved() async {
    final webhookData = {
      'action': 'payment.updated',
      'data': {
        'id': '1234567890',
      },
      'date_created': '2025-01-01T12:00:00Z',
      'type': 'payment',
      'version': 'v1',
    };

    await _sendWebhookTest(webhookData);
  }

  /// Envia datos de prueba al webhook
  static Future<void> _sendWebhookTest(Map<String, dynamic> webhookData) async {
    try {
      final response = await http.post(
        Uri.parse('http://localhost:8080/webhooks/mercadopago'),
        headers: {
          'Content-Type': 'application/json',
          'X-Signature': 'test-signature',
        },
        body: json.encode(webhookData),
      );

      print('Webhook test response: ${response.statusCode}');
      print('Response body: ${response.body}');
    } catch (e) {
      print('Error testing webhook: $e');
    }
  }

  /// Crea datos de pago de prueba para Mercado Pago
  static Map<String, dynamic> createMockPaymentData({
    required String paymentId,
    required String status,
    required String externalReference,
    double amount = 1000.0,
  }) {
    return {
      'id': paymentId,
      'date_created': '2025-01-01T12:00:00Z',
      'date_approved': status == 'approved' ? '2025-01-01T12:05:00Z' : null,
      'date_last_updated': '2025-01-01T12:00:00Z',
      'date_of_expiration': null,
      'money_release_date': null,
      'operation_type': 'regular_payment',
      'payment_method_id': 'visa',
      'payment_type_id': 'credit_card',
      'status': status,
      'status_detail': status == 'approved' ? 'accredited' : 'pending_contingency',
      'currency_id': 'ARS',
      'description': 'El Guia YA - Viaje de Pesca',
      'live_mode': false,
      'sponsor_id': null,
      'authorization_code': null,
      'collector_id': '123456789',
      'payer': {
        'id': '123456789',
        'email': 'test@example.com',
        'identification': {
          'type': 'CBU',
          'number': '0000000000000000000000000',
        },
        'type': 'customer',
      },
      'marketplace': 'NONE',
      'metadata': {
        'supabase_id': 'user_supabase_123',
        'trip_offer_id': 'reserva_456',
        'cbu': '0000000000000000000000000',
        'platform': 'El Guia YA_mobile',
      },
      'external_reference': externalReference,
      'transaction_amount': amount,
      'net_amount': amount * 0.9, // Ejemplo de comision
      'taxes_amount': 0,
      'transaction_amount_refunded': 0,
      'differential_pricing_id': null,
      'deduction_schema': null,
      'callback_url': null,
      'processing_mode': 'aggregator',
      'merchant_account_id': null,
      'acquirer': null,
      'acquirer_reconciliation': null,
      'statement_descriptor': null,
      'installments': 1,
      'card': {
        'id': 'card_id_123',
        'first_six_digits': '411111',
        'last_four_digits': '1111',
        'expiration_year': 2025,
        'expiration_month': 12,
        'date_created': '2025-01-01T12:00:00Z',
        'date_last_updated': '2025-01-01T12:00:00Z',
        'cardholder': {
          'name': 'Test User',
          'identification': {
            'type': 'DNI',
            'number': '12345678',
          },
        },
      },
      'charges_details': [],
      'differential_pricing': null,
      'installments_allowed': null,
      'decimals': 2,
      'fee_details': [],
    };
  }

  /// Simula el flujo completo de un pago
  static Future<void> simulateCompletePaymentFlow() async {
    print('🚀 Iniciando simulacion de flujo de pago completo...');
    
    // 1. Crear pago pendiente
    print('\n📝 1. Creando pago pendiente...');
    await testPaymentCreated();
    
    // Esperar un momento
    await Future.delayed(const Duration(seconds: 2));
    
    // 2. Aprobar pago
    print('\n✅ 2. Aprobando pago...');
    await testPaymentApproved();
    
    print('\n🎉 Flujo completo simulado exitosamente!');
    print('El StreamBuilder del Portal del Capitan deberia haberse actualizado automaticamente.');
  }

  /// Verifica que el webhook server este corriendo
  static Future<bool> checkWebhookServerHealth() async {
    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/webhooks/mercadopago/health'),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Webhook server no esta corriendo: $e');
      return false;
    }
  }
}
