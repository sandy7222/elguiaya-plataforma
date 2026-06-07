import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('openapi.json').readAsStringSync();
  final data = jsonDecode(file);
  print(data.keys.toList());
  print(data['definitions']?.keys.toList());
}
