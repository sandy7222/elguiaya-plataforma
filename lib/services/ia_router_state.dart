import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/groq_config.dart';
import 'connectivity_bridge.dart';
import 'audio_service.dart';

/// Estado visible del motor de IA activo.
enum IAEstado {
  /// Tier 0 — Acción directa en pantalla (< 5ms, sin IA).
  /// El copiloto ejecuta una acción en la pantalla activa sin consultar nada.
  accionDirecta,

  /// Tier 1 — Navegación instantánea (< 5ms, sin IA).
  /// El copiloto navega a una ruta sin consultar nada.
  navegacion,

  /// Tier 2 — Groq Cloud con contexto enriquecido de pantalla.
  cloud,

  /// Tier 3 — ElGuiaEngine offline con contexto de pantalla.
  offline,

  /// Tier 4 — Frase de contingencia (sin red, sin JSON match).
  contingencia,
}

/// Notifier global del estado del router IA.
///
/// El [IAStatusBadge] y cualquier otro widget de la UI escuchan
/// [IARouterState.estado] para reflejar visualmente qué motor está activo.
///
/// El [BaqueanoIAService] actualiza este estado antes de cada llamada.
class IARouterState {
  static final ValueNotifier<IAEstado> estado = ValueNotifier(IAEstado.offline);
  static final ValueNotifier<bool> modoOnline = ValueNotifier(true);
  static StreamSubscription<bool>? _sub;

  /// Indicadores globales de salud de los servicios de soporte
  static final ValueNotifier<bool> routerSano = ValueNotifier(true);
  static final ValueNotifier<bool> cacheSano = ValueNotifier(true);
  static final ValueNotifier<bool> supabaseSano = ValueNotifier(true);

  // Evita alertas redundantes en oscilaciones (flag _notificado)
  static bool _anuncioPerdidaSenal = false;
  static Timer? _timerPerdidaSenal;

  /// Actualiza los estados de salud de forma segura, solo disparando notificaciones si el valor cambia.
  static void actualizarSalud({bool? router, bool? cache, bool? supabase}) {
    if (router != null && routerSano.value != router) {
      routerSano.value = router;
    }
    if (cache != null && cacheSano.value != cache) {
      cacheSano.value = cache;
    }
    if (supabase != null && supabaseSano.value != supabase) {
      supabaseSano.value = supabase;
    }
  }

  /// Inicializa el listener de conectividad para actualizar el estado
  /// automáticamente cuando cambia la red.
  static void inicializar() {
    // Inicializar AudioService TTS al arrancar
    AudioService().inicializar();

    // Cargar preferencia persistente de modo online
    SharedPreferences.getInstance().then((prefs) {
      modoOnline.value = prefs.getBool('guia_modo_online') ?? true;
      _recalcular();
    });

    // Estado inicial basado en la conectividad actual
    _recalcular();

    // Escuchar cambios de red
    _sub?.cancel();
    _sub = ConnectivityBridge.conexionStream.listen((_) => _recalcular());

    // Escuchar cambios en la salud de Supabase para activar el Failsafe
    supabaseSano.removeListener(_onSupabaseHealthChanged);
    supabaseSano.addListener(_onSupabaseHealthChanged);

    // Guardar preferencia persistente al cambiar modoOnline
    modoOnline.removeListener(_onModoOnlineChanged);
    modoOnline.addListener(_onModoOnlineChanged);
  }

  static void _onModoOnlineChanged() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('guia_modo_online', modoOnline.value);
    _recalcular();
  }

  static void _onSupabaseHealthChanged() {
    if (supabaseSano.value == false) {
      debugPrint("⚠️ Supabase fuera de línea. Estado de datos offline.");
      _recalcular();

      _timerPerdidaSenal?.cancel();
      _timerPerdidaSenal = Timer(const Duration(seconds: 3), () {
        if (supabaseSano.value == false && !_anuncioPerdidaSenal) {
          _anuncioPerdidaSenal = true;
          // Notificación por AudioService TTS (es-ES, rate 0.9)
          AudioService().speak('Capitán, perdimos la señal. Trabajando en modo local.');
        }
      });
    } else {
      debugPrint("✅ Conexión restaurada con Supabase. Regresando a normalidad...");
      _timerPerdidaSenal?.cancel(); // Cancelar el timer si se recupera antes de los 3s
      _recalcular();
      // Restaurar el flag para permitir futuras alertas si se vuelve a desconectar
      _anuncioPerdidaSenal = false;
    }
  }

  /// Recalcula el estado según conectividad + disponibilidad de API key.
  static void _recalcular() {
    if (modoOnline.value && ConnectivityBridge.estaConectado && GroqConfig.tieneApiKey) {
      estado.value = IAEstado.cloud;
    } else {
      // Sin API key de Groq, o modo local forzado, caemos directamente a la base de reglas offline
      estado.value = IAEstado.offline;
    }
  }

  /// Fuerza un estado específico (llamado por BaqueanoIAService al
  /// determinar qué tier realmente respondió).
  static void reportarEstado(IAEstado nuevoEstado) {
    estado.value = nuevoEstado;
  }

  static void dispose() {
    _sub?.cancel();
    supabaseSano.removeListener(_onSupabaseHealthChanged);
    modoOnline.removeListener(_onModoOnlineChanged);
  }
}
