import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/el_guia_respuesta.dart';
import 'el_guia_context.dart';

/// Motor de Humor Contextual — El Guía
///
/// Reglas clave:
///   1. NUNCA en modos: emergencia, supervivencia, primeros_auxilios, perdido
///   2. 10% de probabilidad de humor contextual en charla casual
///   3. Anti-repetición: evita los últimos 5 chistes usados
///   4. GIF diferente según tipo de humor (suave vs carcajada)
class ElGuiaHumorEngine {
  static final ElGuiaHumorEngine _instance = ElGuiaHumorEngine._internal();
  factory ElGuiaHumorEngine() => _instance;
  ElGuiaHumorEngine._internal();

  bool _inicializado = false;
  final Random _random = Random();

  // ── Datos cargados ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _chistes = [];
  List<String> _introducciones = [];
  Map<String, dynamic> _humorContextual = {};

  // ── Anti-repetición: historial de IDs ────────────────────────────────────
  final List<int> _historialChistes = [];
  static const int _maxHistorial = 5;

  // ── Modos que BLOQUEAN el humor ───────────────────────────────────────────
  static const Set<String> _modosBloqueo = {
    'emergencia', 'supervivencia',
  };

  static const Set<String> _intencionesBloqueo = {
    'emergencia', 'perdido', 'agua', 'refugio', 'fuego',
    'primeros_auxilios', 'clima',
  };

  // ── GIF map: intención → estado GIF sugerido ──────────────────────────────
  static const Map<String, String> gifPorIntencion = {
    'saludo':            'saludo',
    'despedida':         'saludo',
    'agradecimiento':    'exito',
    'hora':              'piensaLeve',
    'mate':              'tomaMate',
    'preguntas_humanas': 'hablaConMate',
    'ayuda_app':         'explica',
    'charla_cotidiana':  'hablaConMate',
    'chiste':            'chiste',
    'emergencia':        'duda',
    'perdido':           'duda',
    'agua':              'explica',
    'refugio':           'explica',
    'fuego':             'explica',
    'alimento':          'explica',
    'clima':             'piensaProfundo',
    'gps':               'piensaLeve',
    'primeros_auxilios': 'duda',
    'peces':             'explica',
    'carnadas':          'explica',
    'nudos':             'explica',
    'boyas':             'explica',
    'plomadas':          'explica',
    'canas_y_reeles':    'explica',
    'rio':               'piensaProfundo',
    'tienda':            'exito',
    'reserva':           'piensaLeve',
    'fallback':          'duda',
  };

  // ── INICIALIZACIÓN ────────────────────────────────────────────────────────
  Future<void> inicializar() async {
    if (_inicializado) return;

    try {
      final chistesStr = await rootBundle
          .loadString('assets/elguia/librerias/chistes.json');
      final data = json.decode(chistesStr) as Map<String, dynamic>;
      _chistes = List<Map<String, dynamic>>.from(data['chistes'] as List);
      _introducciones = List<String>.from(data['introducciones'] as List);
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ [HUMOR] Error cargando chistes.json: $e');
    }

    try {
      final humorStr = await rootBundle
          .loadString('assets/elguia/librerias/humor_contextual.json');
      _humorContextual = json.decode(humorStr) as Map<String, dynamic>;
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ [HUMOR] Error cargando humor_contextual.json: $e');
    }

    _inicializado = true;
    // ignore: avoid_print
    print('✅ [HUMOR] Motor cargado: ${_chistes.length} chistes.');
  }

  // ── RESPUESTA DE CHISTE DIRECTO ───────────────────────────────────────────
  /// Cuando el usuario pide explícitamente un chiste.
  ElGuiaRespuesta responderChiste() {
    if (_chistes.isEmpty) {
      return ElGuiaRespuesta.chiste(
        'Bueno, ahí va. ¿Por qué el pez no usa computadora? Porque le tiene terror a las redes.',
        'chiste',
      );
    }

    final chiste = _elegirChisteSinRepetir();
    final intro = _introducciones.isNotEmpty
        ? _introducciones[_random.nextInt(_introducciones.length)]
        : 'Ahí va.';
    final gif = chiste['gif'] as String? ?? 'chiste';

    // Registrar en historial
    _registrarChiste(chiste['id'] as int);

    return ElGuiaRespuesta.chiste('$intro ${chiste['texto']}', gif);
  }

