import 'package:supabase/supabase.dart';

void main() async {
  final url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  final anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final supabase = SupabaseClient(url, anonKey);
  
  final colsToTest = [
    'id', 'cliente_id', 'pescador_id', 'capitan_id', 'cotizacion_id', 'estado',
    'fecha_salida', 'fecha_ida', 'fecha_vuelta', 'hora_salida', 'hora_encuentro',
    'punto_encuentro', 'lugar_encuentro', 'precio', 'monto_total', 'monto_cotizacion',
    'datos_pasajeros', 'manifiesto_id', 'productos_tienda', 'total_bultos', 'datos_pago',
    'pasajeros', 'bultos', 'fecha_embarque', 'created_at', 'updated_at',
    'fecha_pago', 'metodo_pago', 'pago_confirmado', 'codigo_acceso', 'nombre_cliente',
    'telefono_cliente', 'nombre_capitan', 'telefono_capitan'
  ];
  
  print('--- PROBANDO COLUMNAS VÍA SELECT EN TABLA reservas ---');
  for (var col in colsToTest) {
    try {
      final res = await supabase.from('reservas').select(col).limit(1);
      print('✅ Columna [$col] SÍ EXISTE. (Select exitoso: $res)');
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('PGRST204') || errStr.contains('Could not find')) {
        print('❌ Columna [$col] NO EXISTE.');
      } else {
        print('❓ Columna [$col] - Error inesperado: $e');
      }
    }
  }
}
