// Tests de seguridad del router del ayudante (Fase 0 de docs/PLAN_AYUDANTE_IA.md).
//
// Regla innegociable: emergencia, primeros auxilios, VHF/Prefectura, "estoy
// perdido", GPS y lo transaccional de la app NUNCA los responde la nube, ni un
// filtro de humor, ni un retraso artificial. Los responde el motor de reglas.
//
// La nube se simula con un Groq falso que cuenta las llamadas y devuelve una
// marca reconocible. Cada caso comprueba tres cosas:
//   1. no se llamó a Groq,
//   2. el texto devuelto no es el de Groq,
//   3. (seguridad) respondió el motor de reglas, no un filtro de humor.
//
// Este archivo nace en ROJO a propósito (paso 0.1): prueba la falla del código
// de hoy. Los pasos 0.2 a 0.5 lo ponen en verde.
//
// ═══ REGLA DE DISEÑO: ANTE LA DUDA, GANA SEGURIDAD ═══════════════════════════
// Una pregunta de pesca tratada como emergencia cuesta una respuesta con el
// teléfono de Prefectura. Una emergencia tratada como pesca puede costar una
// vida. Por eso la detección va de "salvo que" y no de "solo si": una frase es
// seguridad SALVO que sea claramente otra cosa.
//   · Hundimiento ("hund-", "und-"): seguridad salvo que nombre un elemento de
//     pesca (boya, corcho, plomada, señuelo, anzuelo, línea, carnada...) y no
//     nombre una embarcación ni una persona.
//   · Perdido ("estoy perdido", "nos perdimos", "me perdí"): seguridad salvo
//     "con [algo]" ("estoy perdido con los nudos") o "me perdí el/la [pique]".
//     "Perdido en [cualquier cosa]" SIEMPRE es seguridad, aunque suene a
//     "confundido": no se mantiene una lista de lugares.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/ia_router_state.dart';
import 'frases_seguridad.dart';

const Map<String, List<String>> _seguridad = frasesSeguridad;
const List<String> _transaccional = frasesTransaccionales;

const String _marcaNube = 'RESPUESTA-DE-LA-NUBE-NO-DEBE-USARSE';



int _llamadasANube = 0;

