import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElGuiaEngine V2 - Offline Engine Specification Tests', () {
    late ElGuiaEngine engine;

    setUp(() {
      engine = ElGuiaEngine();
      engine.contexto.resetearContexto();
    });

    test('1. Normalizador Previo - Alias and Noise Removal', () async {
      await engine.inicializar();

      // Test alias resolution and noise removal
      final respPeje = await engine.responder('hola che guia como hago para hacer flotar nylon para peje');
      expect(respPeje, isNotNull);
      // 'como_hago_flotar_nylon_pejerrey' should be resolved.
      // Let's verify the response text contains the expected tip for pejerrey nylon floating.
      expect(respPeje.texto.toLowerCase(), contains('pejerrey'));
      expect(respPeje.texto.toLowerCase(), contains('flote'));

      await engine.responder('como se prepara masa para taru');
      // 'como_se_prepara_masa' might match or tararira fallback.
      // Wait, 'taru' gets mapped to 'tararira'. Let's check objectives.
      expect(engine.contexto.objetivosRecientes, contains('tararira'));
    });

    test('2. Motor de Scoring - Weights and Causal Boost', () async {
      await engine.inicializar();

      // Test Causal Boost: "no pica" should increase 'diagnostico' score.
      // In _buscarEnLibreriasDinamico, scoring for 'porque no pica' -> diagnostico: 6 + 3 = 9.
      // Let's test that "no pica" triggers diagnostic lookup or behavior.
      final respNoPica = await engine.responder('porque no pica nada en el rio?');
      expect(
        respNoPica.texto.toLowerCase(),
        anyOf([
          contains('paciencia'),
          contains('pique'),
          contains('carnada'),
          contains('rio'),
          contains('bueno'),
          contains('días'),
          contains('dias'),
        ]),
      );
    });

    test('3. Anti-Rescate - State Query Interception', () async {
      await engine.inicializar();

      // Clear recent objectives
      engine.contexto.resetearContexto();

      // Query containing "como esta" should force 'consulta_estado' and clear target objectives.
      final respEstado = await engine.responder('como esta el parana');
      // Should route to _responderRio since 'rio crecido' or similar is matched in intent detection.
      expect(respEstado.texto.toLowerCase(), anyOf([contains('río'), contains('agua'), contains('crecido'), contains('bajo')]));
      expect(engine.contexto.objetivosRecientes, isEmpty);
    });

    test('4. Fallback Jerárquico - 6 Search Levels', () async {
      await engine.inicializar();

      // Let's query something that maps to an exact level 1: como_se_prepara_masa
      final respMasa = await engine.responder('como se prepara la masa para boga');
      // ignore: avoid_print
      print('DEBUG RESP MASA: ${respMasa.texto}');
      expect(respMasa.texto.toLowerCase(), anyOf([contains('harina'), contains('masa'), contains('esencia'), contains('polenta')]));

      engine.contexto.resetearContexto();

      // Level 4/5 fallback: query 'boyas' directly
      final respBoya = await engine.responder('que boya me recomendas');
      expect(respBoya.texto.toLowerCase(), anyOf([contains('chupetona'), contains('flotador'), contains('luminosa')]));
    });

    test('5. Contexto - Inference using objetivosRecientes', () async {
      await engine.inicializar();

      engine.contexto.resetearContexto();

      // First query to register an objective
      await engine.responder('como hago el nudo palomar');
      expect(engine.contexto.objetivosRecientes, contains('palomar'));

      // Second query lacking objective but needing inference
      // "como se hace" + inferred "palomar" -> should load como_se_hace_nudo_union_tiburon or similar, or fall back to nudos.
      final respInferred = await engine.responder('como se hace');
      // Check that it responds with nudo steps or explanation
      expect(respInferred.texto.toLowerCase(), anyOf([contains('palomar'), contains('nudo')]));
    });

    test('6. Emergencias - Capa de Sinónimos y Preguntas de Seguimiento Propias', () async {
      await engine.inicializar();
      engine.contexto.resetearContexto();

      // "estoy sangrando" no es activador exacto de herida. json de sinonimos lo matchea.
      final respEmergencia = await engine.responder('estoy sangrando de la mano');
      expect(respEmergencia.texto.toLowerCase(), contains('presioná'));
      expect(respEmergencia.texto.toLowerCase(), contains('herida'));

      // Verificar que tenga pregunta de seguimiento específica de herida y no la global
      expect(
        respEmergencia.texto,
        anyOf([
          contains('sangrado'),
          contains('limpio'),
          contains('profunda'),
          contains('zona'),
          contains('apretando'),
        ]),
      );
      // Las de emergencia global de radio náutica no aplican
      expect(respEmergencia.texto, isNot(contains('VHF')));
      expect(respEmergencia.texto, isNot(contains('radio')));
    });
  });
}
