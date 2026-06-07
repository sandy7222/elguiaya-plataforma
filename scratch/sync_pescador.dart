import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    print('--- PROBANDO SYNC DE PESCADOR ---');
    
    // 1. Obtener perfil de Oscar Gambino
    final profiles = await supabase.from('profiles').select('*').eq('user_id', 'ad3315eb-9127-48c8-85f8-f53fd5a33820');
    if (profiles.isEmpty) {
      print('No se encontró el perfil de Oscar Gambino.');
      return;
    }
    
    final p = profiles.first;
    final userId = p['user_id'];
    
    // Parsear DNI a entero
    final rawDni = p['dni'] ?? '0';
    final int? dniInt = int.tryParse(rawDni.toString().replaceAll(RegExp(r'\D'), ''));
    
    print('Intentando insertar pescador Oscar Gambino con columnas seguras...');
    
    // Insertar en pescadores usando solo columnas existentes y seguras
    await supabase.from('pescadores').upsert({
      'user_id': userId,
      'nombre': p['nombre'],
      'dni': dniInt ?? 0,
      'email': p['email'] ?? '',
      'telefono': p['telefono'] ?? '',
      'localidad': p['localidad'] ?? '',
      'provincia': p['provincia'] ?? '',
      'avatar_url': p['avatar_url'],
      'dni_url': p['foto_dni_url'] ?? p['dni_url'],
      'expediente': p['expediente'] ?? 'PES-2026-TEMP',
    });
    
    print('✅ PESCADOR SYNCED CON ÉXITO A TABLA pescadores!');
    
    // 2. También cambiar su estado a 'activo' en profiles
    await supabase.from('profiles').update({'estado': 'activo'}).eq('user_id', userId);
    print('✅ Estado de perfil actualizado a "activo" en profiles!');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
