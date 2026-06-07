import 'dart:convert';
import 'dart:io';

void main() async {
  print('================================================================');
  print('👀 WATCHER: Consolidación Automática en Tiempo Real Iniciada');
  print('🔍 Monitoreando Supabase cada 5 segundos...');
  print('💾 Escribirá directamente en assets/elguia/librerias/');
  print('================================================================');

  final url = Uri.parse('https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/guia_conocimiento_distribuido?select=*&aprobado=eq.true');
  final rpcUrl = Uri.parse('https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/rpc/limpiar_conocimiento_aprobado');
  final client = HttpClient();
  
  while (true) {
    try {
      final req = await client.getUrl(url);
      req.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw');
      
      final res = await req.close();
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final List<dynamic> data = json.decode(body);
        
        if (data.isNotEmpty) {
          print('\n🔔 [${DateTime.now().toLocal().toString().substring(11, 19)}] ¡Detectadas ${data.length} intenciones aprobadas! Consolidando...');
          
          int archivosModificados = 0;
          int intencionesAgregadas = 0;
          int intencionesActualizadas = 0;

          // Agrupar por librería
          final Map<String, List<Map<String, dynamic>>> agrupados = {};
          for (var row in data) {
            final item = Map<String, dynamic>.from(row);
            final String libreria = item['libreria']?.toString() ?? 'resto';
            agrupados.putIfAbsent(libreria, () => []).add(item);
          }

          final assetsDir = Directory('assets/elguia/librerias');
          if (!await assetsDir.exists()) {
            await assetsDir.create(recursive: true);
          }

          for (var entry in agrupados.entries) {
            final String libreria = entry.key;
            final List<Map<String, dynamic>> items = entry.value;

            final file = File('assets/elguia/librerias/$libreria.json');
            Map<String, dynamic> jsonContent = {};

            if (await file.exists()) {
              final raw = await file.readAsString();
              try {
                jsonContent = json.decode(raw) as Map<String, dynamic>;
              } catch (e) {
                jsonContent = {
                  "libreria": libreria,
                  "intenciones": []
                };
              }
            } else {
              jsonContent = {
                "libreria": libreria,
                "intenciones": []
              };
            }

            final List<dynamic> intencionesList = List.from(jsonContent['intenciones'] as List? ?? []);

            for (var item in items) {
              final String intencion = item['intencion']?.toString() ?? '';
              if (intencion.isEmpty) continue;

              List<String> activadores = [];
              if (item['activadores'] is List) {
                activadores = List<String>.from((item['activadores'] as List).map((x) => x.toString()));
              } else if (item['activadores'] is String) {
                try {
                  final parsed = json.decode(item['activadores']);
                  if (parsed is List) {
                    activadores = List<String>.from(parsed.map((x) => x.toString()));
                  }
                } catch (_) {}
              }

              final Map<String, dynamic> nuevoItem = {
                'intencion': intencion,
                'activadores': activadores,
                'respuesta_limpia': item['respuesta_limpia']?.toString() ?? '',
                'gif': item['gif']?.toString() ?? 'hablaConMate',
              };

              int index = -1;
              for (int i = 0; i < intencionesList.length; i++) {
                final existing = intencionesList[i];
                if (existing is Map && existing['intencion'] == intencion) {
                  index = i;
                  break;
                }
              }

              if (index != -1) {
                intencionesList[index] = nuevoItem;
                intencionesActualizadas++;
              } else {
                intencionesList.add(nuevoItem);
                intencionesAgregadas++;
              }
            }

            jsonContent['intenciones'] = intencionesList;
            await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonContent));
            archivosModificados++;
            print('   💾 Guardado assets/elguia/librerias/$libreria.json con éxito.');
          }

          print('   📊 Modificados: $archivosModificados | Agregados: $intencionesAgregadas | Actualizados: $intencionesActualizadas');

          // Limpiar en Supabase
          final cleanReq = await client.postUrl(rpcUrl);
          cleanReq.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw');
          final cleanRes = await cleanReq.close();
          if (cleanRes.statusCode == 200 || cleanRes.statusCode == 204) {
            print('   🧹 Supabase limpiado con éxito (intenciones consolidadas eliminadas).');
          } else {
            print('   ⚠️ Advertencia: No se pudo limpiar Supabase. Código: ${cleanRes.statusCode}');
          }
        }
      }
    } catch (e) {
      print('⚠️ Error en el ciclo del watcher: $e');
    }
    
    // Esperar 5 segundos antes de volver a consultar
    await Future.delayed(Duration(seconds: 5));
  }
}
