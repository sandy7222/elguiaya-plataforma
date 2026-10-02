// Tests del retriever offline de El Guía (lib/services/guia_retrieval/).
//
// Verifican PARIDAD con el prototipo Python de mini_model_lab/retrieval/:
//   1. el corpus de fichas que arma Dart es idéntico al de fichas.py
//      (fichas_corpus.json);
//   2. el stemmer/tokenizador da los mismos stems (stems_esperados.json);
//   3. la búsqueda léxica repite las métricas de evaluar_retrieval.py sobre
//      dataset_validacion_v5.jsonl y rechaza las preguntas fuera de dominio.
//
// Correr: flutter test test/guia_retrieval_test.dart
// Si falla (1) o (2) después de tocar fichas.py / texto_es.py, hay que
// regenerar los JSON: cd mini_model_lab/retrieval && python fichas.py &&
// python evaluar_retrieval.py --sin-semantico

import 'dart:convert';
import 'dart:io';

import 'package:capitanya_master/services/guia_retrieval/guia_corpus_builder.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_ficha.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_retriever.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_stemmer_es.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_texto_es.dart';
import 'package:flutter_test/flutter_test.dart';

const _librerias = 'assets/elguia/librerias';
const _lab = 'mini_model_lab/retrieval';
const _dataset = 'mini_model_lab/dataset';

Map<String, Map<String, dynamic>> _cargarLibreriasDeDisco() {
  final out = <String, Map<String, dynamic>>{};
  for (final f in Directory(_librerias).listSync()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    final stem = f.uri.pathSegments.last.replaceAll('.json', '');
    final decoded = json.decode(f.readAsStringSync());
    if (decoded is Map<String, dynamic>) out[stem] = decoded;
  }
  return out;
}

List<Map<String, dynamic>> _jsonl(String path) => File(path)
    .readAsLinesSync()
    .where((l) => l.trim().isNotEmpty)
    .map((l) => json.decode(l) as Map<String, dynamic>)
    .toList();

