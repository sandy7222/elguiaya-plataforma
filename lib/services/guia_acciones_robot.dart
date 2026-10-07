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

  static final Random _random = Random();
  static bool _cargado = false;
  static Set<String> _rellenoInicio = {};
  static Set<String> _rellenoFin = {};
  static final Map<String, _Accion> _porFrase = {};

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
    final accion = _porFrase[tokens.sublist(ini, fin).join(' ')];
    if (accion == null) return null;
    return AccionRobot(accion.id, accion.estado, accion.respuestas[_random.nextInt(accion.respuestas.length)]);
  }
}

class _Accion {
  final String id;
  final String estado;
  final List<String> respuestas;
  _Accion(this.id, this.estado, this.respuestas);
}
