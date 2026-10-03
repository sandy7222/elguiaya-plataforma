import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'guia_local_updater.dart';
import 'guia_retrieval/guia_modelo_descarga.dart';
import 'el_guia_engine.dart';

class GuiaKnowledgeSyncService {
  /// ¿Hay que bajar el modelo de embeddings (126 MB por WiFi)? Solo si se pidió
  /// la capa semántica. BM25 solo no necesita ningún modelo.
  static bool get debeBajarModelo => ElGuiaEngine.capaSemanticaPermitida;

  static const String _syncKeyPrefix = 'guia_sync_';
  // Marca de agua incremental (fecha_aprobacion más reciente ya aplicada)
  // — separada de _syncKeyPrefix, que guarda CUÁNDO se hizo el último
  // intento de sync (para el throttling de 24h/7d). Si usáramos la misma
  // clave para las dos cosas, un sync que no encuentra nada nuevo para
  // aplicar dejaría de actualizar "cuándo fue el último intento", y el
  // throttle terminaría disparando el sync en cada arranque de la app en
  // vez de esperar el intervalo correspondiente.
  static const String _watermarkKeyPrefix = 'guia_sync_watermark_';

  // Obtiene el límite máximo por librería según la especificación
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
      case 'humor_rioplatense':
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

  // Sincronizar inmediato: categoría "emergencia" aprobadas
  static Future<void> sincronizarInmediato() async {
    await _sincronizarPorCategoria('emergencia');
  }

  // Sincronizar diario: categoría "tecnico" aprobadas
  static Future<void> sincronizarDiario() async {
    await _sincronizarPorCategoria('tecnico');
  }

  // Sincronizar semanal: categoría "lenguaje" aprobadas
  static Future<void> sincronizarSemanal() async {
    await _sincronizarPorCategoria('lenguaje');
  }

