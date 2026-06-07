import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    // Let's run a query to get column info for pedidos, viajes_invitados, and cotizaciones
    // using postgresql information_schema through RPC if we have it, or just trying to select empty rows but with select('*')
    // Wait, the select('*') on an empty table returns an empty list, so we can't see the columns that way.
    // But we can run an RPC or check if there's any SQL we can run.
    // Wait, does Supabase have a way to query information_schema?
    // Let's run: supabase.from('information_schema.columns').select('table_name, column_name, data_type').eq('table_schema', 'public')
    // Let's try!
    final columnsRes = await supabase
        .from('information_schema.columns')
        .select('table_name, column_name, data_type')
        .eq('table_schema', 'public');
        
    print('Columns count: ${columnsRes.length}');
    for (var col in columnsRes) {
      final tableName = col['table_name'];
      if (['pedidos', 'viajes_invitados', 'cotizaciones', 'manifiesto_pasajeros'].contains(tableName)) {
        print('$tableName: ${col['column_name']} (${col['data_type']})');
      }
    }
  } catch (e) {
    print('❌ Error querying information_schema: $e');
  }
}
