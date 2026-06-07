import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final columnsRes = await supabase
        .from('information_schema.columns')
        .select('column_name, data_type')
        .eq('table_name', 'cotizaciones')
        .eq('table_schema', 'public');
        
    print('✅ Columns for table "cotizaciones":');
    for (var col in columnsRes) {
      print('  - ${col['column_name']} (${col['data_type']})');
    }
  } catch (e) {
    print('❌ Error checking columns: $e');
  }
}
