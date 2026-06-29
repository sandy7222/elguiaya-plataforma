import 'package:supabase/supabase.dart';
Future<void> main() async {
  final c = SupabaseClient('https://ymgsxwfwntbqvguvbhoa.supabase.co', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw');
  await c.auth.signInWithPassword(email: 'admin@capitanya.com', password: 'admin123');
  final liqs = await c.from('liquidaciones').select('id,monto,estado,capitan_id').inFilter('estado', ['solicitado','procesando']);
  print('admin ve ${liqs.length} liquidacion(es)');
  for (final l in liqs) print(l);
}
