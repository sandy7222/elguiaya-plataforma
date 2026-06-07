import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final oscarId = 'ad3315eb-9127-48c8-85f8-f53fd5a33820';
    print('Intentando insertar cotización de prueba para Oscar Gambino (Pescador con estado activo) | id: $oscarId...');
    
    final insertRes = await supabase.from('cotizaciones').insert({
      'pescador_id': oscarId,
      'descripcion': 'Prueba de cotizacion activa para Oscar Gambino',
      'estado': 'pendiente',
      'created_at': DateTime.now().toIso8601String(),
    }).select();
    
    print('✅ INSERCIÓN EXITOSA: $insertRes');
  } catch (e) {
    print('❌ ERROR AL INSERTAR: $e');
  }
}
