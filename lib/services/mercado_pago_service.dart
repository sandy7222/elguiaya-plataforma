import 'dart:convert';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';

/// Servicio de integración real con Mercado Pago Checkout Pro
class MercadoPagoService {
  // ─── CREDENCIALES (Cargadas dinámicamente desde config_sistema) ────────────
  static String _accessToken = '';
  static String publicKey = '';
  static bool isSandbox = true;

  static const String _baseUrl = 'https://api.mercadopago.com';

  /// Carga dinámicamente las credenciales desde Supabase
  static Future<void> cargarCredenciales() async {
    try {
      final config = await SupabaseService.getSistemaConfig();
      if (config != null) {
        final dbPublicKey = config['mp_public_key']?.toString();
        final dbAccessToken = config['mp_access_token']?.toString();
        final dbIsSandbox = config['is_sandbox'] as bool? ?? true;

        if (dbPublicKey != null && dbPublicKey.isNotEmpty) {
          publicKey = dbPublicKey;
        }
        if (dbAccessToken != null && dbAccessToken.isNotEmpty) {
          _accessToken = dbAccessToken;
        }
        isSandbox = dbIsSandbox;
        print('🔒 [MERCADO PAGO] Credenciales cargadas desde DB: Sandbox = $isSandbox');
      }
    } catch (e) {
      print('⚠️ [MERCADO PAGO] Error cargando credenciales de la DB: $e');
    }
  }

  // ─── CREAR PREFERENCIA (genera el link de pago real) ─────────────────────
  /// Genera una preferencia de pago en MP y devuelve init_point + preference_id.
  /// [reservaId]   → ID interno de nuestra reserva en Supabase (external_reference).
  /// [titulo]      → Descripción del item (ej: "Viaje de Pesca – 3 pasajeros").
  /// [monto]       → Monto total a cobrar en pesos ARS.
  /// [emailPagador]→ Email del pescador para pre-llenar en MP.
  static Future<MercadoPagoPreferencia> crearPreferencia({
    required String reservaId,
    required String titulo,
    required double monto,
    String emailPagador = '',
    String? dniPagador,
    String? notificacionUrl, // Tu webhook URL de Supabase Edge Functions
  }) async {
    try {
      // Asegurar credenciales frescas antes de procesar el pago
      await cargarCredenciales();

      final body = {
        'items': [
          {
            'title': titulo,
            'quantity': 1,
            'currency_id': 'ARS',
            'unit_price': monto,
          }
        ],
        'payer': {
          'email': emailPagador.isNotEmpty
              ? emailPagador
              : 'TESTUSER2735580008246767076@testuser.com', // COMPRADOR de prueba
          if (dniPagador != null && dniPagador.isNotEmpty)
            'identification': {
              'type': 'DNI',
              'number': dniPagador,
            },
        },

        // El external_reference vincula el pago con nuestra reserva en Supabase
        'external_reference': reservaId,
        // URLs de retorno — usamos HTTPS para que MP Sandbox no quede trabado
        // intentando resolver un deep link El Guia YA:// desde adentro del browser.
        // El usuario vuelve manualmente a la app y toca "Verificar mi pago".
        'back_urls': {
          'success': 'https://El Guia YA.com.ar/pago/success',
          'failure': 'https://El Guia YA.com.ar/pago/failure',
          'pending': 'https://El Guia YA.com.ar/pago/pending',
        },
        // SIN auto_return: el usuario vuelve manualmente a la app

        // Webhook para notificación instantánea (configurar con tu URL real)
        if (notificacionUrl != null)
          'notification_url': notificacionUrl,
        'statement_descriptor': 'El Guia YA',
        'payment_methods': {
          'excluded_payment_types': [],
          'installments': 1, // Sin cuotas para reservas
        },
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/checkout/preferences'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return MercadoPagoPreferencia(
          preferenceId: data['id'].toString(),
          initPoint: data['init_point'].toString(),        // Producción
          sandboxInitPoint: data['sandbox_init_point']?.toString() ?? '', // Sandbox
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception(
          'MP Error ${response.statusCode}: ${error['message'] ?? response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error al crear preferencia MP: $e');
    }
  }

  // ─── REEMBOLSAR PAGO POR ID ──────────────────────────────────────────────
  /// Realiza el reembolso de un pago (total o parcial) directamente en la API de MP.
  /// [paymentId] → ID de la transacción en Mercado Pago.
  /// [amount]    → (Opcional) Monto a reembolsar. Si no se especifica, reembolsa el total.
  static Future<Map<String, dynamic>> reembolsarPago({
    required String paymentId,
    double? amount,
  }) async {
    try {
      await cargarCredenciales();

      final Map<String, dynamic> body = {};
      if (amount != null && amount > 0) {
        body['amount'] = amount;
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/v1/payments/$paymentId/refunds'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'refund_id': data['id']?.toString() ?? '',
          'status': data['status']?.toString() ?? 'approved',
          'amount': (data['amount'] as num?)?.toDouble() ?? amount ?? 0.0,
          'response': data,
        };
      } else {
        Map<String, dynamic> errorData = {};
        try {
          errorData = jsonDecode(response.body);
        } catch (_) {}
        final String errorMsg = errorData['message'] ?? response.body;
        throw Exception('Mercado Pago Error: $errorMsg');
      }
    } catch (e) {
      throw Exception('Error al procesar reembolso en Mercado Pago: $e');
    }
  }

