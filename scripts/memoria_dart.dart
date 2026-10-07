// Fase R, R.1: mira POR DENTRO la memoria de la app en el celular (solo funciona con un APK --profile).
//
//   1) flutter run --profile -d <celular> --no-resident      (instala y abre la app)
//   2) adb logcat -d -s flutter | findstr "VM service"         → anotá el puerto del celular
//   3) adb forward tcp:8181 tcp:<puerto>
//   4) dart run scripts/memoria_dart.dart ws://127.0.0.1:8181/<token>=/ws "etiqueta"
//
// Imprime, para el isolate principal: el uso del heap de Dart (usado, capacidad, memoria externa) y las
// 15 clases que más memoria retienen (propia + externa: ahí aparecen las imágenes decodificadas). La memoria
// externa de las clases `Image`/`Codec` es la que ocupan las texturas y los GIFs decodificados.
//
// Es de solo lectura: no cambia nada en la app.

import 'dart:io';
import 'package:vm_service/vm_service.dart';
import 'package:vm_service/vm_service_io.dart';

String mb(num? b) => b == null ? '—' : (b / 1048576).toStringAsFixed(1);

Future<void> main(List<String> args) async {
  final url = args.isNotEmpty ? args[0] : '';
  final etiqueta = args.length > 1 ? args[1] : '';
  if (url.isEmpty) {
    stderr.writeln('Uso: dart run scripts/memoria_dart.dart ws://127.0.0.1:PUERTO/TOKEN=/ws "etiqueta"');
    exit(64);
  }
  final svc = await vmServiceConnectUri(url);
  try {
    final vm = await svc.getVM();
    final isolate = vm.isolates!.firstWhere((i) => i.name == 'main', orElse: () => vm.isolates!.first);
    final uso = await svc.getMemoryUsage(isolate.id!);
    stdout.writeln('== $etiqueta ==');
    stdout.writeln('Heap de Dart: usado ${mb(uso.heapUsage)} MB · capacidad ${mb(uso.heapCapacity)} MB · externo ${mb(uso.externalUsage)} MB');

    final perfil = await svc.getAllocationProfile(isolate.id!, gc: true);
    final miembros = [...?perfil.members];
    int total(ClassHeapStats m) => (m.bytesCurrent ?? 0) + (m.accumulatedSize != null ? 0 : 0);
    miembros.sort((a, b) => total(b).compareTo(total(a)));
    stdout.writeln('Clases con más memoria retenida (MB) y cantidad de instancias:');
    for (final m in miembros.take(15)) {
      stdout.writeln('  ${mb(total(m)).padLeft(8)} MB  ${(m.instancesCurrent ?? 0).toString().padLeft(8)}  ${m.classRef?.name}');
    }
    final imagenes = miembros.where((m) => const {'Image', '_Image', 'Codec', '_Codec', 'ImageInfo', 'ImageStreamCompleter', 'MultiFrameImageStreamCompleter'}.contains(m.classRef?.name));
    stdout.writeln('Clases de imágenes:');
    for (final m in imagenes) {
      stdout.writeln('  ${m.classRef?.name}: ${m.instancesCurrent} instancias · ${mb(m.bytesCurrent)} MB');
    }
    // Ojo: el tamaño de las imágenes decodificadas NO se puede leer desde acá (son memoria nativa del motor; el
    // ancho y el alto de `_Image` son funciones nativas). Para eso está DiagMemoria (caché de imágenes de Flutter).
    stdout.writeln('Memoria externa total del perfil: ${mb(perfil.memoryUsage?.externalUsage)} MB');
  } finally {
    await svc.dispose();
  }
}
