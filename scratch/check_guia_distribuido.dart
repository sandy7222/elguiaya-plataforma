import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  try {
    print('\n--- Querying all rows in guia_conocimiento_distribuido ---');
    final response = await client.from('guia_conocimiento_distribuido').select('*');
    print('Total rows: ${response.length}\n');
    
    print('APPROVED ROWS:');
    int appCount = 0;
    for (var row in response) {
      if (row['aprobado'] == true) {
        appCount++;
        print('  - ID: ${row['id']} | Categoria: ${row['categoria']} | Intencion: ${row['intencion']} | Libreria: ${row['libreria']} | Consolidado: ${row['fecha_consolidacion']} | Aprobado: ${row['fecha_aprobacion']}');
      }
    }
    if (appCount == 0) print('  (None)');

    print('\nPENDING ROWS:');
    int pendCount = 0;
    for (var row in response) {
      if (row['aprobado'] != true) {
        pendCount++;
        print('  - ID: ${row['id']} | Categoria: ${row['categoria']} | Intencion: ${row['intencion']} | Libreria: ${row['libreria']} | Consolidado: ${row['fecha_consolidacion']} | Aprobado: ${row['fecha_aprobacion']}');
      }
    }
    if (pendCount == 0) print('  (None)');

  } catch (e, stack) {
    print('Error during diagnosis: $e');
    print(stack);
  }
}

