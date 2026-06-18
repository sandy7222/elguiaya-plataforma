import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/models/producto.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'connectivity_bridge.dart';
import 'el_guia_engine.dart';
import 'el_guia_context.dart';
import 'groq_service.dart';
import 'capacitacion_service.dart';
import 'ia_router_state.dart';
import 'gemini_learner.dart';
import '../config/groq_config.dart';
import 'guia_memoria_service.dart';
import 'guia_copilot_brain.dart';
import 'copilot_action_service.dart';
import 'copilot_channel.dart';


/// BaqueanoIAService — Router hibrido online/offline.
///
/// Decide en cada consulta si usar el motor local Ollama como cerebro principal
/// o el motor local offline (cualquier otra condicion o en caso de fallo).
/// El widget guia_overlay.dart no cambia.
class BaqueanoIAService {
  static const String nombre    = 'El Guia';
  static const String identidad = 'Experto pescador argentino, servicial y conocedor de rios y mares';

  static final ElGuiaEngine   _motorLocal    = ElGuiaEngine();

  static List<Producto> _catalogo    = [];
  static DateTime?      _ultimaCarga;

  // Lógica del modo cómico: El Guía Recalentado / Furioso
  static int _nivelFrustracion = 0;
  static String? _ultimaPregunta;
  static int _coincidenciasPregunta = 0;

  // ── Caché de respuestas offline ─────────────────────────────────────
  // Última respuesta exitosa online por intención → se reutiliza offline
  static final Map<String, ElGuiaRespuesta> _cacheRespuestas = {};
  // Contador de consultas offline en la sesión actual
  static int _consultasOffline = 0;

  // Historial de la sesión actual (últimos 5 mensajes, role: user/assistant)
  static final List<Map<String, String>> _historialSesion = [];

  static void _actualizarHistorial(String userMsg, String assistantMsg) {
    _historialSesion.add({'role': 'user', 'content': userMsg});
    _historialSesion.add({'role': 'assistant', 'content': assistantMsg});
    // 8 entradas = 4 turnos completos de conversación.
    // Reduce drásticamente el consumo de tokens por mensaje y evita errores 429 de Rate Limit.
    if (_historialSesion.length > 8) {
      _historialSesion.removeRange(0, _historialSesion.length - 8);
    }
  }

  static final List<String> _respuestasImpaciencia = [
    "¡Eeeh chamigo! No soy lancha con nitro 😤 Dame un segundo.",
    "Pará un cachito que estoy acomodando las boyas mentales 💢",
    "¡Ya va! Más rápido que tararira nerviosa tampoco 😤"
  ];

  static final List<String> _respuestasBugs = [
    "¡La señal anda peor que motor sin nafta! 😤 Vamos con modo río nomás.",
    "Mmm… hoy los satélites vinieron a pescar también 💢",
    "Se me cruzaron los cables del Paraná, pero seguimos chamigo."
  ];

  static final List<String> _respuestasAbsurdas = [
    "😤 Pará chamigo… ¿un tiburón en Chascomús? ¡Ni el pejerrey te cree esa!",
    "Mmm… me parece que me estás cargando más que boga mañera 💢",
    "¡Esa pregunta me dejó recalculando el GPS del río! 😤"
  ];

  static final List<String> _respuestasProtector = [
    "¡Eeeh no seas animal, chamigo! 😤 El río no perdona.",
    "No me hagás renegar 😠 Si hay tormenta fuerte, se espera.",
    "Una pesca se reprograma. Un susto grande no se arregla tan fácil."
  ];

  static final List<String> _respuestasCancelacion = [
    "😤 Uff… eso suele complicar al capitán, chamigo.",
    "Pará que revisamos la política, porque al baqueano ya lo dejaste cebando mate solo 💢",
    "Veamos si todavía entra cancelación, no me hagás renegaaaaar 😤"
  ];

  static final List<String> _respuestasMalaSuerte = [
    "😤 ¡Y bueno! Hay días que los peces hacen paro.",
    "Mirá… hoy hasta yo le gritaría al río 💢",
    "No siempre se gana, chamigo. Hoy los peces estaban idos a estudiar psicología."
  ];

  static final List<String> _respuestasCancelado = [
    "Uff… qué macana, chamigo 😞 Ya me había hecho ilusión de salir al río.",
    "Bueno… no pasa nada. El Paraná sigue ahí esperando.",
    "Mmm… día triste pa’ pescar 😔 Pero ya vamos a rearmar otra salida."
  ];

