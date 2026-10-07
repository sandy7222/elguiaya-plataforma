// Paso 1.8: la nube no puede inventar datos ni citar fuentes que la app no le dio.
//
// Caso real (prueba del dueño en el Moto G15, 2026-10-07): ante "cómo está la pesca el día de hoy" la nube
// contestó "Según el parte oficial, hoy en Glew la temperatura es de 16 °C, humedad 98 % y viento 24 km/h del este.
// El nivel del río está medio, con aguas algo turbias." Los números del clima venían del lector del 1.0b; el
// "parte oficial" y el nivel y la turbidez del río NO existen en ningún dato que la app le dé: rompe la regla 2 de
// AGENTS.md ("nunca inventar datos").
//
// Tres capas (cada una con sus tests):
//   1. Prompt: lista de los datos que la app le da y prohibición de citar lo que no está en esa lista.
//   2. Verificador posterior: reemplaza lo que no está respaldado por "Ese dato no lo tengo; consultalo en el parte oficial."
//   3. Ruteo: "cómo está la pesca hoy" y parecidas las atiende primero el lector de condiciones (datos reales).
//
// Este archivo nace en ROJO a propósito: el verificador todavía no existe.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/guia_condiciones_service.dart';
import 'package:capitanya_master/services/guia_verificador_datos.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

/// Lo que la app le manda a la nube en un caso típico (lector de condiciones del 1.0b).
const _contexto = '[CONDICIONES REALES EN SAN FERNANDO, BA] Hora local: 14:07. Temp: 16°C, Humedad: 98%, '
    'Viento: 24 km/h del este, Olas: sin dato. Fase lunar: Cuarto Menguante (50% iluminada). '
    'No digas que es ideal ni seguro salir: recomendá el parte oficial.';

const _noLoTengo = GuiaVerificadorDatos.reemplazo;

