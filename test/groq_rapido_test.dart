// Paso 1.5 de docs/PLAN_AYUDANTE_IA.md: Groq más rápido.
//
// El cliente le pide a gpt-oss-120b `reasoning_effort: "low"` y un tope de
// `max_completion_tokens` (600: el razonamiento también gasta tokens). Si el tope
// corta la respuesta (finish_reason "length" o texto vacío) se reintenta con más
// margen y, de última, sin tope: una respuesta cortada nunca llega al usuario. Si
// Groq rechazara los parámetros (400), se apagan por esta sesión y se repite el
// pedido normal.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/groq_service.dart';
import 'package:capitanya_master/services/ia_edge_function_client.dart';

http.Response _groq({String contenido = 'Hola, chamigo.', String finish = 'stop', int status = 200}) {
  final cuerpo = status == 200
      ? {
          'choices': [
            {
              'message': {'content': contenido},
              'finish_reason': finish,
            },
          ],
        }
      : {
          'error': {'message': 'bad request'},
        };
  return AiEdgeFunctionClient.respuestaDelProxy({'status': status, 'body': cuerpo});
}

/// Igual que lo lee `GroqService.responder`: utf8.decode(bodyBytes).
String _texto(http.Response r) =>
    jsonDecode(utf8.decode(r.bodyBytes))['choices'][0]['message']['content'] as String;

const _mensajes = [
  {'role': 'user', 'content': 'hola'},
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> pedidos;

  void responderCon(List<http.Response> respuestas) {
    pedidos = [];
    var i = 0;
    AiEdgeFunctionClient.invocadorParaTest = (body) async {
      pedidos.add(body);
      return respuestas[i < respuestas.length ? i++ : respuestas.length - 1];
    };
  }

  setUp(() {
    GroqService.rapido = true;
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => AiEdgeFunctionClient.invocadorParaTest = null);

  Future<http.Response> pedir() => GroqService.pedirChat(messages: _mensajes, temperature: 0.7);

  test('el pedido lleva reasoning_effort low y max_completion_tokens 600', () async {
    responderCon([_groq()]);
    await pedir();
    expect(pedidos.length, 1);
    expect(pedidos.first['provider'], 'groq');
    expect(pedidos.first['reasoning_effort'], 'low');
    expect(pedidos.first['max_completion_tokens'], 600);
  });

  test('con el flag apagado el pedido va como siempre (sin los dos parámetros)', () async {
    GroqService.rapido = false;
    responderCon([_groq()]);
    await pedir();
    expect(pedidos.first.containsKey('reasoning_effort'), isFalse);
    expect(pedidos.first.containsKey('max_completion_tokens'), isFalse);
  });

  test('una respuesta completa se pide una sola vez', () async {
    responderCon([_groq()]);
    final r = await pedir();
    expect(pedidos.length, 1);
    expect(_texto(r), 'Hola, chamigo.');
  });

  test('cortada por el tope (finish_reason length): reintenta con 1200', () async {
    responderCon([_groq(contenido: 'Mirá, chami', finish: 'length'), _groq(contenido: 'Mirá, chamigo, completo.')]);
    final r = await pedir();
    expect(pedidos.length, 2);
    expect(pedidos[1]['max_completion_tokens'], 1200);
    expect(pedidos[1]['reasoning_effort'], 'low');
    expect(_texto(r), 'Mirá, chamigo, completo.');
  });

  test('texto vacío (el razonamiento se comió el tope): también reintenta', () async {
    responderCon([_groq(contenido: '', finish: 'length'), _groq(contenido: 'Ahora sí.')]);
    final r = await pedir();
    expect(pedidos.length, 2);
    expect(_texto(r), 'Ahora sí.');
  });

  test('cortada otra vez: tercer pedido SIN tope, y nunca llega una respuesta cortada', () async {
    responderCon([
      _groq(contenido: 'a', finish: 'length'),
      _groq(contenido: 'b', finish: 'length'),
      _groq(contenido: 'Respuesta entera sin tope.'),
    ]);
    final r = await pedir();
    expect(pedidos.length, 3);
    expect(pedidos[2].containsKey('max_completion_tokens'), isFalse);
    expect(pedidos[2].containsKey('reasoning_effort'), isFalse);
    expect(_texto(r), 'Respuesta entera sin tope.');
  });

  test('si Groq rechaza los parámetros (400): se apagan y se repite el pedido normal', () async {
    responderCon([_groq(status: 400), _groq(contenido: 'Normal.')]);
    final r = await pedir();
    expect(pedidos.length, 2);
    expect(pedidos[1].containsKey('reasoning_effort'), isFalse);
    expect(GroqService.rapido, isFalse, reason: 'queda apagado por esta sesión');
    expect(_texto(r), 'Normal.');
    // y el pedido siguiente ya sale normal, de una sola vez
    responderCon([_groq()]);
    await pedir();
    expect(pedidos.length, 1);
    expect(pedidos.first.containsKey('reasoning_effort'), isFalse);
  });

  test('otros errores (500) no se reintentan acá: los maneja el router', () async {
    responderCon([_groq(status: 500)]);
    final r = await pedir();
    expect(pedidos.length, 1);
    expect(r.statusCode, 500);
  });

  test('aplicarFlags lee la preferencia', () async {
    SharedPreferences.setMockInitialValues({GroqService.prefRapido: false});
    GroqService.aplicarFlags(await SharedPreferences.getInstance());
    expect(GroqService.rapido, isFalse);
    SharedPreferences.setMockInitialValues({});
    GroqService.rapido = true;
    GroqService.aplicarFlags(await SharedPreferences.getInstance());
    expect(GroqService.rapido, isTrue);
  });

  // ── La respuesta del proxy tiene que sobrevivir a las tildes y los emojis ──
  // `http.Response(String)` sin charset codifica en latin1: una tilde salía como un
  // byte suelto (utf8.decode fallaba) y un emoji o una comilla curva tiraba una
  // excepción. Toda respuesta en castellano de la nube caía al motor offline.
  group('respuestaDelProxy: UTF-8', () {
    const textos = [
      'Mirá, chamigo: el dorado pica con luna llena.',
      'Pescá con paciencia — y abrigate bien.',
      'Dijo “dale” y se fue 🎣',
      'ñandú, pingüino, canción, ¿viste?',
    ];
    for (final t in textos) {
      test('"$t"', () {
        final r = AiEdgeFunctionClient.respuestaDelProxy({
          'status': 200,
          'body': {
            'choices': [
              {
                'message': {'content': t},
              },
            ],
          },
        });
        expect(r.statusCode, 200);
        expect(_texto(r), t, reason: 'tal como lo lee GroqService.responder: utf8.decode(bodyBytes)');
      });
    }
    test('una respuesta incompleta del proxy sigue siendo un error', () {
      expect(() => AiEdgeFunctionClient.respuestaDelProxy('no es un mapa'), throwsStateError);
      expect(() => AiEdgeFunctionClient.respuestaDelProxy({'status': 200}), throwsStateError);
      expect(() => AiEdgeFunctionClient.respuestaDelProxy({'body': {}}), throwsStateError);
    });
  });
}