  static final List<String> _respuestasMalaPescaTriste = [
    "😔 Hay días así, chamigo… el río también tiene sus silencios.",
    "No siempre se vuelve con pescado… a veces uno vuelve con la historia.",
    "Hoy los peces ganaron 😞 Pero no te bajonees, la revancha siempre aparece."
  ];

  static final List<String> _respuestasUsuarioTriste = [
    "Eh chamigo… vení, no aflojemos 😔",
    "A veces el río se pone oscuro, pero después baja manso otra vez.",
    "No sé bien qué pasó… pero te acompaño un rato si querés."
  ];

  static final List<String> _respuestasNoPescoMas = [
    "😔 Uff… esa me pegó medio fuerte.",
    "Aunque sea volvé a mirar el río cada tanto, chamigo."
  ];

  static final List<String> _respuestasQueTePasa = [
    "Nada grave, chamigo… ando medio bajón nomás 😔",
    "Hay días que hasta los tornillos hacen ruido distinto…",
    "Capaz necesitaba un rato de río 😞",
    "Se me enredó el anzuelo emocional 💔🎣"
  ];

  static const List<String> _temasProhibidos = [
    'reintegro', 'reembolso', 'devolucion', 'dinero', 'factura',
    'cbu', 'transferencia', 'cuenta', 'banco',
  ];

  static Future<void> inicializar() async {
    await _motorLocal.inicializar();
    await GroqConfig.cargar();
    IARouterState.inicializar();

    if (_ultimaCarga != null &&
        DateTime.now().difference(_ultimaCarga!) < const Duration(minutes: 5)) {
      return;
    }
    // Timeout de 5s: Supabase lento no bloquea el arranque
    try {
      _catalogo = await SupabaseService.getProductos()
          .timeout(const Duration(seconds: 5));
      _ultimaCarga = DateTime.now();
    } catch (_) {}
  }

  static double _obtenerUmbralCategoria(String intencion) {
    switch (intencion) {
      case 'saludo':
      case 'despedida':
      case 'agradecimiento':
      case 'hora':
      case 'charla_cotidiana':
      case 'preguntas_humanas':
      case 'mate':
      case 'chiste':
      case 'que_puede_hacer_bot':
        return 0.50;

      case 'ayuda_app':
      case 'crear_viaje':
      case 'ver_cotizaciones':
      case 'estado_viaje':
      case 'pagar_viaje':
      case 'confirmar_viaje':
      case 'calificar':
      case 'notificaciones':
      case 'perfil_pescador':
      case 'activar_guia':
      case 'reserva':
      case 'elegir_capitan':
      case 'carrito':
      case 'historial_viajes':
      case 'ayuda_general':
      case 'tienda':
        return 0.75;

      case 'peces':
      case 'carnadas':
      case 'nudos':
      case 'boyas':
      case 'plomadas':
      case 'canas_y_reeles':
      case 'rio':
        return 0.85;

      case 'emergencia':
      case 'perdido':
      case 'supervivencia':
      case 'agua':
      case 'refugio':
      case 'fuego':
      case 'alimento':
      case 'clima':
      case 'primeros_auxilios':
      case 'gps':
        return 0.90;

      default:
        return 0.75;
    }
  }

