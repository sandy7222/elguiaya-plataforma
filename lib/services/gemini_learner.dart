import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/gemini_config.dart';
import 'guia_local_updater.dart';

/// GeminiLearner — El auto-distilador del conocimiento.
///
/// Cuando Gemini responde al pescador, en background analiza
/// si la respuesta vale la pena guardarse para el motor offline.
/// Si el puntaje >= 6, la guarda como JSON en el directorio de aprendizaje.
///
/// No requiere API Key para funcionar — solo procesa el JSON
/// que Gemini ya devolvió en su respuesta.
class GeminiLearner {
  static const String _carpetaConsolidada = 'guia_aprendido';
  static const String _carpetaPendiente    = 'guia_aprendido_pendiente';
  static const String _carpetaDescartada   = 'guia_descartado';

  static const Set<String> _intencionesProtegidas = {
    'crear_viaje',
    'pagar_viaje',
    'activar_guia',
    'gps',
    'emergencia',
    'ayuda_app',
  };

  static Future<void> evaluarYGuardar(String pregunta, String respuestaCompleta, {bool exito = true}) async {
    if (!exito) return;
    try {
      debugPrint('Iniciando evaluación de aprendizaje...');
      final datos = parsearBloqueAprendizaje(respuestaCompleta);
      if (datos == null) {
        return;
      }
      if (datos['exito'] == false) {
        return;
      }
      await procesar(datos, pregunta);
      debugPrint('Conocimiento enviado a incubadora correctamente');
    } catch (e) {
      debugPrint('Error al evaluar: $e');
    }
  }

