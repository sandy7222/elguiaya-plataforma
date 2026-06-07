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
      // Search for any string that seems to represent a status of a pedido
      final regex = RegExp(r"['"'""](pendiente|pagado|pagada|despachado|entregado|cancelado|rechazado)['"'""]", caseSensitive: false);
      final matches = regex.allMatches(content);
      if (matches.isNotEmpty) {
        final found = matches.map((m) => m.group(0)).toSet();
        print('${entity.path} contains status values: $found');
      }
    }
  }
}
