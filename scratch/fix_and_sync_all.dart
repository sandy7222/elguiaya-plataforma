import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    print('--- INICIANDO CORRECCIÓN Y SINCRONIZACIÓN GLOBAL DE SOCIOS ---');
    
    // 1. Obtener todos los perfiles
    final profiles = await supabase.from('profiles').select('*');
    print('Total de perfiles encontrados en "profiles": ${profiles.length}');
    
    int corregidos = 0;
    int syncGuias = 0;
    int syncPescadores = 0;
    int fallas = 0;
    
    for (var p in profiles) {
      final userId = p['user_id'];
      final nombre = p['nombre'] ?? 'Usuario Sin Nombre (${userId.substring(0, 8)})';
      final bool esCapitan = p['es_capitan'] == true;
      var estado = p['estado'] ?? 'pendiente';
      
      print('\n👉 Procesando: "$nombre" | Rol: ${esCapitan ? "Capitán" : "Pescador"} | Estado actual: "$estado"');
      
      try {
        // A. Si el estado es 'aprobado', cambiarlo a 'activo' para que cumpla las políticas RLS
        if (estado == 'aprobado') {
          print(' - El estado es "aprobado", actualizándolo a "activo" en profiles...');
          await supabase.from('profiles').update({'estado': 'activo', 'verificado': true}).eq('user_id', userId);
          estado = 'activo';
          corregidos++;
        }
        
        // B. Si es 'activo', asegurar que esté en la tabla legada (pescadores o guias) con columnas seguras
        if (estado == 'activo') {
          final rawDni = p['dni'] ?? '0';
          final int? dniInt = int.tryParse(rawDni.toString().replaceAll(RegExp(r'\D'), ''));
          
          if (esCapitan) {
            print(' - Sincronizando a la tabla "guias"...');
            await supabase.from('guias').upsert({
              'id': userId, 
              'nombre': p['nombre'] ?? p['full_name'],
              'dni': dniInt ?? 0,
              'telefono': p['telefono'] ?? '',
              'email': p['email'] ?? '',
              'localidad': p['localidad'] ?? '',
              'provincia': p['provincia'] ?? '',
              'calle': p['direccion_calle'] ?? p['calle'] ?? '',
              'altura': p['direccion_numero'] ?? p['altura'] ?? '',
              'cp': p['cp']?.toString() ?? '',
              'avatar_url': p['avatar_url'],
              'carnet_timonel': p['carnet_url'],
              'poliza_seguro': p['seguro_url'],
              'expediente': p['expediente'] ?? 'CAP-2026-TEMP',
              'capacidad_personas': p['capacidad_personas'] ?? 4,
            });
            print('   ✅ Sincronizado en "guias" con éxito.');
            syncGuias++;
          } else {
            print(' - Sincronizando a la tabla "pescadores"...');
            try {
              await supabase.from('pescadores').upsert({
                'user_id': userId,
                'nombre': p['nombre'] ?? p['full_name'],
                'dni': dniInt ?? 0,
                'email': p['email'] ?? '',
                'telefono': p['telefono'] ?? '',
                'localidad': p['localidad'] ?? '',
                'provincia': p['provincia'] ?? '',
                'avatar_url': p['avatar_url'],
                'dni_url': p['foto_dni_url'] ?? p['dni_url'],
                'expediente': p['expediente'] ?? 'PES-2026-TEMP',
              });
              print('   ✅ Sincronizado en "pescadores" con éxito.');
              syncPescadores++;
            } catch (e) {
              print('   ⚠️ Error al sincronizar pescador (puede ser por RLS): $e');
              fallas++;
            }
          }
        } else {
          print(' - El usuario está en estado "$estado", se omite la sincronización legada.');
        }
      } catch (e) {
        print(' ❌ Error procesando este socio: $e');
        fallas++;
      }
    }
    
    print('\n🎉 --- PROCESO COMPLETADO ---');
    print('📊 RESUMEN:');
    print(' - Perfiles corregidos a "activo": $corregidos');
    print(' - Guías sincronizados: $syncGuias');
    print(' - Pescadores sincronizados: $syncPescadores');
    print(' - Fallas / Omisiones de RLS: $fallas');
    
  } catch (e) {
    print('❌ ERROR GENERAL DURANTE EL PROCESO: $e');
  }
}