  /// Procesa el bloque de aprendizaje extraído de la respuesta de Gemini.
  /// Llamar en background (no await desde el widget).
  static Future<void> procesar(Map<String, dynamic> datos, String preguntaOriginal) async {
    // Normalizar formato si viene del nuevo Prompt Maestro
    if (datos.containsKey('titulo') && !datos.containsKey('intencion')) {
      final String titulo = datos['titulo']?.toString() ?? '';
      final String intencion = titulo
          .toLowerCase()
          .replaceAll(RegExp(r'[^\w\s]'), '')
          .replaceAll(RegExp(r'\s+'), '_')
          .trim();
      datos['intencion'] = intencion;
    }
    if (datos.containsKey('contenido') && !datos.containsKey('respuesta_limpia')) {
      datos['respuesta_limpia'] = datos['contenido'];
    }
    if (!datos.containsKey('activadores')) {
      datos['activadores'] = [datos['titulo'] ?? preguntaOriginal];
    }
    if (datos.containsKey('nivel_confianza') && !datos.containsKey('puntaje')) {
      final double confianza = (datos['nivel_confianza'] as num?)?.toDouble() ?? 1.0;
      datos['puntaje'] = confianza * 10.0;
    }

    try {
      final intencion = datos['intencion']?.toString() ?? '';
      if (intencion.isEmpty || intencion.length < 3) return;

      final respuesta = datos['respuesta_limpia']?.toString() ?? '';
      if (respuesta.isEmpty) return;

      // 1. Verificar si es intención protegida
      if (_intencionesProtegidas.contains(intencion)) {
        await _descartar(intencion, respuesta, preguntaOriginal, 0.0, 'intencion_protegida');
        return;
      }

      // 2. Calcular Scoring Híbrido
      final geminiScore = (datos['puntaje'] as num?)?.toDouble() ?? 0.0;
      final localScore = calcularLocalScore(respuesta);
      final scoreFinal = (geminiScore * 0.4) + (localScore * 0.6);

      if (scoreFinal < GeminiConfig.umbralCalidad) {
        await _descartar(intencion, respuesta, preguntaOriginal, scoreFinal, 'calidad_insuficiente');
        return;
      }

      // Limpiar activadores
      final activadoresRaw = datos['activadores'] as List<dynamic>? ?? [];
      final activadores = activadoresRaw
          .map((e) => e.toString().toLowerCase().trim())
          .where((e) => e.length >= 3)
          .toList();

      if (activadores.isEmpty) return;
      final gif = datos['gif']?.toString() ?? 'hablaConMate';

      final dirConsolidada = await _obtenerDirConsolidada();
      final dirPendiente = await _obtenerDirPendiente();

      final archivoConsolidado = File('${dirConsolidada.path}/$intencion.json');
      final archivoPendiente = File('${dirPendiente.path}/$intencion.json');

      Map<String, dynamic> existente = {};
      bool estaEnConsolidado = false;
      bool estaEnPendiente = false;
      File archivoDestino = archivoPendiente;

      if (await archivoConsolidado.exists()) {
        try {
          existente = json.decode(await archivoConsolidado.readAsString()) as Map<String, dynamic>;
          estaEnConsolidado = true;
          archivoDestino = archivoConsolidado;
        } catch (_) {}
      } else if (await archivoPendiente.exists()) {
        try {
          existente = json.decode(await archivoPendiente.readAsString()) as Map<String, dynamic>;
          estaEnPendiente = true;
          archivoDestino = archivoPendiente;
        } catch (_) {}
      }

      if (!estaEnConsolidado && !estaEnPendiente) {
        // Nueva intención — crear en Pendientes
        final nuevoJson = {
          'intencion': intencion,
          'origen': 'gemini_auto',
          'fuente': datos['fuente']?.toString() ?? 'conocimiento_propio',
          'fecha': DateTime.now().toIso8601String().substring(0, 10),
          'puntaje': scoreFinal,
          'veces_preguntado': 1,
          'consolidada': false,
          'activadores': activadores.take(8).toList(),
          'respuestas': [respuesta],
          'gif': gif,
          'ejemplo_pregunta': preguntaOriginal,
        };
        await archivoPendiente.writeAsString(
          const JsonEncoder.withIndent('  ').convert(nuevoJson),
        );
        await GeminiConfig.incrementarAprendidas();
        // ignore: avoid_print
        print('[Learner] ✅ Nueva intención incubando: $intencion (score $scoreFinal)');
      } else {
        // Enriquecer
        final activadoresExistentes = List<String>.from(
          (existente['activadores'] as List<dynamic>? ?? []).map((e) => e.toString()),
        );
        final respuestasExistentes = List<String>.from(
          (existente['respuestas'] as List<dynamic>? ?? []).map((e) => e.toString()),
        );
        int vecesPreguntado = (existente['veces_preguntado'] as num?)?.toInt() ?? 1;
        final double puntajeExistente = (existente['puntaje'] as num?)?.toDouble() ?? 0.0;

        // Agregar activadores nuevos hasta un máximo de 8
        for (final a in activadores) {
          if (!activadoresExistentes.contains(a) && activadoresExistentes.length < 8) {
            activadoresExistentes.add(a);
          }
        }

        // Manejo de respuestas (máximo 3)
        if (!respuestasExistentes.contains(respuesta)) {
          if (respuestasExistentes.length < 3) {
            respuestasExistentes.add(respuesta);
          } else {
            // Reemplazo inteligente si el score es mejor por más de 1 punto
            if (scoreFinal > puntajeExistente + 1) {
              respuestasExistentes[0] = respuesta; // Reemplazar la principal
            }
          }
        }

        vecesPreguntado++;
        bool esConsolidada = estaEnConsolidado;
        if (estaEnPendiente && vecesPreguntado >= 3) {
          esConsolidada = true;
        }

        existente['activadores']      = activadoresExistentes;
        existente['respuestas']       = respuestasExistentes;
        existente['veces_preguntado'] = vecesPreguntado;
        existente['consolidada']      = esConsolidada;
        existente['puntaje']          = scoreFinal;

        if (estaEnPendiente && esConsolidada) {
          // Promocionar: guardar en consolidado y borrar de pendiente
          await archivoConsolidado.writeAsString(
            const JsonEncoder.withIndent('  ').convert(existente),
          );
          if (await archivoPendiente.exists()) {
            await archivoPendiente.delete();
          }
          // PASO 2: Supabase check similarity & upload when consolidated
          try {
            final String rawRespuesta = existente['respuestas'] != null && (existente['respuestas'] as List).isNotEmpty
                ? existente['respuestas'].first.toString()
                : respuesta;
            
            // Truncate if > 120 chars
            String respuestaLimpia = rawRespuesta;
            if (respuestaLimpia.length > 120) {
              String cortado = respuestaLimpia.substring(0, 120);
              int ultimoEspacio = cortado.lastIndexOf(' ');
              if (ultimoEspacio > 0) {
                respuestaLimpia = cortado.substring(0, ultimoEspacio).trim();
              } else {
                respuestaLimpia = cortado.trim();
              }
            }
            
            // Determinar categoría y librería
            final categoria = determinarCategoria(intencion);
            final libreria = determinarLibreria(intencion, categoria);
            final limite = obtenerLimiteLibreria(libreria);
            
            final client = Supabase.instance.client;
            
            // Obtener intenciones existentes en Supabase para verificar similitud
            final existingRecords = await client
                .from('guia_conocimiento_distribuido')
                .select('id, activadores, respuesta_limpia, veces_preguntado, puntaje');
            
            final nuevosActivadoresList = List<String>.from(existente['activadores'] ?? [preguntaOriginal.toLowerCase().trim()]);
            final nuevosActivadoresSet = nuevosActivadoresList.map((e) => e.toLowerCase().trim()).toSet();
            
            dynamic recordCoincidente;
            double maxCoincidencia = 0.0;
            
            for (final record in existingRecords) {
              final existentesActivadores = List<String>.from(record['activadores'] as List? ?? [])
                  .map((e) => e.toLowerCase().trim())
                  .toSet();
              
              if (nuevosActivadoresSet.isEmpty) continue;
              final intersection = nuevosActivadoresSet.intersection(existentesActivadores);
              final double coincidencia = intersection.length / nuevosActivadoresSet.length;
              
              if (coincidencia > maxCoincidencia) {
                maxCoincidencia = coincidencia;
                recordCoincidente = record;
              }
            }
            
            if (maxCoincidencia > 0.6 && recordCoincidente != null) {
              // Enriquecer la existente
              final existentesActivadoresList = List<String>.from(recordCoincidente['activadores'] as List? ?? []);
              final existentesActivadoresSet = existentesActivadoresList.map((e) => e.toLowerCase().trim()).toSet();
              final mergedActivadores = existentesActivadoresSet.union(nuevosActivadoresSet).toList();
              final int veces = (recordCoincidente['veces_preguntado'] as num?)?.toInt() ?? 0;
              final double puntajeExistente = (recordCoincidente['puntaje'] as num?)?.toDouble() ?? 0.0;
              
              final Map<String, dynamic> updateData = {
                'activadores': mergedActivadores,
                'veces_preguntado': veces + vecesPreguntado,
                'fecha_ultimo_uso': DateTime.now().toIso8601String().substring(0, 10),
              };
              
              if (scoreFinal > puntajeExistente) {
                updateData['respuesta_limpia'] = respuestaLimpia;
                updateData['puntaje'] = scoreFinal;
                updateData['gif'] = existente['gif'] ?? gif;
              }
              
              await client
                  .from('guia_conocimiento_distribuido')
                  .update(updateData)
                  .eq('id', recordCoincidente['id']);
              
              // ignore: avoid_print
              print('[Learner] ☁️ Enriquecida intención existente en Supabase (id: ${recordCoincidente['id']})');
            } else {
              // Crear una nueva intención
              await client.from('guia_conocimiento_distribuido').insert({
                'libreria': libreria,
                'categoria': categoria,
                'intencion': intencion,
                'activadores': nuevosActivadoresList,
                'respuesta_limpia': respuestaLimpia,
                'gif': existente['gif'] ?? gif,
                'puntaje': scoreFinal,
                'aprobado': false,
                'fecha_consolidacion': DateTime.now().toIso8601String().substring(0, 10),
                'veces_preguntado': vecesPreguntado,
                'limite_libreria': limite,
              });
              // ignore: avoid_print
              print('[Learner] ☁️ Subida consolidada a Supabase para: $intencion');
            }
          } catch (e) {
            // ignore: avoid_print
            print('[Learner] ⚠️ Error procesando consolidación en Supabase: $e');
          }

          // ignore: avoid_print
          print('[Learner] 🌟 PROMOVIDA A CONSOLIDADA: $intencion');
          await GuiaLocalUpdater.recargar();
        } else {
          // Actualizar en el archivo correspondiente
          await archivoDestino.writeAsString(
            const JsonEncoder.withIndent('  ').convert(existente),
          );
          if (esConsolidada) {
            await GuiaLocalUpdater.recargar();
          }
          // ignore: avoid_print
          print('[Learner] 🔄 Intención enriquecida: $intencion (veces: $vecesPreguntado)');
        }
      }

      await _registrarEnLog(intencion, scoreFinal, preguntaOriginal, !estaEnConsolidado && !estaEnPendiente);

    } catch (e) {
      // ignore: avoid_print
      print('[Learner] ⚠️ Error procesando aprendizaje: $e');
    }
  }

