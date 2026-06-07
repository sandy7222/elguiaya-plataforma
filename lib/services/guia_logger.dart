import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

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

  /// Registra una pregunta del usuario con la intención detectada.
  static Future<void> registrar({
    required String texto,
    required String intencion,
    bool esFallback = false,
  }) async {
    try {
      final archivo = await _obtenerArchivo();
      final timestamp = DateTime.now().toIso8601String();

      // Si el archivo no existe, crear con header
      final existe = await archivo.exists();
      if (!existe) {
        await archivo.writeAsString(
          'timestamp,intencion,texto,fallback\n',
          mode: FileMode.write,
        );
      }

      // Sanitizar el texto para CSV (eliminar comas y saltos de línea)
      final textoSanitizado = texto
          .replaceAll('"', "'")
          .replaceAll(',', ';')
          .replaceAll('\n', ' ')
          .trim();

      final linea = '$timestamp,$intencion,"$textoSanitizado",${esFallback ? "si" : "no"}\n';

      // Agregar al archivo
      await archivo.writeAsString(linea, mode: FileMode.append);

      // Control de tamaño: si supera el límite, rotar el archivo
      final lineas = await archivo.readAsLines();
      if (lineas.length > _maxEntradas) {
        // Guardar solo las últimas N/2 entradas
        final mitad = lineas.sublist(lineas.length - (_maxEntradas ~/ 2));
        await archivo.writeAsString(
          'timestamp,intencion,texto,fallback\n${mitad.skip(1).join('\n')}\n',
        );
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
        'pregunta': pregunta,
        'motivo': motivo,
        'timestamp': DateTime.now().toIso8601String(),
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
