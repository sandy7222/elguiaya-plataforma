import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  // Try to update a non-existent UUID in pedidos with all columns we want to use,
  // to see which columns throw a "column does not exist" error.
  final dummyId = '00000000-0000-0000-0000-000000000000';
  
  final columnsToTest = [
    'estado',
    'payment_status',
    'payment_id',
    'payment_method_id',
    'payment_amount',
    'contacto_habilitado',
    'contacto_habilitado_at',
  ];
  
  for (var col in columnsToTest) {
    try {
      await supabase.from('pedidos').update({col: null}).eq('id', dummyId);
      print('✅ Column exists: $col');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('PGRST204') || errStr.contains('column does not exist') || errStr.contains('does not exist')) {
        print('❌ Column does NOT exist: $col');
      } else {
        print('✅ Column exists (failed with other error): $col ($e)');
      }
    }
  }
}