  static double calcularLocalScore(String respuesta) {
    double score = 0.0;
    // 1. Formato sin markdown/asteriscos (max 3 puntos)
    if (!respuesta.contains('*') && !respuesta.contains('#') && !respuesta.contains('`')) {
      score += 3.0;
    }
    // 2. Longitud (max 3 puntos)
    if (respuesta.length >= 40 && respuesta.length <= 300) {
      score += 3.0;
    } else if (respuesta.length >= 20 && respuesta.length <= 400) {
      score += 1.5;
    }
    // 3. Palabras clave locales argentinas (max 4 puntos)
    final palabrasLocales = ['amigo', 'dale', 'mirá', 'viaje', 'pesca', 'chamigo', 'che', 'pique', 'río', 'entrá', 'tocá', 'podés'];
    int count = 0;
    final respLower = respuesta.toLowerCase();
    for (final w in palabrasLocales) {
      if (respLower.contains(w)) {
        count++;
      }
    }
    score += (count * 1.5).clamp(0.0, 4.0);
    return score;
  }

  static Future<void> _descartar(String intencion, String respuesta, String pregunta, double score, String motivo) async {
    try {
      final dir = await _obtenerDirDescartada();
      final archivo = File('${dir.path}/$intencion.json');
      final datosDescarte = {
        'intencion': intencion,
        'respuesta': respuesta,
        'pregunta': pregunta,
        'score': score,
        'motivo': motivo,
        'fecha': DateTime.now().toIso8601String(),
      };
      await archivo.writeAsString(
        const JsonEncoder.withIndent('  ').convert(datosDescarte),
      );
      // ignore: avoid_print
      print('[Learner] ❌ Descartado a cementerio: $intencion (motivo: $motivo, score: $score)');
    } catch (_) {}
  }

