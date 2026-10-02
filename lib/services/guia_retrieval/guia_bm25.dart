import 'dart:math' as math;

import 'guia_ficha.dart';
import 'guia_texto_es.dart';

/// BM25 sobre las fichas, con puntaje NORMALIZADO a [0, 1).
///
/// Espejo de `BuscadorLexico` en `mini_model_lab/retrieval/evaluar_retrieval.py`:
///  - documento = título ×2 + preguntas ×3 + texto + keywords (tokens de
///    [GuiaTextoEs.tokenizar]);
///  - idf = ln(1 + (N - n + 0.5) / (n + 0.5)), k1 = 1.5, b = 0.75;
///  - el puntaje se divide por la cota superior teórica de la consulta
///    (Σ idf(t) · (k1 + 1)), así "1.0" significa "todos los términos de la
///    consulta aparecen saturados" y el umbral es comparable entre consultas.
class GuiaBm25 {
  static const double k1 = 1.5;
  static const double b = 0.75;
  static const int pesoPreguntas = 3;
  static const int pesoTitulo = 2;

  final List<GuiaFicha> fichas;
  final List<Map<String, int>> _docs = [];
  final Map<String, int> _df = {};
  final List<int> _longitudes = [];

  /// Tokens de título + preguntas de cada ficha: de qué "trata".
  final List<Set<String>> _tokensClave = [];
  late final double _avgdl;

  int get n => fichas.length;

  GuiaBm25(this.fichas) {
    for (final f in fichas) {
      final tokens = <String>[];
      final tTitulo = GuiaTextoEs.tokenizar(f.titulo);
      for (var i = 0; i < pesoTitulo; i++) {
        tokens.addAll(tTitulo);
      }
      for (final p in f.preguntas) {
        final tp = GuiaTextoEs.tokenizar(p);
        for (var i = 0; i < pesoPreguntas; i++) {
          tokens.addAll(tp);
        }
      }
      _tokensClave.add(tokens.toSet());
      tokens.addAll(GuiaTextoEs.tokenizar(f.texto));
      for (final k in f.keywords) {
        tokens.addAll(GuiaTextoEs.tokenizar(k));
      }
      final c = <String, int>{};
      for (final t in tokens) {
        c[t] = (c[t] ?? 0) + 1;
      }
      _docs.add(c);
      for (final t in c.keys) {
        _df[t] = (_df[t] ?? 0) + 1;
      }
      _longitudes.add(tokens.length);
    }
    final total = _longitudes.fold<int>(0, (a, b) => a + b);
    _avgdl = n == 0 ? 1 : total / n;
  }

  double idf(String t) {
    final df = _df[t] ?? 0;
    return math.log(1 + (n - df + 0.5) / (df + 0.5));
  }

  /// Puntaje normalizado por ficha (misma posición que [fichas]).
  List<double> puntuar(String consulta) {
    final scores = List<double>.filled(n, 0.0);
    final q = GuiaTextoEs.tokenizar(consulta);
    if (q.isEmpty || n == 0) return scores;
    final qc = <String, int>{};
    for (final t in q) {
      qc[t] = (qc[t] ?? 0) + 1;
    }
    var maximo = 0.0;
    final idfs = <String, double>{};
    for (final t in qc.keys) {
      final v = idf(t);
      idfs[t] = v;
      maximo += v * (k1 + 1);
    }
    if (maximo <= 0) return scores;
    for (var i = 0; i < n; i++) {
      final doc = _docs[i];
      final dl = _longitudes[i];
      var s = 0.0;
      for (final t in qc.keys) {
        final tf = doc[t] ?? 0;
        if (tf == 0) continue;
        s += idfs[t]! * tf * (k1 + 1) / (tf + k1 * (1 - b + b * dl / _avgdl));
      }
      scores[i] = s / maximo;
    }
    return scores;
  }

  /// Para consultas cortas (1-2 tokens) el BM25 normalizado satura y el
  /// puntaje solo no alcanza para decidir. Devuelve:
  ///  - `tokens`: cantidad de tokens distintos de la consulta;
  ///  - `cobertura`: fracción de esos tokens que está en título/preguntas de
  ///    la ficha [i];
  ///  - `ambiguedad`: cantidad de LIBRERÍAS distintas con alguna ficha cuyo
  ///    título/preguntas contienen TODOS los tokens de la consulta
  ///    ("parana" → 8, "palomar" → 1).
  /// Espejo de `BuscadorLexico.cobertura` en evaluar_retrieval.py.
  ({int tokens, double cobertura, int ambiguedad}) cobertura(String consulta, int i) {
    final q = GuiaTextoEs.tokenizar(consulta).toSet();
    if (q.isEmpty || i < 0 || i >= n) return (tokens: 0, cobertura: 0.0, ambiguedad: 0);
    final libs = <String>{};
    for (var j = 0; j < n; j++) {
      if (_tokensClave[j].containsAll(q)) libs.add(fichas[j].libreria);
    }
    final enClave = q.where(_tokensClave[i].contains).length;
    return (tokens: q.length, cobertura: enClave / q.length, ambiguedad: libs.length);
  }
}
