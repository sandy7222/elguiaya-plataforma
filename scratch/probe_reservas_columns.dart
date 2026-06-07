import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  print('--- INSPECCIONANDO COLUMNAS DE "reservas" ---');
  try {
    // Attempting to select from the public columns view if exposed
    final res = await supabase
        .from('columns')
        .select('column_name, data_type')
        .eq('table_name', 'reservas');
    print('✅ Columnas encontradas:');
    for (var col in res) {
      print('  - ${col['column_name']} (${col['data_type']})');
    }
  } catch (e) {
    print('❌ Error al consultar vista columns: $e');
    
    // Alternative: Try to insert a dummy invalid map to force a schema error
    try {
      await supabase.from('reservas').insert({'invalid_column_name_test': 123});
    } catch (e2) {
      print('ℹ️ Error provocado para ver mensaje de schema: $e2');
    }
  }
}
