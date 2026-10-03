import 'dart:math';

import 'guia_ficha.dart';
import 'guia_texto_es.dart';

/// Cómo se le muestra una ficha al usuario.
class GuiaPresentacion {
  /// Entrada corta y variada ("Mirá, chamigo:"). Puede estar vacía.
  final String intro;

  /// El contenido, hecho solo con oraciones de la ficha.
  final String cuerpo;

  /// Un procedimiento que no entra entero: se da el resumen y se ofrece decirlo
  /// paso a paso. Los pasos para dictar están en [pasos] (y los ingredientes, si
  /// los hay, en [ingredientes]).
  final bool ofreceDictado;
  final List<String> pasos;
  final List<String> ingredientes;

  const GuiaPresentacion({
    this.intro = '',
    required this.cuerpo,
    this.ofreceDictado = false,
    this.pasos = const [],
    this.ingredientes = const [],
  });

  String get texto => intro.isEmpty ? cuerpo : '$intro $cuerpo';
}

/// Convierte una ficha cruda en una respuesta.
///
/// Las 342 fichas reales vienen con emojis, el título en MAYÚSCULAS, campos tipo
/// planilla ("Uso: …", "Resistencia: ALTA"), listas numeradas y hasta 1.800
/// caracteres. El presentador las limpia SIN INVENTAR NADA: solo recorta y une
/// oraciones de la ficha, más plantillas fijas para los campos conocidos
/// ("Resistencia: ALTA" → "Es muy resistente"). Un campo desconocido se deja
/// afuera; no se inventa una frase.
///
///  · Ficha INFORMATIVA (un pez, una carnada): 2–3 oraciones, ≤ 350 caracteres,
///    eligiendo las que coinciden con la pregunta.
///  · Ficha de PROCEDIMIENTO (pasos o lista numerada): NO se corta ningún paso.
///    Un nudo con la mitad de los pasos es peor que nada. Los pasos pasan a
///    oraciones naturales ("Primero…, después…, por último…") con un tope de
///    600. Si no entran, se da el resumen y se ofrece decirlo paso a paso.
class GuiaPresentador {
  static const int maxInformativa = 350;
  static const int maxProcedimiento = 600;
  static const String ofertaDictado = '¿Querés que te lo diga paso a paso?';

  static const List<String> _entradas = [
    'Mirá, chamigo:',
    'Te cuento:',
    'Dale, fijate:',
    'A ver, pescador:',
    'Escuchame:',
    'Fijate:',
  ];

