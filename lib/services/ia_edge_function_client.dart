import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente único para IA online. Las claves de proveedores viven solamente en
/// secretos de la Edge Function `ia-proxy`, nunca en Flutter.
class AiEdgeFunctionClient {
  static const _functionName = 'ia-proxy';

  static Future<http.Response> groqChat({
    required String model,
    required List<Map<String, String>> messages,
    required double temperature,
    String? reasoningEffort,
    int? maxCompletionTokens,
  }) {
    return _invoke({
      'provider': 'groq',
      'model': model,
      'messages': messages,
      'temperature': temperature,
      // Paso 1.5: el proxy solo deja pasar valores de su lista blanca.
      'reasoning_effort': ?reasoningEffort,
      'max_completion_tokens': ?maxCompletionTokens,
    });
  }

  static Future<http.Response> geminiGenerate({
    required String model,
    required Map<String, dynamic> body,
  }) {
    return _invoke({
      'provider': 'gemini',
      'model': model,
      'body': body,
    });
  }

  /// Reemplaza la llamada a la Edge Function en los tests (recibe el cuerpo que se
  /// mandaría y devuelve la respuesta del proveedor).
  @visibleForTesting
  static Future<http.Response> Function(Map<String, dynamic> body)? invocadorParaTest;

  static Future<http.Response> _invoke(Map<String, dynamic> body) async {
    final falso = invocadorParaTest;
    if (falso != null) return falso(body);
    final result = await Supabase.instance.client.functions.invoke(
      _functionName,
      body: body,
    );
    return respuestaDelProxy(result.data);
  }

  /// Arma la `http.Response` con lo que devolvió la Edge Function.
  @visibleForTesting
  static http.Response respuestaDelProxy(Object? data) {
    if (data is! Map) {
      throw StateError('Respuesta inválida de la función de IA.');
    }
    final status = data['status'];
    final payload = data['body'];
    if (status is! int || payload == null) {
      throw StateError('Respuesta incompleta de la función de IA.');
    }
    // UTF-8 declarado: `http.Response(String)` sin charset codifica en latin1, y
    // entonces cualquier tilde se leía mal (`utf8.decode` fallaba) y un emoji o una
    // comilla curva tiraba una excepción.
    return http.Response.bytes(
      utf8.encode(jsonEncode(payload)),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
