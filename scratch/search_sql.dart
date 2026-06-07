import 'dart:io';

void main() {
  final dir = Directory('sql');
  if (!dir.existsSync()) {
    print('sql directory not found');
    return;
  }
  
  final list = dir.listSync(recursive: true);
  final regex = RegExp(r'create\s+table\s+(?:if\s+not\s+exists\s+)?(\w+)', caseSensitive: false);
  for (var entity in list) {
    if (entity is File && entity.path.endsWith('.sql')) {
      final content = entity.readAsStringSync();
      final matches = regex.allMatches(content);
      if (matches.isNotEmpty) {
        final tables = matches.map((m) => m.group(1)).join(', ');
        print('${entity.path} defines: $tables');
      }
    }
  }
}
