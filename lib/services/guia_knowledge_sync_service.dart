import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'guia_local_updater.dart';
import 'el_guia_engine.dart';

class GuiaKnowledgeSyncService {
  static const String _syncKeyPrefix = 'guia_sync_';

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
      // Consultar Supabase filtrando aprobado: true y categoria correspondiente
      final response = await client
          .from('guia_conocimiento_distribuido')
          .select('*')
          .eq('aprobado', true)
          .eq('categoria', categoria);

      if (response == null) return;

      final intencionesAprobadas = List<Map<String, dynamic>>.from(response as List);
      if (intencionesAprobadas.isEmpty) return;

      final baseDir = await getApplicationDocumentsDirectory();
      bool huboCambios = false;

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
          print('[SyncService] ⚠️ Librería $libreria al 90% o más ($totalActual/$maxLimite). Sync omitido para $intencion.');
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
      }

      if (huboCambios) {
        // Llamar GuiaLocalUpdater.recargar() al terminar
        await GuiaLocalUpdater.recargar();
        // Inicializar ElGuiaEngine para recargar librerías y activar nuevas intenciones
        await ElGuiaEngine().inicializar();

        // Autolimpieza en el servidor: como ya se copiaron localmente, las borramos de Supabase
        try {
          await client.rpc('limpiar_conocimiento_aprobado_por_categoria', params: {
            'cat_name': categoria,
          });
        } catch (rpcErr) {
          // ignore: avoid_print
          print('[SyncService] ⚠️ Error al autolimpiar Supabase: $rpcErr');
        }
      }

      // Guardar fecha de última sincronización en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_syncKeyPrefix}$categoria', DateTime.now().toIso8601String());

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
    } catch (e) {
      // ignore: avoid_print
      print('[SyncService] Error al verificar sincronizaciones: $e');
    }
  }
}
