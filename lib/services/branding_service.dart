import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:El Guia YA_master/services/supabase_service.dart';

class BrandingConfig {
  final String clave;
  final String? valor;
  final String tipoValor;
  final String? descripcion;
  final DateTime actualizadoAt;
  final String? actualizadoPorEmail;
  final String? actualizadoPorNombre;

  BrandingConfig({
    required this.clave,
    this.valor,
    required this.tipoValor,
    this.descripcion,
    required this.actualizadoAt,
    this.actualizadoPorEmail,
    this.actualizadoPorNombre,
  });

  factory BrandingConfig.fromSupabase(Map<String, dynamic> data) {
    return BrandingConfig(
      clave: data['clave'] ?? '',
      valor: data['valor'],
      tipoValor: data['tipo_valor'] ?? 'texto',
      descripcion: data['descripcion'],
      actualizadoAt: DateTime.parse(data['actualizado_at']),
      actualizadoPorEmail: data['actualizado_por_email'],
      actualizadoPorNombre: data['actualizado_por_nombre'],
    );
  }

  double? get valorNumerico {
    if (valor == null) return null;
    return double.tryParse(valor!);
  }

  bool? get valorBooleano {
    if (valor == null) return null;
    return valor?.toLowerCase() == 'true';
  }

  bool get esImagen => tipoValor == 'imagen_url';
}

class LoginConfig {
  final String? backgroundUrl;
  final double opacity;
  final double brightness;

  LoginConfig({
    this.backgroundUrl,
    required this.opacity,
    required this.brightness,
  });

