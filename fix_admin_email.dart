import 'dart:io';

void main() {
  final dir = Directory('lib');
  int count = 0;
  for (var file in dir.listSync(recursive: true)) {
    if (file is File && file.path.endsWith('.dart')) {
      String content = file.readAsStringSync();
      if (content.contains('admin@El Guia YA.com')) {
        content = content.replaceAll('admin@El Guia YA.com', 'admin@capitanya.com');
        file.writeAsStringSync(content);
        count++;
        print('Fixed admin email in ${file.path}');
      }
    }
  }
  print('Total files fixed: $count');
}
