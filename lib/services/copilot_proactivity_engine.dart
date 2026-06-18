import 'guia_copilot_brain.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CopilotProactivityEngine — El copiloto habla cuando tiene algo valioso
//
//  Un chatbot espera que el usuario pregunte.
//  Un copiloto sugiere en el momento correcto, sin que nadie lo pida.
//
//  Las pantallas emiten CopilotSignal → este motor evalúa si vale interrumpir.
//  Si no es el momento (cooldown, modo silencioso, conversación activa), retorna null.
// ─────────────────────────────────────────────────────────────────────────────

class CopilotProactivityEngine {
  CopilotProactivityEngine._();

  /// Tiempo mínimo entre sugerencias proactivas (evita saturar al usuario).
  static const Duration _cooldown = Duration(seconds: 90);

  static DateTime? _ultimaSugerencia;

  // ─────────────────────────────────────────────────────────────────────────
  //  API PÚBLICA
  // ─────────────────────────────────────────────────────────────────────────

  /// Evalúa una señal emitida por una pantalla y decide si el copiloto debe
  /// hablar proactivamente.
  ///
  /// Retorna el texto de la sugerencia, o null si no es el momento.
  static String? evaluar(
    CopilotSignal senal,
    ScreenContext pantalla,
    CopilotMode modo,
  ) {
    // No interrumpir si el copiloto está en medio de una conversación activa
    if (modo == CopilotMode.asistiendo) return null;

    // No interrumpir si el usuario silenció el copiloto
    if (modo == CopilotMode.silencioso) return null;

    // Cooldown: no saturar al usuario con sugerencias consecutivas
    if (_ultimaSugerencia != null) {
      final transcurrido = DateTime.now().difference(_ultimaSugerencia!);
      if (transcurrido < _cooldown) return null;
    }

    final sugerencia = _resolverSugerencia(senal, pantalla);

    if (sugerencia != null) {
      _ultimaSugerencia = DateTime.now();
    }

    return sugerencia;
  }

  /// Resetea el cooldown manualmente (ej: el usuario cerró sesión o reinició).
  static void resetearCooldown() => _ultimaSugerencia = null;

  // ─────────────────────────────────────────────────────────────────────────
  //  LÓGICA DE RESOLUCIÓN
  // ─────────────────────────────────────────────────────────────────────────

  static String? _resolverSugerencia(
      CopilotSignal senal, ScreenContext pantalla) {
    switch (senal.tipo) {

      case 'viaje_listo':
        return '¡Chamigo! El capitán aceptó tu viaje. ¿Lo confirmamos ahora?';

      case 'cotizacion_recibida':
        return '¡Te llegó una cotización! ¿La revisamos?';

      case 'pago_completado':
        return 'El pago quedó registrado, chamigo. ¡Todo listo para el viaje!';

      case 'error_campo':
        if (senal.mensaje.isNotEmpty) {
          return 'Falta completar "${senal.mensaje}", chamigo. ¿Te ayudo?';
        }
        return 'Parece que hay un campo sin completar. ¿Te ayudo?';

      case 'proactiva':
        // La pantalla ya redactó el mensaje — solo validamos el timing
        return senal.mensaje.isNotEmpty ? senal.mensaje : null;

      case 'inactividad_en_formulario':
        return _sugerenciaPorInactividad(pantalla);

      default:
        return null;
    }
  }

  static String? _sugerenciaPorInactividad(ScreenContext pantalla) {
    switch (pantalla) {
      case ScreenContext.cotizacion:
        return 'Si tenés dudas sobre el precio del viaje, preguntame. Estoy acá.';
      case ScreenContext.pago:
        return 'Si necesitás ayuda con el pago, decime chamigo.';
      case ScreenContext.mapa:
        return '¿Estás buscando un lugar para pescar? Te puedo orientar.';
      case ScreenContext.tienda:
        return '¿Necesitás que te recomiende algún producto, chamigo?';
      default:
        return null; // No sugerir en pantallas sin contexto relevante
    }
  }
}
