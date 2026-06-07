import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'capitan_asistente.dart';
import '../services/baqueano_ia_service.dart';
import '../models/el_guia_respuesta.dart';
import '../services/voice_service.dart';
import '../services/connectivity_bridge.dart';
import '../services/intent_service.dart';
import '../screens/pescador_perfil_edit_screen.dart';



/// Notifier global â€” cualquier parte de la app puede activar/desactivar el Guía
/// sin necesidad de pasar callbacks. Leer/escribir con GuiaOverlayController.
class GuiaOverlayController {
  static final ValueNotifier<bool> activo = ValueNotifier(false);
  static final ValueNotifier<bool> silenciado = ValueNotifier(false);
  static final ValueNotifier<bool> micActivo = ValueNotifier(true);

  /// Llama esto desde pescador_perfil_edit_screen al cambiar el toggle
  static Future<void> setActivo(bool value) async {
    activo.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guia_activo', value);
  }

  static Future<void> setSilenciado(bool value) async {
    silenciado.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guia_silenciado', value);
  }

  static Future<void> setMicActivo(bool value) async {
    micActivo.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guia_mic_activo', value);
  }

  /// Carga la preferencia guardada al arrancar la app
  static Future<void> cargarPreferencia() async {
    final prefs = await SharedPreferences.getInstance();
    activo.value = prefs.getBool('guia_activo') ?? true;
    silenciado.value = prefs.getBool('guia_silenciado') ?? false;
    micActivo.value = prefs.getBool('guia_mic_activo') ?? true;
  }
}

/// Widget global que se inserta en el builder de MaterialApp.
/// Flota sobre todas las pantallas y persiste entre cambios de tab/ruta.
class GuiaOverlay extends StatefulWidget {
  const GuiaOverlay({super.key});

  @override
  State<GuiaOverlay> createState() => _GuiaOverlayState();
}

class _GuiaOverlayState extends State<GuiaOverlay> {
  // â”€â”€ Estado del robot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  bool _mostrarGuia = false;
  bool _permiteInteractuar = false;
  CapitanState _estadoGuia = CapitanState.aparece;
  double _avatarScale = 1.0;
  double _avatarOpacity = 1.0;

  // ── Posición arrastrable ─────────────────────────────────────────────
  double _robotX = -1; // -1 = no inicializado todavía
  double _robotY = -1;

  // ── Animación flotante (bob) ─────────────────────────────────────────
  double _bobOffset = 0.0;
  Timer? _bobTimer;

  // â”€â”€ Conversación â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final TextEditingController _chatController = TextEditingController();
  final List<Map<String, String>> _chatHistory = [];
  bool _isListening = false;
  bool _isMuted = false;
  bool _isTyping = false;
  bool _haySenal = true;
  bool _modoConversacionVoz = false;

  // ── Verificación de Rol ──────────────────────────────────────────────
  bool _rolVerificado = false;
  bool _esCapitanOAdmin = false;
  StreamSubscription<AuthState>? _authSub;

  // â”€â”€ Timers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Timer? _avatarTimer;
  Timer? _inactividadTimer;

