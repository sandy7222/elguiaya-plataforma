import 'guia_bm25.dart';
import 'guia_ficha.dart';
import 'guia_texto_es.dart';

/// Qué hacer con el resultado de una búsqueda.
enum GuiaDecision {
  /// Puntaje alto y margen suficiente: mostrar la ficha tal cual.
  directa,

  /// Está en dominio pero es ambiguo: ofrecer "¿te referís a A, B o C?".
  aclarar,

  /// Fuera de dominio: seguir con el motor de reglas / fallback.
  ninguna,
}

class GuiaCandidato {
  final GuiaFicha ficha;
  final double puntaje;
  final double puntajeLexico;
  final double? puntajeSemantico;
  const GuiaCandidato(this.ficha, this.puntaje, this.puntajeLexico, this.puntajeSemantico);
}

class GuiaResultadoBusqueda {
  final String consulta;
  final GuiaDecision decision;

  /// Mejores candidatos, una sola ficha por librería, orden descendente.
  final List<GuiaCandidato> candidatos;
  final double s1;
  final double s2;
  final bool usoSemantico;
  final Duration duracion;

  const GuiaResultadoBusqueda({
    required this.consulta,
    required this.decision,
    required this.candidatos,
    required this.s1,
    required this.s2,
    required this.usoSemantico,
    required this.duracion,
  });

  GuiaFicha? get mejor => candidatos.isEmpty ? null : candidatos.first.ficha;
  double get margen => s1 - s2;

  /// Resumen compacto para el log: "libreria:0.87 | otra:0.41 | ..."
  String get resumenTop3 => candidatos
      .take(3)
      .map((c) => '${c.ficha.libreria}:${c.puntaje.toStringAsFixed(2)}')
      .join(' | ');
}

/// Umbrales calibrados en `mini_model_lab/retrieval/evaluar_retrieval.py`
/// (ver `resultado_evaluacion.json`). Dos juegos: solo léxico (antes de
/// que el celular tenga el modelo de embeddings) e híbrido.
class GuiaUmbrales {
  final double tAlto;
  final double tBajo;
  final double margen;
  const GuiaUmbrales({required this.tAlto, required this.tBajo, required this.margen});

  /// BM25 solo: validación 71 → 50 directas correctas, 0 incorrectas,
  /// 21 "¿te referís a...?", 0 al motor de reglas; 2/50 OOD aceptadas.
  static const lexico = GuiaUmbrales(tAlto: 0.42, tBajo: 0.18, margen: 0.03);

  /// 0.2·BM25 + 0.8·coseno(e5) re-escalado: validación 71 → 64 directas
  /// correctas, 0 incorrectas, 7 aclaraciones; 1/50 OOD aceptada.
  static const hibrido = GuiaUmbrales(tAlto: 0.60, tBajo: 0.54, margen: 0.01);

  /// Regla para consultas cortas (ver [GuiaBm25.cobertura]): con hasta
  /// [tokensCortos] tokens, solo se responde directo si la consulta toca el
  /// título/preguntas de la mejor ficha y la comparten menos de
  /// [libreriasAmbiguas] librerías.
  static const int tokensCortos = 2;
  static const int libreriasAmbiguas = 3;
}

/// Puntuador semántico enchufable (Paso 5: `GuiaIndiceSemantico`).
/// Devuelve un puntaje en [0, 1] por ficha (misma posición que el corpus)
/// o null si todavía no está disponible (modelo sin descargar, índice en
/// construcción, etc.). En ese caso el retriever sigue solo con BM25.
abstract class GuiaPuntuadorSemantico {
  Future<List<double>?> puntuar(String consulta);
  bool get disponible;
}

