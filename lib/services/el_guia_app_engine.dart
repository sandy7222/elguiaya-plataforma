import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'el_guia_context.dart';

class ElGuiaAppEngine {
  static final ElGuiaAppEngine _instance = ElGuiaAppEngine._internal();
  factory ElGuiaAppEngine() => _instance;
  ElGuiaAppEngine._internal();

  bool _inicializado = false;
  final Random _random = Random();
  final Map<String, Map<String, dynamic>> _modulos = {};

  static const List<String> _archivosModulos = [
    'inicio',
    'mapa_app',
    'reservas_app',
    'tienda_app',
    'carnadas_app',
    'perfil_app',
    'sos_app',
    'notificaciones_app',
    'blog_app',
    'configuracion_app',
    'login_app',
    'mis_pesca_app',
    'cotizacion_app',
    'crear_pedido_app',
    'cotizaciones_pescador_app',
    'pago_app',
    'confirmar_arribo_app',
    'calificacion_app',
  ];

  static const List<String> activadoresGenerales = [
    'como funciona',
    'cómo funciona',
    'no encuentro',
    'donde esta',
    'dónde está',
    'como hago',
    'cómo hago',
    'ayuda con la app',
    'para que sirve',
    'para qué sirve',
    'no se usar',
    'no sé usar',
    'como uso',
    'cómo uso',
    'no entiendo',
    'me explicas',
    'me explicás',
    'no puedo',
    'como entro',
    'cómo entro',
  ];

  static const Map<String, String> _aliasAPantalla = {
    // tienda, catálogo, equipos, aparejos
    'tienda': 'tienda_app',
    'catálogo': 'tienda_app',
    'catalogo': 'tienda_app',
    'equipos': 'tienda_app',
    'aparejos': 'tienda_app',

    // carrito, compras, lo que elegí
    'carrito': 'carrito_app',
    'compras': 'carrito_app',
    'lo que elegí': 'carrito_app',
    'lo que elegi': 'carrito_app',

    // pagar, pasarela, mercado pago, seña
    'pagar': 'pago_app',
    'pasarela': 'pago_app',
    'mercado pago': 'pago_app',
    'seña': 'pago_app',
    'sena': 'pago_app',

    // inicio, portal, home, buscar capitán
    'inicio': 'inicio',
    'portal': 'inicio',
    'home': 'inicio',
    'buscar capitán': 'inicio',
    'buscar capitan': 'inicio',
    'pantalla principal': 'inicio',

    // mapa, tracker, dónde estoy, GPS
    'mapa': 'mapa_app',
    'tracker': 'mapa_app',
    'dónde estoy': 'mapa_app',
    'donde estoy': 'mapa_app',
    'gps': 'mapa_app',
    'GPS': 'mapa_app',
    'ubicacion': 'mapa_app',
    'ubicación': 'mapa_app',

    // notificaciones, alertas, avisos
    'notificaciones': 'notificaciones_app',
    'alertas': 'notificaciones_app',
    'avisos': 'notificaciones_app',

    // perfil, mi cuenta, mis datos
    'perfil': 'perfil_app',
    'mi cuenta': 'perfil_app',
    'mis datos': 'perfil_app',

    // historial, mis viajes, viajes anteriores
    'historial': 'historial_app',
    'mis viajes': 'historial_app',
    'viajes anteriores': 'historial_app',

    // favoritos, guardados, mis favoritos
    'favoritos': 'favoritos_app',
    'guardados': 'favoritos_app',
    'mis favoritos': 'favoritos_app',

    // blog, tutoriales, aprender, nudos
    'blog': 'blog_app',
    'tutoriales': 'blog_app',
    'aprender': 'blog_app',
    'nudos': 'blog_app',
    'noticias': 'blog_app',

    // solunar, tabla solunar, luna
    'solunar': 'solunar_app',
    'tabla solunar': 'solunar_app',
    'luna': 'solunar_app',

    // clima, pronóstico, tiempo
    'clima': 'clima_app',
    'pronóstico': 'clima_app',
    'pronostico': 'clima_app',
    'tiempo': 'clima_app',

    // Otros existentes
    'cotizacion': 'cotizacion_app',
    'cotización': 'cotizacion_app',
    'presupuesto': 'cotizacion_app',
    'reserva': 'reservas_app',
    'reservas': 'reservas_app',
    'carnadas en la app': 'carnadas_app',
    'sos': 'sos_app',
    'emergencia de la app': 'sos_app',
    'configuracion': 'configuracion_app',
    'configuración': 'configuracion_app',
    'login': 'login_app',
    'ingresar': 'login_app',
    'mis pesca': 'mis_pesca_app',
    'crear pedido': 'crear_pedido_app',
    'quiero pescar': 'crear_pedido_app',
    'ver cotizaciones': 'cotizaciones_pescador_app',
    'confirmar arribo': 'confirmar_arribo_app',
    'arribo': 'confirmar_arribo_app',
    'calificacion': 'calificacion_app',
    'anclas': 'calificacion_app',
  };

