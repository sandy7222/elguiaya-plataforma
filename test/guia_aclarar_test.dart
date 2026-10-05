// Paso 1.3b de docs/PLAN_AYUDANTE_IA.md (solo los dos arreglos baratos; el resto es
// la Fase 2). El dueño ya aceptó perder alguna aclaración válida a cambio de no
// inventar.
//
//  (a) El "¿te referís a...?" solo ofrece fichas que comparten con la pregunta al
//      menos una palabra con contenido (sin números ni palabras vacías o
//      genéricas como "cuánto", "cómo", "hace", "tip").
//  (b) "Cómo funciona…", "cómo hago…", "para qué sirve…", "dónde está…" solo activan la
//      ayuda de la app si el objeto es la app ("esto", "la app", "el Guía", "la
//      tienda"...).
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_corpus_builder.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_retriever.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

Map<String, Map<String, dynamic>> _librerias() {
  final out = <String, Map<String, dynamic>>{};
  for (final f in Directory('assets/elguia/librerias').listSync()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    final d = json.decode(f.readAsStringSync());
    if (d is Map<String, dynamic>) out[f.uri.pathSegments.last.replaceAll('.json', '')] = d;
  }
  return out;
}

List<Map<String, dynamic>> _jsonl(String p) => File(p)
    .readAsLinesSync()
    .where((l) => l.trim().isNotEmpty)
    .map((l) => json.decode(l) as Map<String, dynamic>)
    .toList();

