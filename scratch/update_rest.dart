import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/configuracion_app?clave=eq.login_background_url';
  const key = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final headers = {
    'apikey': key,
    'Authorization': 'Bearer $key',
    'Content-Type': 'application/json',
    'Prefer': 'return=representation'
  };

  final body = jsonEncode({
    'valor': 'https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/portada_inicio.jpg',
    'tipo_valor': 'imagen_url'
  });

  print('Actualizando fondo de pantalla...');
  final response = await http.patch(Uri.parse(url), headers: headers, body: body);

  if (response.statusCode == 200 || response.statusCode == 204) {
    print('Exito! Fondo actualizado.');
  } else {
    // If not found, maybe we need to insert
    print('Error o no modificado: ${response.statusCode} - ${response.body}');
    
    // Try POST (upsert)
    final postUrl = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/configuracion_app';
    final postHeaders = {
      ...headers,
      'Prefer': 'resolution=merge-duplicates'
    };
    final postBody = jsonEncode({
      'clave': 'login_background_url',
      'valor': 'https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/portada_inicio.jpg',
      'tipo_valor': 'imagen_url'
    });
    final res = await http.post(Uri.parse(postUrl), headers: postHeaders, body: postBody);
    print('Intento POST (upsert): ${res.statusCode} - ${res.body}');
  }
}
