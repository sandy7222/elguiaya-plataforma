import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VozService {
  static final FlutterTts _tts = FlutterTts();
  static bool _configurado = false;

  // 🛠️ Inicializa y configura los algoritmos de voz de El GuIA
  static Future<void> inicializar() async {
    if (_configurado) return;

    try {
      // Configuramos el idioma en español
      await _tts.setLanguage(
        "es-AR",
      ); // "es-AR" para acento argentino si está disponible, o "es-ES" / "es-MX"

      // Velocidad del habla (1. o 1.5 es ideal, ni muy lento ni modo ardilla)
      await _tts.setSpeechRate(kIsWeb ? 0.9 : 0.45);

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
