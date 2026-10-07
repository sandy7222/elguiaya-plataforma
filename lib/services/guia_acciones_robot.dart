import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'guia_retrieval/guia_texto_es.dart';

/// Una orden que el robot cumple actuando: [estado] es el nombre de `CapitanState` (decide el GIF) y [respuesta] lo que dice.
class AccionRobot {
  final String id;
  final String estado;
  final String respuesta;
  const AccionRobot(this.id, this.estado, this.respuesta);
}

/// Un pedido de acción para el robot flotante. Cada pedido es un objeto nuevo: dos "tomá mate" seguidos avisan dos veces.
class PedidoAccionRobot {
  final String estado;
  PedidoAccionRobot(this.estado);
}

/// Acciones del robot ("tomá mate", "sentate y escuchá", "reíte", "ponete furioso"...): el robot actúa con los GIFs que ya tiene.
///
/// Pedido del dueño. La tabla es `assets/elguia/acciones_robot.json` (editable). Se resuelve sin nube ni IA, y **solo si la frase
/// es TODA la orden** (se ignoran muletillas al principio y al final: "che", "dale", "por favor"...): así "cómo se toma mate" o
/// "pensá en una carnada para el dorado" siguen siendo preguntas y nunca se las traga una gracia del robot. El router lo consulta
/// después del portón de seguridad: una emergencia nunca dispara una acción. Flag `guia_acciones_robot` (encendido).
class GuiaAccionesRobot {
  static const String prefAcciones = 'guia_acciones_robot';
  static const String _asset = 'assets/elguia/acciones_robot.json';
  static bool habilitado = true;

  /// El router publica acá la orden que acaba de detectar; el robot flotante (overlay) la escucha. Así el robot actúa venga la orden
  /// del chat de la pestaña "El Guía", del micrófono del avatar o de donde sea (el chat solo recibía el texto y descartaba la animación).
  static final ValueNotifier<PedidoAccionRobot?> pedida = ValueNotifier<PedidoAccionRobot?>(null);

  static final Random _random = Random();
  static bool _cargado = false;
  static Set<String> _rellenoInicio = {};
  static Set<String> _rellenoFin = {};
  static final Map<String, _Accion> _porFrase = {};

  // Pedidos metidos en una frase más larga ("hola guía, me gustaría saber si podés tomar mate").
  static List<List<String>> _marcadores = [];
  static final List<_Pedido> _pedidos = [];

  /// Palabras que, entre el pedido y la acción, indican que es una pregunta ("quiero que me expliques cómo tomar mate").
  static const Set<String> _esPregunta = {
    'explicar', 'expliques', 'explicame', 'explicas', 'decirme', 'decime', 'contarme', 'contame', 'ensenar', 'ensenarme', 'ensename',
    'ensenes', 'decir', 'saber', 'sabes',
  };
  // Si la palabra justo antes de la acción es una de estas, es una pregunta sobre la acción, no la orden.
  static const Set<String> _antesEsPregunta = {'como', 'cuando', 'donde', 'cual', 'cuanto', 'porque', 'para', 'con', 'sin', 'de', 'del'};
  static const Set<String> _negaciones = {'no', 'nunca', 'jamas', 'ni'};
  static const int _colaMaxima = 4;

  static void aplicarFlags(SharedPreferences prefs) {
    habilitado = prefs.getBool(prefAcciones) ?? habilitado;
  }

  /// Carga la tabla una sola vez. Si falla, no hay acciones (el robot sigue como siempre).
  static Future<void> cargar() async {
    if (_cargado) return;
    try {
      cargarDesdeJson(await rootBundle.loadString(_asset));
    } catch (e) {
      debugPrint('[GuiaAccionesRobot] no se pudo cargar la tabla: $e');
    }
  }

