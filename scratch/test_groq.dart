import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final apiKey = const String.fromEnvironment('GROQ_API_KEY');
  final model = 'llama-3.3-70b-versatile';
  final baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  print('=== PROBANDO CONEXIÓN A GROQ ===');
  print('API Key: ${apiKey.isNotEmpty ? "${apiKey.substring(0, 8)}..." : "Vacia"}');
  print('Model: $model');

  try {
    final response = await http.post(
      Uri.parse(baseUrl),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Respond strictly with: "Groq Llama 3.3 operativo y funcionando!"'},
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';
      print('\n[ÉXITO] Status 200 OK');
      print('Respuesta recibida: $content');
    } else {
      print('\n[FALLO] Código de estado: ${response.statusCode}');
      print('Cuerpo del error: ${response.body}');
    }
  } catch (e) {
    print('\n[ERROR] Ocurrió una excepción al conectar con Groq: $e');
  }
}
