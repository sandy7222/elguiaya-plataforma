// Fase 2 (2.4): runner de evaluación de El Guía, offline.
//
// Corre el conjunto de test/eval/*.jsonl contra el motor SIN nube y mide contra las metas del
// plan (docs/PLAN_AYUDANTE_IA.md, paso 2.4), separando SIEMPRE las preguntas reales (del dueño, del
// celular) de las generadas (por una IA o por plantilla):
//
//   · Pesca: ≥ 85 % top-1 y ≤ 3 % de respuestas directas equivocadas
//   · Fuera de dominio: ≤ 5 % de falsos positivos
//   · Seguridad: 100 %
//
// Escribe build/eval_guia/informe.json y informe.md (y revision_dueno.md con lo que contestó a
// cada pregunta de test/eval/preguntas_dueno.txt, SIN etiquetar, para que el dueño marque).
//
// Qué FALLA este test:
//   1. Seguridad por debajo de 100 % (regla dura, vale para todos los orígenes).
//   2. Cualquier métrica que empeore respecto de test/eval/baseline.json (no deja retroceder).
// Las metas del plan NO hacen fallar el test mientras no se cumplan: se informan con claridad. Cuando
// una mejora sea real, se actualiza el baseline:
//
//   EVAL_ACTUALIZAR_BASELINE=1 flutter test test/eval_guia_test.dart
//
// Barrido de umbrales del buscador (calibración; NO cambia los de la app):
//
//   EVAL_SWEEP=1 flutter test test/eval_guia_test.dart     → build/eval_guia/sweep.md
//
// OJO con la calibración: solo hay preguntas de pesca CON etiqueta de plantilla (generadas). Calibrar
// con ellas es ajustar el buscador a su propia plantilla; la calibración de verdad necesita las
// preguntas reales del dueño, etiquetadas (ver test/eval/README.md).

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_retriever.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

const _dir = 'test/eval';
const _salida = 'build/eval_guia';
const _archivos = [
  'seguridad_dueno.jsonl',
  'seguridad_ia.jsonl',
  'transaccional.jsonl',
  'fuera_dominio.jsonl',
  'pesca_real.jsonl',
  'pesca_plantilla.jsonl',
  'multiturno.jsonl',
  'voz_dictada.jsonl',
  'mezclado.jsonl',
];

/// ¿La fuente es una persona real (el dueño o el celular) o una generada?
bool _esReal(String origen) => origen == 'dueno_real' || origen == 'dictada_celular';

class Caso {
  final String id, texto, categoria, origen;
  final Map<String, dynamic> esperado;
  Caso(this.id, this.texto, this.categoria, this.origen, this.esperado);
}

List<Caso> _cargar() {
  final casos = <Caso>[];
  for (final a in _archivos) {
    final f = File('$_dir/$a');
    if (!f.existsSync()) continue;
    for (final l in f.readAsLinesSync().where((l) => l.trim().isNotEmpty)) {
      final j = jsonDecode(l) as Map<String, dynamic>;
      casos.add(Caso(j['id'] as String, j['texto'] as String, j['categoria'] as String, j['origen'] as String,
          (j['esperado'] as Map?)?.cast<String, dynamic>() ?? {}));
    }
  }
  return casos;
}

List<String> _preguntasDelDueno() {
  final f = File('$_dir/preguntas_dueno.txt');
  if (!f.existsSync()) return [];
  return f.readAsLinesSync().map((l) => l.trim()).where((l) => l.isNotEmpty && !l.startsWith('#')).toList();
}

/// Qué clase de respuesta dio el router.
String _tipoDeRespuesta(String t, List<String> frasesHonestas) {
  if (frasesHonestas.any(t.startsWith)) return 'honesta';
  final m = t.toLowerCase();
  if (m.contains('106') && RegExp(r'canal\s+(?:vhf\s+)?16').hasMatch(m)) return 'seguridad';
  if (t.startsWith('Ese tema esta fuera de mi zona')) return 'rechazo';
  if (t.contains('¿Te referís a...?') || t.contains('creo que me preguntás por')) return 'aclaracion';
  return 'otra';
}

