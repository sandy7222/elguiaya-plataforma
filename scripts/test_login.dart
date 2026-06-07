import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://ymgsxwfwntbqvguvbhoa.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw'
  );

  print('Intentando iniciar sesión con maruba@gmail.com...');
  try {
    final response = await supabase.auth.signInWithPassword(
      email: 'maruba@gmail.com',
      password: 'maruba123',
    );
    print('¡Login exitoso!');
    print('User ID: ${response.user?.id}');
    
    print('Consultando perfil...');
    final profileList = await supabase
        .from('profiles')
        .select('*')
        .eq('user_id', response.user!.id);
        
    if (profileList.isEmpty) {
      print('El usuario no tiene un perfil en la tabla profiles.');
    } else {
      print('Perfil: ${profileList.first}');
    }
  } on AuthException catch (e) {
    print('Error de Autenticación: ${e.message}');
  } catch (e) {
    print('Error general: $e');
  }
}
