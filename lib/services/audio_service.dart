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
      await _flutterTts.setLanguage("es-AR");
      await _configurarVozOptima(_flutterTts);
      await _flutterTts.setSpeechRate(kIsWeb ? 0.5 : 0.45); // Velocidad natural
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);
      _initialized = true;
      debugPrint('AudioService TTS inicializado con éxito (es-AR).');
    } catch (e) {
      debugPrint('Error inicializando AudioService TTS: $e');
    }
  }

  Future<void> _configurarVozOptima(FlutterTts tts) async {
    try {
      final List<dynamic>? voices = await tts.getVoices;
      if (voices != null && voices.isNotEmpty) {
        dynamic selectedVoice;
        final locales = ['es-AR', 'es-419', 'es-MX', 'es-US', 'es-ES'];
        for (final loc in locales) {
          for (final voice in voices) {
            if (voice is Map) {
              final locale = (voice['locale'] ?? voice['lang'] ?? '').toString().toLowerCase();
              final name = (voice['name'] ?? '').toString().toLowerCase();
              if (locale.contains(loc.toLowerCase()) || name.contains(loc.toLowerCase())) {
                selectedVoice = voice;
                break;
              }
            } else {
              final voiceStr = voice.toString().toLowerCase();
              if (voiceStr.contains(loc.toLowerCase())) {
                selectedVoice = voice;
                break;
              }
            }
          }
          if (selectedVoice != null) break;
        }

        if (selectedVoice != null && selectedVoice is Map) {
          final name = (selectedVoice['name'] ?? '').toString();
          final locale = (selectedVoice['locale'] ?? selectedVoice['lang'] ?? '').toString();
          await tts.setVoice({"name": name, "locale": locale});
          debugPrint('Voz optimizada seleccionada para AudioService: $name ($locale)');
        }
      }
    } catch (e) {
      debugPrint('Error al configurar voz óptima en AudioService: $e');
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
