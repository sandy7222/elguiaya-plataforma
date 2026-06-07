import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    print('--- INICIANDO CORRECCIÓN DE ESTADOS DE SOCIOS ---');
    
    // 1. Obtener todos los perfiles con estado 'aprobado'
    final profiles = await supabase.from('profiles').select('*').eq('estado', 'aprobado');
    print('Encontrados ${profiles.length} perfiles con estado "aprobado".');
    
    for (var p in profiles) {
      final userId = p['user_id'];
      final nombre = p['nombre'] ?? 'Sin Nombre';
      final bool esCapitan = p['es_capitan'] == true;
      
      print('\nProcesando a $nombre ($userId) | esCapitan: $esCapitan...');
      
      // A. Actualizar estado a 'activo' en profiles
      await supabase.from('profiles').update({'estado': 'activo', 'verificado': true}).eq('user_id', userId);
      print(' - Estado actualizado a "activo" en profiles.');
      
      // B. Traspasar a tablas legadas (pescadores o guias)
      if (esCapitan) {
        await supabase.from('guias').upsert({
          'id': userId, 
          'nombre': p['nombre'],
          'dni': p['dni'],
          'telefono': p['telefono'],
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
        print(' - Traspasado con éxito a la tabla guias.');
      } else {
        await supabase.from('pescadores').upsert({
          'user_id': userId,
          'nombre': p['nombre'],
          'dni': p['dni'],
          'email': p['email'] ?? '',
          'telefono': p['telefono'],
          'localidad': p['localidad'] ?? '',
          'provincia': p['provincia'] ?? '',
          'calle': p['direccion_calle'] ?? p['calle'] ?? '',
          'altura': p['direccion_numero'] ?? p['altura'] ?? '',
          'cp': p['cp']?.toString() ?? '',
          'avatar_url': p['avatar_url'],
          'foto_dni_url': p['foto_dni_url'],
          'dni_url': p['foto_dni_url'], 
          'expediente': p['expediente'] ?? 'PES-2026-TEMP',
        });
        print(' - Traspasado con éxito a la tabla pescadores.');
      }
    }
    
    print('\n--- CORRECCIÓN DE ESTADOS COMPLETADA ---');
  } catch (e) {
    print('❌ Error durante la corrección: $e');
  }
}
