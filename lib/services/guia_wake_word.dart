import 'package:shared_preferences/shared_preferences.dart';

/// "Wake word": escuchar la frase de activación mientras el Guía duerme (flag `guia_wake_word`, **apagado por defecto**).
///
/// Medido en el Moto G15: cada 6 s abría el micrófono (`onDevice: true`, `es_AR`) y fallaba al instante con
/// `error_language_not_supported` porque el celular no tiene ese paquete sin conexión. Efecto: luz verde de grabación y ruido
/// cada 6 s, batería gastada y ningún reconocimiento. Las preguntas entran por el botón del micrófono. Para volver a
/// encenderlo (cuando exista el paquete sin conexión): `SharedPreferences` `guia_wake_word` = true.
class GuiaWakeWord {
  static const String prefWakeWord = 'guia_wake_word';
  static bool habilitado = false;

  static void aplicarFlags(SharedPreferences prefs) {
    habilitado = prefs.getBool(prefWakeWord) ?? habilitado;
  }

  /// Decide si hay que escuchar la frase de activación ahora.
  static bool debeEscuchar({
    required bool mostrarGuia,
    required bool permiteInteractuar,
    required bool durmiendo,
    required bool escuchando,
    required bool silenciado,
    required bool micActivo,
  }) =>
      habilitado && mostrarGuia && permiteInteractuar && durmiendo && !escuchando && !silenciado && micActivo;
}
