import 'dart:convert';
import 'dart:math';
import 'gemini_learner.dart';

/// GuiaLocalUpdater — Inyecta el conocimiento aprendido al motor local.
///
/// Al inicializar ElGuiaEngine, este servicio carga todos los JSONs
/// generados por GeminiLearner y los convierte en activadores y respuestas
/// que el motor puede usar sin señal.
///
/// Es el puente entre el "aprendizaje online" y la "memoria offline".
class GuiaLocalUpdater {
  static final Random _random = Random();

  // Cache en memoria para no leer disco en cada pregunta
  static Map<String, _IntentAprendido> _cache = {};
  static bool _cargado = false;

  /// Carga todos los aprendizajes en memoria.
  /// Llamar al inicializar ElGuiaEngine.
  static Future<void> cargar() async {
    try {
      final datos = await GeminiLearner.cargarTodo();
      _cache = {};

      for (final entry in datos.entries) {
        final intencion = entry.key;
        final json = entry.value as Map<String, dynamic>;

        final activadores = List<String>.from(
          (json['activadores'] as List<dynamic>? ?? []).map((e) => e.toString().toLowerCase()),
        );
        final respuestas = List<String>.from(
          (json['respuestas'] as List<dynamic>? ?? []).map((e) => e.toString()),
        );
        final gif = json['gif']?.toString() ?? 'hablaConMate';
        final puntaje = (json['puntaje'] as num?)?.toDouble() ?? 5.0;

        if (activadores.isNotEmpty && respuestas.isNotEmpty) {
          _cache[intencion] = _IntentAprendido(
            intencion: intencion,
            activadores: activadores,
            respuestas: respuestas,
            gif: gif,
            puntaje: puntaje,
          );
        }
      }

      _cargado = true;
      // ignore: avoid_print
      print('[LocalUpdater] ✅ ${_cache.length} intenciones aprendidas cargadas en memoria');
    } catch (e) {
      // ignore: avoid_print
      print('[LocalUpdater] ⚠️ Error cargando aprendizajes: $e');
    }
  }

  /// Recarga el cache (llamar después de que Gemini aprende algo nuevo).
  static Future<void> recargar() async {
    _cargado = false;
    await cargar();
  }

  /// Detecta si el texto coincide con alguna intención aprendida.
  /// Retorna el nombre de la intención o null si no hay match.
  static String? detectarIntencion(String textoNormalizado) {
    if (!_cargado || _cache.isEmpty) return null;

    for (final entry in _cache.entries) {
      for (final activador in entry.value.activadores) {
        if (textoNormalizado.contains(activador)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  /// Obtiene una respuesta aleatoria para la intención aprendida.
  static String? obtenerRespuesta(String intencion) {
    final intent = _cache[intencion];
    if (intent == null || intent.respuestas.isEmpty) return null;
    return intent.respuestas[_random.nextInt(intent.respuestas.length)];
  }

  /// Obtiene el gif sugerido para la intención.
  static String obtenerGif(String intencion) {
    return _cache[intencion]?.gif ?? 'hablaConMate';
  }

  /// Retorna todos los activadores en un Map compatible con el motor.
  static Map<String, List<String>> obtenerActivadoresParaMotor() {
    final resultado = <String, List<String>>{};
    for (final entry in _cache.entries) {
      resultado[entry.key] = entry.value.activadores;
    }
    return resultado;
  }

  /// Estado del cache para diagnóstico.
  static Map<String, dynamic> diagnostico() {
    return {
      'cargado': _cargado,
      'total_intenciones': _cache.length,
      'total_activadores': _cache.values.fold<int>(0, (sum, i) => sum + i.activadores.length),
      'intenciones': _cache.keys.toList(),
    };
  }

  static bool get estaCargado => _cargado;
  static int get totalIntenciones => _cache.length;
}

/// Modelo interno de intención aprendida.
class _IntentAprendido {
  final String intencion;
  final List<String> activadores;
  final List<String> respuestas;
  final String gif;
  final double puntaje;

  const _IntentAprendido({
    required this.intencion,
    required this.activadores,
    required this.respuestas,
    required this.gif,
    required this.puntaje,
  });
}
