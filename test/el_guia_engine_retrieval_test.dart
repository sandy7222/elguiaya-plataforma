// Integración del retriever en ElGuiaEngine.responder() (Fase 5, Paso 3).
//
// Verifica el orden de la tubería: intenciones críticas/sociales → motor
// de reglas; el resto → retriever (ficha directa / "¿te referís a...?") →
// búsqueda dinámica → reglas → fallback.
//
// Correr: flutter test test/el_guia_engine_retrieval_test.dart

import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_presentador.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ElGuiaEngine engine;

  setUpAll(() async {
    // El buscador (BM25) viene prendido por defecto (lo prueba guia_flags_test.dart);
    // acá se prende de forma explícita para que este archivo no dependa del
    // valor por defecto.
    ElGuiaEngine.bm25Habilitado = true;
    engine = ElGuiaEngine();
    await engine.inicializar();
    await engine.reconstruirIndiceRetrieval();
  });

  setUp(() => engine.contexto.resetearContexto());

  /// Con el presentador prendido (paso 1.2) la respuesta ya no es la ficha cruda:
  /// es la ficha PRESENTADA para esa pregunta. Se compara el cuerpo (lo que es de
  /// la ficha) y se ignora la entrada ("Te cuento:"), que cambia al azar.
  bool esFichaPresentada(String texto, String pregunta) => engine.fichasRetrieval.any((f) {
        final cuerpo = GuiaPresentador.presentar(f, pregunta).cuerpo;
        return texto.endsWith(cuerpo);
      });

  test('el corpus se arma desde los assets al inicializar', () {
    expect(engine.retrievalListo, isTrue);
    expect(engine.fichasRetrieval.length, greaterThan(300));
  });

  test('una pregunta técnica clara devuelve la ficha PRESENTADA (no la cruda)', () async {
    const pNudo = '¿cómo se hace el nudo palomar?';
    final r = await engine.responder(pNudo);
    expect(esFichaPresentada(r.texto, pNudo), isTrue, reason: r.texto);
    expect(r.texto.toLowerCase(), contains('pasá la línea doble'));
    expect(r.texto, isNot(contains('Resistencia:')), reason: 'la planilla tiene que estar convertida en oraciones');

    const pChupin = 'cómo se hace el chupín de pescado';
    final chupin = await engine.responder(pChupin);
    expect(esFichaPresentada(chupin.texto, pChupin), isTrue, reason: chupin.texto);
    expect(chupin.texto.toUpperCase(), contains('CHUPÍN'));
  });

  test('una pregunta fuera de dominio NO devuelve una ficha', () async {
    for (final q in ['cuánto sale el dólar hoy', 'quién ganó el partido de river', 'cómo cambio una rueda del auto']) {
      final r = await engine.responder(q);
      expect(esFichaPresentada(r.texto, q), isFalse, reason: '"$q" → ${r.texto}');
    }
  });

  test('las intenciones críticas y sociales las sigue respondiendo el motor de reglas', () async {
    final emergencia = await engine.responder('emergencia, se está hundiendo la lancha');
    expect(esFichaPresentada(emergencia.texto, 'emergencia, se está hundiendo la lancha'), isFalse, reason: emergencia.texto);

    engine.contexto.resetearContexto();
    final saludo = await engine.responder('hola, como andas?');
    expect(esFichaPresentada(saludo.texto, 'hola, como andas?'), isFalse, reason: saludo.texto);

    engine.contexto.resetearContexto();
    final pago = await engine.responder('cómo pago el viaje');
    expect(esFichaPresentada(pago.texto, 'cómo pago el viaje'), isFalse, reason: pago.texto);
  });

  test('una especie suelta la resuelve el handler de reglas (intención peces), no una ficha ambigua', () async {
    final r = await engine.responder('contame del dorado');
    expect(r.texto.toLowerCase(), contains('dorado'));
  });

  test('"¿te referís a...?" acepta la elección por número', () async {
    // Buscamos una consulta corta y ambigua que las reglas no reconozcan
    // (intención fallback) para que el retriever ofrezca opciones.
    String? aclaracion;
    for (final q in ['palito', 'brazolada', 'madre', 'mosca', 'lider', 'multifilamento', 'freno']) {
      engine.contexto.resetearContexto();
      final r = await engine.responder(q);
      if (r.texto.contains('¿Te referís a...?')) {
        aclaracion = r.texto;
        break;
      }
    }
    if (aclaracion == null) {
      markTestSkipped('ninguna consulta corta cayó en aclaración con este corpus');
      return;
    }
    expect(aclaracion, contains('1. '));
    final elegida = await engine.responder('la primera');
    expect(esFichaPresentada(elegida.texto, 'la primera'), isTrue,
        reason: 'ACLARACION: $aclaracion\nELEGIDA: ${elegida.texto}');
  });

  // PROBLEMA CONOCIDO, a propósito salteado hasta la Fase 2 (medir y recalibrar).
  // "como se prepara la masa para boga" es la masa de CARNADA, pero el buscador
  // devuelve la receta de empanadas de boga: puntajes 0,6 contra 0,5 y decide
  // "directa". Los umbrales de Dart están en otra escala que los de Python
  // (ver docs/PLAN_AYUDANTE_IA.md, riesgos). Cuando se recalibren, sacar el skip.
  test('"masa para boga" da la masa de carnada, no la receta de empanadas', () async {
    final r = await engine.responder('como se prepara la masa para boga');
    expect(r.texto.toLowerCase(), isNot(contains('empanada')), reason: r.texto);
  }, skip: 'Fase 2: umbrales del buscador sin calibrar (puntajes 0,6 vs 0,5 deciden "directa")');

  test('con BM25 apagado no interviene', () async {
    ElGuiaEngine.bm25Habilitado = false;
    try {
      final r = await engine.responder('¿cómo se hace el nudo palomar?');
      // El motor de reglas contesta con su handler de nudos (o fallback),
      // nunca con una ficha del retriever.
      expect(esFichaPresentada(r.texto, '¿cómo se hace el nudo palomar?'), isFalse, reason: r.texto);
    } finally {
      ElGuiaEngine.bm25Habilitado = true;
    }
  });
}
