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
      if (content.toLowerCase().contains('gu-ia') || content.toLowerCase().contains('guia_local') || content.toLowerCase().contains('baqueano')) {
        print('Found reference in ${entity.path}');
        // Print lines containing these keywords
        final lines = content.split('\n');
        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          if (line.toLowerCase().contains('gu-ia') || line.toLowerCase().contains('guia_local') || line.toLowerCase().contains('baqueano')) {
            print('  Line ${i+1}: $line');
          }
        }
      }
    }
  }
}