class Resultado {
  final Caso caso;
  final String clase; // clasificarIntencion
  final String decision; // directa | aclarar | ninguna | (sin buscador)
  final String? top1Libreria;
  final String? top1Titulo;
  final double s1, s2;
  final List<String> top3Librerias;
  final String respuesta;
  final String tipo;
  Resultado(this.caso, this.clase, this.decision, this.top1Libreria, this.top1Titulo, this.s1, this.s2, this.top3Librerias,
      this.respuesta, this.tipo);
}

class Grupo {
  int n = 0, ok = 0;
  int top1 = 0, recall3 = 0, directas = 0, directasMal = 0, conEtiquetaLibreria = 0;
  int fpRetriever = 0, fpExtremo = 0, fueraDelCorpus = 0;
  final mal = <String>[];
  Map<String, Object> toJson() => {
        'n': n,
        if (conEtiquetaLibreria > 0) ...{
          'con_etiqueta_libreria': conEtiquetaLibreria,
          'top1': top1,
          'recall3': recall3,
          'directas': directas,
          'directas_mal': directasMal,
        },
        'ok': ok,
        if (fueraDelCorpus > 0) 'sin_ficha_en_el_corpus': fueraDelCorpus,
        if (fpRetriever + fpExtremo > 0) ...{'fp_buscador': fpRetriever, 'fp_extremo_a_extremo': fpExtremo},
      };
}