  // ── HUMOR CONTEXTUAL (10% de probabilidad) ────────────────────────────────
  /// Intenta inyectar humor contextual a una respuesta normal.
  /// Devuelve null si no corresponde o la probabilidad no se cumple.
  ElGuiaRespuesta? intentarHumorContextual(
    String textoRespuestaNormal,
    String intencion,
    ElGuiaContext contexto,
  ) {
    // 1. Bloquear si el modo o la intención no permiten humor
    if (!_contextPermiteHumor(intencion, contexto)) return null;

    // 2. 10% de probabilidad
    if (_random.nextDouble() > 0.10) return null;

    // 3. Buscar frase contextual por situación
    final situacion = _detectarSituacion(intencion, textoRespuestaNormal);
    if (situacion == null) return null;

    final frases = _humorContextual['por_situacion']?[situacion] as List?;
    if (frases == null || frases.isEmpty) return null;

    final elegida = frases[_random.nextInt(frases.length)] as Map<String, dynamic>;
    final textoHumor = elegida['texto'] as String;
    final gif = elegida['gif'] as String? ?? 'hablaConMate';

    // Combinar: respuesta normal + comentario humorístico
    return ElGuiaRespuesta.humorContextual(
      '$textoRespuestaNormal\n\n$textoHumor',
      gif,
    );
  }

  // ── GIF SUGERIDO PARA INTENCIÓN ───────────────────────────────────────────
  /// Devuelve el GIF sugerido para una intención dada.
  String gifParaIntencion(String intencion) {
    return gifPorIntencion[intencion] ?? 'hablaConMate';
  }

  // ── HELPERS PRIVADOS ──────────────────────────────────────────────────────
  Map<String, dynamic> _elegirChisteSinRepetir() {
    // Disponibles = todos menos los del historial
    var disponibles = _chistes
        .where((c) => !_historialChistes.contains(c['id'] as int))
        .toList();

    // Si todos fueron usados, reiniciar (pero mantener el último para no repetir)
    if (disponibles.isEmpty) {
      final ultimo = _historialChistes.isNotEmpty ? _historialChistes.last : -1;
      _historialChistes.clear();
      disponibles = _chistes
          .where((c) => c['id'] != ultimo)
          .toList();
    }

    return disponibles[_random.nextInt(disponibles.length)];
  }

  void _registrarChiste(int id) {
    _historialChistes.add(id);
    if (_historialChistes.length > _maxHistorial) {
      _historialChistes.removeAt(0);
    }
  }

  bool _contextPermiteHumor(String intencion, ElGuiaContext contexto) {
    if (_modosBloqueo.contains(contexto.modoActual)) return false;
    if (_intencionesBloqueo.contains(intencion)) return false;
    return true;
  }

  String? _detectarSituacion(String intencion, String texto) {
    final t = texto.toLowerCase();
    if (intencion == 'charla_cotidiana') {
      if (t.contains('no pica') || t.contains('pique') || t.contains('franco') ||
          t.contains('desayunando') || t.contains('negociando')) {
        return 'no_pica';
      }
      if (t.contains('espera') || t.contains('horas') || t.contains('tiempo')) {
        return 'espera_larga';
      }
      if (t.contains('cansado') || t.contains('agotado')) {
        return 'cansancio_leve';
      }
      if (t.contains('aburrido') || t.contains('aburro')) {
        return 'aburrimiento';
      }
    }
    if (t.contains('anzuelo') && (t.contains('perdi') || t.contains('perdí'))) {
      return 'perdio_anzuelo';
    }
    if (t.contains('enredada') || t.contains('enredado') || t.contains('nudo')) {
      return 'linea_enredada';
    }
    if (t.contains('se escapo') || t.contains('se escapó') ||
        t.contains('lo perdi') || t.contains('lo perdí') ||
        t.contains('se solto') || t.contains('se soltó') ||
        t.contains('se fue el pez') || t.contains('perdi el pez') ||
        t.contains('perdí el pez')) {
      return 'perdio_pez';
    }
    return null;
  }

  bool get estaInicializado => _inicializado;
  int get totalChistes => _chistes.length;
}
