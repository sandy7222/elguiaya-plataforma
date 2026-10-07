// Paso 1.6 de docs/PLAN_AYUDANTE_IA.md: circuit breaker + timeout de 6 s para la nube.
//
// Si Groq falla o tarda, la nube queda "abierta" 60 s (si vuelve a fallar al
// probarla, 5 min) y mientras tanto se va directo al motor offline, sin esperar.
// Si el servidor dice 402 o 429 (sin cuota / demasiados pedidos) se abre de
// inmediato, por 5 min. Con un proxy caído: primera respuesta ≤ 6 s, las
// siguientes < 300 ms.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

// Paso 4: el conocimiento de pesca ya no va a la nube (lo contesta el motor local), así que estos casos usan charla
// ('fútbol', 'cuento') como pregunta que SÍ llega a la nube. Lo que prueban (el breaker) no cambia.
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/groq_service.dart';
import 'package:capitanya_master/services/ia_breaker.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

final _t0 = DateTime(2026, 10, 4, 10);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    IABreaker.habilitado = true;
    IABreaker.reiniciar();
  });

  // ── El breaker solo ────────────────────────────────────────────────────────
  group('IABreaker', () {
    test('cerrado al principio: deja llamar', () => expect(IABreaker.permite(_t0), isTrue));

    test('un fallo lo abre 60 s', () {
      IABreaker.registrarFallo(_t0);
      expect(IABreaker.permite(_t0.add(const Duration(seconds: 1))), isFalse);
      expect(IABreaker.permite(_t0.add(const Duration(seconds: 59))), isFalse);
      expect(IABreaker.permite(_t0.add(const Duration(seconds: 61))), isTrue, reason: 'pasados los 60 s se prueba una vez');
    });

    test('mientras se prueba, los demás pedidos siguen yendo al offline', () {
      IABreaker.registrarFallo(_t0);
      final tras = _t0.add(const Duration(seconds: 61));
      expect(IABreaker.permite(tras), isTrue, reason: 'el que prueba');
      expect(IABreaker.permite(tras), isFalse, reason: 'el siguiente espera el resultado');
    });

    test('si la prueba también falla: 5 min', () {
      IABreaker.registrarFallo(_t0);
      final prueba = _t0.add(const Duration(seconds: 61));
      expect(IABreaker.permite(prueba), isTrue);
      IABreaker.registrarFallo(prueba);
      expect(IABreaker.permite(prueba.add(const Duration(minutes: 4, seconds: 59))), isFalse);
      expect(IABreaker.permite(prueba.add(const Duration(minutes: 5, seconds: 1))), isTrue);
    });

    test('si la prueba sale bien: se cierra y vuelve a empezar de 60 s', () {
      IABreaker.registrarFallo(_t0);
      final prueba = _t0.add(const Duration(seconds: 61));
      expect(IABreaker.permite(prueba), isTrue);
      IABreaker.registrarExito();
      expect(IABreaker.permite(prueba), isTrue);
      expect(IABreaker.permite(prueba), isTrue, reason: 'cerrado: no hay límite de pedidos');
      IABreaker.registrarFallo(prueba);
      expect(IABreaker.permite(prueba.add(const Duration(seconds: 61))), isTrue, reason: 'de nuevo 60 s, no 5 min');
    });

    test('402 y 429 lo abren de inmediato, por 5 min', () {
      for (final status in [402, 429]) {
        IABreaker.reiniciar();
        IABreaker.registrarFallo(_t0, status: status);
        expect(IABreaker.permite(_t0.add(const Duration(minutes: 4, seconds: 59))), isFalse, reason: '$status');
        expect(IABreaker.permite(_t0.add(const Duration(minutes: 5, seconds: 1))), isTrue, reason: '$status');
      }
    });

    test('otros códigos (500, 503) abren 60 s', () {
      IABreaker.registrarFallo(_t0, status: 503);
      expect(IABreaker.permite(_t0.add(const Duration(seconds: 59))), isFalse);
      expect(IABreaker.permite(_t0.add(const Duration(seconds: 61))), isTrue);
    });

    test('esFalloInmediato reconoce las excepciones de Groq con 402/429', () {
      expect(IABreaker.estadoDe(const GroqEstadoException(429, 'x')), 429);
      expect(IABreaker.estadoDe(const GroqEstadoException(402, 'x')), 402);
      expect(IABreaker.estadoDe(const GroqEstadoException(500, 'x')), 500);
      expect(IABreaker.estadoDe(TimeoutException('x')), isNull);
      expect(IABreaker.estadoDe(StateError('x')), isNull);
    });

    test('apagado (flag): siempre deja llamar y no registra nada', () {
      IABreaker.habilitado = false;
      IABreaker.registrarFallo(_t0, status: 429);
      expect(IABreaker.permite(_t0), isTrue);
    });

    test('el timeout es de 6 s (12 s con el flag apagado)', () {
      expect(IABreaker.timeoutNube, const Duration(seconds: 6));
      IABreaker.habilitado = false;
      expect(IABreaker.timeoutNube, const Duration(seconds: 12));
    });

    test('aplicarFlags lee la preferencia', () async {
      SharedPreferences.setMockInitialValues({IABreaker.prefBreaker: false});
      IABreaker.aplicarFlags(await SharedPreferences.getInstance());
      expect(IABreaker.habilitado, isFalse);
    });
  });

  // ── En el router: con la nube caída ────────────────────────────────────────
  group('router con la nube caída', () {
    var llamadasANube = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await BaqueanoIAService.inicializarParaTest();
      BaqueanoIAService.reiniciarEstadoParaTest();
      BaqueanoIAService.retrasoArtificial = false;
      IARouterState.modoOnline.value = true;
      IABreaker.reiniciar();
      llamadasANube = 0;
    });
    tearDown(() {
      BaqueanoIAService.groqParaTest = null;
      IABreaker.timeoutParaTest = null;
    });

    Future<int> milisegundos(String pregunta) async {
      final reloj = Stopwatch()..start();
      await BaqueanoIAService.responder(pregunta);
      return reloj.elapsedMilliseconds;
    }

    test('si la nube tira un error: el primer pedido la prueba; los siguientes van directo al offline', () async {
      BaqueanoIAService.groqParaTest = (p, h) async {
        llamadasANube++;
        throw Exception('proxy caído');
      };
      await BaqueanoIAService.responder('contame del fútbol');
      expect(llamadasANube, 1);
      for (var i = 0; i < 4; i++) {
        final ms = await milisegundos('qué opinás del fútbol número $i');
        expect(ms, lessThan(300));
      }
      expect(llamadasANube, 1, reason: 'con el breaker abierto no se vuelve a llamar a la nube');
    });

    test('si la nube se cuelga: la primera respuesta sale dentro del timeout; las siguientes < 300 ms', () async {
      IABreaker.timeoutParaTest = const Duration(milliseconds: 400);
      BaqueanoIAService.groqParaTest = (p, h) {
        llamadasANube++;
        return Completer<ElGuiaRespuesta>().future; // nunca responde
      };
      final primera = await milisegundos('contame del fútbol');
      expect(primera, lessThan(1500), reason: 'esperó el timeout (400 ms) y contestó con el motor local');
      expect(primera, greaterThanOrEqualTo(380));
      final segunda = await milisegundos('qué opinás del fútbol');
      expect(segunda, lessThan(300));
      expect(llamadasANube, 1);
    });

    test('429: abre de inmediato; cuando pasan los 5 min se prueba de nuevo', () async {
      BaqueanoIAService.groqParaTest = (p, h) async {
        llamadasANube++;
        throw const GroqEstadoException(429, 'Límite de consultas alcanzado');
      };
      await BaqueanoIAService.responder('contame del fútbol');
      await BaqueanoIAService.responder('qué opinás del fútbol');
      expect(llamadasANube, 1);
      IABreaker.relojParaTest = () => DateTime.now().add(const Duration(minutes: 6));
      addTearDown(() => IABreaker.relojParaTest = null);
      await BaqueanoIAService.responder('contame un cuento corto');
      expect(llamadasANube, 2, reason: 'pasados los 5 min el breaker deja pasar una prueba');
    });

    test('con la nube andando, el breaker queda cerrado y se llama siempre', () async {
      BaqueanoIAService.groqParaTest = (p, h) async {
        llamadasANube++;
        return const ElGuiaRespuesta(texto: 'Respuesta de la nube.');
      };
      for (var i = 0; i < 3; i++) {
        final r = await BaqueanoIAService.responder('contame del fútbol número $i');
        expect(r.texto, contains('nube'));
      }
      expect(llamadasANube, 3);
    });

    test('con el flag apagado se llama a la nube aunque haya fallado antes', () async {
      IABreaker.habilitado = false;
      BaqueanoIAService.groqParaTest = (p, h) async {
        llamadasANube++;
        throw Exception('proxy caído');
      };
      for (var i = 0; i < 3; i++) {
        await BaqueanoIAService.responder('contame del fútbol número $i');
      }
      expect(llamadasANube, 3);
    });

    test('una emergencia nunca espera a la nube (el portón va antes)', () async {
      BaqueanoIAService.groqParaTest = (p, h) async {
        llamadasANube++;
        throw Exception('x');
      };
      await BaqueanoIAService.responder('me hundo, auxilio');
      expect(llamadasANube, 0);
    });
  });
}
