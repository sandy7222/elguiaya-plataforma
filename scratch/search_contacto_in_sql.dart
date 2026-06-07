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
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.toLowerCase().contains('contacto_habilitado')) {
          print('${entity.path}:${i+1}: $line');
        }
      }
    }
  }
}
