


import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class StorageConnectionTest {
  
  static const String _supabaseUrl = 'https://ymgsxwfwntbqvguvbhoa.supabase.co';
  static const String _supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  /// Simula conexion y prueba de todos los buckets
  static Future<Map<String, dynamic>> probarTodosLosBuckets() async {
    final resultados = <String, dynamic>{};
    
    print('🔍 INICIANDO SIMULACRO DE CONEXION A BUCKETS');
    print('=' * 60);
    
    // Lista de buckets a probar
    final buckets = [
      'branding_images',
      'fotos_perfil', 
      'documentacion_privada',
      'administracion_archivos'
    ];
    
    for (final bucket in buckets) {
      print('\n📁 Probando bucket: $bucket');
      final resultado = await _probarBucket(bucket);
      resultados[bucket] = resultado;
      
      if (resultado['conectado']) {
        print('✅ $bucket: CONECTADO');
        print('   📊 Archivos: ${resultado['cantidad_archivos']}');
        print('   📏 Tamano total: ${resultado['tamano_total_mb']} MB');
      } else {
        print('❌ $bucket: ERROR - ${resultado['error']}');
      }
    }
    
    return resultados;
  }
  
  /// Prueba individual de un bucket
  static Future<Map<String, dynamic>> _probarBucket(String bucketName) async {
    final resultado = <String, dynamic>{};
    
    try {
      // 1. Conectar a Supabase
      final supabase = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      
      // 2. Intentar listar archivos (prueba de conexion)
      final response = await supabase
          .storage
          .from(bucketName)
          .list()
          .timeout(const Duration(seconds: 10));
      
      // 3. Calcular estadisticas
      int cantidadArchivos = response.length;
      double tamanoTotal = 0.0;
      
      for (final file in response) {
        // Intentar obtener tamano del archivo
        try {
          final fileUrl = supabase.storage.from(bucketName).getPublicUrl(file.name);
          tamanoTotal += (file.metadata?['size'] as num?)?.toInt() ?? 0;
        } catch (e) {
          // Ignorar errores individuales
        }
      }
      
      resultado['conectado'] = true;
      resultado['cantidad_archivos'] = cantidadArchivos;
      resultado['tamano_total_mb'] = (tamanoTotal / (1024 * 1024)).toStringAsFixed(2);
      resultado['error'] = null;
      
    } catch (e) {
      resultado['conectado'] = false;
      resultado['cantidad_archivos'] = 0;
      resultado['tamano_total_mb'] = '0.00';
      resultado['error'] = e.toString();
    }
    
    return resultado;
  }
  
  /// Simula subida de prueba a cada bucket
  static Future<Map<String, dynamic>> probarSubidasSimuladas() async {
    final resultados = <String, dynamic>{};
    
    print('\n🚀 INICIANDO PRUEBA DE SUBIDAS SIMULADAS');
    print('=' * 60);
    
    // Datos de prueba
    final testBytes = Uint8List.fromList('TEST_IMAGE_DATA'.codeUnits);
    final testFileName = 'test_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    final buckets = [
      {'name': 'branding_images', 'path': 'test/$testFileName'},
      {'name': 'fotos_perfil', 'path': 'test_user/$testFileName'},
      {'name': 'documentacion_privada', 'path': 'test_docs/$testFileName'},
      {'name': 'administracion_archivos', 'path': 'test_admin/$testFileName'},
    ];
    
    for (final bucket in buckets) {
      print('\n📤 Probando subida a: ${bucket['name']}');
      final resultado = await _probarSubida(bucket['name']!, bucket['path']!, testBytes);
      resultados[bucket['name']!] = resultado;
      
      if (resultado['subida_exitosa']) {
        print('✅ ${bucket['name']}: SUBIDA EXITOSA');
        print('   🔗 URL: ${resultado['url']}');
        
        // Intentar limpiar archivo de prueba
        await _limpiarArchivo(bucket['name']!, bucket['path']!);
      } else {
        print('❌ ${bucket['name']}: ERROR DE SUBIDA');
        print('   🚫 Error: ${resultado['error']}');
      }
    }
    
    return resultados;
  }
  
  /// Prueba de subida individual
  static Future<Map<String, dynamic>> _probarSubida(String bucketName, String path, Uint8List bytes) async {
    final resultado = <String, dynamic>{};
    
    try {
      final supabase = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      
      // Subir archivo de prueba
      final response = await supabase
          .storage
          .from(bucketName)
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          )
          .timeout(const Duration(seconds: 15));
      
      // Obtener URL publica
      final publicUrl = supabase.storage.from(bucketName).getPublicUrl(path);
      
      resultado['subida_exitosa'] = true;
      resultado['url'] = publicUrl;
      resultado['error'] = null;
      
    } catch (e) {
      resultado['subida_exitosa'] = false;
      resultado['url'] = null;
      resultado['error'] = e.toString();
    }
    
    return resultado;
  }
  
  /// Limpia archivo de prueba
  static Future<void> _limpiarArchivo(String bucketName, String path) async {
    try {
      final supabase = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      await supabase.storage.from(bucketName).remove([path]);
      print('   🧹 Archivo de prueba eliminado');
    } catch (e) {
      print('   ⚠️ No se pudo eliminar archivo de prueba: $e');
    }
  }
  
  /// Genera informe completo
  static Future<String> generarInformeCompleto() async {
    final informe = StringBuffer();
    
    informe.writeln('📋 INFORME COMPLETO DE CONEXION A STORAGE');
    informe.writeln('=' * 60);
    informe.writeln('Fecha: ${DateTime.now()}');
    informe.writeln('URL Supabase: $_supabaseUrl');
    informe.writeln('');
    
    // Probar conexion a buckets
    final resultadosConexion = await probarTodosLosBuckets();
    
    informe.writeln('📊 RESULTADOS DE CONEXION:');
    informe.writeln('');
    
    for (final entry in resultadosConexion.entries) {
      final bucket = entry.key;
      final resultado = entry.value;
      
      if (resultado['conectado']) {
        informe.writeln('✅ $bucket: CONECTADO');
        informe.writeln('   📄 Archivos: ${resultado['cantidad_archivos']}');
        informe.writeln('   📏 Tamano: ${resultado['tamano_total_mb']} MB');
      } else {
        informe.writeln('❌ $bucket: ERROR');
        informe.writeln('   🚫 ${resultado['error']}');
      }
      informe.writeln('');
    }
    
    // Probar subidas
    final resultadosSubida = await probarSubidasSimuladas();
    
    informe.writeln('📤 RESULTADOS DE SUBIDAS:');
    informe.writeln('');
    
    for (final entry in resultadosSubida.entries) {
      final bucket = entry.key;
      final resultado = entry.value;
      
      if (resultado['subida_exitosa']) {
        informe.writeln('✅ $bucket: SUBIDA EXITOSA');
        informe.writeln('   🔗 URL: ${resultado['url']}');
      } else {
        informe.writeln('❌ $bucket: ERROR DE SUBIDA');
        informe.writeln('   🚫 ${resultado['error']}');
      }
      informe.writeln('');
    }
    
    // Resumen
    int bucketsConectados = resultadosConexion.values.where((r) => r['conectado']).length;
    int subidasExitosas = resultadosSubida.values.where((r) => r['subida_exitosa']).length;
    
    informe.writeln('📈 RESUMEN:');
    informe.writeln('   📁 Buckets conectados: $bucketsConectados/${resultadosConexion.length}');
    informe.writeln('   📤 Subidas exitosas: $subidasExitosas/${resultadosSubida.length}');
    
    if (bucketsConectados == resultadosConexion.length && subidasExitosas == resultadosSubida.length) {
      informe.writeln('');
      informe.writeln('🎉 TODOS LOS BUCKETS FUNCIONAN CORRECTAMENTE');
    } else {
      informe.writeln('');
      informe.writeln('⚠️ HAY PROBLEMAS QUE NECESITAN ATENCION');
    }
    
    return informe.toString();
  }
}
