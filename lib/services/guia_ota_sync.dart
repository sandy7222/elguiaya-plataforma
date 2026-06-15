import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Servicio de sincronización Over-The-Air (OTA) para el conocimiento de El Guía.
/// Consulta intenciones aprobadas desde Supabase y las integra localmente.
class GuiaOtaSync {
  static const String _prefsKeySyncDate = 'guia_ota_last_sync_date';

  /// Ejecuta la sincronización de conocimiento si el dispositivo está conectado a WiFi.
  static Future<void> sync() async {
    try {
      // 1. Verificar conectividad WiFi
      final connectivity = Connectivity();
      final List<ConnectivityResult> results = await connectivity.checkConnectivity();
      final bool hasWifi = results.any((r) => r == ConnectivityResult.wifi);
      
      if (!hasWifi) {
        // ignore: avoid_print
        print('[GuiaOtaSync] Sincronización omitida: Sin conexión WiFi.');
        return;
      }

      // ignore: avoid_print
      print('[GuiaOtaSync] Iniciando sincronización de conocimiento por WiFi...');

      // 2. Conectarse a Supabase y obtener fecha de última sincronización
      final client = Supabase.instance.client;
      final prefs = await SharedPreferences.getInstance();
      final String? lastSyncDate = prefs.getString(_prefsKeySyncDate);

      // Consultar guia_conocimiento_distribuido WHERE aprobado = true
      var query = client
          .from('guia_conocimiento_distribuido')
          .select('*')
          .eq('aprobado', true);

      // Si existe fecha de sync anterior, aplicar filtro: fecha_aprobacion > fecha_ultima_sync
      if (lastSyncDate != null && lastSyncDate.isNotEmpty) {
        query = query.gt('fecha_aprobacion', lastSyncDate);
      }

      final response = await query;
      if (response == null) {
        // ignore: avoid_print
        print('[GuiaOtaSync] Supabase no respondió.');
        return;
      }

      final List<dynamic> records = response as List<dynamic>;
      if (records.isEmpty) {
        // ignore: avoid_print
        print('[GuiaOtaSync] No hay nuevo conocimiento aprobado para sincronizar.');
        await _saveLastSyncDate(prefs);
        return;
      }

      // ignore: avoid_print
      print('[GuiaOtaSync] Se encontraron ${records.length} registros aprobados nuevos.');

      // 3. Agrupar resultados por campo 'libreria'
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      for (final record in records) {
        if (record is Map<String, dynamic>) {
          final String? libreria = record['libreria'] as String?;
          if (libreria != null && libreria.trim().isNotEmpty) {
            grouped.putIfAbsent(libreria.trim(), () => []).add(record);
          }
        }
      }

      final Directory baseDir = await getApplicationDocumentsDirectory();
      final String otaDir = '${baseDir.path}/elguia/librerias';

      // 4. Procesar cada librería
      for (final entry in grouped.entries) {
        final String libreria = entry.key;
        final List<Map<String, dynamic>> items = entry.value;

        try {
          final File file = File('$otaDir/$libreria.json');
          Map<String, dynamic> jsonContent = {};

          // a. Leer el JSON existente (o usar el asset como fallback)
          if (await file.exists()) {
            final String raw = await file.readAsString();
            jsonContent = json.decode(raw) as Map<String, dynamic>;
          } else {
            try {
              final String rawAsset = await rootBundle.loadString('assets/elguia/librerias/$libreria.json');
              jsonContent = json.decode(rawAsset) as Map<String, dynamic>;
            } catch (_) {
              // Si tampoco existe el asset, inicializamos estructura básica
              jsonContent = {
                'intent': libreria,
                'prioridad': 10,
                'respuestas_puente': [],
                'intenciones': []
              };
            }
          }

          // b. Inyectar las intenciones nuevas en la lista
          final List<dynamic> intencionesList = List.from(jsonContent['intenciones'] as List? ?? []);

          for (final item in items) {
            final String? intencion = item['intencion'] as String?;
            if (intencion == null || intencion.trim().isEmpty) continue;

            final Map<String, dynamic> mappedIntention = {
              'intencion': intencion,
              'activadores': List<String>.from(item['activadores'] as List? ?? []),
              'respuesta_limpia': item['respuesta_limpia'] ?? '',
              'gif': item['gif'] ?? 'hablaConMate',
            };

            int existingIndex = -1;
            for (int i = 0; i < intencionesList.length; i++) {
              final ext = intencionesList[i];
              if (ext is Map && ext['intencion'] == intencion) {
                existingIndex = i;
                break;
              }
            }

            if (existingIndex != -1) {
              intencionesList[existingIndex] = mappedIntention;
            } else {
              intencionesList.add(mappedIntention);
            }
          }

          jsonContent['intenciones'] = intencionesList;

          // c. Escribir el archivo actualizado en <documentos>/elguia/librerias/<libreria>.json
          if (!await file.parent.exists()) {
            await file.parent.create(recursive: true);
          }
          await file.writeAsString(
            const JsonEncoder.withIndent('  ').convert(jsonContent),
          );

          // Loguear cuántos registros procesó por librería
          // ignore: avoid_print
          print('[GuiaOtaSync] Procesados ${items.length} registros para la librería: "$libreria".');
        } catch (e) {
          // Si falla una librería individual, continuar con las demás
          // ignore: avoid_print
          print('[GuiaOtaSync] Error al sincronizar librería "$libreria": $e');
        }
      }

      // 5. Guardar fecha de sync exitosa en SharedPreferences
      await _saveLastSyncDate(prefs);
      // ignore: avoid_print
      print('[GuiaOtaSync] Sincronización finalizada exitosamente.');
    } catch (e) {
      // ignore: avoid_print
      print('[GuiaOtaSync] Error global de sincronización: $e');
    }
  }

  /// Guarda la fecha de sincronización. Para prevenir pérdida de registros aprobados
  /// el mismo día de la sync (después de ejecutarse), guardamos la fecha de ayer.
  static Future<void> _saveLastSyncDate(SharedPreferences prefs) async {
    final DateTime yesterday = DateTime.now().subtract(const Duration(days: 1));
    final String y = yesterday.year.toString().padLeft(4, '0');
    final String m = yesterday.month.toString().padLeft(2, '0');
    final String d = yesterday.day.toString().padLeft(2, '0');
    final String dateStr = '$y-$m-$d';
    
    await prefs.setString(_prefsKeySyncDate, dateStr);
    // ignore: avoid_print
    print('[GuiaOtaSync] Fecha de última sincronización guardada (ayer): $dateStr');
  }
}
