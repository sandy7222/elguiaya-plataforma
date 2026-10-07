// Fase R, R.3b (regla del dueño): los videos se reproducen solo con la Tienda abierta y a la vista.
// Con la Tienda cerrada (pestaña oculta o app en segundo plano) no tiene que existir ningún reproductor;
// con la Tienda abierta, uno solo: el del banner visible.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/banner_video_cache.dart';
import 'package:capitanya_master/widgets/banner_media_widget.dart';

const _url = 'https://example.com/banner.mp4';

Widget _app({required bool tiendaAbierta}) => MaterialApp(
      home: TickerMode(
        enabled: tiendaAbierta,
        child: const Scaffold(body: SizedBox(height: 200, child: VideoLoopPlayer(url: _url))),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el tope es de un solo reproductor', () {
    final c = BannerVideoCache.instance;
    expect(BannerVideoCache.maxReproductores, 1);
    expect(c.activos.value, 0);
    expect(c.reservarCupo(), isTrue);
    expect(c.reservarCupo(), isFalse, reason: 'el segundo banner no puede abrir otro reproductor');
    c.devolverCupo();
    expect(c.activos.value, 0);
    expect(c.reservarCupo(), isTrue);
    c.devolverCupo();
  });

  testWidgets('con la Tienda cerrada hay cero reproductores', (tester) async {
    await tester.pumpWidget(_app(tiendaAbierta: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(BannerVideoCache.instance.activos.value, 0);
  });

  testWidgets('con la app en segundo plano hay cero reproductores', (tester) async {
    await tester.pumpWidget(_app(tiendaAbierta: true));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 300));
    expect(BannerVideoCache.instance.activos.value, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('al cerrar la Tienda se libera el reproductor (cupo vuelve a 0)', (tester) async {
    await tester.pumpWidget(_app(tiendaAbierta: true));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(_app(tiendaAbierta: false));
    await tester.pump(const Duration(milliseconds: 300));
    expect(BannerVideoCache.instance.activos.value, 0);
  });
}
