import 'dart:io';

void main() {
  final dir = Directory('lib');
  if (!dir.existsSync()) {
    print('lib directory not found');
    return;
  }
  
  final list = dir.listSync(recursive: true);
  final usage = <String, List<String>>{};
  final targetTables = {'reservas', 'pedidos', 'reservas_viajes', 'pedidos_tienda'};
  
  for (var entity in list) {
    if (entity is File && entity.path.endsWith('.dart')) {
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.contains('.from(')) {
          final start = line.indexOf('.from(') + 6;
          if (start < line.length) {
            final quoteChar = line[start];
            if (quoteChar == "'" || quoteChar == '"') {
              final end = line.indexOf(quoteChar, start + 1);
              if (end != -1 && end > start + 1) {
                final tableName = line.substring(start + 1, end);
                if (targetTables.contains(tableName)) {
                  usage.putIfAbsent(tableName, () => []).add('${entity.path}:${i+1}');
                }
              }
            }
          }
        }
      }
    }
  }
  
  print('--- TARGET TABLES USAGE IN DART FILES ---');
  for (var table in usage.keys) {
    print('Table: $table');
    for (var fileLoc in usage[table]!.toSet()) {
      print('  - $fileLoc');
    }
  }
}
