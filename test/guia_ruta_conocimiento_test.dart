// Paso 4: las preguntas de CONOCIMIENTO DE PESCA (técnica, carnada, especie, equipo) las contesta el motor local (fichas), no la nube.
//
// Medido en el Moto G15: "pesca de mojarra" fue a la nube, que inventó. El router mandaba a la nube TODO lo que no era seguridad,
// transaccional ni condiciones; el motor local (BM25 + fichas + "no tengo ese dato" honesto) solo respondía sin señal. Ahora, con
// o sin señal, el conocimiento de pesca sale de las fichas; si no hay ficha, el Guía lo dice (regla 2: nunca inventar datos). La
// nube queda para la charla. Se apaga con el flag `guia_pesca_local`.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/guia_ruta_conocimiento.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

const _marcaNube = 'RESPUESTA-DE-LA-NUBE-NO-DEBE-USARSE';
int _llamadas = 0;

void _preparar() {
  _llamadas = 0;
  BaqueanoIAService.reiniciarEstadoParaTest();
  BaqueanoIAService.groqParaTest = (p, h) async {
    _llamadas++;
    return const ElGuiaRespuesta(texto: _marcaNube, gifSugerido: 'hablaConMate');
  };
  IARouterState.modoOnline.value = true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
  });
  setUp(() => GuiaRutaConocimiento.habilitado = true);
  tearDown(() {
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = true;
  });

  group('detecta preguntas de conocimiento de pesca', () {
    const si = [
      'pesca de mojarra',
      'cómo se pesca la mojarra',
      'cómo pescar dorado',
      'qué carnada uso para el surubí',
      'con qué anzuelo pesco pejerrey',
      'qué caña me sirve para spinning',
      'cómo hago el nudo palomar',
      'qué señuelo va bien para tararira',
      'dónde pica el bagre',
      'cuál es la mejor técnica para pescar de fondo',
      'cómo armo un aparejo para boga',
      'qué plomada uso en el río',
      'cuándo hay pique de sábalo',
      // Huecos que mostró la prueba del dueño en el celular (iban a la nube):
      'qué peces hay en el Paraná',
      'cuál es el hábitat del dorado',
      'qué especies se pescan en la laguna',
      'cuándo es la veda del surubí',
      'qué cupo hay para el pejerrey',
      'puedo usar lombriz de cebo',
    ];
    for (final p in si) {
      test('sí: "$p"', () => expect(GuiaRutaConocimiento.esConocimientoDePesca(p), isTrue));
    }
    const no = [
      'hola',
      'hola pescador',
      'contame un chiste',
      'gracias',
      'qué hora es',
      'cómo estás',
      'quiero tomar unos mates',
      'cuántos años tenés',
      'qué opinás del fútbol',
    ];
    for (final p in no) {
      test('no: "$p"', () => expect(GuiaRutaConocimiento.esConocimientoDePesca(p), isFalse));
    }
    test('compara palabras enteras ("pescado" de la pescadería no dispara por "pesca")', () {
      expect(GuiaRutaConocimiento.esConocimientoDePesca('comí pescadería rica'), isFalse);
      expect(GuiaRutaConocimiento.esConocimientoDePesca('el cañonazo se oyó lejos'), isFalse);
    });
  });

  group('por intención del motor (aunque la frase no traiga una palabra del vocabulario)', () {
    const conocimiento = [
      'conocer_peces_argentinos', 'habitat', 'peces', 'carnadas', 'canas_y_reeles', 'nudos', 'plomadas', 'boyas',
      'como_pescar_bagre_de_mar_rio', 'como_hago_nudo_rotor_mar', 'cuando_sirve_boya_chica_pejerrey',
      'donde_se_hace_temporada_dorado_rio', 'que_sirve_anzuelo_dorado', 'que_se_hace_luna_nueva_pique',
    ];
    for (final i in conocimiento) {
      test('conocimiento: $i', () {
        expect(GuiaRutaConocimiento.esIntencionDeConocimiento(i), isTrue);
        expect(GuiaRutaConocimiento.debeResponderLocal('lo que sea', intencion: i), isTrue);
      });
    }
    const otras = [
      'fallback', 'saludo', 'saludo_pescador', 'despedida', 'agradecimiento', 'mate', 'chiste', 'charla_cotidiana', 'hora',
      'ayuda_general', 'preguntas_humanas', 'emergencia', 'tienda', 'crear_viaje', 'gps', 'primeros_auxilios', '',
    ];
    for (final i in otras) {
      test('no es conocimiento: "$i"', () {
        expect(GuiaRutaConocimiento.esIntencionDeConocimiento(i), isFalse);
        expect(GuiaRutaConocimiento.debeResponderLocal('lo que sea', intencion: i), isFalse);
      });
    }
    test('con el flag apagado tampoco desvía por intención', () {
      GuiaRutaConocimiento.habilitado = false;
      expect(GuiaRutaConocimiento.debeResponderLocal('x', intencion: 'habitat'), isFalse);
    });
  });

  group('flag guia_pesca_local', () {
    test('apagado: no desvía nada', () {
      GuiaRutaConocimiento.habilitado = false;
      expect(GuiaRutaConocimiento.debeResponderLocal('pesca de mojarra'), isFalse);
    });
    test('encendido: desvía las de pesca', () {
      expect(GuiaRutaConocimiento.debeResponderLocal('pesca de mojarra'), isTrue);
    });
    test('aplicarFlags lee guia_pesca_local', () async {
      SharedPreferences.setMockInitialValues({'guia_pesca_local': false});
      GuiaRutaConocimiento.aplicarFlags(await SharedPreferences.getInstance());
      expect(GuiaRutaConocimiento.habilitado, isFalse);
      SharedPreferences.setMockInitialValues({});
      GuiaRutaConocimiento.habilitado = true;
      GuiaRutaConocimiento.aplicarFlags(await SharedPreferences.getInstance());
      expect(GuiaRutaConocimiento.habilitado, isTrue);
    });
  });

  group('el router: con señal, el conocimiento de pesca NO va a la nube', () {
    const preguntas = [
      'pesca de mojarra',
      'cómo se pesca la mojarra',
      'qué carnada uso para el surubí',
      'cómo hago el nudo palomar',
    ];
    for (final p in preguntas) {
      test('"$p"', () async {
        _preparar();
        final r = await BaqueanoIAService.responder(p);
        expect(_llamadas, 0, reason: 'la nube inventaba conocimiento de pesca');
        expect(r.texto, isNot(contains(_marcaNube)));
        expect(r.texto.trim(), isNotEmpty);
      });
    }

    test('sin ficha, lo dice (no inventa) y no hay recorrido por la tienda', () async {
      _preparar();
      final r = await BaqueanoIAService.responder('qué carnada uso para la mojarra en Neuquén');
      expect(_llamadas, 0);
      final t = r.texto.toLowerCase();
      expect(t, isNot(contains('tienda')));
      expect(t, isNot(contains('info@')));
    });

    test('con el flag apagado vuelve al camino de antes (la nube)', () async {
      GuiaRutaConocimiento.habilitado = false;
      _preparar();
      await BaqueanoIAService.responder('pesca de mojarra');
      expect(_llamadas, 1);
    });

    test('"qué peces hay en el Paraná" (conocer_peces_argentinos) no va a la nube', () async {
      _preparar();
      await BaqueanoIAService.responder('qué peces hay en el Paraná');
      expect(_llamadas, 0);
    });

    test('la charla sigue yendo a la nube', () async {
      _preparar();
      await BaqueanoIAService.responder('qué opinás del fútbol');
      expect(_llamadas, 1);
    });
  });

  test('el router le pasa la intención principal a GuiaRutaConocimiento', () {
    final c = File('lib/services/baqueano_ia_service.dart').readAsStringSync();
    expect(c, contains('GuiaRutaConocimiento.debeResponderLocal(pregunta, intencion: intencionPrincipal)'));
  });

  test('el router usa GuiaRutaConocimiento antes de la nube', () {
    final c = File('lib/services/baqueano_ia_service.dart').readAsStringSync();
    final i = c.indexOf('GuiaRutaConocimiento.debeResponderLocal(');
    final tier2 = c.indexOf('TIER 2: Groq Cloud');
    expect(i, greaterThan(0));
    expect(i, lessThan(tier2));
  });

  test('el flag se carga con los otros guia_*', () {
    expect(File('lib/services/el_guia_engine.dart').readAsStringSync(), contains('GuiaRutaConocimiento.aplicarFlags(prefs)'));
  });
}