/// Buscador retrieval-first de El Guía.
///
/// Combina BM25 (siempre) con el índice semántico (cuando existe) y aplica
/// la política de tres franjas: directa / aclarar / ninguna.
class GuiaRetriever {
  final List<GuiaFicha> fichas;
  final GuiaBm25 _bm25;
  final GuiaPuntuadorSemantico? semantico;
  final Map<String, List<String>> sinonimos;
  final double pesoLexicoHibrido;
  GuiaUmbrales umbralesLexico;
  GuiaUmbrales umbralesHibrido;

  GuiaRetriever(
    this.fichas, {
    this.semantico,
    this.sinonimos = const {},
    this.pesoLexicoHibrido = 0.2,
    this.umbralesLexico = GuiaUmbrales.lexico,
    this.umbralesHibrido = GuiaUmbrales.hibrido,
  }) : _bm25 = GuiaBm25(fichas);

  /// Cantidad de librerías distintas representadas en el corpus.
  int get librerias => fichas.map((f) => f.libreria).toSet().length;

  /// Consultas de 1-2 tokens: "palomar" sí, "dorado" / "parana" / "nudo" no
  /// (son de muchas fichas → mejor preguntar). Igual que
  /// `confiable_para_directa` en evaluar_retrieval.py.
  bool _confiableParaDirecta(String consulta, int mejor) {
    final c = _bm25.cobertura(consulta, mejor);
    if (c.tokens > GuiaUmbrales.tokensCortos) return true;
    return c.cobertura > 0 && c.ambiguedad < GuiaUmbrales.libreriasAmbiguas;
  }

  /// [consulta] es lo que ve BM25 (puede venir ya normalizada por el motor,
  /// con alias tipo "peje" → "pejerrey"); [consultaSemantica] es el texto
  /// original con acentos para el embedder (si es null se usa [consulta]).
  Future<GuiaResultadoBusqueda> buscar(String consulta, {String? consultaSemantica, int top = 3}) async {
    final t0 = DateTime.now();
    final consultaExp = GuiaTextoEs.expandirSinonimos(consulta, sinonimos);
    final lex = _bm25.puntuar(consultaExp);

    List<double>? sem;
    if (semantico != null && semantico!.disponible) {
      try {
        sem = await semantico!.puntuar(consultaSemantica ?? consulta);
        if (sem != null && sem.length != fichas.length) sem = null;
      } catch (_) {
        sem = null;
      }
    }

    final usoSem = sem != null;
    final umbrales = usoSem ? umbralesHibrido : umbralesLexico;
    final scores = List<double>.generate(fichas.length, (i) {
      if (!usoSem) return lex[i];
      return pesoLexicoHibrido * lex[i] + (1 - pesoLexicoHibrido) * sem![i];
    });

    // Ranking: una ficha por librería (la mejor de cada una).
    final orden = List<int>.generate(fichas.length, (i) => i)
      ..sort((a, b) => scores[b].compareTo(scores[a]));
    final vistas = <String>{};
    final candidatos = <GuiaCandidato>[];
    for (final i in orden) {
      if (!vistas.add(fichas[i].libreria)) continue;
      candidatos.add(GuiaCandidato(fichas[i], scores[i], lex[i], sem?[i]));
      if (candidatos.length >= top) break;
    }

    final s1 = candidatos.isEmpty ? 0.0 : candidatos[0].puntaje;
    final s2 = candidatos.length < 2 ? 0.0 : candidatos[1].puntaje;
    GuiaDecision decision;
    if (candidatos.isEmpty || s1 < umbrales.tBajo) {
      decision = GuiaDecision.ninguna;
    } else if (s1 >= umbrales.tAlto &&
        (s1 - s2) >= umbrales.margen &&
        _confiableParaDirecta(consultaExp, orden.first)) {
      decision = GuiaDecision.directa;
    } else {
      decision = GuiaDecision.aclarar;
    }

    return GuiaResultadoBusqueda(
      consulta: consulta,
      decision: decision,
      candidatos: candidatos,
      s1: s1,
      s2: s2,
      usoSemantico: usoSem,
      duracion: DateTime.now().difference(t0),
    );
  }
}
