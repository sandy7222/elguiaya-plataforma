import 'dart:async';

/// Memoria conversacional temporal de El Guía.
/// Registra el contexto de la conversación actual y se resetea por inactividad.
class ElGuiaContext {
  /// Modo operativo actual del asistente.
  /// Valores: 'normal', 'supervivencia', 'emergencia'
  String modoActual = 'normal';

  /// Última intención detectada en la conversación.
  String ultimaIntencion = '';

  /// Nivel de frustración del usuario (de 0 a 5).
  int nivelFrustracion = 0;

  /// Especie de pez mencionada en contexto (para consultas combinadas).
  String especieActual = '';

  /// Estado del río mencionado en contexto (crecido, bajo, turbio, claro).
  String estadoRioActual = '';

  /// Lista de los últimos objetivos detectados o temas de conversación.
  List<String> objetivosRecientes = [];

  /// Pantalla de la app activa en el contexto de ayuda de navegación.
  /// Permite responder preguntas de seguimiento como "no lo encuentro"
  /// sin que el usuario repita en qué pantalla está.
  String pantallaActual = '';

  /// Índice del paso actual en la guía de uso (0-based).
  /// Se incrementa con cada "y después?" para avanzar secuencialmente.
  int pasoActualEnGuia = 0;

  /// Indica que el bot hizo una pregunta guiada y espera respuesta.
  /// Ejemplo: "¿Qué buscás: el mapa, reservas, la tienda o tu perfil?"
  bool esperandoRespuestaGuiada = false;

  /// Texto de la pregunta guiada pendiente (para contexto de seguimiento).
  String preguntaGuiadaPendiente = '';

  /// Indica que el bot terminó su última respuesta con una pregunta de seguimiento
  /// y ahora espera cualquier respuesta del usuario para cerrar la conversación
  /// de forma ordenada (con una frase de cierre variada en español ribereño).
  bool esperandoCierre = false;

  /// Guarda el texto de la última pregunta que hizo el bot (para contextualizar
  /// la frase de cierre si fuera necesario).
  String ultimaPreguntaHecha = '';

  /// Última respuesta entregada (para evitar repetición exacta).
  String ultimaRespuesta = '';

  /// Estado actual del viaje del pescador (para respuestas contextuales).
  /// Valores: '', 'pendiente', 'aceptado', 'pagado', 'en_curso', 'listo_para_confirmar', 'cerrado'
  String estadoViajeActual = '';

  /// Contexto de acción de viaje en curso.
  /// Valores: '', 'creando', 'cotizando', 'pagando', 'confirmando', 'calificando'
  String viajeContexto = '';

  /// Última consulta textual enviada por el usuario (para análisis de rol/zona).
  String ultimaConsulta = '';

  /// Indica si la consulta proviene del módulo de blog (para forzar rol redactor).
  bool esBlog = false;

  /// Timestamp del último mensaje recibido (para auto-reset).
  DateTime? _ultimaActividad;

  /// Timer de reset automático por inactividad.
  Timer? _resetTimer;

  /// Tiempo de inactividad antes de resetear el contexto (2 minutos).
  static const Duration _tiempoReset = Duration(minutes: 2);

  /// Registra actividad y reinicia el timer de reset.
  void registrarActividad() {
    _ultimaActividad = DateTime.now();
    _resetTimer?.cancel();
    _resetTimer = Timer(_tiempoReset, resetearContexto);
  }

  /// Resetea el contexto conversacional (modo normal, sin especie ni estado).
  void resetearContexto() {
    modoActual = 'normal';
    ultimaIntencion = '';
    nivelFrustracion = 0;
    especieActual = '';
    estadoRioActual = '';
    pantallaActual = '';
    pasoActualEnGuia = 0;
    esperandoRespuestaGuiada = false;
    preguntaGuiadaPendiente = '';
    ultimaRespuesta = '';
    estadoViajeActual = '';
    viajeContexto = '';
    ultimaConsulta = '';
    esBlog = false;
    objetivosRecientes = [];
    esperandoCierre = false;
    ultimaPreguntaHecha = '';
    _ultimaActividad = null;
  }

  /// Devuelve true si el contexto tiene datos útiles de la sesión anterior.
  bool get tieneContexto =>
      ultimaIntencion.isNotEmpty ||
      especieActual.isNotEmpty ||
      estadoRioActual.isNotEmpty ||
      pantallaActual.isNotEmpty ||
      estadoViajeActual.isNotEmpty ||
      viajeContexto.isNotEmpty ||
      modoActual != 'normal';

  /// Devuelve cuántos segundos lleva inactivo el contexto.
  int get segundosInactivo {
    if (_ultimaActividad == null) return 0;
    return DateTime.now().difference(_ultimaActividad!).inSeconds;
  }

  void dispose() {
    _resetTimer?.cancel();
  }
}
