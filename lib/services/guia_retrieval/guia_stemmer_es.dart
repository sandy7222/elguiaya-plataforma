/// Stemmer Snowball para español (port del algoritmo oficial, misma
/// estructura que `nltk.stem.snowball.SpanishStemmer`).
///
/// Se usa sobre palabras YA normalizadas por [GuiaTextoEs.normalizar]
/// (minúsculas, sin acentos), por eso los sufijos acentuados casi nunca
/// matchean: eso es intencional y es exactamente lo que hace el
/// prototipo Python (`mini_model_lab/retrieval/texto_es.py`), que aplica
/// `snowballstemmer` después de sacar acentos. La paridad se verifica en
/// `test/guia_retrieval_test.dart` contra `stems_esperados.json`.
class GuiaStemmerEs {
  static const String _vocales = 'aeiouáéíóúü';

  static const List<String> _paso0 = [
    'selas', 'selos', 'sela', 'selo', 'las', 'les', 'los', 'nos', 'me', 'se',
    'la', 'le', 'lo',
  ];

  static const List<String> _paso1 = [
    'amientos', 'imientos', 'amiento', 'imiento', 'aciones', 'uciones',
    'adoras', 'adores', 'ancias', 'logías', 'encias', 'amente', 'idades',
    'anzas', 'ismos', 'ables', 'ibles', 'istas', 'adora', 'ación', 'acion',
    'antes', 'ancia', 'logía', 'ución', 'ucion', 'encia', 'mente', 'anza',
    'icos', 'icas',
    'ismo', 'able', 'ible', 'ista', 'osos', 'osas', 'ador', 'ante', 'idad',
    'ivas', 'ivos', 'ico', 'ica', 'oso', 'osa', 'iva', 'ivo',
  ];

  static const List<String> _paso2a = [
    'yeron', 'yendo', 'yamos', 'yais', 'yan', 'yen', 'yas', 'yes', 'ya',
    'ye', 'yo', 'yó',
  ];

  static const List<String> _paso2b = [
    'aríamos', 'eríamos', 'iríamos', 'iéramos', 'iésemos', 'aríais',
    'aremos', 'eríais', 'eremos', 'iríais', 'iremos', 'ierais', 'ieseis',
    'asteis', 'isteis', 'ábamos', 'áramos', 'ásemos', 'arían', 'arías',
    'aréis', 'erían', 'erías', 'eréis', 'irían', 'irías', 'iréis', 'ieran',
    'iesen', 'ieron', 'iendo', 'ieras', 'ieses', 'abais', 'arais', 'aseis',
    'éamos', 'arán', 'arás', 'aría', 'erán', 'erás', 'ería', 'irán', 'irás',
    'iría', 'iera', 'iese', 'aste', 'iste', 'aban', 'aran', 'asen', 'aron',
    'ando', 'abas', 'adas', 'idas', 'aras', 'ases', 'íais', 'ados', 'idos',
    'amos', 'imos', 'emos', 'ará', 'aré', 'erá', 'eré', 'irá', 'iré', 'aba',
    'ada', 'ida', 'ara', 'ase', 'ían', 'ado', 'ido', 'ías', 'áis', 'éis',
    'ía', 'ad', 'ed', 'id', 'an', 'ió', 'ar', 'er', 'ir', 'as', 'ís', 'en',
    'es',
  ];

  static const List<String> _paso3 = ['os', 'a', 'e', 'o', 'á', 'é', 'í', 'ó'];

  static bool _esVocal(String c) => _vocales.contains(c);

  static String _sinFinal(String s, int n) =>
      n >= s.length ? '' : s.substring(0, s.length - n);

  static String _sinAcentos(String w) => w
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  static bool _terminaEnAlguno(String s, List<String> sufijos) {
    for (final suf in sufijos) {
      if (s.endsWith(suf)) return true;
    }
    return false;
  }

  /// R1 y R2 estándar de Snowball.
  static List<String> _r1r2(String word) {
    var r1 = '';
    var r2 = '';
    for (var i = 1; i < word.length; i++) {
      if (!_esVocal(word[i]) && _esVocal(word[i - 1])) {
        r1 = word.substring(i + 1);
        break;
      }
    }
    for (var i = 1; i < r1.length; i++) {
      if (!_esVocal(r1[i]) && _esVocal(r1[i - 1])) {
        r2 = r1.substring(i + 1);
        break;
      }
    }
    return [r1, r2];
  }

  /// RV estándar de Snowball.
  static String _rv(String word) {
    var rv = '';
    if (word.length >= 2) {
      if (!_esVocal(word[1])) {
        for (var i = 2; i < word.length; i++) {
          if (_esVocal(word[i])) {
            rv = word.substring(i + 1);
            break;
          }
        }
      } else if (_esVocal(word[0]) && _esVocal(word[1])) {
        for (var i = 2; i < word.length; i++) {
          if (!_esVocal(word[i])) {
            rv = word.substring(i + 1);
            break;
          }
        }
      } else {
        // consonante-vocal: RV es la región después de la tercera letra
        rv = word.length > 3 ? word.substring(3) : '';
      }
    }
    return rv;
  }

