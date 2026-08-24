import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';
import 'package:capitanya_master/services/weather_service.dart';

void main() {
  test('el fallback meteorológico no inventa condiciones favorables', () {
    final weather = WeatherService.datosNoDisponibles();
    expect(weather.datosDisponibles, isFalse);
    expect(weather.descripcion, contains('NO DISPONIBLES'));
    expect(weather.descripcion.toUpperCase(), isNot(contains('IDEAL')));
    expect(weather.pronosticoExtendido, isEmpty);
    expect(weather.pronosticoHorario, isEmpty);
  });

  test('datos incompletos de API no se clasifican como clima favorable', () {
    for (final payload in <Map<String, dynamic>>[
      {},
      {'current': <String, dynamic>{}},
      {'current': <String, dynamic>{'temperature_2m': 22}},
      {'current': <String, dynamic>{'wind_speed_10m': 12}},
    ]) {
      final weather = MarineWeather.fromJson(payload, null);
      expect(weather.datosDisponibles, isFalse);
      expect(weather.descripcion.toUpperCase(), isNot(contains('IDEAL')));
    }
  });

  test('el contenido PNA usa 106 y VHF 16', () {
    final file = File('assets/elguia/librerias/prefectura_naval_argentina.json');
    final data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final pna = data['prefectura_naval_argentina'] as Map<String, dynamic>;
    expect(pna['numero_emergencia_nacional'], '106');
    expect((pna['canal_universal_emergencia'] as Map<String, dynamic>)['canal'], 16);
    expect(file.readAsStringSync(), isNot(contains('0800-999-7622')));
  });

  test('El Guía informa 106 y nunca el teléfono PNA retirado', () async {
    final engine = ElGuiaEngine();
    await engine.inicializar();
    final response = await engine.responder('necesito contactar a Prefectura');
    expect(response.texto, contains('106'));
    expect(response.texto, isNot(contains('0800-999-7622')));
  });
}
