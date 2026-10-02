import 'dart:convert';

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
  }) {
    return _invoke({
      'provider': 'groq',
      'model': model,
      'messages': messages,
      'temperature': temperature,
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

  static Future<http.Response> _invoke(Map<String, dynamic> body) async {
    final result = await Supabase.instance.client.functions.invoke(
      _functionName,
      body: body,
    );
    final data = result.data;
    if (data is! Map) {
      throw StateError('Respuesta inválida de la función de IA.');
    }
    final status = data['status'];
    final payload = data['body'];
    if (status is! int || payload == null) {
      throw StateError('Respuesta incompleta de la función de IA.');
    }
    return http.Response(jsonEncode(payload), status);
  }
}
