import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found');
    return;
  }
  
  final list = dir.listSync(recursive: true);
  for (var entity in list) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final content = entity.readAsStringSync();
      if (content.contains('class Pedido ') || content.contains('class PedidoItem ') || content.contains('class ViajeInvitado')) {
        print('${entity.path} contains class');
      }
    }
  }
}
