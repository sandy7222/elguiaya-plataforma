import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/el_guia_respuesta.dart';
import '../config/groq_config.dart';
import 'capacitacion_service.dart';
import 'gemini_learner.dart';
import 'el_guia_context.dart';
import 'guia_rol_service.dart';
import 'connectivity_bridge.dart';
import 'supabase_service.dart';

class GroqService {
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  // ID temporal para la corrección de aprendizaje
  static String? _ultimoRegistroId;

  /// Responde una consulta de chat usando el modelo en la nube de Groq.
  /// Lanza excepción en cualquier fallo para que BaqueanoIAService maneje el fallback.
  Future<ElGuiaRespuesta> responder(
    String pregunta, {
    String? contextoExtra,
    ElGuiaContext? contexto,
    List<Map<String, String>>? historial,
  }) async {
    if (!ConnectivityBridge.estaConectado) {
      throw Exception('Failsafe: Dispositivo sin conexión a internet, forzando fallback local');
    }

    if (!GroqConfig.tieneApiKey) {
      throw Exception('Sin API Key de Groq configurada');
    }

    // Detectar si el usuario corrige el aprendizaje previo
    if (_ultimoRegistroId != null) {
      final lowerPregunta = pregunta.toLowerCase();
      final frasesCorreccion = [
        'no es así',
        'estás equivocado',
        'estás equivocada',
        'estas equivocado',
        'estas equivocada',
        'en realidad',
        'te corrijo',
        'eso está mal',
        'no es correcto'
      ];
      final esCorreccion = frasesCorreccion.any((frase) => lowerPregunta.contains(frase));

      if (esCorreccion) {
        // Eliminar el registro anterior de Supabase
        unawaited(SupabaseService.eliminarConocimiento(_ultimoRegistroId!));
        debugPrint('[GroqService] Detección de corrección: registro anterior $_ultimoRegistroId eliminado.');
      } else {
        debugPrint('[GroqService] Mensaje normal: el registro $_ultimoRegistroId queda pendiente de aprobación en Supabase (aprobado: false).');
      }
      _ultimoRegistroId = null;
    }

    final rol = GuiaRolService.detectarRol(pregunta);
    final String rolePrompt;
    final String systemPrompt;

    if (rol == GuiaRol.soporteApp) {
      rolePrompt = CapacitacionService.obtenerPromptSoporteApp();
      systemPrompt = """
$rolePrompt

REGLA 1 — IDENTIDAD:
Respondé con respeto y colaboración a todos los usuarios.
Nunca inventés datos técnicos. Si no sabés algo, decilo honestamente en tono rústico.
""";
    } else {
      final zona = GuiaRolService.detectarZona(pregunta);
      rolePrompt = CapacitacionService.obtenerPromptGuiaNacional(zona);
      systemPrompt = """
$rolePrompt

REGLA 1 — IDENTIDAD:
Respondé con respeto y colaboración a todos los usuarios.
Nunca inventés datos técnicos. Si no sabés algo, decilo honestamente en tono rústico.

REGLA 2 — PROTOCOLO DE APRENDIZAJE AUTOMÁTICO:
⚠️ IMPORTANTE: Vos NO te conectás a ninguna base de datos ni a Supabase. Eso ya está resuelto por el sistema.
Tu única responsabilidad es: cuando identifiques conocimiento técnico valioso en la conversación
(técnicas de pesca, carnadas, nudos, especies, condiciones del río, campamentismo, cocina ribereña),
debés AGREGAR AL FINAL de tu respuesta la etiqueta |||APRENDO||| seguida del JSON.
El sistema intercepta esa etiqueta automáticamente y guarda el conocimiento en la base de datos. Vos no hacés nada más que emitir el token y el JSON.

REGLA 3 — CUÁNDO emitir |||APRENDO|||:
- Solo cuando la respuesta contiene conocimiento técnico concreto y reutilizable.
- NO en charlas de saludo, bromas, preguntas emocionales ni respuestas donde decís "no sé".
- Si emitís |||APRENDO|||, el JSON DEBE ser válido y completo.

REGLA 4 — FORMATO EXACTO del bloque de aprendizaje:
Primero va tu respuesta normal al usuario. Luego, sin línea en blanco, el token y el JSON:

|||APRENDO|||
{
  "intencion": "como_hacer_nudo_palomar",
  "activadores": ["cómo hago el nudo palomar", "nudo para anzuelo", "atar el anzuelo"],
  "respuesta_limpia": "El nudo palomar: doble el hilo, pasalo por el ojo, hacé un nudo simple, pasá el anzuelo por el lazo y apretá.",
  "gif": "hablaConMate",
  "puntaje": 9,
  "fuente": "groq_sesion"
}

Valores válidos para "gif": hablaConMate | exito | piensaLeve | piensaProfundo | saludo | duda | enojado | triste
El campo "puntaje" va de 1 a 10 según cuán valioso es el conocimiento para un pescador argentino.
El campo "intencion" siempre en snake_case: como_pescar_dorado | que_carnada_usar | nudo_palomar.
El campo "respuesta_limpia" máximo 120 caracteres, sin asteriscos ni markdown.
""";
    }


    final String finalSystemPrompt = contextoExtra != null && contextoExtra.isNotEmpty
        ? "$systemPrompt\nINFORMACIÓN DE CONTEXTO ACTUAL:\n$contextoExtra\n"
        : systemPrompt;

    // Obtener el contexto del usuario (rehidratación de memoria)
    final miniContext = await GuiaMemoriaService.cargarContextoRehidratado();

    // Fusionar con el prompt base en UN SOLO system
    final systemFinal = miniContext != null && miniContext.isNotEmpty
        ? '$finalSystemPrompt\n\nCONTEXTO DEL USUARIO:\n$miniContext'
        : finalSystemPrompt;

    // Reconstruir lista de mensajes incluyendo el historial
    final List<Map<String, String>> apiMessages = [];
    apiMessages.add({'role': 'system', 'content': systemFinal});
    if (historial != null) {
      apiMessages.addAll(historial);
    }
    apiMessages.add({'role': 'user', 'content': pregunta});

    http.Response? tempResponse;
    int maxIntentos = 1;

    for (int intento = 1; intento <= maxIntentos; intento++) {
      try {
        tempResponse = await http.post(
          Uri.parse(_baseUrl),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Authorization': 'Bearer ${GroqConfig.apiKey}',
          },
          body: jsonEncode({
            'model': GroqConfig.modelo,
            'messages': apiMessages,
            'temperature': 0.7,
          }),
        ).timeout(
          const Duration(seconds: 12), // Ajustado a 12s para evitar cortes por congestión
        );
        break; // Éxito, salimos del bucle
      } catch (e) {
        if (intento == maxIntentos) {
          if (e is TimeoutException) {
            throw TimeoutException('Groq no respondió en 12 segundos.');
          }
          rethrow;
        }
        debugPrint('[GroqService] Falló intento $intento de conexión con Groq ($e). Reintentando en 1 segundo...');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (tempResponse == null) {
      throw Exception('No se pudo establecer conexión con Groq.');
    }
    final response = tempResponse;

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final content = data['choices']?[0]?['message']?['content'] ?? '';

      // Buscar bloque con token |||APRENDO|||
      final token = '|||APRENDO|||';
      final hasToken = content.contains(token);
      
      String textoVisible = content;
      Map<String, dynamic>? jsonAprendido;

      if (hasToken) {
        final partes = content.split(token);
        if (partes.length >= 3) {
          // Formato: Texto |||APRENDO||| JSON |||APRENDO||| Texto
          final jsonStr = partes[1].trim();
          try {
            jsonAprendido = jsonDecode(jsonStr) as Map<String, dynamic>;
          } catch (e) {
            // Intento secundario: extraer solo el JSON interno
            final inicioJson = jsonStr.indexOf('{');
            final finJson = jsonStr.lastIndexOf('}');
            if (inicioJson >= 0 && finJson >= 0) {
              try {
                jsonAprendido = jsonDecode(jsonStr.substring(inicioJson, finJson + 1)) as Map<String, dynamic>;
              } catch (_) {}
            }
          }
          // Unir texto antes y después del bloque
          textoVisible = (partes.first + partes.sublist(2).join('')).trim();
        } else if (partes.length == 2) {
          // Formato: Texto |||APRENDO||| JSON
          final jsonStr = partes[1].trim();
          try {
            jsonAprendido = jsonDecode(jsonStr) as Map<String, dynamic>;
          } catch (e) {
            final inicioJson = jsonStr.indexOf('{');
            final finJson = jsonStr.lastIndexOf('}');
            if (inicioJson >= 0 && finJson >= 0) {
              try {
                jsonAprendido = jsonDecode(jsonStr.substring(inicioJson, finJson + 1)) as Map<String, dynamic>;
              } catch (_) {}
            }
          }
          textoVisible = partes.first.trim();
        }
      }

      // Limpiar bloques de código markdown si los hay en el texto visible
      textoVisible = textoVisible
          .replaceAll(RegExp(r'```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'```\s*', multiLine: true), '')
          .trim();

      String gif = 'hablaConMate';
      if (jsonAprendido != null) {
        try {
          gif = jsonAprendido['gif']?.toString() ?? 'hablaConMate';
          
          // Persistencia en Supabase (global)
          SupabaseService.guardarConocimiento(jsonAprendido).then((id) {
            if (id != null) {
              _ultimoRegistroId = id;
            }
          });
          
          // Persistencia en Supabase (local)
          unawaited(CapacitacionService.persistirNuevoConocimiento(jsonAprendido));
          
          // Procesamiento local
          unawaited(GeminiLearner.procesar(jsonAprendido, pregunta));
        } catch (e) {
          debugPrint('[GroqService] Error al persistir bloque de aprendizaje: $e');
        }
      }

      // ── Detector de carencias ────────────────────────────────────────
      // Si Groq no disparó |||APRENDO||| pero expresa incertidumbre,
      // guardamos la pregunta como carencia en Supabase para que el
      // administrador pueda nutrir las librerías con ese conocimiento.
      if (!hasToken && _esRespuestaDeCarencia(textoVisible)) {
        unawaited(_guardarCarencia(pregunta, textoVisible));
      }

      return ElGuiaRespuesta(
        texto: textoVisible.isNotEmpty ? textoVisible : 'No pude procesar eso bien, che.',
        gifSugerido: gif,
        origenGemini: true,
      );

    } else if (response.statusCode == 401) {
      // Clave inválida — el orquestador puede diferenciar este caso si hace falta
      throw Exception('API Key de Groq inválida (401). Verificá la clave en el panel de administración.');

    } else if (response.statusCode == 429) {
      // Rate limit — fallback silencioso
      throw Exception('Límite de consultas de Groq alcanzado (429). Usando motor alternativo.');

    } else {
      throw Exception('Error en API Groq (Status ${response.statusCode}): ${response.body}');
    }
  }

  // ── Detección de carencias ─────────────────────────────────────────────

  /// Frases que indican que Groq no supo responder la pregunta.
  static const List<String> _frasesCarencia = [
    'no tengo información',
    'no sé ',
    'no sé,',
    'no lo sé',
    'no puedo responder',
    'no tengo datos',
    'no estoy seguro',
    'no cuento con',
    'desconozco',
    'no hay datos',
    'no tengo certeza',
    'escapa a mi conocimiento',
    'no tengo acceso',
    'información no disponible',
    'no dispongo de',
    'no me es posible',
    'no tengo detalles',
  ];

  /// Retorna true si el texto de Groq indica incertidumbre o desconocimiento.
  static bool _esRespuestaDeCarencia(String texto) {
    final lower = texto.toLowerCase();
    return _frasesCarencia.any((f) => lower.contains(f));
  }

  /// Guarda la pregunta como carencia en guia_conocimiento_distribuido.
  /// Se ejecuta en background (unawaited) para no bloquear la respuesta al usuario.
  static Future<void> _guardarCarencia(String pregunta, String respuestaGroq) async {
    try {
      // Generar slug a partir de la pregunta (máx 50 chars, snake_case)
      final slug = pregunta
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-záéíóúüñ\s]', unicode: true), '')
          .trim()
          .replaceAll(RegExp(r'\s+'), '_')
          .replaceAll(RegExp(r'[áàä]'), 'a')
          .replaceAll(RegExp(r'[éèë]'), 'e')
          .replaceAll(RegExp(r'[íìï]'), 'i')
          .replaceAll(RegExp(r'[óòö]'), 'o')
          .replaceAll(RegExp(r'[úùü]'), 'u')
          .replaceAll('ñ', 'n');
      final intencion = 'carencia_${slug.length > 50 ? slug.substring(0, 50) : slug}';

      final client = Supabase.instance.client;

      // Evitar duplicados: verificar si ya existe una carencia con este slug
      final existentes = await client
          .from('guia_conocimiento_distribuido')
          .select('id, veces_preguntado')
          .eq('intencion', intencion)
          .limit(1);

      if (existentes.isNotEmpty) {
        // Ya existe → incrementar veces_preguntado
        final id = existentes.first['id'];
        final veces = (existentes.first['veces_preguntado'] as num?)?.toInt() ?? 1;
        await client
            .from('guia_conocimiento_distribuido')
            .update({'veces_preguntado': veces + 1})
            .eq('id', id);
        debugPrint('[GroqService] 🕳️ Carencia ya registrada, incrementando veces: $intencion');
        return;
      }

      // Nueva carencia
      await client.from('guia_conocimiento_distribuido').insert({
        'libreria': 'general_tecnico',
        'categoria': 'carencia',
        'intencion': intencion,
        'activadores': [pregunta.toLowerCase().trim()],
        'respuesta_limpia': 'CARENCIA: El Guía no supo responder esto. Pregunta: ${pregunta.length > 100 ? pregunta.substring(0, 100) : pregunta}',
        'gif': 'piensaLeve',
        'puntaje': 0.0,
        'aprobado': false,
        'fuente': 'carencia_groq',
        'fecha_consolidacion': DateTime.now().toIso8601String().substring(0, 10),
        'veces_preguntado': 1,
        'limite_libreria': 200,
      });
      debugPrint('[GroqService] 🕳️ Carencia nueva guardada en Supabase: $intencion');
    } catch (e) {
      debugPrint('[GroqService] ⚠️ Error al guardar carencia: $e');
    }
  }

  /// Prueba la conexión contra Groq con una clave específica.
  Future<String> probarConexion(String apiKey) async {
    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': GroqConfig.modelo,
        'messages': [
          {'role': 'user', 'content': 'Respond strictly with: "Groq Llama 3.3 operativo"'},
        ],
        'temperature': 0.1,
      }),
    ).timeout(const Duration(seconds: 8));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices']?[0]?['message']?['content'] ?? '';
    } else {
      throw Exception('Código de estado ${response.statusCode}: ${response.body}');
    }
  }

  /// Redacta una salida de pesca con Groq en tono ribereño argentino
  static Future<String> redactarSalidaPesca({
    required String transcripcion,
    required String fecha,
    required String zona,
  }) async {
    if (!ConnectivityBridge.estaConectado) {
      throw Exception('Dispositivo sin conexión a internet.');
    }
    if (!GroqConfig.tieneApiKey) {
      throw Exception('Sin API Key de Groq configurada');
    }

    final systemPrompt = CapacitacionService.obtenerPromptRedactor();
    final userPrompt = """
Tomá este relato de pesca y redactá la nota periodística basada estrictamente en él:

Relato del pescador:
$transcripcion

Fecha de la salida: $fecha
Zona de pesca: $zona
""";

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Bearer ${GroqConfig.apiKey}',
      },
      body: jsonEncode({
        'model': GroqConfig.modelo,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userPrompt},
        ],
        'temperature': 0.7,
      }),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices']?[0]?['message']?['content'] ?? '';
    } else {
      throw Exception('Error en API Groq (Status ${response.statusCode}): ${response.body}');
    }
  }
}