  static Future<ElGuiaRespuesta> responder(String pregunta) async {
    final pq = pregunta.toLowerCase().trim();

    // (La rehidratación del contexto del usuario ahora se maneja directamente dentro de GroqService de forma unificada)

    // Actualizar la memoria del pescador en segundo plano (asíncrono)
    GuiaMemoriaService.actualizarMemoria(pregunta);

    // Diagnóstico verbal: el robot reporta su estado de conexión
    if (_esConsultaEstado(pq)) return await _respuestaEstado();

    // Interceptar triggers de enojo cómico (El Guía Recalentado)
    final enojoRespuesta = _detectarTriggersEnojo(pq);
    if (enojoRespuesta != null) return enojoRespuesta;

    // Interceptar triggers de tristeza/empatía (El Guía Triste)
    final tristezaRespuesta = _detectarTriggersTristeza(pq);
    if (tristezaRespuesta != null) return tristezaRespuesta;

    // Filtro de temas prohibidos (siempre, independiente del motor)
    if (esTemaProhibido(pq)) {
      return ElGuiaRespuesta.simple(
        'Ese tema esta fuera de mi zona. Para consultas sobre pagos o reembolsos, contacta al equipo de EL GUIA YA.',
      );
    }

    // ── TIER 0: Acción contextual directa (< 5ms, sin IA) ─────────────────────
    // Si el copiloto sabe en qué pantalla está el usuario, puede ejecutar
    // acciones sin consultar ningún motor de IA.
    final brain = GuiaCopilotBrain.instance;
    final copilotAction = CopilotActionService.detectarAccion(
      pregunta,
      brain.pantallaActiva.value,
      brain.accionActiva.value,
    );
    if (copilotAction != null) {
      IARouterState.reportarEstado(IAEstado.accionDirecta);
      debugPrint('[BaqueanoRouter] → TIER 0 ACCIÓN DIRECTA: ${copilotAction.tipo} en ${brain.pantallaActiva.value.name}');
      // Delegar la acción a la pantalla activa vía CopilotChannel
      if (copilotAction.payload != null) {
        CopilotChannel.delegar(copilotAction.payload!);
      }
      return ElGuiaRespuesta(
        texto: copilotAction.respuesta,
        gifSugerido: copilotAction.gifSugerido,
        rutaNavegacion: copilotAction.ruta,
        accionPayload: copilotAction.payload,
        exito: true,
      );
    }

    // Tienda: siempre local (datos del catálogo de Supabase)
    if (_catalogo.isNotEmpty) {
      final intenciones = _motorLocal.detectarIntenciones(pq);
      if (intenciones.contains('tienda')) {
        final producto = _buscarProductoEnConsulta(pq);
        if (producto != null) {
          return ElGuiaRespuesta(
            texto: _respuestaProducto(producto, pq),
            gifSugerido: 'exito',
          );
        }
      }
    }

    // ── Confidence Router ───────────────────────────────────────────────────
    // LÓGICA: Groq (en la nube) es el cerebro principal en línea.
    // Si no hay conexión, falla o está offline total, cae al motor offline de manera sutil.
    final intencionPrincipal = _motorLocal.obtenerIntencionPrincipal(pq);
    debugPrint('[BaqueanoRouter] intent=$intencionPrincipal | offline_count=$_consultasOffline');

    // ── TIER 2: Groq Cloud ───────────────────────────────────
    if (ConnectivityBridge.estaConectado && GroqConfig.tieneApiKey) {
      try {
        debugPrint('[BaqueanoRouter] → GROQ ONLINE');
        final contextoExtra = await CapacitacionService.getContextoContextual(pregunta);
        final copiaHistorial = List<Map<String, String>>.from(_historialSesion);
        final resp = await GroqService().responder(
          pregunta,
          contextoExtra: contextoExtra,
          historial: copiaHistorial,
        );
        IARouterState.reportarEstado(IAEstado.cloud);
        final finalResp = _agregarRuta(resp, _obtenerRutaParaIntencion(intencionPrincipal));
        GeminiLearner.evaluarYGuardar(pregunta, finalResp.texto, exito: finalResp.exito);
        _actualizarHistorial(pregunta, finalResp.texto);
        return finalResp;
      } catch (e) {
        debugPrint('[BaqueanoRouter] → GROQ ONLINE falló: $e. Cayendo al motor offline...');
      }
    }

    // ── TIER 3: ElGuiaEngine (offline failsafe) ──────────────
    _consultasOffline++;
    IARouterState.reportarEstado(IAEstado.offline);
    debugPrint('[BaqueanoRouter] → MOTOR LOCAL (offline #$_consultasOffline)');

    try {
      final ms = 400 + Random().nextInt(800);
      await Future.delayed(Duration(milliseconds: ms));

      final respuestaLocal = await _motorLocal.responder(pregunta);

      if (respuestaLocal.gifSugerido == 'duda' &&
          _cacheRespuestas.containsKey(intencionPrincipal)) {
        debugPrint('[BaqueanoRouter] → Usando caché de respuesta online para $intencionPrincipal');
        final cachedResp = _cacheRespuestas[intencionPrincipal]!;
        final finalResp = _agregarRuta(cachedResp, _obtenerRutaParaIntencion(intencionPrincipal));
        GeminiLearner.evaluarYGuardar(pregunta, finalResp.texto, exito: finalResp.exito);
        _actualizarHistorial(pregunta, finalResp.texto);
        return finalResp;
      }

      final finalResp = _agregarRuta(respuestaLocal, _obtenerRutaParaIntencion(intencionPrincipal));
      GeminiLearner.evaluarYGuardar(pregunta, finalResp.texto, exito: finalResp.exito);
      _actualizarHistorial(pregunta, finalResp.texto);
      return finalResp;
    } catch (e) {
      debugPrint('[BaqueanoRouter] → Motor local offline falló: $e');
      final errorResp = const ElGuiaRespuesta(
        texto: 'Chamigo, me trabé un segundo. ¿Me repetís la pregunta con otras palabras?',
        gifSugerido: 'piensaLeve',
        exito: false,
      );
      GeminiLearner.evaluarYGuardar(pregunta, errorResp.texto, exito: errorResp.exito);
      return errorResp;
    }
  }

