// Paso 1.2 de docs/PLAN_AYUDANTE_IA.md: el presentador de fichas.
//
// Con BM25 prendido (paso 1.1), el buscador devuelve la ficha cruda. Las 342
// fichas reales son un menú de formatos: 142 con emoji, 144 con el título en
// MAYÚSCULAS, 194 con campos tipo planilla ("Uso: …", "Resistencia: ALTA"),
// 160 de más de 350 caracteres y 69 con lista numerada de pasos.
//
// El presentador las convierte en respuesta, sin inventar nada: solo recorta y
// une oraciones de la ficha (más plantillas fijas para los campos conocidos).
//
//  · Ficha INFORMATIVA (un pez, una carnada): 2–3 oraciones, ≤ 350 caracteres,
//    eligiendo las que coinciden con la pregunta.
//  · Ficha de PROCEDIMIENTO (pasos o lista numerada): NO se cortan pasos. Un
//    nudo con la mitad de los pasos es peor que nada. Los pasos pasan a oraciones
//    naturales ("Primero…, después…, por último…") con un tope de 600; si no
//    entran, se da el resumen y se ofrece decirlo paso a paso, de a uno.
//
// Este archivo nace en ROJO a propósito: el presentador empieza siendo un
// esqueleto que devuelve la ficha cruda.

import 'dart:math';

import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/ia_router_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_ficha.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_presentador.dart';
import 'package:capitanya_master/services/guia_retrieval/guia_texto_es.dart';
import 'package:flutter_test/flutter_test.dart';

final RegExp _emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{FE0F}]', unicode: true);
final RegExp _numero = RegExp(r'\d+(?:[.,]\d+)?');
final RegExp _itemNumerado = RegExp(r'^\s*\d+[\.\)]\s+(.*)$', multiLine: true);

/// Los pasos de una ficha, calculados acá (no con el presentador).
List<String> _pasosDeLaFicha(String texto) {
  final numerados = _itemNumerado.allMatches(texto).map((m) => m.group(1)!.trim()).toList();
  if (numerados.length >= 2) return numerados;
  final campo = RegExp(r'^Pasos:\s*(.*)$', multiLine: true).firstMatch(texto);
  if (campo != null) {
    return campo.group(1)!.split(RegExp(r'\.,\s*')).map((p) => p.trim()).where((p) => p.isNotEmpty).toList();
  }
  return const [];
}

String _n(String s) => GuiaTextoEs.normalizar(s);

