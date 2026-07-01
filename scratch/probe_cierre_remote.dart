import 'package:supabase/supabase.dart';

void main() async {
  final s = SupabaseClient(
    'https://ymgsxwfwntbqvguvbhoa.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
  );

  for (final t in ['alertas_admin', 'alertas_negocio', 'vw_monitor_cierres']) {
    try {
      await s.from(t).select('id').limit(1);
      print('OK table/view: $t');
    } catch (e) {
      print('FAIL $t => $e');
    }
  }

  for (final f in [
    'vigilancia_cierre_operaciones',
    'cierre_manual_admin',
    'confirmar_retorno_y_liberar_pago',
    'ejecutar_vigilancia_cierres',
  ]) {
    try {
      await s.rpc(f);
      print('OK rpc: $f');
    } catch (e) {
      print('FAIL rpc $f => $e');
    }
  }
}
