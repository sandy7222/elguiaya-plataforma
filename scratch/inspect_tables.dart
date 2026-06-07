import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final profilesRes = await supabase.from('profiles').select('user_id, nombre, es_capitan, estado');
    print('✅ PROFILES ENCONTRADOS: ${profilesRes.length}');
    for (var p in profilesRes.take(5)) {
      print(' - User: ${p['nombre']} | Capitan: ${p['es_capitan']} | Estado: ${p['estado']}');
    }
    
    final guiasRes = await supabase.from('guias').select('id, nombre');
    print('✅ GUIAS ENCONTRADOS: ${guiasRes.length}');
    
    final pescadoresRes = await supabase.from('pescadores').select('user_id, nombre');
    print('✅ PESCADORES ENCONTRADOS: ${pescadoresRes.length}');
    
    final cotizacionesRes = await supabase.from('cotizaciones').select('id, pescador_id, estado');
    print('✅ COTIZACIONES ENCONTRADAS: ${cotizacionesRes.length}');
  } catch (e) {
    print('❌ Error al inspeccionar tablas: $e');
  }
}