  static String? _obtenerRutaParaIntencion(String intencion) {
    switch (intencion) {
      case 'tienda':
        return '/tienda';
      case 'carrito':
        return '/carrito';
      case 'perfil_pescador':
      case 'activar_guia':
        return '/perfil';
      case 'gps':
      case 'crear_viaje':
        return '/mapa';
      case 'notificaciones':
        return '/notificaciones';
      case 'historial_viajes':
        return '/inicio';
      default:
        return null;
    }
  }

  static ElGuiaRespuesta _agregarRuta(ElGuiaRespuesta original, String? ruta) {
    if (ruta == null || original.rutaNavegacion != null) return original;
    return ElGuiaRespuesta(
      texto: original.texto,
      gifSugerido: original.gifSugerido,
      esHumorContextual: original.esHumorContextual,
      origenGemini: original.origenGemini,
      rutaNavegacion: ruta,
      exito: original.exito,
      mensaje: original.mensaje,
      error: original.error,
      tipoError: original.tipoError,
    );
  }

  static Producto? _buscarProductoEnConsulta(String query) {
    if (_catalogo.isEmpty) return null;
    final tokens = query.toLowerCase().split(RegExp(r'\s+'));
    Producto? mejor;
    int maxCoincidencias = 0;

    for (final p in _catalogo) {
      final nombreL = p.nombre.toLowerCase();
      final descL   = p.descripcion.toLowerCase();
      final rubroL  = p.rubro.toLowerCase();
      int coincidencias = 0;

      for (final token in tokens) {
        if (token.length <= 2) continue;
        if (nombreL.contains(token)) coincidencias += 3;
        if (descL.contains(token))   coincidencias += 1;
        if (rubroL.contains(token))  coincidencias += 2;
      }

      if (coincidencias > maxCoincidencias) {
        maxCoincidencias = coincidencias;
        mejor = p;
      }
    }
    return maxCoincidencias >= 3 ? mejor : null;
  }

  static String _respuestaProducto(Producto p, String pq) {
    final quiereStock  = pq.contains('stock') || pq.contains('quedan') ||
        pq.contains('hay') || pq.contains('disponib');
    final quierePrecio = pq.contains('precio') || pq.contains('cuesta') ||
        pq.contains('cuanto') || pq.contains('valor');

    String respuesta;
    if (quiereStock && !quierePrecio) {
      respuesta = 'Del ${p.nombre} nos quedan ${p.stock} unidades en la tienda.';
    } else if (quierePrecio && !quiereStock) {
      respuesta = 'El ${p.nombre} está a \$${p.precio.toStringAsFixed(0)}.';
    } else {
      respuesta = 'Del ${p.nombre} nos quedan ${p.stock} unidades a \$${p.precio.toStringAsFixed(0)}.';
    }

    if (p.stock <= 3 && p.stock > 0) {
      debugPrint('[BaqueanoRouter] stock_limit_warning: producto=${p.nombre}, stock=${p.stock}');
      respuesta += ' ¡Quedan las últimas!';
    } else if (p.stock == 0) {
      respuesta += ' Se nos agotó el stock por ahora.';
    }
    return '$respuesta ¿Te sirve para armar el aparejo?';
  }

  static bool esTemaProhibido(String pregunta) =>
      _temasProhibidos.any((t) => pregunta.toLowerCase().contains(t));

  // ── Diagnóstico verbal ─────────────────────────────────────────────────────

  static const List<String> _triggersEstado = [
    'conectado', 'conexion', 'conexión', 'estas online', 'estas en linea',
    'estas en línea', 'estás online', 'estás en linea', 'estás en línea',
    'sos ia', 'eres ia', 'modo ia', 'que motor', 'que modelo', 'qué motor', 'qué modelo',
    'funcionas', 'funcionas con', 'con que trabajas', 'con qué trabajas',
    'estado del sistema', 'estado sistema', 'modo offline', 'modo online',
  ];

  static bool _esConsultaEstado(String pq) =>
      _triggersEstado.any((t) => pq.contains(t));

