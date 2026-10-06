// Fase 2 (2.3): arma los archivos de test/eval/*.jsonl con lo que YA existía.
//
//   dart run scripts/eval_importar.dart
//
// No inventa preguntas de pesca: carga (1) las preguntas reales del dueño que están en el plan
// y en los tests de oro, (2) las 50 fuera de dominio, (3) las frases de seguridad y
// transaccionales de los tests de la Fase 0 y (4) el conjunto de validación de plantilla, que se
// reporta APARTE porque no son preguntas de usuarios reales. Se corre una vez; después los
// .jsonl son la fuente de verdad (se editan a mano). Si se vuelve a correr, pisa lo importado.

import 'dart:convert';
import 'dart:io';
import '../test/frases_seguridad.dart';

/// Preguntas reales del dueño (docs/PLAN_AYUDANTE_IA.md, paso 0.4 y 2.3).
/// `ambulancia`: la respuesta tiene que traer también el 107 y el 911.
const _dueno = <(String, bool, bool)>[
  // (texto, ambulancia, esSeguridad)
  ('estoy en la isla perdido, cómo consigo agua?', false, true),
  ('cómo hago fuego?', false, false), // suelta NO es seguridad (plan 0.4)
  ('me picó una raya en la pierna qué hago?', true, true),
  ('me mordió una yarará o una víbora qué hago?', true, true),
  ('estoy perdido cómo llamo a prefectura?', false, true),
  ('me corté la piel, cómo paro el sangrado?', true, true),
  ('tengo una fractura, qué hago?', true, true),
  ('cómo llamo a prefectura?', false, true),
  ('cómo pido auxilio?', false, true),
  ('estoy perdido qué hago?', false, true),
  ('se me clavó un anzuelo qué hago?', true, true),
  ('se me clavo una anzuelo', true, true),
  ('algo me picó porque se hincha', true, true),
  ('estoy perdido en la isla, qué puedo hacer para comer?', false, true),
];

String _linea(Map<String, Object?> m) => jsonEncode(m);

void _escribir(String nombre, List<Map<String, Object?>> filas) {
  File('test/eval/$nombre').writeAsStringSync('${filas.map(_linea).join('\n')}\n');
  stdout.writeln('${filas.length.toString().padLeft(4)}  test/eval/$nombre');
}

void main() {
  Directory('test/eval').createSync(recursive: true);
  final yaDueno = _dueno.map((d) => d.$1).toSet();

  // ── Seguridad del dueño ───────────────────────────────────────────────────
  var n = 0;
  _escribir('seguridad_dueno.jsonl', [
    for (final d in _dueno.where((d) => d.$3))
      {
        'id': 'seg-dueno-${(++n).toString().padLeft(3, '0')}',
        'texto': d.$1,
        'categoria': 'seguridad',
        'origen': 'dueno_real',
        'esperado': {'ambulancia': d.$2},
      },
  ]);

  // ── Seguridad escrita por la IA en la Fase 0 ──────────────────────────────
  n = 0;
  final seg = <Map<String, Object?>>[];
  for (final g in frasesSeguridad.entries) {
    final ambulancia = g.key == 'primeros auxilios' || g.key == 'salud sin emergencia';
    for (final f in g.value) {
      if (yaDueno.contains(f)) continue;
      seg.add({
        'id': 'seg-ia-${(++n).toString().padLeft(3, '0')}',
        'texto': f,
        'categoria': 'seguridad',
        'origen': 'generada_ia',
        'grupo': g.key,
        'esperado': {'ambulancia': ambulancia},
      });
    }
  }
  _escribir('seguridad_ia.jsonl', seg);

  // ── Transaccionales ───────────────────────────────────────────────────────
  n = 0;
  _escribir('transaccional.jsonl', [
    for (final f in frasesTransaccionales)
      {
        'id': 'trans-${(++n).toString().padLeft(3, '0')}',
        'texto': f,
        // "cómo cancelo mi reserva" lo preguntó el dueño; el resto lo escribió la IA.
        'categoria': 'transaccional',
        'origen': f == 'cómo cancelo mi reserva' ? 'dueno_real' : 'generada_ia',
        'esperado': <String, Object?>{},
      },
  ]);

  // ── Fuera de dominio ──────────────────────────────────────────────────────
  n = 0;
  _escribir('fuera_dominio.jsonl', [
    for (final l in File('mini_model_lab/retrieval/preguntas_fuera_de_dominio.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty))
      {
        'id': 'ood-${(++n).toString().padLeft(3, '0')}',
        'texto': (jsonDecode(l) as Map)['instruction'],
        'categoria': 'fuera_dominio',
        'origen': 'generada_ia',
        'esperado': {'tipo': 'ninguna'},
      },
  ]);

  // ── Pesca: preguntas reales del dueño que no son de seguridad ─────────────
  _escribir('pesca_real.jsonl', [
    {
      'id': 'pesca-dueno-000',
      'texto': 'cómo hago fuego?',
      'categoria': 'pesca',
      'origen': 'dueno_real',
      'esperado': {'no_seguridad': true},
      'nota': 'suelta NO es seguridad (plan 0.4); la contesta el motor de reglas (fuego)',
    },
    {
      'id': 'pesca-dueno-001',
      'texto': 'cómo se arma una carpa?',
      'categoria': 'pesca',
      'origen': 'dueno_real',
      'esperado': {
        'no_libreria': ['peces'],
        'no_contiene': ['dorado, surubí'],
      },
      'nota': 'es la carpa de acampar; hoy la toma como el pez y lista especies (plan 2.3)',
    },
    {
      'id': 'pesca-dueno-002',
      'texto': 'qué puedo hacer para comer?',
      'categoria': 'pesca',
      'origen': 'dueno_real',
      'esperado': {'no_fallback': true},
      'nota': 'hoy contesta "No tengo esa información" (plan 2.3)',
    },
  ]);

  // ── Pesca de plantilla (NO son preguntas reales: se reporta aparte) ───────
  n = 0;
  _escribir('pesca_plantilla.jsonl', [
    for (final l in File('mini_model_lab/dataset/dataset_validacion_v5.jsonl').readAsLinesSync().where((l) => l.trim().isNotEmpty))
      {
        'id': 'pesca-plantilla-${(++n).toString().padLeft(3, '0')}',
        'texto': (jsonDecode(l) as Map)['instruction'],
        'categoria': 'pesca',
        'origen': 'generada_plantilla',
        'esperado': {'libreria': (jsonDecode(l) as Map)['fuente_libreria']},
      },
  ]);

  // ── Categorías que llenan el dueño y el celular (vacías a propósito) ──────
  for (final nombre in ['multiturno.jsonl', 'voz_dictada.jsonl', 'mezclado.jsonl']) {
    final f = File('test/eval/$nombre');
    if (!f.existsSync()) f.writeAsStringSync('');
    stdout.writeln('   0  test/eval/$nombre (vacío: lo completan el dueño y el Moto G15)');
  }
}
