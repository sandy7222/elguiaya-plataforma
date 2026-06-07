import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  final colsToTest = [
    'pescador_id', 'descripcion', 'coordenadas_partida', 'coordenadas_destino',
    'localidad_partida', 'provincia_partida', 'localidad_destino', 'provincia_destino',
    'lugar_encuentro', 'fecha_ida', 'fecha_vuelta', 'hora_encuentro',
    'cantidad_personas', 'track_log', 'estado', 'created_at', 'distancia_km'
  ];
  
  print('--- PROBANDO COLUMNAS EN TABLA cotizaciones ---');
  for (var col in colsToTest) {
    try {
      final res = await supabase.from('cotizaciones').insert({
        'pescador_id': 'ad3315eb-9127-48c8-85f8-f53fd5a33820', // Oscar Gambino
        'descripcion': 'Test',
        col: col == 'created_at' || col == 'fecha_ida' || col == 'fecha_vuelta' 
            ? DateTime.now().toIso8601String() 
            : col == 'cantidad_personas' ? 2 : col == 'distancia_km' ? 10.0 : 'test_val'
      }).select();
      print('✅ Columna [$col] es VÁLIDA. (Insert exitoso: $res)');
      
      // Limpiar
      await supabase.from('cotizaciones').delete().eq('pescador_id', 'ad3315eb-9127-48c8-85f8-f53fd5a33820');
    } catch (e) {
      if (e.toString().contains('PGRST204') || e.toString().contains('Could not find')) {
        print('❌ Columna [$col] NO EXISTE.');
      } else {
        print('❓ Columna [$col] existe o dio otro error: $e');
      }
    }
  }
}
