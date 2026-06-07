import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  try {
    print('\n--- Listing Database Triggers ---');
    // We can query pg_trigger and pg_class to get triggers
    final List<dynamic> response = await client.rpc('get_my_triggers_check'); 
    print('Triggers: $response');
  } catch (e) {
    print('RPC get_my_triggers_check failed (which is normal if it does not exist). Let us try a raw query via a temporary function or check schema cache.');
    try {
      // Let's try querying information_schema.triggers or similar tables if public read is allowed.
      // But usually direct select on pg_trigger is not exposed via Postgrest unless we have an RPC function.
      print('Since we cannot run arbitrary SQL directly without RPC, let us query the active tables to see if we can find any clues.');
    } catch (err) {
      print('Error: $err');
    }
  }

  // Let's check if we have any unread notifications in public.notificaciones and public.notificaciones_globales
  try {
    print('\n--- Checking recent notifications in public.notificaciones ---');
    final notifs = await client.from('notificaciones').select('*').order('fecha', ascending: false).limit(10);
    print('Found ${notifs.length} recent notifications:');
    for (var n in notifs) {
      print('  - ID: ${n['id']}, Title: ${n['titulo']}, Message: ${n['mensaje']}, Leida: ${n['leida']}, Date: ${n['fecha']}');
    }
  } catch (e) {
    print('Error querying notificaciones: $e');
  }

  try {
    print('\n--- Checking recent notifications in public.notificaciones_globales ---');
    final notifs = await client.from('notificaciones_globales').select('*').order('created_at', ascending: false).limit(10);
    print('Found ${notifs.length} recent global notifications:');
    for (var n in notifs) {
      print('  - ID: ${n['id']}, Title: ${n['titulo']}, Content: ${n['contenido']}, Leido: ${n['leido']}, Date: ${n['created_at']}');
    }
  } catch (e) {
    print('Error querying notificaciones_globales: $e');
  }
}
