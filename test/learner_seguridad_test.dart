// Paso 0.5 de docs/PLAN_AYUDANTE_IA.md: el aprendizaje automático no aprende de
// temas reservados (seguridad y transaccional).
//
// Contexto: cuando Groq responde, puede agregar un bloque |||APRENDO||| con un
// "conocimiento" que se guarda, se consolida y se sube a Supabase para que los
// celulares lo usen sin señal. Si lo aprendido toca una emergencia o un pago, el
// día de mañana un texto inventado por un modelo podría contestar una
// emergencia. Antes solo se miraba el TÍTULO que inventaba Groq, y le faltaban
// primeros auxilios, Prefectura, VHF y pagos.
//
// Se mira la PREGUNTA, el título y cada ACTIVADOR que se iba a guardar. Ante la
// duda, no se aprende: perder un conocimiento de pesca no cuesta nada.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/gemini_learner.dart';

Map<String, dynamic> _bloque({
  required String intencion,
  List<String> activadores = const ['conocimiento de prueba'],
}) =>
    {
      'intencion': intencion,
      'activadores': activadores,
      'respuesta_limpia': 'Respuesta de prueba corta y clara para un pescador.',
      'gif': 'hablaConMate',
      'puntaje': 9,
      'fuente': 'groq_sesion',
    };

