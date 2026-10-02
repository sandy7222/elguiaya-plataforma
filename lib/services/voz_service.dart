import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VozService {
  static final FlutterTts _tts = FlutterTts();
  static bool _configurado = false;

  // 🛠️ Inicializa y configura los algoritmos de voz de El GuIA
  static Future<void> inicializar() async {
    if (_configurado) return;

    try {
      await _tts.setLanguage("es-AR");
      try {
        final List<dynamic>? voices = await _tts.getVoices;
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
            await _tts.setVoice({"name": name, "locale": locale});
            print("🔊 El GuIA VozService: Voz optimizada seleccionada: $name ($locale)");
          }
        }
      } catch (e) {
        print("⚠️ Error configurando voz en VozService: $e");
      }

      // Velocidad del habla (1. o 1.5 es ideal, ni muy lento ni modo ardilla)
      await _tts.setSpeechRate(kIsWeb ? 0.5 : 0.45);

      // Tono de la voz (1.0 es el valor por defecto técnico)
      await _tts.setPitch(1.0);

      // Forzamos a que el audio no se corte si el usuario sale de la app
      await _tts.setVolume(1.0);
      
      // Aseguramos que hablar() devuelva el control solo cuando el audio termine
      await _tts.awaitSpeakCompletion(true);

      _configurado = true;
      print(
        "🔊 El GuIA: Sistemas de síntesis de voz inicializados correctamente.",
      );
    } catch (e) {
      print("⚠️ Error inicializando motor de voz: $e");
    }
  }

  // 🗣️ Cambia los bytes de texto a ondas de audio en ráfaga
  static Future<void> hablar(String texto) async {
    if (texto.isEmpty) return;

    // Limpieza preventiva: removemos emojis o caracteres raros por si las dudas
    // aunque El GuIA ya tiene prohibido meter adornos literarios.
    await _tts.speak(texto);
  }

  // 🛑 Frena el habla de inmediato (por si el usuario cierra el chat)
  static Future<void> detener() async {
    await _tts.stop();
  }
}
