import 'package:supabase/supabase.dart';

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  print('Initializing Supabase client...');
  final client = SupabaseClient(url, anonKey);

  try {
    print('\n--- Clearing simulated notifications from notificaciones_globales ---');
    final responseGlobal = await client
        .from('notificaciones_globales')
        .delete()
        .eq('titulo', '💬 ¡Nuevo Pescador Interesado!');
    print('Cleaned from notificaciones_globales.');

    print('\n--- Clearing simulated notifications from notificaciones ---');
    final responseLegacy = await client
        .from('notificaciones')
        .delete()
        .eq('titulo', '💬 ¡Nuevo Pescador Interesado!');
    print('Cleaned from notificaciones.');

    print('\n--- Clearing mock contact requests from solicitudes_contacto ---');
    final responseSolicitudes = await client
        .from('solicitudes_contacto')
        .delete()
        .eq('mensaje_inicial', '¡Hola! Vi tu servicio y me interesa mucho. ¿Hay lugar?');
    print('Cleaned from solicitudes_contacto.');

    print('\n🎉 CLEANUP COMPLETED SUCCESSFULLY!');
  } catch (e, stack) {
    print('Error during cleanup: $e');
    print(stack);
  }
}
