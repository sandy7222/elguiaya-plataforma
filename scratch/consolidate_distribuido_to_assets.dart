import 'dart:convert';
import 'dart:io';

void main() async {
  print('==================================================');
  print('🚀 Iniciando consolidación de conocimiento distribuido a Assets...');
  print('==================================================');

  final url = Uri.parse('https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/guia_conocimiento_distribuido?select=*&aprobado=eq.true');
  final client = HttpClient();
  
  try {
    final req = await client.getUrl(url);
    req.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw');
    
    final res = await req.close();
    if (res.statusCode != 200) {
      print('❌ Error al consultar Supabase. Código: ${res.statusCode}');
      return;
    }
    
    final body = await res.transform(utf8.decoder).join();
    final List<dynamic> data = json.decode(body);
    
    if (data.isEmpty) {
      print('ℹ️ No hay intenciones marcadas como "aprobado = true" en la base de datos para consolidar.');
      return;
    }

    print('📊 Se encontraron ${data.length} intenciones aprobadas para consolidar.');

    int archivosModificados = 0;
    int intencionesAgregadas = 0;
    int intencionesActualizadas = 0;

    // Agrupar por librería para hacer un solo guardado por archivo
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
          print('⚠️ Error al parsear JSON existente en assets/elguia/librerias/$libreria.json. Se recreará.');
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

        // Parsear activadores si vienen como string de JSON o lista
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

        // Buscar si ya existe para actualizar o agregar
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

      // Guardar de vuelta al archivo
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(jsonContent));
      archivosModificados++;
      print('💾 Guardado assets/elguia/librerias/$libreria.json con éxito.');
    }

    print('==================================================');
    print('✅ Proceso de consolidación finalizado:');
    print('   📂 Archivos JSON modificados/creados: $archivosModificados');
    print('   ➕ Nuevas intenciones añadidas: $intencionesAgregadas');
    print('   🔄 Intenciones actualizadas: $intencionesActualizadas');
    print('==================================================');

    // Llamar a la función RPC en Supabase para limpiar los datos ya consolidados
    print('🧹 Iniciando limpieza automática en Supabase...');
    final rpcUrl = Uri.parse('https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/rpc/limpiar_conocimiento_aprobado');
    final cleanReq = await client.postUrl(rpcUrl);
    cleanReq.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw');
    
    final cleanRes = await cleanReq.close();
    if (cleanRes.statusCode == 200 || cleanRes.statusCode == 204) {
      print('🗑️ Supabase limpiado con éxito: Se eliminaron las intenciones aprobadas.');
    } else {
      print('⚠️ Advertencia: No se pudo limpiar Supabase de forma automática. Código: ${cleanRes.statusCode}');
    }

  } catch (e) {
    print('❌ Error crítico durante la consolidación: $e');
  } finally {
    client.close();
  }
}
