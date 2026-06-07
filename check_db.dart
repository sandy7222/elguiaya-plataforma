import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  await Supabase.initialize(url: url, anonKey: anonKey);
  final client = Supabase.instance.client;

  try {
    print('\n--- Querying profiles table ---');
    final profiles = await client.from('profiles').select('user_id, rol, nombre');
    print('Total profiles: ${profiles.length}');
    for (var p in profiles) {
      print('  User ID: ${p['user_id']}, Rol: ${p['rol']}, Nombre: ${p['nombre']}');
    }

    print('\n--- Querying pescadores table ---');
    final pescadores = await client.from('pescadores').select('*');
    print('Total pescadores: ${pescadores.length}');
    for (var p in pescadores) {
      print('  User ID (or id): ${p['user_id'] ?? p['id']}, Nombre: ${p['nombre']}');
    }

    print('\n--- Querying guias (capitanes) table ---');
    final guias = await client.from('guias').select('*');
    print('Total guias: ${guias.length}');
    for (var g in guias) {
      print('  ID: ${g['id']}, Nombre: ${g['nombre']}');
    }

    print('\n--- Querying notificaciones table count ---');
    final notifLegacy = await client.from('notificaciones').select('id');
    print('Legacy notifications count: ${notifLegacy.length}');

    print('\n--- Querying notificaciones_globales table count ---');
    final notifGlobal = await client.from('notificaciones_globales').select('id');
    print('Global notifications count: ${notifGlobal.length}');

  } catch (e, stack) {
    print('Error during diagnosis: $e');
    print(stack);
  }
}
