import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final response = await supabase.from('guias').select('*').limit(1);
    if (response.isNotEmpty) {
      print('✅ REGISTRO ENCONTRADO EN guias:');
      final record = response.first;
      for (var entry in record.entries) {
        print(' - ${entry.key}: ${entry.value} (Type: ${entry.value.runtimeType})');
      }
    } else {
      print('No se encontraron registros en guias.');
    }
  } catch (e) {
    print('❌ Error al consultar guias: $e');
  }
}
