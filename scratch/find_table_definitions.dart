import 'dart:io';

void main() {
  final dir = Directory('sql');
  if (!dir.existsSync()) {
    print('sql directory not found');
    return;
  }
  
  final list = dir.listSync(recursive: true);
  for (var entity in list) {
    if (entity is File && entity.path.endsWith('.sql')) {
      final content = entity.readAsStringSync();
      if (content.contains(RegExp(r'create\s+table\s+.*?pedidos\b', caseSensitive: false))) {
        print('${entity.path} contains CREATE TABLE ... pedidos');
      }
      if (content.contains(RegExp(r'create\s+table\s+.*?reservas\b', caseSensitive: false))) {
        print('${entity.path} contains CREATE TABLE ... reservas');
      }
    }
  }
}
