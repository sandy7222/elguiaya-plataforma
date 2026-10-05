import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

/// Prepara un texto para que el celular lo DIGA (paso 1.2b, flag `guia_voz_limpia`).
///
/// Es la única función de este tipo: la usan `VoiceService`, `AudioService` y
/// `VozService`, y vale también para las respuestas de la nube. Lo que se MUESTRA en
/// pantalla lo limpia el presentador de fichas; esto es solo para lo que se dice.
///
/// Los motores de voz borran o deletrean lo que no es una palabra: "50 %" se leía
/// "cincuenta", "18 °C" "dieciocho ce", "12 km/h" "doce kmh", "$15.000" "pesos quince
/// mil", "1." "uno punto", y un título en MAYÚSCULAS a veces se deletrea. Acá los
/// símbolos se TRADUCEN a palabras, se sacan emojis, comillas, markdown, viñetas y
/// numeración, y los títulos en mayúsculas pasan a minúsculas (salvo siglas
/// conocidas). Nunca se pierde un número.
class GuiaTextoVoz {
  static const String prefVozLimpia = 'guia_voz_limpia';
  static bool habilitado = true;

  static void aplicarFlags(SharedPreferences prefs) {
    habilitado = prefs.getBool(prefVozLimpia) ?? habilitado;
  }

  /// Siglas que se conservan en mayúsculas. Cómo se pronuncian ("ve hache efe") es
  /// asunto del léxico de pronunciación (paso 1.2c).
  static const Set<String> siglasConocidas = {
    'VHF', 'GPS', 'SMN', 'PNA', 'SOS', 'DNI', 'CBU', 'IVA', 'UV', 'AIS', 'DSC', 'RCP', 'EPIRB', 'IA', 'ABS',
  };

  // Unidad → (singular, plural). Las de una letra solo valen en minúscula.
  static const Map<String, (String, String)> _unidades = {
    'km': ('kilómetro', 'kilómetros'),
    'cm': ('centímetro', 'centímetros'),
    'mm': ('milímetro', 'milímetros'),
    'm': ('metro', 'metros'),
    'kg': ('kilo', 'kilos'),
    'kgs': ('kilo', 'kilos'),
    'gr': ('gramo', 'gramos'),
    'grs': ('gramo', 'gramos'),
    'g': ('gramo', 'gramos'),
    'lb': ('libra', 'libras'),
    'lbs': ('libra', 'libras'),
    'min': ('minuto', 'minutos'),
    'seg': ('segundo', 'segundos'),
    'hs': ('hora', 'horas'),
    'h': ('hora', 'horas'),
    'lt': ('litro', 'litros'),
    'lts': ('litro', 'litros'),
    'l': ('litro', 'litros'),
  };

  static const String _num = r'\d+(?:[.,]\d+)?';

  static String _plural(String numero, (String, String) palabras) => numero == '1' ? palabras.$1 : palabras.$2;

  // ── Léxico de pronunciación (paso 1.2c, parte 2) ──────────────────────────
  // assets/elguia/voz/pronunciacion.json, editable por el dueño: cómo se DICEN las
  // siglas, las palabras en inglés del equipo de pesca y los nombres difíciles. Solo
  // afecta a lo que se dice; en pantalla el texto no cambia.
  static const String _rutaLexico = 'assets/elguia/voz/pronunciacion.json';
  static final Map<String, String> _siglas = {};
  static final Map<String, String> _palabras = {}; // claves en minúscula
  static RegExp? _reSiglas;
  static RegExp? _rePalabras;

  static void limpiarLexico() {
    _siglas.clear();
    _palabras.clear();
    _reSiglas = null;
    _rePalabras = null;
  }

