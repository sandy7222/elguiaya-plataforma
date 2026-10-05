// Paso 1.2c, parte 2: léxico de pronunciación editable (assets/elguia/voz/pronunciacion.json).
//
// El motor de voz pronuncia según la ortografía y no sabe de siglas ("VHF"), de
// palabras en inglés del equipo de pesca ("spinning", "baitcasting", "jig", "leader",
// "kayak") ni de nombres guaraníes. `GuiaTextoVoz.preparar` aplica el léxico antes de
// hablar. Lo edita el dueño: la prueba de oído (parte 3, en su celular) agrega lo que
// suene mal. Lo que se MUESTRA en pantalla no cambia, solo lo que se DICE.
//
// Este archivo nace en ROJO a propósito: el léxico todavía no existe.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_corpus_builder.dart';
import 'package:capitanya_master/services/guia_texto_voz.dart';

const _ruta = 'assets/elguia/voz/pronunciacion.json';

String _v(String t) => GuiaTextoVoz.preparar(t);

List<String> _fichas() {
  final libs = <String, Map<String, dynamic>>{};
  for (final f in Directory('assets/elguia/librerias').listSync()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    final d = json.decode(f.readAsStringSync());
    if (d is Map<String, dynamic>) libs[f.uri.pathSegments.last.replaceAll('.json', '')] = d;
  }
  return GuiaCorpusBuilder.construir(libs).fichas.map((f) => f.texto).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    GuiaTextoVoz.habilitado = true;
    GuiaTextoVoz.limpiarLexico();
  });
  tearDown(GuiaTextoVoz.limpiarLexico);

  group('el archivo del léxico', () {
    late Map<String, dynamic> j;
    setUpAll(() => j = json.decode(File(_ruta).readAsStringSync()) as Map<String, dynamic>);

    test('existe, es JSON válido y trae una ayuda para quien lo edita', () {
      expect(j['ayuda'], isA<String>());
      expect(j['siglas'], isA<Map>());
      expect(j['palabras'], isA<Map>());
    });

    test('trae las siglas del plan (VHF, GPS, SMN, PNA)', () {
      final siglas = (j['siglas'] as Map).cast<String, dynamic>();
      for (final s in ['VHF', 'GPS', 'SMN', 'PNA']) {
        expect(siglas.containsKey(s), isTrue, reason: s);
      }
      expect(siglas['VHF'], 've hache efe');
    });

    test('trae las palabras en inglés del equipo (spinning, baitcasting, jig, leader, kayak)', () {
      final palabras = (j['palabras'] as Map).cast<String, dynamic>();
      for (final p in ['spinning', 'baitcasting', 'jig', 'leader', 'kayak']) {
        expect(palabras.containsKey(p), isTrue, reason: p);
      }
    });

    test('toda sigla de GuiaTextoVoz.siglasConocidas tiene su pronunciación (salvo las que se leen como palabra)', () {
      final siglas = (j['siglas'] as Map).cast<String, dynamic>();
      const seLeenComoPalabra = {'IVA', 'SOS'};
      for (final s in GuiaTextoVoz.siglasConocidas) {
        if (seLeenComoPalabra.contains(s)) continue;
        expect(siglas.containsKey(s), isTrue, reason: 'falta "$s" en el léxico');
      }
    });

    test('todas las entradas son texto no vacío', () {
      for (final grupo in ['siglas', 'palabras']) {
        (j[grupo] as Map).forEach((k, v) {
          expect(k, isNotEmpty);
          expect(v, isA<String>(), reason: '$grupo/$k');
          expect((v as String).trim(), isNotEmpty, reason: '$grupo/$k');
        });
      }
    });
  });

  group('aplicado', () {
    setUp(() => GuiaTextoVoz.cargarLexico(json.decode(File(_ruta).readAsStringSync()) as Map<String, dynamic>));

    test('las siglas se dicen letra por letra', () {
      expect(_v('Llamá al VHF canal 16'), 'Llamá al ve hache efe canal 16');
      expect(_v('El GPS y el SMN no andan; avisá a la PNA'), 'El ge pe ese y el ese eme ene no andan; avisá a la pe ene a');
    });

    test('las palabras en inglés se dicen como suenan en castellano', () {
      expect(_v('Una caña de spinning'), 'Una caña de espínin');
      expect(_v('Pesca con baitcasting'), isNot(contains('baitcasting')));
      expect(_v('Pesca en kayak'), isNot(contains('kayak')));
    });

    test('no distingue mayúsculas en las palabras, y conserva la inicial', () {
      expect(_v('Spinning liviano'), startsWith('Espínin'));
      expect(_v('SPINNING'), 'espínin');
    });

    test('las siglas distinguen mayúsculas (una palabra que se escribe igual no se toca)', () {
      GuiaTextoVoz.cargarLexico({
        'siglas': {'IVA': 'iva'},
        'palabras': <String, dynamic>{},
      });
      expect(_v('el gps anda'), 'el gps anda');
    });

    test('solo palabras enteras: "jig" no pisa a "jigging" ni a otra palabra que lo contiene', () {
      final jig = (json.decode(File(_ruta).readAsStringSync())['palabras'] as Map)['jig'] as String;
      final jigging = (json.decode(File(_ruta).readAsStringSync())['palabras'] as Map)['jigging'] as String?;
      expect(_v('un jig pesado'), 'un $jig pesado');
      if (jigging != null) expect(_v('reel de jigging'), contains(jigging));
      expect(_v('el jigsaw'), 'el jigsaw', reason: 'jigsaw no es jig');
    });

    test('no toca los números ni las unidades', () {
      expect(_v('VHF 16, 12 km/h'), 've hache efe 16, 12 kilómetros por hora');
    });

    test('es idempotente', () {
      for (final t in ['Llamá al VHF canal 16', 'Pesca de spinning y baitcasting', 'El GPS del kayak']) {
        final una = _v(t);
        expect(_v(una), una);
      }
    });

    test('sobre las 342 fichas: ningún número se pierde y no quedan siglas del léxico sin decir', () {
      final siglas = ((json.decode(File(_ruta).readAsStringSync())['siglas']) as Map).keys.cast<String>();
      for (final t in _fichas()) {
        final s = _v(t);
        final salida = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)!).toSet();
        final sinLista = t.replaceAll(RegExp(r'(^|\n)\s*\d+[.)]\s', multiLine: true), '\n').replaceAll('1/2', 'medio');
        for (final m in RegExp(r'\d+').allMatches(sinLista)) {
          expect(salida.contains(m.group(0)), isTrue, reason: '${m.group(0)} en "${t.length > 50 ? t.substring(0, 50) : t}"');
        }
        for (final sigla in siglas) {
          expect(RegExp('(?<![A-Za-zÁÉÍÓÚÑ])$sigla(?![A-Za-zÁÉÍÓÚÑ])').hasMatch(s), isFalse, reason: 'quedó "$sigla": $s');
        }
      }
    });
  });

  group('robustez', () {
    test('sin léxico cargado el texto sale como siempre', () {
      expect(_v('Llamá al VHF canal 16'), 'Llamá al VHF canal 16');
    });

    test('un léxico mal formado se ignora sin romper', () {
      GuiaTextoVoz.cargarLexico({'siglas': 'no es un mapa', 'palabras': 3});
      expect(_v('Llamá al VHF canal 16'), 'Llamá al VHF canal 16');
      GuiaTextoVoz.cargarLexico({
        'siglas': {'VHF': '', 'GPS': 7, 'SMN': 'ese eme ene'},
        'palabras': {'': 'x'},
      });
      expect(_v('VHF GPS SMN'), 'VHF GPS ese eme ene', reason: 'las entradas inválidas se saltean, las buenas valen');
    });

    test('el dueño puede sumar una palabra y se aplica de inmediato', () {
      GuiaTextoVoz.cargarLexico({
        'siglas': <String, dynamic>{},
        'palabras': {'Traful': 'trafúl'},
      });
      // Se capitaliza porque el original lo estaba y "decir" va en minúscula.
      expect(_v('en el lago Traful'), 'en el lago Trafúl');
    });

    test('con el flag apagado no se aplica nada', () {
      GuiaTextoVoz.cargarLexico({
        'siglas': {'VHF': 've hache efe'},
        'palabras': <String, dynamic>{},
      });
      GuiaTextoVoz.habilitado = false;
      expect(_v('VHF'), 'VHF');
    });

    test('el motor carga el léxico de los assets al iniciar (así lo usa la voz en la app)', () async {
      await ElGuiaEngine().inicializar();
      expect(_v('Llamá al VHF canal 16'), 'Llamá al ve hache efe canal 16');
    });

    test('el archivo está declarado como asset en pubspec.yaml', () {
      expect(File('pubspec.yaml').readAsStringSync(), contains('assets/elguia/voz/'));
    });
  });
}
