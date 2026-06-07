import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  final candidateTables = [
    'profiles', 'guias', 'pescadores', 'cotizaciones', 'rubros', 'categorias',
    'productos', 'pedidos', 'pedido_items', 'alertas_admin', 'envios_logisticos',
    'avisos_legales', 'aceptaciones_avisos', 'banners_promo', 'blog_articulos',
    'config_sistema', 'disputas_viajes', 'documentos_usuarios', 'disponibilidad',
    'pedidos_tienda', 'reservas_viajes', 'vinculo_logistico', 'notificaciones_glew',
    'chats_asistidos', 'mensajes_chat', 'reputacion_capitanes', 'calificaciones_viajes',
    'logs_sistema', 'alertas_negocio', 'presupuestos', 'alertas_fraude',
    'suspensiones_capitanes', 'advertencias_capitanes', 'productos_viajes',
    'fcm_tokens', 'reservas', 'pagos', 'liquidaciones', 'transacciones_capitanes',
    'notificaciones_usuarios'
  ];
  
  print('--- TESTING WHICH TABLES EXIST IN DB ---');
  for (var table in candidateTables) {
    try {
      final res = await supabase.from(table).select().limit(1);
      print('✅ Table EXISTS: $table (Count/Result: ${res.length})');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('PGRST205') || errStr.contains('Could not find the table')) {
        print('❌ Table DOES NOT EXIST: $table');
      } else {
        print('✅ Table EXISTS (with permissions/other error): $table ($e)');
      }
    }
  }
}
