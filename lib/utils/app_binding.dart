import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/widgets.dart';

/// Binding de la app (Fase R, R.3): pone un TOPE al tamaño con que se decodifica toda imagen.
///
/// Medido en el Moto G15 (docs/INFORME_MEMORIA_R1.md): al abrir la Tienda la memoria gráfica sube de 102 a 473 MB en
/// 4 segundos; hay 112 `Image.network` y solo 2 con `cacheWidth`, así que las fotos se decodifican a su tamaño real
/// (una de 4000×3000 ocupa 48 MB). Acá se limita el lado más largo de TODA imagen que no pidió un tamaño propio:
/// 4000×3000 pasa a 800×600 (1,9 MB). Los GIFs del avatar (426×240) y cualquier imagen con `cacheWidth` no se tocan.
class AppBinding extends WidgetsFlutterBinding {
  /// Lado más largo permitido, en píxeles. 800 alcanza para cualquier tarjeta en un celular.
  static const int maxLado = 800;

  static bool _inicializado = false;

  /// Reemplaza a `WidgetsFlutterBinding.ensureInitialized()` en `main()`.
  static WidgetsBinding ensureInitialized() {
    if (!_inicializado) {
      _inicializado = true;
      AppBinding();
    }
    return WidgetsBinding.instance;
  }

  /// A qué tamaño decodificar una imagen de [w]×[h]. Si el widget pidió el suyo ([pedido], por ejemplo `cacheWidth`),
  /// se respeta; si no, se aplica el tope conservando la proporción.
  static ui.TargetImageSize tamanoObjetivo(int w, int h, ui.TargetImageSizeCallback? pedido) {
    final propio = pedido?.call(w, h);
    if (propio != null && (propio.width != null || propio.height != null)) return propio;
    final lado = math.max(w, h);
    if (lado <= maxLado) return ui.TargetImageSize(width: w, height: h);
    final f = maxLado / lado;
    return ui.TargetImageSize(width: math.max(1, (w * f).round()), height: math.max(1, (h * f).round()));
  }

  @override
  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) {
    return super.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (int w, int h) => tamanoObjetivo(w, h, getTargetSize),
    );
  }
}