  /// Carga el léxico desde su JSON ({"siglas": {...}, "palabras": {...}}). Las entradas
  /// mal formadas (clave vacía, "decir" vacío o que no es texto) se saltean; si todo el
  /// archivo está mal, el texto sale como siempre.
  static void cargarLexico(Map<String, dynamic> json) {
    limpiarLexico();
    void leerGrupo(Object? grupo, void Function(String, String) guardar) {
      if (grupo is! Map) return;
      grupo.forEach((k, v) {
        if (k is String && k.trim().isNotEmpty && v is String && v.trim().isNotEmpty) guardar(k.trim(), v.trim());
      });
    }

    leerGrupo(json['siglas'], (k, v) => _siglas[k] = v);
    leerGrupo(json['palabras'], (k, v) => _palabras[k.toLowerCase()] = v);

    String alternativas(Iterable<String> claves) {
      final ordenadas = claves.toList()..sort((a, b) => b.length.compareTo(a.length));
      return ordenadas.map(RegExp.escape).join('|');
    }

    const borde = r'(?<![\p{L}\p{N}])';
    const bordeFin = r'(?![\p{L}\p{N}])';
    if (_siglas.isNotEmpty) _reSiglas = RegExp('$borde(${alternativas(_siglas.keys)})$bordeFin', unicode: true);
    if (_palabras.isNotEmpty) {
      _rePalabras = RegExp('$borde(${alternativas(_palabras.keys)})$bordeFin', unicode: true, caseSensitive: false);
    }
  }

  /// Carga el léxico que viene en la app. Si falta o está roto, no pasa nada.
  static Future<void> cargarLexicoDeAssets() async {
    try {
      final texto = await rootBundle.loadString(_rutaLexico);
      final j = jsonDecode(texto);
      if (j is Map<String, dynamic>) cargarLexico(j);
    } catch (_) {}
  }

  static String _aplicarLexico(String t) {
    final siglas = _reSiglas;
    if (siglas != null) t = t.replaceAllMapped(siglas, (m) => _siglas[m[1]] ?? m[0]!);
    final palabras = _rePalabras;
    if (palabras != null) {
      t = t.replaceAllMapped(palabras, (m) {
        final decir = _palabras[m[1]!.toLowerCase()];
        if (decir == null) return m[0]!;
        // "Spinning" al empezar una frase → "Espínin".
        final inicial = m[1]![0];
        final esMayuscula = inicial != inicial.toLowerCase();
        final decirEnMinuscula = decir[0] == decir[0].toLowerCase();
        return esMayuscula && decirEnMinuscula ? decir[0].toUpperCase() + decir.substring(1) : decir;
      });
    }
    return t;
  }

