import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  GuiaCopilotBrain — Cerebro global del copiloto contextual
//
//  El estado del Guía YA deja de vivir dentro del widget flotante y pasa a
//  ser un singleton accesible desde cualquier pantalla.
//
//  Las pantallas EMITEN contexto → el copiloto REACCIONA.
//  El copiloto EMITE acciones → las pantallas EJECUTAN.
// ─────────────────────────────────────────────────────────────────────────────
class GuiaCopilotBrain {
  GuiaCopilotBrain._();
  static final GuiaCopilotBrain instance = GuiaCopilotBrain._();

  // ── CONTEXTO DE PANTALLA ────────────────────────────────────────────────────
  // Quién actualiza: cada pantalla en su initState() → pantallaCargada()
  // Quién lee: BaqueanoIAService, CapacitacionService, CopilotActionService
  final ValueNotifier<ScreenContext> pantallaActiva =
      ValueNotifier(ScreenContext.ninguna);

  // ── CONTEXTO DE ACCIÓN ──────────────────────────────────────────────────────
  // Qué flujo está ejecutando el usuario en este momento
  final ValueNotifier<AppAction?> accionActiva = ValueNotifier(null);

  // ── SEÑALES DE PROACTIVIDAD ─────────────────────────────────────────────────
  // Las pantallas emiten señales para que el copiloto sugiera en el momento
  // correcto sin que el usuario lo pida.
  final ValueNotifier<CopilotSignal?> senal = ValueNotifier(null);

  // ── MODO DEL COPILOTO ───────────────────────────────────────────────────────
  final ValueNotifier<CopilotMode> modo =
      ValueNotifier(CopilotMode.escuchando);

  // ── HISTORIAL DE ACCIONES (últimas N — para contexto de flujo) ─────────────
  final List<AppActionRecord> historialAcciones = [];
  static const int _maxHistorial = 10;

  // ─────────────────────────────────────────────────────────────────────────────
  //  API PÚBLICA — llamada desde las pantallas
  // ─────────────────────────────────────────────────────────────────────────────

  /// Llamar en initState() de cada pantalla importante.
  /// Actualiza el contexto de pantalla activa para que el copiloto sepa
  /// dónde está el usuario sin que este tenga que explicarlo.
  ///
  /// [datosLocales] es opcional: permite pasar datos relevantes de la pantalla
  /// (ej: monto de la cotización, ID del viaje) para contexto enriquecido.
  void pantallaCargada(
    ScreenContext pantalla, {
    Map<String, dynamic>? datosLocales,
  }) {
    pantallaActiva.value = pantalla;
    // Limpiar acción activa al cambiar de pantalla
    accionActiva.value = null;
    debugPrint('[CopilotBrain] 📍 Pantalla activa: ${pantalla.name}');
  }

  /// Llamar cuando el usuario inicia una acción que el copiloto puede asistir.
  /// Registra la acción en el historial para contexto de flujo.
  void iniciarAccion(AppAction accion) {
    accionActiva.value = accion;
    historialAcciones.add(AppActionRecord(accion, DateTime.now()));
    if (historialAcciones.length > _maxHistorial) {
      historialAcciones.removeAt(0);
    }
    debugPrint('[CopilotBrain] ⚡ Acción iniciada: ${accion.name}');
  }

  /// Llamar cuando una acción se completa (para memoria de comportamiento).
  void completarAccion(AppAction accion) {
    if (accionActiva.value == accion) {
      accionActiva.value = null;
    }
    debugPrint('[CopilotBrain] ✅ Acción completada: ${accion.name}');
  }

  /// Emite una señal para que el motor de proactividad evalúe si el copiloto
  /// debe sugerir algo sin que el usuario lo haya pedido.
  void emitirSenal(CopilotSignal s) {
    senal.value = s;
    debugPrint('[CopilotBrain] 📡 Señal emitida: ${s.tipo}');
  }

  /// Shortcut para solicitar ayuda proactiva con un mensaje específico.
  void solicitarAyudaProactiva(String motivo) =>
      emitirSenal(CopilotSignal.ayudaProactiva(motivo));

  /// Actualiza el modo operativo del copiloto.
  void setModo(CopilotMode m) => modo.value = m;

  /// Devuelve el resumen del flujo reciente (últimas N acciones) como string.
  /// Se usa para inyectar en el prompt de Groq como contexto de flujo.
  String get resumenFlujReciente {
    if (historialAcciones.isEmpty) return '';
    final ultimas = historialAcciones.reversed.take(3);
    return ultimas.map((r) => r.accion.name).join(' → ');
  }

  /// Limpia el estado al cerrar sesión o desmontar el copiloto.
  void reset() {
    pantallaActiva.value = ScreenContext.ninguna;
    accionActiva.value = null;
    senal.value = null;
    modo.value = CopilotMode.escuchando;
    historialAcciones.clear();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ENUMS DE DOMINIO
// ─────────────────────────────────────────────────────────────────────────────

/// Pantallas conocidas de la app. Agregar nuevas pantallas aquí al integrarlas.
enum ScreenContext {
  ninguna,
  inicio,
  mapa,
  cotizacion,
  pago,
  reservas,
  tienda,
  carrito,
  perfil,
  blog,
  historial,
  emergencia,
  solunar,
  chat,
  calificacion,
  configuracion,
}

/// Modo operativo actual del copiloto.
enum CopilotMode {
  /// Modo normal — escucha pero no interrumpe.
  escuchando,

  /// En medio de una conversación activa.
  asistiendo,

  /// Emitió una sugerencia sin que el usuario la pidiera.
  proactivo,

  /// El usuario lo silenció — no interrumpir.
  silencioso,

  /// Modo prioritario — emergencia detectada.
  emergencia,
}

/// Acciones de app que el copiloto puede reconocer y asistir.
enum AppAction {
  creandoViaje,
  cotizando,
  pagando,
  confirmandoArribo,
  calificando,
  buscandoCarnada,
  leyendoBlog,
  configurando,
  navegandoMapa,
  agregandoAlCarrito,
}

/// Registro inmutable de una acción con su timestamp.
class AppActionRecord {
  final AppAction accion;
  final DateTime momento;
  const AppActionRecord(this.accion, this.momento);
}

/// Señal que una pantalla emite para que el copiloto evalúe proactividad.
class CopilotSignal {
  final String tipo;
  final String mensaje;

  const CopilotSignal._(this.tipo, this.mensaje);

  factory CopilotSignal.ayudaProactiva(String m) =>
      CopilotSignal._('proactiva', m);

  factory CopilotSignal.errorEnFormulario(String campo) =>
      CopilotSignal._('error_campo', campo);

  factory CopilotSignal.viajeListo() =>
      const CopilotSignal._('viaje_listo', '');

  factory CopilotSignal.cotizacionRecibida() =>
      const CopilotSignal._('cotizacion_recibida', '');

  factory CopilotSignal.inactividadEnFormulario() =>
      const CopilotSignal._('inactividad_en_formulario', '');

  factory CopilotSignal.pagoCompletado() =>
      const CopilotSignal._('pago_completado', '');
}