  // ─── VERIFICAR ESTADO DE UN PAGO POR ID ──────────────────────────────────
  /// Consulta el estado de un pago directamente en la API de MP.
  static Future<EstadoPagoMP> verificarPago(String paymentId) async {
    try {
      await cargarCredenciales();

      final response = await http.get(
        Uri.parse('$_baseUrl/v1/payments/$paymentId'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return EstadoPagoMP.fromJson(data);
      } else {
        throw Exception('Error verifying payment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error al verificar pago MP: $e');
    }
  }

  // ─── PARSEAR ESTADO DE MP A NUESTRO SISTEMA ───────────────────────────────
  /// Convierte el status de MP a nuestro estado interno de reserva.
  static EstadoReservaMP parsearEstado(String mpStatus) {
    switch (mpStatus.toLowerCase()) {
      case 'approved':
        return EstadoReservaMP.aprobado;
      case 'pending':
      case 'in_process':
      case 'authorized':
        return EstadoReservaMP.pendiente;
      case 'rejected':
      case 'cancelled':
      case 'refunded':
      case 'charged_back':
        return EstadoReservaMP.rechazado;
      default:
        return EstadoReservaMP.pendiente;
    }
  }

  // ─── BUSCAR PAGO POR EXTERNAL_REFERENCE (SIN WEBHOOK) ────────────────────
  /// Busca el pago en la API de MP usando el reservaId como external_reference.
  /// Esto es independiente del webhook — funciona siempre que MP procesó el pago.
  static Future<EstadoPagoMP?> buscarPagoPorReferencia(String reservaId) async {
    try {
      await cargarCredenciales();

      final response = await http.get(
        Uri.parse('$_baseUrl/v1/payments/search?external_reference=$reservaId&sort=date_created&criteria=desc&range=date_created&begin_date=NOW-1DAYS&end_date=NOW'),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          // Tomamos el pago más reciente (primero en la lista)
          return EstadoPagoMP.fromJson(results.first);
        }
        return null; // Sin resultados = pago aún no procesado
      } else {
        throw Exception('Error buscando pago: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Error al buscar pago por referencia: $e');
    }
  }
}

// ─── MODELOS ─────────────────────────────────────────────────────────────────

class MercadoPagoPreferencia {
  final String preferenceId;
  final String initPoint;       // Link de producción
  final String sandboxInitPoint; // Link de sandbox/prueba

  const MercadoPagoPreferencia({
    required this.preferenceId,
    required this.initPoint,
    required this.sandboxInitPoint,
  });

  /// Devuelve el link correcto según el entorno
  String get linkPago => (MercadoPagoService.isSandbox && sandboxInitPoint.isNotEmpty) ? sandboxInitPoint : initPoint;
}

class EstadoPagoMP {
  final String id;
  final String status;          // approved | pending | rejected
  final String statusDetail;    // Detalle específico de MP
  final double transactionAmount;
  final String? externalReference;
  final String? payerEmail;
  final String paymentMethodId;
  final DateTime? dateApproved;

  const EstadoPagoMP({
    required this.id,
    required this.status,
    required this.statusDetail,
    required this.transactionAmount,
    this.externalReference,
    this.payerEmail,
    required this.paymentMethodId,
    this.dateApproved,
  });

  factory EstadoPagoMP.fromJson(Map<String, dynamic> json) {
    return EstadoPagoMP(
      id: json['id'].toString(),
      status: json['status'] ?? 'pending',
      statusDetail: json['status_detail'] ?? '',
      transactionAmount: (json['transaction_amount'] as num?)?.toDouble() ?? 0,
      externalReference: json['external_reference']?.toString(),
      payerEmail: json['payer']?['email']?.toString(),
      paymentMethodId: json['payment_method_id']?.toString() ?? '',
      dateApproved: json['date_approved'] != null
          ? DateTime.tryParse(json['date_approved'])
          : null,
    );
  }
}

enum EstadoReservaMP {
  aprobado,
  pendiente,
  rechazado,
}
