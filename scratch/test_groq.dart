import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  const String baseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  const String apiKeyGuia = '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';
  const String apiKeyCentralita = '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';

  print('=== DIAGNÓSTICO DE CONEXIÓN A GROQ ===\n');

  await testKey('El Guía (Key Guia)', apiKeyGuia, baseUrl);
  await testKey('Centralita (Key Centralita)', apiKeyCentralita, baseUrl);
}

Future<void> testKey(String name, String key, String url) async {
  print('Probando clave de $name...');
  try {
    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $key',
      },
      body: jsonEncode({
        'model': 'llama-3.3-70b-versatile',
        'messages': [
          {'role': 'user', 'content': 'Responde estrictamente con la palabra: OK'},
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 8));

    print('Status Code: ${response.statusCode}');
    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      print('Respuesta de Groq: "$content"');
      print('✅ CLAVE OPERATIVA Y CONECTADA.\n');
    } else {
      print('❌ ERROR EN LA CLAVE (Status ${response.statusCode}): ${response.body}\n');
    }
  } catch (e) {
    print('❌ ERROR DE RED O TIMEOUT: $e\n');
  }
}
