import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final responseTable = await supabase.from('cotizaciones').select('*').order('created_at', ascending: false);
    print('✅ COTIZACIONES TABLE ENCONTRADAS: ${responseTable.length}');
    for (var c in responseTable) {
      print('ID: ${c['id']} | PescadorID: ${c['pescador_id']} | Estado: ${c['estado']} | Desc: ${c['descripcion']}');
      print('  -> coordenadas_partida: ${c['coordenadas_partida']}');
      print('  -> punto_partida: ${c['punto_partida']}');
      print('  -> localidad_partida: ${c['localidad_partida']} | provincia_partida: ${c['provincia_partida']}');
    }
  } catch (e) {
    print('❌ Error al consultar tabla cotizaciones: $e');
  }

  try {
    final responseView = await supabase.from('cotizaciones_mapa').select('*');
    print('✅ COTIZACIONES_MAPA VIEW ENCONTRADAS: ${responseView.length}');
    for (var c in responseView) {
      print('ID: ${c['id']} | PescadorID: ${c['pescador_id']} | Estado: ${c['estado']} | Desc: ${c['descripcion_corta']}');
      print('  -> ubicacion: ${c['ubicacion']}');
    }
  } catch (e) {
    print('❌ Error al consultar vista cotizaciones_mapa: $e');
  }
}
