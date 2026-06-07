import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/';
  final apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  try {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        'apikey': apiKey,
      },
    );
    
    if (response.statusCode == 200) {
      final doc = json.decode(response.body);
      final definitions = doc['definitions'] as Map<String, dynamic>?;
      if (definitions != null) {
        print('--- TABLES LIST ---');
        for (var tableName in definitions.keys) {
          print('Table: $tableName');
          final tableDef = definitions[tableName] as Map<String, dynamic>;
          final properties = tableDef['properties'] as Map<String, dynamic>?;
          if (properties != null) {
            print('  Columns:');
            for (var colName in properties.keys) {
              final colDef = properties[colName] as Map<String, dynamic>;
              print('    - $colName (${colDef['type']})');
            }
          }
        }
      } else {
        print('No definitions found in OpenAPI doc');
      }
    } else {
      print('Failed to load OpenAPI doc: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
