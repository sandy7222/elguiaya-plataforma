import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

void main() async {
  print('=== DIAGNÓSTICO DE COTIZACIONES ===');
  try {
    await Supabase.initialize(
      url: 'https://ymgsxwfwntbqvguvbhoa.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw',
    );
    final supabase = Supabase.instance.client;
    print('Conexión con Supabase establecida.');

    // Intentamos recuperar cotizaciones
    final res = await supabase.from('cotizaciones').select('*');
    print('¡Consulta realizada con éxito!');
    print('Total de cotizaciones en la tabla: ${res.length}');
    
    if (res.isNotEmpty) {
      print('\nPrimeras 3 cotizaciones encontradas:');
      for (var i = 0; i < (res.length > 3 ? 3 : res.length); i++) {
        final doc = res[i];
        print(' - ID: ${doc['id']} | Pescador ID: ${doc['pescador_id']} | Estado: ${doc['estado']} | Creado: ${doc['created_at']}');
      }
    } else {
      print('\nLa tabla está completamente VACÍA.');
    }
  } catch (e) {
    print('⚠️ Error al consultar la tabla "cotizaciones": $e');
  }
  exit(0);
}
