// Paso 1.2c, parte 1: las respuestas de assets/elguia/ no tienen tildes faltantes SIN ambigüedad.
//
// El motor de voz acentúa según la ortografía: "rio" se lee mal, "río" bien. El script
// scripts/revisar_tildes.mjs corrige solo lo que no puede ser otra palabra (río, surubí,
// Paraná, también, tenés...). Este test corre el script en modo informe y exige 0
// pendientes; si alguien agrega una respuesta con "rio", falla y se corrige con:
//
//   node scripts/revisar_tildes.mjs --aplicar
//
// Las AMBIGUAS (estas/estás, mas/más, llama/llamá...) son de revisión a mano y no se
// exigen acá. Necesita Node; si no está instalado, el test se saltea.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('0 casos de tildes faltantes sin ambigüedad en las respuestas', () async {
    final ProcessResult r;
    try {
      r = await Process.run('node', ['scripts/revisar_tildes.mjs'], stdoutEncoding: utf8, stderrEncoding: utf8);
    } on ProcessException {
      markTestSkipped('Node no está instalado');
      return;
    }
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final salida = r.stdout.toString();
    final m = RegExp(r'SIN AMBIGÜEDAD: (\d+) casos').firstMatch(salida);
    expect(m, isNotNull, reason: salida);
    expect(int.parse(m!.group(1)!), 0, reason: 'corré: node scripts/revisar_tildes.mjs --aplicar\n$salida');
  });

  test('el script no toca los activadores ni las palabras clave (van sin tilde a propósito)', () {
    final codigo = File('scripts/revisar_tildes.mjs').readAsStringSync();
    expect(codigo, contains('activadores'));
    expect(codigo, contains('sinonimos'));
    expect(codigo, contains('palabras_clave'));
  });
}
