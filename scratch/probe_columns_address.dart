import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  // Lista de columnas a probar para la tabla 'pescadores'
  final colsToTest = ['direccion', 'direccion_calle', 'direccion_numero', 'codigo_postal', 'cod_postal', 'postal_code', 'postal', 'zip', 'zipcode', 'postalcode', 'foto_dni'];
  
  print('--- PROBANDO MÁS COLUMNAS EN TABLA pescadores ---');
  for (var col in colsToTest) {
    try {
      final res = await supabase.from('pescadores').insert({
        'user_id': 'ad3315eb-9127-48c8-85f8-f53fd5a33820', // Oscar Gambino's ID
        'nombre': 'Oscar Gambino',
        col: 'test'
      }).select();
      print('✅ Columna [$col] es VÁLIDA. (Insert exitoso: $res)');
      
      // Limpiar despues de probar
      await supabase.from('pescadores').delete().eq('user_id', 'ad3315eb-9127-48c8-85f8-f53fd5a33820');
    } catch (e) {
      if (e.toString().contains('PGRST204') || e.toString().contains('Could not find')) {
        print('❌ Columna [$col] NO EXISTE.');
      } else {
        print('❓ Columna [$col] dio otro error: $e');
      }
    }
  }
}
