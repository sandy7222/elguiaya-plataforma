// Paso 1.4 de docs/PLAN_AYUDANTE_IA.md: sin retraso artificial.
//
// El router esperaba entre 400 y 1200 ms antes de contestar con el motor local,
// para simular "pensar". En un celular sin señal eso es tiempo perdido: la
// respuesta offline tiene que salir en < 300 ms. El flag `guia_retraso_artificial`
// (apagado por defecto) lo deja prendible para quien lo quiera.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

const _preguntas = [
  'cómo se hace el nudo palomar',
  'qué carnada uso para el dorado',
  'hola, cómo andás',
  'cuánto sale el dólar hoy',
  'contame del surubí',
  'qué hora es',
  'cómo cambio una rueda del auto',
  'para qué sirve una boya',
  'cómo se hace el chupín de pescado',
  'qué es la sudestada',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
  });

  setUp(() {
    BaqueanoIAService.retrasoArtificial = false;
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = false;
  });

  test('viene apagado', () => expect(BaqueanoIAService.retrasoArtificial, isFalse));

  test('offline: el p95 de ${_preguntas.length} consultas es < 300 ms', () async {
    final tiempos = <int>[];
    for (final p in _preguntas) {
      final reloj = Stopwatch()..start();
      await BaqueanoIAService.responder(p);
      reloj.stop();
      tiempos.add(reloj.elapsedMilliseconds);
    }
    tiempos.sort();
    final p95 = tiempos[(tiempos.length * 0.95).ceil() - 1];
    expect(p95, lessThan(300), reason: 'tiempos ordenados: $tiempos');
  });

  test('prendido, vuelve a esperar entre 400 y 1200 ms', () async {
    BaqueanoIAService.retrasoArtificial = true;
    final reloj = Stopwatch()..start();
    await BaqueanoIAService.responder('cómo se hace el nudo palomar');
    expect(reloj.elapsedMilliseconds, greaterThanOrEqualTo(380));
  });

  test('aplicarFlags lee la preferencia', () async {
    SharedPreferences.setMockInitialValues({BaqueanoIAService.prefRetrasoArtificial: true});
    BaqueanoIAService.aplicarFlags(await SharedPreferences.getInstance());
    expect(BaqueanoIAService.retrasoArtificial, isTrue);
    SharedPreferences.setMockInitialValues({});
    BaqueanoIAService.retrasoArtificial = false;
    BaqueanoIAService.aplicarFlags(await SharedPreferences.getInstance());
    expect(BaqueanoIAService.retrasoArtificial, isFalse);
  });
}