  /// Carga todos los JSONs aprendidos consolidados como mapa de intención → datos.
  static Future<Map<String, dynamic>> cargarTodo() async {
    final resultado = <String, dynamic>{};
    try {
      final dir = await _obtenerDirConsolidada();
      if (!await dir.exists()) return resultado;

      final archivos = dir.listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.json') && !f.path.endsWith('_log.json'));

      for (final archivo in archivos) {
        try {
          final contenido = json.decode(await archivo.readAsString()) as Map<String, dynamic>;
          final intencion = contenido['intencion']?.toString() ?? '';
          if (intencion.isNotEmpty) {
            resultado[intencion] = contenido;
          }
        } catch (_) {
          // Archivo corrupto → ignorar
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[Learner] ⚠️ Error cargando aprendizajes: $e');
    }
    return resultado;
  }

  /// Devuelve estadísticas del aprendizaje para el panel admin.
  static Future<Map<String, dynamic>> estadisticas() async {
    try {
      final dirCons = await _obtenerDirConsolidada();
      final dirPend = await _obtenerDirPendiente();
      final dirDesc = await _obtenerDirDescartada();

      final archivosCons = await dirCons.exists() ? dirCons.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList() : [];
      final archivosPend = await dirPend.exists() ? dirPend.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList() : [];
      final archivosDesc = await dirDesc.exists() ? dirDesc.listSync().whereType<File>().where((f) => f.path.endsWith('.json')).toList() : [];

      int consolidadas = archivosCons.length;
      int pendientes = archivosPend.length;
      int descartados = archivosDesc.length;

      int totalActivadores = 0;
      final List<Map<String, dynamic>> ultimas = [];

      for (final archivo in archivosCons) {
        try {
          final datos = json.decode(await (archivo as File).readAsString()) as Map<String, dynamic>;
          totalActivadores += (datos['activadores'] as List<dynamic>? ?? []).length;
          ultimas.add({
            'intencion': datos['intencion'],
            'puntaje': datos['puntaje'],
            'veces': datos['veces_preguntado'],
            'consolidada': true,
            'fecha': datos['fecha'] ?? '',
            'ejemplo': datos['ejemplo_pregunta'] ?? '',
            'fuente': datos['fuente'] ?? 'conocimiento_propio',
          });
        } catch (_) {}
      }

      for (final archivo in archivosPend) {
        try {
          final datos = json.decode(await (archivo as File).readAsString()) as Map<String, dynamic>;
          ultimas.add({
            'intencion': datos['intencion'],
            'puntaje': datos['puntaje'],
            'veces': datos['veces_preguntado'],
            'consolidada': false,
            'fecha': datos['fecha'] ?? '',
            'ejemplo': datos['ejemplo_pregunta'] ?? '',
            'fuente': datos['fuente'] ?? 'conocimiento_propio',
          });
        } catch (_) {}
      }

      // Ordenar por fecha descendente
      ultimas.sort((a, b) => (b['fecha'] ?? '').compareTo(a['fecha'] ?? ''));

      // Cobertura offline real: resueltas localmente / total_consultas
      final total = GeminiConfig.totalConsultasTotal;
      final geminiTotal = GeminiConfig.totalPreguntas;
      final localTotal = total - geminiTotal;
      final coberturaPct = total > 0 ? ((localTotal / total) * 100).round() : 60;

      return {
        'total': consolidadas,
        'consolidadas': consolidadas,
        'pendientes': pendientes,
        'descartados': descartados,
        'total_activadores': totalActivadores,
        'cobertura_pct': coberturaPct,
        'ultimas': ultimas.take(10).toList(),
        'directorio': dirCons.path,
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Parsea el bloque |||APRENDO||| de la respuesta de Gemini.
  /// Retorna null si no hay bloque o si el JSON es inválido.
  static Map<String, dynamic>? parsearBloqueAprendizaje(String respuestaCompleta) {
    const token = '|||APRENDO|||';
    final idx = respuestaCompleta.indexOf(token);
    if (idx < 0) return null;

    final jsonStr = respuestaCompleta.substring(idx + token.length).trim();
    try {
      final inicio = jsonStr.indexOf('{');
      final fin = jsonStr.lastIndexOf('}');
      if (inicio < 0 || fin < 0) return null;
      return json.decode(jsonStr.substring(inicio, fin + 1)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Extrae solo la respuesta visible al usuario (antes del token).
  static String extraerRespuestaUsuario(String respuestaCompleta) {
    const token = '|||APRENDO|||';
    final idx = respuestaCompleta.indexOf(token);
    if (idx < 0) return respuestaCompleta.trim();
    return respuestaCompleta.substring(0, idx).trim();
  }

  // ── Privados ──────────────────────────────────────────────────────────────

  static Future<Directory> _obtenerDirConsolidada() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_carpetaConsolidada');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _obtenerDirPendiente() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_carpetaPendiente');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<Directory> _obtenerDirDescartada() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/$_carpetaDescartada');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  static Future<void> _registrarEnLog(
    String intencion, double puntaje, String pregunta, bool esNueva) async {
    try {
      final dir = await _obtenerDirConsolidada();
      final logFile = File('${dir.path}/aprendizaje_log.json');

      List<dynamic> log = [];
      if (await logFile.exists()) {
        try {
          log = json.decode(await logFile.readAsString()) as List<dynamic>;
        } catch (_) {
          log = [];
        }
      }

      log.insert(0, {
        'ts': DateTime.now().toIso8601String(),
        'intencion': intencion,
        'puntaje': puntaje,
        'nueva': esNueva,
        'pregunta': pregunta,
      });

      if (log.length > 500) log = log.sublist(0, 500);

      await logFile.writeAsString(json.encode(log));
    } catch (_) {}
  }

  static String determinarCategoria(String intencion) {
    final lower = intencion.toLowerCase();
    if (lower.contains('emergencia') ||
        lower.contains('seguridad') ||
        lower.contains('primeros_auxilios') ||
        lower.contains('primerosauxilios')) {
      return 'emergencia';
    }
    if (lower.contains('charla') ||
        lower.contains('emociones') ||
        lower.contains('humor') ||
        lower.contains('saludo') ||
        lower.contains('despedida') ||
        lower.contains('celebracion') ||
        lower.contains('acompanamiento') ||
        lower.contains('clima')) {
      return 'lenguaje';
    }
    return 'tecnico';
  }

  static String determinarLibreria(String intencion, String categoria) {
    final lower = intencion.toLowerCase();
    if (categoria == 'emergencia') {
      return 'emergencia';
    }
    if (categoria == 'lenguaje') {
      if (lower.contains('saludo') || lower.contains('despedida') || lower.contains('charla')) {
        return 'charla_cotidiana';
      }
      if (lower.contains('emocion') || lower.contains('triste') || lower.contains('alegre') || lower.contains('frustra') || lower.contains('euforia')) {
        return 'emociones_pescador';
      }
      if (lower.contains('celebracion') || lower.contains('record') || lower.contains('pesco_grande')) {
        return 'celebraciones';
      }
      if (lower.contains('humor') || lower.contains('chiste') || lower.contains('cargada') || lower.contains('picara')) {
        return 'chistes';
      }
      if (lower.contains('clima') || lower.contains('frio') || lower.contains('calor') || lower.contains('tormenta')) {
        return 'reacciones_clima';
      }
      if (lower.contains('acompanamiento') || lower.contains('solo') || lower.contains('aburrido') || lower.contains('espera')) {
        return 'acompanamiento';
      }
      return 'charla_cotidiana'; // Fallback para lenguaje
    }
    // Técnico
    if (lower.contains('pez') || lower.contains('peces') || lower.contains('dorado') || lower.contains('surubi') || lower.contains('boga')) {
      return 'peces';
    }
    if (lower.contains('carnada') || lower.contains('cebo') || lower.contains('anchoa') || lower.contains('lombriz')) {
      return 'carnadas';
    }
    if (lower.contains('nudo') || lower.contains('atar') || lower.contains('anzuelo')) {
      return 'nudos';
    }
    if (lower.contains('boya') || lower.contains('flotador')) {
      return 'boyas';
    }
    if (lower.contains('plomada') || lower.contains('plomo')) {
      return 'plomadas';
    }
    if (lower.contains('cana') || lower.contains('caña') || lower.contains('reel')) {
      return 'canas_y_reeles';
    }
    if (lower.contains('rio') || lower.contains('crecida') || lower.contains('bajante')) {
      return 'rio';
    }
    return 'general_tecnico'; // Fallback técnico
  }

  static int obtenerLimiteLibreria(String libreria) {
    switch (libreria) {
      case 'peces':
      case 'especies':
        return 40;
      case 'carnadas':
        return 30;
      case 'nudos':
        return 20;
      case 'charla_cotidiana':
      case 'charla':
        return 30;
      case 'emergencia':
        return 50;
      case 'clima':
      case 'reacciones_clima':
        return 20;
      case 'chistes':
      case 'humor':
        return 20;
      case 'emociones_pescador':
      case 'emociones':
        return 20;
      default:
        return 30; // resto 30
    }
  }
}
