// Fase 2 (2.2, alternativa sin tocar la base): exportar el registro anónimo desde el panel de admin.
//
// Mientras no haya una tabla en Supabase para la subida automática (necesita una migración en
// producción, que espera el OK del dueño), el dueño exporta el CSV desde el panel de admin y lo
// manda a mano. Lo exportado ya está anonimizado (se limpia al escribir, ver guia_anonimizador).
//
// Este archivo nace en ROJO a propósito: el servicio y la pantalla todavía no existen.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/screens/admin_guia_registro_screen.dart';
import 'package:capitanya_master/services/guia_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('guia_export_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => tmp.path);
    GuiaLogger.reiniciarParaTest();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
    tmp.deleteSync(recursive: true);
  });

  group('GuiaLogger.archivosParaExportar', () {
    test('sin registros no hay nada para exportar', () async {
      expect(await GuiaLogger.archivosParaExportar(), isEmpty);
    });

    test('devuelve los CSV que existen (preguntas y búsquedas)', () async {
      await GuiaLogger.registrar(texto: 'qué carnada uso', intencion: 'carnadas');
      var a = await GuiaLogger.archivosParaExportar();
      expect(a.map((f) => f.uri.pathSegments.last), ['guia_preguntas.csv']);
      await GuiaLogger.registrarRetrieval(
        texto: 'cómo se hace el nudo palomar',
        decision: 'directa',
        intencionReglas: 'nudos',
        usoSemantico: false,
        s1: 0.9,
        s2: 0.1,
        ms: 2,
        top3: 'nudos:0.90',
      );
      a = await GuiaLogger.archivosParaExportar();
      expect(a.map((f) => f.uri.pathSegments.last), containsAll(['guia_preguntas.csv', 'guia_retrieval.csv']));
    });

    test('lo exportado ya está anonimizado: sin datos personales ni hora', () async {
      await GuiaLogger.registrar(texto: 'me llamo Pablo Díaz, mi mail es pablo@mail.com y mi cel 1144556677', intencion: 'saludo');
      final contenido = (await GuiaLogger.archivosParaExportar()).map((f) => f.readAsStringSync()).join('\n');
      for (final prohibido in ['Pablo', 'Díaz', '@mail', '1144556677']) {
        expect(contenido, isNot(contains(prohibido)));
      }
      expect(contenido, isNot(matches(RegExp(r'\d{2}:\d{2}'))));
    });
  });

  group('GuiaLogger.borrarRegistros', () {
    test('borra los CSV y devuelve cuántos', () async {
      await GuiaLogger.registrar(texto: 'hola', intencion: 'saludo');
      expect(await GuiaLogger.borrarRegistros(), 1);
      expect(await GuiaLogger.archivosParaExportar(), isEmpty);
      expect(await GuiaLogger.borrarRegistros(), 0);
    });
  });

  group('pantalla de admin', () {
    // La pantalla lee archivos de verdad: hay que dejar correr el IO real (runAsync) y recién
    // después dibujar. pumpAndSettle no sirve: el indicador de carga anima sin parar.
    Future<void> abrir(WidgetTester t) async {
      await t.runAsync(() async {
        await t.pumpWidget(const MaterialApp(home: AdminGuiaRegistroScreen()));
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      await t.pump();
      await t.pump(const Duration(milliseconds: 50));
    }

    testWidgets('sin registros lo dice y no ofrece exportar', (t) async {
      await abrir(t);
      expect(find.textContaining('Todavía no hay preguntas'), findsOneWidget);
      expect(find.text('EXPORTAR CSV'), findsNothing);
    });

    testWidgets('con registros muestra el total y el botón de exportar', (t) async {
      await t.runAsync(() async {
        await GuiaLogger.registrar(texto: 'qué carnada uso', intencion: 'carnadas');
        await GuiaLogger.registrar(texto: 'cuánto sale el dólar', intencion: 'fallback', esFallback: true);
      });
      await abrir(t);
      expect(find.textContaining('2 preguntas'), findsOneWidget);
      expect(find.text('EXPORTAR CSV'), findsOneWidget);
      expect(find.textContaining('anónimo'), findsWidgets, reason: 'tiene que explicar que está anonimizado');
    });
  });
}
