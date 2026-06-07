import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  final marthaId = '5b8d481b-b5bb-4a08-bbfc-d7d0ae98bedf';
  
  final candidateTables = [
    'profiles', 'guias', 'pescadores', 'cotizaciones', 'pedidos', 
    'reservas', 'pagos', 'liquidaciones', 'transacciones_capitanes',
    'notificaciones_usuarios', 'presupuestos'
  ];
  
  print('--- SEARCHING FOR MARTHA SANCHEZ IN TABLES ---');
  for (var table in candidateTables) {
    try {
      final res = await supabase.from(table).select();
      for (var row in res) {
        final rowStr = row.toString();
        if (rowStr.contains(marthaId) || rowStr.contains('Martha') || rowStr.contains('Sanchez')) {
          print('Found in table "$table": $row');
        }
      }
    } catch (e) {
      print('Error querying table "$table": $e');
    }
  }
}
