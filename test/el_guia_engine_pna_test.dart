import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ElGuiaEngine - Prefectura Naval Argentina Offline Tests', () {
    late ElGuiaEngine engine;

    setUp(() {
      engine = ElGuiaEngine();
    });

    test('1. PNA General Fallback Response', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('prefectura naval argentina');
      // ignore: avoid_print
      print('Respuesta General: ${respuesta.texto}');
      
      expect(respuesta.texto.toLowerCase(), contains('emergencia'));
      expect(respuesta.texto.toLowerCase(), contains('canal 16'));
    });

    test('2. PNA Kilometer Response (Rosario km 400)', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('estoy en el km 400 del parana, a que prefectura llamo?');
      // ignore: avoid_print
      print('Respuesta Km 400: ${respuesta.texto}');

      expect(respuesta.texto, contains('Rosario'));
      expect(respuesta.texto, contains('L6I'));
      expect(respuesta.texto, contains('14'));
    });

    test('3. PNA Kilometer Range Multiple Match (km 1300)', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('dame el canal de prefectura en el km 1300');
      // ignore: avoid_print
      print('Respuesta Km 1300: ${respuesta.texto}');

      expect(respuesta.texto, contains('Itatí'));
      expect(respuesta.texto, contains('Bermejo'));
    });

    test('4. PNA Locality Match (Corrientes)', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('que canal usa prefectura en corrientes capital?');
      // ignore: avoid_print
      print('Respuesta Corrientes: ${respuesta.texto}');

      expect(respuesta.texto, contains('Corrientes'));
      expect(respuesta.texto, contains('L6Y'));
    });

    test('5. PNA Calling Steps Procedure', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('como llamo por radio a prefectura?');
      // ignore: avoid_print
      print('Respuesta Procedimiento: ${respuesta.texto}');

      expect(respuesta.texto.toLowerCase(), contains('sintonizá'));
      expect(respuesta.texto.toLowerCase(), contains('presioná'));
      expect(respuesta.texto.toLowerCase(), contains('prefectura, prefectura, prefectura'));
    });

    test('6. PNA Radio and Channels Recommendations', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('que radio me recomendas llevar y que canales uso?');
      // ignore: avoid_print
      print('Respuesta Recomendaciones: ${respuesta.texto}');

      expect(respuesta.texto.toLowerCase(), contains('waterproof'));
      expect(respuesta.texto.toLowerCase(), contains('entre barcos'));
    });

    test('7. PNA QA Canales Match (Canal 70)', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('para que sirve el canal 70?');
      // ignore: avoid_print
      print('Respuesta Canal 70 QA: ${respuesta.texto}');

      expect(respuesta.texto.toLowerCase(), contains('llamada selectiva digital'));
    });

    test('8. PNA Specific Channel Detail Match (Canal 12)', () async {
      await engine.inicializar();

      final respuesta = await engine.responder('cual es la frecuencia de transmisión del canal 12?');
      // ignore: avoid_print
      print('Respuesta Canal 12 Freq: ${respuesta.texto}');

      expect(respuesta.texto, contains('156.600 MHz'));
      expect(respuesta.texto.toLowerCase(), contains('oficial de trabajo'));
    });
  });
}
