import 'guia_wake_word.dart';
import 'guia_texto_voz.dart';
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'connectivity_bridge.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _flutterTts = FlutterTts();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isTtsInitialized = false;
  bool _isSttInitialized = false;

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

  /// Último texto que devolvió el STT en la sesión principal (parcial o final).
  String _ultimoTextoReconocido = '';
  String get ultimoTextoReconocido => _ultimoTextoReconocido;

  Function(String, bool)? _onResultCallback;
  VoidCallback? _onSessionEnded;
  void Function(String error)? _onSttError;
  bool _escuchaPrincipalActiva = false;
  bool _usandoOnDevice = false;
  bool _reintentandoEnNube = false;
  bool _silenciarCompletionHandler = false;
  bool _vioListeningEstaSesion = false;
  DateTime? _escuchaIniciadaEn;
  int _sesionStt = 0;
  int _reaperturasSilencio = 0;
  String? _localeSttResuelto;

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
      await _configurarVozOptima(_flutterTts);
      await _flutterTts.setSpeechRate(
        kIsWeb ? 0.5 : 0.45,
      ); // Adaptar velocidad según plataforma (0.5 en Web, 0.45 en móvil)
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
          debugPrint('Voz optimizada seleccionada para El Guía: $name ($locale)');
        }
      }
    } catch (e) {
      debugPrint('Error al configurar voz óptima en El Guía: $e');
    }
  }

  Future<void> _initStt() async {
    if (_isSttInitialized) return;
    try {
      // Solo inicializa el motor. El permiso de micrófono se pide en startListening,
      // cuando el usuario toca el botón del mic — nunca al arrancar la app.
      _isSttInitialized = await _speech.initialize(
        onError: (val) {
          debugPrint('Error STT: ${val.errorMsg}');
          _manejarErrorSttPrincipal(val.errorMsg);
        },
        onStatus: (val) {
          debugPrint('Status STT: $val');
          if (_isVadListening || _isWakeWordListening) {
            return;
          }
          if (val == 'listening') {
            _vioListeningEstaSesion = true;
            isListeningNotifier.value = true;
          } else if (val == 'notListening' || val == 'done') {
            if (!_puedeCerrarSesionStt()) {
              debugPrint(
                '[VoiceService] Status $val ignorado (sesión aún no establecida)',
              );
              return;
            }
            isListeningNotifier.value = false;
            _notificarFinSesionStt();
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

  Future<void> _initVad() => _initStt();

  Future<void> _initWakeWord() => _initStt();

  Future<void> speak(String text) async {
    if (!_isTtsInitialized) await _initTts();

    // Corregir la pronunciación del asistente "Gu-IA" para que suene como "el Guía"
    // Paso 1.2b: la preparación del texto para voz vive en un solo lugar.
    String cleanText = GuiaTextoVoz.preparar(text).replaceAll(
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
      try {
        await _flutterTts.speak(cleanText);
      } catch (e) {
        _isSpeaking = false;
        debugPrint('Error en _flutterTts.speak: $e');
      }
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
      _manejarFinTts();
    });
    _flutterTts.setCancelHandler(() {
      debugPrint('[VoiceService] TTS Cancel Callback');
      _manejarFinTts();
    });
    _flutterTts.setErrorHandler((message) {
      debugPrint('[VoiceService] TTS Error Callback: $message');
      _manejarFinTts();
    });
  }

  void _manejarFinTts() {
    _isSpeaking = false;
    if (_silenciarCompletionHandler) {
      _silenciarCompletionHandler = false;
      return;
    }
    _completionHandler?.call();
  }

  Future<void> stop({bool notifyCompletion = true}) async {
    _isSpeaking = false;
    if (!notifyCompletion) {
      _silenciarCompletionHandler = true;
    }
    await _flutterTts.stop();
    if (!notifyCompletion) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _silenciarCompletionHandler = false;
      });
    }
  }

  bool get isListening => _speech.isListening;

  Future<bool> startListening(
    Function(String, bool) onResult, {
    VoidCallback? onSessionEnded,
    void Function(String error)? onError,
  }) async {
    // Liberar TTS y otros reconocedores para no pelear el foco de audio.
    await stop(notifyCompletion: false);
    await stopVADListener();
    await stopWakeWordListener();

    // El stop() nativo emite notListening; hay que esperar a que se drene
    // antes de marcar la sesión nueva, si no la matamos al milisegundo.
    await Future.delayed(const Duration(milliseconds: 250));

    _onResultCallback = onResult;
    _onSessionEnded = onSessionEnded;
    _onSttError = onError;
    _ultimoTextoReconocido = '';
    _reintentandoEnNube = false;
    _vioListeningEstaSesion = false;
    _reaperturasSilencio = 0;
    _sesionStt++;
    final sesion = _sesionStt;

    // Pedir permiso de micrófono aquí, solo cuando el usuario lo necesita
    if (!_isSttInitialized) {
      if (!kIsWeb) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          debugPrint('Permiso de micrófono denegado.');
          isListeningNotifier.value = false;
          onError?.call('permiso_denegado');
          return false;
        }
      }
      await _initStt();
    }
    if (!_isSttInitialized) {
      isListeningNotifier.value = false;
      onError?.call('stt_no_disponible');
      return false;
    }

    final hayRed = ConnectivityBridge.estaConectado;
    // Con señal: STT de Google en la nube (el mic se queda abierto).
    // Sin señal: on-device. Forzar on-device con Wi‑Fi corta el mic en ~1s
    // si el celular no tiene el paquete offline.
    _usandoOnDevice = !hayRed;
    debugPrint(
      '[VoiceService] startListening onDevice=$_usandoOnDevice hayRed=$hayRed',
    );

    final localeId = await _resolverLocaleStt();
    _escuchaPrincipalActiva = true;
    _escuchaIniciadaEn = DateTime.now();
    isListeningNotifier.value = true;

    var ok = await _escuchar(localeId: localeId, onDevice: _usandoOnDevice);

    if (!ok && !_usandoOnDevice) {
      debugPrint('[VoiceService] Nube no arrancó; último intento on-device...');
      _usandoOnDevice = true;
      ok = await _escuchar(localeId: localeId, onDevice: true);
    } else if (!ok && _usandoOnDevice && hayRed) {
      debugPrint('[VoiceService] On-device no arrancó; reintento en nube...');
      _usandoOnDevice = false;
      ok = await _escuchar(localeId: localeId, onDevice: false);
    }

    if (!ok || sesion != _sesionStt) {
      _escuchaPrincipalActiva = false;
      isListeningNotifier.value = false;
      onError?.call(hayRed ? 'stt_no_disponible' : 'stt_offline');
      return false;
    }
    return true;
  }

  Future<bool> _escuchar({
    required String localeId,
    required bool onDevice,
  }) async {
    try {
      await _speech.listen(
        onResult: (result) {
          _ultimoTextoReconocido = result.recognizedWords;
          _onResultCallback?.call(result.recognizedWords, result.finalResult);
        },
        localeId: localeId,
        listenFor: const Duration(seconds: 40),
        pauseFor: const Duration(seconds: 4),
        cancelOnError: false,
        partialResults: true,
        onDevice: onDevice,
      );
      return true;
    } catch (e) {
      debugPrint('[VoiceService] Error listen onDevice=$onDevice: $e');
      return false;
    }
  }

  Future<String> _resolverLocaleStt() async {
    if (_localeSttResuelto != null) return _localeSttResuelto!;
    const preferidos = [
      'es_AR',
      'es-AR',
      'es_419',
      'es-419',
      'es_MX',
      'es-MX',
      'es_ES',
      'es-ES',
      'es_US',
      'es-US',
    ];
    String norm(String s) => s.replaceAll('-', '_').toLowerCase();
    try {
      final locales = await _speech.locales();
      final ids = locales.map((l) => l.localeId).toList();
      if (ids.isEmpty) {
        _localeSttResuelto = 'es_AR';
        return 'es_AR';
      }
      for (final preferido in preferidos) {
        for (final id in ids) {
          if (norm(id) == norm(preferido)) {
            _localeSttResuelto = id;
            debugPrint('[VoiceService] Locale STT: $id');
            return id;
          }
        }
      }
      for (final id in ids) {
        if (id.toLowerCase().startsWith('es')) {
          _localeSttResuelto = id;
          debugPrint('[VoiceService] Locale STT (fallback es): $id');
          return id;
        }
      }
    } catch (e) {
      debugPrint('[VoiceService] Error listando locales STT: $e');
    }
    _localeSttResuelto = 'es_ES';
    return _localeSttResuelto!;
  }

  bool _esErrorOnDeviceNoDisponible(String msg) {
    final m = msg.toLowerCase();
    return m.contains('language') ||
        m.contains('unavailable') ||
        m.contains('not_supported') ||
        m.contains('listen_failed') ||
        m.contains('error_client') ||
        m.contains('error_busy');
  }

  bool _esErrorSilencio(String msg) {
    final m = msg.toLowerCase();
    return m.contains('error_no_match') ||
        m.contains('error_speech_timeout') ||
        m.contains('no_match') ||
        m.contains('speech_timeout');
  }

  bool _puedeCerrarSesionStt() {
    if (!_escuchaPrincipalActiva || _reintentandoEnNube) return false;
    // El stop() anterior emite notListening; no cerrar hasta que esta
    // sesión haya llegado a 'listening'.
    if (!_vioListeningEstaSesion) return false;
    return true;
  }

  void _manejarErrorSttPrincipal(String errorMsg) {
    if (_isVadListening || _isWakeWordListening) return;
    if (!_escuchaPrincipalActiva) return;

    if (_esErrorSilencio(errorMsg)) {
      if (_ultimoTextoReconocido.trim().isNotEmpty) {
        isListeningNotifier.value = false;
        _notificarFinSesionStt();
        return;
      }
      if (_reaperturasSilencio < 4) {
        _reaperturasSilencio++;
        debugPrint(
          '[VoiceService] STT silencio ($errorMsg), reabriendo mic (#$_reaperturasSilencio)...',
        );
        Future.microtask(() async {
          if (!_escuchaPrincipalActiva) return;
          final localeId = await _resolverLocaleStt();
          await _escuchar(localeId: localeId, onDevice: _usandoOnDevice);
        });
        return;
      }
    }

    if (_usandoOnDevice &&
        !_reintentandoEnNube &&
        ConnectivityBridge.estaConectado &&
        _esErrorOnDeviceNoDisponible(errorMsg)) {
      debugPrint(
        '[VoiceService] STT on-device falló ($errorMsg), reintentando en nube...',
      );
      _reintentandoEnNube = true;
      Future.microtask(() async {
        _usandoOnDevice = false;
        _vioListeningEstaSesion = false;
        _escuchaIniciadaEn = DateTime.now();
        final localeId = await _resolverLocaleStt();
        final ok = await _escuchar(localeId: localeId, onDevice: false);
        _reintentandoEnNube = false;
        if (!ok) {
          _escuchaPrincipalActiva = false;
          isListeningNotifier.value = false;
          _onSttError?.call(errorMsg);
        }
      });
      return;
    }

    if (_reintentandoEnNube) return;
    isListeningNotifier.value = false;
    _escuchaPrincipalActiva = false;
    _onSttError?.call(
      ConnectivityBridge.estaConectado ? errorMsg : 'stt_offline',
    );
  }

  void _notificarFinSesionStt() {
    if (_isVadListening || _isWakeWordListening) return;
    if (_reintentandoEnNube) return;
    if (!_escuchaPrincipalActiva) return;
    if (!_puedeCerrarSesionStt() && _ultimoTextoReconocido.trim().isEmpty) {
      return;
    }
    _escuchaPrincipalActiva = false;
    _onSessionEnded?.call();
  }

  Future<void> stopListening() async {
    final debiaNotificar = _escuchaPrincipalActiva;
    _escuchaPrincipalActiva = false;
    await _speech.stop();
    isListeningNotifier.value = false;
    if (debiaNotificar) {
      _onSessionEnded?.call();
    }
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
    if (!_isSttInitialized) return;

    try {
      _isVadListening = true;
      await _speech.listen(
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
      await _speech.stop();
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
    if (!GuiaWakeWord.habilitado) return; // apagado por flag: abría el micrófono cada 6 s y fallaba
    if (_isWakeWordListening) return;
    // Detener otros reconocedores para liberar el recurso nativo de audio
    await stopListening();
    await stopVADListener();

    await _initWakeWord();
    if (!_isSttInitialized) return;
    _isWakeWordListening = true;
    _runWakeWordBurst(onWake);
  }

  void _runWakeWordBurst(Function() onWake) async {
    if (!_isWakeWordListening || !_isSttInitialized) return;
    try {
      await _speech.listen(
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
      await _speech.stop();
    } catch (e) {
      debugPrint('Error deteniendo WakeWord: $e');
    }
  }
}
