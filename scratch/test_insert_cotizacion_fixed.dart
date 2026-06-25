import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final oscarId = 'ad3315eb-9127-48c8-85f8-f53fd5a33820';
    print('Intentando insertar cotización de prueba (sin distancia_millas)...');
    
    final insertRes = await supabase.from('cotizaciones').insert({
      'pescador_id': oscarId,
      'descripcion': 'Prueba de cotizacion sin enviar columna distancia_millas',
      'estado': 'pendiente',
      'distancia_km': 15.5, // 15.5 km
      'created_at': DateTime.now().toIso8601String(),
    }).select();
    
    print('✅ INSERCIÓN EXITOSA:');
    print(insertRes.first);
    
    // Test dynamic fallback from data
    final insertedData = insertRes.first;
    final double? distKm = (insertedData['distancia_km'] as num?)?.toDouble();
    final double? distMillasDb = (insertedData['distancia_millas'] as num?)?.toDouble();
    final double? distMillasCalculated = distMillasDb ?? (distKm != null ? distKm * 0.621371 : null);
    
    print('--- Validación de Millas ---');
    print('Distancia KM: $distKm');
    print('Distancia Millas (DB): $distMillasDb');
    print('Distancia Millas (Calculada): $distMillasCalculated');
    
    // Limpiar cotización de prueba
    final idToDelete = insertedData['id'];
    await supabase.from('cotizaciones').delete().eq('id', idToDelete);
    print('🧹 Registro de prueba eliminado.');
  } catch (e) {
    print('❌ ERROR AL INSERTAR/PROBAR: $e');
  }
}
