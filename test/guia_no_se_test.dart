// Paso 1.3 de docs/PLAN_AYUDANTE_IA.md: "no tengo ese dato" honesto.
//
// Cuando el buscador no encuentra nada y las reglas caen en fallback, el Guía no
// dice "no te entendí" (el problema no es que no entienda: es que no tiene el
// dato) ni tira un menú de la app. Dice, con una de 6 frases al azar y sin repetir
// la misma dos veces seguidas, que no tiene esa información. Si la pregunta roza
// seguridad, suma el 106 y el canal 16.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

// El router espera entre 0,4 y 1,2 s por consulta (retraso artificial que saca el
// paso 1.4): con ~50 consultas un test pasa de los 30 s por defecto.
@Timeout(Duration(minutes: 5))
library;

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/guia_condiciones_service.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

const _lab = 'mini_model_lab/retrieval';

List<String> _frasesHonestas() {
  final j = jsonDecode(File('assets/elguia/personalidad.json').readAsStringSync()) as Map<String, dynamic>;
  return List<String>.from((j['no_se_honesto'] as List?) ?? const []);
}

List<String> _fueraDeDominio() => File('$_lab/preguntas_fuera_de_dominio.jsonl')
    .readAsLinesSync()
    .where((l) => l.trim().isNotEmpty)
    .map((l) => jsonDecode(l)['instruction'] as String)
    .toList();

bool _esHonesta(String texto, List<String> frases) => frases.any(texto.startsWith);

