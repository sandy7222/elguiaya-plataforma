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
      final name = entity.path.split(Platform.pathSeparator).last.toLowerCase();
      if (name.contains('ticket') || name.contains('payment') || name.contains('embarque') || name.contains('pago')) {
        print(entity.path);
      }
    }
  }
}
