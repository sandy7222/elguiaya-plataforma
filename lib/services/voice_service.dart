import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  // STT secundario exclusivo para el VAD (Voice Activity Detection).
  final stt.SpeechToText _vadSpeech = stt.SpeechToText();

  // STT terciario exclusivo para el Wake Word listener.
  final stt.SpeechToText _wakeWordSpeech = stt.SpeechToText();

  bool _isTtsInitialized = false;
  bool _isSttInitialized = false;
  bool _isVadInitialized = false;
  bool _isWakeWordInitialized = false;

  // Notificador del estado de escucha activa para sincronizar la UI
  final ValueNotifier<bool> isListeningNotifier = ValueNotifier<bool>(false);

  /// true mientras el GuIA está hablando (TTS activo)
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  /// true mientras el VAD está escuchando en segundo plano
  bool _isVadListening = false;

  /// true mientras el wake word listener está activo
  bool _isWakeWordListening = false;
  Timer? _wakeWordTimer;

  // Frases trigger aceptadas para activar el GuIA por voz.
  // Se detectan por contains() en minúsculas — tolerante a variaciones.
  static const List<String> _wakeWordTriggers = [
    'guía',
    'guia',
    'chamigo',
    'pregunta guía',
    'pregunta guia',
    'oye guía',
    'oye guia',
    'una pregunta',
  ];

  Future<void> init() async {
    // Solo inicializamos TTS (síntesis de voz) — no necesita permisos.
    // El STT (reconocimiento de voz) se inicializa de forma lazy en el
    // primer uso real del micrófono para no disparar el diálogo de permiso
    // al arrancar la app antes de que el usuario active el GuIA.
    await _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setLanguage("es-AR");
      await _flutterTts.setSpeechRate(
        kIsWeb ? 0.9 : 0.45,
      ); // Adaptar velocidad según plataforma (0.9 en Web, 0.45 en móvil)
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(0.9); // Tono ligeramente más grave
      try {
        await _flutterTts.awaitSpeakCompletion(true);
      } catch (e) {
        debugPrint('awaitSpeakCompletion no soportado: $e');
      }
      _isTtsInitialized = true;
      _registerCompletionHandler();
    } catch (e) {
      debugPrint('Error inicializando TTS: $e');
    }
  }

  Future<void> _initStt() async {
    try {
      // Solo inicializa el motor. El permiso de micrófono se pide en startListening,
      // cuando el usuario toca el botón del mic — nunca al arrancar la app.
      _isSttInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('Error STT: ${val.errorMsg}');
          isListeningNotifier.value = false;
        },
        onStatus: (val) {
          debugPrint('Status STT: $val');
          if (val == 'listening') {
            isListeningNotifier.value = true;
          } else if (val == 'notListening' || val == 'done') {
            isListeningNotifier.value = false;
          }
        },
      );
    } catch (e) {
      debugPrint('Error inicializando STT: $e');
      isListeningNotifier.value = false;
    }
  }

  /// Inicializa el STT de forma explícita (llamado desde el perfil cuando el
  /// usuario activa los comandos de voz y ya tiene el permiso concedido).
  Future<void> initStt() => _initStt();

  Future<void> _initVad() async {
    if (_isVadInitialized) return;
    try {
      _isVadInitialized = await _vadSpeech.initialize(
        onError: (val) => debugPrint('Error VAD: ${val.errorMsg}'),
        onStatus: (val) => debugPrint('Status VAD: $val'),
      );
    } catch (e) {
      debugPrint('Error inicializando VAD: $e');
    }
  }

  Future<void> _initWakeWord() async {
    if (_isWakeWordInitialized) return;
    try {
      _isWakeWordInitialized = await _wakeWordSpeech.initialize(
        onError: (val) => debugPrint('Error WakeWord: ${val.errorMsg}'),
        onStatus: (val) => debugPrint('Status WakeWord: $val'),
      );
    } catch (e) {
      debugPrint('Error inicializando WakeWord: $e');
    }
  }

  Future<void> speak(String text) async {
    if (!_isTtsInitialized) await _initTts();

    // Corregir la pronunciación del asistente "Gu-IA" para que suene como "el Guía"
    String cleanText = text.replaceAll(
      RegExp(r'Gu-IA', caseSensitive: false),
      'el Guía',
    );

    // Limpiar markdown y caracteres no pronunciables como emojis
    cleanText = cleanText.replaceAll('\$', ' pesos ');
    cleanText = cleanText.replaceAll('*', '');
    cleanText = cleanText.replaceAll('_', '');
    cleanText = cleanText.replaceAll('#', '');

    // Eliminar emojis y caracteres no pronunciables (conserva letras, números, acentos y puntuación básica)
    cleanText = cleanText.replaceAll(
      RegExp(r'[^\w\sáéíóúÁÉÍÓÚñÑüÜ.,;:!?()¡¿\-]', unicode: true),
      '',
    );

    // Colapsar múltiples espacios
    cleanText = cleanText.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleanText.isNotEmpty) {
      _isSpeaking = true;
      _registerCompletionHandler(); // Re-registrar para evitar pérdida del callback en transiciones de foco de audio/mic
      await _flutterTts.speak(cleanText);
    }
  }

  Function()? _completionHandler;

  void setCompletionHandler(Function() onComplete) {
    _completionHandler = onComplete;
    _registerCompletionHandler();
  }

  void _registerCompletionHandler() {
    _flutterTts.setCompletionHandler(() {
      debugPrint('[VoiceService] TTS Completion Callback');
      _isSpeaking = false;
      if (_completionHandler != null) {
        _completionHandler!();
      }
    });
    _flutterTts.setCancelHandler(() {
      debugPrint('[VoiceService] TTS Cancel Callback');
      _isSpeaking = false;
      if (_completionHandler != null) {
        _completionHandler!();
      }
    });
    _flutterTts.setErrorHandler((message) {
      debugPrint('[VoiceService] TTS Error Callback: $message');
      _isSpeaking = false;
      if (_completionHandler != null) {
        _completionHandler!();
      }
    });
  }

  Future<void> stop() async {
    _isSpeaking = false;
    await _flutterTts.stop();
  }

  bool get isListening => _speech.isListening;

  Future<bool> startListening(Function(String, bool) onResult) async {
    // Detener otros reconocedores para liberar el recurso nativo de audio
    await stopVADListener();
    await stopWakeWordListener();

    // Pedir permiso de micrófono aquí, solo cuando el usuario lo necesita
    if (!_isSttInitialized) {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('Permiso de micrófono denegado.');
          isListeningNotifier.value = false;
          return false;
        }
      }
      await _initStt();
    }
    if (_isSttInitialized) {
      isListeningNotifier.value = true;
      await _speech.listen(
        onResult: (result) {
          onResult(result.recognizedWords, result.finalResult);
        },
        localeId: "es_AR",
        listenFor: const Duration(
          seconds: 40,
        ), // Aumentado a 40s para que no se corte al formular preguntas largas
        pauseFor: const Duration(
          milliseconds: 1000,
        ), // Reducido a 1.0s para mayor velocidad de respuesta
        cancelOnError: false,
      );
      return true;
    }
    isListeningNotifier.value = false;
    return false;
  }

  Future<void> stopListening() async {
    await _speech.stop();
    isListeningNotifier.value = false;
  }

  // ── VAD (Voice Activity Detection) ──────────────────────────────────────
  // Escucha en segundo plano mientras el GuIA habla.
  // Si detecta que el usuario empezó a hablar, llama a onInterrupcion().
  // Usa onDevice:true para poder correr en paralelo al TTS sin conflicto de audio.

  /// Inicia la escucha VAD. Llama [onInterrupcion] con el texto parcial detectado.
  Future<void> startVADListener(
    Function(String textoDetectado) onInterrupcion,
  ) async {
    if (_isVadListening) return;
    // Detener otros reconocedores para liberar el recurso nativo de audio
    await stopListening();
    await stopWakeWordListener();

    await _initVad();
    if (!_isVadInitialized) return;

    try {
      _isVadListening = true;
      await _vadSpeech.listen(
        onResult: (result) {
          // Si el STT retornó palabras, el usuario habló → interrupción
          if (result.recognizedWords.trim().isNotEmpty) {
            final palabrasDetectadas = result.recognizedWords.trim();
            stopVADListener();
            onInterrupcion(palabrasDetectadas); // pasa el texto ya capturado
          }
        },
        localeId: 'es_AR',
        listenFor: const Duration(
          seconds: 60,
        ), // escucha larga mientras el GuIA habla
        pauseFor: const Duration(
          milliseconds: 1500,
        ), // reacciona rápido (1.5s de silencio)
        cancelOnError: true,
        onDevice: true, // clave: permite correr en paralelo al TTS en Android
        partialResults: true, // detecta apenas el usuario empieza a hablar
      );
    } catch (e) {
      debugPrint('Error iniciando VAD: $e');
      _isVadListening = false;
    }
  }

  /// Detiene el VAD listener.
  Future<void> stopVADListener() async {
    if (!_isVadListening) return;
    _isVadListening = false;
    try {
      await _vadSpeech.stop();
    } catch (e) {
      debugPrint('Error deteniendo VAD: $e');
    }
  }

  // ── Wake Word Listener ───────────────────────────────────────────────────
  // Escucha en bursts periódicos buscando la frase de activación mientras
  // el GuIA duerme. Sin dependencias nuevas — usa el STT del sistema.
  // Burst: 4s de escucha → 1.5s de pausa → repite hasta detectar o parar.

  /// Inicia el listener de wake word. Llama [onWake] al detectar la frase.
  Future<void> startWakeWordListener(Function() onWake) async {
    if (_isWakeWordListening) return;
    // Detener otros reconocedores para liberar el recurso nativo de audio
    await stopListening();
    await stopVADListener();

    await _initWakeWord();
    if (!_isWakeWordInitialized) return;
    _isWakeWordListening = true;
    _runWakeWordBurst(onWake);
  }

  void _runWakeWordBurst(Function() onWake) async {
    if (!_isWakeWordListening || !_isWakeWordInitialized) return;
    try {
      await _wakeWordSpeech.listen(
        onResult: (result) {
          if (!_isWakeWordListening) return;
          final text = result.recognizedWords.toLowerCase();
          if (_wakeWordTriggers.any((trigger) => text.contains(trigger))) {
            stopWakeWordListener();
            onWake();
          }
        },
        localeId: 'es_AR',
        listenFor: const Duration(seconds: 4),
        pauseFor: const Duration(seconds: 2),
        cancelOnError: false,
        onDevice: true, // bajo consumo, sin red
        partialResults: true, // detecta apenas empieza a decir la frase
      );
    } catch (e) {
      debugPrint('Error en burst wake word: $e');
    }
    // Después del burst (4s de escucha + 1.5s de pausa de descanso), espera 6s y repite si sigue activo.
    // Esto evita llamadas listen() superpuestas en el mismo reconocedor.
    _wakeWordTimer = Timer(const Duration(seconds: 6), () {
      if (_isWakeWordListening) _runWakeWordBurst(onWake);
    });
  }

  /// Detiene el wake word listener.
  Future<void> stopWakeWordListener() async {
    if (!_isWakeWordListening) return;
    _isWakeWordListening = false;
    _wakeWordTimer?.cancel();
    _wakeWordTimer = null;
    try {
      await _wakeWordSpeech.stop();
    } catch (e) {
      debugPrint('Error deteniendo WakeWord: $e');
    }
  }
}
