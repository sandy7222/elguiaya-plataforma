// Fase 2 (2.1): registro anónimo de las preguntas.
//
// Antes de guardar una pregunta, una limpieza borra correos, teléfonos, secuencias de 6 o más
// dígitos y lo que sigue a "me llamo" o "soy". El registro guarda solo el DÍA (no la hora). La
// rotación del archivo se revisa cada 100 registros, no en cada uno.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/guia_anonimizador.dart';
import 'package:capitanya_master/services/guia_logger.dart';

String _l(String t) => GuiaAnonimizador.limpiar(t);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ── 20 textos con datos personales: 0 quedan ───────────────────────────────
  // (texto, lo que NO puede aparecer en la salida)
  const conDatos = <(String, List<String>)>[
    ('mi mail es juan.perez@gmail.com, mandame la cotización', ['juan.perez', '@gmail']),
    ('escribime a pescador_87@hotmail.com.ar por el viaje', ['pescador_87', '@hotmail']),
    ('contacto: capitan+viajes@mi-sitio.com.ar', ['capitan+viajes', '@mi-sitio']),
    ('llamame al 11 5555 1234 para coordinar', ['5555', '1234']),
    ('mi celular es +54 9 11 4444-5555', ['4444', '5555']),
    ('mi número: (011) 15-6789-0123 dale', ['6789', '0123']),
    ('whatsapp 341 555 6677', ['555', '6677']),
    ('tel 0343-4221234', ['4221234']),
    ('mi dni es 30123456', ['30123456']),
    ('DNI 28.456.789 del capitán', ['456.789', '28.456']),
    ('el cbu es 0170099220000012345678', ['0170099220000012345678']),
    ('me llamo Carlos Gómez y quiero reservar', ['Carlos', 'Gómez']),
    ('hola, me llamo Marcela, soy de Rosario', ['Marcela', 'Rosario']),
    ('soy Roberto Sánchez, pescador del Paraná', ['Roberto', 'Sánchez']),
    ('mi nombre es Lucía Fernández', ['Lucía', 'Fernández']),
    ('buenas, soy el Tano Rodríguez', ['Rodríguez']),
    ('pasame el contacto: 3434 123456 y mail pepe@yahoo.com', ['3434', '123456', 'pepe@']),
    ('mi patente es AB123CD y mi teléfono 1155667788', ['1155667788']),
    ('entrá a https://miweb.com/perfil?id=887766 para ver', ['887766', 'miweb.com/perfil']),
    ('transferí al 2850590940090418135201 y avisame', ['2850590940090418135201']),
  ];

  group('0 datos personales quedan', () {
    test('hay 20 textos', () => expect(conDatos.length, 20));
    for (final c in conDatos) {
      test('"${c.$1}"', () {
        final s = _l(c.$1);
        for (final prohibido in c.$2) {
          expect(s, isNot(contains(prohibido)), reason: 'quedó "$prohibido": $s');
        }
        // Ninguna secuencia de 6 o más dígitos (con separadores comunes) sobrevive.
        for (final m in RegExp(r'\d[\d ().\-]{4,}\d').allMatches(s)) {
          expect(m.group(0)!.replaceAll(RegExp(r'\D'), '').length, lessThan(6), reason: s);
        }
        expect(s, isNot(contains('@')), reason: s);
      });
    }
  });

  group('lo que no es personal se conserva', () {
    const limpios = [
      'qué carnada uso para el dorado',
      'cómo se hace el nudo palomar',
      'pesco con 20 libras de línea y 0,8 mm',
      'salgo a las 6:30 con 3 amigos',
      'el reel pesa 250 gramos',
      'cuánto sale el viaje de 8 horas',
      'estoy perdido en la isla, cómo consigo agua?',
      'me duele la cabeza, qué tomo',
      'cómo llamo a prefectura?',
      'quiero llamar al capitán',
    ];
    for (final t in limpios) {
      test('"$t"', () => expect(_l(t), t));
    }

    test('"soy" y "me llamo" sin nombre detrás no rompen nada', () {
      expect(_l('soy'), 'soy');
      expect(_l('no sé cómo me llamo'), isNotEmpty);
    });
  });

  group('propiedades', () {
    test('es idempotente', () {
      for (final c in conDatos) {
        final una = _l(c.$1);
        expect(_l(una), una);
      }
    });
    test('no devuelve más largo que el original más un marcador por dato', () {
      for (final c in conDatos) {
        expect(_l(c.$1).length, lessThan(c.$1.length + 30));
      }
    });
    test('el texto vacío queda vacío', () => expect(_l(''), ''));
  });

  // ── El registro: solo el día, texto limpio, rotación cada 100 ──────────────
  group('GuiaLogger', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('guia_logger_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (call) async => tmp.path);
      GuiaLogger.reiniciarParaTest();
    });
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), null);
      tmp.deleteSync(recursive: true);
    });

    File csv() => File('${tmp.path}/guia_preguntas.csv');

    test('guarda el texto ya limpio', () async {
      await GuiaLogger.registrar(texto: 'me llamo Carlos Gómez, mi mail es carlos@gmail.com', intencion: 'saludo');
      final t = csv().readAsStringSync();
      expect(t, isNot(contains('Carlos')));
      expect(t, isNot(contains('@gmail')));
    });

    test('guarda solo el día: sin hora, minutos ni segundos', () async {
      await GuiaLogger.registrar(texto: 'qué carnada uso', intencion: 'carnadas');
      final fila = csv().readAsLinesSync()[1];
      final primera = fila.split(',').first;
      expect(primera, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')), reason: 'la primera columna es solo el día: $primera');
      expect(fila, isNot(matches(RegExp(r'\d{2}:\d{2}'))));
    });

    test('el encabezado dice "dia", no "timestamp"', () async {
      await GuiaLogger.registrar(texto: 'hola', intencion: 'saludo');
      expect(csv().readAsLinesSync().first, startsWith('dia,'));
    });

    test('el registro de búsquedas (retrieval) también va limpio y con solo el día', () async {
      await GuiaLogger.registrarRetrieval(
        texto: 'soy Pedro Gómez, llamame al 11 4444 5555',
        decision: 'directa',
        intencionReglas: 'fallback',
        usoSemantico: false,
        s1: 0.5,
        s2: 0.1,
        ms: 3,
        top3: 'peces:0.50',
      );
      final t = File('${tmp.path}/guia_retrieval.csv').readAsStringSync();
      expect(t, isNot(contains('Pedro')));
      expect(t, isNot(contains('4444')));
      expect(t.split('\n')[1].split(',').first, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    });

    test('los fallos offline también van limpios y con solo el día', () async {
      await GuiaLogger.registrarFalloOffline(pregunta: 'soy Ana Pérez, mi dni es 30111222', motivo: 'sin ficha');
      final t = File('${tmp.path}/guia_fallos_offline.json').readAsStringSync();
      expect(t, isNot(contains('Ana')));
      expect(t, isNot(contains('30111222')));
      expect(t, isNot(matches(RegExp(r'T\d{2}:\d{2}'))));
    });

    test('la rotación se revisa cada 100 registros, no en cada uno', () async {
      // Con un tope de 5 filas se ve cuándo rota: recién al llegar al registro 100.
      GuiaLogger.maxEntradasParaTest = 5;
      for (var i = 1; i <= 99; i++) {
        await GuiaLogger.registrar(texto: 'pregunta $i', intencion: 'x');
      }
      expect(csv().readAsLinesSync().length - 1, 99, reason: 'hasta el 99 no se revisa nada');
      await GuiaLogger.registrar(texto: 'pregunta 100', intencion: 'x');
      final filas = csv().readAsLinesSync().length - 1;
      expect(filas, lessThanOrEqualTo(5), reason: 'en el 100 se revisó y rotó: quedan $filas');
    });
  });
}
