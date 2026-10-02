import 'guia_stemmer_es.dart';

/// Normalización y tokenización en español para la búsqueda léxica.
///
/// Espejo exacto de `mini_model_lab/retrieval/texto_es.py`: mismo
/// pipeline, misma lista de stopwords, mismo stemmer. Si se cambia algo
/// acá hay que cambiarlo allá (y re-correr `evaluar_retrieval.py` para
/// recalibrar umbrales).
///
/// Pipeline: minúsculas → sin acentos (ñ → n) → solo [a-z0-9] → split →
/// sin stopwords → sin tokens de 1 letra → stem Snowball español.
class GuiaTextoEs {
  static const Set<String> stopwords = {
    'a', 'al', 'algo', 'alguna', 'algunas', 'alguno', 'algunos', 'ante',
    'como', 'con', 'contra', 'cual', 'cuales', 'cuando', 'de', 'del',
    'desde', 'donde', 'dos', 'e', 'el', 'ella', 'ellas', 'ellos', 'en',
    'entre', 'era', 'es', 'esa', 'esas', 'ese', 'eso', 'esos', 'esta',
    'estas', 'este', 'esto', 'estos', 'fue', 'ha', 'hace', 'hacer',
    'hago', 'hay', 'la', 'las', 'le', 'les', 'lo', 'los', 'mas', 'me',
    'mi', 'mis', 'mucho', 'muy', 'nada', 'ni', 'no', 'nos', 'o', 'os',
    'otra', 'otro', 'para', 'pero', 'poco', 'por', 'porque', 'puede',
    'puedo', 'que', 'quien', 'se', 'sea', 'ser', 'si', 'sin', 'sobre',
    'son', 'soy', 'su', 'sus', 'tal', 'tambien', 'te', 'tengo', 'ti',
    'tiene', 'toda', 'todas', 'todo', 'todos', 'tu', 'tus', 'un', 'una',
    'unas', 'uno', 'unos', 'usa', 'usar', 'uso', 'vos', 'y', 'ya', 'yo',
    'sabes', 'conoces', 'decime', 'contame', 'explicame', 'quiero',
    'querria', 'podes', 'podrias', 'sirve', 'sirven', 'conviene', 'mejor',
    'forma', 'manera', 'correcta', 'seria', 'che', 'chamigo',
  };

  static const Map<String, String> _acentos = {
    'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
    'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
    'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
    'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
    'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
    'ñ': 'n', 'ç': 'c',
  };

  static final RegExp _noAlfanumerico = RegExp(r'[^a-z0-9]+');
  static final RegExp _espacios = RegExp(r'\s+');

  /// Minúsculas, sin acentos, solo letras/números separados por un espacio.
  static String normalizar(String texto) {
    final sb = StringBuffer();
    for (final rune in texto.toLowerCase().runes) {
      final c = String.fromCharCode(rune);
      sb.write(_acentos[c] ?? c);
    }
    return sb
        .toString()
        .replaceAll(_noAlfanumerico, ' ')
        .replaceAll(_espacios, ' ')
        .trim();
  }

  /// Tokens stemmeados, sin stopwords ni tokens de una letra.
  static List<String> tokenizar(String texto) {
    final norm = normalizar(texto);
    if (norm.isEmpty) return const [];
    final salida = <String>[];
    for (final p in norm.split(' ')) {
      if (p.length <= 1 || stopwords.contains(p)) continue;
      salida.add(GuiaStemmerEs.stem(p));
    }
    return salida;
  }

  /// Expansión de sinónimos del lado de la consulta.
  ///
  /// [sinonimos] es el mapa que ya carga `ElGuiaEngine` desde
  /// `sinonimos_*.json` (canónico → variantes). Si la consulta contiene una
  /// variante, se agrega el canónico al texto para que el BM25 lo vea.
  /// No se usa en la calibración de Python; por eso es opcional y se aplica
  /// solo cuando el motor pasa el mapa.
  static String expandirSinonimos(String consulta, Map<String, List<String>> sinonimos) {
    if (sinonimos.isEmpty) return consulta;
    final norm = ' ${normalizar(consulta)} ';
    final extras = <String>[];
    sinonimos.forEach((canonico, variantes) {
      for (final v in variantes) {
        final vn = normalizar(v);
        if (vn.isNotEmpty && norm.contains(' $vn ')) {
          extras.add(canonico);
          break;
        }
      }
    });
    if (extras.isEmpty) return consulta;
    return '$consulta ${extras.join(' ')}';
  }
}
