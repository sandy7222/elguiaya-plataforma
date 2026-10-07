// Acciones del robot: "tomá mate", "sentate y escuchá", "reíte", "ponete furioso"... el robot actúa con sus GIFs.
//
// Pedido del dueño (2026-10-07): que se le pueda ordenar al robot que haga lo que ya tiene grabado (los GIFs tienen un nombre que dice
// lo que hacen). Se resuelve sin nube ni IA: una tabla editable (`assets/elguia/acciones_robot.json`) y un detector que exige que la
// frase sea TODA la orden (así "pensá en una carnada para el dorado" o "cómo se toma mate" siguen siendo preguntas). Una emergencia
// nunca dispara una gracia del robot (el portón de seguridad va antes).

import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/guia_acciones_robot.dart';
import 'package:capitanya_master/services/ia_router_state.dart';
import 'package:capitanya_master/widgets/capitan_asistente.dart';

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
    await GuiaAccionesRobot.cargar();
  });
  setUp(() {
    GuiaAccionesRobot.habilitado = true;
    GuiaAccionesRobot.pedida.value = null;
  });
  tearDown(() {
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = true;
  });

  // frase → estado esperado
  const ordenes = <String, String>{
    'tomá mate': 'tomaMate',
    'tomamos mate?': 'tomaMate',
    'tomemos unos mates': 'tomaMate',
    'cebá un mate': 'tomaMate',
    'sacá el mate': 'tomaMate',
    'che Guía, tomá mate por favor': 'tomaMate',
    'dale, tomamos mate': 'tomaMate',
    'sentate y escuchá': 'soloEscucha',
    'sentate': 'soloEscucha',
    'reíte': 'rieGana',
    'reite fuerte': 'rieGana',
    'ponete a reír': 'rieGana',
    'ponete furioso': 'enojado',
    'enojate': 'enojado',
    'dale, ponete furioso un rato': 'enojado',
    'ponete triste': 'triste',
    'saludá': 'saludo',
    'saludá a la gente': 'saludo',
    'dormite': 'durmiendo',
    'andá a dormir': 'durmiendo',
    'despertate': 'despierta',
    'pensá': 'piensaLeve',
    'jugamos a las cartas': 'juegaCartas',
    'hacé el OK': 'exito',
  };

  group('detecta la orden', () {
    ordenes.forEach((frase, estado) {
      test('"$frase" → $estado', () {
        final a = GuiaAccionesRobot.detectar(frase);
        expect(a, isNotNull);
        expect(a!.estado, estado);
        expect(a.respuesta.trim(), isNotEmpty);
      });
    });
  });

  // Así habla el dueño (prueba en el celular, 18:57): "Hola guía, cómo estás, me gustaría saber si podés tomar mate". La orden viene
  // metida en una frase más larga, como pedido ("podés...", "quiero que...", "me gustaría que..."). Se entiende si hay un pedido
  // explícito + la acción, sin negación, y casi nada después de la acción.
  group('pedidos dentro de una frase más larga', () {
    const pedidos = <String, String>{
      'Hola guía cómo estás me gustaría saber si podés tomar mate': 'tomaMate',
      'hola guía, ¿podés tomar mate?': 'tomaMate',
      'quiero que tomes unos mates conmigo': 'tomaMate',
      'me gustaría que tomes mate': 'tomaMate',
      'che guía, ¿podés tomar un mate?': 'tomaMate',
      'te pido que te sientes y escuches': 'soloEscucha',
      'quiero que te rías': 'rieGana',
      '¿podés reírte un poco?': 'rieGana',
      'me gustaría que te pongas furioso': 'enojado',
      'hola, ¿podés ponerte furioso?': 'enojado',
      '¿podés ponerte triste?': 'triste',
      'quiero que saludes a todos': 'saludo',
      '¿podés saludar a la gente?': 'saludo',
      'quiero que te vayas a dormir': 'durmiendo',
      '¿podés dormirte un rato?': 'durmiendo',
      'necesito que te despiertes': 'despierta',
      'me gustaría que juguemos a las cartas': 'juegaCartas',
      '¿podés hacer el ok?': 'exito',
    };
    pedidos.forEach((frase, estado) {
      test('"$frase" → $estado', () {
        final a = GuiaAccionesRobot.detectar(frase);
        expect(a, isNotNull);
        expect(a!.estado, estado);
      });
    });

    const siguenSiendoPreguntas = [
      'cómo puedo tomar mate con poca yerba',
      'podés decirme qué carnada uso para el dorado',
      'podés pensar en una carnada para el dorado',
      'me gustaría saber cómo se toma mate',
      'quiero que me expliques cómo tomar mate sin lavado',
      'podés tomar mate con yerba del Paraná es lo mejor que hay en el mundo entero',
      'no quiero que tomes mate',
      'no podés tomar mate ahora',
      'quiero que no te rías',
      'podés decirme si hay veda del surubí',
      'hola guía cómo estás',
      'me gustaría saber qué peces hay en el Paraná',
      'podés ayudarme con un nudo',
      'quiero que me cuentes un chiste',
    ];
    for (final f in siguenSiendoPreguntas) {
      test('sigue siendo pregunta: "$f"', () => expect(GuiaAccionesRobot.detectar(f), isNull));
    }

    test('el router lo cumple sin nube y avisa al robot flotante', () async {
      _preparar();
      final r = await BaqueanoIAService.responder('Hola guía cómo estás me gustaría saber si podés tomar mate');
      expect(_llamadas, 0);
      expect(r.gifSugerido, 'tomaMate');
      expect(GuiaAccionesRobot.pedida.value?.estado, 'tomaMate');
    });
  });

  group('NO es una orden (sigue siendo una pregunta o charla)', () {
    const noSon = [
      'cómo se toma mate',
      'qué mate me recomendás',
      'pensá en una carnada para el dorado',
      'pensá que mañana hay sudestada',
      'no te rías',
      'no tomes mate ahora',
      'no te pongas furioso',
      'sentate a esperar el pique me dijo mi tío',
      'tomá mate con yerba del Paraná es lo mejor que hay',
      'qué hago si me pongo furioso con el reel enredado',
      'hola',
      'qué hora es',
      'contame algo del fútbol',
      'cuándo es la veda del surubí',
      '',
      '   ',
    ];
    for (final f in noSon) {
      test('"$f"', () => expect(GuiaAccionesRobot.detectar(f), isNull));
    }
  });

  test('con el flag apagado no detecta nada', () {
    GuiaAccionesRobot.habilitado = false;
    expect(GuiaAccionesRobot.detectar('tomá mate'), isNull);
  });

  test('aplicarFlags lee guia_acciones_robot', () async {
    SharedPreferences.setMockInitialValues({'guia_acciones_robot': false});
    GuiaAccionesRobot.aplicarFlags(await SharedPreferences.getInstance());
    expect(GuiaAccionesRobot.habilitado, isFalse);
    SharedPreferences.setMockInitialValues({});
    GuiaAccionesRobot.habilitado = true;
    GuiaAccionesRobot.aplicarFlags(await SharedPreferences.getInstance());
    expect(GuiaAccionesRobot.habilitado, isTrue);
  });

  group('el router: la orden se cumple sin nube', () {
    const delRouter = {
      'tomá mate',
      'sentate y escuchá',
      'reíte',
      'ponete furioso',
      'ponete triste',
      'dormite',
      'jugamos a las cartas',
      'saludá',
      'despertate',
      'pensá',
      'hacé el OK',
    };
    ordenes.forEach((frase, estado) {
      if (!delRouter.contains(frase)) return;
      test('"$frase" → gif $estado, 0 llamadas a la nube', () async {
        _preparar();
        final r = await BaqueanoIAService.responder(frase);
        expect(_llamadas, 0);
        expect(r.gifSugerido, estado);
        expect(r.texto, isNot(contains(_marcaNube)));
        expect(r.texto.trim(), isNotEmpty);
      });
    });

    test('una emergencia gana: tras "se hunde la lancha", "tomá mate" no hace la gracia', () async {
      _preparar();
      await BaqueanoIAService.responder('se hunde la lancha');
      final r = await BaqueanoIAService.responder('tomá mate');
      expect(r.gifSugerido, isNot('tomaMate'));
      expect(_llamadas, 0);
    });

    test('una pregunta de pesca sigue su camino', () async {
      _preparar();
      final r = await BaqueanoIAService.responder('qué carnada uso para el surubí');
      expect(r.texto.toLowerCase(), contains('carnada'));
    });
  });

  group('la tabla (assets/elguia/acciones_robot.json)', () {
    final datos = jsonDecode(File('assets/elguia/acciones_robot.json').readAsStringSync()) as Map<String, dynamic>;
    final acciones = (datos['acciones'] as List).cast<Map<String, dynamic>>();
    final estados = CapitanState.values.map((e) => e.name).toSet();
    final overlay = File('lib/widgets/guia_overlay.dart').readAsStringSync();

    test('cada acción tiene un estado válido y un GIF que existe', () {
      for (final a in acciones) {
        expect(estados, contains(a['estado']), reason: a['id'].toString());
        expect(File('assets/gifs/${a['gif']}').existsSync(), isTrue, reason: '${a['id']}: ${a['gif']}');
      }
    });
    test('cada acción tiene frases y respuestas, y las frases van normalizadas (sin tildes, signos ni mayúsculas)', () {
      for (final a in acciones) {
        expect((a['frases'] as List), isNotEmpty, reason: a['id'].toString());
        expect((a['respuestas'] as List), isNotEmpty, reason: a['id'].toString());
        for (final f in (a['frases'] as List).cast<String>()) {
          expect(f, matches(RegExp(r'^[a-z0-9 ]+$')), reason: '"$f" en ${a['id']}');
        }
      }
    });
    test('los pedidos van normalizados, no se repiten y cada acción tiene los suyos (menos pensar)', () {
      final vistos = <String, String>{};
      for (final a in acciones) {
        final ps = (a['pedidos'] as List? ?? const []).cast<String>();
        if (a['id'] != 'pensar') expect(ps, isNotEmpty, reason: a['id'].toString());
        for (final p in ps) {
          expect(p, matches(RegExp(r'^[a-z0-9 ]+$')), reason: '"$p" en ${a['id']}');
          expect(vistos.containsKey(p), isFalse, reason: '"$p" está en ${vistos[p]} y en ${a['id']}');
          vistos[p] = a['id'].toString();
        }
      }
      for (final m in (datos['marcadores_pedido'] as List).cast<String>()) {
        expect(m, matches(RegExp(r'^[a-z0-9 ]+$')), reason: m);
      }
    });
    test('ninguna frase se repite entre acciones', () {
      final vistas = <String, String>{};
      for (final a in acciones) {
        for (final f in (a['frases'] as List).cast<String>()) {
          expect(vistas.containsKey(f), isFalse, reason: '"$f" está en ${vistas[f]} y en ${a['id']}');
          vistas[f] = a['id'].toString();
        }
      }
    });
    test('las respuestas no mencionan la tienda ni traen datos', () {
      for (final a in acciones) {
        for (final r in (a['respuestas'] as List).cast<String>()) {
          expect(r.toLowerCase(), isNot(contains('tienda')), reason: r);
          expect(RegExp(r'\d').hasMatch(r), isFalse, reason: r);
        }
      }
    });
    test('el overlay sabe pasar cada estado de la tabla a su animación (_gifToState)', () {
      for (final a in acciones) {
        expect(overlay, contains("case '${a['estado']}':"), reason: 'falta en _gifToState: ${a['estado']}');
      }
    });
  });

  test('el router detecta las acciones después del portón de seguridad', () {
    final c = File('lib/services/baqueano_ia_service.dart').readAsStringSync();
    final puerta = c.indexOf('PORTÓN DE SEGURIDAD');
    final accion = c.indexOf('GuiaAccionesRobot.detectar(');
    final sticky = c.indexOf('_turnosEmergenciaRestantes > 0');
    expect(accion, greaterThan(puerta));
    expect(accion, greaterThan(sticky));
  });

  // Hallazgo de la prueba del dueño: el chat de la pestaña "El Guía" llamaba al router y descartaba la animación, y el robot flotante
  // no se enteraba. Ahora el router publica el pedido y el overlay lo escucha, venga de donde venga la orden.
  group('el robot flotante se entera de la orden (aunque venga del chat)', () {
    test('el router publica el pedido con el estado', () async {
      _preparar();
      await BaqueanoIAService.responder('tomá mate');
      expect(GuiaAccionesRobot.pedida.value, isNotNull);
      expect(GuiaAccionesRobot.pedida.value!.estado, 'tomaMate');
    });
    test('la misma orden dos veces vuelve a disparar el aviso', () async {
      _preparar();
      var avisos = 0;
      void oyente() => avisos++;
      GuiaAccionesRobot.pedida.addListener(oyente);
      addTearDown(() => GuiaAccionesRobot.pedida.removeListener(oyente));
      await BaqueanoIAService.responder('tomá mate');
      await BaqueanoIAService.responder('tomá mate');
      expect(avisos, 2);
    });
    test('una pregunta no publica nada', () async {
      _preparar();
      await BaqueanoIAService.responder('qué carnada uso para el surubí');
      expect(GuiaAccionesRobot.pedida.value, isNull);
    });
    test('una emergencia no publica nada', () async {
      _preparar();
      await BaqueanoIAService.responder('se hunde la lancha');
      expect(GuiaAccionesRobot.pedida.value, isNull);
    });
    test('el overlay escucha el aviso y lo suelta al cerrarse', () {
      final c = File('lib/widgets/guia_overlay.dart').readAsStringSync();
      expect(c, contains('GuiaAccionesRobot.pedida.addListener(_onAccionRobot)'));
      expect(c, contains('GuiaAccionesRobot.pedida.removeListener(_onAccionRobot)'));
    });
    test('si el overlay está dormido o apagado no hace nada raro: solo reacciona si el Guía está a la vista', () {
      final c = File('lib/widgets/guia_overlay.dart').readAsStringSync();
      final i = c.indexOf('void _onAccionRobot()');
      expect(i, greaterThan(0));
      expect(c.substring(i, i + 400), contains('_mostrarGuia'));
    });
  });

  test('al dormirse, el overlay apaga el modo conversación (si no, reabre el micrófono y se despierta)', () {
    final c = File('lib/widgets/guia_overlay.dart').readAsStringSync();
    expect(c, contains('if (nuevoEstado == CapitanState.durmiendo) _modoConversacionVoz = false;'));
  });

  test('el flag se carga con los otros guia_*', () {
    expect(File('lib/services/el_guia_engine.dart').readAsStringSync(), contains('GuiaAccionesRobot.aplicarFlags(prefs)'));
  });
}