String _v(String r, {String contexto = _contexto, String pregunta = 'cómo está la pesca hoy'}) =>
    GuiaVerificadorDatos.verificar(r, contexto: '$contexto\n$pregunta').texto;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── El caso real ───────────────────────────────────────────────────────────
  group('el caso real del dueño', () {
    const real = 'Según el parte oficial, hoy en Glew (Buenos Aires) la temperatura es de 16 °C, humedad 98 % y viento '
        '24 km/h del este. El nivel del río está medio, con aguas algo turbias. Con estas condiciones el dorado suele '
        'buscar comederos en zonas claras, mientras que el surubí sigue activo en el fondo con corriente.';

    test('se saca la fuente inventada y el nivel/turbidez del río', () {
      final s = _v(real);
      expect(s.toLowerCase(), isNot(contains('según el parte oficial')));
      expect(s.toLowerCase(), isNot(contains('nivel del río')));
      expect(s.toLowerCase(), isNot(contains('turbias')));
      expect(s, contains(_noLoTengo));
    });

    test('se conservan los números que SÍ le dio la app', () {
      final s = _v(real);
      expect(s, contains('16'));
      expect(s, contains('98'));
      expect(s, contains('24 km/h'));
    });

    test('se conserva el consejo de pesca general', () {
      expect(_v(real), contains('el dorado suele buscar comederos'));
    });

    test('el reemplazo aparece una sola vez', () {
      expect(_noLoTengo.allMatches(_v(real)).length, 1);
    });
  });

  // ── Variantes: todas tienen que corregirse ─────────────────────────────────
  group('variantes que inventan', () {
    const inventadas = <String, String>{
      'según Prefectura el río está en 2,3 m': 'Prefectura',
      'Según la Prefectura Naval, hoy hay alerta por sudestada.': 'Prefectura',
      'El SMN indica viento de 35 km/h para la tarde.': '35',
      'De acuerdo con el SMN, mañana llueve todo el día.': 'SMN',
      'El INA informa una crecida del río Paraná.': 'INA',
      'Según el Instituto Nacional del Agua el río viene bajando.': 'Instituto',
      'El parte oficial indica que el río está en 3 metros.': 'parte oficial indica',
      'El nivel del río está alto y con mucha correntada.': 'nivel del río',
      'La altura del río hoy es de 2,10 m.': 'altura del río',
      'El caudal es de 15.000 m³/s.': 'caudal',
      'Hay una crecida importante en el Paraná.': 'crecida',
      'La temperatura del agua es de 18 °C.': '18',
      'Hay olas de 1,2 metros en la costa.': 'olas',
      'La pleamar es a las 18:20.': '18:20',
      'El sol sale a las 6:32 y se pone a las 19:41.': '6:32',
      'La veda del surubí empieza el 1 de noviembre.': 'veda',
      'El viento es de 40 km/h con ráfagas de 60 km/h.': '40',
      'Hoy hay 25 °C en la zona.': '25',
      'La presión está en 1015 hPa.': '1015',
      'La turbidez del agua es alta hoy.': 'turbidez',
    };
    for (final c in inventadas.entries) {
      test('"${c.key}"', () {
        final s = _v(c.key);
        expect(s, contains(_noLoTengo), reason: s);
        expect(s, isNot(contains(c.value)), reason: 'quedó "${c.value}": $s');
      });
    }
  });

  // ── Lo que NO se toca ──────────────────────────────────────────────────────
  group('lo legítimo se conserva intacto', () {
    const legitimas = [
      'Consultá el parte oficial del SMN o de Prefectura antes de salir.',
      'Revisá el parte oficial antes de zarpar.',
      'Hoy hay 16 °C, humedad del 98 % y viento de 24 km/h del este.',
      'Con 16,2 grados y viento del este, el dorado suele estar cerca de los remansos.',
      'Usá línea de 0,30 mm y un anzuelo número 4 para el pejerrey.',
      'El dorado pica mejor con luna llena y carnada viva.',
      'Una caña de 2,10 m es buena para spinning liviano.',
      'Con sudestada el río crece: fijate siempre el estado del río antes de salir.',
      'Respetá las vedas vigentes de cada zona.',
      'El surubí se alimenta en el fondo, cerca de los pozos.',
      'Llevá agua, protector solar y un abrigo.',
    ];
    for (final t in legitimas) {
      test('"$t"', () => expect(_v(t), t));
    }

    test('un número que dijo el usuario en su pregunta es suyo: se acepta', () {
      expect(_v('Entonces con esos 28 km/h conviene ir con cuidado.', pregunta: 'hay 28 km/h de viento, salgo?'),
          'Entonces con esos 28 km/h conviene ir con cuidado.');
    });

    test('un número redondeado a partir del dato de la app se acepta (16,2 → 16)', () {
      expect(_v('La temperatura anda en 16 grados.', contexto: 'Temp: 16,2°C'), 'La temperatura anda en 16 grados.');
    });

    test('una fecha o dato que sí está en el contexto no se toca', () {
      expect(_v('El sol sale a las 6:29.', contexto: 'sol sale 6:29 y se pone 18:59'), 'El sol sale a las 6:29.');
    });
  });

  group('propiedades', () {
    test('es idempotente', () {
      const t = 'Según el parte oficial, hay 40 km/h. El nivel del río está medio. El dorado pica.';
      final una = _v(t);
      expect(_v(una), una);
    });
    test('vacío queda vacío', () => expect(_v(''), ''));
    test('informa qué corrigió', () {
      final r = GuiaVerificadorDatos.verificar('El caudal es de 15.000 m³/s. El dorado pica.', contexto: _contexto);
      expect(r.corrigio, isTrue);
      expect(r.reemplazos, isNotEmpty);
      final limpia = GuiaVerificadorDatos.verificar('El dorado pica.', contexto: _contexto);
      expect(limpia.corrigio, isFalse);
    });
    test('si todo era inventado, queda solo el aviso (nunca vacío)', () {
      final s = _v('El nivel del río está alto.');
      expect(s, _noLoTengo);
    });
  });

  // ── Capa 1: el prompt ──────────────────────────────────────────────────────
  group('el prompt', () {
    final reglas = GuiaVerificadorDatos.reglasDeDatos;
    test('lista los datos que la app SÍ da', () {
      for (final dato in ['hora', 'temperatura', 'viento', 'humedad', 'luna']) {
        expect(reglas.toLowerCase(), contains(dato), reason: dato);
      }
    });
    test('prohíbe citar fuentes y mediciones que no estén en esa lista', () {
      final r = reglas.toLowerCase();
      expect(r, contains('prohibido'));
      for (final x in ['parte oficial', 'prefectura', 'smn', 'ina', 'nivel del río', 'caudal', 'veda']) {
        expect(r, contains(x), reason: x);
      }
      expect(r, contains(_noLoTengo.toLowerCase()));
    });
    test('GroqService la agrega al prompt y aplica el verificador a lo que contesta la nube', () {
      final codigo = File('lib/services/groq_service.dart').readAsStringSync();
      expect(codigo, contains('GuiaVerificadorDatos.reglasDeDatos'));
      expect(codigo, contains('GuiaVerificadorDatos.verificar('));
    });
  });

  // ── Capa 3: el ruteo ───────────────────────────────────────────────────────
  group('"cómo está la pesca hoy" pasa primero por el lector de condiciones', () {
    const preguntas = [
      'cómo está la pesca el día de hoy',
      'cómo está la pesca hoy',
      'qué tal la pesca hoy',
      'cómo viene la pesca hoy',
      'está bueno para pescar hoy',
      'hay pique hoy',
      'conviene pescar hoy',
      'cómo anda la pesca ahora',
      'cómo está el día para pescar',
    ];
    for (final p in preguntas) {
      test('detecta: "$p"', () => expect(GuiaCondicionesService.detectar(p), TipoCondicion.pesca));
    }
    const noSon = [
      'cómo se pesca el dorado',
      'qué carnada uso hoy para pescar',
      'cómo pesco con viento',
      'cuál es la mejor hora para pescar',
      'por qué no hay pique cuando hay luna llena',
    ];
    for (final p in noSon) {
      test('no es esta: "$p"', () => expect(GuiaCondicionesService.detectar(p), isNot(TipoCondicion.pesca)));
    }

    test('el router la contesta SIN llamar a la nube, con datos reales o diciendo que no los tiene', () async {
      SharedPreferences.setMockInitialValues({});
      await BaqueanoIAService.inicializarParaTest();
      BaqueanoIAService.reiniciarEstadoParaTest();
      IARouterState.modoOnline.value = true;
      GuiaCondicionesService.habilitado = true;
      var llamadas = 0;
      BaqueanoIAService.groqParaTest = (p, h) async {
        llamadas++;
        return const ElGuiaRespuesta(texto: 'Según el parte oficial el río está medio.');
      };
      final r = await BaqueanoIAService.responder('cómo está la pesca el día de hoy');
      expect(llamadas, 0, reason: 'la nube no tiene que inventar sobre esto');
      final t = r.texto.toLowerCase();
      expect(t, isNot(contains('según el parte oficial')));
      expect(t, isNot(contains('nivel del río')));
      expect(t, anyOf(contains('no tengo datos'), contains('grados')));
      expect(t, contains('pique'), reason: 'tiene que decir que del pique no hay dato medido');
    });
  });
}