  factory LoginConfig.fromSupabase(List<Map<String, dynamic>> data) {
    final row = data.isNotEmpty ? data.first : {};
    return LoginConfig(
      backgroundUrl: row['background_url'],
      opacity: (row['opacity'] as num?)?.toDouble() ?? 0.7,
      brightness: (row['brightness'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class BrandingService {
  static final SupabaseClient _supabase = SupabaseService.supabase;
  static const String _bucketName = 'branding';

  static Stream<List<BrandingConfig>> getBrandingStream() {
    return _supabase
        .from('vista_configuracion_branding')
        .stream(primaryKey: ['clave'])
        .order('categoria, clave')
        .map((event) => event.map((config) => BrandingConfig.fromSupabase(config)).toList());
  }

  static Future<LoginConfig> getLoginConfig() async {
    print('DEBUG: Iniciando carga de configuracion de branding...');
    final startTime = DateTime.now();
    
    try {
      final response = await _supabase
          .from('configuracion_app')
          .select()
          .inFilter('clave', ['login_background_url', 'login_opacity', 'login_brightness'])
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => [],
          );
      
      final configs = <String, String>{};
      for (final item in response) {
        configs[item['clave']] = item['valor'] ?? '';
      }
      
      final endTime = DateTime.now();
      print('DEBUG: Configuracion cargada via consulta directa en ${endTime.difference(startTime).inMilliseconds}ms');
      
      return LoginConfig(
        backgroundUrl: getSafeUrl(configs['login_background_url']),
        opacity: double.tryParse(configs['login_opacity'] ?? '0.5') ?? 0.5,
        brightness: double.tryParse(configs['login_brightness'] ?? '1.0') ?? 1.0,
      );
        } catch (e) {
      print('DEBUG: Error en consulta directa: $e');
    }

    return LoginConfig(
      backgroundUrl: defaultBackgroundUrl,
      opacity: 0.5,
      brightness: 1.0,
    );
  }

  static String getSafeUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    if (!kIsWeb) return url;
    if (url.contains('weserv')) return url;
    return 'https://images.weserv.nl/?url=${url.replaceAll('https://', '')}';
  }

  static String get defaultBackgroundUrl {
    const raw = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/portada_inicio.jpg';
    if (!kIsWeb) return raw;
    return 'https://images.weserv.nl/?url=${raw.replaceAll('https://', '')}';
  }

  static String get defaultLogoUrl {
    const raw = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/velero.jpg';
    if (!kIsWeb) return raw;
    return 'https://images.weserv.nl/?url=${raw.replaceAll('https://', '')}&q=100&w=600';
  }

  static Stream<LoginConfig> getLoginConfigStream() {
    return _supabase
        .from('configuracion_app')
        .stream(primaryKey: ['clave'])
        .inFilter('clave', ['login_background_url', 'login_opacity', 'login_brightness'])
        .map((event) {
          final configs = <String, String>{};
          for (final item in event) {
            configs[item['clave']] = item['valor'] ?? '';
          }
          final rawUrl = configs['login_background_url'] ?? '';
          
          return LoginConfig(
            backgroundUrl: getSafeUrl(rawUrl),
            opacity: double.tryParse(configs['login_opacity'] ?? '0.5') ?? 0.5,
            brightness: double.tryParse(configs['login_brightness'] ?? '1.0') ?? 1.0,
          );
        });
  }

  static Stream<int> getBannerRotationStream() {
    return _supabase
        .from('configuracion_app')
        .stream(primaryKey: ['clave'])
        .eq('clave', 'banner_rotation_seconds')
        .map((event) {
          if (event.isEmpty) return 5;
          return int.tryParse(event.first['valor'] ?? '5') ?? 5;
        });
  }

  static Future<int> getBannerRotationSeconds() async {
    try {
      final response = await _supabase
          .from('configuracion_app')
          .select('valor')
          .eq('clave', 'banner_rotation_seconds')
          .maybeSingle();
      
      if (response == null) return 5;
      return int.tryParse(response['valor']?.toString() ?? '5') ?? 5;
    } catch (e) {
      return 5;
    }
  }

  static Future<String> subirImagenBranding({
    required dynamic archivo,
    required String carpeta,
    String? nombrePersonalizado,
  }) async {
    try {
      Uint8List fileBytes;
      String fileName;
      String contentType;
      
      if (archivo is XFile) {
        fileName = archivo.name.toLowerCase();
        fileBytes = await archivo.readAsBytes();
        
        if (fileName.endsWith('.png')) {
          contentType = 'image/png';
        } else if (fileName.endsWith('.gif')) contentType = 'image/gif';
        else if (fileName.endsWith('.webp')) contentType = 'image/webp';
        else contentType = 'image/jpeg';
      } else if (archivo is Uint8List) {
        fileName = nombrePersonalizado ?? 'image.jpg';
        fileBytes = archivo;
        contentType = 'image/jpeg';
      } else {
        throw Exception('Tipo de archivo no soportado');
      }

      final String finalFileName = nombrePersonalizado ?? generarNombreUnico(fileName);
      final String fullPath = '$carpeta/$finalFileName';
      
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            fullPath,
            fileBytes,
            fileOptions: FileOptions(
              contentType: contentType,
              upsert: true,
            ),
          );

      return _supabase.storage.from(_bucketName).getPublicUrl(fullPath);
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  static Future<bool> eliminarImagenBranding(String url) async {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      
      int bucketIndex = -1;
      for (int i = 0; i < pathSegments.length; i++) {
        if (pathSegments[i] == _bucketName) {
          bucketIndex = i;
          break;
        }
      }

      if (bucketIndex == -1 || bucketIndex + 1 >= pathSegments.length) {
        throw Exception('URL de imagen invalida');
      }

      final path = pathSegments.skip(bucketIndex + 1).join('/');
      await _supabase.storage.from(_bucketName).remove([path]);
      return true;
    } catch (e) {
      throw Exception('Error al eliminar imagen: $e');
    }
  }

  static Future<bool> actualizarConfiguracion({
    required String clave,
    required String valor,
    String? tipoValor,
    String? descripcion,
  }) async {
    try {
      await _supabase.from('configuracion_app').upsert({
        'clave': clave,
        'valor': valor,
        'tipo_valor': tipoValor ?? 'texto',
        'descripcion': descripcion,
        'actualizado_at': DateTime.now().toIso8601String(),
      }, onConflict: 'clave');
      return true;
    } catch (dbError) {
      throw Exception('Error al actualizar configuracion ($clave): $dbError');
    }
  }

  static Future<bool> actualizarConfiguracionLogin({
    String? backgroundUrl,
    double? opacity,
    double? brightness,
  }) async {
    try {
      bool resultado = true;
      if (backgroundUrl != null) {
        resultado &= await actualizarConfiguracion(
          clave: 'login_background_url',
          valor: backgroundUrl,
          tipoValor: 'imagen_url',
          descripcion: 'Imagen de fondo login',
        );
      }
      if (opacity != null) {
        resultado &= await actualizarConfiguracion(
          clave: 'login_opacity',
          valor: opacity.toString(),
          tipoValor: 'numero',
        );
      }
      if (brightness != null) {
        resultado &= await actualizarConfiguracion(
          clave: 'login_brightness',
          valor: brightness.toString(),
          tipoValor: 'numero',
        );
      }
      return resultado;
    } catch (e) {
      throw Exception('Error al actualizar login: $e');
    }
  }

  static Future<bool> actualizarTextosLegales(String textoAyuda, String textoTerminos) async {
    try {
      bool resultado = true;
      resultado &= await actualizarConfiguracion(clave: 'texto_ayuda', valor: textoAyuda, tipoValor: 'texto_largo');
      resultado &= await actualizarConfiguracion(clave: 'texto_terminos', valor: textoTerminos, tipoValor: 'texto_largo');
      return resultado;
    } catch (e) {
      throw Exception('Error al actualizar textos: $e');
    }
  }

  static Future<Map<String, String>> getTextosLegales() async {
    try {
      final response = await _supabase
          .from('configuracion_app')
          .select()
          .inFilter('clave', ['texto_ayuda', 'texto_terminos']);
      
      final configs = <String, String>{};
      for (final item in response) {
        configs[item['clave']] = item['valor'] ?? '';
      }
          return configs;
    } catch (e) {
      return {};
    }
  }

  static bool esAdministrador() {
    return true; // Bypass para pruebas
  }

  static String generarNombreUnico(String nombreOriginal) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final extension = nombreOriginal.split('.').last;
    final nombreSinExtension = nombreOriginal.substring(0, nombreOriginal.lastIndexOf('.'));
    return '${nombreSinExtension}_$timestamp.$extension';
  }

  static Future<bool> limpiarConfiguracionBranding() async {
    try {
      await actualizarConfiguracionLogin(
        backgroundUrl: null,
        opacity: 0.5,
        brightness: 1.0,
      );
      return true;
    } catch (e) {
      throw Exception('Error al limpiar branding: $e');
    }
  }
}
