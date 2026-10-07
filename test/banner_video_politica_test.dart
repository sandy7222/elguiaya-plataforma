// Fase R, R.3b: política de reproducción de los videos de banners.
//
// Medido en el Moto G15 (docs/INFORME_MEMORIA_R1.md): con los videos de banners la memoria del recorrido completo
// pasó de 551 a 945 MB. Regla: solo se reproduce lo que se ve (pestaña visible + app en primer plano) y en equipos
// de 4 GB o menos no se reproduce video: se muestra una imagen fija.

import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/banner_video_politica.dart';

void main() {
  group('equipo liviano', () {
    test('el Moto G15 (3,78 GB) es liviano', () {
      expect(BannerVideoPolitica.esEquipoLiviano(3870), isTrue);
    });
    test('justo 4 GB es liviano', () {
      expect(BannerVideoPolitica.esEquipoLiviano(4096), isTrue);
    });
    test('6 GB no es liviano', () {
      expect(BannerVideoPolitica.esEquipoLiviano(5600), isFalse);
    });
    test('si no se pudo medir la RAM, no se asume liviano', () {
      expect(BannerVideoPolitica.esEquipoLiviano(null), isFalse);
    });
  });

  group('debeReproducir', () {
    test('visible, app activa, equipo con RAM: reproduce', () {
      expect(BannerVideoPolitica.debeReproducir(visible: true, appActiva: true, ramMb: 8000), isTrue);
    });
    test('pestaña oculta: no reproduce', () {
      expect(BannerVideoPolitica.debeReproducir(visible: false, appActiva: true, ramMb: 8000), isFalse);
    });
    test('app en segundo plano: no reproduce', () {
      expect(BannerVideoPolitica.debeReproducir(visible: true, appActiva: false, ramMb: 8000), isFalse);
    });
    test('equipo de 4 GB: nunca reproduce, aunque esté visible', () {
      expect(BannerVideoPolitica.debeReproducir(visible: true, appActiva: true, ramMb: 3870), isFalse);
    });
    test('RAM desconocida: reproduce si está visible y activa', () {
      expect(BannerVideoPolitica.debeReproducir(visible: true, appActiva: true, ramMb: null), isTrue);
    });
  });
}