  static final RegExp _emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}\u{200D}]', unicode: true);
  static final RegExp _itemNumerado = RegExp(r'^\d+[\.\)]\s+(.*)$');
  static final RegExp _vineta = RegExp(r'^[-•*]\s+(.*)$');
  static final RegExp _encabezado = RegExp(r'^([^:]{2,45}):$');
  static final RegExp _campo = RegExp(r'^([A-ZÁÉÍÓÚÑ][A-Za-záéíóúñ_ ]{1,30}):\s+(.+)$');

  // ── Campos conocidos ──────────────────────────────────────────────────────
  // Campos cuyo valor ya es una oración de la ficha: se usan tal cual.
  static const Set<String> _camposTexto = {
    'consejo', 'consejo del baqueano', 'descripcion', 'descripcion corta', 'descripcion extensa',
    'consejo encarne', 'error comun', 'efecto pesca', 'mejor momento', 'marea', 'mareas',
    'agua turbia', 'tormenta', 'parada de agua', 'zona pesca', 'crecida', 'recomendacion',
    'riesgo principal', 'como agarrarlo', 'revisar aparejo', 'gomones', 'embarcacion', 'causa',
    'carnada recomendada',
  };

  // Campos de valor corto, con una plantilla fija. {v} es el valor de la ficha.
  // La segunda parte son las palabras con las que se puede preguntar por el
  // campo ("qué carnada…" → carnada), que solo se usan para puntuar.
  static const Map<String, List<String>> _plantillas = {
    'uso': ['Sirve para {v}.', 'uso sirve usar para'],
    'habitat': ['Vive en {v}.', 'habitat vive donde zona'],
    'carnada': ['Se pesca con {v}.', 'carnada carnadas cebo'],
    'principales': ['Las principales son {v}.', 'carnada carnadas principales'],
    'secundarias': ['Las secundarias son {v}.', 'carnada carnadas secundarias'],
    'equipo': ['Conviene usar {v}.', 'equipo cana reel linea aparejo'],
    'temporada': ['Respecto de la temporada, {v}.', 'temporada epoca cuando mes'],
    'peligro': ['El peligro es {v}.', 'peligro riesgo peligroso'],
    'ideal para': ['Es ideal para {v}.', 'ideal sirve para'],
    'recomendado para': ['Se recomienda para {v}.', 'recomendado recomienda para'],
    'peso recomendado': ['El peso recomendado es {v}.', 'peso plomada gramos'],
    'nombre cientifico': ['Su nombre científico es {v}.', 'nombre cientifico'],
    'caracteristicas': ['Sus características son {v}.', 'caracteristicas'],
    'estado': ['Su estado de conservación es {v}.', 'estado conservacion'],
    'cuota buenos aires': ['La cuota en Buenos Aires es {v}.', 'cuota cupo piezas buenos aires'],
    'cana': ['Para la caña, {v}.', 'cana equipo'],
    'reel': ['Para el reel, {v}.', 'reel equipo'],
    'aparejo': ['Para el aparejo, {v}.', 'aparejo equipo'],
    'anzuelo': ['Para el anzuelo, {v}.', 'anzuelo equipo'],
  };

  // De lo que se arma una oración con sentido propio, pero que casi nunca es lo
  // que se pregunta: no se usan para "rellenar" una respuesta corta.
  static const Set<String> _secundarias = {'nombre cientifico', 'estado', 'causa', 'cuota buenos aires'};

  // ── API ───────────────────────────────────────────────────────────────────

  static GuiaPresentacion presentar(GuiaFicha ficha, String pregunta, {Random? random}) {
    final rnd = random ?? Random();
    final p = _parsear(ficha);
    final entrada = _entradas[rnd.nextInt(_entradas.length)];

    if (p.pasos.length >= 2) {
      return _presentarProcedimiento(ficha, p, entrada);
    }
    return _presentarInformativa(p, pregunta, entrada);
  }

  /// Los pasos de un procedimiento ya limpios (sin numeración), o vacío.
  static List<String> pasosDe(GuiaFicha ficha) {
    final p = _parsear(ficha);
    return p.pasos.length >= 2 ? p.pasos : const [];
  }

  /// El mensaje del paso [i] de [n] cuando se dicta de a uno.
  static String mensajeDePaso(List<String> pasos, int i) {
    final n = pasos.length;
    final paso = _terminar(_minusculaInicial(pasos[i]));
    final String conector;
    if (n == 1) {
      return '${_mayusculaInicial(paso)} Listo, ese era el único paso.';
    } else if (i == 0) {
      conector = 'Primero, ';
    } else if (i == n - 1) {
      return 'Por último, $paso Listo, ese era el último paso.';
    } else {
      const medios = ['después, ', 'luego, ', 'ahora, '];
      conector = _mayusculaInicial(medios[(i - 1) % medios.length]);
    }
    return '$conector$paso ¿Sigo?';
  }

  /// El mensaje de los ingredientes (si los hay) cuando se dicta de a uno.
  static String mensajeDeIngredientes(List<String> ingredientes) =>
      'Los ingredientes: ${ingredientes.map(_quitarPuntoFinal).join(', ')}. ¿Sigo con los pasos?';

  // ── Ficha informativa ─────────────────────────────────────────────────────

  static GuiaPresentacion _presentarInformativa(_Ficha p, String pregunta, String entrada) {
    final presupuesto = maxInformativa - entrada.length - 1;
    var unidades = p.unidades;
    if (unidades.isEmpty) {
      // Una ficha de una sola línea con un campo que no conocemos ("Moncholo:
      // pez de 40-50 cm…"): se muestra la línea tal cual, sin inventar nada.
      unidades = [for (final o in _oraciones(p.limpio)) _Unidad(o, '', 0)];
    }
    final cuerpo = _elegir(unidades, pregunta, presupuesto);
    return GuiaPresentacion(intro: entrada, cuerpo: cuerpo);
  }

  /// Elige 2–3 oraciones: las que coinciden con la pregunta (la etiqueta del
  /// campo pesa más que las palabras sueltas), en el orden de la ficha.
  static String _elegir(List<_Unidad> unidades, String pregunta, int presupuesto) {
    final q = GuiaTextoEs.tokenizar(pregunta).toSet();
    final puntaje = <_Unidad, int>{};
    for (final u in unidades) {
      final enTexto = GuiaTextoEs.tokenizar(u.texto).where(q.contains).toSet().length;
      final enEtiqueta = GuiaTextoEs.tokenizar(u.etiqueta).where(q.contains).toSet().length;
      puntaje[u] = enTexto + 3 * enEtiqueta;
    }
    final mejor = puntaje.values.fold<int>(0, max);

    final ordenadas = [...unidades]
      ..sort((a, b) {
        final c = puntaje[b]!.compareTo(puntaje[a]!);
        return c != 0 ? c : a.orden.compareTo(b.orden);
      });

    final elegidas = <_Unidad>[];
    var usado = 0;
    bool entra(_Unidad u) => usado + u.texto.length + (elegidas.isEmpty ? 0 : 1) <= presupuesto;

    // Las que coinciden con la pregunta. Si hay una coincidencia fuerte (un
    // campo preguntado), las oraciones que solo suman una palabra suelta se
    // dejan afuera para no diluir la respuesta.
    for (final u in ordenadas) {
      if (elegidas.length >= 3) break;
      final s = puntaje[u]!;
      if (s <= 0 || s * 2 < mejor) continue;
      if (elegidas.isEmpty && u.texto.length > presupuesto) {
        elegidas.add(_Unidad(_recortar(u.texto, presupuesto), u.etiqueta, u.orden));
        usado = elegidas.first.texto.length;
        break;
      }
      if (entra(u)) {
        usado += u.texto.length + (elegidas.isEmpty ? 0 : 1);
        elegidas.add(u);
      }
    }

    // Pregunta general ("contame del dorado"): se completa con lo siguiente de
    // la ficha, salvo los datos secundarios.
    if (mejor < 3 && usado < 140) {
      for (final u in unidades) {
        if (elegidas.length >= 3 || usado >= 140) break;
        if (elegidas.contains(u) || _secundarias.contains(u.clave)) continue;
        if (entra(u)) {
          usado += u.texto.length + (elegidas.isEmpty ? 0 : 1);
          elegidas.add(u);
        }
      }
    }

    if (elegidas.isEmpty) {
      final primera = unidades.first;
      elegidas.add(primera.texto.length > presupuesto
          ? _Unidad(_recortar(primera.texto, presupuesto), primera.etiqueta, primera.orden)
          : primera);
    }
    elegidas.sort((a, b) => a.orden.compareTo(b.orden));
    return elegidas.map((u) => _terminar(u.texto)).join(' ');
  }

  // ── Ficha de procedimiento ────────────────────────────────────────────────

  static GuiaPresentacion _presentarProcedimiento(GuiaFicha ficha, _Ficha p, String entrada) {
    final presupuesto = maxProcedimiento - entrada.length - 1;
    final pasos = p.pasos;
    final narracion = _narrar(pasos);

    if (narracion.length <= presupuesto) {
      // Entran todos los pasos. Se suma el contexto (qué es, para qué sirve) y el
      // consejo mientras haya lugar, pero NUNCA a costa de un paso.
      final partes = <String>[];
      var usado = narracion.length;
      for (final u in p.unidades) {
        if (u.etiquetaConsejo) continue;
        final t = _terminar(u.texto);
        if (partes.length >= 3 || usado + t.length + 1 > presupuesto) break;
        partes.add(t);
        usado += t.length + 1;
      }
      for (final u in p.unidades.where((u) => u.etiquetaConsejo)) {
        final t = _terminar(u.texto);
        if (usado + t.length + 1 <= presupuesto) {
          partes.add(t);
          usado += t.length + 1;
          break;
        }
      }
      // Contexto primero, pasos después, consejo al final.
      final contexto = partes.where((t) => !p.unidades.any((u) => u.etiquetaConsejo && _terminar(u.texto) == t)).toList();
      final consejo = partes.where((t) => p.unidades.any((u) => u.etiquetaConsejo && _terminar(u.texto) == t)).toList();
      return GuiaPresentacion(intro: entrada, cuerpo: [...contexto, narracion, ...consejo].join(' '));
    }

    // No entra entero: resumen + oferta de dictado. No se corta ningún paso.
    final base = p.unidades.where((u) => !u.etiquetaConsejo).map((u) => _terminar(u.texto)).firstWhere(
          (t) => t.length <= 200,
          orElse: () => '${_terminar(p.tituloBonito ?? ficha.titulo)}',
        );
    final resumen = '$base Son ${_enPalabras(pasos.length)} pasos. $ofertaDictado';
    return GuiaPresentacion(
      intro: entrada,
      cuerpo: resumen,
      ofreceDictado: true,
      pasos: pasos,
      ingredientes: p.ingredientes,
    );
  }

  /// "Primero, …. Después, …. Por último, …."
  static String _narrar(List<String> pasos) {
    final n = pasos.length;
    const medios = ['Después', 'Luego', 'Y después', 'Ahora'];
    final salida = <String>[];
    for (var i = 0; i < n; i++) {
      final p = _terminar(_minusculaInicial(pasos[i]));
      if (i == 0) {
        salida.add('Primero, $p');
      } else if (i == n - 1) {
        salida.add('Por último, $p');
      } else {
        salida.add('${medios[(i - 1) % medios.length]}, $p');
      }
    }
    return salida.join(' ');
  }

  // ── Lectura de la ficha ───────────────────────────────────────────────────

  static _Ficha _parsear(GuiaFicha ficha) {
    final unidades = <_Unidad>[];
    final pasos = <String>[];
    final ingredientes = <String>[];
    final limpio = StringBuffer();
    String? titulo;
    String seccion = '';
    String? resistencia;
    String? dificultad;
    int posResDif = -1;
    var orden = 0;

    void agregar(String texto, String etiqueta, {String clave = '', bool consejo = false}) {
      final t = texto.trim();
      if (t.isEmpty) return;
      unidades.add(_Unidad(t, etiqueta, orden++, clave: clave, etiquetaConsejo: consejo));
    }

    var primera = true;
    for (final cruda in ficha.texto.split('\n')) {
      final linea = _limpiarLinea(cruda);
      if (linea.isEmpty) continue;
      limpio.write('$linea ');

      if (primera) {
        primera = false;
        if (_esTituloEnMayusculas(linea)) {
          titulo = linea;
          continue;
        }
      }

      final numerado = _itemNumerado.firstMatch(linea);
      if (numerado != null) {
        final t = numerado.group(1)!.trim();
        (seccion.contains('ingrediente') ? ingredientes : pasos).add(t);
        continue;
      }
      final vineta = _vineta.firstMatch(linea);
      if (vineta != null) {
        final t = vineta.group(1)!.trim();
        if (seccion.contains('ingrediente')) {
          ingredientes.add(t);
        } else {
          agregar(t, '');
        }
        continue;
      }
      final enc = _encabezado.firstMatch(linea);
      if (enc != null) {
        seccion = GuiaTextoEs.normalizar(enc.group(1)!);
        continue;
      }
      final campo = _campo.firstMatch(linea);
      if (campo != null) {
        final clave = GuiaTextoEs.normalizar(campo.group(1)!);
        final valor = campo.group(2)!.trim();
        if (clave == 'pasos') {
          pasos.addAll(valor.split(RegExp(r'\.,\s*')).map((x) => x.trim()).where((x) => x.isNotEmpty));
        } else if (clave == 'resistencia') {
          resistencia = valor;
          if (posResDif < 0) posResDif = orden++;
        } else if (clave == 'dificultad') {
          dificultad = valor;
          if (posResDif < 0) posResDif = orden++;
        } else if (_camposTexto.contains(clave)) {
          final consejo = clave.startsWith('consejo') && clave != 'consejo encarne';
          for (final o in _oraciones(valor)) {
            agregar(o, clave, clave: clave, consejo: consejo);
          }
        } else if (_plantillas.containsKey(clave)) {
          final pl = _plantillas[clave]!;
          // "Peligro: ALTO" → "El peligro es alto": el nivel va en minúscula.
          final v = clave == 'peligro' ? _quitarPuntoFinal(valor).toLowerCase() : _valor(valor);
          agregar(pl[0].replaceAll('{v}', v), pl[1], clave: clave);
        }
        // Un campo que no conocemos se deja afuera: no se inventa una frase.
        continue;
      }
      // Prosa suelta.
      for (final o in _oraciones(linea)) {
        agregar(o, '');
      }
    }

    // "Resistencia: ALTA / Dificultad: BAJA" → una sola oración.
    final frase = _fraseResistencia(resistencia, dificultad, ficha.libreria);
    if (frase != null) {
      unidades.add(_Unidad(frase, 'resistencia dificultad facil dificil resistente',
          posResDif >= 0 ? posResDif : orden++,
          clave: 'resistencia'));
    }
    unidades.sort((a, b) => a.orden.compareTo(b.orden));

    final cuerpo = limpio.toString().trim();
    return _Ficha(
      unidades: unidades,
      pasos: pasos.map((x) => x.trim()).toList(),
      ingredientes: ingredientes,
      limpio: cuerpo,
      titulo: titulo,
      tituloBonito: titulo == null ? null : _tituloBonito(titulo, cuerpo),
    );
  }

  static String? _fraseResistencia(String? resistencia, String? dificultad, String libreria) {
    String? res;
    switch (resistencia == null ? '' : GuiaTextoEs.normalizar(resistencia)) {
      case 'alta':
        res = 'muy resistente';
      case 'media':
        res = 'bastante resistente';
      case 'baja':
        res = 'poco resistente';
    }
    String? dif;
    switch (dificultad == null ? '' : GuiaTextoEs.normalizar(dificultad)) {
      case 'baja':
        dif = 'fácil de hacer';
      case 'media':
        dif = 'de dificultad media';
      case 'alta':
        dif = 'difícil de hacer';
    }
    if (res == null && dif == null) return null;
    final sujeto = libreria.startsWith('nudos') ? 'Es un nudo' : 'Es';
    return '$sujeto ${[res, dif].whereType<String>().join(' y ')}.';
  }

  // ── Utilidades de texto ───────────────────────────────────────────────────

  static String _limpiarLinea(String l) => l
      .replaceAll(_emoji, '')
      .replaceAll('**', '')
      .replaceAll('__', '')
      .replaceAll('`', '')
      .replaceFirst(RegExp(r'^\s*#+\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _esTituloEnMayusculas(String linea) {
    final letras = linea.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ]'), '');
    return letras.length >= 4 && letras == letras.toUpperCase() && !linea.contains(':');
  }

  /// "CHUPÍN DE ARMADO TRADICIONAL" → "Chupín de armado tradicional", sin
  /// minusculizar los nombres propios ni las siglas que la ficha escribe con
  /// mayúscula en el cuerpo ("Paraná", "VHF").
  static String _tituloBonito(String titulo, String cuerpo) {
    final propias = RegExp(r'(?<=[a-záéíóúñ,;] )[A-ZÁÉÍÓÚÑ][a-záéíóúñ]+')
        .allMatches(cuerpo)
        .map((m) => GuiaTextoEs.normalizar(m.group(0)!))
        .toSet();
    final palabras = titulo.split(' ');
    final salida = <String>[];
    for (var i = 0; i < palabras.length; i++) {
      final w = palabras[i];
      final n = GuiaTextoEs.normalizar(w);
      if (w.length <= 4 && w == w.toUpperCase() && w.length > 1 && RegExp(r'^[A-ZÁÉÍÓÚÑ]+$').hasMatch(w) && propias.contains(n)) {
        salida.add(w);
      } else if (propias.contains(n)) {
        salida.add(w[0] + w.substring(1).toLowerCase());
      } else {
        salida.add(w.toLowerCase());
      }
    }
    return _mayusculaInicial(salida.join(' '));
  }

  static List<String> _oraciones(String parrafo) => parrafo
      .split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ¿¡"“])'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();

  /// El valor de un campo listo para meterlo en una plantilla.
  static String _valor(String v) => _minusculaInicial(_quitarPuntoFinal(v.trim()));

  static String _quitarPuntoFinal(String s) => s.trim().replaceFirst(RegExp(r'[.\s]+$'), '');

  static String _terminar(String s) {
    final t = s.trim();
    if (t.isEmpty) return t;
    if (RegExp(r'[.!?…)"”]$').hasMatch(t)) return t;
    return t.endsWith(':') || t.endsWith(',') || t.endsWith(';') ? '${t.substring(0, t.length - 1)}.' : '$t.';
  }

  /// Primera letra en minúscula, salvo siglas y advertencias en mayúsculas
  /// ("NUNCA", "VHF") o números.
  static String _minusculaInicial(String s) {
    if (s.length < 2) return s;
    final a = s[0];
    final b = s[1];
    if (a != a.toLowerCase() && b == b.toLowerCase() && b != b.toUpperCase()) {
      return a.toLowerCase() + s.substring(1);
    }
    return s;
  }

  static String _mayusculaInicial(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _recortar(String s, int max) {
    if (s.length <= max) return s;
    final corte = s.substring(0, max);
    final coma = [corte.lastIndexOf(','), corte.lastIndexOf(';')].reduce((a, b) => a > b ? a : b);
    if (coma > max * 0.5) return '${corte.substring(0, coma).trim()}.';
    final espacio = corte.lastIndexOf(' ');
    return '${corte.substring(0, espacio > 0 ? espacio : max).trim()}…';
  }

  static String _enPalabras(int n) {
    const p = {
      2: 'dos', 3: 'tres', 4: 'cuatro', 5: 'cinco', 6: 'seis', 7: 'siete', 8: 'ocho', 9: 'nueve',
      10: 'diez', 11: 'once', 12: 'doce', 13: 'trece', 14: 'catorce', 15: 'quince', 16: 'dieciséis',
      17: 'diecisiete', 18: 'dieciocho', 19: 'diecinueve', 20: 'veinte',
    };
    return p[n] ?? 'varios';
  }
}

class _Unidad {
  final String texto;

  /// Palabras con las que se puede preguntar por esta oración (su campo).
  final String etiqueta;
  final int orden;
  final String clave;
  final bool etiquetaConsejo;

  const _Unidad(this.texto, this.etiqueta, this.orden, {this.clave = '', this.etiquetaConsejo = false});
}

class _Ficha {
  final List<_Unidad> unidades;
  final List<String> pasos;
  final List<String> ingredientes;
  final String limpio;
  final String? titulo;
  final String? tituloBonito;

  const _Ficha({
    required this.unidades,
    required this.pasos,
    required this.ingredientes,
    required this.limpio,
    required this.titulo,
    required this.tituloBonito,
  });
}