  static Future<ElGuiaRespuesta> _respuestaEstado() async {
    if (ConnectivityBridge.estaConectado && GroqConfig.tieneApiKey) {
      try {
        final svc = GroqService();
        final respuesta = await svc.probarConexion(GroqConfig.apiKey).timeout(const Duration(seconds: 4));
        if (respuesta.contains('operativo') || respuesta.isNotEmpty) {
          return const ElGuiaRespuesta(
            texto: '¡Todo listo, chamigo! Estoy conectado a mi motor de IA en la nube (Groq Llama 3.3). Las respuestas serán instantáneas y súper completas.',
            gifSugerido: 'exito',
          );
        }
      } catch (e) {
        debugPrint('[BaqueanoRouter] Error de ping con Groq: $e');
        return ElGuiaRespuesta(
          texto: 'Tengo conexión y clave de Groq configurada, pero falló la prueba de comunicación: $e. Intentemos verificar la validez de la clave.',
          gifSugerido: 'duda',
        );
      }
    }    return const ElGuiaRespuesta(
      texto: '¡Todo listo, chamigo! Estoy operativo en modo local de contingencia, resolviendo tus consultas directamente con mis cartas náuticas offline.',
      gifSugerido: 'hablaConMate',
    );
  }

  // Intenciones que devuelven datos dinámicos: no se bloquean por repetición
  static const Set<String> _intentsDinamicos = {
    'hora', 'clima', 'gps', 'solunar', 'notificaciones', 'carrito',
  };

  static ElGuiaRespuesta? _detectarTriggersEnojo(String pq) {
    // 1. Detección de insistencia / repetición de frases idénticas
    // Excepto para intents dinámicos (hora, GPS, clima) que siempre dan datos frescos
    final intencionActual = _motorLocal.obtenerIntencionPrincipal(pq);
    final esDinamico = _intentsDinamicos.contains(intencionActual);

    if (esDinamico) {
      // Para datos dinámicos: reseteamos el contador de repetición y dejamos pasar
      _ultimaPregunta = null;
      _coincidenciasPregunta = 0;
    } else {
      if (_ultimaPregunta == pq) {
        _coincidenciasPregunta++;
      } else {
        _ultimaPregunta = pq;
        _coincidenciasPregunta = 1;
      }
    }

    if (!esDinamico && _coincidenciasPregunta >= 3) {
      _nivelFrustracion = (_nivelFrustracion + 1).clamp(0, 3);
      if (pq.contains('no anda') || pq.contains('no funciona') || pq.contains('error') || pq.contains('no responde')) {
        return ElGuiaRespuesta(
          texto: '😤 Pará amigo… si seguimos apretando todo junto hacemos llorar al robot.',
          gifSugerido: 'enojado',
        );
      }
    }

    // 2. Impaciencia
    if (pq.contains('dale') || pq.contains('apúrate') || pq.contains('apurate') || 
        pq.contains('hace rato espero') || pq.contains('rapido') || pq.contains('rápido') ||
        pq.contains('pura') || pq.contains('apuras') || pq.contains('apure')) {
      _nivelFrustracion = (_nivelFrustracion + 1).clamp(0, 3);
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_impaciencia', _respuestasImpaciencia);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'enojado');
    }

    // 3. Preguntas absurdas (tiburón en Chascomús, etc.)
    if ((pq.contains('tiburon') || pq.contains('tiburón')) && (pq.contains('chascomus') || pq.contains('chascomús') || pq.contains('laguna'))) {
      _nivelFrustracion = (_nivelFrustracion + 1).clamp(0, 3);
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_absurdas', _respuestasAbsurdas);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'enojado');
    }

    // 4. Furioso protector (tormenta peligrosa)
    if (pq.contains('tormenta') && (pq.contains('salgo') || pq.contains('pesco') || pq.contains('navego') || pq.contains('igual') || pq.contains('embarco'))) {
      _nivelFrustracion = (_nivelFrustracion + 1).clamp(0, 3);
      final lista = _obtenerListaLibreria('reacciones_clima', 'respuestas_protector', _respuestasProtector);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'enojado');
    }

    // 5. Cancelaciones de último momento
    if (pq.contains('cancelar') && (pq.contains('media hora') || pq.contains('30 min') || pq.contains('ahora') || pq.contains('ultimo momento') || pq.contains('último momento') || pq.contains('antes'))) {
      _nivelFrustracion = (_nivelFrustracion + 1).clamp(0, 3);
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_cancelacion', _respuestasCancelacion);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'enojado');
    }

