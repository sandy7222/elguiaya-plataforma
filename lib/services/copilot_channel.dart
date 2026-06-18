import 'guia_copilot_brain.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CopilotChannel — Canal de comunicación bidireccional Pantalla ↔ Copiloto
//
//  Patrón: EventBus ligero, sin dependencias externas.
//
//  Flujo:
//    1. Pantalla se registra en initState()  → registrar(pantallaId, handler)
//    2. Copiloto delega una acción           → delegar(payload)
//    3. CopilotChannel rutea al handler      → _handlers[pantalla]?.call(payload)
//    4. Pantalla la ejecuta                  → _confirmarCotizacion(), etc.
//    5. Pantalla se desregistra en dispose() → desregistrar(pantallaId)
// ─────────────────────────────────────────────────────────────────────────────

typedef CopilotActionHandler = void Function(Map<String, dynamic> payload);

class CopilotChannel {
  CopilotChannel._();

  static final Map<String, CopilotActionHandler> _handlers = {};

  // ─────────────────────────────────────────────────────────────────────────
  //  API PÚBLICA — llamada desde las PANTALLAS
  // ─────────────────────────────────────────────────────────────────────────

  /// Registrar un handler para recibir acciones del copiloto.
  /// Llamar en initState() de la pantalla.
  ///
  /// [pantallaId] debe coincidir con el nombre del enum ScreenContext.
  /// Ejemplo: 'cotizacion', 'mapa', 'pago'.
  static void registrar(String pantallaId, CopilotActionHandler handler) {
    _handlers[pantallaId] = handler;
  }

  /// Desregistrar el handler al salir de la pantalla.
  /// Llamar en dispose() de la pantalla.
  static void desregistrar(String pantallaId) {
    _handlers.remove(pantallaId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  API PÚBLICA — llamada desde el COPILOTO (GuiaOverlay / BaqueanoIAService)
  // ─────────────────────────────────────────────────────────────────────────

  /// Delega un payload de acción a la pantalla actualmente registrada.
  /// El copiloto no necesita saber qué pantalla es — el canal lo resuelve.
  static void delegar(Map<String, dynamic> payload) {
    final pantallaActiva =
        GuiaCopilotBrain.instance.pantallaActiva.value.name;
    final handler = _handlers[pantallaActiva];
    if (handler != null) {
      handler(payload);
    } else {
      // Sin handler registrado — acción ignorada silenciosamente
      // Esto ocurre si la pantalla no se integró aún (normal durante la migración)
    }
  }

  /// Delega a una pantalla específica por ID (override del contexto activo).
  /// Usar solo cuando se necesita enviar a una pantalla no activa.
  static void delegarA(String pantallaId, Map<String, dynamic> payload) {
    _handlers[pantallaId]?.call(payload);
  }

  /// Indica si la pantalla activa tiene un handler registrado.
  static bool get pantallaActivaRegistrada {
    final pantallaActiva =
        GuiaCopilotBrain.instance.pantallaActiva.value.name;
    return _handlers.containsKey(pantallaActiva);
  }

  /// Lista de pantallas actualmente registradas (para debugging).
  static List<String> get pantallasRegistradas => _handlers.keys.toList();
}
