import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final responseTable = await supabase.from('cotizaciones').select('*').order('created_at', ascending: false).limit(1);
    if (responseTable.isNotEmpty) {
      print('✅ RECENT COTIZACION:');
      print(responseTable.first);
    } else {
      print('No cotizaciones found');
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}