String _pct(num a, num b) => b == 0 ? 'sin datos' : '${(a / b * 100).toStringAsFixed(1)} %';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ElGuiaEngine engine;
  late List<String> frasesHonestas;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    BaqueanoIAService.retrasoArtificial = false;
    ElGuiaEngine.bm25Habilitado = true;
    await BaqueanoIAService.inicializarParaTest();
    engine = ElGuiaEngine();
    await engine.reconstruirIndiceRetrieval();
    final p = jsonDecode(File('assets/elguia/personalidad.json').readAsStringSync()) as Map<String, dynamic>;
    frasesHonestas = List<String>.from(p['no_se_honesto'] as List);
  });

  test('evaluación offline contra las metas del plan', () async {
    IARouterState.modoOnline.value = false;
    final retriever = engine.retrieverParaTest!;
    final casos = _cargar();
    expect(casos, isNotEmpty);

    Future<Resultado> correr(Caso c) async {
      BaqueanoIAService.reiniciarEstadoParaTest();
      IARouterState.modoOnline.value = false;
      engine.contexto.resetearContexto();
      final clase = engine.clasificarIntencion(c.texto).name;
      final r = await retriever.buscar(c.texto);
      BaqueanoIAService.reiniciarEstadoParaTest();
      IARouterState.modoOnline.value = false;
      final ElGuiaRespuesta resp = await BaqueanoIAService.responder(c.texto);
      return Resultado(
        c,
        clase,
        r.decision.name,
        r.mejor?.libreria,
        r.mejor?.titulo,
        r.s1,
        r.s2,
        r.candidatos.map((x) => x.ficha.libreria).toList(),
        resp.texto,
        _tipoDeRespuesta(resp.texto, frasesHonestas),
      );
    }

    final resultados = <Resultado>[];
    for (final c in casos) {
      if (c.categoria == 'multiturno') continue; // la estructura está; las conversaciones las escribe el dueño
      resultados.add(await correr(c));
    }

    // ── Medición por (categoría, real/generada) ───────────────────────────────
    final libsDelCorpus = engine.fichasRetrieval.map((f) => f.libreria).toSet();
    final grupos = <String, Grupo>{};
    final malos = <Map<String, Object?>>[];
    for (final r in resultados) {
      final c = r.caso;
      final g = grupos.putIfAbsent('${c.categoria}/${_esReal(c.origen) ? 'real' : 'generada'}/${c.origen}', Grupo.new);
      // Una pregunta cuya librería no tiene ficha en el corpus (ej. las críticas) no se puede acertar con
      // el buscador: no cuenta, pero se informa.
      final libEsperada = c.esperado['libreria'] as String?;
      if (c.categoria == 'pesca' && libEsperada != null && !libsDelCorpus.contains(libEsperada)) {
        g.fueraDelCorpus++;
        continue;
      }
      g.n++;
      var ok = true;
      String detalle = '';
      switch (c.categoria) {
        case 'seguridad':
          final amb = c.esperado['ambulancia'] == true;
          final t = r.respuesta.toLowerCase();
          ok = r.clase == 'seguridad' &&
              t.contains('106') &&
              RegExp(r'canal\s+(?:vhf\s+)?16').hasMatch(t) &&
              (!amb || (t.contains('107') && t.contains('911'))) &&
              r.tipo != 'honesta';
          if (!ok) detalle = 'clase=${r.clase} tipo=${r.tipo}${amb ? ' (pedía 107/911)' : ''}';
        case 'transaccional':
          ok = r.clase == 'transaccional';
          if (!ok) detalle = 'clase=${r.clase}';
        case 'fuera_dominio':
          if (r.decision == 'directa') g.fpRetriever++;
          final inventa = r.tipo == 'otra' || r.tipo == 'aclaracion';
          if (inventa) g.fpExtremo++;
          ok = !inventa;
          if (!ok) detalle = 'contestó (${r.tipo}): ${r.respuesta.replaceAll('\n', ' ').substring(0, r.respuesta.length.clamp(0, 80))}';
        case 'pesca':
          final lib = c.esperado['libreria'] as String?;
          if (lib != null) {
            g.conEtiquetaLibreria++;
            final top1 = r.top1Libreria == lib;
            if (top1) g.top1++;
            if (r.top3Librerias.contains(lib)) g.recall3++;
            if (r.decision == 'directa') {
              g.directas++;
              if (!top1) g.directasMal++;
            }
            ok = top1;
            if (!ok) detalle = 'esperaba $lib, top-1 ${r.top1Libreria} (${r.decision})';
          } else if (c.esperado['no_libreria'] is List || c.esperado['no_contiene'] is List) {
            final prohibidas = List<String>.from((c.esperado['no_libreria'] as List?) ?? const []);
            final textosProhibidos = List<String>.from((c.esperado['no_contiene'] as List?) ?? const []);
            ok = !prohibidas.contains(r.top1Libreria) &&
                !textosProhibidos.any((t) => r.respuesta.toLowerCase().contains(t.toLowerCase()));
            if (!ok) detalle = 'top-1 ${r.top1Libreria}; contestó: ${r.respuesta.replaceAll('\n', ' ').substring(0, r.respuesta.length.clamp(0, 90))}';
          } else if (c.esperado['no_fallback'] == true) {
            ok = r.tipo != 'honesta';
            if (!ok) detalle = 'contestó "no tengo ese dato"';
          } else if (c.esperado['no_seguridad'] == true) {
            ok = r.clase != 'seguridad' && r.respuesta.trim().isNotEmpty;
            if (!ok) detalle = 'clase=${r.clase}';
          }
      }
      if (ok) g.ok++;
      if (!ok) {
        malos.add({'id': c.id, 'texto': c.texto, 'categoria': c.categoria, 'origen': c.origen, 'detalle': detalle});
        g.mal.add(c.id);
      }
    }

    // ── Metas del plan, por base (real / generada) ────────────────────────────
    Grupo sumar(bool real, String cat) {
      final t = Grupo();
      grupos.forEach((k, g) {
        final partes = k.split('/');
        if (partes[0] != cat || (partes[1] == 'real') != real) return;
        t.n += g.n;
        t.ok += g.ok;
        t.top1 += g.top1;
        t.recall3 += g.recall3;
        t.directas += g.directas;
        t.directasMal += g.directasMal;
        t.conEtiquetaLibreria += g.conEtiquetaLibreria;
        t.fpRetriever += g.fpRetriever;
        t.fpExtremo += g.fpExtremo;
      });
      return t;
    }

    final metas = <Map<String, Object?>>[];
    void meta(String id, String descripcion, String base, num valor, num total, bool Function(double pct) cumple, String meta) {
      final tieneDatos = total >= 30;
      metas.add({
        'id': id,
        'descripcion': descripcion,
        'base': base,
        'valor': valor,
        'sobre': total,
        'porcentaje': total == 0 ? null : valor / total * 100,
        'meta': meta,
        'cumple': total == 0 ? null : cumple(valor / total * 100),
        'confiable': tieneDatos,
      });
    }

    for (final real in [true, false]) {
      final base = real ? 'real' : 'generada';
      final pesca = sumar(real, 'pesca');
      final ood = sumar(real, 'fuera_dominio');
      final seg = sumar(real, 'seguridad');
      meta('pesca_top1', 'Pesca: acierto top-1', base, pesca.top1, pesca.conEtiquetaLibreria, (p) => p >= 85, '≥ 85 %');
      meta('pesca_directas_mal', 'Pesca: respuestas directas equivocadas', base, pesca.directasMal, pesca.conEtiquetaLibreria,
          (p) => p <= 3, '≤ 3 %');
      meta('ood_falsos_positivos', 'Fuera de dominio: falsos positivos del buscador (directa)', base, ood.fpRetriever, ood.n,
          (p) => p <= 5, '≤ 5 %');
      meta('ood_inventa_extremo', 'Fuera de dominio: respuestas inventadas de punta a punta', base, ood.fpExtremo, ood.n,
          (p) => p <= 5, '≤ 5 %');
      meta('seguridad', 'Seguridad: clasificada + 106/canal 16 (+107/911)', base, seg.ok, seg.n, (p) => p >= 100, '100 %');
    }

    // ── Archivos del informe ──────────────────────────────────────────────────
    final deLaFicha = engine.fichasRetrieval.length;
    final informe = {
      'fecha': DateTime.now().toIso8601String().substring(0, 10),
      'fichas': deLaFicha,
      'umbrales_buscador': {
        't_alto': retriever.umbralesLexico.tAlto,
        't_bajo': retriever.umbralesLexico.tBajo,
        'margen': retriever.umbralesLexico.margen,
      },
      'casos': resultados.length,
      'preguntas_del_dueno_sin_etiquetar': _preguntasDelDueno().length,
      'grupos': grupos.map((k, g) => MapEntry(k, g.toJson())),
      'metas': metas,
      'casos_mal': malos,
    };
    Directory(_salida).createSync(recursive: true);
    File('$_salida/informe.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(informe));

    final md = StringBuffer()
      ..writeln('# Evaluación de El Guía (offline)')
      ..writeln()
      ..writeln('Fecha: ${informe['fecha']} · casos: ${resultados.length} · fichas: $deLaFicha · preguntas del dueño sin etiquetar: ${_preguntasDelDueno().length}')
      ..writeln()
      ..writeln('| Meta | Base | Resultado | Meta del plan | ¿Cumple? |')
      ..writeln('|---|---|---|---|---|');
    for (final m in metas) {
      final total = m['sobre'] as num;
      final cumple = m['cumple'];
      final etiqueta = total == 0
          ? 'sin datos'
          : cumple == true
              ? '✔'
              : '✘';
      final aviso = total > 0 && m['confiable'] == false ? ' (pocos casos: ${total.toInt()})' : '';
      md.writeln('| ${m['descripcion']} | ${m['base']} | ${_pct(m['valor'] as num, total)} (${m['valor']}/${total.toInt()})$aviso | ${m['meta']} | $etiqueta |');
    }
    md
      ..writeln()
      ..writeln('> **Real** = preguntas del dueño o dictadas en el celular. **Generada** = escritas por una IA o por plantilla: no miden lo que dice')
      ..writeln('> la gente de verdad (la plantilla repite las palabras de la ficha y infla el acierto). Mientras no haya preguntas reales con etiqueta,')
      ..writeln('> las metas de pesca de la base "real" quedan **sin datos**.')
      ..writeln()
      ..writeln('## Casos que fallan (${malos.length})')
      ..writeln();
    for (final m in malos) {
      md.writeln('- `${m['id']}` (${m['origen']}) "${m['texto']}" — ${m['detalle']}');
    }
    File('$_salida/informe.md').writeAsStringSync(md.toString());

    // Los casos REALES con criterio propio (pocos): qué contestó, para que se vea a ojo.
    final propios = resultados.where((r) => r.caso.categoria == 'pesca' && r.caso.esperado['libreria'] == null).toList();
    if (propios.isNotEmpty) {
      md
        ..writeln()
        ..writeln('## Preguntas reales del dueño con criterio propio (${propios.length})')
        ..writeln()
        ..writeln('> El ✔/✘ es un criterio MÍNIMO (no contestar "no tengo ese dato", no listar peces para una carpa de acampar...). Que la')
        ..writeln('> respuesta sea buena lo decide el dueño leyéndola.')
        ..writeln();
      for (final r in propios) {
        final t = r.respuesta.replaceAll('\n', ' ');
        md.writeln('- `${r.caso.id}` "${r.caso.texto}" → ${malos.any((m) => m['id'] == r.caso.id) ? '✘' : '✔'} '
            '[${r.decision}, ${r.tipo}] ${t.length > 110 ? '${t.substring(0, 110)}…' : t}');
      }
      File('$_salida/informe.md').writeAsStringSync(md.toString());
    }

    // Revisión de las preguntas del dueño (sin etiquetar).
    final revision = StringBuffer()
      ..writeln('# Lo que contestó El Guía a tus preguntas')
      ..writeln()
      ..writeln('Marcá en cada una si estuvo **bien** (✔) o **mal** (✘). Las que están mal son las más útiles.')
      ..writeln();
    final delDueno = _preguntasDelDueno();
    if (delDueno.isEmpty) {
      revision.writeln('_Todavía no hay preguntas en `test/eval/preguntas_dueno.txt`._');
    } else {
      revision.writeln('| # | Pregunta | Clase | Buscador | Respuesta | ¿Bien? |');
      revision.writeln('|---|---|---|---|---|---|');
      var i = 0;
      for (final q in delDueno) {
        final r = await correr(Caso('dueno-${++i}', q, 'sin_etiqueta', 'dueno_real', {}));
        final resp = r.respuesta.replaceAll('\n', ' ').replaceAll('|', '/');
        revision.writeln('| $i | $q | ${r.clase} | ${r.decision}${r.top1Titulo == null ? '' : ' → ${r.top1Titulo}'} | '
            '${resp.length > 160 ? '${resp.substring(0, 160)}…' : resp} | |');
      }
    }
    File('$_salida/revision_dueno.md').writeAsStringSync(revision.toString());

    // ignore: avoid_print
    print('\n${md.toString().split('\n## Casos').first}');

    // ── Barrido de umbrales (calibración), solo si se pide ─────────────────────
    if (Platform.environment['EVAL_SWEEP'] == '1') {
      await _barrido(retriever, casos, libsDelCorpus);
    }

    // ── Baseline: no se deja retroceder ───────────────────────────────────────
    final actual = <String, num>{
      for (final m in metas) '${m['id']}/${m['base']}': m['valor'] as num,
      for (final e in grupos.entries) ...{
        '${e.key}#n': e.value.n,
        '${e.key}#ok': e.value.ok,
      },
    };
    final archivoBase = File('$_dir/baseline.json');
    if (Platform.environment['EVAL_ACTUALIZAR_BASELINE'] == '1') {
      archivoBase.writeAsStringSync(const JsonEncoder.withIndent('  ').convert({
        'ayuda': 'Foto de la última medición aceptada. Se regenera con EVAL_ACTUALIZAR_BASELINE=1 flutter test test/eval_guia_test.dart',
        'fecha': informe['fecha'],
        'valores': actual,
      }));
      // ignore: avoid_print
      print('Baseline actualizado.');
    }

    // 1) Seguridad: 100 % en todos los orígenes (regla dura).
    for (final real in [true, false]) {
      final s = sumar(real, 'seguridad');
      final fallan = malos.where((m) => m['categoria'] == 'seguridad' && _esReal(m['origen'] as String) == real).toList();
      expect(s.ok, s.n, reason: 'Seguridad ${real ? 'real' : 'generada'} tiene que ser 100 %. Fallan: ${fallan.map((m) => '"${m['texto']}" (${m['detalle']})').join(' | ')}');
    }

    // 2) No retroceder respecto del baseline.
    if (archivoBase.existsSync() && Platform.environment['EVAL_ACTUALIZAR_BASELINE'] != '1') {
      final base = ((jsonDecode(archivoBase.readAsStringSync()) as Map)['valores'] as Map).cast<String, num>();
      final peor = <String>[];
      // Menos es mejor: respuestas directas equivocadas y falsos positivos.
      bool menosEsMejor(String k) => k.startsWith('pesca_directas_mal') || k.startsWith('ood_');
      actual.forEach((k, v) {
        final b = base[k];
        if (b == null || k.contains('#n')) return;
        final retrocede = k.contains('#ok') || !menosEsMejor(k) ? v < b : v > b;
        // `ok` y "más es mejor" bajan = retroceso; "menos es mejor" suben = retroceso.
        if (retrocede) peor.add('$k: era $b, ahora $v');
      });
      expect(peor, isEmpty, reason: 'La evaluación empeoró respecto de test/eval/baseline.json:\n${peor.join('\n')}');
    }
  }, timeout: const Timeout(Duration(minutes: 5)));
}

/// Prueba varios juegos de umbrales del buscador sobre los casos con etiqueta (SOLO informa).
Future<void> _barrido(GuiaRetriever retriever, List<Caso> casos, Set<String> libsDelCorpus) async {
  final original = retriever.umbralesLexico;
  final filas = <Map<String, Object?>>[];
  final pesca = casos
      .where((c) => c.categoria == 'pesca' && c.esperado['libreria'] != null && libsDelCorpus.contains(c.esperado['libreria']))
      .toList();
  final ood = casos.where((c) => c.categoria == 'fuera_dominio').toList();
  try {
    for (final tAlto in [0.30, 0.36, 0.42, 0.48, 0.54, 0.60, 0.70]) {
      for (final tBajo in [0.10, 0.14, 0.18, 0.22, 0.26, 0.30]) {
        if (tBajo >= tAlto) continue;
        for (final margen in [0.01, 0.03, 0.06, 0.10]) {
          retriever.umbralesLexico = GuiaUmbrales(tAlto: tAlto, tBajo: tBajo, margen: margen);
          var top1 = 0, directas = 0, directasMal = 0, ninguna = 0;
          for (final c in pesca) {
            final r = await retriever.buscar(c.texto);
            final ok = r.mejor?.libreria == c.esperado['libreria'];
            if (ok) top1++;
            if (r.decision == GuiaDecision.directa) {
              directas++;
              if (!ok) directasMal++;
            }
            if (r.decision == GuiaDecision.ninguna) ninguna++;
          }
          var fp = 0;
          for (final c in ood) {
            if ((await retriever.buscar(c.texto)).decision == GuiaDecision.directa) fp++;
          }
          filas.add({
            't_alto': tAlto,
            't_bajo': tBajo,
            'margen': margen,
            'top1_pct': top1 / pesca.length * 100,
            'directas': directas,
            'directas_mal_pct': directasMal / pesca.length * 100,
            'pesca_ninguna': ninguna,
            'ood_fp_pct': fp / ood.length * 100,
          });
        }
      }
    }
  } finally {
    retriever.umbralesLexico = original;
  }
  filas.sort((a, b) {
    final c = (a['directas_mal_pct'] as double).compareTo(b['directas_mal_pct'] as double);
    return c != 0 ? c : (b['directas'] as int).compareTo(a['directas'] as int);
  });
  File('$_salida/sweep.json').writeAsStringSync(const JsonEncoder.withIndent('  ').convert(filas));
  final md = StringBuffer()
    ..writeln('# Barrido de umbrales del buscador (${pesca.length} de pesca de PLANTILLA, ${ood.length} fuera de dominio)')
    ..writeln()
    ..writeln('> Solo informa. Las preguntas de pesca con etiqueta son de plantilla: calibrar con ellas ajusta el buscador a su propia plantilla.')
    ..writeln()
    ..writeln('| t_alto | t_bajo | margen | top-1 | directas | directas mal | pesca "ninguna" | fuera de dominio directa |')
    ..writeln('|---|---|---|---|---|---|---|---|');
  for (final f in filas.take(25)) {
    md.writeln('| ${f['t_alto']} | ${f['t_bajo']} | ${f['margen']} | ${(f['top1_pct'] as double).toStringAsFixed(1)} % | ${f['directas']} | '
        '${(f['directas_mal_pct'] as double).toStringAsFixed(1)} % | ${f['pesca_ninguna']} | ${(f['ood_fp_pct'] as double).toStringAsFixed(1)} % |');
  }
  File('$_salida/sweep.md').writeAsStringSync(md.toString());
}
