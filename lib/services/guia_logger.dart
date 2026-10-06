import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'guia_anonimizador.dart';

/// GuiaLogger — Registra cada pregunta del usuario al Gu-IA en un CSV local.
///
/// Propósito:
///   Cuando la app esté en producción, este archivo se puede revisar
///   para ver el top de preguntas reales que hace la gente.
///   Eso permite nutrir el bot con intenciones y activadores reales.
///
/// Formato del CSV:
///   timestamp,intencion_detectada,texto_original,fallback
///
/// Uso:
///   GuiaLogger.registrar(texto: 'quiero pescar', intencion: 'crear_viaje');
///
/// Ver el archivo:
///   GuiaLogger.obtenerRutaArchivo() → ruta absoluta del CSV
///   GuiaLogger.leerTop(n: 20) → top N preguntas más frecuentes
class GuiaLogger {
  static const String _nombreArchivo = 'guia_preguntas.csv';
  static const int _maxEntradas = 5000; // Límite para no crecer infinito

  /// La rotación del archivo se REVISA cada 100 registros (no en cada uno: leer todo el
  /// archivo por cada pregunta era caro). Un contador por archivo.
  static const int _cadaCuantosRevisar = 100;
  static int _contadorPreguntas = 0;
  static int _contadorRetrieval = 0;

  @visibleForTesting
  static int? maxEntradasParaTest;

  @visibleForTesting
  static void reiniciarParaTest() {
    _contadorPreguntas = 0;
    _contadorRetrieval = 0;
    maxEntradasParaTest = null;
  }

  static int get _tope => maxEntradasParaTest ?? _maxEntradas;

