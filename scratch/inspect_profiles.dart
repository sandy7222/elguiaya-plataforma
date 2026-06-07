import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    final response = await supabase.from('profiles').select('*');
    print('✅ TOTAL PROFILES: ${response.length}');
    for (var p in response) {
      print('ID: ${p['user_id'] ?? p['id']} | Rol: ${p['rol']} | Nombre: ${p['nombre']} | AvatarUrl: ${p['avatar_url']} | Capitan: ${p['es_capitan']} | Lat: ${p['zona_lat']} | Lng: ${p['zona_lng']}');
    }
  } catch (e) {
    print('❌ Error checking profiles: $e');
  }
}