String _sinTildes(String t) => t
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
    ElGuiaEngine.aclararEstricto = true;
    ElGuiaEngine.ayudaAppEstricta = true;
  });

  setUp(() {
    ElGuiaEngine.aclararEstricto = true;
    ElGuiaEngine.ayudaAppEstricta = true;
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = false;
  });

  // ── (a) Aclaración con una palabra en común ────────────────────────────────
  group('(a) "¿te referís a...?" solo con una palabra en común', () {
    late GuiaRetriever retriever;
    late List<dynamic> fichas;
    setUpAll(() {
      final r = GuiaCorpusBuilder.construir(_librerias());
      fichas = r.fichas;
      retriever = GuiaRetriever(r.fichas);
    });

    test('fuera de dominio: se van las aclaraciones sin relación (las que no comparten ni una palabra)', () async {
      var aclaran = 0, quedanSinNada = 0;
      final sinNada = <String>[];
      for (final q in _jsonl('mini_model_lab/retrieval/preguntas_fuera_de_dominio.jsonl')) {
        final pregunta = q['instruction'] as String;
        final res = await retriever.buscar(pregunta);
        if (res.decision != GuiaDecision.aclarar) continue;
        aclaran++;
        final quedan = res.candidatos.where((c) => ElGuiaEngine.comparteContenido(pregunta, c.ficha)).toList();
        if (quedan.isEmpty) {
          quedanSinNada++;
          sinNada.add(pregunta);
        }
      }
      // ignore: avoid_print
      print('1.3b (a): de $aclaran aclaraciones fuera de dominio, $quedanSinNada quedan sin ninguna opción: ${sinNada.join(' | ')}');
      expect(aclaran, greaterThanOrEqualTo(10));
      expect(quedanSinNada, greaterThanOrEqualTo(5), reason: 'el filtro tiene que sacar al menos la mitad');
    });

    test('válidas: ninguna aclaración de validación se queda sin opciones y se conserva la ficha correcta', () async {
      final libs = fichas.map((f) => f.libreria as String).toSet();
      var aclaran = 0, sinOpciones = 0, pierdeLaCorrecta = 0;
      for (final q in _jsonl('mini_model_lab/dataset/dataset_validacion_v5.jsonl').where((x) => libs.contains(x['fuente_libreria']))) {
        final pregunta = q['instruction'] as String;
        final res = await retriever.buscar(pregunta);
        if (res.decision != GuiaDecision.aclarar) continue;
        aclaran++;
        final quedan = res.candidatos.where((c) => ElGuiaEngine.comparteContenido(pregunta, c.ficha)).toList();
        if (quedan.isEmpty) sinOpciones++;
        final estaba = res.candidatos.any((c) => c.ficha.libreria == q['fuente_libreria']);
        if (estaba && !quedan.any((c) => c.ficha.libreria == q['fuente_libreria'])) pierdeLaCorrecta++;
      }
      // ignore: avoid_print
      print('1.3b (a): de $aclaran aclaraciones válidas, $sinOpciones quedan sin opciones y $pierdeLaCorrecta pierden la ficha correcta');
      expect(aclaran, greaterThanOrEqualTo(15));
      expect(sinOpciones, 0);
      expect(pierdeLaCorrecta, 0);
    });

    test('no cuentan los números ni las palabras genéricas', () {
      final ficha = fichas.firstWhere((f) => f.titulo.toLowerCase().contains('identificacion') || f.titulo.toLowerCase().contains('identificación'));
      expect(ElGuiaEngine.comparteContenido('cuánto es 45 por 12', ficha), isFalse);
      expect(ElGuiaEngine.comparteContenido('cómo hago tip consejo algún', ficha), isFalse);
    });

    test('con el flag apagado el filtro no se aplica', () async {
      ElGuiaEngine.aclararEstricto = false;
      final engine = ElGuiaEngine();
      await engine.inicializar();
      await engine.reconstruirIndiceRetrieval();
      engine.contexto.resetearContexto();
      final r = await engine.responder('cómo se hace la salsa bolognesa');
      expect(r.texto, contains('¿Te referís a...?'), reason: 'antes del 1.3b salía esta aclaración sin relación');
    });

    test('con el filtro prendido, estas preguntas ya no ofrecen fichas sin relación', () async {
      final engine = ElGuiaEngine();
      await engine.inicializar();
      await engine.reconstruirIndiceRetrieval();
      for (final q in ['cuánto es 45 por 12', 'cuánto cuesta un iphone', 'cuándo empieza el mundial', 'cuántos habitantes tiene rosario', 'cómo pinto una pared']) {
        engine.contexto.resetearContexto();
        final r = await engine.responder(q);
        expect(r.texto, isNot(contains('¿Te referís a...?')), reason: '"$q" → ${r.texto}');
      }
    });
  });

  // ── (b) "cómo funciona…" solo es ayuda de la app si habla de la app ────────
  group('(b) ayuda de la app solo si el objeto es la app', () {
    final engine = ElGuiaEngine();
    setUpAll(() async => engine.inicializar());

    List<String> intenciones(String t) => engine.detectarIntenciones(_sinTildes(t));

    const deLaApp = [
      'cómo funciona esto',
      'cómo funciona la app',
      'cómo funciona la aplicación',
      'cómo funciona el guía',
      'para qué sirve esto',
      'para qué sirve la app',
      'cómo uso la app',
      'cómo uso esto',
      'cómo hago en la app',
      'dónde está el botón',
      'cómo funciona la tienda',
      'cómo funciona el mapa',
      'no encuentro mi reserva',
      'no encuentro la pantalla de pagos',
      'no sé usar la app',
    ];
    for (final f in deLaApp) {
      test('app: "$f"', () => expect(intenciones(f), contains('ayuda_app')));
    }

    const noEsLaApp = [
      'cómo funciona la bolsa de valores',
      'cómo hago para bajar de peso rápido',
      'cómo hago para dormir mejor',
      'cómo funciona un motor de combustión',
      'para qué sirve el bitcoin',
      'cómo uso una tijera',
      'dónde está la torre eiffel',
      'dónde está mi paciencia',
      'no encuentro mis llaves',
      'cómo funciona la democracia',
    ];
    for (final f in noEsLaApp) {
      test('no es la app: "$f"', () => expect(intenciones(f), isNot(contains('ayuda_app'))));
    }

    test('con el flag apagado vuelve a activarse (comportamiento de antes)', () {
      ElGuiaEngine.ayudaAppEstricta = false;
      expect(intenciones('cómo funciona la bolsa de valores'), contains('ayuda_app'));
    });

    test('fuera de dominio: ya no contesta un menú de la app', () async {
      for (final q in ['cómo funciona la bolsa de valores', 'cómo hago para dormir mejor', 'cómo hago para bajar de peso rápido']) {
        final r = await BaqueanoIAService.responder(q);
        expect(r.texto, isNot(contains('¿Qué estás buscando?')), reason: '"$q" → ${r.texto}');
        expect(r.texto, isNot(contains('¿Qué querés usar?')), reason: '"$q" → ${r.texto}');
        expect(r.texto, isNot(contains('No te ubiqué bien')), reason: '"$q" → ${r.texto}');
      }
    });
  });

  group('flags', () {
    test('vienen prendidos', () {
      expect(ElGuiaEngine.aclararEstricto, isTrue);
      expect(ElGuiaEngine.ayudaAppEstricta, isTrue);
    });
    test('aplicarFlags lee las preferencias', () async {
      SharedPreferences.setMockInitialValues({
        ElGuiaEngine.prefAclararEstricto: false,
        ElGuiaEngine.prefAyudaAppEstricta: false,
      });
      ElGuiaEngine.aplicarFlags(await SharedPreferences.getInstance());
      expect(ElGuiaEngine.aclararEstricto, isFalse);
      expect(ElGuiaEngine.ayudaAppEstricta, isFalse);
    });
  });
}
