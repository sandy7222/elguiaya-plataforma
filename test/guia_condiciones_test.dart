// Paso 1.0b de docs/PLAN_AYUDANTE_IA.md: lector de condiciones determinista
// (hora, luna, sol, clima).
//
// El Guía no redacta estos datos con una IA: los LEE (reloj del celular,
// `SolunarService`, caché del último pronóstico) y los dice con plantillas.
// Sin señal responde con el pronóstico guardado PARA LA HORA ACTUAL, diciendo de
// cuándo es; si el dato es viejo lo avisa; si no hay, dice que no tiene.
// Seguridad: nunca "ideal" ni "seguro"; si la pregunta es salir o no, manda al
// parte oficial; olas solo si el proveedor las informó.
//
// Este archivo nace en ROJO a propósito: el lector todavía no existe.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/guia_condiciones_service.dart';
import 'package:capitanya_master/services/location_preference_service.dart';
import 'package:capitanya_master/services/solunar_service.dart';
import 'package:capitanya_master/services/weather_service.dart';

final _lugar = LocationDetails(latitude: -34.442, longitude: -58.558, name: 'SAN FERNANDO, BA');
final _ahora = DateTime(2026, 10, 3, 11, 20); // sábado

/// Pronóstico de 72 h que arranca en [desde]: la hora i tiene (15 + i % 10) grados y
/// (10 + i % 7) km/h de viento del sudeste (135°), con ráfagas 8 km/h más fuertes.
ClimaGuardado _guardado({
  required DateTime descargadoEn,
  DateTime? desde,
  bool olas = false,
  double viento = -1,
  double lat = -34.442,
  double lon = -58.558,
}) {
  final inicio = desde ?? DateTime(descargadoEn.year, descargadoEn.month, descargadoEn.day, descargadoEn.hour);
  final horas = [
    for (var i = 0; i < 72; i++)
      HourlyForecast(
        hora: inicio.add(Duration(hours: i)),
        temperatura: 15.0 + i % 10,
        humedad: 60,
        vientoKmH: viento >= 0 ? viento : 10.0 + i % 7,
        vientoNudos: 0,
        rafagasKmH: (viento >= 0 ? viento : 10.0 + i % 7) + 8,
        rafagasNudos: 0,
        direccionViento: 135,
        alturaOlas: olas ? 0.6 : 0,
      ),
  ];
  return ClimaGuardado(
    clima: MarineWeather(
      olajeDisponible: olas,
      obtenidoEn: descargadoEn,
      temperatura: 15,
      velocidadViento: 10,
      direccionViento: 135,
      alturaOlas: olas ? 0.6 : 0,
      humedad: 60,
      presion: 1012,
      descripcion: 'SIN ALERTAS SEGÚN DATOS DISPONIBLES - CONSULTAR PARTE OFICIAL',
      pronosticoExtendido: const [],
      pronosticoHorario: horas,
    ),
    descargadoEn: descargadoEn,
    lat: lat,
    lon: lon,
  );
}

