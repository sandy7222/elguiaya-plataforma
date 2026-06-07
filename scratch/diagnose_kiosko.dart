import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  try {
    print('\n--- Checking profiles with es_capitan = true ---');
    try {
      final captains = await client.from('profiles').select().eq('es_capitan', true);
      print('Found ${captains.length} captains:');
      for (var c in captains) {
        print('  - user_id: ${c['user_id']}, email: ${c['email']}, nombre: ${c['nombre_completo'] ?? c['nombre']}, estado: ${c['estado_cuenta']}');
      }
    } catch (e) {
      print('Error checking profiles: $e');
    }

    print('\n--- Checking kiosko_capitan table schema / content ---');
    try {
      final products = await client.from('kiosko_capitan').select().limit(5);
      print('Found ${products.length} products in kiosko_capitan:');
      for (var p in products) {
        print('  - id: ${p['id']}, capitan_id: ${p['capitan_id']}, nombre: ${p['nombre_producto']}, precio: ${p['precio']}, activo: ${p['activo']}');
      }
    } catch (e) {
      print('Error checking kiosko_capitan: $e');
    }

    print('\n--- Checking storage.buckets table directly via SQL ---');
    try {
      final buckets = await client.from('storage.buckets').select('*');
      print('Found ${buckets.length} buckets in storage.buckets:');
      bool foundProductos = false;
      for (var b in buckets) {
        print('  - ID: ${b['id']}, Name: ${b['name']}, Public: ${b['public']}');
        if (b['id'] == 'productos') foundProductos = true;
      }
      if (!foundProductos) {
        print('🚨 WARNING: Bucket "productos" is NOT in storage.buckets table!');
      } else {
        print('✅ Bucket "productos" exists in database storage.buckets!');
      }
    } catch (e) {
      print('Error querying storage.buckets table: $e');
    }

  } catch (e, stack) {
    print('Unexpected error during diagnosis: $e');
    print(stack);
  }
}
