import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final response = await supabase.from('pedidos').select('*');
    print('✅ TOTAL PEDIDOS: ${response.length}');
    for (var p in response) {
      print('ID: ${p['id']} | PescadorID: ${p['pescador_id']} | CapitanID: ${p['capitan_id']} | EstadoCotizacion: ${p['estado_cotizacion']} | Estado: ${p['estado']} | CreatedAt: ${p['created_at']} | Desc: ${p['descripcion']} | CoorPartida: ${p['coordenadas_partida']}');
    }
  } catch (e) {
    print('❌ Error checking pedidos: $e');
  }
}