  @visibleForTesting
  static void cargarDesdeJson(String contenido) {
    final datos = jsonDecode(contenido) as Map<String, dynamic>;
    String n(Object? t) => GuiaTextoEs.normalizar(t.toString());
    _rellenoInicio = (datos['relleno_inicio'] as List? ?? const []).map(n).toSet();
    _rellenoFin = (datos['relleno_fin'] as List? ?? const []).map(n).toSet();
    _porFrase.clear();
    _pedidos.clear();
    _marcadores = (datos['marcadores_pedido'] as List? ?? const []).map((m) => n(m).split(' ')).toList();
    for (final a in (datos['acciones'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final accion = _Accion(
        a['id'].toString(),
        a['estado'].toString(),
        (a['respuestas'] as List? ?? const []).map((r) => r.toString()).where((r) => r.trim().isNotEmpty).toList(),
      );
      if (accion.respuestas.isEmpty) continue;
      for (final f in (a['frases'] as List? ?? const [])) {
        _porFrase[n(f)] = accion;
      }
      for (final f in (a['pedidos'] as List? ?? const [])) {
        _pedidos.add(_Pedido(n(f).split(' '), accion));
      }
      _pedidos.sort((x, y) => y.tokens.length.compareTo(x.tokens.length));
    }
    _cargado = true;
  }

  /// La acción pedida, o null si la frase no es (toda) una orden del robot.
  static AccionRobot? detectar(String texto) {
    if (!habilitado || _porFrase.isEmpty) return null;
    final tokens = GuiaTextoEs.normalizar(texto).split(' ').where((t) => t.isNotEmpty).toList();
    var ini = 0;
    var fin = tokens.length;
    while (ini < fin && _rellenoInicio.contains(tokens[ini])) {
      ini++;
    }
    while (fin > ini && _rellenoFin.contains(tokens[fin - 1])) {
      fin--;
    }
    if (ini >= fin) return null;
    var accion = _porFrase[tokens.sublist(ini, fin).join(' ')];
    accion ??= _pedidoDentroDeUnaFrase(tokens);
    if (accion == null) return null;
    return AccionRobot(accion.id, accion.estado, accion.respuestas[_random.nextInt(accion.respuestas.length)]);
  }

  static int _buscar(List<String> tokens, List<String> frase, [int desde = 0]) {
    for (var i = desde; i + frase.length <= tokens.length; i++) {
      var ok = true;
      for (var j = 0; j < frase.length; j++) {
        if (tokens[i + j] != frase[j]) {
          ok = false;
          break;
        }
      }
      if (ok) return i;
    }
    return -1;
  }

  /// La acción pedida DENTRO de una frase más larga: hace falta un pedido explícito ("podés", "quiero que"...) ANTES de la acción, sin
  /// negaciones, sin palabras de pregunta entre el pedido y la acción, y casi nada después. Si no, sigue siendo una pregunta o charla.
  static _Accion? _pedidoDentroDeUnaFrase(List<String> tokens) {
    if (_pedidos.isEmpty || _marcadores.isEmpty) return null;
    if (tokens.any(_negaciones.contains)) return null;
    for (final p in _pedidos) {
      final i = _buscar(tokens, p.tokens);
      if (i < 0) continue;
      if (tokens.length - (i + p.tokens.length) > _colaMaxima) continue;
      if (i > 0 && _antesEsPregunta.contains(tokens[i - 1])) continue;
      // Un pedido explícito antes de la acción, y sin palabras de pregunta entre los dos.
      for (final m in _marcadores) {
        var desde = 0;
        while (true) {
          final k = _buscar(tokens, m, desde);
          if (k < 0 || k + m.length > i) break;
          final entre = tokens.sublist(k + m.length, i);
          if (!entre.any(_esPregunta.contains)) return p.accion;
          desde = k + 1;
        }
      }
    }
    return null;
  }
}

class _Pedido {
  final List<String> tokens;
  final _Accion accion;
  _Pedido(this.tokens, this.accion);
}

class _Accion {
  final String id;
  final String estado;
  final List<String> respuestas;
  _Accion(this.id, this.estado, this.respuestas);
}