  static String preparar(String texto) {
    if (!habilitado || texto.isEmpty) return texto;
    var t = texto;

    t = t.replaceAll(RegExp(r'Gu-IA', caseSensitive: false), 'el Guía');

    // ── Pies y pulgadas: 6'6" no puede quedar "66" cuando se sacan las comillas ─
    t = t.replaceAllMapped(
      RegExp('(\\d+)[\'’](\\d+)?["”]?(?:\\s+pies\\b)?'),
      (m) => m[2] == null ? '${m[1]} pies' : '${m[1]} pies ${m[2]} pulgadas',
    );
    t = t.replaceAllMapped(RegExp('(\\d+)["”]'), (m) => '${m[1]} pulgadas');
    // "#4" es "número 4" (líneas de mosca); el # de los títulos se saca más abajo.
    t = t.replaceAllMapped(RegExp(r'#(\d)'), (m) => 'número ${m[1]}');

    // ── Estructura: viñetas, numeración y títulos de markdown ────────────────
    t = t.replaceAll(RegExp(r'(^|\n)[ \t]*(?:\d+[.)]|[-•·▪●*])[ \t]+'), '\n');
    t = t.replaceAll(RegExp(r'(^|\n)[ \t]*#+[ \t]*'), '\n');
    t = t.replaceAll(RegExp(r'[*_`~#]'), '');

    // ── Números y unidades: se traducen, no se borran ────────────────────────
    // Decimal con punto → coma (un millar, "15.000", no se toca).
    t = t.replaceAllMapped(RegExp(r'(\d)\.(\d{1,2})(?!\d)'), (m) => '${m[1]},${m[2]}');
    t = t.replaceAllMapped(
      RegExp(r'\$\s?(\d[\d.,]*)'),
      (m) => '${m[1]} ${m[1] == '1' ? 'peso' : 'pesos'}',
    );
    // Rangos antes de una unidad: "10-15 cm" → "10 a 15 cm".
    t = t.replaceAllMapped(
      RegExp('($_num)\\s?[-–]\\s?($_num)(?=\\s?(?:cm|mm|km|kg|gr|lbs?|min|hs?|m|%|°))'),
      (m) => '${m[1]} a ${m[2]}',
    );
    t = t.replaceAllMapped(RegExp(r'\b1/2\s?kg\b'), (_) => 'medio kilo');
    t = t.replaceAllMapped(RegExp(r'\b1/2\s?m\b'), (_) => 'medio metro');
    // "1/2 taza" → "media taza", "1/2 pimiento" → "medio pimiento".
    t = t.replaceAllMapped(
      RegExp(r'\b1/2\b(\s+\p{L}+)?', unicode: true),
      (m) => '${RegExp(r'a$').hasMatch((m[1] ?? '').trim()) ? 'media' : 'medio'}${m[1] ?? ''}',
    );
    t = t.replaceAllMapped(RegExp(r'\b(\d+)/(\d+)\b'), (m) => '${m[1]} sobre ${m[2]}');
    t = t.replaceAllMapped(RegExp(r'(\d)\s?km\s?/\s?h\b', caseSensitive: false), (m) => '${m[1]} kilómetros por hora');
    t = t.replaceAll(RegExp(r'\bkm\s?/\s?h\b', caseSensitive: false), 'kilómetros por hora');
    t = t.replaceAllMapped(RegExp(r'(\d)\s?m\s?/\s?s\b'), (m) => '${m[1]} metros por segundo');
    t = t.replaceAllMapped(RegExp('($_num)\\s?[°º]\\s?[Ff]\\b'), (m) => '${m[1]} grados Fahrenheit');
    t = t.replaceAllMapped(
      RegExp('($_num)\\s?[°º]\\s?[Cc]?'),
      (m) => '${m[1]} ${m[1] == '1' ? 'grado' : 'grados'}',
    );
    t = t.replaceAll(RegExp(r'\s?%'), ' por ciento');
    t = t.replaceAllMapped(RegExp(r'(\d{1,2}:\d{2})\s?hs?\b'), (m) => '${m[1]} horas');
    t = t.replaceAllMapped(
      RegExp('($_num)\\s?(kgs?|grs?|lbs?|km|cm|mm|min|seg|hs?|lts?|m|g|l)(?![\\p{L}\\p{N}/])', unicode: true),
      (m) {
        final unidad = _unidades[m[2]!];
        return unidad == null ? m[0]! : '${m[1]} ${_plural(m[1]!, unidad)}';
      },
    );

    // ── Símbolos sueltos ─────────────────────────────────────────────────────
    t = t.replaceAll(RegExp(r'\s*[—–]\s*'), ', ');
    t = t.replaceAll(RegExp(r'\s-\s'), ', ');
    t = t.replaceAll('&', ' y ');
    t = t.replaceAll('+', ' más ');
    t = t.replaceAll('=', ' igual a ');
    t = t.replaceAll(RegExp(r'\by\s?/\s?o\b', caseSensitive: false), 'y o');
    t = t.replaceAll('/', ' ');
    t = t.replaceAll('…', '...');
    // Comillas rectas y curvas, apóstrofes y corchetes: no se dicen.
    t = t.replaceAll(RegExp('["\'“”‘’«»\\[\\]{}<>|]'), '');
    // Emojis y todo lo que no sea letra, número, espacio o puntuación básica.
    t = t.replaceAll(RegExp(r'[^\p{L}\p{N}\s.,;:!?()¡¿\-]', unicode: true), '');

    // ── Saltos de línea → pausa ──────────────────────────────────────────────
    t = t.replaceAllMapped(RegExp(r'([^\n]?)[ \t]*\n[\s]*'), (m) {
      final antes = m[1] ?? '';
      if (antes.isEmpty) return ' ';
      return '$antes${'.,;:!?'.contains(antes) ? '' : '.'} ';
    });

    // ── Mayúsculas: los títulos pasan a minúsculas, las siglas se conservan ──
    t = t.replaceAllMapped(
      RegExp(r'(?<![\p{L}\p{N}])[A-ZÁÉÍÓÚÑÜ]{2,}(?![\p{L}\p{N}])', unicode: true),
      (m) => siglasConocidas.contains(m[0]) ? m[0]! : m[0]!.toLowerCase(),
    );

    // ── Espacios y puntuación ────────────────────────────────────────────────
    t = t.replaceAll(RegExp(r'\s+'), ' ');
    t = t.replaceAllMapped(RegExp(r'\s+([.,;:!?])'), (m) => m[1]!);
    t = t.replaceAll(RegExp(r',(\s*,)+'), ',');
    return _aplicarLexico(t.trim());
  }
}
