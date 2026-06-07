import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  final columnsToTest = [
    'id',
    'reserva_id',
    'pedido_id',
    'user_id',
    'usuario_id',
    'cliente_id',
    'nombre_receptor',
    'telefono_receptor',
    'calle',
    'numero',
    'piso_depto',
    'barrio',
    'ciudad',
    'provincia',
    'codigo_postal',
    'instrucciones',
    'acepta_aviso_ausencia',
  ];
  
  print('--- Probing columns ---');
  for (var col in columnsToTest) {
    try {
      // Try to select just this column.
      // If it returns a list (empty or not) without throwing a "Could not find the column..." error,
      // it means the column exists!
      final res = await supabase.from('envio_domicilio').select(col).limit(1);
      print('✅ Column exists: $col (Select succeeded: $res)');
    } catch (e) {
      if (e.toString().contains('Could not find')) {
        print('❌ Column does NOT exist: $col');
      } else {
        print('⚠️ Column exists but select failed (e.g. type or permission): $col -> $e');
      }
    }
  }
}
