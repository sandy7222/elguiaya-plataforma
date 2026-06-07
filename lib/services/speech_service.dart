import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isAvailable = false;

  // Ya no inicializamos en el constructor porque el contexto
  // de permisos requiere que sea un proceso asíncrono controlado.
  SpeechService();

  Future<void> inicializar() async {
    // 1. Pedimos permiso explícitamente antes de tocar el hardware
    var status = await Permission.microphone.request();
    if (status.isGranted) {
      _isAvailable = await _speech.initialize(
        onError: (val) => debugPrint('⚠️ Error STT: $val'),
        onStatus: (val) => debugPrint('🎙️ Estado STT: $val'),
      );
    } else {
      debugPrint("❌ Permiso de micrófono denegado.");
    }
  }

  Future<void> escuchar({required Function(String) alResultado}) async {
    // Si no está disponible, intentamos re-inicializar
    if (!_isAvailable) {
      await inicializar();
    }

    if (_isAvailable) {
      await _speech.listen(
        onResult: (val) {
          if (val.finalResult) {
            alResultado(val.recognizedWords);
          }
        },
        localeId: 'es_AR',
        cancelOnError: true,
        listenMode: stt.ListenMode.dictation,
      );
    } else {
      debugPrint("❌ El reconocimiento de voz no está disponible.");
    }
  }

  Future<void> detener() async {
    await _speech.stop();
  }
}
