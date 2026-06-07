import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  try {
    // 1. Fetch one row from 'pedidos' to see columns
    final pedidosRes = await supabase.from('pedidos').select('*').limit(1);
    print('✅ PEDIDOS SCHEMA (sample row):');
    if (pedidosRes.isNotEmpty) {
      print(pedidosRes.first.keys.toList());
      print(pedidosRes.first);
    } else {
      print('Table is empty');
    }
    
    // 2. Fetch one row from 'viajes_invitados' to see columns
    final invitadosRes = await supabase.from('viajes_invitados').select('*').limit(1);
    print('\n✅ VIAJES_INVITADOS SCHEMA (sample row):');
    if (invitadosRes.isNotEmpty) {
      print(invitadosRes.first.keys.toList());
      print(invitadosRes.first);
    } else {
      print('Table is empty');
    }

    // 3. Fetch one row from 'cotizaciones' to see columns
    final cotizacionesRes = await supabase.from('cotizaciones').select('*').limit(1);
    print('\n✅ COTIZACIONES SCHEMA (sample row):');
    if (cotizacionesRes.isNotEmpty) {
      print(cotizacionesRes.first.keys.toList());
      print(cotizacionesRes.first);
    } else {
      print('Table is empty');
    }

    // 4. Fetch one row from 'profiles' to see columns
    final profilesRes = await supabase.from('profiles').select('*').limit(1);
    print('\n✅ PROFILES SCHEMA (sample row):');
    if (profilesRes.isNotEmpty) {
      print(profilesRes.first.keys.toList());
      print(profilesRes.first);
    } else {
      print('Table is empty');
    }
  } catch (e) {
    print('❌ Error al inspeccionar schemas: $e');
  }
}
