// Paso 1.2b de docs/PLAN_AYUDANTE_IA.md: texto para voz, en un solo lugar.
//
// `VoiceService.speak` borraba los símbolos sin traducirlos: "50 %" se leía
// "cincuenta", "18 °C" "dieciocho ce", "12 km/h" "doce kmh", "$15.000" "pesos quince
// mil", "1." "uno punto", y los títulos en MAYÚSCULAS algunos motores los deletrean.
// Además `audio_service.dart` y `voz_service.dart` hablaban sin ninguna limpieza.
// `GuiaTextoVoz.preparar` es la única función que prepara lo que se DICE (lo que se
// muestra en pantalla lo limpia el presentador, 1.2).
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_corpus_builder.dart';
import 'package:capitanya_master/services/guia_texto_voz.dart';

String _v(String t) => GuiaTextoVoz.preparar(t);

final _emoji = RegExp('[\u{1F000}-\u{1FFFF}\u{2190}-\u{21FF}\u{2300}-\u{23FF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE0F}\u{200D}]', unicode: true);
final _prohibidos = RegExp('["\'“”‘’«»*_#`~|<>\\[\\]{}%°\$=+]');
final _numeracion = RegExp(r'(^|\n)\s*(\d+[.)]|[-•·▪●])\s', multiLine: true);

List<String> _fichas() {
  final libs = <String, Map<String, dynamic>>{};
  for (final f in Directory('assets/elguia/librerias').listSync()) {
    if (f is! File || !f.path.endsWith('.json')) continue;
    final d = json.decode(f.readAsStringSync());
    if (d is Map<String, dynamic>) libs[f.uri.pathSegments.last.replaceAll('.json', '')] = d;
  }
  return GuiaCorpusBuilder.construir(libs).fichas.map((f) => f.texto).toList();
}