Future<String?> _preguntar(
  String pregunta, {
  DateTime? ahora,
  ClimaGuardado? cache,
  MarineWeather? descarga,
  bool conSenal = false,
}) async {
  final r = await GuiaCondicionesService.responder(
    pregunta,
    ahora: ahora ?? _ahora,
    lugar: _lugar,
    leerCache: () async => cache,
    descargar: conSenal && descarga != null ? (_) async => descarga : (_) async => null,
  );
  return r?.texto;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GuiaCondicionesService.habilitado = true;
  });

  // ── Detección: qué preguntas atiende el lector ─────────────────────────────
  group('detectar', () {
    const positivas = {
      TipoCondicion.hora: [
        'qué hora es',
        'me decís la hora?',
        'che guía, qué hora tenés',
        'qué hora son',
      ],
      TipoCondicion.fecha: ['qué día es hoy', 'a cuánto estamos hoy', 'qué fecha es hoy'],
      TipoCondicion.sol: [
        'a qué hora sale el sol',
        'a qué hora se pone el sol hoy',
        'a qué hora amanece',
        'a qué hora atardece hoy',
      ],
      TipoCondicion.luna: [
        'qué fase de la luna hay hoy',
        'cómo está la luna esta noche',
        'hay luna llena hoy',
        'a qué hora sale la luna',
        'qué luna tenemos hoy',
      ],
      TipoCondicion.solunar: [
        'cuál es la mejor hora para pescar hoy',
        'cuáles son los períodos solunares de hoy',
        'a qué hora conviene pescar hoy',
      ],
      TipoCondicion.clima: [
        'cómo está el clima hoy',
        'qué temperatura hay ahora',
        'cuántos grados hace',
        'cómo está el viento ahora',
        'qué tiempo hace',
        'va a llover hoy',
        'cómo viene el tiempo mañana',
        'hay mucho viento hoy',
        'cómo está el oleaje ahora',
        'cuál es el pronóstico de hoy',
        'puedo salir a pescar hoy, cómo está el clima',
        'hace frío ahora',
      ],
    };
    for (final g in positivas.entries) {
      for (final f in g.value) {
        test('${g.key.name}: "$f"', () => expect(GuiaCondicionesService.detectar(f), g.key));
      }
    }

    // Preguntas de pesca/tiempo que NO piden un dato actual: las sigue contestando
    // el motor de siempre.
    const negativas = [
      'cómo afecta el viento a la pesca',
      'qué carnada uso con viento sur',
      'por qué no pican cuando hay luna llena',
      'cómo influye la luna en la pesca',
      'qué es la sudestada',
      'hoy tengo poco tiempo, qué me recomendás',
      'cuánto tiempo tarda en pescarse un dorado',
      'qué hago si hay tormenta eléctrica',
      'a qué hora abre la tienda',
      'cómo se hace el nudo palomar',
      'qué es el oleaje',
      'a qué temperatura pica el pejerrey',
      'para qué sirve la humedad en la carnada',
      'hola, cómo andás',
      'qué día sale el próximo viaje',
      'cómo preparo la masa para boga',
      'el viento sur es malo para el dorado?',
      'cuándo se pone el sol conviene el señuelo oscuro',
      'qué hora de la tarde es mejor para el surubí',
      'qué es la fase lunar',
    ];
    for (final f in negativas) {
      test('no atiende: "$f"', () => expect(GuiaCondicionesService.detectar(f), isNull));
    }
  });

  // ── Hora y fecha ───────────────────────────────────────────────────────────
  group('hora y fecha: reloj del celular', () {
    test('14:35', () async {
      expect(await _preguntar('qué hora es', ahora: DateTime(2026, 10, 3, 14, 35)), contains('14:35'));
    });
    test('1:05 va en singular', () async {
      final t = await _preguntar('qué hora es', ahora: DateTime(2026, 10, 3, 1, 5));
      expect(t, contains('Es la 1:05'));
    });
    test('9:00 con minutos en dos cifras', () async {
      expect(await _preguntar('qué hora es', ahora: DateTime(2026, 10, 3, 9, 0)), contains('9:00'));
    });
    test('fecha en castellano', () async {
      final t = await _preguntar('qué día es hoy', ahora: DateTime(2026, 10, 3, 9, 0));
      expect(t, contains('sábado'));
      expect(t, contains('3 de octubre'));
    });
  });

  // ── Luna y sol: iguales a SolunarService ───────────────────────────────────
  group('luna y sol: lo que dice SolunarService', () {
    final fechas = [
      DateTime(2026, 1, 3, 10),
      DateTime(2026, 3, 14, 10),
      DateTime(2026, 6, 21, 10),
      DateTime(2026, 9, 7, 10),
      DateTime(2026, 12, 25, 10),
    ];
    for (final f in fechas) {
      test('fase lunar del ${f.day}/${f.month}', () async {
        final info = await SolunarService.calculateSolunar(f, _lugar.latitude, _lugar.longitude);
        final t = (await _preguntar('qué fase de la luna hay hoy', ahora: f))!;
        expect(t.toLowerCase(), contains(info.moonPhaseName.toLowerCase()));
        expect(t, contains('${(info.moonIllumination * 100).round()} por ciento'));
      });
    }
    test('sale y se pone el sol', () async {
      final f = DateTime(2026, 10, 3, 10);
      final info = await SolunarService.calculateSolunar(f, _lugar.latitude, _lugar.longitude);
      final t = (await _preguntar('a qué hora sale el sol', ahora: f))!;
      String hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';
      expect(t, contains(hm(info.sunrise)));
      expect(t, contains(hm(info.sunset)));
    });
    test('períodos solunares: dice de dónde salen y que no es una garantía', () async {
      final t = (await _preguntar('cuál es la mejor hora para pescar hoy'))!;
      expect(t.toLowerCase(), contains('tabla solunar'));
      expect(t.toLowerCase(), contains('no es una garantía'));
    });
  });

  // ── Clima ──────────────────────────────────────────────────────────────────
  group('clima: pronóstico guardado para la hora actual', () {
    test('caché de 2 h: usa la hora actual (11:00 → 17 grados, 12 km/h) y dice cuándo bajó', () async {
      // Bajado a las 9:20; la hora 11 es la i=2: 17 grados y 12 km/h del sudeste.
      final t = (await _preguntar('cómo está el clima hoy', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20))))!;
      expect(t, contains('9:20'));
      expect(t, contains('17 grados'));
      expect(t, contains('12 kilómetros por hora'));
      expect(t.toLowerCase(), contains('sudeste'));
      expect(t, isNot(contains('Ojo')), reason: '2 horas no es dato viejo');
    });

    test('caché de 7 h: avisa que es viejo', () async {
      final t = (await _preguntar('cómo está el clima hoy', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 4, 20))))!;
      expect(t, contains('4:20'));
      expect(t, contains('7 horas'));
      expect(t, contains('Ojo'));
    });

    test('caché de 50 h: dice que no tiene datos vigentes y no inventa números', () async {
      final t = (await _preguntar(
        'cómo está el clima hoy',
        cache: _guardado(descargadoEn: _ahora.subtract(const Duration(hours: 50)), desde: _ahora.subtract(const Duration(hours: 50))),
      ))!;
      expect(t.toLowerCase(), contains('no tengo datos'));
      expect(t, isNot(contains('grados')));
    });

    test('sin caché y sin señal: no tengo datos', () async {
      final t = (await _preguntar('qué temperatura hay ahora'))!;
      expect(t.toLowerCase(), contains('no tengo datos'));
      expect(t, isNot(contains('grados')));
    });

    test('con señal baja el pronóstico fresco y lo usa', () async {
      final fresco = _guardado(descargadoEn: _ahora, desde: DateTime(2026, 10, 3, 11)).clima;
      final t = (await _preguntar(
        'qué temperatura hay ahora',
        cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 4, 20)),
        descarga: fresco,
        conSenal: true,
      ))!;
      expect(t, contains('15 grados'), reason: 'la hora 11 del pronóstico fresco es la i=0: 15 grados');
      expect(t, isNot(contains('Ojo')));
    });

    test('con señal pero la descarga falla: cae al caché', () async {
      final t = (await _preguntar(
        'qué temperatura hay ahora',
        cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20)),
        conSenal: true,
      ))!;
      expect(t, contains('17 grados'));
    });

    test('caché de otro lugar (a más de 30 km): no se usa', () async {
      final t = (await _preguntar(
        'qué temperatura hay ahora',
        cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20), lat: -31.4, lon: -64.2),
      ))!;
      expect(t.toLowerCase(), contains('no tengo datos'));
    });

    test('mañana: usa la hora de mañana en el pronóstico', () async {
      // Mañana 11:00 es la i=26 desde las 9:00 de hoy... desde 9:00 → i=26 → 15+6=21 grados.
      final t = (await _preguntar('cómo viene el tiempo mañana', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20))))!;
      expect(t.toLowerCase(), contains('mañana'));
      expect(t, contains('21 grados'));
    });

    test('olas: solo si el proveedor las informó', () async {
      final sin = (await _preguntar('cómo está el oleaje ahora', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20))))!;
      expect(sin.toLowerCase(), contains('no tengo dato de olas'));
      expect(sin, isNot(contains('metros')));
      final con = (await _preguntar('cómo está el oleaje ahora', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20), olas: true)))!;
      expect(con, contains('0,6 metros'));
    });

    test('lluvia: no hay dato, lo dice', () async {
      final t = (await _preguntar('va a llover hoy', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20))))!;
      expect(t.toLowerCase(), contains('lluvia'));
      expect(t.toLowerCase(), contains('no tengo dato'));
    });

    test('pregunta sobre salir: manda al parte oficial', () async {
      final t = (await _preguntar('puedo salir a pescar hoy, cómo está el clima', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20))))!;
      expect(t, contains('parte oficial'));
      expect(t, contains('SMN'));
      expect(t, contains('Prefectura'));
    });

    test('viento fuerte: avisa con precaución, sin calificar de "bueno"', () async {
      final t = (await _preguntar('cómo está el viento ahora', cache: _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20), viento: 32)))!;
      expect(t.toLowerCase(), contains('fuerte'));
      expect(t, contains('parte oficial'));
    });

    test('sin hora en el pronóstico (caché sin horario) y vieja: no inventa', () async {
      final c = ClimaGuardado(
        clima: MarineWeather(
          temperatura: 12,
          velocidadViento: 9,
          direccionViento: 0,
          alturaOlas: 0,
          humedad: 50,
          presion: 1000,
          descripcion: '',
          pronosticoExtendido: const [],
          pronosticoHorario: const [],
          olajeDisponible: false,
        ),
        descargadoEn: DateTime(2026, 10, 3, 4, 20),
        lat: _lugar.latitude,
        lon: _lugar.longitude,
      );
      final t = (await _preguntar('qué temperatura hay ahora', cache: c))!;
      expect(t.toLowerCase(), contains('no tengo datos'));
    });
  });

  // ── Seguridad de redacción: nada de "ideal" ni "seguro" ────────────────────
  group('seguridad de redacción', () {
    test('ninguna salida dice "ideal" ni "seguro"', () async {
      const preguntas = [
        'qué hora es',
        'qué día es hoy',
        'a qué hora sale el sol',
        'qué fase de la luna hay hoy',
        'cuál es la mejor hora para pescar hoy',
        'cómo está el clima hoy',
        'puedo salir a pescar hoy, cómo está el clima',
        'cómo está el viento ahora',
        'qué temperatura hay ahora',
        'va a llover hoy',
        'cómo está el oleaje ahora',
        'hace frío ahora',
      ];
      final caches = <ClimaGuardado?>[
        null,
        _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20)),
        _guardado(descargadoEn: DateTime(2026, 10, 3, 4, 20), olas: true),
        _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20), viento: 5),
        _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20), viento: 40),
      ];
      var n = 0;
      for (final p in preguntas) {
        for (final c in caches) {
          final t = await _preguntar(p, cache: c);
          expect(t, isNotNull, reason: p);
          expect(t!.toLowerCase(), isNot(contains('ideal')), reason: '"$p" → $t');
          expect(t.toLowerCase(), isNot(contains('seguro')), reason: '"$p" → $t');
          expect(t.toLowerCase(), isNot(contains('segura')), reason: '"$p" → $t');
          n++;
        }
      }
      expect(n, 60);
    });
  });

  // ── Rapidez ────────────────────────────────────────────────────────────────
  test('responde del caché en menos de 300 ms', () async {
    final c = _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20));
    final reloj = Stopwatch()..start();
    for (final p in ['qué hora es', 'qué fase de la luna hay hoy', 'cómo está el clima hoy']) {
      await _preguntar(p, cache: c);
    }
    reloj.stop();
    expect(reloj.elapsedMilliseconds / 3, lessThan(300));
  });

  // ── Caché: ida y vuelta ────────────────────────────────────────────────────
  group('ClimaCache', () {
    test('lo que se guarda se lee igual (actual, horario y diario)', () async {
      final g = _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20), olas: true);
      await ClimaCache.guardar(g.clima, g.lat, g.lon, ahora: g.descargadoEn);
      final l = (await ClimaCache.leer())!;
      expect(l.descargadoEn, g.descargadoEn);
      expect(l.lat, g.lat);
      expect(l.clima.pronosticoHorario.length, 72);
      expect(l.clima.pronosticoHorario[2].temperatura, 17);
      expect(l.clima.olajeDisponible, isTrue);
    });
    test('un clima "no disponible" no pisa el caché bueno', () async {
      final g = _guardado(descargadoEn: DateTime(2026, 10, 3, 9, 20));
      await ClimaCache.guardar(g.clima, g.lat, g.lon, ahora: g.descargadoEn);
      await ClimaCache.guardar(WeatherService.datosNoDisponibles(), g.lat, g.lon);
      expect((await ClimaCache.leer())!.clima.pronosticoHorario.length, 72);
    });
    test('sin nada guardado devuelve null', () async {
      expect(await ClimaCache.leer(), isNull);
    });
  });

  // ── Flag ───────────────────────────────────────────────────────────────────
  group('flag guia_condiciones', () {
    test('viene prendido', () => expect(GuiaCondicionesService.habilitado, isTrue));
    test('apagado no responde nada', () async {
      GuiaCondicionesService.habilitado = false;
      expect(await _preguntar('qué hora es'), isNull);
    });
    test('aplicarFlags lee la preferencia', () async {
      SharedPreferences.setMockInitialValues({GuiaCondicionesService.prefCondiciones: false});
      GuiaCondicionesService.aplicarFlags(await SharedPreferences.getInstance());
      expect(GuiaCondicionesService.habilitado, isFalse);
    });
  });

  // ── Router: antes de la nube, y nunca en una emergencia ────────────────────
  group('router', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await BaqueanoIAService.inicializarParaTest();
      BaqueanoIAService.reiniciarEstadoParaTest();
      GuiaCondicionesService.ahoraParaTest = () => DateTime(2026, 10, 3, 14, 35);
      BaqueanoIAService.groqParaTest = (p, h) async => const ElGuiaRespuesta(texto: 'RESPUESTA DE LA NUBE');
      addTearDown(() => GuiaCondicionesService.ahoraParaTest = null);
    });

    test('"qué hora es" lo contesta el lector, no la nube ni el motor de reglas', () async {
      final r = await BaqueanoIAService.responder('qué hora es');
      expect(r.texto, contains('14:35'));
      expect(r.texto, isNot(contains('NUBE')));
    });

    test('una pregunta de pesca con la palabra "hora" sigue su camino', () async {
      final r = await BaqueanoIAService.responder('qué hora de la tarde es mejor para el surubí');
      expect(r.texto, isNot(contains('14:35')));
    });

    test('una emergencia nunca la atiende el lector', () async {
      for (final f in ['estoy perdido, qué hora es', 'me hundo, cómo está el viento ahora', 'hay una persona al agua, qué hora es']) {
        BaqueanoIAService.reiniciarEstadoParaTest();
        final r = await BaqueanoIAService.responder(f);
        expect(r.texto, isNot(contains('14:35')), reason: f);
        expect(r.texto.toLowerCase(), isNot(contains('grados')), reason: f);
      }
    });
  });
}
