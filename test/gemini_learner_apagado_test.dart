// El aprendizaje automático queda APAGADO por flag (`guia_aprendizaje_auto`, por defecto false).
//
// Medido en el Moto G15 (docs/ESTADO.md): ante "pesca de mojarra" la nube inventó una respuesta y `GeminiLearner` la guardó como
// conocimiento "pendiente" (el registro mostró "Nueva intención incubando: como_pescar_mojarra" y "Conocimiento auto-guardado en
// Supabase"). A la 3.ª vez se consolida y el motor offline la sirve como verdad. AGENTS.md regla 2: nunca inventar datos.
// Mientras no haya una verificación de lo aprendido, el Guía no aprende solo.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/gemini_learner.dart';

Map<String, dynamic> _bloque() => {
      'intencion': 'como_pescar_mojarra',
      'activadores': ['pesca de mojarra', 'como pescar mojarra'],
      'respuesta_limpia': 'Respuesta de prueba corta y clara para un pescador.',
      'gif': 'hablaConMate',
      'puntaje': 9,
      'fuente': 'groq_sesion',
    };

Future<String> _evento(Future<void> Function() accion) async {
  final eventos = <String>[];
  GeminiLearner.observadorParaTest = eventos.add;
  try {
    await accion();
  } finally {
    GeminiLearner.observadorParaTest = null;
  }
  return eventos.isEmpty ? 'nada' : eventos.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeminiLearner.aprendizajeAutomatico = false;
  });

  test('por defecto está apagado', () {
    expect(GeminiLearner.aprendizajeAutomatico, isFalse);
  });

  test('apagado: procesar no guarda nada (ni local ni en Supabase)', () async {
    expect(await _evento(() => GeminiLearner.procesar(_bloque(), 'pesca de mojarra')), 'apagado');
  });

  test('apagado: evaluarYGuardar con un bloque |||APRENDO||| tampoco aprende', () async {
    const respuesta = 'La mojarra pica con lombriz. |||APRENDO|||'
        '{"intencion":"como_pescar_mojarra","activadores":["pesca de mojarra"],"respuesta_limpia":"inventado","puntaje":9}';
    expect(await _evento(() => GeminiLearner.evaluarYGuardar('pesca de mojarra', respuesta)), 'apagado');
  });

  test('encendido por flag: vuelve a procesar (se puede reactivar)', () async {
    GeminiLearner.aprendizajeAutomatico = true;
    final e = await _evento(() => GeminiLearner.procesar(_bloque(), 'pesca de mojarra'));
    expect(e, isNot('apagado'));
  });

  test('aplicarFlags lee guia_aprendizaje_auto', () async {
    SharedPreferences.setMockInitialValues({'guia_aprendizaje_auto': true});
    GeminiLearner.aplicarFlags(await SharedPreferences.getInstance());
    expect(GeminiLearner.aprendizajeAutomatico, isTrue);
    SharedPreferences.setMockInitialValues({});
    GeminiLearner.aprendizajeAutomatico = false;
    GeminiLearner.aplicarFlags(await SharedPreferences.getInstance());
    expect(GeminiLearner.aprendizajeAutomatico, isFalse);
  });

  test('el flag se carga al arrancar el motor, junto a los otros guia_*', () {
    expect(File('lib/services/el_guia_engine.dart').readAsStringSync(), contains('GeminiLearner.aplicarFlags(prefs)'));
  });
}