  @override
  void initState() {
    super.initState();
    VoiceService().init();

    // Saludo inicial (solo una vez)
    _chatHistory.add({
      'text': '¡Hola amigo! Soy el Guía, tu compañero. Preguntame lo que quieras sobre la pesca o tocá el micrófono para charlar.',
      'isUser': 'false',
    });

    // Escuchar cambios del notifier
    GuiaOverlayController.activo.addListener(_onActivoChanged);
    GuiaOverlayController.silenciado.addListener(_onSilenciadoChanged);
    GuiaOverlayController.micActivo.addListener(_onMicActivoChanged);

    _isMuted = GuiaOverlayController.silenciado.value;

    // Conectividad
    _haySenal = ConnectivityBridge.estaConectado;
    ConnectivityBridge.conexionStream.listen((conectado) {
      if (mounted) setState(() => _haySenal = conectado);
    });

    // Loop de conversación: después de que termina de hablar, vuelve a escuchar (solo si el modo voz está activo)
    VoiceService().setCompletionHandler(() {
      if (mounted && _mostrarGuia && !_isMuted && _permiteInteractuar && _modoConversacionVoz && !_isListening) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && _mostrarGuia && !_isMuted && _permiteInteractuar && _modoConversacionVoz && !_isListening) {
            _iniciarEscuchaAutomatica();
          }
        });
      }
    });

    // Escuchar cambios de autenticación para resetear/verificar roles
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (!mounted) return;
      final session = data.session;
      setState(() {
        _rolVerificado = false;
        _esCapitanOAdmin = false;
      });
      if (session != null) {
        _verificarRolUsuario(session.user.id);
      } else {
        if (_mostrarGuia) {
          _apagarGuia();
        }
      }
    });

    // Si ya hay sesión activa al iniciar, verificar rol
    final inicialSession = Supabase.instance.client.auth.currentSession;
    if (inicialSession != null) {
      _verificarRolUsuario(inicialSession.user.id);
    }
  }

  @override
  void dispose() {
    GuiaOverlayController.activo.removeListener(_onActivoChanged);
    GuiaOverlayController.silenciado.removeListener(_onSilenciadoChanged);
    GuiaOverlayController.micActivo.removeListener(_onMicActivoChanged);
    _authSub?.cancel();
    _chatController.dispose();
    _avatarTimer?.cancel();
    _inactividadTimer?.cancel();
    _bobTimer?.cancel();
    VoiceService().stop();
    VoiceService().stopVADListener();
    VoiceService().stopWakeWordListener();
    super.dispose();
  }

  Future<void> _verificarRolUsuario(String userId) async {
    final email = Supabase.instance.client.auth.currentSession?.user.email ?? '';
    final bool isHardcodedAdmin = email.toLowerCase().trim() == 'admin@capitanya.com';
    final bool isMetadataAdmin = Supabase.instance.client.auth.currentSession?.user.userMetadata?['rol']?.toString().toLowerCase() == 'admin';

    if (isHardcodedAdmin || isMetadataAdmin) {
      if (mounted) {
        setState(() {
          _rolVerificado = true;
          _esCapitanOAdmin = true;
        });
        if (_mostrarGuia) {
          _apagarGuia();
        }
      }
      return;
    }

    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('es_capitan, es_admin')
          .eq('user_id', userId)
          .maybeSingle();

      if (res != null) {
        final esCapitan = res['es_capitan'] == true;
        final esAdmin = res['es_admin'] == true;
        final capOAdmin = esCapitan || esAdmin;

        if (mounted) {
          setState(() {
            _rolVerificado = true;
            _esCapitanOAdmin = capOAdmin;
          });
          if (capOAdmin) {
            if (_mostrarGuia) {
              _apagarGuia();
            }
          } else {
            // Es pescador, si debe estar activo y no se muestra, encenderlo
            if (GuiaOverlayController.activo.value && !_mostrarGuia) {
              _encenderGuia();
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _rolVerificado = true;
            _esCapitanOAdmin = false;
          });
          if (GuiaOverlayController.activo.value && !_mostrarGuia) {
            _encenderGuia();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error en _verificarRolUsuario de El Guía: $e');
      if (mounted) {
        setState(() {
          _rolVerificado = true;
          _esCapitanOAdmin = false;
        });
        if (GuiaOverlayController.activo.value && !_mostrarGuia) {
          _encenderGuia();
        }
      }
    }
  }

  void _onSilenciadoChanged() {
    if (!mounted) return;
    setState(() {
      _isMuted = GuiaOverlayController.silenciado.value;
    });
    if (_isMuted) {
      VoiceService().stop();
    }
  }

  void _onMicActivoChanged() {
    if (!mounted) return;
    setState(() {
      if (!GuiaOverlayController.micActivo.value && _isListening) {
        VoiceService().stopListening();
        _isListening = false;
        _estadoGuia = CapitanState.durmiendo;
        _modoConversacionVoz = false;
      }
    });
    // Si el mic se desactivó, para el wake word; si se activó y está durmiendo, lo arranca
    _verificarWakeWord();
  }

  void _onActivoChanged() {
    if (!mounted) return;
    if (GuiaOverlayController.activo.value) {
      if (!_mostrarGuia && !(_rolVerificado && _esCapitanOAdmin)) {
        _encenderGuia();
      }
    } else {
      if (_mostrarGuia) _apagarGuia();
    }
  }

  // â”€â”€ Ciclo de vida del robot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _encenderGuia() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return; // ✅ Evita iniciar o hablar antes de loguearse
    if (_rolVerificado && _esCapitanOAdmin) return; // ✅ Evita encender para capitán/admin

    BaqueanoIAService.inicializar();

    // ── Resetear posición: esquina inferior derecha pero con margen seguro
    // Se resetea a -1 para que el build() lo recalcule con el tamaño real
    _robotX = -1;
    _robotY = -1;

    setState(() {
      _mostrarGuia = true;
      _estadoGuia = CapitanState.aparece;
      _avatarScale = 1.0;
      _avatarOpacity = 1.0;
      _permiteInteractuar = false;
      _modoConversacionVoz = false;
    });

    // ── Iniciar animación flotante (bob cada 1.5s, ±6px)
    _bobTimer?.cancel();
    _bobTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || !_mostrarGuia) return;
      final t = DateTime.now().millisecondsSinceEpoch / 1000.0;
      setState(() => _bobOffset = math.sin(t * math.pi * 1.3) * 6.0);
    });

    // Aparece (1.5s) â†’ saluda (4s) â†’ pasa a dormir/reposo
    _avatarTimer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || !_mostrarGuia) return;
      setState(() => _estadoGuia = CapitanState.saludo);
      if (!_isMuted && _chatHistory.isNotEmpty) {
        VoiceService().speak(_chatHistory.first['text']!);
      }
      _avatarTimer = Timer(const Duration(seconds: 4), () {
        if (!mounted || !_mostrarGuia) return;
        setState(() {
          _permiteInteractuar = true;
          _estadoGuia = CapitanState.durmiendo;
        });
        _reiniciarTemporizadorInactividad();
        _verificarWakeWord(); // arranca el wake word listener al entrar en reposo
      });
    });
  }

  void _apagarGuia() {
    VoiceService().stop();
    VoiceService().stopVADListener();
    VoiceService().stopWakeWordListener();
    _avatarTimer?.cancel();
    _inactividadTimer?.cancel();
    _bobTimer?.cancel();
    setState(() {
      _estadoGuia = CapitanState.desaparece;
      _avatarScale = 0.0;
      _avatarOpacity = 0.0;
      _permiteInteractuar = false;
      _modoConversacionVoz = false;
    });
    _avatarTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _mostrarGuia = false);
    });
    if (GuiaOverlayController.activo.value) {
      GuiaOverlayController.setActivo(false);
    }
  }

  void _reiniciarTemporizadorInactividad() {
    _inactividadTimer?.cancel();
    if (!_mostrarGuia || !_permiteInteractuar) return;
    _inactividadTimer = Timer(const Duration(seconds: 60), () {
      if (mounted && _mostrarGuia) {
        setState(() => _estadoGuia = CapitanState.durmiendo);
        _verificarWakeWord(); // el GuIA duerme por inactividad → activa wake word
      }
    });
  }

  // ── Wake Word + Despertar ────────────────────────────────────────────────

  /// Verifica si el wake word listener debe estar activo y lo arranca o para.
  /// Debe llamarse cada vez que el estado del GuIA o el mic cambian.
  void _verificarWakeWord() {
    if (!mounted) return;
    final debeEscuchar = _mostrarGuia &&
        _permiteInteractuar &&
        _estadoGuia == CapitanState.durmiendo &&
        !_isListening &&
        !_isMuted &&
        GuiaOverlayController.micActivo.value;
    if (debeEscuchar) {
      VoiceService().startWakeWordListener(() {
        if (mounted && _mostrarGuia) _despertarGuia();
      });
    } else {
      VoiceService().stopWakeWordListener();
    }
  }

  /// Secuencia de activación: despierta el GuIA, dice la frase de confirmación
  /// y abre el mic. Se dispara tanto por wake word como por tap al GIF en reposo.
  void _despertarGuia() {
    if (!mounted || !_mostrarGuia || !_permiteInteractuar) return;
    VoiceService().stopWakeWordListener();
    _reiniciarTemporizadorInactividad();
    setState(() {
      _estadoGuia = CapitanState.despierta;  // animación de despertar (8.1s)
      _modoConversacionVoz = true;           // activa el loop: al terminar TTS → escucha
    });
    // La frase suena mientras el GuIA hace la animación de despertar.
    // Al terminar de hablar, el setCompletionHandler de initState() auto-arranca
    // _iniciarEscuchaAutomatica() porque _modoConversacionVoz == true.
    const fraseActivacion = 'Sí, dígame chamigo, ¿en qué lo puedo ayudar?';
    if (!_isMuted) VoiceService().speak(fraseActivacion);
  }

  // ── Interrupción ─────────────────────────────────────────────────────────
  void _interrumpir({String textoInicial = ''}) {
    if (!mounted || !_mostrarGuia || !_permiteInteractuar) return;
    VoiceService().stop();
    VoiceService().stopVADListener();
    VoiceService().stopWakeWordListener(); // nunca deben correr dos listeners a la vez
    _reiniciarTemporizadorInactividad();
    setState(() {
      _isListening = true;
      _estadoGuia = CapitanState.soloEscucha;
      _modoConversacionVoz = true;
      // Si el VAD ya capturó algo, lo mostramos en el campo de texto
      if (textoInicial.isNotEmpty) _chatController.text = textoInicial;
    });
    // Arranca el STT principal para capturar el resto de la pregunta.
    // Combina el texto inicial del VAD con lo que el STT capture a continuación.
    VoiceService().startListening((recognizedText, isFinal) {
      if (!mounted) return;
      // Combinar: si el STT ya incluye las palabras del VAD, usarlo solo;
      // si no, anteponemos el texto inicial para no perder las primeras palabras.
      final textoCompleto = (textoInicial.isNotEmpty &&
              !recognizedText.toLowerCase().contains(textoInicial.toLowerCase()))
          ? '$textoInicial $recognizedText'.trim()
          : recognizedText;
      setState(() => _chatController.text = textoCompleto);
      if (isFinal && textoCompleto.trim().isNotEmpty) {
        // Nuevo sentido de la conversación: se formula como un turno fresco
        _enviarMensaje(textoCompleto);
      }
    });
  }

  // â”€â”€ Voz â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  void _iniciarEscuchaAutomatica() async {
    if (!mounted || !_mostrarGuia || _isMuted || !_permiteInteractuar) return;
    _reiniciarTemporizadorInactividad();
    setState(() {
      _isListening = true;
      _estadoGuia = CapitanState.escuchando;
    });
    await VoiceService().startListening((recognizedText, isFinal) {
      if (!mounted) return;
      setState(() => _chatController.text = recognizedText);
      if (isFinal && recognizedText.trim().isNotEmpty) {
        _enviarMensaje(recognizedText);
      }
    });
  }

  void _enviarMensaje(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;
    _reiniciarTemporizadorInactividad();

    final tLower = cleanText.toLowerCase();

    // Verbal mute/unmute triggers
    final muteTriggers = ['silenciar', 'callate', 'cállate', 'no hables', 'mudo'];
    final unmuteTriggers = ['habla', 'hablá', 'desmutear', 'activar voz'];

    if (muteTriggers.any((trigger) => tLower.contains(trigger))) {
      const resp = 'Dale, me quedo mudo, chamigo';
      setState(() {
        _chatHistory.add({'text': cleanText, 'isUser': 'true'});
        _chatHistory.add({'text': resp, 'isUser': 'false'});
        _estadoGuia = CapitanState.triste;
      });
      await VoiceService().speak(resp);
      await GuiaOverlayController.setSilenciado(true);
      return;
    }

    if (unmuteTriggers.any((trigger) => tLower.contains(trigger))) {
      const resp = '¡Volví a hablar, chamigo!';
      await GuiaOverlayController.setSilenciado(false);
      setState(() {
        _chatHistory.add({'text': cleanText, 'isUser': 'true'});
        _chatHistory.add({'text': resp, 'isUser': 'false'});
        _estadoGuia = CapitanState.exito;
      });
      await VoiceService().speak(resp);
      return;
    }

    // Despedida verbal
    if (['chau', 'adios', 'adiós', 'apagar', 'apagate', 'apágate'].contains(tLower)) {
      setState(() => _chatHistory.add({'text': cleanText, 'isUser': 'true'}));
      const despedida = '¡Nos vemos, amigo! Buenas pescas...';
      setState(() => _chatHistory.add({'text': despedida, 'isUser': 'false'}));
      if (!_isMuted) VoiceService().speak(despedida);
      _avatarTimer = Timer(const Duration(milliseconds: 1500), _apagarGuia);
      return;
    }

    // ── Comandos de navegación instantánea ───────────────────────────────────
    // Se ejecutan ANTES del motor IA — sin esperar Gemini ni el engine local.
    final navIntent = IntentService.detectarNavegacion(cleanText);
    if (navIntent != null) {
      setState(() {
        _chatHistory.add({'text': cleanText, 'isUser': 'true'});
        _chatHistory.add({'text': navIntent.respuesta, 'isUser': 'false'});
        _estadoGuia = CapitanState.exito;
      });
      _chatController.clear();
      if (!_isMuted) {
        VoiceService().speak(navIntent.respuesta);
      }
      // Navega con una pequeña pausa para que el usuario escuche la confirmación
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) {
          Navigator.of(context, rootNavigator: true).pushNamed(navIntent.ruta);
        }
      });
      _reiniciarTemporizadorInactividad();
      return;
    }

    setState(() {
      _chatHistory.add({'text': cleanText, 'isUser': 'true'});
      _isTyping = true;
      _estadoGuia = CapitanState.piensaLeve;
    });
    _chatController.clear();

    if (_isListening) {
      await VoiceService().stopListening();
      setState(() => _isListening = false);
    }

    // Respuesta IA
    final String responseText;
    CapitanState nuevoEstado = CapitanState.explica;

    if (!_haySenal) {
      responseText = ConnectivityBridge.obtenerRespuestaTrinchera();
    } else {
      final ElGuiaRespuesta respuesta = await BaqueanoIAService.responder(cleanText);
      responseText = respuesta.texto;
      nuevoEstado = _gifToState(respuesta.gifSugerido);

      if (respuesta.rutaNavegacion != null && GuiaOverlayController.micActivo.value) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pushNamed(respuesta.rutaNavegacion!);
          }
        });
      }
    }

    if (mounted) {
      setState(() {
        _chatHistory.add({'text': responseText, 'isUser': 'false'});
        _isTyping = false;
        _estadoGuia = nuevoEstado;
      });
      if (!_isMuted) {
        VoiceService().speak(responseText);
        // Opción 1: VAD — escucha en paralelo mientras el GuIA habla.
        // El callback recibe las palabras ya capturadas para no perderlas.
        if (_modoConversacionVoz && GuiaOverlayController.micActivo.value) {
          VoiceService().startVADListener((textoDetectado) {
            if (mounted && _mostrarGuia && _permiteInteractuar) {
              _interrumpir(textoInicial: textoDetectado);
            }
          });
        }
      } else {
        _avatarTimer?.cancel();
        _avatarTimer = Timer(const Duration(seconds: 3), () {
          if (mounted && _mostrarGuia) {
            setState(() => _estadoGuia = CapitanState.durmiendo);
            _verificarWakeWord(); // vuelve al reposo → activa wake word
          }
        });
      }
      _reiniciarTemporizadorInactividad();
    }
  }

  CapitanState _gifToState(String gif) {
    switch (gif) {
      case 'saludo':         return CapitanState.saludo;
      case 'chiste':         return CapitanState.chiste;
      case 'rieGana':        return CapitanState.rieGana;
      case 'hablaConMate':   return CapitanState.hablaConMate;
      case 'tomaMate':       return CapitanState.tomaMate;
      case 'explica':        return CapitanState.explica;
      case 'exito':          return CapitanState.exito;
      case 'piensaLeve':     return CapitanState.piensaLeve;
      case 'piensaProfundo': return CapitanState.piensaProfundo;
      case 'escuchando':     return CapitanState.escuchando;
      case 'soloEscucha':    return CapitanState.soloEscucha;
      case 'duda':           return CapitanState.duda;
      case 'enojado':        return CapitanState.enojado;
      case 'triste':         return CapitanState.triste;
      default:               return CapitanState.hablaConMate;
    }
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Si no hay sesión activa en Supabase, no mostramos nada
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      if (_mostrarGuia) {
        // Apagamos silenciosamente si la sesión se cerró
        _mostrarGuia = false;
        _permiteInteractuar = false;
        _estadoGuia = CapitanState.desaparece;
        _avatarTimer?.cancel();
        _inactividadTimer?.cancel();
        _bobTimer?.cancel();
        VoiceService().stop();
      }
      return const SizedBox.shrink();
    }

    // Si ya verificamos y determinamos que es capitán o admin, no mostramos nada
    if (_rolVerificado && _esCapitanOAdmin) {
      return const SizedBox.shrink();
    }

    // Si hay sesión y el guía debe estar activo pero no se muestra, lo encendemos reactivamente
    if (GuiaOverlayController.activo.value && !_mostrarGuia && !(_rolVerificado && _esCapitanOAdmin)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && GuiaOverlayController.activo.value && !_mostrarGuia && !(_rolVerificado && _esCapitanOAdmin)) {
          _encenderGuia();
        }
      });
    }

    // Si el guía no está activo/visible, no renderizamos nada
    if (!_mostrarGuia) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;

    // ── Posición inicial: esquina inferior derecha con margen seguro
    // Ancho robot ~240 visible, alto ~300. Se ubica a 1/4 desde abajo.
    if (_robotX < 0) {
      _robotX = screenSize.width - 260; // Ajustado por tamaño x1.5 (240 + 20px de margen)
      // Quedamos a ~60% de la pantalla de alto para que no tape la barra inferior
      _robotY = screenSize.height * 0.55;
    }

    final double maxLeft = math.max(0.0, screenSize.width - 240.0);
    final double maxTop = math.max(0.0, screenSize.height - 350.0);

    return Positioned(
      left: _robotX.clamp(0.0, maxLeft),
      // El bob offset desplaza verticalmente para el efecto flotante
      top: (_robotY + _bobOffset).clamp(0.0, maxTop),
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _robotX = (_robotX + details.delta.dx).clamp(0.0, maxLeft);
            _robotY = (_robotY + details.delta.dy).clamp(0.0, maxTop);
          });
        },
        child: SizedBox(
          width: 240, // Ajustado a x1.5 (original 160)
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── GIF del robot con tap → El GuIA Pro ──────────────────
              AnimatedScale(
                scale: _avatarScale,
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeInBack,
                child: AnimatedOpacity(
                  opacity: _avatarOpacity,
                  duration: const Duration(milliseconds: 1000),
                  child: GestureDetector(
                    onTap: () {
                      // 1) Si el GuIA está hablando → interrumpir (ya implementado)
                      if (VoiceService().isSpeaking && _permiteInteractuar) {
                        _interrumpir();
                        return;
                      }
                      // 2) Si el GuIA está durmiendo/en reposo → despertar (NUEVO)
                      if (_estadoGuia == CapitanState.durmiendo && _permiteInteractuar) {
                        _despertarGuia();
                        return;
                      }
                      // 3) Si está activo/conversando → no hace nada (Ollama local removido)

                    },
                    child: CapitanAsistente(
                      estado: _estadoGuia,
                      width: 240, // Ajustado a x1.5 (original 160)
                      height: 240, // Ajustado a x1.5 (original 160)
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // ── Botones: mic + cerrar ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // El mic se muestra gris/deshabilitado mientras el GuIA presenta
                  // (primeros ~5.5s), verde cuando está libre y rojo cuando graba.
                  _buildBoton(
                    icono: !_permiteInteractuar
                        ? Icons.mic_rounded
                        : _isListening
                            ? Icons.mic_off_rounded
                            : Icons.mic_rounded,
                    color: !_permiteInteractuar
                        ? Colors.white24          // Gris: GuIA presentando, esperar
                        : _isListening
                            ? Colors.redAccent    // Rojo: grabando, toca para detener
                            : const Color(0xFF00E676), // Verde: libre, toca para hablar
                    pulsa: _isListening,
                    onTap: () async {
                      // Si el GuIA aún está presentando, no hacer nada
                      if (!_permiteInteractuar) return;
                      _reiniciarTemporizadorInactividad();

                      // Verificar si los comandos de voz están deshabilitados
                      final micActivo = GuiaOverlayController.micActivo.value;
                      if (!micActivo) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              '🤖 Chamigo, tenés que activar los Comandos por Voz en tus Ajustes de Perfil.',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            backgroundColor: const Color(0xFF001F3F),
                            behavior: SnackBarBehavior.floating,
                            action: SnackBarAction(
                              label: 'Ajustes',
                              textColor: const Color(0xFF00E676),
                              onPressed: () {
                                final screen = PescadorPerfilEditScreen();
                                Navigator.of(context, rootNavigator: true).push(
                                  MaterialPageRoute(
                                    builder: (context) => screen,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                        return;
                      }

                      if (_isListening) {
                        // Rojo → toca para DETENER la grabación
                        await VoiceService().stopListening();
                        setState(() {
                          _isListening = false;
                          _estadoGuia = CapitanState.durmiendo;
                          _modoConversacionVoz = false;
                        });
                      } else {
                        // ↓ Pide permiso de mic SOLO aquí, la primera vez
                        setState(() {
                          _isListening = true;
                          _estadoGuia = CapitanState.soloEscucha;
                          _modoConversacionVoz = true;
                        });
                        await VoiceService().startListening((recognizedText, isFinal) {
                          if (!mounted) return;
                          setState(() => _chatController.text = recognizedText);
                          if (isFinal && recognizedText.trim().isNotEmpty) {
                            _enviarMensaje(recognizedText);
                          }
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 12),
                  _buildBoton(
                    icono: Icons.close_rounded,
                    color: Colors.redAccent,
                    pulsa: false,
                    onTap: _apagarGuia,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoton({
    required IconData icono,
    required Color color,
    required bool pulsa,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: pulsa ? 46 : 40,
        height: pulsa ? 46 : 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(0.15),
          border: Border.all(color: color, width: 1.8),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: pulsa ? 16 : 8,
              spreadRadius: pulsa ? 2 : 0,
            ),
          ],
        ),
        child: Icon(icono, color: color, size: 20),
      ),
    );
  }
}

