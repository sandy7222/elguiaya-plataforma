import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  print('--- PROBING RESERVAS TABLE WITH INT ID ---');
  final dummyIntId = 999999;
  try {
    // Try to insert a minimal row letting id autogenerate, or specifying an integer ID
    final insertRes = await supabase.from('reservas').insert({
      'id': dummyIntId,
      'estado': 'pendiente',
    }).select();
    
    if (insertRes.isNotEmpty) {
      print('✅ Insert succeeded in reservas!');
      print('Columns in reservas: ${insertRes.first.keys.toList()}');
      print('Row content: ${insertRes.first}');
      
      // Clean up
      await supabase.from('reservas').delete().eq('id', dummyIntId);
      print('✅ Cleaned up dummy row in reservas.');
    } else {
      print('⚠️ Insert returned empty list in reservas.');
    }
  } catch (e) {
    print('❌ Error inserting with integer ID: $e');
    
    // Try without specifying ID (autoincrement)
    try {
      final insertRes2 = await supabase.from('reservas').insert({
        'estado': 'pendiente',
      }).select();
      
      if (insertRes2.isNotEmpty) {
        final newId = insertRes2.first['id'];
        print('✅ Insert without ID succeeded in reservas! New ID: $newId');
        print('Columns in reservas: ${insertRes2.first.keys.toList()}');
        print('Row content: ${insertRes2.first}');
        
        await supabase.from('reservas').delete().eq('id', newId);
        print('✅ Cleaned up dummy row in reservas.');
      } else {
        print('⚠️ Insert without ID returned empty list in reservas.');
      }
    } catch (e2) {
      print('❌ Error inserting without ID: $e2');
    }
  }
}