GuiaFicha _fichaSintetica(String texto, {String libreria = 'prueba', String categoria = 'especies'}) => GuiaFicha(
      id: 'prueba/sintetica',
      libreria: libreria,
      titulo: 'prueba',
      texto: texto,
      preguntas: const [],
      keywords: const [],
      categoria: categoria,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ElGuiaEngine engine;
  late List<GuiaFicha> fichas;

  setUpAll(() async {
    engine = ElGuiaEngine();
    await engine.inicializar();
    await engine.reconstruirIndiceRetrieval();
    fichas = engine.fichasRetrieval.toList();
  });

  String preguntaPara(GuiaFicha f) => f.preguntas.isNotEmpty ? f.preguntas.first : f.titulo;

  // ── Invariantes sobre las 342 fichas reales ───────────────────────────────
  group('sobre todas las fichas reales', () {
    test('hay fichas de verdad', () => expect(fichas.length, greaterThan(300)));

    test('ninguna presentación tiene emojis ni markdown ni numeración ni viñetas', () {
      for (final f in fichas) {
        final t = GuiaPresentador.presentar(f, preguntaPara(f), random: Random(1)).texto;
        expect(_emoji.hasMatch(t), isFalse, reason: '${f.id}: emoji → $t');
        expect(t, isNot(contains('**')), reason: '${f.id}');
        expect(t, isNot(contains('__')), reason: '${f.id}');
        expect(t, isNot(contains('`')), reason: '${f.id}');
        expect(RegExp(r'^\s*\d+[\.\)]\s', multiLine: true).hasMatch(t), isFalse, reason: '${f.id}: numeración → $t');
        expect(RegExp(r'^\s*[-•*]\s', multiLine: true).hasMatch(t), isFalse, reason: '${f.id}: viñeta → $t');
      }
    });

    test('ninguna presentación tiene un título en mayúsculas ni una planilla de campos', () {
      final etiquetas = RegExp(
        r'^\s*(Uso|Resistencia|Dificultad|Pasos|Habitat|Hábitat|Carnada|Equipo|Temporada|Peligro|'
        r'Descripcion|Descripción|Nombre cientifico|Consejo del Baqueano|Ideal para)\s*:',
        multiLine: true,
      );
      for (final f in fichas) {
        final t = GuiaPresentador.presentar(f, preguntaPara(f), random: Random(1)).texto;
        final primeraLinea = t.split('\n').first.replaceAll(RegExp(r'[^A-Za-zÁÉÍÓÚÑáéíóúñ ]'), '').trim();
        expect(primeraLinea.length > 8 && primeraLinea == primeraLinea.toUpperCase(), isFalse,
            reason: '${f.id}: título en mayúsculas → $t');
        expect(etiquetas.hasMatch(t), isFalse, reason: '${f.id}: campo tipo planilla → $t');
      }
    });

    test('respeta el tope: 350 las informativas, 600 los procedimientos', () {
      for (final f in fichas) {
        final tope = _pasosDeLaFicha(f.texto).isNotEmpty ? 600 : 350;
        final t = GuiaPresentador.presentar(f, preguntaPara(f), random: Random(1)).texto;
        expect(t.length, lessThanOrEqualTo(tope), reason: '${f.id} (${t.length} car, tope $tope) → $t');
      }
    });

    test('TODO número de la salida existe en la ficha (no se inventa ni se cambia ninguno)', () {
      for (final f in fichas) {
        final t = GuiaPresentador.presentar(f, preguntaPara(f), random: Random(1)).texto;
        for (final m in _numero.allMatches(t)) {
          expect(f.texto, contains(m.group(0)!), reason: '${f.id}: "${m.group(0)}" no está en la ficha → $t');
        }
      }
    });

    test('nunca queda vacía y termina como una oración', () {
      for (final f in fichas) {
        final t = GuiaPresentador.presentar(f, preguntaPara(f), random: Random(1)).texto.trim();
        expect(t, isNotEmpty, reason: f.id);
        expect(RegExp(r'[.!?…)]$').hasMatch(t), isTrue, reason: '${f.id}: no termina como oración → "$t"');
      }
    });

    test('NINGÚN paso de un procedimiento se pierde: o están todos o se ofrece el paso a paso', () {
      var procedimientos = 0;
      for (final f in fichas) {
        final pasos = _pasosDeLaFicha(f.texto);
        if (pasos.isEmpty) continue;
        procedimientos++;
        final p = GuiaPresentador.presentar(f, preguntaPara(f), random: Random(1));
        if (p.ofreceDictado) {
          expect(p.pasos.length, greaterThanOrEqualTo(pasos.length), reason: '${f.id}: faltan pasos para dictar');
          for (final paso in pasos) {
            expect(p.pasos.map(_n).any((x) => x.contains(_n(paso))), isTrue, reason: '${f.id}: falta el paso "$paso"');
          }
          expect(p.texto, endsWith('¿Querés que te lo diga paso a paso?'), reason: f.id);
        } else {
          final salida = _n(p.texto);
          for (final paso in pasos) {
            expect(salida, contains(_n(paso)), reason: '${f.id}: se perdió el paso "$paso" → ${p.texto}');
          }
        }
      }
      expect(procedimientos, greaterThan(40), reason: 'el test tiene que probar muchos procedimientos');
    });
  });

  // ── Cada tipo de ficha ────────────────────────────────────────────────────
  group('ficha de procedimiento corta: el nudo palomar', () {
    late GuiaFicha palomar;
    setUpAll(() => palomar = fichas.firstWhere((f) => f.id == 'nudos/nudos/palomar'));

    test('convierte la planilla en oraciones naturales', () {
      final t = GuiaPresentador.presentar(palomar, 'cómo se hace el nudo palomar', random: Random(1)).texto;
      expect(t, isNot(contains('Resistencia:')));
      expect(t, isNot(contains('ALTA')));
      expect(t, isNot(contains('BAJA')));
      expect(t.toLowerCase(), contains('resistente'));
      expect(t.toLowerCase(), contains('fácil'));
      expect(t, contains('Primero'));
      expect(t, contains('Por último'));
    });

    test('trae LOS CUATRO pasos, sin cortar ninguno', () {
      final p = GuiaPresentador.presentar(palomar, 'cómo se hace el nudo palomar', random: Random(1));
      expect(p.ofreceDictado, isFalse);
      final t = _n(p.texto);
      for (final paso in _pasosDeLaFicha(palomar.texto)) {
        expect(t, contains(_n(paso)));
      }
    });
  });

  group('ficha de procedimiento larga: la receta del chupín', () {
    late GuiaFicha chupin;
    setUpAll(() => chupin = fichas.firstWhere((f) => f.id == 'como_se_hace_chupin_pescado'));

    test('no entra entera: da un resumen y ofrece el paso a paso', () {
      final p = GuiaPresentador.presentar(chupin, 'cómo se hace el chupín de pescado', random: Random(1));
      expect(p.ofreceDictado, isTrue);
      expect(p.texto.length, lessThanOrEqualTo(600));
      expect(p.texto, endsWith('¿Querés que te lo diga paso a paso?'));
      expect(p.pasos.length, greaterThanOrEqualTo(10));
    });
  });

  group('ficha informativa: elige lo que coincide con la pregunta', () {
    late GuiaFicha dorado;
    setUpAll(() => dorado = fichas.firstWhere((f) => f.id == 'peces/dorado'));

    test('"qué carnada uso para el dorado" → la carnada, sin la planilla entera', () {
      final t = GuiaPresentador.presentar(dorado, 'qué carnada uso para el dorado', random: Random(1)).texto;
      expect(t, contains('morena viva'));
      expect(t.length, lessThanOrEqualTo(350));
      expect(t, isNot(contains('Salminus')), reason: 'el nombre científico no se pidió');
      expect(t, isNot(contains('Carnada:')));
    });

    test('"dónde vive el dorado" → el hábitat', () {
      final t = GuiaPresentador.presentar(dorado, 'dónde vive el dorado', random: Random(1)).texto;
      expect(t.toLowerCase(), contains('correderas'));
      expect(t, contains('Vive en'));
    });
  });

  group('campos desconocidos y advertencias', () {
    test('un campo desconocido con un valor suelto se deja afuera: no se inventa una frase', () {
      final f = _fichaSintetica('Campo inventado: valor raro\nDescripcion: Es un pez de agua dulce.');
      final t = GuiaPresentador.presentar(f, 'qué es', random: Random(1)).texto;
      expect(t, contains('pez de agua dulce'));
      expect(t.toLowerCase(), isNot(contains('inventado')));
      expect(t.toLowerCase(), isNot(contains('valor raro')));
    });

    test('las advertencias en mayúsculas dentro de una oración se conservan (NUNCA, PROHIBIDO)', () {
      final f = _fichaSintetica('Embarcacion: Lancha rígida de fibra. NUNCA gomón o semirrígido, las espinas pueden perforar.');
      final t = GuiaPresentador.presentar(f, 'desde qué embarcación se pesca', random: Random(1)).texto;
      expect(t, contains('NUNCA'), reason: 'una advertencia de seguridad no se pasa a minúsculas');
    });

    test('una ficha de una sola oración corta se muestra tal cual (con o sin entrada)', () {
      final f = _fichaSintetica('Sin escamas, gris plomo con panza blanca. Llega a 20 kilos.');
      final t = GuiaPresentador.presentar(f, 'cómo es el bagre', random: Random(1)).texto;
      expect(t, contains('Sin escamas, gris plomo con panza blanca.'));
      expect(t, contains('Llega a 20 kilos.'));
    });
  });

  group('el flag guia_presentador', () {
    tearDown(() => ElGuiaEngine.presentadorHabilitado = true);

    test('viene prendido por defecto', () => expect(ElGuiaEngine.presentadorHabilitado, isTrue));

    test('apagado, se muestra la ficha cruda como antes', () {
      final palomar = fichas.firstWhere((f) => f.id == 'nudos/nudos/palomar');
      ElGuiaEngine.presentadorHabilitado = false;
      final r = engine.presentarFichaParaTest(palomar, 'cómo se hace el nudo palomar');
      expect(r.texto, palomar.texto);
    });

    test('se lee de SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'guia_presentador': false});
      ElGuiaEngine.aplicarFlags(await SharedPreferences.getInstance());
      expect(ElGuiaEngine.presentadorHabilitado, isFalse);
    });
  });

  group('variedad', () {
    test('la entrada cambia: no es siempre la misma frase', () {
      final f = fichas.firstWhere((f) => f.id == 'peces/dorado');
      final entradas = <String>{};
      for (var i = 0; i < 40; i++) {
        entradas.add(GuiaPresentador.presentar(f, 'contame del dorado', random: Random(i)).intro);
      }
      expect(entradas.length, greaterThanOrEqualTo(3), reason: 'solo hubo: $entradas');
    });

    test('la entrada no suma números ni cambia el contenido', () {
      final f = fichas.firstWhere((f) => f.id == 'peces/dorado');
      final a = GuiaPresentador.presentar(f, 'contame del dorado', random: Random(1));
      final b = GuiaPresentador.presentar(f, 'contame del dorado', random: Random(2));
      expect(a.cuerpo, b.cuerpo, reason: 'solo cambia la entrada');
    });
  });

  // ── Dictado paso a paso, en el motor ──────────────────────────────────────
  group('dictado paso a paso', () {
    late GuiaFicha chupin;
    setUpAll(() => chupin = fichas.firstWhere((f) => f.id == 'como_se_hace_chupin_pescado'));
    setUp(() => engine.contexto.resetearContexto());

    test('"sí" empieza a dictar, y cada paso trae el siguiente', () async {
      final oferta = engine.presentarFichaParaTest(chupin, 'cómo se hace el chupín de pescado');
      expect(oferta.texto, endsWith('¿Querés que te lo diga paso a paso?'));
      expect(engine.hayDictadoPendiente, isTrue);

      final pasos = _pasosDeLaFicha(chupin.texto);
      var turno = 0;
      var ultima = '';
      while (engine.hayDictadoPendiente && turno < 40) {
        final r = await engine.responder(turno == 0 ? 'sí' : 'dale');
        ultima = r.texto;
        expect(ultima, isNot(contains('Me parece bien, chamigo')), reason: 'el "sí" se tomó como cierre de charla');
        turno++;
      }
      expect(engine.hayDictadoPendiente, isFalse, reason: 'tiene que terminar');
      expect(_n(ultima), contains(_n(pasos.last)), reason: 'el último mensaje es el último paso');
      expect(turno, greaterThanOrEqualTo(pasos.length), reason: 'un mensaje por paso, como mínimo');
    });

    test('"repetime" repite el paso y "no" lo termina', () async {
      engine.presentarFichaParaTest(chupin, 'cómo se hace el chupín de pescado');
      final primero = await engine.responder('sí');
      final repetido = await engine.responder('repetime');
      expect(repetido.texto, primero.texto);
      final fin = await engine.responder('no, gracias');
      expect(engine.hayDictadoPendiente, isFalse);
      expect(fin.texto, isNotEmpty);
    });

    test('una pregunta que no tiene que ver cancela el dictado y se contesta normal', () async {
      engine.presentarFichaParaTest(chupin, 'cómo se hace el chupín de pescado');
      final r = await engine.responder('cuánto sale el dólar hoy');
      expect(engine.hayDictadoPendiente, isFalse);
      expect(_n(r.texto), isNot(contains(_n(_pasosDeLaFicha(chupin.texto).first))));
    });

    test('una emergencia en medio del dictado la atiende el motor de seguridad, no el dictado', () async {
      engine.presentarFichaParaTest(chupin, 'cómo se hace el chupín de pescado');
      final r = await engine.responder('me corté con el cuchillo y sangra mucho', modoSeguridad: true);
      expect(engine.hayDictadoPendiente, isFalse);
      expect(r.texto.toLowerCase(), contains('presion'));
    });

    test('en el router, un "sí" en medio de un dictado NO va a la nube', () async {
      SharedPreferences.setMockInitialValues({});
      await BaqueanoIAService.inicializarParaTest();
      BaqueanoIAService.reiniciarEstadoParaTest();
      var llamadasANube = 0;
      BaqueanoIAService.groqParaTest = (pregunta, historial) async {
        llamadasANube++;
        return const ElGuiaRespuesta(texto: 'RESPUESTA-DE-LA-NUBE');
      };
      IARouterState.modoOnline.value = true;
      try {
        engine.presentarFichaParaTest(chupin, 'cómo se hace el chupín de pescado');
        final r = await BaqueanoIAService.responder('sí');
        expect(llamadasANube, 0, reason: 'la nube no sabe de qué receta se está hablando');
        expect(r.texto, isNot(contains('RESPUESTA-DE-LA-NUBE')));
        expect(r.texto.toLowerCase(), contains('ingredientes'));
      } finally {
        BaqueanoIAService.reiniciarEstadoParaTest();
        IARouterState.modoOnline.value = true;
      }
    });

    test('sin un dictado en curso, un "sí" suelto no se toma como dictado', () {
      engine.reiniciarDictadoParaTest();
      expect(engine.esContinuacionDeDictado('sí'), isFalse);
    });

    test('esContinuacionDeDictado reconoce los "sí" cortos y no las preguntas nuevas', () {
      engine.presentarFichaParaTest(chupin, 'cómo se hace el chupín de pescado');
      for (final s in ['sí', 'dale', 'ok', 'seguí', 'siguiente', 'y después', 'decime', 'paso a paso']) {
        expect(engine.esContinuacionDeDictado(s), isTrue, reason: s);
      }
      for (final s in ['cuánto sale el dólar hoy', 'qué carnada uso para el dorado', 'me hundo']) {
        expect(engine.esContinuacionDeDictado(s), isFalse, reason: s);
      }
    });
  });
}
