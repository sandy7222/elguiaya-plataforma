import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      if (content.contains('package:El Guia YA_master')) {
        content = content.replaceAll('package:El Guia YA_master', 'package:capitanya_master');
        file.writeAsStringSync(content);
        count++;
        print('Fixed imports in ${file.path}');
      }
    }
  }
  print('Total files fixed: $count');
}