/// Corre [GeminiLearner.procesar] y devuelve qué hizo.
Future<String> _procesar(String pregunta, Map<String, dynamic> datos) async {
  final eventos = <String>[];
  GeminiLearner.observadorParaTest = eventos.add;
  try {
    await GeminiLearner.procesar(datos, pregunta);
  } finally {
    GeminiLearner.observadorParaTest = null;
  }
  return eventos.isEmpty ? 'nada' : eventos.first;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // El aprendizaje automático está apagado por defecto; acá se enciende para probar el filtro de seguridad.
    GeminiLearner.aprendizajeAutomatico = true;
  });

  // ── Preguntas reservadas: no se aprende, aunque el título sea inocente ─────
  group('no aprende de una PREGUNTA de seguridad o de pagos', () {
    const preguntasReservadas = [
      // Seguridad
      'se hunde la lancha',
      'me estoy ahogando',
      'se cayó mi hijo al agua',
      'estoy perdido en el río',
      'me picó una raya en la pierna qué hago?',
      'tengo una fractura, qué hago?',
      'se me clavó un anzuelo qué hago?',
      'me mordió una víbora',
      'tengo hipotermia',
      'cómo llamo a prefectura?',
      'cómo pido auxilio?',
      'qué canal uso para pedir auxilio por radio',
      'cómo uso la radio vhf',
      // Pagos y viajes
      'cómo pago el viaje',
      'quiero pagar con tarjeta',
      'mercado pago no me deja pagar',
      'cómo cancelo mi reserva',
      'dónde veo mis cotizaciones',
      'estado de mi viaje',
      'agregar al carrito',
    ];
    for (final pregunta in preguntasReservadas) {
      test('"$pregunta"', () async {
        final evento = await _procesar(pregunta, _bloque(intencion: 'conocimiento_inocente'));
        expect(
          evento,
          startsWith('bloqueado'),
          reason: 'el aprendizaje procesó una consulta reservada ($evento)',
        );
      });
    }
  });

  // ── El título que inventa Groq o los activadores tocan un tema reservado ───
  group('no aprende si el TÍTULO o los ACTIVADORES tocan un tema reservado', () {
    test('título "como_pedir_auxilio_por_radio" con pregunta de pesca', () async {
      final evento = await _procesar(
        'cómo se arma una línea con tres boyas',
        _bloque(intencion: 'como_pedir_auxilio_por_radio'),
      );
      expect(evento, startsWith('bloqueado'));
    });

    test('título "primeros_auxilios_quemadura"', () async {
      final evento = await _procesar(
        'qué hago con un pescado grande',
        _bloque(intencion: 'primeros_auxilios_quemadura'),
      );
      expect(evento, startsWith('bloqueado'));
    });

    test('un activador de emergencia ("se hunde la lancha")', () async {
      final evento = await _procesar(
        'cómo se arma una línea con tres boyas',
        _bloque(intencion: 'linea_tres_boyas', activadores: ['armar linea tres boyas', 'se hunde la lancha']),
      );
      expect(evento, startsWith('bloqueado'));
    });

    test('un activador de Prefectura ("canal 16")', () async {
      final evento = await _procesar(
        'cómo se arma una línea con tres boyas',
        _bloque(intencion: 'linea_tres_boyas', activadores: ['canal 16']),
      );
      expect(evento, startsWith('bloqueado'));
    });

    test('un activador de pagos ("pagar el viaje")', () async {
      final evento = await _procesar(
        'cómo se arma una línea con tres boyas',
        _bloque(intencion: 'linea_tres_boyas', activadores: ['pagar el viaje']),
      );
      expect(evento, startsWith('bloqueado'));
    });

    for (final protegida in ['pagar_viaje', 'crear_viaje', 'gps', 'emergencia', 'primeros_auxilios', 'prefectura_naval_argentina', 'perdido']) {
      test('intención protegida "$protegida"', () async {
        final evento = await _procesar('cómo se arma una línea', _bloque(intencion: protegida));
        expect(evento, startsWith('bloqueado'));
      });
    }
  });

  // ── El router ya sabe que la consulta es reservada ─────────────────────────
  group('evaluarYGuardar con el tema reservado marcado por el router', () {
    const respuesta = 'Hacé esto y listo.\n|||APRENDO|||\n'
        '{"intencion":"nudo_palomar","activadores":["nudo palomar"],'
        '"respuesta_limpia":"Doblá el hilo y pasalo por el ojo.","gif":"hablaConMate","puntaje":9}';

    test('temaReservado: true no procesa nada', () async {
      final eventos = <String>[];
      GeminiLearner.observadorParaTest = eventos.add;
      await GeminiLearner.evaluarYGuardar('se hunde la lancha', respuesta, temaReservado: true);
      GeminiLearner.observadorParaTest = null;
      expect(eventos, isEmpty, reason: 'el router dijo que es un tema reservado');
    });

    test('sin marca, un conocimiento de pesca sí se procesa', () async {
      final eventos = <String>[];
      GeminiLearner.observadorParaTest = eventos.add;
      await GeminiLearner.evaluarYGuardar('cómo hago el nudo palomar', respuesta);
      GeminiLearner.observadorParaTest = null;
      expect(eventos, contains('procesando'));
    });
  });

  // ── No se pasa de largo: la pesca normal se sigue aprendiendo ──────────────
  group('la pesca normal SÍ se sigue aprendiendo', () {
    const casos = [
      ['qué carnada uso para el dorado', 'carnada_dorado', 'carnada para dorado'],
      ['cómo se arma una línea con tres boyas', 'linea_tres_boyas', 'armar linea tres boyas'],
      ['cuál es el mejor reel para surubí', 'reel_surubi', 'reel para surubi'],
      ['por qué se hunde el corcho cuando pica', 'corcho_que_se_hunde', 'corcho se hunde pique'],
      ['cómo clavar el anzuelo cuando pica el pejerrey', 'clavar_pejerrey', 'clavar anzuelo pejerrey'],
      ['estoy perdido con los nudos, cuál me conviene', 'nudos_conviene', 'nudo conviene'],
      ['cómo cocino una boga', 'receta_boga', 'cocinar boga'],
    ];
    for (final c in casos) {
      test('"${c[0]}"', () async {
        final evento = await _procesar(c[0], _bloque(intencion: c[1], activadores: [c[2]]));
        expect(evento, 'procesando', reason: 'se bloqueó un conocimiento de pesca normal ($evento)');
      });
    }
  });
}