void main() {
  late List<GuiaFicha> fichas;
  late GuiaCorpusReporte reporte;

  setUpAll(() {
    final r = GuiaCorpusBuilder.construir(_cargarLibreriasDeDisco());
    fichas = r.fichas;
    reporte = r.reporte;
  });

  group('corpus de fichas', () {
    test('excluye las 41 críticas y las sociales, convierte el resto', () {
      expect(reporte.excluidasCriticas.length, 41);
      expect(reporte.excluidasSociales.length, 14);
      expect(reporte.sinFichas, isEmpty, reason: 'librerías sin ninguna ficha');
      expect(reporte.sinConvertir, isEmpty, reason: 'claves sin regla de conversión');
      for (final f in fichas) {
        expect(GuiaCorpusBuilder.motivoExclusion(f.libreria), isNull);
      }
    });

    test('es idéntico al que genera fichas.py', () {
      final esperadas = (json.decode(File('$_lab/fichas_corpus.json').readAsStringSync()) as List)
          .map((j) => GuiaFicha.fromJson(j as Map<String, dynamic>))
          .toList();
      final porId = {for (final f in fichas) f.id: f};
      expect(porId.length, fichas.length, reason: 'ids duplicados en el corpus Dart');
      expect(fichas.length, esperadas.length, reason: 'cantidad de fichas');
      final diferencias = <String>[];
      for (final e in esperadas) {
        final d = porId[e.id];
        if (d == null) {
          diferencias.add('falta ${e.id}');
          continue;
        }
        if (d.texto != e.texto) diferencias.add('texto distinto en ${e.id}');
        if (d.titulo != e.titulo) diferencias.add('título distinto en ${e.id}: "${d.titulo}" vs "${e.titulo}"');
        if (d.preguntas.join('|') != e.preguntas.join('|')) diferencias.add('preguntas distintas en ${e.id}');
        if (d.keywords.join('|') != e.keywords.join('|')) diferencias.add('keywords distintas en ${e.id}');
        if (d.categoria != e.categoria) diferencias.add('categoría distinta en ${e.id}');
      }
      expect(diferencias, isEmpty, reason: diferencias.take(10).join('\n'));
    });
  });

  group('texto en español', () {
    test('normalizar saca acentos, puntuación y mayúsculas', () {
      expect(GuiaTextoEs.normalizar('¿Cómo se pesca el DORADO, ché?'), 'como se pesca el dorado che');
      expect(GuiaTextoEs.normalizar('Ñandú  y  pirá-pitá'), 'nandu y pira pita');
    });

    test('stemmer da los mismos stems que snowballstemmer (Python)', () {
      final esperados = json.decode(File('$_lab/stems_esperados.json').readAsStringSync()) as Map<String, dynamic>;
      final errores = <String>[];
      esperados.forEach((palabra, stem) {
        final d = GuiaStemmerEs.stem(palabra);
        if (d != stem) errores.add('$palabra → "$d" (esperado "$stem")');
      });
      expect(errores, isEmpty, reason: '${errores.length} diferencias, ej.: ${errores.take(15).join(', ')}');
    });

    test('tokenizar saca stopwords y stemmea', () {
      expect(GuiaTextoEs.tokenizar('¿Qué carnada uso para el dorado?'), ['carn', 'dor']);
      expect(GuiaTextoEs.tokenizar('carnadas'), ['carn']);
    });
  });

  group('búsqueda léxica', () {
    late GuiaRetriever retriever;
    setUpAll(() => retriever = GuiaRetriever(fichas));

    test('repite las métricas de evaluar_retrieval.py en validación', () async {
      final libs = fichas.map((f) => f.libreria).toSet();
      final val = _jsonl('$_dataset/dataset_validacion_v5.jsonl')
          .where((r) => libs.contains(r['fuente_libreria']))
          .toList();
      var top1 = 0, rec3 = 0, directas = 0, directasMal = 0, aclara = 0, ninguna = 0;
      for (final r in val) {
        final res = await retriever.buscar(r['instruction'] as String);
        final objetivo = r['fuente_libreria'];
        final libsTop = res.candidatos.map((c) => c.ficha.libreria).toList();
        if (libsTop.isNotEmpty && libsTop.first == objetivo) top1++;
        if (libsTop.contains(objetivo)) rec3++;
        switch (res.decision) {
          case GuiaDecision.directa:
            directas++;
            if (libsTop.first != objetivo) directasMal++;
          case GuiaDecision.aclarar:
            aclara++;
          case GuiaDecision.ninguna:
            ninguna++;
        }
      }
      // ignore: avoid_print
      print('validación n=${val.length}: top1=$top1 recall@3=$rec3 | directas=$directas '
          '(mal: $directasMal) aclarar=$aclara ninguna=$ninguna');
      expect(val.length, 71);
      expect(top1 / val.length, greaterThanOrEqualTo(0.85));
      expect(rec3, val.length, reason: 'recall@3 debe ser 100 %');
      expect(directasMal, lessThanOrEqualTo(2));
      expect(ninguna, 0);
    });

    test('rechaza las preguntas fuera de dominio', () async {
      final ood = _jsonl('$_lab/preguntas_fuera_de_dominio.jsonl');
      var directas = 0;
      for (final r in ood) {
        final res = await retriever.buscar(r['instruction'] as String);
        if (res.decision == GuiaDecision.directa) directas++;
      }
      expect(ood.length, 50);
      expect(directas, lessThanOrEqualTo(2), reason: 'máximo 4 % de falsas aceptaciones');
    });

    test('casos puntuales', () async {
      // "dorado" solo es un empate legítimo entre la ficha de la especie y
      // sus carnadas: en modo léxico tiene que caer en "¿te referís a...?"
      // con peces entre las opciones (el híbrido lo resuelve directo).
      final dorado = await retriever.buscar('contame del dorado');
      expect(dorado.candidatos.map((c) => c.ficha.libreria), contains('peces'));
      expect(dorado.decision, isNot(GuiaDecision.ninguna));
      if (dorado.decision == GuiaDecision.directa) expect(dorado.mejor?.libreria, 'peces');

      final nudo = await retriever.buscar('cómo hago el nudo palomar');
      expect(nudo.mejor?.id, 'nudos/nudos/palomar');

      final vacio = await retriever.buscar('¿?');
      expect(vacio.decision, GuiaDecision.ninguna);

      final critica = await retriever.buscar('cómo pago el viaje');
      expect(critica.candidatos.every((c) => !GuiaCorpusBuilder.criticas.contains(c.ficha.libreria)), isTrue);
    });
  });
}
