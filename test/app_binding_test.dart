// Fase R, R.3: tope global al tamaño con que se decodifican las imágenes.
//
// Medido en el Moto G15 (docs/INFORME_MEMORIA_R1.md): al abrir la Tienda la memoria gráfica sube de 102 a 473 MB en
// 4 segundos, con 8 imágenes en el caché de Flutter que suman 93 MB (≈11,6 MB cada una: fotos enormes decodificadas a
// su tamaño real). En toda la app hay 112 `Image.network` y solo 2 con `cacheWidth`. En lugar de tocar los 110 sitios,
// `AppBinding` limita el lado más largo de TODA imagen que no pidió un tamaño propio. Una foto de 4000×3000 (48 MB
// decodificada) pasa a 800×600 (1,9 MB). Los GIFs del avatar (426×240) no se tocan.

import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/utils/app_binding.dart';

void main() {
  group('AppBinding.tamanoObjetivo', () {
    test('una foto grande se achica al tope, conservando la proporción', () {
      final t = AppBinding.tamanoObjetivo(4000, 3000, null);
      expect(t.width, 800);
      expect(t.height, 600);
    });

    test('una foto vertical también', () {
      final t = AppBinding.tamanoObjetivo(3000, 4000, null);
      expect(t.width, 600);
      expect(t.height, 800);
    });

    test('una imagen chica (el GIF del avatar, 426×240) no se toca', () {
      final t = AppBinding.tamanoObjetivo(426, 240, null);
      expect(t.width, 426);
      expect(t.height, 240);
    });

    test('justo en el tope no se toca', () {
      final t = AppBinding.tamanoObjetivo(800, 800, null);
      expect(t.width, 800);
      expect(t.height, 800);
    });

    test('si el widget pidió su propio tamaño (cacheWidth), se respeta', () {
      final t = AppBinding.tamanoObjetivo(4000, 3000, (w, h) => const ui.TargetImageSize(width: 300, height: 225));
      expect(t.width, 300);
      expect(t.height, 225);
    });

    test('si el widget pidió solo el ancho, se respeta y no se pisa', () {
      final t = AppBinding.tamanoObjetivo(4000, 3000, (w, h) => const ui.TargetImageSize(width: 500));
      expect(t.width, 500);
      expect(t.height, isNull);
    });

    test('una imagen enorme de 12000 px cae bajo el tope', () {
      final t = AppBinding.tamanoObjetivo(12000, 9000, null);
      expect(t.width! <= AppBinding.maxLado && t.height! <= AppBinding.maxLado, isTrue);
    });

    test('el tope es de 800 px (alcanza para cualquier tarjeta del celular)', () {
      expect(AppBinding.maxLado, 800);
    });

    test('nunca devuelve 0 (una imagen muy alargada)', () {
      final t = AppBinding.tamanoObjetivo(10000, 3, null);
      expect(t.width, 800);
      expect(t.height, greaterThanOrEqualTo(1));
    });

    test('el costo decodificado baja de 48 MB a menos de 2 MB para una foto de 4000×3000', () {
      final t = AppBinding.tamanoObjetivo(4000, 3000, null);
      final antes = 4000 * 3000 * 4 / 1048576;
      final despues = t.width! * t.height! * 4 / 1048576;
      expect(antes, greaterThan(40));
      expect(despues, lessThan(2));
    });
  });
}
