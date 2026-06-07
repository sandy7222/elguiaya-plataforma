import 'dart:io';

void main() {
  final file = File('lib/services/supabase_service.dart');
  if (!file.existsSync()) {
    print('File not found');
    return;
  }
  
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains("from('pedidos'") || line.contains("from('reservas'") || line.contains("pedidos") || line.contains("viajes_invitados")) {
      print('${i + 1}: $line');
    }
  }
}
