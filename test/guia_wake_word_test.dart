// Fase R (voz): el "wake word" (escuchar la frase de activación mientras el Guía duerme) queda APAGADO por flag.
//
// Medido en el Moto G15 (docs/ESTADO.md): con el Guía acostado, cada 6 s la app abría el micrófono con `onDevice: true` y
// `es_AR`; el celular no tiene ese paquete sin conexión y fallaba al instante (`error_language_not_supported`). Resultado:
// luz verde de grabación y ruido cada 6 s, batería gastada, y nunca reconoció nada. Las preguntas del dueño entran por el
// botón del micrófono, no por esto. Se apaga con `guia_wake_word` (por defecto false) y se puede volver a encender.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/guia_wake_word.dart';

bool _decidir({
  bool mostrar = true,
  bool permite = true,
  bool durmiendo = true,
  bool escuchando = false,
  bool silenciado = false,
  bool micActivo = true,
}) =>
    GuiaWakeWord.debeEscuchar(
      mostrarGuia: mostrar,
      permiteInteractuar: permite,
      durmiendo: durmiendo,
      escuchando: escuchando,
      silenciado: silenciado,
      micActivo: micActivo,
    );

void main() {
  setUp(() => GuiaWakeWord.habilitado = false);

  test('por defecto está apagado', () {
    expect(GuiaWakeWord.habilitado, isFalse);
  });

  test('apagado: nunca escucha, ni con el Guía durmiendo y todo en orden', () {
    expect(_decidir(), isFalse);
  });

  group('encendido por flag (se puede volver a activar)', () {
    setUp(() => GuiaWakeWord.habilitado = true);
    test('durmiendo y todo en orden: escucha', () => expect(_decidir(), isTrue));
    test('Guía oculto: no', () => expect(_decidir(mostrar: false), isFalse));
    test('presentándose: no', () => expect(_decidir(permite: false), isFalse));
    test('despierto: no', () => expect(_decidir(durmiendo: false), isFalse));
    test('ya escuchando: no', () => expect(_decidir(escuchando: true), isFalse));
    test('silenciado: no', () => expect(_decidir(silenciado: true), isFalse));
    test('micrófono desactivado en Ajustes: no', () => expect(_decidir(micActivo: false), isFalse));
  });

  test('aplicarFlags lee la preferencia guia_wake_word', () async {
    SharedPreferences.setMockInitialValues({'guia_wake_word': true});
    GuiaWakeWord.aplicarFlags(await SharedPreferences.getInstance());
    expect(GuiaWakeWord.habilitado, isTrue);
    SharedPreferences.setMockInitialValues({});
    GuiaWakeWord.habilitado = false;
    GuiaWakeWord.aplicarFlags(await SharedPreferences.getInstance());
    expect(GuiaWakeWord.habilitado, isFalse);
  });

  // Hay dos puertas: el overlay decide cuándo, y VoiceService lo ejecuta. Las dos tienen que respetar el flag.
  test('el overlay decide con GuiaWakeWord.debeEscuchar', () {
    final codigo = File('lib/widgets/guia_overlay.dart').readAsStringSync();
    expect(codigo, contains('GuiaWakeWord.debeEscuchar('));
  });

  test('VoiceService.startWakeWordListener no abre el micrófono si el flag está apagado', () {
    final codigo = File('lib/services/voice_service.dart').readAsStringSync();
    final inicio = codigo.indexOf('Future<void> startWakeWordListener');
    expect(inicio, greaterThan(0));
    final cuerpo = codigo.substring(inicio, inicio + 400);
    expect(cuerpo, contains('GuiaWakeWord.habilitado'));
    expect(cuerpo.indexOf('GuiaWakeWord.habilitado'), lessThan(cuerpo.indexOf('stopListening')));
  });

  test('el flag se carga al arrancar el motor, junto a los otros guia_*', () {
    final codigo = File('lib/services/el_guia_engine.dart').readAsStringSync();
    expect(codigo, contains('GuiaWakeWord.aplicarFlags(prefs)'));
  });
}