  /// Solo el DÍA, nunca la hora: con la hora y un texto se puede reconstruir quién preguntó.
  static String _dia(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Registra una pregunta del usuario con la intención detectada.
  static Future<void> registrar({
    required String texto,
    required String intencion,
    bool esFallback = false,
  }) async {
    try {
      final archivo = await _obtenerArchivo();
      final dia = _dia(DateTime.now());

      // Si el archivo no existe, crear con header
      final existe = await archivo.exists();
      if (!existe) {
        await archivo.writeAsString(
          'dia,intencion,texto,fallback\n',
          mode: FileMode.write,
        );
      }

      // Datos personales fuera ANTES de guardar; después, sanitizar para CSV.
      final textoSanitizado = GuiaAnonimizador.limpiar(texto)
          .replaceAll('"', "'")
          .replaceAll(',', ';')
          .replaceAll('\n', ' ')
          .trim();

      final linea = '$dia,$intencion,"$textoSanitizado",${esFallback ? "si" : "no"}\n';

      // Agregar al archivo
      await archivo.writeAsString(linea, mode: FileMode.append);

      // Control de tamaño: se revisa cada 100 registros, no en cada uno.
      if (++_contadorPreguntas % _cadaCuantosRevisar == 0) {
        final lineas = await archivo.readAsLines();
        if (lineas.length > _tope) {
          // Guardar solo las últimas N/2 entradas
          final mitad = lineas.sublist(lineas.length - (_tope ~/ 2).clamp(1, _tope));
          await archivo.writeAsString(
            'dia,intencion,texto,fallback\n${mitad.skip(mitad.first.startsWith('dia,') || mitad.first.startsWith('timestamp,') ? 1 : 0).join('\n')}\n',
          );
        }
      }
    } catch (e) {
      // El logger nunca debe romper la app — silencioso
      // ignore: avoid_print
      print('[GuiaLogger] Error al registrar: $e');
    }
  }

  /// Devuelve las N preguntas más frecuentes que cayeron en fallback.
  /// Útil para saber qué no entiende el bot y nutrir los activadores.
  static Future<List<Map<String, dynamic>>> leerTopFallbacks({int n = 20}) async {
    try {
      final archivo = await _obtenerArchivo();
      if (!await archivo.exists()) return [];

      final lineas = await archivo.readAsLines();
      final conteo = <String, int>{};

      for (final linea in lineas.skip(1)) {
        final partes = linea.split(',');
        if (partes.length >= 4 && partes[3].trim() == 'si') {
          final texto = partes.length >= 3 ? partes[2].replaceAll('"', '') : '';
          if (texto.isNotEmpty) {
            conteo[texto] = (conteo[texto] ?? 0) + 1;
          }
        }
      }

      // Ordenar por frecuencia descendente
      final ordenado = conteo.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return ordenado
          .take(n)
          .map((e) => {'texto': e.key, 'veces': e.value})
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Devuelve estadísticas básicas: total de preguntas, % fallback, top intenciones.
  static Future<Map<String, dynamic>> estadisticas() async {
    try {
      final archivo = await _obtenerArchivo();
      if (!await archivo.exists()) {
        return {'total': 0, 'fallbacks': 0, 'porcentaje_fallback': 0.0};
      }

      final lineas = await archivo.readAsLines();
      final datos = lineas.skip(1).toList();
      final total = datos.length;
      final fallbacks = datos.where((l) => l.endsWith(',si')).length;
      final conteoIntenciones = <String, int>{};

      for (final linea in datos) {
        final partes = linea.split(',');
        if (partes.length >= 2) {
          final intencion = partes[1];
          conteoIntenciones[intencion] = (conteoIntenciones[intencion] ?? 0) + 1;
        }
      }

      final topIntenciones = (conteoIntenciones.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
        .take(10)
        .map((e) => {'intencion': e.key, 'veces': e.value})
        .toList();

      return {
        'total': total,
        'fallbacks': fallbacks,
        'porcentaje_fallback':
            total > 0 ? (fallbacks / total * 100).toStringAsFixed(1) : '0.0',
        'top_intenciones': topIntenciones,
        'ruta': archivo.path,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Devuelve la ruta absoluta del archivo CSV.
  static Future<String> obtenerRutaArchivo() async {
    final archivo = await _obtenerArchivo();
    return archivo.path;
  }

  static Future<File> _obtenerArchivo() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_nombreArchivo');
  }

  // ── Retrieval-first (Fase 5) ─────────────────────────────────────────────
  static const String _nombreArchivoRetrieval = 'guia_retrieval.csv';
  static const String _headerRetrieval =
      'dia,decision,intencion_reglas,uso_semantico,s1,s2,ms,top3,texto\n';

  /// Registra cada búsqueda del retriever: pregunta, franja (directa /
  /// aclarar / ninguna), top-3 con puntajes y tiempos. Es la materia prima
  /// del Paso 6 (calibración con logs reales): se lee con [leerRetrieval] o
  /// se exporta con `mini_model_lab/retrieval/analizar_logs.py`.
  static Future<void> registrarRetrieval({
    required String texto,
    required String decision,
    required String intencionReglas,
    required bool usoSemantico,
    required double s1,
    required double s2,
    required int ms,
    required String top3,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final archivo = File('${dir.path}/$_nombreArchivoRetrieval');
      if (!await archivo.exists()) {
        await archivo.writeAsString(_headerRetrieval, mode: FileMode.write);
      }
      String limpiar(String s) =>
          GuiaAnonimizador.limpiar(s).replaceAll('"', "'").replaceAll(',', ';').replaceAll('\n', ' ').trim();
      final linea = '${_dia(DateTime.now())},$decision,$intencionReglas,'
          '${usoSemantico ? 'si' : 'no'},${s1.toStringAsFixed(3)},${s2.toStringAsFixed(3)},'
          '$ms,"${limpiar(top3)}","${limpiar(texto)}"\n';
      await archivo.writeAsString(linea, mode: FileMode.append);

      if (++_contadorRetrieval % _cadaCuantosRevisar == 0) {
        final lineas = await archivo.readAsLines();
        if (lineas.length > _tope) {
          final mitad = lineas.sublist(lineas.length - (_tope ~/ 2).clamp(1, _tope));
          await archivo.writeAsString('$_headerRetrieval${mitad.skip(mitad.first.startsWith('dia,') || mitad.first.startsWith('timestamp,') ? 1 : 0).join('\n')}\n');
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[GuiaLogger] Error al registrar retrieval: $e');
    }
  }

  /// Devuelve las últimas [n] búsquedas del retriever (más recientes al final),
  /// ya parseadas. Para la pantalla de admin / calibración.
  static Future<List<Map<String, String>>> leerRetrieval({int n = 200}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final archivo = File('${dir.path}/$_nombreArchivoRetrieval');
      if (!await archivo.exists()) return [];
      final lineas = await archivo.readAsLines();
      final campos = _headerRetrieval.trim().split(',');
      final salida = <Map<String, String>>[];
      for (final l in lineas.skip(1)) {
        final partes = l.split(',');
        if (partes.length < campos.length) continue;
        // los dos últimos campos van entre comillas y no tienen comas (se
        // reemplazaron por ';'), así que el split directo alcanza
        final fila = <String, String>{};
        for (var i = 0; i < campos.length; i++) {
          fila[campos[i]] = partes[i].replaceAll('"', '');
        }
        salida.add(fila);
      }
      return salida.length > n ? salida.sublist(salida.length - n) : salida;
    } catch (_) {
      return [];
    }
  }

  /// Ruta del CSV de retrieval (para compartirlo / copiarlo al laboratorio).
  static Future<String> obtenerRutaRetrieval() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/$_nombreArchivoRetrieval';
  }

  /// Registra un fallo de búsqueda en librerías offline en un archivo JSON local.
  static Future<void> registrarFalloOffline({
    required String pregunta,
    required String motivo,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final archivo = File('${dir.path}/guia_fallos_offline.json');
      
      List<dynamic> fallos = [];
      if (await archivo.exists()) {
        try {
          final contenido = await archivo.readAsString();
          fallos = json.decode(contenido) as List<dynamic>;
        } catch (_) {}
      }

      final nuevoFallo = {
        'pregunta': GuiaAnonimizador.limpiar(pregunta),
        'motivo': motivo,
        'dia': _dia(DateTime.now()),
      };

      if (fallos.length >= 500) {
        fallos.removeRange(0, 100);
      }
      fallos.add(nuevoFallo);

      await archivo.writeAsString(json.encode(fallos), mode: FileMode.write);
    } catch (e) {
      // ignore: avoid_print
      print('[GuiaLogger] Error al registrar fallo offline: $e');
    }
  }
}
