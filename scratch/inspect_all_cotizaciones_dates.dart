import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final responseTable = await supabase.from('cotizaciones').select('*').order('created_at', ascending: false);
    print('✅ TOTAL COTIZACIONES: ${responseTable.length}');
    for (var c in responseTable) {
      print('ID: ${c['id']} | CreatedAt: ${c['created_at']}');
      print('  -> coordenadas_partida: ${c['coordenadas_partida']}');
      print('  -> punto_partida: ${c['punto_partida']}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
