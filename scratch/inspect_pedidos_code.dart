import 'dart:io';

void main() {
  final file = File('lib/services/supabase_service.dart');
  if (!file.existsSync()) {
    print('supabase_service.dart not found');
    return;
  }
  
  final lines = file.readAsLinesSync();
  print('--- USAGES OF pedidos IN supabase_service.dart ---');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.contains('from(\'pedidos\')') || line.contains('from("pedidos")')) {
      print('Line ${i+1}: $line');
      // Print surrounding lines
      final start = (i - 5) < 0 ? 0 : (i - 5);
      final end = (i + 15) >= lines.length ? lines.length - 1 : (i + 15);
      for (var j = start; j <= end; j++) {
        print('  ${j+1}: ${lines[j]}');
      }
      print('-----------------------------------------');
    }
  }
}
