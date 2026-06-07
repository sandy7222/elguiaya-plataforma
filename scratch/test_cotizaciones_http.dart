import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

void main() async {
  print('=== DIAGNÓSTICO HTTP DIRECTO A SUPABASE ===');
  final url = Uri.parse('https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/cotizaciones?select=*');
  final headers = {
    'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
    'Authorization': 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
  };

  try {
    final response = await http.get(url, headers: headers);
    print('Código de respuesta HTTP: ${response.statusCode}');
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body);
      print('Total de cotizaciones encontradas: ${data.length}');
      if (data.isNotEmpty) {
        for (var i = 0; i < (data.length > 5 ? 5 : data.length); i++) {
          final row = data[i];
          print(' - ID: ${row['id']} | Estado: ${row['estado']} | Creado: ${row['created_at']}');
        }
      } else {
        print('La tabla está VACÍA.');
      }
    } else {
      print('Error de servidor: ${response.body}');
    }
  } catch (e) {
    print('Error de red: $e');
  }
  exit(0);
}