/// Respuestas típicas de Groq: comillas, emojis, negritas, listas, símbolos.
const _groq = [
  'Mirá, chamigo: el *dorado* pica mejor con luna llena 🌕. Usá "carnada viva" y paciencia.',
  '**Consejo:** con viento de 25 km/h conviene anclar en un lugar abrigado ⚓.',
  '1. Armá la línea\n2. Atá el anzuelo\n3. Lanzá suave 🎣',
  '- Llevá agua\n- Llevá protector\n- Avisá a Prefectura (106)',
  'Hoy hay 18°C, 60% de humedad y viento del sudeste a 12 km/h.',
  'El kit sale \$15.000 y trae 3 anzuelos de 2/0 y un reel.',
  'Pescá entre 10-15 cm de profundidad — ahí está el pique.',
  'NUNCA salgas con tormenta; llamá al VHF canal 16 o al 106.',
  'Dijo “dale” y ‘listo’, che; «todo bien».',
  '### Nudos\nEl palomar aguanta 40 lbs y 15 kg de tensión.',
  'La caña de 2,10 m y 0,8 mm de línea rinde mejor... ¿viste?',
  'Salí a las 9:10 hs y volvé antes de las 18:30.',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => GuiaTextoVoz.habilitado = true);

  // ── Unidades y símbolos: se TRADUCEN, no se borran ─────────────────────────
  group('unidades', () {
    const casos = {
      '18 °C': '18 grados',
      '18°C': '18 grados',
      '1 °C': '1 grado',
      '135°': '135 grados',
      '50 %': '50 por ciento',
      '50%': '50 por ciento',
      '12 km/h': '12 kilómetros por hora',
      '12km/h': '12 kilómetros por hora',
      '3 m/s': '3 metros por segundo',
      '\$15.000': '15.000 pesos',
      '\$ 1500': '1500 pesos',
      '\$1': '1 peso',
      '30 cm': '30 centímetros',
      '1 cm': '1 centímetro',
      '2 m': '2 metros',
      '1 m': '1 metro',
      '1,5 m': '1,5 metros',
      '0,8 mm': '0,8 milímetros',
      '5 km': '5 kilómetros',
      '5 kg': '5 kilos',
      '1 kg': '1 kilo',
      '200 gr': '200 gramos',
      '200 g': '200 gramos',
      '40 lbs': '40 libras',
      '10 lb': '10 libras',
      '9:10 hs': '9:10 horas',
      '12 hs': '12 horas',
      '15 min': '15 minutos',
      '30 seg': '30 segundos',
      '10-15 cm': '10 a 15 centímetros',
      '2/0': '2 sobre 0',
      '1/2 kg': 'medio kilo',
      "6'6\" pies": '6 pies 6 pulgadas',
      "Largo: 6' a 7'": 'Largo: 6 pies a 7 pies',
      'tubo de 2"': 'tubo de 2 pulgadas',
      'Cañas #4 a #6': 'Cañas número 4 a número 6',
      '1/2 taza': 'media taza',
      '1/2 pimiento': 'medio pimiento',
    };
    for (final c in casos.entries) {
      test('"${c.key}" → "${c.value}"', () => expect(_v(c.key), c.value));
    }

    test('en una frase', () {
      expect(_v('Hoy hay 18°C, 60% de humedad y viento a 12 km/h.'),
          'Hoy hay 18 grados, 60 por ciento de humedad y viento a 12 kilómetros por hora.');
    });
    test('una hora común no se toca', () => expect(_v('Son las 14:35.'), 'Son las 14:35.'));
    test('un decimal con punto pasa a coma, un millar no', () {
      expect(_v('olas de 0.6 metros'), 'olas de 0,6 metros');
      expect(_v('sale 15.000 pesos'), 'sale 15.000 pesos');
    });
    test('"m" suelta (sin número) no es metros', () => expect(_v('mi mamá m'), 'mi mamá m'));
  });

  // ── Limpieza ───────────────────────────────────────────────────────────────
  group('limpieza', () {
    const casos = {
      '**Nudo palomar**': 'Nudo palomar',
      '🎣 Mirá 🐟 el río 🌊': 'Mirá el río',
      'Dijo “dale” y se fue': 'Dijo dale y se fue',
      "Pa' la pesca, \"chamigo\"": 'Pa la pesca, chamigo',
      '1. Pasá la línea\n2. Hacé el nudo': 'Pasá la línea. Hacé el nudo',
      '- primero\n- segundo': 'primero. segundo',
      '• uno\n• dos': 'uno. dos',
      '### Título\nTexto': 'Título. Texto',
      'Pescá — y abrigate': 'Pescá, y abrigate',
      'Gu-IA te ayuda': 'el Guía te ayuda',
      'pesca & camping': 'pesca y camping',
      'y/o': 'y o',
      'pesca/boya': 'pesca boya',
      'a +b': 'a más b',
      'x = y': 'x igual a y',
      'Hola...   mundo': 'Hola... mundo',
    };
    for (final c in casos.entries) {
      test('"${c.key.replaceAll('\n', r'\n')}"', () => expect(_v(c.key), c.value));
    }
  });

  // ── Mayúsculas: los títulos se pasan a minúsculas, las siglas quedan ───────
  group('mayúsculas', () {
    test('un título en mayúsculas pasa a minúsculas', () {
      expect(_v('BOYA ELEVADORA PARA PEJERREY'), 'boya elevadora para pejerrey');
      expect(_v('NUNCA uses eso'), 'nunca uses eso');
    });
    test('las siglas conocidas se conservan', () {
      expect(_v('Llamá al VHF canal 16'), 'Llamá al VHF canal 16');
      expect(_v('El GPS y el SMN no andan; avisá a la PNA'), 'El GPS y el SMN no andan; avisá a la PNA');
      expect(_v('Pedí un SOS por radio'), 'Pedí un SOS por radio');
    });
    test('una sigla dentro de un título en mayúsculas se conserva', () {
      expect(_v('RADIO VHF PORTÁTIL'), 'radio VHF portátil');
    });
    test('letras sueltas no se tocan', () => expect(_v('Opción A o B'), 'Opción A o B'));
  });

  // ── Invariantes sobre textos reales ────────────────────────────────────────
  group('invariantes', () {
    final fichas = _fichas();
    final climas = [
      'Según el pronóstico que bajé a las 4:20, a esta hora se esperan 22 grados, viento de 20 kilómetros por hora del sur, con ráfagas de 30 y humedad del 60 por ciento.',
      'Hoy el sol sale a las 6:29 y se pone a las 18:59.',
    ];
    final todos = [...fichas, ..._groq, ...climas];

    test('hay al menos 40 textos', () => expect(todos.length, greaterThanOrEqualTo(40)));

    test('0 emojis, comillas, asteriscos ni símbolos en la salida', () {
      final malos = <String>[];
      for (final t in todos) {
        final s = _v(t);
        if (_emoji.hasMatch(s) || _prohibidos.hasMatch(s) || s.contains('km/h') || s.contains('/')) {
          malos.add(s.length > 90 ? s.substring(0, 90) : s);
        }
      }
      expect(malos, isEmpty, reason: '${malos.length} salidas con símbolos: ${malos.take(4).join(' | ')}');
    });

    test('0 numeración ni viñetas', () {
      final malos = todos.map(_v).where(_numeracion.hasMatch).toList();
      expect(malos, isEmpty);
    });

    test('ninguna palabra en mayúsculas que no sea una sigla conocida', () {
      final malos = <String>{};
      for (final t in todos) {
        for (final m in RegExp(r'\b[A-ZÁÉÍÓÚÑÜ]{2,}\b').allMatches(_v(t))) {
          if (!GuiaTextoVoz.siglasConocidas.contains(m.group(0))) malos.add(m.group(0)!);
        }
      }
      expect(malos, isEmpty);
    });

    test('ningún número se pierde (salvo la numeración de las listas)', () {
      final perdidos = <String>[];
      for (final t in todos) {
        // La numeración de las listas no se dice, y "1/2" se dice "medio" o "media".
        final sinLista = t.replaceAll(RegExp(r'(^|\n)\s*\d+[.)]\s', multiLine: true), '\n').replaceAll('1/2', 'medio');
        final s = _v(t);
        final salida = RegExp(r'\d+').allMatches(s).map((m) => m.group(0)!).toSet();
        for (final m in RegExp(r'\d+').allMatches(sinLista)) {
          if (!salida.contains(m.group(0))) perdidos.add('${m.group(0)} en "${t.length > 60 ? t.substring(0, 60) : t}"');
        }
      }
      expect(perdidos, isEmpty, reason: perdidos.take(5).join(' | '));
    });

    test('nunca deja la salida vacía si había letras', () {
      for (final t in todos) {
        if (RegExp(r'\p{L}', unicode: true).hasMatch(t)) expect(_v(t).trim(), isNotEmpty);
      }
    });

    test('es idempotente: preparar dos veces da lo mismo', () {
      for (final t in todos) {
        final una = _v(t);
        expect(_v(una), una);
      }
    });

    test('espacios simples y sin espacio antes de la puntuación', () {
      for (final t in todos) {
        final s = _v(t);
        expect(s, isNot(contains('  ')));
        expect(s, isNot(matches(RegExp(r'\s[.,;:!?]'))), reason: s);
        expect(s, equals(s.trim()));
      }
    });
  });

  // ── Flag ───────────────────────────────────────────────────────────────────
  group('flag guia_voz_limpia', () {
    test('viene prendido', () => expect(GuiaTextoVoz.habilitado, isTrue));
    test('apagado devuelve el texto tal cual', () {
      GuiaTextoVoz.habilitado = false;
      expect(_v('18 °C **hola**'), '18 °C **hola**');
    });
    test('aplicarFlags lee la preferencia', () async {
      SharedPreferences.setMockInitialValues({GuiaTextoVoz.prefVozLimpia: false});
      GuiaTextoVoz.aplicarFlags(await SharedPreferences.getInstance());
      expect(GuiaTextoVoz.habilitado, isFalse);
    });
  });

  // ── Los tres caminos de voz pasan por la misma función ─────────────────────
  // `voice_service.dart` (el del overlay), `audio_service.dart` y `voz_service.dart`
  // (el del chat simple) llaman a FlutterTts. Ninguno puede hablar sin prepararlo.
  group('los caminos de voz usan preparar()', () {
    for (final archivo in ['voice_service', 'audio_service', 'voz_service']) {
      test(archivo, () {
        final codigo = File('lib/services/$archivo.dart').readAsStringSync();
        expect(codigo, contains('GuiaTextoVoz.preparar('));
        // Cada .speak( de FlutterTts recibe texto ya preparado.
        for (final m in RegExp(r'_(?:flutterTts|tts)\.speak\(([^)]*\)?)\)').allMatches(codigo)) {
          expect(m.group(1), anyOf(contains('preparar'), equals('cleanText')), reason: m.group(0));
        }
      });
    }
  });
}
