import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  print('Authenticating as maruba@gmail.com...');
  final loginRes = await client.auth.signInWithPassword(
    email: 'maruba@gmail.com',
    password: 'maruba123',
  );
  
  final userId = loginRes.user!.id;
  print('Logged in successfully! User ID: $userId');

  try {
    print('Attempting mock upsert into viajes_invitados...');
    await client.from('viajes_invitados').upsert({
      'pescador_id': userId,
      'pedido_id': null,
      'nombre': 'Martha',
      'apellido': 'Sanchez',
      'dni': 22365554,
      'es_titular': true,
      'foto_dni_url': null,
    });
    print('✅ Upsert succeeded!');
  } catch (e) {
    print('❌ Upsert failed: $e');
  }
}
