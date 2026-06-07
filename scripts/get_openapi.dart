import 'dart:convert';
import 'dart:io';

void main() async {
  final url = Uri.parse('https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/');
  final req = await HttpClient().getUrl(url);
  req.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw');
  final res = await req.close();
  final body = await res.transform(utf8.decoder).join();
  File('openapi.json').writeAsStringSync(body);
  print('OpenAPI guardado');
}
