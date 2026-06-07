
import 'package:capitanya_master/services/supabase_service.dart';

void main() async {
  await SupabaseService.initialize();
  final response = await SupabaseService.supabase.from('productos').select('id, nombre, destacado');
  print('PRODUCTOS ENCONTRADOS: ${response.length}');
  for (var p in response) {
    print(' - ${p['nombre']}: Destacado=${p['destacado']}');
  }
}
