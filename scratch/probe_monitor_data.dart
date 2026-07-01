import 'package:supabase/supabase.dart';

void main() async {
  final s = SupabaseClient(
    'https://ymgsxwfwntbqvguvbhoa.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
  );

  final rows = await s.from('vw_monitor_cierres').select('pedido_id, descripcion, estado_actual, nivel_alerta, horas_desde_retorno, monto_total').limit(5);
  print('Monitor rows: ${rows.length}');
  for (final r in rows) {
    print(r);
  }

  final ped = await s.from('pedidos').select('id, estado, fecha_regreso, estado_retorno').inFilter('estado', ['en_curso', 'listo_para_confirmar']).limit(3);
  print('\nPedidos activos sample:');
  for (final p in ped) {
    print(p);
  }
}