/// Prepara el entorno de un caso: nube falsa que cuenta, router "con señal" y
/// una marca de estado que un filtro de humor dejaría intacta.
void _prepararCaso({required bool conSenal}) {
  _llamadasANube = 0;
  BaqueanoIAService.reiniciarEstadoParaTest();
  BaqueanoIAService.groqParaTest = (pregunta, historial) async {
    _llamadasANube++;
    return const ElGuiaRespuesta(texto: _marcaNube, gifSugerido: 'hablaConMate');
  };
  IARouterState.modoOnline.value = conSenal;
  IARouterState.reportarEstado(IAEstado.contingencia);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
  });

  tearDown(() {
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = true;
  });

  // ── Seguridad con señal: la nube nunca responde ───────────────────────────
  for (final grupo in _seguridad.entries) {
    group('CON señal · ${grupo.key}', () {
      for (final frase in grupo.value) {
        test('"$frase"', () async {
          _prepararCaso(conSenal: true);
          expect(
            ElGuiaEngine().clasificarIntencion(frase),
            ClaseIntencion.seguridad,
            reason: 'el motor no reconoce esta frase como seguridad (si pasa el resto del test, es por casualidad)',
          );
          final resp = await BaqueanoIAService.responder(frase);
          expect(_llamadasANube, 0, reason: 'se llamó a la nube con un tema de seguridad');
          expect(resp.texto, isNot(contains(_marcaNube)));
          expect(
            IARouterState.estado.value,
            IAEstado.offline,
            reason: 'tenía que responder el motor de reglas, no un filtro de humor ni la nube',
          );
        });
      }
    });
  }

  // ── Seguridad sin señal: responde el motor de reglas, no un filtro de humor ─
  for (final grupo in _seguridad.entries) {
    group('SIN señal · ${grupo.key}', () {
      for (final frase in grupo.value) {
        test('"$frase"', () async {
          _prepararCaso(conSenal: false);
          expect(
            ElGuiaEngine().clasificarIntencion(frase),
            ClaseIntencion.seguridad,
            reason: 'el motor no reconoce esta frase como seguridad (si pasa el resto del test, es por casualidad)',
          );
          final resp = await BaqueanoIAService.responder(frase);
          expect(_llamadasANube, 0);
          expect(resp.texto, isNot(contains(_marcaNube)));
          expect(
            IARouterState.estado.value,
            IAEstado.offline,
            reason: 'tenía que responder el motor de reglas, no un filtro de humor',
          );
        });
      }
    });
  }

  // ── Transaccional: puede seguir sus caminos, pero nunca a la nube ─────────
  group('CON señal · transaccional', () {
    for (final frase in _transaccional) {
      test('"$frase"', () async {
        _prepararCaso(conSenal: true);
        final resp = await BaqueanoIAService.responder(frase);
        expect(_llamadasANube, 0, reason: 'se llamó a la nube con un tema transaccional');
        expect(resp.texto, isNot(contains(_marcaNube)));
      });
    }
  });

  // ── Paso 0.3: el filtro de impaciencia no confunde palabras comunes ───────
  // "dale", "rápido" y "pura" salen del filtro: aparecen en frases normales
  // ("pura suerte", "dale, contame…") y en urgencias reales. Quedan solo las
  // frases largas de impaciencia ("hace rato espero", "apurate").
  group('filtro de impaciencia', () {
    // Paso 4: las frases de pesca ahora las atiende el motor local (fichas), no la nube. Lo que se prueba es lo mismo: que una
    // palabra común ("dale", "rápido", "pura") no corte la consulta con la respuesta de impaciencia (gif 'enojado').
    const noEsImpaciencia = [
      'dale che qué hago con este pescado',
      'dale che contame algo del fútbol',
    ];
    const noEsImpacienciaDePesca = [
      'dale contame cómo se arma una línea con boyas',
      'respondeme rápido qué carnada se usa para el dorado',
      'es pura suerte pescar un surubí grande',
      'el dorado es pura fuerza en la pelea',
      'cuál es la carnada más rápida de conseguir para pejerrey',
    ];
    for (final frase in noEsImpacienciaDePesca) {
      test('"$frase" lo atiende el motor local, no recibe el chiste de impaciencia', () async {
        _prepararCaso(conSenal: true);
        final resp = await BaqueanoIAService.responder(frase);
        expect(_llamadasANube, 0, reason: 'el conocimiento de pesca sale de las fichas, no de la nube');
        expect(resp.texto, isNot(contains(_marcaNube)));
        expect(resp.gifSugerido, isNot('enojado'),
            reason: 'una palabra común ("dale", "rápido", "pura") no debe cortar la consulta con un chiste');
      });
    }
    for (final frase in noEsImpaciencia) {
      test('"$frase" llega a la nube, no recibe el chiste', () async {
        _prepararCaso(conSenal: true);
        final resp = await BaqueanoIAService.responder(frase);
        expect(
          _llamadasANube,
          1,
          reason: 'una palabra común ("dale", "rápido", "pura") no debe cortar la consulta con un chiste',
        );
        expect(resp.texto, contains(_marcaNube));
      });
    }

    const siEsImpaciencia = [
      'apurate con la respuesta',
      'hace rato espero que me contestes',
      'no me apures tanto',
    ];
    for (final frase in siEsImpaciencia) {
      test('"$frase" sigue recibiendo la respuesta de impaciencia', () async {
        _prepararCaso(conSenal: true);
        final resp = await BaqueanoIAService.responder(frase);
        expect(_llamadasANube, 0, reason: 'la impaciencia real la atiende el filtro, no la nube');
        expect(resp.texto, isNot(contains(_marcaNube)));
      });
    }

    test('"dale rápido que se hunde la lancha" es una emergencia, no impaciencia', () async {
      _prepararCaso(conSenal: true);
      final resp = await BaqueanoIAService.responder('dale rápido que se hunde la lancha');
      expect(_llamadasANube, 0);
      expect(resp.texto, isNot(contains(_marcaNube)));
      expect(IARouterState.estado.value, IAEstado.offline);
      expect(resp.gifSugerido, isNot('enojado'), reason: 'el GIF de enojo es el del chiste de impaciencia');
    });
  });

  // ── Control de falsos positivos: la pesca normal no es seguridad ──────────
  // Ampliar el reconocimiento de emergencias no debe hacer que el ayudante
  // conteste con teléfonos de Prefectura cuando alguien pregunta por pesca.
  group('no confunde la pesca con seguridad', () {
    const pescaNormal = [
      'cómo pesco a la deriva con mosca',
      'qué carnada uso para el dorado',
      'qué especies están en peligro de extinción en el paraná',
      'se me cayó la caña al río qué hago',
      'cómo armo una línea con tres boyas',
      'a qué hora es mejor pescar pejerrey',
      'cómo preparo el mate con agua caliente',
      'qué hago si no pica nada',
      'cómo limpio un surubí',
      'me recomendás una caña para surubí',
      'qué nudo uso para atar el anzuelo',
      'cuál es el mejor reel para el río',
      // Aparejos que se hunden: sin embarcación ni persona, no es emergencia.
      'cuando la boya se hunde clavá',
      'se me hundió la boya y no clavé',
      'el corcho se hundió y era una boga',
      'la plomada se hunde mucho en la correntada',
      'el señuelo se hunde muy rápido en este tramo',
      'el anzuelo se hundió en el barro',
      'la línea se hunde y se enreda con el pique',
      'por qué se hunde el flote cuando pica el pejerrey',
      'se hundió el corcho dos veces seguidas',
      'qué plomada se hunde más rápido',
      'cuánto tarda en hundirse el señuelo',
      'la boya se hundio y no pude clavar',
      'se undio el corcho y recogí tarde',
      'el flote se me hunde con la corriente',
      'si el corcho se hunde despacio es una mojarra',
      // "Perdido" como "confundido": no es perderse en el río.
      'estoy perdido con los nudos, cuál me conviene',
      'estoy perdido con tanta marca de reel',
      'me perdí con tantas opciones de cañas',
      'me perdí el pique por mirar el celular',
      'me perdí la pesca de ayer por trabajar',
      'estoy perdido con los tipos de plomadas',
      // Caídas, tiradas y agua con aparejos u objetos: no es una persona.
      'tiré la línea al agua y picó un dorado',
      'tiro el anzuelo al agua con carnada viva',
      'se me cayó el celular al agua',
      'la carnada se ahogó en el fondo',
      'el pejerrey salió del agua y se soltó',
      'no sale el pique con este calor',
      'se llena de agua el balde de los peces',
      'cómo evito que entre agua en la caja de señuelos',
      'tiré el reel al río sin querer',
      // "Hace agua" / "se llena de agua" hablando de cosas, no de una embarcación.
      'la conservadora hace agua',
      'el hielo hace agua al derretirse',
      'cómo evito que se llene de agua la caja de señuelos',
    ];
    for (final frase in pescaNormal) {
      test('"$frase"', () {
        expect(
          ElGuiaEngine().clasificarIntencion(frase),
          isNot(ClaseIntencion.seguridad),
          reason: 'una consulta de pesca normal no debe tratarse como emergencia',
        );
      });
    }
  });

  // ── Ante la duda, gana seguridad ──────────────────────────────────────────
  // Frases ambiguas que se tratan como seguridad A PROPÓSITO. Suenan a
  // "confundido", pero "perdido en…" siempre es seguridad: el costo de un falso
  // positivo es un teléfono de más; el de un falso negativo, una persona
  // perdida sin respuesta. Si alguna vez se cambia esta regla, que sea a
  // conciencia y no por accidente.
  group('ante la duda, gana seguridad', () {
    const ambiguas = [
      'estoy perdido en el tema de las carnadas',
      'me perdí en la explicación de los nudos',
      'estoy perdido en este foro de pesca',
      'mi amigo se hunde mientras pesca dorados',
    ];
    for (final frase in ambiguas) {
      test('"$frase" se trata como seguridad', () {
        expect(
          ElGuiaEngine().clasificarIntencion(frase),
          ClaseIntencion.seguridad,
          reason: 'ante la duda, gana seguridad',
        );
      });
    }
  });

  // ── "qué hago" solo es ayuda de la app si habla de la app ──────────────────
  // El activador genérico "que hago" atrapaba preguntas de pesca. Sin señal,
  // una intención reservada impide que el buscador de fichas la vea.
  group('ayuda general exige contexto de la app', () {
    const dePesca = [
      'qué hago con este pescado',
      'qué hago con la carnada que me sobró',
      'qué hago si el pejerrey no come',
    ];
    for (final frase in dePesca) {
      test('"$frase" no es ayuda de la app', () {
        expect(
          ElGuiaEngine().clasificarIntencion(frase),
          ClaseIntencion.otra,
          reason: 'una pregunta de pesca no debe quedar reservada como ayuda de la app',
        );
      });
    }

    const deLaApp = [
      'no sé usar la app',
      'cómo funciona esto',
      'qué hago en la app',
      'cómo uso la app',
    ];
    for (final frase in deLaApp) {
      test('"$frase" sí es ayuda de la app', () {
        expect(
          ElGuiaEngine().clasificarIntencion(frase),
          isNot(ClaseIntencion.otra),
          reason: 'es ayuda de la app: la responde el motor, no queda como pregunta libre',
        );
      });
    }
  });

  // ═══ PASO 0.4 ═════════════════════════════════════════════════════════════
  // Toda respuesta de seguridad trae el 106 y el canal 16 (y en primeros
  // auxilios, también el 107 o el 911), y ninguna es "no lo tengo claro".
  // Los contactos van ANTES de cualquier pregunta o dato extra.
  final canal16 = RegExp(r'canal\s+(?:vhf\s+)?16');

  void contactos(String texto, {bool ambulancia = false}) {
    final t = texto.toLowerCase();
    expect(t, contains('106'), reason: 'falta el 106 de Prefectura');
    expect(canal16.hasMatch(t), isTrue, reason: 'falta el canal 16 de VHF');
    if (ambulancia) {
      expect(t, contains('107'), reason: 'en primeros auxilios falta el 107');
      expect(t, contains('911'), reason: 'en primeros auxilios falta el 911');
    }
    expect(t, isNot(contains('no lo tengo claro')));
    expect(t, isNot(contains('no tengo esa información')));
    expect(t, isNot(contains('ver tabla')), reason: 'remite a una tabla que el usuario no ve');
  }

  group('contactos en TODA respuesta de seguridad', () {
    for (final grupo in _seguridad.entries) {
      for (final frase in grupo.value) {
        test('[${grupo.key}] "$frase"', () async {
          _prepararCaso(conSenal: true);
          final resp = await BaqueanoIAService.responder(frase);
          contactos(resp.texto, ambulancia: grupo.key == 'primeros auxilios' || grupo.key == 'salud sin emergencia');
        });
      }
    }

    test('los turnos del modo pegajoso también traen los contactos', () async {
      // Varias vueltas: la respuesta de "no entendí" es al azar y una sola
      // pasada puede salir bien por casualidad.
      // El modo pegajoso dura 3 turnos: se prueban de a tres, con distintas frases.
      const seguimientos = [
        ['y ahora qué hago?', 'no sé qué hacer', 'qué más'],
        ['sí', 'no', 'ok'],
        ['ayuda', 'qué hago', 'dale'],
        ['no puedo', 'y después', 'gracias'],
      ];
      for (var i = 0; i < 8; i++) {
        for (final turnos in seguimientos) {
          _prepararCaso(conSenal: true);
          await BaqueanoIAService.responder('se hunde la lancha');
          for (final frase in turnos) {
            final resp = await BaqueanoIAService.responder(frase);
            contactos(resp.texto);
          }
        }
      }
    });

    test('si el motor de reglas falla, igual sale el aviso con 106 y canal 16 (y un GIF serio)', () async {
      _prepararCaso(conSenal: true);
      BaqueanoIAService.simularFalloDeReglasParaTest = true;
      final resp = await BaqueanoIAService.responder('se hunde la lancha');
      contactos(resp.texto);
      expect(resp.gifSugerido, isNot('enojado'), reason: 'el aviso de emergencia no puede tener cara de enojo');
    });

    test('las respuestas de seguridad no traen preguntas de seguimiento al azar', () async {
      // Antes salía, por ejemplo, "¿Pediste baquía obligatoria para el Paraná?".
      for (var i = 0; i < 40; i++) {
        _prepararCaso(conSenal: true);
        final resp = await BaqueanoIAService.responder('estoy perdido qué hago?');
        expect(resp.texto, isNot(contains('baquía')));
        expect(resp.texto, isNot(contains('cheraí')));
        expect(resp.texto, isNot(contains('¿')), reason: 'en una emergencia no se piden más datos');
      }
    });
  });

  // ── Test de oro: preguntas reales del dueño ───────────────────────────────
  group('test de oro: preguntas reales del dueño', () {
    Future<ElGuiaRespuesta> preguntar(String frase, {bool conSenal = true}) async {
      _prepararCaso(conSenal: conSenal);
      final resp = await BaqueanoIAService.responder(frase);
      expect(_llamadasANube, 0);
      return resp;
    }

    void esSeguridad(String frase) => expect(
          ElGuiaEngine().clasificarIntencion(frase),
          ClaseIntencion.seguridad,
          reason: '"$frase" tiene que clasificarse como seguridad',
        );

    test('"estoy en la isla perdido, cómo consigo agua?"', () async {
      const p = 'estoy en la isla perdido, cómo consigo agua?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto);
      expect(r.texto.toLowerCase(), contains('herv'), reason: 'tiene que decir cómo potabilizar el agua del río');
    });

    test('"cómo hago fuego?" suelta no es seguridad y se responde bien', () async {
      const p = 'cómo hago fuego?';
      expect(ElGuiaEngine().clasificarIntencion(p), isNot(ClaseIntencion.seguridad));
      // Sin señal: no es seguridad, así que con señal iría a la nube; acá se
      // prueba lo que contesta el motor de reglas.
      final r = await preguntar(p, conSenal: false);
      expect(r.texto.toLowerCase(), matches(RegExp(r'rami|rama|encend|enciend')));
    });

    test('"me picó una raya en la pierna qué hago?"', () async {
      const p = 'me picó una raya en la pierna qué hago?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto, ambulancia: true);
      expect(r.texto.toLowerCase(), contains('agua caliente'));
      expect(r.texto.toLowerCase(), matches(RegExp(r'm[eé]dic')));
      expect(r.texto.toLowerCase(), isNot(contains('presiona la herida')), reason: 'eso es de un corte, no de una raya');
    });

    test('"me mordió una yarará o una víbora qué hago?"', () async {
      const p = 'me mordió una yarará o una víbora qué hago?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto, ambulancia: true);
      expect(r.texto.toLowerCase(), matches(RegExp(r'm[eé]dic')));
    });

    test('"estoy perdido cómo llamo a prefectura?"', () async {
      const p = 'estoy perdido cómo llamo a prefectura?';
      esSeguridad(p);
      contactos((await preguntar(p)).texto);
    });

    test('"me corté la piel, cómo paro el sangrado?"', () async {
      const p = 'me corté la piel, cómo paro el sangrado?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto, ambulancia: true);
      expect(r.texto.toLowerCase(), contains('presion'));
    });

    test('"tengo una fractura, qué hago?"', () async {
      const p = 'tengo una fractura, qué hago?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto, ambulancia: true);
      expect(r.texto.toLowerCase(), contains('inmoviliz'));
      expect(r.texto.toLowerCase(), contains('acomod'), reason: 'tiene que decir que NO se intente acomodar');
    });

    test('"cómo llamo a prefectura?"', () async {
      const p = 'cómo llamo a prefectura?';
      esSeguridad(p);
      contactos((await preguntar(p)).texto);
    });

    test('"cómo pido auxilio?"', () async {
      const p = 'cómo pido auxilio?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto);
      expect(r.texto, contains('911'));
    });

    test('"estoy perdido qué hago?" da pasos concretos y contactos', () async {
      const p = 'estoy perdido qué hago?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto);
      expect(r.texto.toLowerCase(), contains('agua'));
      expect(r.texto.toLowerCase(), contains('señal'), reason: 'tiene que incluir cómo hacerse ver');
    });

    // ── 0.4b: persona al agua y agua que entra tienen pautas propias ─────────
    // Antes caían en la frase genérica de rescate ("hacer fuego visible para
    // rescate aéreo"), que no sirve cuando alguien se cayó al agua.
    group('persona al agua', () {
      const frases = [
        'se cayó mi hijo al agua',
        'hombre al agua',
        'persona al agua',
        'mi amigo se tiró al agua y no sale',
        'se ahoga mi hijo',
        'el nene no sale del agua',
      ];
      for (final p in frases) {
        test('"$p"', () async {
          esSeguridad(p);
          final r = await preguntar(p);
          contactos(r.texto);
          final t = r.texto.toLowerCase();
          expect(t, contains('pierdas de vista'), reason: 'no perderla de vista');
          expect(t, contains('flote'), reason: 'tirarle algo que flote');
          expect(t, contains('no te tires'), reason: 'no tirarse salvo que no haya otra opción');
          expect(t, contains('neutro'), reason: 'acercar la embarcación con el motor en neutro');
          expect(t, isNot(contains('fuego visible')), reason: 'esa es la frase genérica de rescate');
        });
      }
    });

    group('entra agua en la embarcación', () {
      const frases = [
        'la lancha se está llenando de agua',
        'se nos llenó de agua el bote',
        'hace agua',
        'se está llenando de agua',
        'entra agua al bote',
        'el barco hace agua',
      ];
      for (final p in frases) {
        test('"$p"', () async {
          esSeguridad(p);
          final r = await preguntar(p);
          contactos(r.texto);
          final t = r.texto.toLowerCase();
          expect(t, contains('chaleco'), reason: 'todos con el chaleco puesto');
          expect(t, contains('achic'), reason: 'achicar el agua');
          expect(t, contains('costa'), reason: 'ir hacia la costa más cercana');
          expect(t, contains('no abandones'), reason: 'no abandonar la embarcación mientras flote');
          expect(t, isNot(contains('fuego visible')), reason: 'esa es la frase genérica de rescate');
        });
      }
    });

    test('anzuelo: con y sin el error "una anzuelo" dan la MISMA respuesta buena', () async {
      const bien = 'se me clavó un anzuelo qué hago?';
      const mal = 'se me clavo una anzuelo';
      esSeguridad(bien);
      esSeguridad(mal);
      final a = await preguntar(bien);
      final b = await preguntar(mal);
      contactos(a.texto, ambulancia: true);
      expect(a.texto.toLowerCase(), contains('anzuelo'));
      expect(a.texto.toLowerCase(), contains('no intentes'));
      expect(b.texto, a.texto, reason: 'el error de tipeo no puede cambiar la respuesta');
    });

    test('"algo me picó porque se hincha": primeros auxilios y signos de alarma', () async {
      const p = 'algo me picó porque se hincha';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto, ambulancia: true);
      expect(r.texto.toLowerCase(), matches(RegExp(r'garganta|respirar')), reason: 'tiene que nombrar los signos de alergia grave');
    });

    test('"estoy perdido en la isla, qué puedo hacer para comer?"', () async {
      const p = 'estoy perdido en la isla, qué puedo hacer para comer?';
      esSeguridad(p);
      final r = await preguntar(p);
      contactos(r.texto);
      expect(r.texto.toLowerCase(), contains('pesc'), reason: 'tiene que orientar sobre alimento (la pesca)');
    });
  });

  // ── Modo emergencia pegajoso: los 3 turnos siguientes también van a reglas ─
  group('modo emergencia pegajoso', () {
    const seguimientos = [
      'y ahora qué hago?',
      'no sé qué hacer',
      'qué más',
    ];

    test('después de una emergencia, los 3 turnos siguientes no usan la nube', () async {
      _prepararCaso(conSenal: true);
      await BaqueanoIAService.responder('se hunde la lancha');
      for (final frase in seguimientos) {
        final resp = await BaqueanoIAService.responder(frase);
        expect(_llamadasANube, 0, reason: 'seguimiento "$frase" llegó a la nube');
        expect(resp.texto, isNot(contains(_marcaNube)));
        expect(IARouterState.estado.value, IAEstado.offline);
      }
    });

    test('el modo emergencia vence: el cuarto turno ya puede usar la nube', () async {
      _prepararCaso(conSenal: true);
      await BaqueanoIAService.responder('se hunde la lancha');
      for (final frase in seguimientos) {
        await BaqueanoIAService.responder(frase);
      }
      await BaqueanoIAService.responder('qué opinás del fútbol');
      expect(_llamadasANube, 1, reason: 'pasados los 3 turnos, la nube vuelve a poder responder (la charla, no la pesca: paso 4)');
    });
  });
}