  static const List<String> _activadoresSiguientePaso = [
    'y después',
    'y despues',
    'siguiente',
    'qué sigue',
    'que sigue',
    'y luego',
    'y ahora que',
    'y ahora qué',
    'continua',
    'continuá',
  ];

  static const List<String> _frasesPuente = [
    'Dale, te ayudo.',
    'Dale, vamos juntos.',
    'No pasa nada, te voy guiando.',
    'Claro. Te explico paso a paso.',
    'Vamos a resolverlo.',
    'Sin drama. Te cuento cómo es.',
  ];

  static const List<String> _preguntasGuiadas = [
    '¿Qué estás buscando? ¿El mapa, las reservas, la tienda o tu perfil?',
    '¿Qué querés usar? Decime: el GPS, reservas, la tienda, perfil u otra cosa.',
  ];

  Future<void> inicializar() async {
    if (_inicializado) return;
    for (final archivo in _archivosModulos) {
      try {
        final contenido = await rootBundle.loadString(
          'assets/elguia/app/$archivo.json',
        );
        final datos = json.decode(contenido) as Map<String, dynamic>;
        final clave = datos['pantalla'] as String? ?? archivo;
        _modulos[archivo] = datos;
        if (clave != archivo) _modulos[clave] = datos;
      } catch (_) {}
    }
    _inicializado = true;
  }

  Future<String> responder(
    String textoNormalizado,
    ElGuiaContext contexto,
  ) async {
    if (!_inicializado) await inicializar();
    if (contexto.esperandoRespuestaGuiada)
      return _resolverRespuestaGuiada(textoNormalizado, contexto);
    if (_esSiguientePaso(textoNormalizado) &&
        contexto.pantallaActual.isNotEmpty)
      return _avanzarPaso(contexto);
    final pantalla = detectarPantalla(textoNormalizado);
    if (pantalla != null) {
      contexto.pantallaActual = pantalla;
      contexto.pasoActualEnGuia = 0;
      return _responderSobrePantalla(pantalla, textoNormalizado);
    }
    if (contexto.pantallaActual.isNotEmpty)
      return _responderSeguimiento(textoNormalizado, contexto);
    return _iniciarPreguntaGuiada(contexto);
  }

  String _resolverRespuestaGuiada(String texto, ElGuiaContext contexto) {
    contexto.esperandoRespuestaGuiada = false;
    final pantalla = detectarPantalla(texto);
    if (pantalla != null) {
      contexto.pantallaActual = pantalla;
      contexto.pasoActualEnGuia = 0;
      return _responderSobrePantalla(pantalla, texto);
    }
    return 'No te ubiqué bien.';
  }

  String _iniciarPreguntaGuiada(ElGuiaContext contexto) {
    contexto.esperandoRespuestaGuiada = true;
    return _preguntasGuiadas[_random.nextInt(_preguntasGuiadas.length)];
  }

  String? detectarPantalla(String texto) {
    String? mejorModulo;
    int mejorLongitud = 0;
    for (final entry in _aliasAPantalla.entries) {
      if (texto.contains(entry.key) && entry.key.length > mejorLongitud) {
        mejorLongitud = entry.key.length;
        mejorModulo = entry.value;
      }
    }
    return mejorModulo;
  }

  bool _esSiguientePaso(String texto) =>
      _activadoresSiguientePaso.any((a) => texto.contains(a));

  String _avanzarPaso(ElGuiaContext contexto) {
    final modulo = _modulos[contexto.pantallaActual];
    if (modulo == null) return "No hay pasos.";
    final pasos = modulo['pasos'] as List<dynamic>?;
    if (pasos == null || pasos.isEmpty) return "No hay más pasos.";
    final indice = contexto.pasoActualEnGuia + 1;
    if (indice >= pasos.length) return "¡Eso es todo!";
    contexto.pasoActualEnGuia = indice;
    return 'Paso ${indice + 1}: ${pasos[indice]}';
  }

  String _responderSobrePantalla(String clave, String texto) {
    final modulo = _modulos[clave];
    if (modulo == null) return "Sección no encontrada.";
    final respCorta = modulo['respuesta_corta'] as String?;
    return respCorta ?? "Te guío.";
  }

  String _responderSeguimiento(String texto, ElGuiaContext contexto) {
    return _modulos[contexto.pantallaActual]?['respuesta_corta'] ??
        "¿Seguimos?";
  }
}
