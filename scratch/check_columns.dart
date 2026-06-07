import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  try {
    print('\n--- Querying profiles columns ---');
    final response = await client.from('profiles').select().limit(1);
    if (response.isNotEmpty) {
      final keys = response.first.keys.toList();
      keys.sort();
      print('Columns in profiles table:');
      for (var key in keys) {
        print('  - $key : ${response.first[key]}');
      }
    } else {
      print('Profiles table is empty!');
    }
  } catch (e, stack) {
    print('Error during diagnosis: $e');
    print(stack);
  }
}
