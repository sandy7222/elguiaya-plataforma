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
    print('Inserting mock notification into notificaciones_globales...');
    final response = await client.from('notificaciones_globales').insert({
      'receptor_id': userId,
      'tipo_actor': 'sistema',
      'categoria': 'informativa',
      'prioridad': 'informativa',
      'titulo': 'Test diagnostic',
      'contenido': 'Checking id data type',
      'leido': false,
      'payload': {},
    }).select('*');

    print('Response received: $response');
    if (response.isNotEmpty) {
      final insertedRow = response[0];
      print('=== Inserted Row Types ===');
      insertedRow.forEach((key, val) {
        print('  Column: $key, Value: $val, Type: ${val.runtimeType}');
      });
    } else {
      print('Empty response returned.');
    }

    // Clean up
    print('Cleaning up test notification...');
    await client.from('notificaciones_globales').delete().eq('receptor_id', userId).eq('titulo', 'Test diagnostic');
    print('Cleanup complete.');
  } catch (e) {
    print('Error inserting/querying: $e');
  }
}
