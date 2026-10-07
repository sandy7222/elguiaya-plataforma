import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Instrumento de medición de memoria (Fase R, R.1). **Apagado en las compilaciones normales**: solo
/// funciona si se compila con `--dart-define=DIAG_MEM=true`. No cambia nada del comportamiento de la app.
///
/// Cada 5 segundos escribe en el registro (`adb logcat -s flutter | findstr DIAG_MEM`) lo que sabe el
/// caché de imágenes de Flutter: cuántas imágenes decodificadas tiene guardadas y cuántos MB suman, cuántas
/// están "vivas" (en pantalla o retenidas por algún widget) y cuántas se están cargando. Sirve para saber si
/// la memoria gráfica que mide Android (`dumpsys meminfo`, "Graphics") son imágenes decodificadas.
class DiagMemoria {
  static const bool activo = bool.fromEnvironment('DIAG_MEM');

  /// Diagnóstico R.3 (`--dart-define=DIAG_SIN_GIF=true`): el avatar usa una imagen fija en vez de los 22 GIFs.
  static const bool sinGif = bool.fromEnvironment('DIAG_SIN_GIF');

  /// Diagnóstico R.3 (`--dart-define=DIAG_SIN_VIDEO=true`): los banners con video no reproducen nada.
  static const bool sinVideo = bool.fromEnvironment('DIAG_SIN_VIDEO');
  static Timer? _timer;

  static void iniciar() {
    if (!activo || _timer != null) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _escribir());
    _escribir();
  }

  static void _escribir() {
    final c = PaintingBinding.instance.imageCache;
    String mb(int b) => (b / 1048576).toStringAsFixed(1);
    debugPrint('[DIAG_MEM] imageCache: ${c.currentSize} imágenes · ${mb(c.currentSizeBytes)} MB '
        '(tope ${c.maximumSize} imágenes / ${mb(c.maximumSizeBytes)} MB) · vivas ${c.liveImageCount} · cargando ${c.pendingImageCount}');
  }
}
