import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Servicio de Audio y Text-to-Speech (TTS) reutilizable.
class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  bool _initialized = false;

  /// Inicializa el motor de TTS configurando voz en español y velocidad natural.
  Future<void> inicializar() async {
    if (_initialized) return;
    try {
      await _flutterTts.setLanguage("es-ES");
      await _flutterTts.setSpeechRate(0.9); // Velocidad natural rápida
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _initialized = true;
      debugPrint('AudioService TTS inicializado con éxito (es-ES, rate 0.9).');
    } catch (e) {
      debugPrint('Error inicializando AudioService TTS: $e');
    }
  }

  /// Método público para reproducir voz sin bloquear el hilo principal.
  Future<void> speak(String text) async {
    if (!_initialized) {
      await inicializar();
    }
    if (text.isNotEmpty) {
      // FlutterTts.speak se ejecuta asíncronamente
      await _flutterTts.speak(text);
    }
  }
}
