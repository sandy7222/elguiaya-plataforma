import 'dart:convert';
import 'dart:io';

void main() async {
  print('==================================================');
  print('🔍 Iniciando diagnóstico de tablas del Recolector de Basura...');
  print('==================================================');

  final client = HttpClient();
  
  try {
    // 1. Verificar papelera_cotizaciones
    await verificarTabla(client, 'papelera_cotizaciones');
    
    // 2. Verificar papelera_archivos
    await verificarTabla(client, 'papelera_archivos');
    
    // 3. Verificar guia_conocimiento_cementerio
    await verificarTabla(client, 'guia_conocimiento_cementerio');

  } catch (e) {
    print('❌ Error crítico de diagnóstico: $e');
  } finally {
    client.close();
  }
}

Future<void> verificarTabla(HttpClient client, String tabla) async {
  final url = Uri.parse('https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1/$tabla?select=*&limit=1');
  try {
    final req = await client.getUrl(url);
    req.headers.add('apikey', 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw');
    
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    
    if (res.statusCode == 200) {
      print('✅ Tabla "$tabla": EXISTE. Respuesta del servidor: $body');
    } else {
      print('❌ Tabla "$tabla": NO EXISTE o inaccesible (Código HTTP ${res.statusCode}). Detalles: $body');
    }
  } catch (e) {
    print('⚠️ Error al consultar "$tabla": $e');
  }
}
