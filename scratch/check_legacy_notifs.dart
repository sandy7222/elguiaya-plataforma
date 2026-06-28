import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  print('Logging in as maruba@gmail.com...');
  final loginRes = await client.auth.signInWithPassword(
    email: 'maruba@gmail.com',
    password: 'maruba123',
  );
  
  final userId = loginRes.user!.id;
  print('Logged in successfully! User ID: $userId');

  try {
    print('\n--- Querying notificaciones (legacy) for user ---');
    final legacyNotifs = await client.from('notificaciones').select('*').order('created_at', ascending: false);
    print('Found ${legacyNotifs.length} legacy notifications:');
    for (var n in legacyNotifs) {
      print('  - ID: ${n['id']}, Title: ${n['titulo']}, Message: ${n['mensaje']}, Leida: ${n['leida']}, Created: ${n['created_at']}');
    }

    print('\n--- Querying notificaciones_globales (modern) for user ---');
    final globalNotifs = await client.from('notificaciones_globales').select('*').order('created_at', ascending: false);
    print('Found ${globalNotifs.length} global notifications:');
    for (var n in globalNotifs) {
      print('  - ID: ${n['id']}, Title: ${n['titulo']}, Content: ${n['contenido']}, Leido: ${n['leido']}, Created: ${n['created_at']}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
