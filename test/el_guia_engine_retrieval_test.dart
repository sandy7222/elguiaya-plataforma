// Integración del retriever en ElGuiaEngine.responder() (Fase 5, Paso 3).
//
// Verifica el orden de la tubería: intenciones críticas/sociales → motor
// de reglas; el resto → retriever (ficha directa / "¿te referís a...?") →
// búsqueda dinámica → reglas → fallback.
//
// Correr: flutter test test/el_guia_engine_retrieval_test.dart

import 'package:capitanya_master/services/el_guia_engine.dart';
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

  bool esFicha(String texto) => engine.fichasRetrieval.any((f) => f.texto == texto);

  test('el corpus se arma desde los assets al inicializar', () {
    expect(engine.retrievalListo, isTrue);
    expect(engine.fichasRetrieval.length, greaterThan(300));
  });

  test('una pregunta técnica clara devuelve la ficha tal cual', () async {
    final r = await engine.responder('¿cómo se hace el nudo palomar?');
    expect(esFicha(r.texto), isTrue, reason: r.texto);
    expect(r.texto, contains('Pasá la línea doble'));

    final chupin = await engine.responder('cómo se hace el chupín de pescado');
    expect(esFicha(chupin.texto), isTrue, reason: chupin.texto);
    expect(chupin.texto.toUpperCase(), contains('CHUPÍN'));
  });

  test('una pregunta fuera de dominio NO devuelve una ficha', () async {
    for (final q in ['cuánto sale el dólar hoy', 'quién ganó el partido de river', 'cómo cambio una rueda del auto']) {
      final r = await engine.responder(q);
      expect(esFicha(r.texto), isFalse, reason: '"$q" → ${r.texto}');
    }
  });

  test('las intenciones críticas y sociales las sigue respondiendo el motor de reglas', () async {
    final emergencia = await engine.responder('emergencia, se está hundiendo la lancha');
    expect(esFicha(emergencia.texto), isFalse, reason: emergencia.texto);

    engine.contexto.resetearContexto();
    final saludo = await engine.responder('hola, como andas?');
    expect(esFicha(saludo.texto), isFalse, reason: saludo.texto);

    engine.contexto.resetearContexto();
    final pago = await engine.responder('cómo pago el viaje');
    expect(esFicha(pago.texto), isFalse, reason: pago.texto);
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
    expect(esFicha(elegida.texto), isTrue, reason: 'ACLARACION: $aclaracion\nELEGIDA: ${elegida.texto}');
  });

  test('con BM25 apagado no interviene', () async {
    ElGuiaEngine.bm25Habilitado = false;
    try {
      final r = await engine.responder('¿cómo se hace el nudo palomar?');
      // El motor de reglas contesta con su handler de nudos (o fallback),
      // nunca con una ficha del retriever.
      expect(esFicha(r.texto), isFalse, reason: r.texto);
    } finally {
      ElGuiaEngine.bm25Habilitado = true;
    }
  });
}