    // 6. Mala suerte pescadora
    if (pq.contains('no pico') || pq.contains('no picó') || pq.contains('no pesque') || pq.contains('no pesqué') || pq.contains('sin pique') || pq.contains('nada de pique') || pq.contains('no pesco nada') || pq.contains('no pescó nada')) {
      _nivelFrustracion = (_nivelFrustracion + 1).clamp(0, 3);
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_mala_suerte', _respuestasMalaSuerte);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'enojado');
    }

    return null;
  }

  static ElGuiaRespuesta? _detectarTriggersTristeza(String pq) {
    // 1. Preguntas emocionales directas
    if (pq == '¿estás triste?' || pq == 'estas triste') {
      return const ElGuiaRespuesta(
        texto: "Un poquito… pero se me pasa. Contame vos, ¿cómo andás?",
        gifSugerido: 'triste',
      );
    }
    if (pq == '¿por qué?' || pq == 'por que' || pq == 'por qué') {
      return const ElGuiaRespuesta(
        texto: "Capaz porque hoy nadie pescó 😔 O porque el mate salió lavado…",
        gifSugerido: 'triste',
      );
    }
    if (pq.contains('no estés triste') || pq.contains('no estes triste')) {
      return const ElGuiaRespuesta(
        texto: "Bueno… gracias chamigo 😌 Ya me acomodaste un tornillo del ánimo.",
        gifSugerido: 'exito',
      );
    }
    if (pq == '¿qué te pasa?' || pq == 'que te pasa' || pq == 'como andas' || pq == '¿cómo andás?') {
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_que_te_pasa', _respuestasQueTePasa);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'triste');
    }

    // 2. Viaje cancelado
    if (pq.contains('cancelar viaje') || pq.contains('no puedo ir') || 
        pq.contains('se suspendió') || pq.contains('se suspendio') || 
        pq.contains('capitán canceló') || pq.contains('capitan cancelo') ||
        pq.contains('mal clima')) {
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_cancelado', _respuestasCancelado);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'triste');
    }

    // 3. Mala pesca (tristeza/empatía)
    if (pq.contains('no picó nada') || pq.contains('no pico nada') || 
        pq.contains('volví sin pescar') || pq.contains('volvi sin pescar') || 
        pq.contains('un desastre') || pq.contains('sin pique') || pq.contains('nada de pique')) {
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_mala_pesca_triste', _respuestasMalaPescaTriste);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'triste');
    }

    // 4. Usuario triste o frustrado
    if (pq.contains('estoy mal') || pq.contains('me fue horrible') || 
        pq.contains('estoy triste') || pq.contains('salió todo mal') || 
        pq.contains('salio todo mal') || pq.contains('me quiero ir') || 
        pq.contains('me peleé') || pq.contains('me pelee') || pq.contains('me siento solo')) {
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_usuario_triste', _respuestasUsuarioTriste);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'triste');
    }

    // 5. Deja de pescar
    if (pq.contains('no pesco más') || pq.contains('no pesco mas') || pq.contains('dejo de pescar') || pq.contains('no voy a pescar más')) {
      final lista = _obtenerListaLibreria('emociones_pescador', 'respuestas_no_pesco_mas', _respuestasNoPescoMas);
      final texto = lista[Random().nextInt(lista.length)];
      return ElGuiaRespuesta(texto: texto, gifSugerido: 'triste');
    }

    // 6. Mucho tiempo sin usar la app (simulado)
    if (pq.contains('hace mucho') || pq.contains('tanto tiempo') || pq.contains('volví') || pq.contains('volvi')) {
      return const ElGuiaRespuesta(
        texto: "Te extrañé un poco… las boyas estaban juntando polvo 😔",
        gifSugerido: 'triste',
      );
    }

    return null;
  }

  static List<Producto> getProductosEscasos() =>
      _catalogo.where((p) => p.activo && p.stock > 0 && p.stock <= 3).toList();

  static List<Producto> getCatalogo()    => List.unmodifiable(_catalogo);
  static int get totalProductos          => _catalogo.where((p) => p.activo).length;
  static ElGuiaEngine get motor          => _motorLocal;

  static List<String> _obtenerListaLibreria(String libName, String key, List<String> fallback) {
    try {
      final libData = _motorLocal.obtenerLibreria(libName);
      if (libData != null && libData.containsKey(key)) {
        final list = libData[key];
        if (list is List) {
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {}
    return fallback;
  }
}
