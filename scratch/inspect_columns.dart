import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  try {
    final res = await supabase.from('geometry_columns').select('*');
    if (res.isNotEmpty) {
      print('✅ SUCCESS geometry_columns:');
      for (var row in res) {
        print('  - Table: ${row['f_table_name']} | Column: ${row['f_geometry_column']} | Type: ${row['type']}');
      }
    } else {
      print('ℹ️ No geometry columns found');
    }
  } catch (e) {
    print('❌ Error querying geometry_columns: $e');
  }
}
