import 'dart:io';

void main() {
  final file = File('lib/services/el_guia_engine.dart');
  final lines = file.readAsLinesSync();
  for (int i = 0; i < lines.length; i++) {
    final line = lines[i].trim();
    if ((line.contains('class ') ||
         line.contains('void ') ||
         line.contains('Future<') ||
         line.contains('static ') ||
         (line.contains('(') && (line.startsWith('bool ') || line.startsWith('String ') || line.startsWith('int ') || line.startsWith('Map ') || line.startsWith('List ')))
        ) && !line.startsWith('//') && !line.startsWith('*')) {
      print('${i + 1}: $line');
    }
  }
}