  static Future<void> _sincronizarPorCategoria(String categoria) async {
    try {
      final client = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final marcaAguaStr = prefs.getString('${_watermarkKeyPrefix}$categoria');

      // Consultar Supabase filtrando aprobado: true y categoria correspondiente.
      //
      // IMPORTANTE — esto ya NO borra nada de Supabase al terminar (ver más
      // abajo). Antes este método bajaba TODO lo aprobado de la categoría y
      // llamaba a limpiar_conocimiento_aprobado_por_categoria() para
      // borrarlo de la tabla apenas terminaba. Eso corría en paralelo con
      // el GitHub Action nocturno (consolidate.yml →
      // limpiar_conocimiento_aprobado()), que hace exactamente lo mismo
      // para consolidar el conocimiento en los JSON del repo. Los dos
      // procesos compiten por las mismas filas: quien borra primero le
      // deja al otro la tabla vacía, así que según el orden de la carrera
      // el conocimiento aprobado quedaba solo en el celular que sincronizó
      // primero (y nunca en el repo/próximo build) o solo en el repo (y
      // nunca llegaba a un celular ya instalado sin actualizar).
      //
      // Ahora este método es de solo lectura respecto a Supabase: filtra
      // incrementalmente por fecha_aprobacion > última sincronización de
      // este dispositivo para esta categoría, y deja el borrado como
      // responsabilidad exclusiva del proceso nocturno. Así puede volver a
      // leer lo mismo sin romper nada si hace falta, y no le saca la fila a
      // nadie más.
      var query = client
          .from('guia_conocimiento_distribuido')
          .select('*')
          .eq('aprobado', true)
          .eq('categoria', categoria);

      if (marcaAguaStr != null && marcaAguaStr.isNotEmpty) {
        final fechaCorte = marcaAguaStr.substring(0, 10); // yyyy-MM-dd, mismo formato que fecha_aprobacion
        query = query.gt('fecha_aprobacion', fechaCorte);
      }

      final response = await query;

      if (response == null) return;

      final intencionesAprobadas = List<Map<String, dynamic>>.from(response as List);
      if (intencionesAprobadas.isEmpty) return;

      // Marca de throttle: registramos que efectivamente corrimos una
      // sincronización con datos para esta categoría, igual que antes
      // (así sincronizarDiario/sincronizarSemanal respetan sus ventanas de
      // 24h/7 días en verificarYEjecutarSincronizaciones en vez de
      // reintentar en cada arranque).
      await prefs.setString('${_syncKeyPrefix}$categoria', DateTime.now().toIso8601String());

      final baseDir = await getApplicationDocumentsDirectory();
      bool huboCambios = false;
      String? fechaAplicadaMasReciente;

      for (final item in intencionesAprobadas) {
        final String libreria = item['libreria']?.toString() ?? 'resto';
        final String intencion = item['intencion']?.toString() ?? '';
        if (intencion.isEmpty) continue;

        final maxLimite = obtenerLimiteLibreria(libreria);

        // Cargar archivo JSON local
        final overrideFile = File('${baseDir.path}/elguia/librerias/$libreria.json');
        Map<String, dynamic> jsonContent = {};

        if (await overrideFile.exists()) {
          final raw = await overrideFile.readAsString();
          jsonContent = json.decode(raw) as Map<String, dynamic>;
        } else {
          try {
            final raw = await rootBundle.loadString('assets/elguia/librerias/$libreria.json');
            jsonContent = json.decode(raw) as Map<String, dynamic>;
          } catch (_) {
            // Estructura básica si no existe el asset
            jsonContent = {
              "libreria": libreria,
              "intenciones": []
            };
          }
        }

        // Obtener lista actual de intenciones en la librería
        final List<dynamic> intencionesList = List.from(jsonContent['intenciones'] as List? ?? []);

        // Verificar si la librería destino ya alcanzó su límite máximo (chequeo al 90%)
        final int totalActual = intencionesList.length;
        if (totalActual >= (maxLimite * 0.9).round()) {
          // ignore: avoid_print
          print('[SyncService] ⚠️ Librería $libreria al 90% o más ($totalActual/$maxLimite). Sync omitido para $intencion — no avanzamos la marca de agua para esta fecha, se reintentará.');
          continue;
        }

        // Buscar si ya existe la intención
        bool existe = false;
        for (int i = 0; i < intencionesList.length; i++) {
          final existingIntent = intencionesList[i];
          if (existingIntent is Map && existingIntent['intencion'] == intencion) {
            // Enriquecer o sobreescribir la intención
            intencionesList[i] = {
              'intencion': intencion,
              'activadores': List<String>.from(item['activadores'] as List? ?? []),
              'respuesta_limpia': item['respuesta_limpia'],
              'gif': item['gif'] ?? 'hablaConMate',
            };
            existe = true;
            break;
          }
        }

        if (!existe) {
          intencionesList.add({
            'intencion': intencion,
            'activadores': List<String>.from(item['activadores'] as List? ?? []),
            'respuesta_limpia': item['respuesta_limpia'],
            'gif': item['gif'] ?? 'hablaConMate',
          });
        }

        jsonContent['intenciones'] = intencionesList;

        // Guardar override
        if (!await overrideFile.parent.exists()) {
          await overrideFile.parent.create(recursive: true);
        }
        await overrideFile.writeAsString(
          const JsonEncoder.withIndent('  ').convert(jsonContent),
        );
        huboCambios = true;

        // Vamos guardando la fecha_aprobacion más reciente entre lo que SÍ
        // se aplicó, para usarla como marca de agua — así un ítem saltado
        // por el límite del 90% no queda perdido para siempre.
        final String? fechaItem = item['fecha_aprobacion']?.toString();
        if (fechaItem != null &&
            (fechaAplicadaMasReciente == null || fechaItem.compareTo(fechaAplicadaMasReciente) > 0)) {
          fechaAplicadaMasReciente = fechaItem;
        }
      }

      if (huboCambios) {
        // Llamar GuiaLocalUpdater.recargar() al terminar
        await GuiaLocalUpdater.recargar();
        // Inicializar ElGuiaEngine para recargar librerías y activar nuevas intenciones
        await ElGuiaEngine().inicializar();
        // Re-armar el corpus del retriever con los overrides recién bajados
        // (y, si hay modelo, re-vectorizar solo las fichas que cambiaron).
        await ElGuiaEngine().reconstruirIndiceRetrieval();
      }

      // Marca de agua incremental: solo avanza hasta la fecha_aprobacion
      // más reciente que realmente se aplicó. Si todo se saltó por el
      // límite del 90%, no avanza nada, así se reintenta la próxima vez en
      // vez de perderse para siempre.
      if (fechaAplicadaMasReciente != null) {
        await prefs.setString('${_watermarkKeyPrefix}$categoria', fechaAplicadaMasReciente);
      }

    } catch (e) {
      // ignore: avoid_print
      print('[SyncService] Error sincronizando $categoria: $e');
    }
  }

  // Verifica si ha pasado un día/semana para programar sync en background
  static Future<void> verificarYEjecutarSincronizaciones() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ahora = DateTime.now();

      // Sincronización inmediata (siempre que arranca la app)
      await sincronizarInmediato();

      // Sincronización diaria (tecnico)
      final ultimaDiariaStr = prefs.getString('${_syncKeyPrefix}tecnico');
      if (ultimaDiariaStr == null) {
        await sincronizarDiario();
      } else {
        final ultimaDiaria = DateTime.parse(ultimaDiariaStr);
        if (ahora.difference(ultimaDiaria).inHours >= 24) {
          await sincronizarDiario();
        }
      }

      // Sincronización semanal (lenguaje)
      final ultimaSemanalStr = prefs.getString('${_syncKeyPrefix}lenguaje');
      if (ultimaSemanalStr == null) {
        await sincronizarSemanal();
      } else {
        final ultimaSemanal = DateTime.parse(ultimaSemanalStr);
        if (ahora.difference(ultimaSemanal).inDays >= 7) {
          await sincronizarSemanal();
        }
      }

      // Modelo de embeddings para el retriever (Fase 5): solo por WiFi, a lo
      // sumo un chequeo por día, en segundo plano. Si baja algo nuevo,
      // GuiaModeloDescarga.onModeloListo avisa al motor para armar el índice.
      if (debeBajarModelo) {
        unawaited(GuiaModeloDescarga.verificarYDescargar());
      }
    } catch (e) {
      // ignore: avoid_print
      print('[SyncService] Error al verificar sincronizaciones: $e');
    }
  }
}
