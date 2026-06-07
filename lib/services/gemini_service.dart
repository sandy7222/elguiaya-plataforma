import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/gemini_config.dart';
import '../models/el_guia_respuesta.dart';
import 'capacitacion_service.dart';
import 'gemini_learner.dart';
import 'el_guia_engine.dart';
import 'el_guia_context.dart';

/// GeminiService â€” El cerebro online de El Guía.
///
/// Llama a la API de Gemini con la systemInstruction de CapacitacionService.
/// Implementa la jerarquía de fallback completa:
///   - Límite diario superado   â†’ motor local (silencioso)
///   - Rate limit (429)         â†’ motor local + pausa 60min
///   - Timeout > 8s             â†’ motor local (silencioso)
///   - Cualquier error de API   â†’ motor local (silencioso)
///
/// Usa http directamente para no requerir el paquete google_generative_ai
/// hasta que esté disponible en pubspec. Compatible con REST v1beta.
class GeminiService {
  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static final ElGuiaEngine _motorLocal = ElGuiaEngine();

  /// Responde la pregunta del pescador.
  /// Si Gemini no está disponible, usa el motor local de forma invisible.
  Future<ElGuiaRespuesta> responder(String pregunta) async {
    // Precondición: ¿puede llamar a la API?
    if (!GeminiConfig.puedeConsultar) {
      // ignore: avoid_print
      print('[GeminiService] bloqueado — puedeConsultar=false. Estado: ${GeminiConfig.estadoDescripcion}');
      return _motorLocal.responder(pregunta);
    }

    try {
      final respuestaCompleta = await _llamarApi(pregunta);

      // ignore: avoid_print
      print('[GeminiService] respuesta cruda (primeros 200 chars): ${respuestaCompleta.substring(0, respuestaCompleta.length.clamp(0, 200))}');

      // Limpiar markdown si Gemini envolvió el JSON en ```json ... ```
      final respuestaLimpia = _limpiarMarkdown(respuestaCompleta);

      // Validar formato: necesita el token |||APRENDO|||
      final hasToken = respuestaLimpia.contains('|||APRENDO|||');
      final bloque = GeminiLearner.parsearBloqueAprendizaje(respuestaLimpia);

      // ignore: avoid_print
      print('[GeminiService] hasToken=$hasToken | bloque=${bloque != null ? 'OK' : 'NULL'}');

      if (!hasToken || bloque == null) {
        // ignore: avoid_print
        print('[GeminiService] ⚠️ Strike registrado. hasToken=$hasToken, bloque=$bloque');
        await GeminiConfig.registrarStrike();
        // Aun así intentamos mostrar la respuesta si hay texto visible
        final textoVisible = hasToken
            ? GeminiLearner.extraerRespuestaUsuario(respuestaLimpia)
            : respuestaLimpia.split('|||APRENDO|||').first.trim();
        if (textoVisible.isNotEmpty && textoVisible.length > 10) {
          // ignore: avoid_print
          print('[GeminiService] fallback suave: mostrando texto visible sin aprender');
          return ElGuiaRespuesta(
            texto: textoVisible,
            gifSugerido: 'hablaConMate',
            origenGemini: true,
          );
        }
        return _motorLocal.responder(pregunta);
      }

      // Si tiene éxito, se resetean los strikes
      GeminiConfig.resetStrikes();

      // Registrar la consulta exitosa
      await GeminiConfig.registrarConsulta();

      // Extraer la respuesta visible
      final textoUsuario = GeminiLearner.extraerRespuestaUsuario(respuestaLimpia);
      final gifSugerido  = _extraerGif(respuestaLimpia);

      // Auto-aprendizaje en background (no bloquea la respuesta)
      unawaited(GeminiLearner.procesar(bloque, pregunta));

      return ElGuiaRespuesta(
        texto: textoUsuario.isNotEmpty ? textoUsuario : _fallbackTexto(),
        gifSugerido: gifSugerido,
        origenGemini: true,
      );
    } on _RateLimitException {
      // 429 → pausa automática + fallback silencioso
      // ignore: avoid_print
      print('[GeminiService] 🛑 Rate limit 429 — pausando API 60 min');
      await GeminiConfig.activarPausaRateLimit();
      return _motorLocal.responder(pregunta);
    } on TimeoutException {
      // ignore: avoid_print
      print('[GeminiService] ⏱️ Timeout — fallback local');
      return _motorLocal.responder(pregunta);
    } catch (e) {
      // ignore: avoid_print
      print('[GeminiService] ❌ Error inesperado: $e');
      return _motorLocal.responder(pregunta);
    }
  }

  /// Llamada de prueba para el botón "Probar conexión" del panel admin.
  /// Devuelve el texto crudo de Gemini o lanza excepción con el motivo.
  Future<String> probarConexion() async {
    if (!GeminiConfig.tieneApiKey) throw Exception('Sin API key');
    return await _llamarApi('¿Hola! ¿Estás funcionando? Respondé solo: "Sí, Gemini 1.5 Flash operativo"');
  }