  static String stem(String palabra) {
    var word = palabra.toLowerCase();
    if (word.isEmpty) return word;
    var paso1Ok = false;
    final r = _r1r2(word);
    var r1 = r[0];
    var r2 = r[1];
    var rv = _rv(word);

    // Paso 0: pronombre enclítico
    for (final suf in _paso0) {
      if (!(word.endsWith(suf) && rv.endsWith(suf))) continue;
      final rvBase = _sinFinal(rv, suf.length);
      final wordBase = _sinFinal(word, suf.length);
      final terminaVerbal = _terminaEnAlguno(rvBase, const [
        'ando', 'ándo', 'ar', 'ár', 'er', 'ér', 'iendo', 'iéndo', 'ir', 'ír',
      ]);
      if (terminaVerbal ||
          (rvBase.endsWith('yendo') && wordBase.endsWith('uyendo'))) {
        word = _sinAcentos(wordBase);
        r1 = _sinAcentos(_sinFinal(r1, suf.length));
        r2 = _sinAcentos(_sinFinal(r2, suf.length));
        rv = _sinAcentos(rvBase);
      }
      break;
    }

    // Paso 1: sufijos estándar
    for (final suf in _paso1) {
      if (!word.endsWith(suf)) continue;
      if (suf == 'amente' && r1.endsWith(suf)) {
        paso1Ok = true;
        word = _sinFinal(word, 6);
        r2 = _sinFinal(r2, 6);
        rv = _sinFinal(rv, 6);
        if (r2.endsWith('iv')) {
          word = _sinFinal(word, 2);
          r2 = _sinFinal(r2, 2);
          rv = _sinFinal(rv, 2);
          if (r2.endsWith('at')) {
            word = _sinFinal(word, 2);
            rv = _sinFinal(rv, 2);
          }
        } else if (_terminaEnAlguno(r2, const ['os', 'ic', 'ad'])) {
          word = _sinFinal(word, 2);
          rv = _sinFinal(rv, 2);
        }
      } else if (r2.endsWith(suf)) {
        paso1Ok = true;
        // Snowball 3.x también acepta las formas sin tilde (acion, ucion),
        // que es justo lo que llega después de normalizar.
        const grupoAdor = [
          'adora', 'ador', 'ación', 'acion', 'adoras', 'adores', 'aciones',
          'ante', 'antes', 'ancia', 'ancias',
        ];
        if (grupoAdor.contains(suf)) {
          word = _sinFinal(word, suf.length);
          r2 = _sinFinal(r2, suf.length);
          rv = _sinFinal(rv, suf.length);
          if (r2.endsWith('ic')) {
            word = _sinFinal(word, 2);
            rv = _sinFinal(rv, 2);
          }
        } else if (suf == 'logía' || suf == 'logías') {
          word = '${_sinFinal(word, suf.length)}log';
          rv = '${_sinFinal(rv, suf.length)}log';
        } else if (suf == 'ución' || suf == 'ucion' || suf == 'uciones') {
          word = '${_sinFinal(word, suf.length)}u';
          rv = '${_sinFinal(rv, suf.length)}u';
        } else if (suf == 'encia' || suf == 'encias') {
          word = '${_sinFinal(word, suf.length)}ente';
          rv = '${_sinFinal(rv, suf.length)}ente';
        } else if (suf == 'mente') {
          word = _sinFinal(word, 5);
          r2 = _sinFinal(r2, 5);
          rv = _sinFinal(rv, 5);
          if (_terminaEnAlguno(r2, const ['ante', 'able', 'ible'])) {
            word = _sinFinal(word, 4);
            rv = _sinFinal(rv, 4);
          }
        } else if (suf == 'idad' || suf == 'idades') {
          word = _sinFinal(word, suf.length);
          r2 = _sinFinal(r2, suf.length);
          rv = _sinFinal(rv, suf.length);
          for (final pre in const ['abil', 'ic', 'iv']) {
            if (r2.endsWith(pre)) {
              word = _sinFinal(word, pre.length);
              rv = _sinFinal(rv, pre.length);
            }
          }
        } else if (const ['ivo', 'iva', 'ivos', 'ivas'].contains(suf)) {
          word = _sinFinal(word, suf.length);
          r2 = _sinFinal(r2, suf.length);
          rv = _sinFinal(rv, suf.length);
          if (r2.endsWith('at')) {
            word = _sinFinal(word, 2);
            rv = _sinFinal(rv, 2);
          }
        } else {
          word = _sinFinal(word, suf.length);
          rv = _sinFinal(rv, suf.length);
        }
      }
      break;
    }

    // Paso 2a y 2b: sufijos verbales
    if (!paso1Ok) {
      for (final suf in _paso2a) {
        if (rv.endsWith(suf) &&
            word.length > suf.length &&
            word[word.length - suf.length - 1] == 'u') {
          word = _sinFinal(word, suf.length);
          rv = _sinFinal(rv, suf.length);
          break;
        }
      }
      for (final suf in _paso2b) {
        if (rv.endsWith(suf)) {
          word = _sinFinal(word, suf.length);
          rv = _sinFinal(rv, suf.length);
          if (const ['en', 'es', 'éis', 'emos'].contains(suf)) {
            if (word.endsWith('gu')) word = _sinFinal(word, 1);
            if (rv.endsWith('gu')) rv = _sinFinal(rv, 1);
          }
          break;
        }
      }
    }

    // Paso 3: sufijo residual
    for (final suf in _paso3) {
      if (rv.endsWith(suf)) {
        word = _sinFinal(word, suf.length);
        if (suf == 'e' || suf == 'é') {
          rv = _sinFinal(rv, suf.length);
          if (word.endsWith('gu') && rv.endsWith('u')) {
            word = _sinFinal(word, 1);
          }
        }
        break;
      }
    }

    return _sinAcentos(word);
  }
}
