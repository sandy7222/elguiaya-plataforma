// Paso 1.1 de docs/PLAN_AYUDANTE_IA.md: separar los flags del buscador.
//
// Antes, un solo flag (`guia_retrieval_first`, apagado por defecto) prendía a la
// vez el buscador léxico por fichas (BM25) y la capa de embeddings con llama.cpp
// (~150 MB de RAM y un modelo de 126 MB por WiFi). Por eso el buscador, que
// acertaba casi todo, quedó apagado.
//
// Ahora:
//   · `guia_bm25`      (por defecto TRUE):  el buscador léxico. Sin RAM extra.
//   · `guia_semantico` (por defecto FALSE): llama.cpp. Requiere BM25.
//   · `guia_retrieval_first` (legado): `false` guardado a mano apaga BM25.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/guia_knowledge_sync_service.dart';

/// Lo que dice el plan que son los valores por defecto.
void _valoresPorDefecto() {
  ElGuiaEngine.bm25Habilitado = true;
  ElGuiaEngine.semanticoHabilitado = false;
}

Future<void> _conPrefs(Map<String, Object> valores) async {
  SharedPreferences.setMockInitialValues(valores);
  ElGuiaEngine.aplicarFlags(await SharedPreferences.getInstance());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('valores por defecto', () {
    test('BM25 viene PRENDIDO y el semántico APAGADO', () {
      expect(ElGuiaEngine.bm25Habilitado, isTrue, reason: 'el buscador léxico no cuesta RAM: tiene que venir prendido');
      expect(ElGuiaEngine.semanticoHabilitado, isFalse, reason: 'llama.cpp (~150 MB de RAM) tiene que venir apagado');
      expect(ElGuiaEngine.capaSemanticaPermitida, isFalse);
    });

    test('sin nada guardado, los flags quedan como están', () async {
      _valoresPorDefecto();
      await _conPrefs({});
      expect(ElGuiaEngine.bm25Habilitado, isTrue);
      expect(ElGuiaEngine.semanticoHabilitado, isFalse);
    });
  });

  group('lo guardado en SharedPreferences', () {
    setUp(_valoresPorDefecto);

    test('guia_bm25=false apaga el buscador', () async {
      await _conPrefs({'guia_bm25': false});
      expect(ElGuiaEngine.bm25Habilitado, isFalse);
    });

    test('guia_semantico=true prende la capa semántica', () async {
      await _conPrefs({'guia_semantico': true});
      expect(ElGuiaEngine.semanticoHabilitado, isTrue);
      expect(ElGuiaEngine.capaSemanticaPermitida, isTrue);
    });

    test('guia_bm25=true y guia_semantico=true prenden las dos', () async {
      await _conPrefs({'guia_bm25': true, 'guia_semantico': true});
      expect(ElGuiaEngine.bm25Habilitado, isTrue);
      expect(ElGuiaEngine.semanticoHabilitado, isTrue);
    });

    test('el semántico no funciona sin BM25, aunque esté pedido', () async {
      await _conPrefs({'guia_bm25': false, 'guia_semantico': true});
      expect(ElGuiaEngine.semanticoHabilitado, isTrue);
      expect(ElGuiaEngine.capaSemanticaPermitida, isFalse, reason: 'la capa semántica trabaja sobre el buscador');
    });
  });

  group('el flag anterior (guia_retrieval_first) guardado a mano', () {
    setUp(_valoresPorDefecto);

    test('false se respeta como "BM25 apagado"', () async {
      await _conPrefs({'guia_retrieval_first': false});
      expect(ElGuiaEngine.bm25Habilitado, isFalse);
      expect(ElGuiaEngine.semanticoHabilitado, isFalse);
    });

    test('true prendía todo, y se respeta: BM25 y semántico', () async {
      await _conPrefs({'guia_retrieval_first': true});
      expect(ElGuiaEngine.bm25Habilitado, isTrue);
      expect(ElGuiaEngine.semanticoHabilitado, isTrue);
    });

    test('los flags nuevos mandan sobre el anterior', () async {
      await _conPrefs({'guia_retrieval_first': false, 'guia_bm25': true});
      expect(ElGuiaEngine.bm25Habilitado, isTrue, reason: 'guia_bm25 manda sobre el legado');

      _valoresPorDefecto();
      await _conPrefs({'guia_retrieval_first': true, 'guia_semantico': false});
      expect(ElGuiaEngine.semanticoHabilitado, isFalse, reason: 'guia_semantico manda sobre el legado');
    });
  });

  group('nombre anterior (retrievalFirstHabilitado)', () {
    test('es lo mismo que BM25', () {
      _valoresPorDefecto();
      ElGuiaEngine.retrievalFirstHabilitado = false;
      expect(ElGuiaEngine.bm25Habilitado, isFalse);
      ElGuiaEngine.bm25Habilitado = true;
      expect(ElGuiaEngine.retrievalFirstHabilitado, isTrue);
    });
  });

  group('el modelo de 126 MB solo se baja si se pidió la capa semántica', () {
    test('con BM25 solo (el valor por defecto) NO se baja ningún modelo', () {
      _valoresPorDefecto();
      expect(GuiaKnowledgeSyncService.debeBajarModelo, isFalse,
          reason: 'BM25 no necesita modelo; bajarlo gastaría 126 MB de datos por nada');
    });

    test('con BM25 y semántico, sí', () {
      _valoresPorDefecto();
      ElGuiaEngine.semanticoHabilitado = true;
      expect(GuiaKnowledgeSyncService.debeBajarModelo, isTrue);
    });

    test('con el semántico pedido pero BM25 apagado, no', () {
      _valoresPorDefecto();
      ElGuiaEngine.bm25Habilitado = false;
      ElGuiaEngine.semanticoHabilitado = true;
      expect(GuiaKnowledgeSyncService.debeBajarModelo, isFalse);
    });
  });
}