/// Preguntas que hoy terminan en el fallback del motor de reglas.
const _caenEnFallback = [
  'cuánto sale el dólar hoy',
  'cómo cambio una rueda del auto',
  'cuál es la capital de francia',
  'cómo configuro el wifi del router',
  'cómo arreglo una canilla que gotea',
  'recomendame un libro de historia argentina',
  'qué es la inflación',
  'cómo cuido un cactus',
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ElGuiaEngine.noSeHonestoHabilitado = true;
    GuiaCondicionesService.habilitado = true;
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = false;
  });

  group('las frases', () {
    test('hay 6, distintas, y ninguna dice "no te entendí"', () {
      final f = _frasesHonestas();
      expect(f.length, 6);
      expect(f.toSet().length, 6);
      for (final x in f) {
        expect(x.toLowerCase(), isNot(contains('entend')), reason: x);
        expect(x.toLowerCase(), contains('no '), reason: 'tiene que decir que no tiene el dato: $x');
      }
    });
  });

  group('una pregunta fuera de dominio que cae en fallback', () {
    for (final q in _caenEnFallback) {
      test('"$q" → una de las 6 frases', () async {
        final r = await BaqueanoIAService.responder(q);
        expect(_esHonesta(r.texto, _frasesHonestas()), isTrue, reason: r.texto);
      });
    }

    test('nunca la misma frase dos veces seguidas (48 preguntas distintas)', () async {
      String? anterior;
      final historia = <String>[];
      var n = 0;
      for (var i = 0; i < 48; i++) {
        final pregunta = '${_caenEnFallback[i % _caenEnFallback.length]} número $i';
        final r = await BaqueanoIAService.responder(pregunta);
        if (!_esHonesta(r.texto, _frasesHonestas())) {
          anterior = null; // "seguidas": una respuesta de otro tipo corta la cadena
          continue;
        }
        if (anterior != null) expect(r.texto, isNot(anterior), reason: 'repetida en la pregunta $i ("$pregunta"), tras $historia');
        anterior = r.texto;
        historia.add(r.texto.substring(0, 12));
        n++;
      }
      expect(n, greaterThan(30), reason: 'casi todas tenían que ser frases honestas');
    });

    test('salen las 6 frases (es al azar, no una fija)', () async {
      final vistas = <String>{};
      for (var i = 0; i < 48; i++) {
        final r = await BaqueanoIAService.responder('${_caenEnFallback[i % _caenEnFallback.length]} número $i');
        for (final f in _frasesHonestas()) {
          if (r.texto.startsWith(f)) vistas.add(f);
        }
      }
      expect(vistas.length, 6);
    });

    test('dos fallbacks seguidos no activan el "veo que andás con problemas con la app"', () async {
      for (final q in _caenEnFallback.take(4)) {
        final r = await BaqueanoIAService.responder(q);
        expect(r.texto.toLowerCase(), isNot(contains('problemas con la app')), reason: q);
      }
    });
  });

  group('si la pregunta roza seguridad, se suman el 106 y el canal 16', () {
    test('con una palabra de peligro', () async {
      final r = await BaqueanoIAService.responder('es peligroso, cuánto sale el dólar hoy');
      expect(r.texto, contains('106'));
      expect(r.texto, contains('canal 16'));
    });
    test('sin seguridad, no los agrega', () async {
      final r = await BaqueanoIAService.responder('cómo cambio una rueda del auto');
      expect(r.texto, isNot(contains('106')));
      expect(r.texto, isNot(contains('canal 16')));
    });
  });

  group('flag guia_no_se_honesto', () {
    test('viene prendido', () => expect(ElGuiaEngine.noSeHonestoHabilitado, isTrue));
    test('apagado vuelve a las frases de siempre', () async {
      ElGuiaEngine.noSeHonestoHabilitado = false;
      final r = await BaqueanoIAService.responder('cómo cambio una rueda del auto');
      expect(_esHonesta(r.texto, _frasesHonestas()), isFalse, reason: r.texto);
    });
    test('aplicarFlags lee la preferencia', () async {
      SharedPreferences.setMockInitialValues({ElGuiaEngine.prefNoSeHonesto: false});
      ElGuiaEngine.aplicarFlags(await SharedPreferences.getInstance());
      expect(ElGuiaEngine.noSeHonestoHabilitado, isFalse);
    });
  });

  // ── El lector de condiciones no contesta lo que no es de acá ───────────────
  group('"qué hora es en España" no es la hora local', () {
    for (final q in ['qué hora es en españa', 'qué hora es en tokio', 'qué día es en australia']) {
      test('"$q"', () => expect(GuiaCondicionesService.detectar(q), isNull));
    }
    test('"qué hora es" sigue funcionando', () => expect(GuiaCondicionesService.detectar('qué hora es'), TipoCondicion.hora));
  });

  // ── Las 50 fuera de dominio: cuántas se contestan inventando ───────────────
  // El plan pide 0. Hoy no se llega: parte del problema es el buscador (umbrales
  // sin calibrar, Fase 2) y parte la detección de intenciones de la app. Esto es un
  // TRINQUETE: si una pregunta nueva empieza a inventar, falla; cuando se arreglen,
  // se baja `_conocidas` hasta vaciarla (meta del plan: 0).
  group('50 preguntas fuera de dominio', () {
    // Respuestas que no son inventar: la frase honesta, el rechazo de pagos y seguridad.
    bool legitima(String t, List<String> frases) =>
        _esHonesta(t, frases) ||
        t.startsWith('Ese tema esta fuera de mi zona') ||
        t.contains('Prefectura Naval al 106');

    /// Fuera de dominio que HOY se contestan con algo inventado o inventan una
    /// ayuda de la app que no corresponde. Meta: vaciar esta lista (Fase 2).
    // 17 de 50 (34 %). Causas: (1) el buscador ofrece "¿te referís a...?" con
    // fichas sin relación (umbrales sin calibrar: los puntajes de estas consultas
    // se solapan con los de preguntas válidas, no se separan con un piso); (2) la
    // detección de intenciones de la app contesta con un menú ("¿Qué querés
    // usar?", "Mis Viajes"); (3) el buscador acierta "directa" con una ficha de
    // cocina ("horno" → masa de empanadas). Todo eso es de la Fase 2.
    const conocidas = <String>{
      'cómo hago para bajar de peso rápido',
      'cuánto es 45 por 12',
      'qué hora es en españa',
      'cuánto cuesta un iphone',
      'explicame la teoría de la relatividad',
      'cómo se hace la salsa bolognesa',
      'cuál es el mejor celular gama media',
      'cómo aprendo a tocar la guitarra',
      'cuándo empieza el mundial',
      'cómo funciona la bolsa de valores',
      'cómo se limpia el horno',
      'cuántos habitantes tiene rosario',
      'cuánto tarda el vuelo a madrid',
      'qué es un agujero negro',
      'cómo hago para dormir mejor',
      'cómo pinto una pared',
      'cómo se juega al truco',
    };

    test('ninguna pregunta nueva inventa; las conocidas se listan', () async {
      final frases = _frasesHonestas();
      final inventan = <String>[];
      final detalle = StringBuffer();
      for (final q in _fueraDeDominio()) {
        BaqueanoIAService.reiniciarEstadoParaTest();
        final r = await BaqueanoIAService.responder(q);
        if (!legitima(r.texto, frases)) {
          inventan.add(q);
          detalle.writeln('  "$q" → ${r.texto.replaceAll('\n', ' ').substring(0, r.texto.length.clamp(0, 90))}');
        }
      }
      // ignore: avoid_print
      print('FUERA DE DOMINIO que inventan: ${inventan.length} de 50\n$detalle');
      expect(_fueraDeDominio().length, 50);
      expect(inventan.length, lessThanOrEqualTo(conocidas.length));
      final nuevas = inventan.where((q) => !conocidas.contains(q)).toList();
      expect(nuevas, isEmpty, reason: 'preguntas fuera de dominio que hoy se contestan con otra cosa que "no tengo ese dato":\n$detalle');
    });
  });
}
