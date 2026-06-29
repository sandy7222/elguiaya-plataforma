import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ymgsxwfwntbqvguvbhoa.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
  );

  try {
    final res = await supabase.from('fcm_tokens').select('*');
    print('Total FCM tokens registrados en Supabase: ${res.length}');
    for (final r in res) {
      print(' - Usuario: ${r['usuario_id']} | Dispositivo: ${r['dispositivo']} | Token: ${r['token'].toString().substring(0, 20)}...');
    }
  } catch (e) {
    print('Error leyendo fcm_tokens: $e');
  }
}