  /// Entrenamiento manual: el admin le pide a Gemini que aprenda un tema.
  /// Usa Google Search Grounding para buscar info en tiempo real.
  /// Devuelve un mapa con { 'respuesta': texto, 'aprendido': bool, 'intencion': nombre }.
  Future<Map<String, dynamic>> buscarYMemorizar(String tema) async {
    if (!GeminiConfig.tieneApiKey) throw Exception('Sin API key');

    final url = Uri.parse(
      '$_baseUrl/${GeminiConfig.modelo}:generateContent?key=${GeminiConfig.apiKey}',
    );

    final promptEntrenamiento = '''
Sos El Guía, el asistente de Capitán-YA, una app de pesca deportiva argentina en el Río Paraná.
El administrador de la app te pide que aprendas sobre este tema para poder responderlo offline a los pescadores:

TEMA A APRENDER: $tema

Instrucciones:
1. Buscá información sobre este tema.
2. Sintetizá en máximo 3 líneas, en lenguaje ribereño argentino (usás "dale", "amigo", "tocá", "mirá").
3. Sin markdown, sin asteriscos, texto plano.
4. Luego escribí exactamente: |||APRENDO|||
5. Luego el JSON de aprendizaje sin ningún texto extra.

Formato obligatorio del JSON:
{
  "intencion": "nombre_en_snake_case_descriptivo",
  "activadores": ["frase 1 que podría preguntar un pescador", "frase 2", "frase 3", "frase 4"],
  "respuesta_limpia": "tu respuesta de 3 líneas exactamente",
  "gif": "hablaConMate",
  "puntaje": 9
}
''';

    final body = json.encode({
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': promptEntrenamiento}],
        }
      ],
      'tools': [
        {
          'googleSearchRetrieval': {
            'dynamicRetrievalConfig': {
              'mode': 'MODE_DYNAMIC',
              'dynamicThreshold': 0.1,
            }
          }
        }
      ],
      'generationConfig': {
        'temperature': 0.4,
        'topP': 0.9,
        'maxOutputTokens': 800,
      },
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode == 429) throw Exception('Límite de cuota alcanzado. Esperá unos minutos.');
    if (response.statusCode != 200) {
      throw Exception('Gemini API ${response.statusCode}: ${response.body}');
    }

    final decoded  = json.decode(response.body) as Map<String, dynamic>;
    final textoRaw = _extraerTextoDeRespuesta(decoded);

    // Parsear el bloque de aprendizaje
    final bloque = GeminiLearner.parsearBloqueAprendizaje(textoRaw);
    if (bloque == null) {
      return {'respuesta': textoRaw, 'aprendido': false, 'intencion': ''};
    }

    // Guardar en memoria permanente
    await GeminiLearner.procesar(bloque, tema);

    final intencion = bloque['intencion']?.toString() ?? '';
    final respuesta = GeminiLearner.extraerRespuestaUsuario(textoRaw);

    return {
      'respuesta': respuesta.isNotEmpty ? respuesta : textoRaw,
      'aprendido': true,
      'intencion': intencion,
      'activadores': bloque['activadores'] ?? [],
    };
  }

  // â”€â”€ Llamada HTTP a la API REST de Gemini â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<String> _llamarApi(String pregunta) async {
    final systemInstruction = await CapacitacionService.obtenerSystemInstruction(
      contexto: ElGuiaContext()
        ..ultimaConsulta = pregunta
        ..esBlog = false,
    );
    final url = Uri.parse(
      '$_baseUrl/${GeminiConfig.modelo}:generateContent?key=${GeminiConfig.apiKey}',
    );

    final body = json.encode({
      // camelCase obligatorio en la REST API de Gemini
      'systemInstruction': {
        'parts': [{'text': systemInstruction}],
      },
      'contents': [
        {
          'role': 'user',
          'parts': [{'text': pregunta}],
        }
      ],
      // Google Search activo: Gemini busca en la web de forma agresiva cuando es necesario (threshold 0.2)
      'tools': [
        {
          'googleSearchRetrieval': {
            'dynamicRetrievalConfig': {
              'mode': 'MODE_DYNAMIC',
              'dynamicThreshold': 0.2,
            }
          }
        }
      ],
      'generationConfig': {
        'temperature': 0.75,
        'topP': 0.9,
        'maxOutputTokens': 1200,
      },
      'safetySettings': [
        {'category': 'HARM_CATEGORY_HARASSMENT',        'threshold': 'BLOCK_ONLY_HIGH'},
        {'category': 'HARM_CATEGORY_HATE_SPEECH',       'threshold': 'BLOCK_ONLY_HIGH'},
        {'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT', 'threshold': 'BLOCK_ONLY_HIGH'},
        {'category': 'HARM_CATEGORY_DANGEROUS_CONTENT', 'threshold': 'BLOCK_ONLY_HIGH'},
      ],
    });

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        )
        .timeout(Duration(seconds: GeminiConfig.timeoutSegundos));

    if (response.statusCode == 429) throw _RateLimitException();
    if (response.statusCode != 200) {
      throw Exception('Gemini API ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    return _extraerTextoDeRespuesta(decoded);
  }

  String _extraerTextoDeRespuesta(Map<String, dynamic> decoded) {
    try {
      final candidates = decoded['candidates'] as List<dynamic>;
      final content    = candidates.first['content'] as Map<String, dynamic>;
      final parts      = content['parts'] as List<dynamic>;
      return parts.first['text']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  String _extraerGif(String respuestaCompleta) {
    final bloque = GeminiLearner.parsearBloqueAprendizaje(respuestaCompleta);
    if (bloque == null) return 'hablaConMate';
    return bloque['gif']?.toString() ?? 'hablaConMate';
  }

  /// Elimina bloques de código markdown (```json ... ```) que Gemini a veces
  /// agrega alrededor del JSON de aprendizaje, para que el parser no falle.
  String _limpiarMarkdown(String texto) {
    // Reemplazar ```json ... ``` y ``` ... ``` por el contenido desnudo
    return texto
        .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'```\s*', multiLine: true), '');
  }

  String _fallbackTexto() =>
      'No pude procesar eso bien, amigo. Intentá de nuevo con otras palabras.';
}

/// Excepción interna para distinguir 429 de otros errores.
class _RateLimitException implements Exception {}

