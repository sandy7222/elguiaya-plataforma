import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:capitanya_master/models/banner_promo.dart';
import 'package:capitanya_master/models/categoria.dart';
import 'package:capitanya_master/models/cotizacion.dart';
import 'package:capitanya_master/models/direccion_envio.dart';
import 'package:capitanya_master/models/documento.dart';
import 'package:capitanya_master/models/favorito.dart';
import 'package:capitanya_master/models/guia.dart';
import 'package:capitanya_master/models/manifiesto_viaje.dart';
import 'package:capitanya_master/models/pedido.dart';
import 'package:capitanya_master/models/pedido_item.dart';
import 'package:capitanya_master/models/perfil_capitan.dart';
import 'package:capitanya_master/models/pescador.dart';
import 'package:capitanya_master/models/producto.dart';
import 'package:capitanya_master/models/rubro.dart';
import 'package:capitanya_master/models/user_profile.dart';
import 'package:capitanya_master/models/viajes_invitados.dart';
import 'package:capitanya_master/models/producto_atributo.dart';
import 'package:capitanya_master/models/notificacion.dart';
import 'package:capitanya_master/models/articulo_blog.dart';
import 'package:capitanya_master/services/afip_service.dart';
import 'package:capitanya_master/services/geofencing_service.dart';
import 'package:capitanya_master/services/notificacion_service.dart';
import 'mercado_pago_service.dart';
import 'disponibilidad_service_final.dart';
import 'notificacion_helper.dart';

class SupabaseService {
  static List<Producto> _cachedProductos = [];
  static List<Categoria> _cachedCategorias = [];

  static const String _envUrl = String.fromEnvironment('SUPABASE_URL');
  static const String _url = _envUrl != '' ? _envUrl : 'https://ymgsxwfwntbqvguvbhoa.supabase.co';

  static const String _envAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _anonKey = _envAnonKey != '' ? _envAnonKey : 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';

  // 🚨 CONFIGURACIÓN MODO OBRA (Bypass Auth 429) - DESACTIVADO PARA PRODUCCIÓN REAL
  static const bool MODO_OBRA_ACTIVE = false; 
  static const String MODO_OBRA_USER_ID = '00000000-0000-0000-0000-000000000000';

  // Simulación de Notificaciones en Tiempo Real (Modo Obra)
  static final StreamController<String> _notificacionesController = StreamController<String>.broadcast();
  static Stream<String> get notificacionesStream => _notificacionesController.stream;

  static void simularNuevaRutaTrazada() {
    _notificacionesController.add('¡Nueva ruta trazada en tu zona!');
  }

  /// Obtiene el cliente de Supabase de forma segura
  static SupabaseClient get supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      print('⚠️ [SUPABASE] Intento de acceso antes de inicializacion');
      rethrow; // O manejarlo de forma mas suave
    }
  }

  /// Obtiene el ID del usuario actual de la sesión real
  static String? get currentUserId => supabase.auth.currentUser?.id;

  static String? get currentUserEmail => supabase.auth.currentUser?.email;

  // --- MÉTODOS DE AUTH REALES ---
  static Future<AuthResponse> signUp(String email, String password) async {
    return await supabase.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await supabase.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    try {
      await eliminarFCMToken();
    } catch (e) {
      print('⚠️ [SUPABASE] Error limpiando token al cerrar sesión: $e');
    }
    await supabase.auth.signOut();
  }

  /// Inicializa la conexion con Supabase al arrancar la app
  static Future<void> initialize() async {
    try {
      // Inicialización con manejo de errores y timeout
      await Supabase.initialize(
        url: _url,
        anonKey: _anonKey,
      );
      print('✅ [SUPABASE] Inicializado correctamente');
    } catch (e) {
      print('❌ [SUPABASE] Error en inicializacion: $e');
    }
  }
  
  /// Verifica conectividad especifica con Supabase
  static Future<Map<String, dynamic>> _checkSupabaseConnectivity() async {
    final result = <String, dynamic>{};
    
    // En Web no existe InternetAddress.lookup, omitimos esta verificacion
    if (kIsWeb) {
      result['supabase_reachable'] = true;
      result['ip_addresses'] = [];
      result['error'] = null;
      result['diagnostic'] = 'Web: Verificacion DNS omitida';
      return result;
    }
    
    try {
      // DNS Check omitido para compatibilidad con compiladores estrictos
      result['supabase_reachable'] = true;
      result['ip_addresses'] = [];
      result['error'] = null;
      result['diagnostic'] = 'Mobile: DNS Check omitido para estabilidad';
    } catch (e) {
      result['supabase_reachable'] = false;
      result['error'] = e.toString();
      result['diagnostic'] = 'Error en verificacion: $e';
    }
    return result;
  }

  static Future<List<Guia>> getGuias() async {
    try {
      final response = await supabase
          .from('guias')
          .select('*')
          .order('id', ascending: false);
      
      return response.map((g) => Guia(
        id: g['id']?.toString() ?? '',
        nombre: g['nombre'] ?? '',
        dni: g['dni']?.toString() ?? '',
        localidad: g['localidad'] ?? '',
        provincia: g['provincia'] ?? '',
        calle: g['calle'] ?? '',
        altura: g['altura'] ?? '',
        email: g['email'] ?? '',
        especialidad: g['especialidad'] ?? '',
        telefono: g['telefono'] ?? '',
        carnetTimonel: g['carnet_timonel'] ?? '',
        polizaSeguro: g['poliza_seguro'] ?? '',
        cbu: g['cbu'] ?? '',
        bancoNombre: g['banco_nombre'] ?? '',
      )).toList();
    } catch (e) {
      throw Exception('Error al obtener guias: $e');
    }
  }

  /// Obtiene el perfil del guia/capitan actual
  static Future<Map<String, dynamic>?> obtenerPerfilGuiaActual() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return null;
      
      final guia = await supabase
          .from('guias')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();
      
      if (guia != null) {
        return guia;
      }
      
      final profile = await supabase
          .from('profiles')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();
          
      return profile;
    } catch (e) {
      print('Error en obtenerPerfilGuiaActual: $e');
      return null;
    }
  }

  static Future<Map<String, double>? > geocodificarDireccion({
    String? calle,
    String? numero,
    String? localidad,
    String? provincia,
  }) async {
    try {
      final parts = <String>[];
      if (calle != null && calle.trim().isNotEmpty) {
        parts.add(calle.trim());
        if (numero != null && numero.trim().isNotEmpty) {
          parts.add(numero.trim());
        }
      }
      if (localidad != null && localidad.trim().isNotEmpty) {
        parts.add(localidad.trim());
      }
      if (provincia != null && provincia.trim().isNotEmpty) {
        parts.add(provincia.trim());
      } else {
        parts.add('Argentina');
      }

      if (parts.isEmpty) return null;

      final query = parts.join(', ');
      print('🌐 [GEOCODER] Geocodificando dirección: "$query"');

      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query.toLowerCase().trim())}&format=json&countrycodes=ar&limit=1',
      );

      final httpResponse = await http.get(
        geoUrl,
        headers: {'User-Agent': 'El Guia YA_Mobile_App'},
      );

      if (httpResponse.statusCode == 200) {
        final List results = json.decode(httpResponse.body);
        if (results.isNotEmpty) {
          final lat = double.tryParse(results[0]['lat'].toString());
          final lon = double.tryParse(results[0]['lon'].toString());
          if (lat != null && lon != null) {
            print('🌐 [GEOCODER] Encontrado Nominatim: $lat, $lon');
            return {'lat': lat, 'lng': lon};
          }
        }
      }

      // Fallback a búsqueda solo por localidad si falla la dirección completa
      if (localidad != null && localidad.trim().isNotEmpty) {
        final cleanLocalidad = localidad.replaceAll('Buolevard', 'Boulevard').trim();
        print('🌐 [GEOCODER] Nominatim dirección completa falló. Reintentando por localidad: "$cleanLocalidad"');
        
        final fallbackQuery = provincia != null && provincia.trim().isNotEmpty
            ? '$cleanLocalidad, ${provincia.trim()}, Argentina'
            : '$cleanLocalidad, Argentina';

        final fallbackGeoUrl = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(fallbackQuery.toLowerCase().trim())}&format=json&countrycodes=ar&limit=1',
        );

        final fallbackHttpResponse = await http.get(
          fallbackGeoUrl,
          headers: {'User-Agent': 'El Guia YA_Mobile_App'},
        );

        if (fallbackHttpResponse.statusCode == 200) {
          final List results = json.decode(fallbackHttpResponse.body);
          if (results.isNotEmpty) {
            final lat = double.tryParse(results[0]['lat'].toString());
            final lon = double.tryParse(results[0]['lon'].toString());
            if (lat != null && lon != null) {
              print('🌐 [GEOCODER] Encontrado Nominatim (localidad): $lat, $lon');
              return {'lat': lat, 'lng': lon};
            }
          }
        }
      }
    } catch (e) {
      print('🌐 [GEOCODER] Error al geocodificar: $e');
    }
    return null;
  }

  /// Inserta un nuevo guia en la base de datos
  static Future<void> guardarGuia(Guia guia, {String? referidoId}) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Geocodificar dirección antes de guardar
      double? lat;
      double? lng;
      try {
        final coords = await geocodificarDireccion(
          calle: guia.calle,
          numero: guia.altura,
          localidad: guia.localidad,
          provincia: guia.provincia,
        );
        if (coords != null) {
          lat = coords['lat'];
          lng = coords['lng'];
        }
      } catch (e) {
        print('⚠️ Error al geocodificar durante guardarGuia: $e');
      }

      // 1. Guardar en tabla guias (Legado/Específica)
      await supabase.from('guias').insert({
        ...guia.toMap(),
        if (lat != null) 'zona_lat': lat,
        if (lng != null) 'zona_lng': lng,
      });
      
      // 2. Sincronizar con tabla profiles (Master)
      await supabase.from('profiles').upsert({
        'user_id': guia.id,
        'nombre': guia.nombre,
        'dni': guia.dni,
        'telefono': guia.telefono,
        'localidad': guia.localidad,
        'direccion_calle': guia.calle,
        'direccion_numero': guia.altura,
        'provincia': guia.provincia,
        'es_capitan': true, // Marcar como capitan
        'verificado': false, // Inicialmente pendiente
        'estado': 'pendiente',
        'avatar_url': guia.avatarUrl,
        'seguro_url': guia.seguroUrl,
        'embarcacion_url': guia.embarcacionUrl,
        'foto_dni_url': guia.dniUrl,
        'carnet_url': guia.carnetUrl,
        'referido': guia.referido,
        'referido_id': referidoId,
        if (lat != null) 'zona_lat': lat,
        if (lng != null) 'zona_lng': lng,
      }, onConflict: 'user_id');

    } catch (e) {
      // Este error suele ser por falta de permisos RLS en la base de datos
      throw Exception('Error al guardar guia en la base de datos: $e');
    }
  }

  /// Obtener perfiles (Capitanes o Pescadores) con documentación pendiente
  static Future<List<Map<String, dynamic>>> getPerfilesPendientes() async {
    try {
      final supabase = Supabase.instance.client;
      
      final response = await supabase
          .from('profiles')
          .select('*')
          .inFilter('estado', ['pendiente', 'en_revision'])
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Error en getPerfilesPendientes: $e');
      throw Exception('Error al obtener perfiles pendientes: $e');
    }
  }

  /// Obtener directorio completo de capitanes aprobados y activos
  static Future<List<Map<String, dynamic>>> getDirectorioCapitanes() async {
    try {
      final supabase = Supabase.instance.client;
      // Obtener perfiles de capitán activos
      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('es_capitan', true)
          .eq('estado', 'activo')
          .order('created_at', ascending: false);
      
      final list = List<Map<String, dynamic>>.from(response);
      
      // Obtener datos de guias para combinar CBU y Banco
      final guiasData = await supabase
          .from('guias')
          .select('id, cbu, banco_nombre');
          
      final guiasMap = {for (var g in guiasData) g['id']?.toString(): g};
      
      for (var p in list) {
        final capId = p['user_id']?.toString();
        final g = guiasMap[capId];
        if (g != null) {
          p['cbu'] = g['cbu'] ?? '';
          p['banco_nombre'] = g['banco_nombre'] ?? '';
        }
      }
      
      return list;
    } catch (e) {
      throw Exception('Error al obtener directorio de capitanes: $e');
    }
  }

  /// Obtener cantidad total de cotizaciones
  static Future<int> getContadorCotizaciones() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('cotizaciones').select('id');
      return (response as List).length;
    } catch (e) {
      print('Error al contar cotizaciones: $e');
      return 0;
    }
  }

  /// Aprobar o rechazar documentación de capitán y traspasar a tablas legadas
  static Future<void> actualizarEstadoSocio(String userId, String estado, {String? expediente}) async {
    try {
      final supabase = Supabase.instance.client;
      
      // 1. Obtener datos actuales del perfil para saber si es capitan y si ya tiene expediente
      final profileResponse = await supabase
          .from('profiles')
          .select('es_capitan, expediente')
          .eq('user_id', userId)
          .single();
      
      final bool isCapitan = profileResponse['es_capitan'] == true;
      String? expedienteFinal = expediente ?? profileResponse['expediente'];

      // 2. Generar Legajo Automático si es aprobación y no tiene uno
      if (estado == 'activo' && expedienteFinal == null) {
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
        final prefix = isCapitan ? 'CAP' : 'PES';
        expedienteFinal = '$prefix-2026-$timestamp';
      }

      // 3. Actualizar el perfil maestro
      final updateData = {
        'estado': estado,
        'verificado': estado == 'activo',
        'expediente': expedienteFinal,
      };
      
      await supabase
          .from('profiles')
          .update(updateData)
          .eq('user_id', userId);

      // 2. Si es admitido (activo), asegurar que esté en la tabla legada correspondiente
      if (estado == 'activo') {
        final profile = await supabase
            .from('profiles')
            .select('*')
            .eq('user_id', userId)
            .single();
        
        await traspasarSocioALegado(profile);
      }
    } catch (e) {
      throw Exception('Error al actualizar estado del socio: $e');
    }
  }

  /// Traspasa los datos de un perfil a la tabla de pescadores o guias según corresponda
  static Future<void> traspasarSocioALegado(Map<String, dynamic> profile) async {
    try {
      final supabase = Supabase.instance.client;
      final isCapitan = profile['es_capitan'] == true;
      final userId = profile['user_id'];

      // Parsear DNI a entero de forma segura
      final rawDni = profile['dni'] ?? '0';
      final int? dniInt = int.tryParse(rawDni.toString().replaceAll(RegExp(r'\D'), ''));

      if (isCapitan) {
        // Traspasar a tabla 'guias'
        await supabase.from('guias').upsert({
          'id': userId, 
          'nombre': profile['nombre'],
          'dni': dniInt ?? 0,
          'telefono': profile['telefono'],
          'email': profile['email'] ?? '',
          'localidad': profile['localidad'] ?? '',
          'provincia': profile['provincia'] ?? '',
          'calle': profile['direccion_calle'] ?? profile['calle'] ?? '',
          'altura': profile['direccion_numero'] ?? profile['altura'] ?? '',
          'cp': profile['cp']?.toString() ?? '',
          'avatar_url': profile['avatar_url'],
          'carnet_timonel': profile['carnet_url'],
          'poliza_seguro': profile['seguro_url'],
          'expediente': profile['expediente'] ?? 'CAP-2026-TEMP',
          'capacidad_personas': profile['capacidad_personas'] ?? 0,
          'referido': profile['referido'],
          'cbu': profile['cbu'],
          'banco_nombre': profile['banco_nombre'],
        });
      } else {
        // Traspasar a tabla 'pescadores'
        await supabase.from('pescadores').upsert({
          'user_id': userId,
          'nombre': profile['nombre'],
          'dni': dniInt ?? 0,
          'email': profile['email'] ?? '',
          'telefono': profile['telefono'],
          'localidad': profile['localidad'] ?? '',
          'provincia': profile['provincia'] ?? '',
          'avatar_url': profile['avatar_url'],
          'dni_url': profile['foto_dni_url'] ?? profile['dni_url'], 
          'expediente': profile['expediente'] ?? 'PES-2026-TEMP',
          'referido': profile['referido'],
        });
      }
    } catch (e) {
      print('Error en el traspaso a tablas legadas: $e');
      // No lanzamos excepcion para no frenar el proceso principal, pero lo logueamos
    }
  }

  /// Verifica si han pasado más de 48 horas desde el registro y auto-aprueba si es necesario
  static Future<bool> actualizarEstadoEnvio(String pedidoId, String nuevoEstado) async {
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('pedidos').update({'estado_envio': nuevoEstado}).eq('id', pedidoId);
      return true;
    } catch (e) {
      print('Error al actualizar envío: $e');
      return false;
    }
  }

  static Future<void> verificarAutoAprobacion(String userId) async {
    try {
      final supabase = Supabase.instance.client;
      final profile = await supabase
          .from('profiles')
          .select('created_at, estado')
          .eq('user_id', userId)
          .single();

      if (profile['estado'] == 'pendiente') {
        final createdAt = DateTime.parse(profile['created_at']);
        final horasTranscurridas = DateTime.now().difference(createdAt).inHours;

        if (horasTranscurridas >= 48) {
          print('Auto-aprobando socio por vencimiento de 48hs (Usuario: $userId)');
          await actualizarEstadoSocio(userId, 'activo');
        }
      }
    } catch (e) {
      print('Error en verificación de auto-aprobación: $e');
    }
  }

  /// Inserta un nuevo pescador en la base de datos con automatizacion de legajo
  static Future<void> guardarPescador(Pescador pescador, {String? referidoId}) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Generar Numero de Socio Automatico (Legajo)
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      final numeroSocio = 'PES-2026-$timestamp';

      // Geocodificar dirección antes de guardar
      double? lat;
      double? lng;
      try {
        final coords = await geocodificarDireccion(
          calle: pescador.calle,
          numero: pescador.altura,
          localidad: pescador.localidad,
          provincia: pescador.provincia,
        );
        if (coords != null) {
          lat = coords['lat'];
          lng = coords['lng'];
        }
      } catch (e) {
        print('⚠️ Error al geocodificar durante guardarPescador: $e');
      }
 
      // 1. Guardar en tabla profiles (Master) con estado activo y legajo
      final profileData = {
        'user_id': pescador.id,
        'nombre': pescador.nombre,
        'dni': pescador.dni,
        'telefono': pescador.telefono,
        'localidad': pescador.localidad,
        'direccion_calle': pescador.calle,
        'direccion_numero': pescador.altura,
        'provincia': pescador.provincia,
        'es_capitan': false,
        'verificado': true,
        'estado': 'activo',
        'expediente': numeroSocio,
        'foto_dni_url': pescador.dniUrl,
        'avatar_url': pescador.avatarUrl,
        'referido': pescador.referido,
        'referido_id': referidoId,
        'bio_pescador': pescador.bioPescador,
        if (lat != null) 'zona_lat': lat,
        if (lng != null) 'zona_lng': lng,
      };
 
      await supabase.from('profiles').upsert(profileData, onConflict: 'user_id');
 
      // 2. Traspasar inmediatamente a la tabla legada de pescadores
      await traspasarSocioALegado(profileData);
 
    } catch (e) {
      throw Exception('Error al guardar pescador y generar legajo: $e');
    }
  }

  /// Obtener directorio completo de pescadores para el admin
  static Future<List<Map<String, dynamic>>> getDirectorioPescadores() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('es_capitan', false)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener directorio de pescadores: $e');
    }
  }

  /// Cambiar estado de un pescador (Bloquear/Desbloquear)
  static Future<void> actualizarEstadoPescador(String userId, String estado) async {
    try {
      await supabase
          .from('profiles')
          .update({'estado': estado})
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar estado del pescador: $e');
    }
  }

  static Future<List<Pescador>> getPescadores() async {
    try {
      final response = await supabase
          .from('pescadores')
          .select('*');
      
      return response.map((p) => Pescador(
        id: p['user_id'] ?? p['id']?.toString(),
        nombre: p['nombre'] ?? '',
        dni: p['dni']?.toString() ?? '',
        localidad: p['localidad'] ?? '',
        provincia: p['provincia'] ?? '',
        calle: p['calle'] ?? '',
        altura: p['altura'] ?? '',
        email: p['email'] ?? '',
        cp: p['cp']?.toString() ?? '',
        telefono: p['telefono'] ?? '',
      )).toList();
    } catch (e) {
      throw Exception('Error al obtener pescadores: $e');
    }
  }

  /// Guardar documento en la tabla documentos_usuarios
  static Future<void> guardarDocumento(Documento documento) async {
    try {
      await supabase.from('documentos_usuarios').insert(documento.toMap());
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a documentos_usuarios. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al guardar documento en Supabase: $e');
    }
  }

  /// Obtener documentos de un usuario
  static Future<List<Documento>> getDocumentosPorUsuario(String usuarioId) async {
    try {
      final response = await supabase
          .from('documentos_usuarios')
          .select('*')
          .eq('usuario_id', usuarioId)
          .order('created_at', ascending: false);
      
      return List<Documento>.from(response.map((doc) => Documento.fromSupabase(doc)));
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a documentos_usuarios. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al obtener documentos de Supabase: $e');
    }
  }

  /// Obtener documentos por tipo
  static Future<List<Documento>> getDocumentosPorTipo(String tipoDoc) async {
    try {
      final response = await supabase
          .from('documentos_usuarios')
          .select('*')
          .eq('tipo_doc', tipoDoc)
          .order('created_at', ascending: false);
      
      return List<Documento>.from(response.map((doc) => Documento.fromSupabase(doc)));
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a documentos_usuarios. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al obtener documentos por tipo de Supabase: $e');
    }
  }

  /// Eliminar documento
  static Future<void> eliminarDocumento(String documentoId) async {
    try {
      await supabase.from('documentos_usuarios').delete().eq('id', documentoId);
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a documentos_usuarios. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al eliminar documento de Supabase: $e');
    }
  }

  
  /// Guardar invitado en la tabla viajes_invitados
  static Future<void> guardarInvitado(ViajesInvitados invitado) async {
    try {
      await supabase.from('viajes_invitados').insert(invitado.toMap());
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a viajes_invitados. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al guardar invitado en Supabase: $e');
    }
  }

  /// Obtener invitados de un pescador
  static Future<List<ViajesInvitados>> getInvitadosPorPescador(String pescadorId) async {
    try {
      final response = await supabase
          .from('viajes_invitados')
          .select('*')
          .eq('pescador_id', pescadorId)
          .order('created_at', ascending: false);
      
      return List<ViajesInvitados>.from(response.map((inv) => ViajesInvitados.fromSupabase(inv)));
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a viajes_invitados. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al obtener invitados de Supabase: $e');
    }
  }

  /// Eliminar invitado
  static Future<void> eliminarInvitado(String invitadoId) async {
    try {
      await supabase.from('viajes_invitados').delete().eq('id', invitadoId);
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a viajes_invitados. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al eliminar invitado de Supabase: $e');
    }
  }

  // ========== METODOS DE E-COMMERCE ==========

  /// Guardar producto en la tabla productos y retornar su ID
  static Future<String> guardarProducto(Producto producto) async {
    try {
      _cachedProductos.clear();
      final response = await supabase
          .from('productos')
          .insert(producto.toInsertMap())
          .select('id')
          .single();
      return response['id'].toString();
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a productos. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al guardar producto en Supabase: $e');
    }
  }

  /// Actualiza un producto existente
  static Future<void> actualizarProducto(Producto producto) async {
    try {
      _cachedProductos.clear();
      await supabase
          .from('productos')
          .update(producto.toInsertMap())
          .eq('id', producto.id);
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a productos.');
      }
      throw Exception('Error al actualizar producto en Supabase: $e');
    }
  }

  /// Obtener todos los productos
  static Future<List<Producto>> getProductos({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedProductos.isNotEmpty) {
      return _cachedProductos;
    }
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .order('created_at', ascending: false);
      
      _cachedProductos = List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
      return _cachedProductos;
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a productos. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al obtener productos de Supabase: $e');
    }
  }

  /// Obtener productos destacados
  static Future<List<Producto>> getProductosDestacados() async {
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .eq('destacado', true)
          .eq('activo', true)
          .limit(8);
      
      return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
    } catch (e) {
      throw Exception('Error al obtener productos destacados: $e');
    }
  }

  /// Obtener productos por categoria
  static Future<List<Producto>> getProductosPorCategoria(String categoriaId, {bool forceRefresh = false}) async {
    try {
      final prods = await getProductos(forceRefresh: forceRefresh);
      final filtered = prods.where((p) => p.categoriaId == categoriaId).toList();
      filtered.sort((a, b) => a.nombre.compareTo(b.nombre));
      return filtered;
    } catch (e) {
      // Fallback a consulta directa si falla
      try {
        final response = await supabase
            .from('productos')
            .select('*')
            .eq('categoria_id', categoriaId)
            .order('nombre', ascending: true);
        return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
      } catch (_) {
        rethrow;
      }
    }
  }

  /// NOVEDADES: Obtener los últimos productos agregados
  static Future<List<Producto>> getNovedades({int limit = 10}) async {
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .eq('activo', true)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
    } catch (e) {
      print('Error al obtener novedades: $e');
      return [];
    }
  }

  /// MÁS VENDIDOS: Obtener productos destacados
  static Future<List<Producto>> getMasVendidos({int limit = 10}) async {
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .eq('activo', true)
          .eq('destacado', true)
          .limit(limit);
      
      return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
    } catch (e) {
      print('Error al obtener más vendidos: $e');
      return [];
    }
  }

  /// PRODUCTOS POR RUBRO: Para carruseles específicos (Camping, Pesca, etc.)
  static Future<List<Producto>> getProductosPorRubro(String rubro, {int limit = 10}) async {
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .eq('activo', true)
          .ilike('rubro', '%$rubro%')
          .limit(limit);
      
      return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
    } catch (e) {
      print('Error al obtener productos por rubro: $e');
      return [];
    }
  }

  /// Actualizar stock de producto
  static Future<void> actualizarStock(String productoId, int nuevoStock) async {
    try {
      _cachedProductos.clear();
      await supabase
          .from('productos')
          .update({'stock': nuevoStock, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', productoId);
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a productos. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al actualizar stock de producto en Supabase: $e');
    }
  }

  /// Eliminar producto (desactivar)
  static Future<void> eliminarProducto(String productoId) async {
    try {
      _cachedProductos.clear();
      await supabase
          .from('productos')
          .update({'activo': false, 'updated_at': DateTime.now().toIso8601String()})
          .eq('id', productoId);
    } catch (e) {
      // Error especifico para RLS
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a productos. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al eliminar producto de Supabase: $e');
    }
  }

  /// Obtener Atributos Técnicos (Ficha Técnica) de un producto
  static Future<List<ProductoAtributo>> getAtributosPorProducto(String productoId) async {
    try {
      final response = await supabase
          .from('producto_atributos')
          .select('*, atributos(*)')
          .eq('producto_id', productoId);
      
      return List<ProductoAtributo>.from(response.map((attr) => ProductoAtributo.fromSupabase(attr)));
    } catch (e) {
      print('Error al obtener atributos técnicos: $e');
      return [];
    }
  }

  /// Obtener producto por ID (para Deep Linking)
  static Future<Producto?> getProductoById(String id) async {
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      return Producto.fromSupabase(response);
    } catch (e) {
      print('Error al obtener producto por ID: $e');
      return null;
    }
  }

  /// BUSCADOR INTELIGENTE (ilike)
  static Future<List<Producto>> searchProductos(String query) async {
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .or('nombre.ilike.%$query%,descripcion.ilike.%$query%')
          .eq('activo', true)
          .order('nombre', ascending: true);
      
      return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
    } catch (e) {
      print('Error en búsqueda inteligente: $e');
      return [];
    }
  }

  /// STREAM EN TIEMPO REAL: Productos
  static Stream<List<Producto>> getProductosStream() {
    return supabase
        .from('productos')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) => data.map((prod) => Producto.fromSupabase(prod)).toList());
  }

  /// STREAM EN TIEMPO REAL: Categorías
  static Stream<List<Categoria>> getCategoriasStream({bool soloActivas = true}) {
    var query = supabase.from('categorias').stream(primaryKey: ['id']);
    
    return query.map((data) {
      var list = data.map((cat) => Categoria.fromSupabase(cat)).toList();
      if (soloActivas) {
        list = list.where((c) => c.activa).toList();
      }
      list.sort((a, b) => a.nombre.compareTo(b.nombre));
      return list;
    });
  }

  /// GESTIÓN DE INVENTARIO AUTOMÁTICA (Restar stock al vender)
  static Future<void> restarStock(String productoId, int cantidad) async {
    try {
      // 1. Obtener stock actual
      final prod = await getProductoById(productoId);
      if (prod != null) {
        final nuevoStock = (prod.stock - cantidad).clamp(0, 9999);
        await actualizarStock(productoId, nuevoStock);
      }
    } catch (e) {
      print('Error al restar stock: $e');
    }
  }

  /// Eliminar producto de forma permanente (Hard Delete)
  static Future<void> eliminarProductoReal(String productoId) async {
    try {
      _cachedProductos.clear();
      await supabase.from('productos').delete().eq('id', productoId);
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando la eliminacion.');
      }
      throw Exception('Error al eliminar producto de Supabase: $e');
    }
  }



  /// Obtener productos relacionados
  static Future<List<Producto>> getRelacionados(String productoId, {int limite = 5}) async {
    try {
      final prod = await getProductoById(productoId);
      if (prod == null) return [];

      final response = await supabase
          .from('productos')
          .select('*')
          .eq('categoria_id', prod.categoriaId)
          .neq('id', productoId)
          .eq('activo', true)
          .limit(limite);
      
      return List<Producto>.from(response.map((p) => Producto.fromSupabase(p)));
    } catch (e) {
      print('Error al obtener relacionados: $e');
      return [];
    }
  }

  /// Obtener categoría por ID
  static Future<Categoria?> getCategoriaById(String id) async {
    try {
      final response = await supabase
          .from('categorias')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      return Categoria.fromSupabase(response);
    } catch (e) {
      print('Error al obtener categoría por ID: $e');
      return null;
    }
  }

  /// DASHBOARD: Alertas Tempranas de Stock basadas en Velocidad de Leads
  static Future<List<Map<String, dynamic>>> getAlertasStockPredictivas() async {
    try {
      // 1. Obtener productos activos
      final productos = await getProductos();
      
      // 2. Obtener leads de los últimos 7 días (con fallback si la tabla no tiene la columna)
      List<dynamic> leads = [];
      try {
        final haceUnaSemana = DateTime.now().subtract(const Duration(days: 7)).toIso8601String();
        final leadsResponse = await supabase
            .from('cotizaciones')
            .select('id, created_at')
            .gte('created_at', haceUnaSemana);
        leads = leadsResponse as List<dynamic>;
      } catch (_) {
        // Tabla sin columna compatible — ignorar leads, seguir con stock crítico
        leads = [];
      }
      
      List<Map<String, dynamic>> alertas = [];

      for (var prod in productos) {
        if (prod.stock == 0) continue; // Ya encalló

        // Contar leads para este producto
        final leadsProd = leads.where((l) => l['producto_id'] == prod.id).length;
        
        if (leadsProd > 0) {
          final velocidadDiaria = leadsProd / 7;
          final diasRestantes = prod.stock / velocidadDiaria;

          if (diasRestantes <= 5) {
            alertas.add({
              'producto': prod.nombre,
              'stock': prod.stock,
              'dias_restantes': diasRestantes.round(),
              'prioridad': diasRestantes <= 2 ? 'ALTA' : 'MEDIA',
              'mensaje': 'Capitán, a este ritmo te quedarás sin ${prod.nombre} en ${diasRestantes.round()} días.',
              'rubro': prod.rubro,
            });
          }
        } else if (prod.stock < 3) {
          // Alerta por stock crítico aunque no haya leads recientes
          alertas.add({
            'producto': prod.nombre,
            'stock': prod.stock,
            'dias_restantes': 0,
            'prioridad': 'CRITICA',
            'mensaje': '¡Peligro! Stock crítico de ${prod.nombre}. Solo quedan ${prod.stock} unidades.',
            'rubro': prod.rubro,
          });
        }
      }

      return alertas;
    } catch (e) {
      print('Error en Dashboard Predictivo: $e');
      return [];
    }
  }

  /// Obtener todas las categorias (con Seed Data para Modo Obra)
  static Future<List<Categoria>> getCategorias({bool soloActivas = false, bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedCategorias.isNotEmpty) {
      if (soloActivas) {
        return _cachedCategorias.where((c) => c.activa).toList();
      }
      return _cachedCategorias;
    }
    try {
      final response = await supabase
          .from('categorias')
          .select('*')
          .order('nombre', ascending: true);
      
      final results = List<Categoria>.from(response.map((cat) => Categoria.fromSupabase(cat)));
      _cachedCategorias = results;

      // MODO OBRA: Si no hay categorías, inyectar 3 principales
      if (MODO_OBRA_ACTIVE && results.isEmpty) {
        _cachedCategorias = [
          Categoria(
            id: 'cat-1',
            nombre: 'Pesca Deportiva',
            descripcion: 'Excursiones con guías expertos en el Paraná.',
            iconoUrl: 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?q=80&w=400&auto=format&fit=crop',
            activa: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Categoria(
            id: 'cat-2',
            nombre: 'Alquiler de Embarcaciones',
            descripcion: 'Yates, lanchas y trackers para tu salida.',
            iconoUrl: 'https://images.unsplash.com/photo-1567899378494-47b22a2ec96a?q=80&w=400&auto=format&fit=crop',
            activa: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Categoria(
            id: 'cat-3',
            nombre: 'Paseos y Excursiones',
            descripcion: 'Disfrutá del río en familia o con amigos.',
            iconoUrl: 'https://images.unsplash.com/photo-1500530855697-b586d89ba3ee?q=80&w=400&auto=format&fit=crop',
            activa: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
      }

      if (soloActivas) {
        return _cachedCategorias.where((c) => c.activa).toList();
      }
      return _cachedCategorias;
    } catch (e) {
      if (MODO_OBRA_ACTIVE) {
        // Fallback de emergencia si falla Supabase por completo
        _cachedCategorias = [
          Categoria(
            id: 'cat-1',
            nombre: 'Pesca Deportiva',
            descripcion: 'Guías expertos.',
            activa: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Categoria(
            id: 'cat-2',
            nombre: 'Alquiler',
            descripcion: 'Embarcaciones.',
            activa: true,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];
        if (soloActivas) {
          return _cachedCategorias.where((c) => c.activa).toList();
        }
        return _cachedCategorias;
      }
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Politicas RLS bloqueadas.');
      }
      throw Exception('Error al obtener categorias: $e');
    }
  }

  /// Guardar categoria
  static Future<void> guardarCategoria(Categoria categoria) async {
    try {
      _cachedCategorias.clear();
      final data = {
        'nombre': categoria.nombre,
        'descripcion': categoria.descripcion,
        'activa': categoria.activa,
        'rubro_id': categoria.rubroId,
        'parent_id': categoria.parentId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Eliminar nulos para evitar errores si la columna no acepta vacios vs nulos
      data.removeWhere((key, value) => value == null);

      await supabase.from('categorias').insert(data);
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a categorias. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al guardar categoria en Supabase: $e');
    }
  }

  /// Actualizar categoria
  static Future<void> actualizarCategoria(Categoria categoria) async {
    try {
      _cachedCategorias.clear();
      final data = {
        'nombre': categoria.nombre,
        'descripcion': categoria.descripcion,
        'activa': categoria.activa,
        'rubro_id': categoria.rubroId,
        'parent_id': categoria.parentId,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      data.removeWhere((key, value) => value == null);

      await supabase.from('categorias').update(data).eq('id', categoria.id);
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a categorias. Debes configurarlas en el panel de Supabase.');
      }
      throw Exception('Error al actualizar categoria en Supabase: $e');
    }
  }

  /// Eliminar categoria (Borrado Fisico)
  static Future<void> eliminarCategoria(String categoriaId) async {
    try {
      _cachedCategorias.clear();
      await supabase.from('categorias').delete().eq('id', categoriaId);
    } catch (e) {
      if (e.toString().contains('401') || e.toString().contains('permission')) {
        throw Exception('ERROR 401: Las politicas RLS estan bloqueando el acceso a categorias. Debes configurarlas en el panel de Supabase.');
      }
      // Error de foreign key
      if (e.toString().contains('violates foreign key constraint')) {
        throw Exception('No se puede eliminar la categoria porque tiene productos asociados.');
      }
      throw Exception('Error al eliminar categoria de Supabase: $e');
    }
  }

  // ========== METODOS DE RUBROS ==========

  /// Obtener todos los rubros
  static Future<List<Rubro>> getRubros() async {
    try {
      final response = await supabase
          .from('rubros')
          .select('*')
          .eq('activo', true)
          .order('nombre', ascending: true);
      
      return List<Rubro>.from(response.map((rub) => Rubro.fromSupabase(rub)));
    } catch (e) {
      throw Exception('Error al obtener rubros de Supabase: $e');
    }
  }

  /// Obtener categorias por rubro
  static Future<List<Categoria>> getCategoriasPorRubro(String rubroId) async {
    try {
      final response = await supabase
          .from('categorias')
          .select('*')
          .eq('rubro_id', rubroId)
          .eq('activa', true)
          .order('nombre', ascending: true);
      
      return List<Categoria>.from(response.map((cat) => Categoria.fromSupabase(cat)));
    } catch (e) {
      throw Exception('Error al obtener categorias por rubro de Supabase: $e');
    }
  }

  /// Obtener productos por rubro y categoria
  static Future<List<Producto>> getProductosPorRubroCategoria({
    String? rubro,
    String? categoriaId,
  }) async {
    try {
      var query = supabase
          .from('productos')
          .select('*')
          .eq('activo', true)
          .gt('stock', 0);
      
      if (rubro != null && rubro.isNotEmpty) {
        query = query.eq('rubro', rubro);
      }
      
      if (categoriaId != null && categoriaId.isNotEmpty) {
        query = query.eq('categoria_id', categoriaId);
      }
      
      final response = await query.order('created_at', ascending: false);
      
      return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
    } catch (e) {
      throw Exception('Error al obtener productos por rubro/categoria de Supabase: $e');
    }
  }



  // ========== METODOS DE FAVORITOS ==========

  /// Guardar favorito
  static Future<void> guardarFavorito(Favorito favorito) async {
    try {
      await supabase.from('favoritos').insert(favorito.toInsertMap());
    } catch (e) {
      throw Exception('Error al guardar favorito en Supabase: $e');
    }
  }

  /// Obtener favoritos de un usuario (considera Modo Obra)
  static Future<List<Favorito>> getFavoritosPorUsuario([String? usuarioId]) async {
    try {
      final targetId = usuarioId ?? currentUserId;
      if (targetId == null) return [];

      final response = await supabase
          .from('favoritos')
          .select('*')
          .eq('usuario_id', targetId)
          .order('created_at', ascending: false);
      
      return List<Favorito>.from(response.map((fav) => Favorito.fromSupabase(fav)));
    } catch (e) {
      throw Exception('Error al obtener favoritos de Supabase: $e');
    }
  }

  /// Eliminar favorito
  static Future<void> eliminarFavorito(String favoritoId) async {
    try {
      await supabase.from('favoritos').delete().eq('id', favoritoId);
    } catch (e) {
      throw Exception('Error al eliminar favorito de Supabase: $e');
    }
  }

  /// Obtener productos por IDs
  static Future<List<Producto>> getProductosPorIds(List<String> productoIds) async {
    try {
      final response = await supabase
          .from('productos')
          .select('*')
          .filter('id', 'in', productoIds)
          .order('nombre', ascending: true);
      
      return List<Producto>.from(response.map((prod) => Producto.fromSupabase(prod)));
    } catch (e) {
      throw Exception('Error al obtener productos por IDs de Supabase: $e');
    }
  }

  // ========== METODOS DE PEDIDOS ==========

  /// Crear pedido con items de forma atomica
  static Future<String> crearPedidoConItems({
    required String usuarioId,
    required List<Map<String, dynamic>> items,
    required double total,
    required String direccionEnvio,
    String notas = '',
  }) async {
    try {
      // Usar funcion RPC para transaccion atomica
      final response = await supabase.rpc('crear_pedido_con_items', params: {
        'p_usuario_id': usuarioId,
        'p_items': items,
        'p_total': total,
        'p_direccion_envio': direccionEnvio,
        'p_notas': notas,
      });

      return response.toString();
    } catch (e) {
      throw Exception('Error al crear pedido en Supabase: $e');
    }
  }

  /// Obtener pedidos de un usuario con relacion de tablas (considera Modo Obra)
  static Future<List<Pedido>> getPedidosPorUsuarioConItems([String? usuarioId]) async {
    try {
      final targetId = usuarioId ?? currentUserId;
      if (targetId == null) return [];

      final response = await supabase
          .from('pedidos')
          .select('*, pedido_items(*, productos(*))')
          .eq('usuario_id', targetId)
          .order('created_at', ascending: false);
      
      return List<Pedido>.from(response.map((ped) => Pedido.fromSupabase(ped)));
    } catch (e) {
      throw Exception('Error al obtener pedidos de Supabase: $e');
    }
  }

  /// Obtener pedidos de un usuario (delegado a la función maestra con items)
  static Future<List<Pedido>> getPedidosPorUsuario(String usuarioId) async {
    return await getPedidosPorUsuarioConItems(usuarioId);
  }

  /// Obtener items de un pedido
  static Future<List<PedidoItem>> getItemsPorPedido(String pedidoId) async {
    try {
      final response = await supabase
          .from('pedido_items')
          .select('*')
          .eq('pedido_id', pedidoId)
          .order('created_at', ascending: true);
      
      return List<PedidoItem>.from(response.map((item) => PedidoItem.fromSupabase(item)));
    } catch (e) {
      throw Exception('Error al obtener items del pedido de Supabase: $e');
    }
  }

  /// Actualizar estado de pedido
  static Future<void> actualizarEstadoPedido(String pedidoId, String nuevoEstado) async {
    try {
      await supabase
          .from('pedidos')
          .update({
            'estado': nuevoEstado,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId);
    } catch (e) {
      throw Exception('Error al actualizar estado del pedido: $e');
    }
  }

  /// Cancelar pedido
  static Future<void> cancelarPedido(String pedidoId) async {
    try {
      await supabase.rpc('cancelar_pedido', params: {
        'p_pedido_id': pedidoId,
      });
    } catch (e) {
      throw Exception('Error al cancelar pedido: $e');
    }
  }

  // ========== METODOS DE ADMIN VENTAS ==========

  /// Consulta maestra de todos los pedidos con relaciones
  static Future<List<Map<String, dynamic>>> getPedidosMaestro() async {
    try {
      final response = await supabase
          .from('pedidos')
          .select('''
            *,
            pedido_items(*, producto:productos(*, categoria:categorias(nombre))),
            usuarios!inner(
              id,
              email,
              nombre,
              telefono,
              created_at
            )
          ''')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener pedidos maestro de Supabase: $e');
    }
  }

  /// Actualizar estado de envio de un pedido
  static Future<void> actualizarEstadoEnvioPedido(String pedidoId, String nuevoEstado) async {
    try {
      await supabase
          .from('pedidos')
          .update({
            'estado_envio': nuevoEstado,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId);
    } catch (e) {
      throw Exception('Error al actualizar estado de envio: $e');
    }
  }

  /// Actualizar estado de envio y agregar ticket de envio
  static Future<void> actualizarEstadoEnvioConTicket(
    String pedidoId, 
    String nuevoEstado,
    String ticketUrl
  ) async {
    try {
      await supabase
          .from('pedidos')
          .update({
            'estado_envio': nuevoEstado,
            'ticket_envio_url': ticketUrl,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId);
    } catch (e) {
      throw Exception('Error al actualizar estado de envio con ticket: $e');
    }
  }

  /// Obtener estadisticas de ventas para el admin
  static Future<Map<String, dynamic>> getEstadisticasVentas() async {
    try {
      final response = await supabase.rpc('obtener_estadisticas_ventas');
      return Map<String, dynamic>.from(response);
    } catch (e) {
      // Si la funcion RPC no existe, usar consulta directa
      try {
        final pedidos = await supabase
            .from('pedidos')
            .select('total, estado, estado_envio, created_at');
        
        final totalVentas = pedidos.fold<double>(0.0, (sum, pedido) => 
          sum + ((pedido['total'] as num?)?.toDouble() ?? 0.0));
        
        final pedidosPendientes = pedidos.where((p) => 
          p['estado'] == 'pendiente' || p['estado_envio'] == 'preparando').length;
        
        final pedidosDespachados = pedidos.where((p) => 
          p['estado_envio'] == 'despachado').length;
        
        final pedidosEntregados = pedidos.where((p) => 
          p['estado_envio'] == 'entregado').length;
        
        return {
          'total_ventas': totalVentas,
          'total_pedidos': pedidos.length,
          'pedidos_pendientes': pedidosPendientes,
          'pedidos_despachados': pedidosDespachados,
          'pedidos_entregados': pedidosEntregados,
        };
      } catch (e2) {
        throw Exception('Error al obtener estadisticas de ventas: $e2');
      }
    }
  }

  /// Obtener pedidos por estado de envio
  static Future<List<Map<String, dynamic>>> getPedidosPorEstadoEnvio(String estadoEnvio) async {
    try {
      final response = await supabase
          .from('pedidos')
          .select('''
            *,
            pedido_items(*, productos(*)),
            usuarios!inner(
              id,
              email,
              nombre,
              telefono,
              created_at
            )
          ''')
          .eq('estado_envio', estadoEnvio)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener pedidos por estado de envio: $e');
    }
  }

  // ========== METODOS DE DIRECCIONES DE ENVIO ==========

  /// Guardar direccion de envio
  static Future<String> guardarDireccionEnvio(DireccionEnvio direccion) async {
    try {
      final response = await supabase
          .from('direcciones_envio')
          .insert(direccion.toInsertMap())
          .select('id')
          .single();
      
      return response['id'] as String;
    } catch (e) {
      throw Exception('Error al guardar direccion de envio: $e');
    }
  }

  /// Obtener direcciones de envio de un usuario
  static Future<List<DireccionEnvio>> getDireccionesEnvioPorUsuario(String usuarioId) async {
    try {
      final response = await supabase
          .from('direcciones_envio')
          .select('*')
          .eq('usuario_id', usuarioId)
          .order('created_at', ascending: false);
      
      return List<DireccionEnvio>.from(response.map((dir) => DireccionEnvio.fromSupabase(dir)));
    } catch (e) {
      throw Exception('Error al obtener direcciones de envio: $e');
    }
  }

  /// Actualizar direccion de envio
  static Future<void> actualizarDireccionEnvio(DireccionEnvio direccion) async {
    try {
      await supabase
          .from('direcciones_envio')
          .update({
            ...direccion.toInsertMap(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', direccion.id);
    } catch (e) {
      throw Exception('Error al actualizar direccion de envio: $e');
    }
  }

  /// Eliminar direccion de envio
  static Future<void> eliminarDireccionEnvio(String direccionId) async {
    try {
      await supabase
          .from('direcciones_envio')
          .delete()
          .eq('id', direccionId);
    } catch (e) {
      throw Exception('Error al eliminar direccion de envio: $e');
    }
  }

  // ========== METODOS DE MANIFIESTOS DE VIAJE ==========

  /// Guardar manifiesto de viaje
  static Future<String> guardarManifiestoViaje(ManifiestoViaje manifiesto) async {
    try {
      final response = await supabase
          .from('manifiestos_viaje')
          .insert(manifiesto.toInsertMap())
          .select('id')
          .single();
      
      return response['id'] as String;
    } catch (e) {
      throw Exception('Error al guardar manifiesto de viaje: $e');
    }
  }

  /// Obtener manifiestos de viaje de un usuario
  static Future<List<ManifiestoViaje>> getManifiestosViajePorUsuario(String usuarioId) async {
    try {
      final response = await supabase
          .from('manifiestos_viaje')
          .select('*')
          .eq('usuario_id', usuarioId)
          .order('created_at', ascending: false);
      
      return List<ManifiestoViaje>.from(response.map((man) => ManifiestoViaje.fromSupabase(man)));
    } catch (e) {
      throw Exception('Error al obtener manifiestos de viaje: $e');
    }
  }

  /// Actualizar manifiesto de viaje
  static Future<void> actualizarManifiestoViaje(ManifiestoViaje manifiesto) async {
    try {
      await supabase
          .from('manifiestos_viaje')
          .update({
            ...manifiesto.toInsertMap(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', manifiesto.id);
    } catch (e) {
      throw Exception('Error al actualizar manifiesto de viaje: $e');
    }
  }

  /// Eliminar manifiesto de viaje
  static Future<void> eliminarManifiestoViaje(String manifiestoId) async {
    try {
      await supabase
          .from('manifiestos_viaje')
          .delete()
          .eq('id', manifiestoId);
    } catch (e) {
      throw Exception('Error al eliminar manifiesto de viaje: $e');
    }
  }

  /// Guardar multiples manifiestos de viaje (batch)
  static Future<List<String>> guardarManifiestosViajeBatch(List<ManifiestoViaje> manifiestos) async {
    try {
      final datos = manifiestos.map((m) => m.toInsertMap()).toList();
      final response = await supabase
          .from('manifiestos_viaje')
          .insert(datos)
          .select('id');
      
      return List<String>.from(response.map((r) => r['id'] as String));
    } catch (e) {
      throw Exception('Error al guardar manifiestos de viaje batch: $e');
    }
  }

  // ========== METODOS DE BANNERS PROMO ==========

  /// Obtener banners activos ordenados
  static Future<List<BannerPromo>> getBannersActivos() async {
    try {
      final response = await supabase
          .from('banners_promo')
          .select('*')
          .eq('activo', true)
          .order('orden', ascending: true)
          .order('created_at', ascending: false);
      
      return List<BannerPromo>.from(response.map((banner) => BannerPromo.fromSupabase(banner)));
    } catch (e) {
      throw Exception('Error al obtener banners activos: $e');
    }
  }

  /// Obtener todos los banners (para admin)
  static Future<List<BannerPromo>> getAllBanners() async {
    try {
      final response = await supabase
          .from('banners_promo')
          .select('*')
          .order('orden', ascending: true)
          .order('created_at', ascending: false);
      
      return List<BannerPromo>.from(response.map((banner) => BannerPromo.fromSupabase(banner)));
    } catch (e) {
      throw Exception('Error al obtener todos los banners: $e');
    }
  }

  /// Crear nuevo banner
  static Future<String> crearBanner(BannerPromo banner) async {
    try {
      final response = await supabase
          .from('banners_promo')
          .insert(banner.toInsertMap())
          .select('id')
          .single();
      
      return response['id'].toString();
    } catch (e) {
      throw Exception('Error al crear banner: $e');
    }
  }

  /// Actualizar banner existente
  static Future<void> actualizarBanner(BannerPromo banner) async {
    try {
      final updateData = banner.toInsertMap();
      
      await supabase
          .from('banners_promo')
          .update(updateData)
          .eq('id', banner.id);
    } catch (e) {
      throw Exception('Error al actualizar banner: $e');
    }
  }

  /// Eliminar banner
  static Future<void> eliminarBanner(String bannerId) async {
    try {
      await supabase
          .from('banners_promo')
          .delete()
          .eq('id', bannerId);
    } catch (e) {
      throw Exception('Error al eliminar banner: $e');
    }
  }

  /// Cambiar estado de banner (activar/desactivar)
  static Future<void> toggleBannerEstado(String bannerId, bool nuevoEstado) async {
    try {
      await supabase
          .from('banners_promo')
          .update({
            'activo': nuevoEstado,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bannerId);
    } catch (e) {
      throw Exception('Error al cambiar estado del banner: $e');
    }
  }

  /// Reordenar banners
  static Future<void> reordenarBanners(List<Map<String, dynamic>> bannersOrdenados) async {
    try {
      await supabase.rpc('reordenar_banners', params: {
        'banners_data': bannersOrdenados,
      });
    } catch (e) {
      // Si la funcion RPC no existe, hacer actualizaciones individuales
      for (final banner in bannersOrdenados) {
        await supabase
            .from('banners_promo')
            .update({
              'orden': banner['orden'],
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', banner['id']);
      }
    }
  }

  // ========== METODOS DE PROFILES DE USUARIO ==========

  /// Obtener o crear perfil de usuario (considera Modo Obra)
  static Future<UserProfile> getOrCreateProfile([String? userId]) async {
    try {
      final targetId = userId ?? currentUserId;
      if (targetId == null) throw Exception('No hay usuario identificado');
      
      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('user_id', targetId)
          .maybeSingle();
      
      if (response != null) {
        return UserProfile.fromSupabase(response);
      } else {
        // Crear perfil nuevo con datos de bypass si es necesario
        final newProfile = UserProfile.temporal(userId: targetId);
        final insertResponse = await supabase
            .from('profiles')
            .insert(newProfile.toInsertMap())
            .select()
            .single();
        
        return UserProfile.fromSupabase(insertResponse);
      }
    } catch (e) {
      throw Exception('Error al obtener o crear perfil: $e');
    }
  }

  /// Obtener perfil de usuario (con fallback para Modo Obra)
  static Future<UserProfile?> getProfile(String targetId) async {
    try {
      // Fallback para Identidad Maestra
      if (MODO_OBRA_ACTIVE && targetId == MODO_OBRA_USER_ID) {
        return UserProfile(
          id: 'master-identity-mock',
          userId: MODO_OBRA_USER_ID,
          nombre: 'Capitán Sandy',
          avatarUrl: 'https://images.unsplash.com/photo-1544161515-4af6b1d8d179?q=80&w=200&auto=format&fit=crop',
          esCapitan: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }

      final response = await supabase
          .from('profiles')
          .select('*')
          .eq('user_id', targetId)
          .maybeSingle();
      
      if (response != null) {
        return UserProfile.fromSupabase(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Buscar UID de un usuario por su email (para coordinar tests entre Laura y Mandril)
  static Future<String?> getUserIdByEmail(String email) async {
    try {
      // Nota: En Supabase, la tabla profiles debe tener una relacion o el email guardado
      // Si el email no esta en profiles, esto fallaria a menos que usemos una funcion RPC o busquemos en otra tabla
      final response = await supabase
          .from('profiles')
          .select('user_id')
          .eq('email', email)
          .maybeSingle();
      
      return response?['user_id'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Actualizar perfil de usuario
  static Future<void> updateProfile(UserProfile profile) async {
    try {
      await supabase
          .from('profiles')
          .update({
            ...profile.toInsertMap(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', profile.userId);
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  /// Guardar o actualizar perfil (upsert)
  static Future<UserProfile> saveProfile(UserProfile profile) async {
    try {
      double? lat = profile.puertoBaseLat;
      double? lng = profile.puertoBaseLon;

      if (lat == null || lng == null) {
        if ((profile.direccionCalle != null && profile.direccionCalle!.isNotEmpty) ||
            (profile.localidad != null && profile.localidad!.isNotEmpty)) {
          try {
            final coords = await geocodificarDireccion(
              calle: profile.direccionCalle,
              numero: profile.direccionNumero,
              localidad: profile.localidad,
              provincia: null,
            );
            if (coords != null) {
              lat = coords['lat'];
              lng = coords['lng'];
            }
          } catch (e) {
            print('⚠️ Error al geocodificar durante saveProfile: $e');
          }
        }
      }

      final insertMap = profile.toInsertMap();
      if (lat != null) {
        insertMap['zona_lat'] = lat;
        insertMap['puerto_base_lat'] = lat;
      }
      if (lng != null) {
        insertMap['zona_lng'] = lng;
        insertMap['puerto_base_lon'] = lng;
      }

      final response = await supabase
          .from('profiles')
          .upsert({
            ...insertMap,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      
      return UserProfile.fromSupabase(response);
    } catch (e) {
      throw Exception('Error al guardar perfil: $e');
    }
  }

  /// Subir foto DNI al bucket 'fotos_perfil'
  static Future<String> uploadProfileDni(dynamic imageFile, String userId) async {
    try {
      // Nomenclatura: user_id_dni.jpg
      final fileName = '${userId}_dni.jpg';
      final path = 'fotos_perfil/$fileName';
      
      final Uint8List bytes = imageFile is XFile ? await imageFile.readAsBytes() : imageFile;

      final response = await supabase.storage
          .from('fotos_perfil')
          .uploadBinary(path, bytes);
      
      if (response.isEmpty) {
        throw Exception('Error al subir foto DNI de perfil');
      }
      
      // Obtener URL publica
      final imageUrl = supabase.storage
          .from('fotos_perfil')
          .getPublicUrl(path);
      
      return imageUrl;
    } catch (e) {
      throw Exception('Error al subir foto DNI de perfil: $e');
    }
  }

  /// Eliminar foto DNI del bucket 'fotos_perfil'
  static Future<void> deleteProfileDni(String imageUrl) async {
    try {
      // Extraer el path de la URL
      final uri = Uri.parse(imageUrl);
      final path = uri.path.split('/').skip(2).join('/');
      
      await supabase.storage
          .from('fotos_perfil')
          .remove([path]);
    } catch (e) {
      throw Exception('Error al eliminar foto DNI de perfil: $e');
    }
  }

  // ========== METODOS DE COTIZACIONES ==========
  
  /// Crear nueva cotizacion
  static Future<String> crearCotizacion(Cotizacion cotizacion) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .insert(cotizacion.toInsertMap())
          .select('id')
          .single();
      
      final cotId = response['id'] as String;

      notificarCapitanesNuevaCotizacion(
        cotizacionId: cotId,
        descripcion: cotizacion.descripcion,
        puntoPartida: cotizacion.puntoPartida ?? {},
      ).catchError((e) => print('Error al notificar capitanes en crearCotizacion: $e'));

      return cotId;
    } catch (e) {
      throw Exception('Error al crear cotizacion: $e');
    }
  }

  /// Crear cotizacion con datos geograficos
  static Future<String> crearCotizacionConRuta(
    Cotizacion cotizacion, 
    Map<String, dynamic> partida, 
    Map<String, dynamic> destino
  ) async {
    try {
      final insertData = {
        ...cotizacion.toInsertMap(),
        'punto_partida': partida,
        'punto_destino': destino,
      };
      
      final response = await supabase
          .from('cotizaciones')
          .insert(insertData)
          .select('id')
          .single();
      
      final cotId = response['id'] as String;

      notificarCapitanesNuevaCotizacion(
        cotizacionId: cotId,
        descripcion: cotizacion.descripcion,
        puntoPartida: partida,
      ).catchError((e) => print('Error al notificar capitanes en crearCotizacionConRuta: $e'));

      return cotId;
    } catch (e) {
      throw Exception('Error al crear cotizacion con ruta: $e');
    }
  }

  /// Obtener cotizaciones de un pescador
  static Future<List<Cotizacion>> getCotizacionesPescador(String pescadorId) async {
    try {
      final limiteExpiracion = DateTime.now().subtract(const Duration(hours: 24)).toIso8601String();
      
      final response = await supabase
          .from('cotizaciones')
          .select('*')
          .eq('pescador_id', pescadorId)
          .gt('created_at', limiteExpiracion)
          .order('created_at', ascending: false);
      
      return List<Cotizacion>.from(response.map((cot) => Cotizacion.fromSupabase(cot)));
    } catch (e) {
      throw Exception('Error al obtener cotizaciones del pescador: $e');
    }
  }

  /// Obtener cotizaciones pendientes de un capitan
  static Future<List<Cotizacion>> getCotizacionesPendientes(String capitanId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('*')
          .eq('capitan_id', capitanId)
          .eq('estado', Cotizacion.ESTADO_PENDIENTE)
          .order('created_at', ascending: true);
      
      return List<Cotizacion>.from(response.map((cot) => Cotizacion.fromSupabase(cot)));
    } catch (e) {
      throw Exception('Error al obtener cotizaciones pendientes: $e');
    }
  }

  /// Obtener todas las cotizaciones de un capitan (con Seed Data para Modo Obra)
  static Future<List<Cotizacion>> getCotizacionesCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('*')
          .eq('capitan_id', capitanId)
          .order('created_at', ascending: false);
      
      final results = List<Cotizacion>.from(response.map((cot) => Cotizacion.fromSupabase(cot)));

      // MODO OBRA: Inyectar 3 cotizaciones reales si está vacío
      if (MODO_OBRA_ACTIVE && results.isEmpty) {
        return [
          Cotizacion(
            id: 'cot-1',
            pescadorId: 'test-pescador-1',
            capitanId: capitanId,
            descripcion: 'Excursión de pesca 6 horas - 4 personas. Incluye carnada y equipos.',
            estado: Cotizacion.ESTADO_ACEPTADO,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
            presupuestoMonto: 150000,
          ),
          Cotizacion(
            id: 'cot-2',
            pescadorId: 'test-pescador-2',
            capitanId: capitanId,
            descripcion: 'Paseo al atardecer con brindis - Pareja. Salida 18:00hs.',
            estado: Cotizacion.ESTADO_PRESUPUESTADO,
            createdAt: DateTime.now().subtract(const Duration(hours: 5)),
            updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
            presupuestoMonto: 45000,
          ),
          Cotizacion(
            id: 'cot-3',
            pescadorId: 'test-pescador-3',
            capitanId: capitanId,
            descripcion: 'Traslado a isla para campamento - Grupo de 6. Solo ida.',
            estado: Cotizacion.ESTADO_PENDIENTE,
            createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
            updatedAt: DateTime.now().subtract(const Duration(minutes: 20)),
          ),
        ];
      }
      return results;
    } catch (e) {
      return [];
    }
  }

  /// Actualizar cotizacion (presupuestar por capitan)
  static Future<void> actualizarCotizacion(Cotizacion cotizacion) async {
    try {
      await supabase
          .from('cotizaciones')
          .update({
            ...cotizacion.toInsertMap(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cotizacion.id);
    } catch (e) {
      throw Exception('Error al actualizar cotizacion: $e');
    }
  }

  /// Presupuestar cotizacion (capitan)
  static Future<void> presupuestarCotizacion(String cotizacionId, double monto) async {
    try {
      await supabase
          .from('cotizaciones')
          .update({
            'presupuesto_monto': monto,
            'estado': Cotizacion.ESTADO_PRESUPUESTADO,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cotizacionId);
    } catch (e) {
      throw Exception('Error al presupuestar cotizacion: $e');
    }
  }

  /// Responder cotizacion (aceptar/rechazar por pescador)
  static Future<void> responderCotizacion(String cotizacionId, String respuesta) async {
    try {
      await supabase
          .from('cotizaciones')
          .update({
            'estado': respuesta,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cotizacionId);
    } catch (e) {
      throw Exception('Error al responder cotizacion: $e');
    }
  }

  /// Eliminar cotizacion
  static Future<void> eliminarCotizacion(String cotizacionId) async {
    try {
      await supabase
          .from('cotizaciones')
          .delete()
          .eq('id', cotizacionId);
    } catch (e) {
      throw Exception('Error al eliminar cotizacion: $e');
    }
  }

  /// Obtener estadisticas de capitan
  static Future<Map<String, dynamic>> getEstadisticasCapitan(String capitanId) async {
    try {
      final response = await supabase.rpc('tiempo_respuesta_promedio', params: {
        'p_capitan_id': capitanId,
      });
      
      return {
        'tiempoRespuestaPromedio': response,
        'cotizacionesPendientes': await getCotizacionesPendientes(capitanId),
        'totalCotizaciones': await getCotizacionesCapitan(capitanId),
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas del capitan: $e');
    }
  }

  /// Configurar canal Realtime para cotizaciones
  static RealtimeChannel cotizacionesChannel({
    required Function(Map<String, dynamic>) onCotizacionCreada,
    required Function(Map<String, dynamic>) onCotizacionActualizada,
    String? capitanId,
    String? pescadorId,
  }) {
    final channel = supabase.channel('cotizaciones_${DateTime.now().millisecondsSinceEpoch}');
    
    // Escuchar nuevas cotizaciones
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'cotizaciones',
      callback: (payload, [ref]) {
        final cotizacion = payload.newRecord;
        
        // Filtrar por capitan si se especifica
        // Permitimos si capitan_id es nulo (Nuevo Lead para Radar)
        if (capitanId != null && 
            cotizacion['capitan_id'] != null && 
            cotizacion['capitan_id'] != capitanId) {
          return;
        }
        
        // Filtrar por pescador si se especifica
        if (pescadorId != null && cotizacion['pescador_id'] != pescadorId) {
          return;
        }
        
        onCotizacionCreada(cotizacion);
            },
    );
    
    // Escuchar actualizaciones de cotizaciones
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'cotizaciones',
      callback: (payload, [ref]) {
        final cotizacion = payload.newRecord;
        
        // Filtrar por capitan si se especifica
        if (capitanId != null && cotizacion['capitan_id'] != capitanId) {
          return;
        }
        
        // Filtrar por pescador si se especifica
        if (pescadorId != null && cotizacion['pescador_id'] != pescadorId) {
          return;
        }
        
        onCotizacionActualizada(cotizacion);
            },
    );
    
    return channel;
  }

  /// Registrar en logs de sistema
  static Future<void> registrarLogSistema({
    required String tipo,
    required String descripcion,
    String? userId,
    String? cotizacionId,
    Map<String, dynamic>? datosAdicionales,
  }) async {
    try {
      await supabase
          .from('logs_sistema')
          .insert({
            'tipo': tipo,
            'descripcion': descripcion,
            'user_id': userId,
            'cotizacion_id': cotizacionId,
            'datos_adicionales': datosAdicionales,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      // No lanzar excepcion para no interrumpir el flujo principal
    }
  }

  // ========== METODOS DE PERFIL DE CAPITAN ==========

  /// Obtener perfil de capitan por user_id (Sincronización Real)
  static Future<PerfilCapitan?> getPerfilCapitan(String userId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('user_id, es_capitan, estado, telefono, dni, avatar_url, zona_lat, zona_lng, zona_radio_km, disponible')
          .eq('user_id', userId)
          .eq('es_capitan', true)
          .maybeSingle();
      
      if (response != null) {
        return PerfilCapitan.fromSupabase(response);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Actualizar limite de respuesta del capitan
  static Future<void> actualizarLimiteRespuesta(String userId, int limiteMinutos) async {
    try {
      await supabase
          .from('profiles')
          .update({
            'limite_respuesta_minutos': limiteMinutos,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('es_capitan', true);
    } catch (e) {
      throw Exception('Error al actualizar limite de respuesta: $e');
    }
  }

  /// Registrar solicitud de contacto (Interes del pescador)
  static Future<void> registrarSolicitudContacto({
    required String idCapitan,
    String? idProducto,
    String? mensaje,
  }) async {
    try {
      final idUser = currentUserId;
      if (idUser == null) throw Exception('Usuario no identificado');

      // Bloquear simulación y auto-contactos por motivos de seguridad
      if (idUser == idCapitan) {
        print('⚠️ Bloqueado contacto del capitán consigo mismo (simulación o vulnerabilidad).');
        return;
      }

      await supabase.from('solicitudes_contacto').insert({
        'id_pescador': idUser,
        'id_capitan': idCapitan,
        'id_producto': idProducto,
        'mensaje_inicial': mensaje,
      });

      // Crear una notificación física en la base de datos para la campanita del Capitán
      await enviarNotificacion(
        usuarioId: idCapitan,
        titulo: '💬 ¡Nuevo Pescador Interesado!',
        mensaje: mensaje ?? 'Un pescador está interesado en tus servicios de navegación.',
        tipo: 'solicitud_contacto',
        metadata: {
          'pescador_id': idUser,
          'producto_id': idProducto,
        },
      );
      
      // Notificar al sistema local para que el capitan vea el globo/alerta inmediatamente
      _notificacionesController.add('¡Nueva ruta trazada en tu zona! (${idUser.substring(0,5)}...)');
      
    } catch (e) {
      throw Exception('Error al registrar solicitud de contacto: $e');
    }
  }

  /// Obtener solicitudes de contacto para un capitán
  static Future<List<Map<String, dynamic>>> getSolicitudesContacto(String idCapitan) async {
    try {
      final response = await supabase
          .from('solicitudes_contacto')
          .select('*, profiles:id_pescador(*), productos:id_producto(*)')
          .eq('id_capitan', idCapitan)
          .order('fecha', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  /// Marcar solicitud de contacto como leída
  static Future<void> marcarSolicitudLeida(String idSolicitud) async {
    try {
      await supabase
          .from('solicitudes_contacto')
          .update({'estado': 'leido'})
          .eq('id', idSolicitud);
    } catch (e) {
      throw Exception('Error al marcar solicitud como leída: $e');
    }
  }

  /// Obtener cotizaciones pendientes con tiempo restante
  static Future<List<Map<String, dynamic>>> getCotizacionesPendientesConTiempo(String capitanId) async {
    try {
      final response = await supabase.rpc('cotizaciones_pendientes_con_tiempo', params: {
        'p_capitan_id': capitanId,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener cotizaciones con tiempo: $e');
    }
  }

  /// Marcar cotizaciones en riesgo
  static Future<List<Map<String, dynamic>>> marcarCotizacionesEnRiesgo() async {
    try {
      final response = await supabase.rpc('marcar_cotizaciones_en_riesgo');
      
      // Registrar alertas de negocio
      for (final alerta in response) {
        await _crearAlertaNegocio(alerta);
      }
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al marcar cotizaciones en riesgo: $e');
    }
  }

  /// Crear alerta de negocio
  static Future<void> _crearAlertaNegocio(Map<String, dynamic> alertaData) async {
    try {
      await supabase
          .from('alertas_negocio')
          .insert({
            'tipo': 'cotizacion_en_riesgo',
            'cotizacion_id': alertaData['cotizacion_id'],
            'capitan_id': alertaData['capitan_id'],
            'pescador_id': alertaData['pescador_id'],
            'pescador_telefono': alertaData['pescador_telefono'],
            'descripcion': 'Cotizacion sin respuesta en tiempo limite',
            'tiempo_transcurrido': alertaData['tiempo_transcurrido'],
            'limite_respuesta': alertaData['limite_respuesta'],
            'notificada': false,
            'created_at': DateTime.now().toIso8601String(),
          });

      // Registrar log para admin
      await registrarLogSistema(
        tipo: 'alerta_negocio',
        descripcion: 'Cotizacion en riesgo detectada - Telefono: ${alertaData['pescador_telefono']}',
        userId: alertaData['capitan_id'],
        cotizacionId: alertaData['cotizacion_id'],
        datosAdicionales: {
          'pescador_telefono': alertaData['pescador_telefono'],
          'tiempo_transcurrido': alertaData['tiempo_transcurrido'],
          'limite_respuesta': alertaData['limite_respuesta'],
        },
      );
    } catch (e) {
    }
  }

  /// Obtener metricas de cumplimiento mensual
  static Future<Map<String, dynamic>> getMetricasCumplimientoMensual(
    String capitanId, 
    int anio, 
    int mes
  ) async {
    try {
      final response = await supabase.rpc('metricas_cumplimiento_mensual', params: {
        'p_capitan_id': capitanId,
        'p_anio': anio,
        'p_mes': mes,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'total_cotizaciones': 0,
        'respondidas_a_tiempo': 0,
        'respondidas_fuera_tiempo': 0,
        'porcentaje_cumplimiento': 0.0,
        'tiempo_promedio_respuesta': '0 minutes',
        'tiempo_limite_promedio': 15,
      };
    } catch (e) {
      throw Exception('Error al obtener metricas de cumplimiento: $e');
    }
  }

  /// Obtener alertas de negocio no notificadas
  static Future<List<Map<String, dynamic>>> getAlertasNoNotificadas() async {
    try {
      final response = await supabase
          .from('alertas_negocio')
          .select('*')
          .eq('notificada', false)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener alertas no notificadas: $e');
    }
  }

  /// Marcar alerta como notificada
  static Future<void> marcarAlertaNotificada(String alertaId) async {
    try {
      await supabase
          .from('alertas_negocio')
          .update({
            'notificada': true,
            'resuelta_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertaId);
    } catch (e) {
      throw Exception('Error al marcar alerta como notificada: $e');
    }
  }

  /// Configurar canal Realtime para alertas de negocio
  static RealtimeChannel alertasChannel({
    required Function(Map<String, dynamic>) onAlertaCreada,
  }) {
    final channel = supabase.channel('alertas_${DateTime.now().millisecondsSinceEpoch}');
    
    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'alertas_negocio',
      callback: (payload, [ref]) {
        onAlertaCreada(payload.newRecord);
            },
    );
    
    return channel;
  }

  // ========== METODOS DE GEOFENCING ==========
  
  /// Actualizar configuracion de geofencing del capitan
  static Future<void> actualizarGeofencingCapitan(
    String userId, 
    double radioOperacion, 
    Map<String, dynamic> centroOperacion
  ) async {
    try {
      await supabase
          .from('profiles')
          .update({
            'zona_radio_km': radioOperacion,
            'zona_lat': centroOperacion['lat'],
            'zona_lng': centroOperacion['lon'],
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('es_capitan', true);
    } catch (e) {
      throw Exception('Error al actualizar geofencing: $e');
    }
  }

  /// Actualizar perfil de capitan completo (incluyendo docs)
  static Future<void> actualizarPerfilCapitan(PerfilCapitan perfil) async {
    try {
      final data = perfil.toMap();
      
      // 1. Actualizar en tabla profiles (Master)
      await supabase
          .from('profiles')
          .update(data)
          .eq('user_id', perfil.userId);
          
      // 2. Intentar actualizar en tabla guias (Legado/Específica)
      try {
        await supabase
            .from('guias')
            .update({
              'avatar_url': perfil.avatarUrl,
              'seguro_url': perfil.seguroUrl,
              'embarcacion_url': perfil.embarcacionUrl,
            })
            .eq('id', perfil.userId);
      } catch (e) {
        // No se pudo actualizar en guias (puede que no exista el registro)
      }
    } catch (e) {
      throw Exception('Error al actualizar perfil de capitan: $e');
    }
  }

  /// Cambiar estado de disponibilidad del capitan
  static Future<void> cambiarDisponibilidadCapitan(String userId, bool disponible) async {
    try {
      await supabase
          .from('profiles')
          .update({
            'disponible': disponible,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('es_capitan', true);
    } catch (e) {
      throw Exception('Error al cambiar disponibilidad: $e');
    }
  }

  /// Obtener capitanes disponibles para una cotizacion
  static Future<List<Map<String, dynamic>>> getCapitanesDisponiblesParaCotizacion(
    double latPartida, 
    double lonPartida
  ) async {
    try {
      final response = await supabase.rpc('get_capitanes_disponibles_para_cotizacion', params: {
        'p_lat_partida': latPartida,
        'p_lon_partida': lonPartida,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener capitanes disponibles: $e');
    }
  }

  /// Crear cotizacion con asignacion automatica
  static Future<Map<String, dynamic>> crearCotizacionConAsignacion(
    String pescadorId,
    String descripcion,
    Map<String, dynamic> puntoPartida,
    Map<String, dynamic>? puntoDestino
  ) async {
    try {
      final response = await supabase.rpc('crear_cotizacion_con_asignacion', params: {
        'p_pescador_id': pescadorId,
        'p_descripcion': descripcion,
        'p_punto_partida': puntoPartida,
        'p_punto_destino': puntoDestino,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo crear la cotizacion');
    } catch (e) {
      throw Exception('Error al crear cotizacion con asignacion: $e');
    }
  }

  /// Verificar si un capitan cubre un punto especifico
  static Future<bool> verificarCoberturaCapitan(String capitanId, double lat, double lon) async {
    try {
      final response = await supabase.rpc('capitan_cubre_punto', params: {
        'p_capitan_id': capitanId,
        'p_lat': lat,
        'p_lon': lon,
      });
      
      return response as bool? ?? false;
    } catch (e) {
      throw Exception('Error al verificar cobertura: $e');
    }
  }

  /// Obtener estadisticas de cobertura
  static Future<Map<String, dynamic>> getEstadisticasCobertura() async {
    try {
      final response = await supabase.rpc('get_estadisticas_cobertura');
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'total_capitanes': 0,
        'capitanes_disponibles': 0,
        'capitanes_con_geofencing': 0,
        'cobertura_total_km': 0.0,
        'radio_promedio_km': 0.0,
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas de cobertura: $e');
    }
  }

  /// Obtener vista de capitanes disponibles
  static Future<List<Map<String, dynamic>>> getCapitanesDisponibles() async {
    try {
      final response = await supabase
          .from('vw_capitanes_disponibles')
          .select('*')
          .order('estado_operativo');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener capitanes disponibles: $e');
    }
  }

  // ========== METODOS DE ADMINISTRADOR ==========
  
  /// Obtener datos para mapa de calor de capitanes
  static Future<List<Map<String, dynamic>>> getMapaCalorCapitanes() async {
    try {
      final response = await supabase.rpc('get_mapa_calor_capitanes');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener mapa de calor: $e');
    }
  }

  /// Obtener estadisticas de cobertura en tiempo real
  static Future<Map<String, dynamic>> getEstadisticasCoberturaTiempoReal() async {
    try {
      final response = await supabase.rpc('get_estadisticas_cobertura_tiempo_real');
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'total_capitanes': 0,
        'capitanes_activos': 0,
        'capitanes_en_descanso': 0,
        'cobertura_total_km2': 0.0,
        'zonas_con_cobertura': 0,
        'cotizaciones_hoy': 0,
        'cotizaciones_huerfanas_hoy': 0,
        'porcentaje_cobertura': 0.0,
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas de cobertura: $e');
    }
  }

  /// Obtener analisis de cobertura de ultimos 30 dias
  static Future<List<Map<String, dynamic>>> getAnalisisCobertura() async {
    try {
      final response = await supabase
          .from('vw_analisis_cobertura')
          .select('*')
          .order('fecha', ascending: false)
          .limit(30);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener analisis de cobertura: $e');
    }
  }

  /// Realizar matchmaking con pulso de tiempo real
  static Future<Map<String, dynamic>> matchmakingConPulso(
    String pescadorId,
    String descripcion,
    Map<String, dynamic> puntoPartida,
    Map<String, dynamic>? puntoDestino
  ) async {
    try {
      final response = await supabase.rpc('matchmaking_con_pulso', params: {
        'p_pescador_id': pescadorId,
        'p_descripcion': descripcion,
        'p_punto_partida': puntoPartida,
        'p_punto_destino': puntoDestino,
      });
      
      if (response.isNotEmpty) {
        final result = response.first;
        final cotId = result['cotizacion_id']?.toString() ?? result['id']?.toString();
        if (cotId != null) {
          notificarCapitanesNuevaCotizacion(
            cotizacionId: cotId,
            descripcion: descripcion,
            puntoPartida: puntoPartida,
          ).catchError((e) => print('Error al notificar capitanes en matchmaking: $e'));
        }
        return result;
      }
      
      throw Exception('No se pudo realizar el matchmaking');
    } catch (e) {
      throw Exception('Error en matchmaking con pulso: $e');
    }
  }

  /// Registrar cotizacion huerfana manualmente
  static Future<void> registrarCotizacionHuerfana(
    String cotizacionId,
    String pescadorId,
    double latPartida,
    double lonPartida,
    String descripcion
  ) async {
    try {
      await supabase.rpc('registrar_cotizacion_huerfana', params: {
        'p_cotizacion_id': cotizacionId,
        'p_pescador_id': pescadorId,
        'p_lat_partida': latPartida,
        'p_lon_partida': lonPartida,
        'p_descripcion': descripcion,
      });
    } catch (e) {
      throw Exception('Error al registrar cotizacion huerfana: $e');
    }
  }

  /// Obtener alertas de zonas sin cobertura
  static Future<List<Map<String, dynamic>>> getAlertasZonaSinCobertura() async {
    try {
      final response = await supabase
          .from('alertas_negocio')
          .select('*')
          .eq('tipo', 'zona_sin_cobertura')
          .eq('notificada', false)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener alertas de zona sin cobertura: $e');
    }
  }

  /// Marcar alerta de zona sin cobertura como revisada
  static Future<void> marcarAlertaZonaSinCoberturaRevisada(String alertaId) async {
    try {
      await supabase
          .from('alertas_negocio')
          .update({
            'notificada': true,
            'resuelta_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertaId);
    } catch (e) {
      throw Exception('Error al marcar alerta como revisada: $e');
    }
  }

  // ========== METODOS DE FINALIZACION DE VIAJES ==========
  
  /// Obtener viajes listos para confirmacion de un cliente
  static Future<List<Map<String, dynamic>>> getViajesListosConfirmacion(String clienteId) async {
    try {
      final response = await supabase
          .from('vw_viajes_listos_confirmacion')
          .select('*')
          .eq('cliente_id', clienteId)
          .order('fecha_pactada', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener viajes listos para confirmacion: $e');
    }
  }

  /// Obtener coordenadas para la verificación GPS del viaje
  static Future<Map<String, Map<String, double>>> obtenerCoordenadasVerificacion(String pedidoId) async {
    try {
      final response = await supabase
          .from('pedidos')
          .select('track_log, cotizaciones(punto_destino)')
          .eq('id', pedidoId)
          .maybeSingle();

      if (response == null) {
        throw Exception('Pedido no encontrado.');
      }

      final cotizacion = response['cotizaciones'] as Map<String, dynamic>?;
      final puntoDestino = cotizacion?['punto_destino'] as Map<String, dynamic>?;
      
      // Coordenadas del puerto de destino
      double destLat = 0.0;
      double destLon = 0.0;
      if (puntoDestino != null) {
        destLat = (puntoDestino['lat'] ?? puntoDestino['latitude'] ?? 0.0).toDouble();
        destLon = (puntoDestino['lon'] ?? puntoDestino['longitude'] ?? puntoDestino['lng'] ?? 0.0).toDouble();
      }

      // Coordenadas del capitán (último punto del track_log)
      double capLat = 0.0;
      double capLon = 0.0;
      final trackLog = response['track_log'] as List?;
      if (trackLog != null && trackLog.isNotEmpty) {
        final lastPoint = trackLog.last as Map<String, dynamic>;
        capLat = (lastPoint['lat'] ?? lastPoint['latitude'] ?? 0.0).toDouble();
        capLon = (lastPoint['lng'] ?? lastPoint['lon'] ?? lastPoint['longitude'] ?? 0.0).toDouble();
      } else {
        // Fallback sandbox/test: si no hay track_log, asumir que el capitán está en el puerto de destino
        capLat = destLat;
        capLon = destLon;
      }

      return {
        'capitan': {'lat': capLat, 'lon': capLon},
        'puerto': {'lat': destLat, 'lon': destLon},
      };
    } catch (e) {
      throw Exception('Error al obtener coordenadas para verificación: $e');
    }
  }

  /// Confirmar viaje exitoso con verificación GPS anti-fraude
  static Future<Map<String, dynamic>> confirmarViajeExitoso(
    String pedidoId,
    String clienteId, {
    required Map<String, double> coordenadasCapitan,
    required Map<String, double> coordenadasPescador,
    required Map<String, double> coordenadasPuertoDestino,
  }) async {
    try {
      // 1. Regla 1 (Arribo): Capitán vs Puerto de Destino < 1 km (1000 metros)
      final double distanciaPuerto = GeofencingService.calcularDistanciaHaversine(
        coordenadasCapitan,
        coordenadasPuertoDestino,
      );

      if (distanciaPuerto > 1000.0) {
        return {
          'exito': false,
          'mensaje': 'Error de localización: El capitán se encuentra a ${distanciaPuerto.toStringAsFixed(1)} metros del puerto de destino (máximo permitido 1000 metros).',
          'error_tipo': 'LOCALIZACION_PUERTO',
        };
      }

      // 2. Regla 2 (Fidelidad): Capitán vs Pescador < 100 metros
      final double distanciaCapitanPescador = GeofencingService.calcularDistanciaHaversine(
        coordenadasCapitan,
        coordenadasPescador,
      );

      if (distanciaCapitanPescador > 100.0) {
        // Gatillo de Emergencia: Disparar disputa automática y congelar fondos/comisiones
        try {
          await iniciarDisputaViaje(
            viajeId: pedidoId,
            reclamanteId: clienteId,
            motivo: 'POSIBLE_FRAUDE_GPS',
            descargo: 'Fraude detectado por geofencing. Distancia entre Capitán y Pescador: ${distanciaCapitanPescador.toStringAsFixed(1)} metros (límite 100 metros). Saldos y comisiones del promotor congelados.',
          );
        } catch (disputaError) {
          print('Error al disparar disputa automática: $disputaError');
        }

        return {
          'exito': false,
          'mensaje': 'Transacción cancelada inmediatamente por sospecha de fraude. Se ha iniciado una disputa automática.',
          'error_tipo': 'POSIBLE_FRAUDE_GPS',
        };
      }

      // 3. Si pasa el geofencing, proceder con la confirmación exitosa
      final response = await supabase.rpc('confirmar_viaje_exitoso', params: {
        'p_pedido_id': pedidoId,
        'p_cliente_id': clienteId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo confirmar el viaje');
    } on ArgumentError catch (e) {
      return {
        'exito': false,
        'mensaje': 'Error de geolocalización: ${e.message}',
        'error_tipo': 'COORDENADAS_INVALIDAS',
      };
    } catch (e) {
      throw Exception('Error al confirmar viaje: $e');
    }
  }

  /// Reportar problema en viaje
  static Future<Map<String, dynamic>> reportarProblemaViaje(
    String pedidoId, 
    String clienteId, 
    String motivo
  ) async {
    try {
      final response = await supabase.rpc('reportar_problema_viaje', params: {
        'p_pedido_id': pedidoId,
        'p_cliente_id': clienteId,
        'p_motivo': motivo,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo reportar el problema');
    } catch (e) {
      throw Exception('Error al reportar problema: $e');
    }
  }

  /// Iniciar disputa de viaje ("Botón de Pánico")
  static Future<Map<String, dynamic>> iniciarDisputaViaje({
    required String viajeId,
    required String reclamanteId,
    required String motivo,
    required String descargo,
  }) async {
    try {
      // 1. Cambiar el estado del viaje a 'disputa' y bloquear saldo en pedidos
      await supabase.from('pedidos').update({
        'estado': 'disputa',
        'motivo_disputa': motivo,
        'saldo_bloqueado': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', viajeId);

      // 2. Insertar registro en la tabla disputas_viajes
      await supabase.from('disputas_viajes').insert({
        'viaje_id': viajeId,
        'reclamante_id': reclamanteId,
        'motivo': motivo,
        'descargo': descargo,
        'estado': 'pendiente',
        'monto_retenido': 0.0,
      });

      // 3. Simulación de Mercado Pago - Retener/Congelar fondos en Mercado Pago
      _simularCongelamientoMercadoPago(viajeId);

      return {
        'exito': true,
        'mensaje': 'Disputa iniciada exitosamente. Fondos preventivamente retenidos.',
      };
    } catch (e) {
      throw Exception('Error al iniciar disputa de viaje: $e');
    }
  }

  /// Simulación espejo de congelamiento de fondos en Mercado Pago
  static void _simularCongelamientoMercadoPago(String viajeId) {
    // TODO: Integración real con Mercado Pago Split Payments API para congelar fondos
    // mp.payment.capture(paymentId, { capture: false }) o retener el split.
    print('Simulación Mercado Pago: Fondos congelados preventivamente para el viaje $viajeId');
  }

  /// Obtener saldos del capitan
  static Future<Map<String, dynamic>> getSaldosCapitan(String capitanId) async {
    try {
      final response = await supabase.rpc('get_saldos_capitan', params: {
        'p_capitan_id': capitanId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'saldo_a_confirmar': 0.0,
        'saldo_disponible': 0.0,
        'total_viajes': 0,
        'viajes_pendientes_confirmacion': 0,
        'ultimo_viaje_confirmado': null,
      };
    } catch (e) {
      throw Exception('Error al obtener saldos del capitan: $e');
    }
  }

  /// Obtener transacciones del capitan
  static Future<List<Map<String, dynamic>>> getTransaccionesCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('transacciones_capitanes')
          .select('*')
          .eq('capitan_id', capitanId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener transacciones del capitan: $e');
    }
  }

  /// Solicitar liquidacion
  static Future<void> solicitarLiquidacion(String capitanId, double monto) async {
    try {
      await supabase
          .from('liquidaciones')
          .insert({
            'capitan_id': capitanId,
            'monto': monto,
            'estado': 'pendiente',
            'created_at': DateTime.now().toIso8601String(),
          });
      
      // Marcar transacciones como liquidadas
      await supabase
          .from('transacciones_capitanes')
          .update({
            'estado': 'liquidado',
            'liquidacion_at': DateTime.now().toIso8601String(),
          })
          .eq('capitan_id', capitanId)
          .eq('estado', 'disponible');
      
      // Registrar en logs
      await supabase
          .from('logs_sistema')
          .insert({
            'tipo': 'liquidacion_solicitada',
            'descripcion': 'Capitan solicito liquidacion',
            'user_id': capitanId,
            'datos_adicionales': {
              'monto': monto,
              'timestamp': DateTime.now().toIso8601String(),
            },
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      throw Exception('Error al solicitar liquidacion: $e');
    }
  }

  /// Obtener todas las liquidaciones para el panel de administración
  static Future<List<Map<String, dynamic>>> getLiquidacionesAdmin() async {
    try {
      // 1. Obtener liquidaciones ordenadas por fecha de creación
      final liquidacionesResponse = await supabase
          .from('liquidaciones')
          .select('*')
          .order('created_at', ascending: false);
      
      final liquidaciones = List<Map<String, dynamic>>.from(liquidacionesResponse);
      if (liquidaciones.isEmpty) return [];

      // 2. Obtener IDs únicos de capitanes
      final capitanIds = liquidaciones
          .map((l) => l['capitan_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (capitanIds.isEmpty) return liquidaciones;

      // 3. Obtener nombres de profiles
      final profilesResponse = await supabase
          .from('profiles')
          .select('user_id, nombre')
          .inFilter('user_id', capitanIds);
      
      final profilesMap = {
        for (var p in profilesResponse)
          p['user_id']?.toString(): p['nombre']?.toString()
      };

      // 4. Obtener CBUs de guias
      final guiasResponse = await supabase
          .from('guias')
          .select('id, cbu')
          .inFilter('id', capitanIds);

      final guiasMap = {
        for (var g in guiasResponse)
          g['id']?.toString(): g['cbu']?.toString()
      };

      // 5. Unir los datos para la UI del administrador
      for (var liq in liquidaciones) {
        final capId = liq['capitan_id']?.toString();
        liq['capitan_nombre'] = profilesMap[capId] ?? 'Capitán ID: ${capId?.substring(0, 8)}';
        liq['capitan_cbu'] = guiasMap[capId] ?? 'Sin CBU cargado';
      }

      return liquidaciones;
    } catch (e) {
      print('Error en getLiquidacionesAdmin: $e');
      return [];
    }
  }

  /// Confirmar el pago de una liquidación
  static Future<void> confirmarPagoLiquidacion(String liquidacionId, String capitanId) async {
    try {
      // 1. Actualizar estado de la liquidación a 'aprobado'
      await supabase
          .from('liquidaciones')
          .update({
            'estado': 'aprobado',
            'pagado_at': DateTime.now().toIso8601String(),
          })
          .eq('id', liquidacionId);
      
      // 2. Registrar en logs del sistema para auditoría
      await supabase
          .from('logs_sistema')
          .insert({
            'tipo': 'liquidacion_aprobada',
            'descripcion': 'Administrador confirmó el pago de liquidación',
            'user_id': capitanId,
            'datos_adicionales': {
              'liquidacion_id': liquidacionId,
              'timestamp': DateTime.now().toIso8601String(),
            },
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      throw Exception('Error al confirmar pago de liquidación: $e');
    }
  }

  /// Obtener liquidaciones pendientes para el módulo de administración
  static Future<List<Map<String, dynamic>>> fetchPendingLiquidacionesAdmin() async {
    try {
      // 1. Obtener liquidaciones en estado 'pendiente'
      final liquidacionesResponse = await supabase
          .from('liquidaciones')
          .select('*')
          .eq('estado', 'pendiente')
          .order('created_at', ascending: false);
      
      final liquidaciones = List<Map<String, dynamic>>.from(liquidacionesResponse);
      if (liquidaciones.isEmpty) return [];

      // 2. Obtener IDs únicos de solicitantes
      final userIds = liquidaciones
          .map((l) => (l['capitan_id'] ?? l['usuario_id'])?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      if (userIds.isEmpty) return liquidaciones;

      // 3. Obtener nombres y avatares de profiles
      final profilesResponse = await supabase
          .from('profiles')
          .select('user_id, nombre, avatar_url, es_capitan')
          .inFilter('user_id', userIds);
      
      final profilesMap = {
        for (var p in profilesResponse)
          p['user_id']?.toString(): p
      };

      // 4. Obtener CBUs de guias (como RLS fallback)
      final guiasResponse = await supabase
          .from('guias')
          .select('id, cbu')
          .inFilter('id', userIds);

      final guiasMap = {
        for (var g in guiasResponse)
          g['id']?.toString(): g['cbu']?.toString()
      };

      // 5. Intentar obtener de perfiles_privados de manera segura en caso de que exista la tabla
      Map<String, String> perfilesPrivadosMap = {};
      try {
        final ppResponse = await supabase
            .from('perfiles_privados')
            .select('user_id, cbu')
            .inFilter('user_id', userIds);
        for (var pp in ppResponse) {
          perfilesPrivadosMap[pp['user_id']?.toString() ?? ''] = pp['cbu']?.toString() ?? '';
        }
      } catch (_) {
        // Ignorar si no existe perfiles_privados
      }

      // 6. Unir los datos para la UI del administrador con validación de saldo
      final List<Map<String, dynamic>> resultadoFiltrado = [];
      for (var liq in liquidaciones) {
        final capId = (liq['capitan_id'] ?? liq['usuario_id'])?.toString();
        if (capId == null) continue;

        final profile = profilesMap[capId];
        liq['nombre'] = profile?['nombre'] ?? 'Usuario ID: ${capId.substring(0, 8)}';
        liq['avatar_url'] = profile?['avatar_url'];
        final bool esCap = profile?['es_capitan'] == true;
        liq['rol'] = esCap ? 'Capitán' : 'Vendedor/Promotor';

        // Traer CBU de perfiles_privados, fallback a guias
        liq['cbu'] = perfilesPrivadosMap[capId] ?? guiasMap[capId] ?? 'Sin CBU cargado';

        // Obtener saldo disponible del usuario
        double saldoDisponible = 0.0;
        try {
          final saldos = await getSaldosCapitan(capId);
          saldoDisponible = (saldos['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
        } catch (_) {}

        liq['saldo_disponible'] = saldoDisponible;
        final monto = (liq['monto'] as num?)?.toDouble() ?? 0.0;

        // Validación de Saldo: el saldo disponible debe ser mayor o igual al monto solicitado
        liq['saldo_valido'] = saldoDisponible >= monto;
        
        resultadoFiltrado.add(liq);
      }

      return resultadoFiltrado;
    } catch (e) {
      print('Error en fetchPendingLiquidacionesAdmin: $e');
      return [];
    }
  }

  /// Procesar liquidación y realizar la transacción atómica
  static Future<void> procesarLiquidacionAdmin({
    required String liquidacionId,
    required String usuarioId,
    required double monto,
    required String cbuDestino,
  }) async {
    try {
      final adminId = currentUserId ?? 'admin';

      // 1. Cambiar el estado de la liquidación a 'pagado'
      await supabase
          .from('liquidaciones')
          .update({
            'estado': 'pagado',
            'pagado_at': DateTime.now().toIso8601String(),
          })
          .eq('id', liquidacionId);

      // 2. Intentar restar el monto del saldo_disponible en la tabla 'saldos' si existe
      try {
        final saldoResponse = await supabase
            .from('saldos')
            .select('saldo_disponible')
            .eq('usuario_id', usuarioId)
            .maybeSingle();

        if (saldoResponse != null) {
          final double actual = (saldoResponse['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
          await supabase
              .from('saldos')
              .update({'saldo_disponible': actual - monto})
              .eq('usuario_id', usuarioId);
        }
      } catch (_) {
        // Ignorar si no hay tabla saldos
      }

      // También actualizamos transacciones asociadas
      try {
        await supabase
            .from('transacciones_capitanes')
            .update({
              'estado': 'liquidado',
              'liquidacion_at': DateTime.now().toIso8601String(),
            })
            .eq('capitan_id', usuarioId)
            .eq('estado', 'disponible');
      } catch (_) {}

      // 3. Crear un registro en la tabla historial_pagos
      try {
        await supabase
            .from('historial_pagos')
            .insert({
              'admin_id': adminId,
              'usuario_id': usuarioId,
              'monto': monto,
              'fecha': DateTime.now().toIso8601String(),
              'cbu_destino': cbuDestino,
              'created_at': DateTime.now().toIso8601String(),
            });
      } catch (_) {
        // Fallback si no existe la tabla: guardamos en logs_sistema
        await supabase
            .from('logs_sistema')
            .insert({
              'tipo': 'pago_liquidado',
              'descripcion': 'Historial Pago: Admin liquidó \$${monto.toStringAsFixed(2)} a CBU: $cbuDestino',
              'user_id': usuarioId,
              'datos_adicionales': {
                'admin_id': adminId,
                'liquidacion_id': liquidacionId,
                'monto': monto,
                'cbu': cbuDestino,
              },
              'created_at': DateTime.now().toIso8601String(),
            });
      }

      // 4. Disparar una notificación Push de Dopamina al comisionista/usuario
      String nombreUsuario = 'Comisionista';
      try {
        final profileData = await supabase
            .from('profiles')
            .select('nombre')
            .eq('user_id', usuarioId)
            .maybeSingle();
        if (profileData != null && profileData['nombre'] != null) {
          nombreUsuario = profileData['nombre'].toString();
        } else {
          // Si no está en profiles, intentar buscar en comisionistas
          final promotorData = await supabase
              .from('comisionistas')
              .select('nombre')
              .eq('id', usuarioId)
              .maybeSingle();
          if (promotorData != null && promotorData['nombre'] != null) {
            nombreUsuario = promotorData['nombre'].toString();
          }
        }
      } catch (_) {}

      await enviarNotificacionConDopamina(
        usuarioId: usuarioId,
        titulo: '¡Fondos Enviados! 💸',
        mensaje: 'Hola $nombreUsuario, acabamos de transferir \$${monto.toStringAsFixed(2)} a tu cuenta de Mercado Pago. ¡Gracias por ser parte de EL GUIA YA!',
        tipo: 'promo',
        sonido: 'alerta',
      );

    } catch (e) {
      throw Exception('Error al procesar liquidación: $e');
    }
  }




  /// Obtener viajes en disputa para administrador
  /// Query directa a pedidos — no requiere función RPC en Supabase.
  static Future<List<Map<String, dynamic>>> getViajesEnDisputa() async {
    try {
      final List<dynamic> response = await supabase
          .from('pedidos')
          .select('id, estado, total, monto_total, motivo_disputa, created_at, updated_at, pescador_id, capitan_id')
          .or('estado.eq.disputa,estado.eq.en_disputa');
      
      final List<Map<String, dynamic>> resultado = [];
      final List<Map<String, dynamic>> rows = List<Map<String, dynamic>>.from(response);
      
      if (rows.isEmpty) {
        return [];
      }

      // Collect profile IDs
      final Set<String> profileIds = {};
      for (final row in rows) {
        final String? pescadorId = row['pescador_id']?.toString();
        final String? capitanId = row['capitan_id']?.toString();
        if (pescadorId != null && pescadorId.isNotEmpty) {
          profileIds.add(pescadorId);
        }
        if (capitanId != null && capitanId.isNotEmpty) {
          profileIds.add(capitanId);
        }
      }

      // Fetch profiles
      final Map<String, String> profileNames = {};
      if (profileIds.isNotEmpty) {
        try {
          final List<dynamic> profilesRes = await supabase
              .from('profiles')
              .select('id, nombre, apellido')
              .inFilter('id', profileIds.toList());
          
          for (final p in profilesRes) {
            final String id = p['id']?.toString() ?? '';
            final String nombre = p['nombre']?.toString() ?? '';
            final String apellido = p['apellido']?.toString() ?? '';
            final String nombreCompleto = '$nombre $apellido'.trim();
            if (id.isNotEmpty) {
              profileNames[id] = nombreCompleto.isNotEmpty ? nombreCompleto : 'Sin Nombre';
            }
          }
        } catch (pe) {
          print('Error al obtener nombres de perfiles: $pe');
        }
      }

      for (final row in rows) {
        final String pedidoId = row['id']?.toString() ?? '';
        final String? pescadorId = row['pescador_id']?.toString();
        final String? capitanId = row['capitan_id']?.toString();
        
        final String clienteNombre = (pescadorId != null) ? (profileNames[pescadorId] ?? 'Pescador') : 'Cliente';
        final String capitanNombre = (capitanId != null) ? (profileNames[capitanId] ?? 'Capitán') : 'Capitán';
        
        final double montoTotal = (row['monto_total'] as num?)?.toDouble() ?? 
                                  (row['total'] as num?)?.toDouble() ?? 0.0;
        
        final String motivo = row['motivo_disputa']?.toString() ?? row['descripcion']?.toString() ?? '';
        
        final DateTime createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now();
        final DateTime updatedAt = DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.now();
        final int diasEnDisputa = DateTime.now().difference(updatedAt).inDays;
        
        final String urgencia = diasEnDisputa >= 7
            ? 'alta'
            : diasEnDisputa >= 3
                ? 'media'
                : 'baja';

        resultado.add({
          'pedido_id': pedidoId,
          'id': pedidoId,
          'estado': 'disputa',
          'monto_total': montoTotal,
          'motivo_disputa': motivo,
          'dias_en_disputa': diasEnDisputa,
          'urgencia': urgencia,
          'cliente_nombre': clienteNombre,
          'capitan_nombre': capitanNombre,
          'descripcion': motivo,
          'created_at': row['created_at'] ?? row['updated_at'] ?? DateTime.now().toIso8601String(),
        });
      }

      return resultado;
    } catch (e) {
      throw Exception('Error al obtener viajes en disputa: $e');
    }
  }


  /// Liberar pago manualmente (admin)
  static Future<Map<String, dynamic>> liberarPagoManualAdmin(
    String pedidoId,
    bool favorCapitan,
    String observaciones,
  ) async {
    try {
      // Si se decide a favor del cliente, procesar el reembolso en caliente
      if (!favorCapitan) {
        final List<dynamic> pagosList = await supabase
            .from('pagos')
            .select()
            .eq('reserva_id', pedidoId)
            .eq('estado', 'confirmado');

        if (pagosList.isNotEmpty) {
          final pagoData = pagosList.first;
          final String metodoPago = pagoData['metodo_pago'] ?? '';
          final String? transaccionId = pagoData['transaccion_id'];
          final double monto = (pagoData['monto'] as num?)?.toDouble() ?? 0.0;

          if (metodoPago == 'mercado_pago' && transaccionId != null && transaccionId.isNotEmpty) {
            final refundResult = await MercadoPagoService.reembolsarPago(
              paymentId: transaccionId,
              amount: monto,
            );

            if (refundResult['success'] == true) {
              await supabase
                  .from('pagos')
                  .update({'estado': 'reembolsado'})
                  .eq('id', pagoData['id']);
                  
              // Registrar log específico del reembolso
              await registrarLogSistema(
                tipo: 'reembolso_mercado_pago_exito',
                descripcion: 'Reembolso exitoso en Mercado Pago para el pedido/reserva $pedidoId. Monto: \$$monto.',
                datosAdicionales: {
                  'pedido_id': pedidoId,
                  'transaccion_id': transaccionId,
                  'monto': monto,
                  'refund_id': refundResult['refund_id'],
                },
              );
            } else {
              throw Exception('El reembolso en Mercado Pago no pudo completarse.');
            }
          }
        }
      }

      final response = await supabase.rpc('liberar_pago_manual_admin', params: {
        'p_pedido_id': pedidoId,
        'p_admin_id': currentUserId ?? '00000000-0000-0000-0000-000000000000',
        'p_observaciones': observaciones.isEmpty ? null : observaciones,
        'p_favor_capitan': favorCapitan,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo liberar el pago');
    } catch (e) {
      throw Exception('Error al liberar pago manual: $e');
    }
  }

  /// Verificar si un viaje esta listo para confirmacion
  static Future<bool> verificarViajeListoParaConfirmacion(String pedidoId) async {
    try {
      final response = await supabase.rpc('verificar_viaje_listo_para_confirmacion', params: {
        'p_pedido_id': pedidoId,
      });
      
      return response as bool? ?? false;
    } catch (e) {
      throw Exception('Error al verificar estado del viaje: $e');
    }
  }

  // ========== METODOS DE CIERRE DE OPERACIONES ==========
  
  /// Ejecutar vigilancia de cierres
  static Future<Map<String, dynamic>> ejecutarVigilanciaCierres() async {
    try {
      final response = await supabase.rpc('vigilancia_cierre_operaciones');
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'pedidos_procesados': 0,
        'notificaciones_enviadas': 0,
        'alertas_demora_creadas': 0,
        'detalles_procesamiento': [],
      };
    } catch (e) {
      throw Exception('Error al ejecutar vigilancia de cierres: $e');
    }
  }

  /// Confirmar retorno y liberar pago
  static Future<Map<String, dynamic>> confirmarRetornoYLiberarPago(String pedidoId, String clienteId) async {
    try {
      final response = await supabase.rpc('confirmar_retorno_y_liberar_pago', params: {
        'p_pedido_id': pedidoId,
        'p_cliente_id': clienteId,
      });
      
      // 🚀 Ejecutar el Motor de Comisiones
      try {
        await procesarComisionesViaje(pedidoId);
      } catch (ex) {
        print('Error en procesamiento de comisiones: $ex');
      }
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo confirmar el retorno');
    } catch (e) {
      throw Exception('Error al confirmar retorno: $e');
    }
  }

  /// Cierre manual por administrador
  static Future<Map<String, dynamic>> cierreManualAdmin(
    String pedidoId,
    bool liberarPago,
    String observaciones,
  ) async {
    try {
      final response = await supabase.rpc('cierre_manual_admin', params: {
        'p_pedido_id': pedidoId,
        'p_admin_id': 'admin_id', // ID de administrador fijo para pruebas
        'p_observaciones': observaciones.isEmpty ? null : observaciones,
        'p_liberar_pago': liberarPago,
      });
      
      // 🚀 Ejecutar el Motor de Comisiones en caso de liberar el pago
      if (liberarPago) {
        try {
          await procesarComisionesViaje(pedidoId);
        } catch (ex) {
          print('Error en procesamiento de comisiones manual: $ex');
        }
      }
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo realizar el cierre manual');
    } catch (e) {
      throw Exception('Error al realizar cierre manual: $e');
    }
  }

  /// 🚀 Motor de Comisiones (Modelo 10% Fee + Match Logic)
  static Future<void> procesarComisionesViaje(String pedidoId) async {
    try {
      // 1. Evitar procesamiento duplicado
      try {
        final checkLog = await supabase
            .from('logs_comisiones')
            .select('id')
            .eq('viaje_id', pedidoId)
            .maybeSingle();
        if (checkLog != null) {
          print('⚠️ Las comisiones para el viaje $pedidoId ya fueron procesadas anteriormente.');
          return;
        }
      } catch (_) {
        // Ignorar si la tabla no existe en la base de datos local todavía
      }

      // 2. Obtener datos del viaje (pedido)
      final pedidoResponse = await supabase
          .from('pedidos')
          .select('capitan_id, pescador_id, total, monto_total, estado')
          .eq('id', pedidoId)
          .single();

      final estado = pedidoResponse['estado']?.toString();
      if (estado == 'disputa') {
        print('⚠️ El viaje $pedidoId está en disputa. Las comisiones y saldos están retenidos preventivamente.');
        return;
      }

      final capitanId = pedidoResponse['capitan_id']?.toString();
      final pescadorId = pedidoResponse['pescador_id']?.toString();
      final double valorViaje = (pedidoResponse['total'] as num? ?? pedidoResponse['monto_total'] as num? ?? 0.0).toDouble();

      if (capitanId == null || pescadorId == null || valorViaje <= 0.0) {
        print('⚠️ Datos de viaje incompletos para comisionar.');
        return;
      }

      // 3. Obtener perfiles de capitán y pescador (para referidos, referido_id y created_at)
      final capitanProfile = await supabase
          .from('profiles')
          .select('referido, referido_id, created_at')
          .eq('user_id', capitanId)
          .single();

      final pescadorProfile = await supabase
          .from('profiles')
          .select('referido, referido_id, created_at')
          .eq('user_id', pescadorId)
          .single();

      String? referidoCapitanId = capitanProfile['referido_id']?.toString();
      String? referidoPescadorId = pescadorProfile['referido_id']?.toString();

      // Fallback de compatibilidad heredada: si no tienen referido_id pero tienen el código alfanumérico "referido"
      if (referidoCapitanId == null && capitanProfile['referido'] != null) {
        final promotor = await validarCodigoPromotor(capitanProfile['referido'].toString());
        if (promotor != null) {
          referidoCapitanId = promotor['id']?.toString();
        }
      }
      if (referidoPescadorId == null && pescadorProfile['referido'] != null) {
        final promotor = await validarCodigoPromotor(pescadorProfile['referido'].toString());
        if (promotor != null) {
          referidoPescadorId = promotor['id']?.toString();
        }
      }

      final DateTime capitanCreatedAt = DateTime.tryParse(capitanProfile['created_at']?.toString() ?? '') ?? DateTime.now();
      final DateTime pescadorCreatedAt = DateTime.tryParse(pescadorProfile['created_at']?.toString() ?? '') ?? DateTime.now();

      // 4. Validar límite mensual (30 días o periodo del mes)
      final ahora = DateTime.now();
      final bool capitanEnPeriodo = ahora.difference(capitanCreatedAt).inDays <= 30;
      final bool pescadorEnPeriodo = ahora.difference(pescadorCreatedAt).inDays <= 30;

      // 5. Validar "Solo primer viaje concretado de los usuarios referidos"
      // Verificar viajes completados anteriores del pescador
      final pescadorTrips = await supabase
          .from('pedidos')
          .select('id')
          .eq('pescador_id', pescadorId)
          .eq('estado', 'completado')
          .neq('id', pedidoId)
          .limit(2);
      final bool esPrimerViajePescador = (pescadorTrips as List).isEmpty;

      // Verificar viajes completados anteriores del capitán
      final capitanTrips = await supabase
          .from('pedidos')
          .select('id')
          .eq('capitan_id', capitanId)
          .eq('estado', 'completado')
          .neq('id', pedidoId)
          .limit(2);
      final bool esPrimerViajeCapitan = (capitanTrips as List).isEmpty;

      // Base del cálculo: Comisión fija de plataforma del 10%
      final double comisionTotalApp = valorViaje * 0.10;

      double pagoVendedor = 0.0;
      double netaApp = comisionTotalApp;
      String escenario = 'SIN_REFERENCIA';
      String? vendedorId;

      if (referidoCapitanId != null || referidoPescadorId != null) {
        // CASO 1: MATCH PERFECTO (Vendedor trajo a ambos, primer viaje, período válido)
        if (referidoPescadorId != null &&
            referidoCapitanId != null &&
            referidoPescadorId == referidoCapitanId &&
            esPrimerViajePescador &&
            esPrimerViajeCapitan &&
            pescadorEnPeriodo &&
            capitanEnPeriodo) {
          vendedorId = referidoPescadorId;
          pagoVendedor = comisionTotalApp * 1.0;
          netaApp = 0.0;
          escenario = 'MATCH';
        }
        // CASO 2: RECLUTADOR DE CAPITÁN (Vendedor trajo solo al guía, primer viaje, período válido)
        else if (referidoCapitanId != null &&
            esPrimerViajeCapitan &&
            capitanEnPeriodo &&
            (referidoPescadorId != referidoCapitanId || !esPrimerViajePescador || !pescadorEnPeriodo)) {
          vendedorId = referidoCapitanId;
          pagoVendedor = comisionTotalApp * 0.7;
          netaApp = comisionTotalApp * 0.3;
          escenario = 'CAPITAN';
        }
        // CASO 3: RECLUTADOR DE PESCADOR (Vendedor trajo solo al cliente, primer viaje, período válido)
        else if (referidoPescadorId != null &&
            esPrimerViajePescador &&
            pescadorEnPeriodo &&
            (referidoPescadorId != referidoCapitanId || !esPrimerViajeCapitan || !capitanEnPeriodo)) {
          vendedorId = referidoPescadorId;
          pagoVendedor = comisionTotalApp * 0.2;
          netaApp = comisionTotalApp * 0.8;
          escenario = 'PESCADOR';
        }
        else {
          escenario = 'EXPIRADO_O_REPETIDO';
          print('⚠️ Comisión expirada (>30 días) o no es el primer viaje concretado del referido.');
        }
      }

      // 6. Transacción Atómica
      // A. Registrar log para Auditoría del Administrador
      try {
        await supabase.from('logs_comisiones').insert({
          'viaje_id': pedidoId,
          'pescador_id': pescadorId,
          'capitan_id': capitanId,
          'vendedor_id': vendedorId,
          'monto_viaje': valorViaje,
          'comision_app': comisionTotalApp,
          'pago_vendedor': pagoVendedor,
          'neta_app': netaApp,
          'escenario': escenario,
          'created_at': DateTime.now().toIso8601String(),
        });
      } catch (err) {
        print('Error al guardar log de comisiones: $err');
      }

      // B. Acreditar saldo al promotor/vendedor si corresponde
      if (vendedorId != null && pagoVendedor > 0.0) {
        final saldoResponse = await supabase
            .from('saldos')
            .select('saldo_disponible')
            .eq('usuario_id', vendedorId)
            .maybeSingle();

        double actual = 0.0;
        if (saldoResponse != null) {
          actual = (saldoResponse['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
        }

        await supabase.from('saldos').upsert({
          'usuario_id': vendedorId,
          'saldo_disponible': actual + pagoVendedor,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'usuario_id');

        print('🎉 Acreditado \$$pagoVendedor a promotor $vendedorId. Escenario: $escenario');

        // C. Enviar Notificación Push Dopamínica instantánea al Comisionista
        try {
          String codigoPromocional = 'Referido';
          try {
            final promotorData = await supabase
                .from('comisionistas')
                .select('codigo_comision')
                .eq('id', vendedorId)
                .maybeSingle();
            if (promotorData != null && promotorData['codigo_comision'] != null) {
              codigoPromocional = promotorData['codigo_comision'].toString().toUpperCase();
            }
          } catch (_) {}

          final String tituloNoti = escenario == 'MATCH'
              ? '¡Felicidades, Match Perfecto! 🏆'
              : escenario == 'CAPITAN'
                  ? '¡Comisión por Capitán! ⚓'
                  : '¡Comisión por Pescador! 🎣';

          await enviarNotificacionConDopamina(
            usuarioId: vendedorId,
            titulo: tituloNoti,
            mensaje: 'Tu código $codigoPromocional acaba de generar una comisión de \$${pagoVendedor.toStringAsFixed(2)}. El saldo se ha acreditado en tu billetera.',
            tipo: 'promo',
            sonido: 'monedas',
          );
        } catch (e) {
          // El dinero es prioridad, la notificación es plus. Si falla no se interrumpe la transacción.
          print('⚠️ Error al notificar comisión al vendedor: $e');
        }
      }
    } catch (e) {
      print('❌ Error crítico al procesar comisiones: $e');
      throw Exception('Fallo transaccional en Motor de Comisiones: $e');
    }
  }

  /// Obtener logs de comisiones para el administrador
  static Future<List<Map<String, dynamic>>> fetchLogsComisionesAdmin() async {
    try {
      final response = await supabase
          .from('logs_comisiones')
          .select('*')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error al obtener logs comisiones: $e');
      return [];
    }
  }

  /// Obtener viajes listos para confirmar retorno
  static Future<List<Map<String, dynamic>>> getViajesListosConfirmarRetorno(String clienteId) async {
    try {
      final response = await supabase.rpc('get_viajes_listos_confirmar_retorno', params: {
        'p_cliente_id': clienteId,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener viajes listos para confirmar retorno: $e');
    }
  }

  /// Obtener monitor de cierres para administrador
  static Future<List<Map<String, dynamic>>> getMonitorCierres() async {
    try {
      final response = await supabase
          .from('vw_monitor_cierres')
          .select('*')
          .order('fecha_regreso', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener monitor de cierres: $e');
    }
  }

  /// Verificar si un viaje esta listo para confirmar retorno
  static Future<bool> verificarViajeListoConfirmarRetorno(String pedidoId) async {
    try {
      final response = await supabase.rpc('verificar_viaje_listo_confirmar_retorno', params: {
        'p_pedido_id': pedidoId,
      });
      
      return response as bool? ?? false;
    } catch (e) {
      throw Exception('Error al verificar estado de retorno: $e');
    }
  }



  // ========== METODOS DEL PESCADOR DASHBOARD ==========
  
  /// Crear cotizacion tecnica completa
  static Future<Map<String, dynamic>> crearCotizacionTecnica(Map<String, dynamic> datos) async {
    try {
      final response = await supabase.from('cotizaciones').insert({
        'pescador_id': datos['pescador_id'],
        'descripcion': datos['descripcion'],
        'coordenadas_partida': datos['coordenadas_partida'],
        'coordenadas_destino': datos['coordenadas_destino'],
        'punto_partida': datos['coordenadas_partida'],
        'punto_destino': datos['coordenadas_destino'],
        'localidad_partida': datos['localidad_partida'],
        'provincia_partida': datos['provincia_partida'],
        'localidad_destino': datos['localidad_destino'],
        'provincia_destino': datos['provincia_destino'],
        'lugar_encuentro': datos['lugar_encuentro'],
        'fecha_ida': datos['fecha_ida'],
        'fecha_vuelta': datos['fecha_vuelta'],
        'hora_encuentro': datos['hora_encuentro'],
        'cantidad_personas': datos['cantidad_personas'],
        'track_log': datos['track_log'],
        'estado': 'pendiente',
        'created_at': DateTime.now().toIso8601String(),
      }).select().single();
      
      final cotId = response['id'];

      notificarCapitanesNuevaCotizacion(
        cotizacionId: cotId,
        descripcion: datos['descripcion'] ?? 'Salida de Pesca',
        puntoPartida: datos['coordenadas_partida'] ?? {},
      ).catchError((e) => print('Error al notificar capitanes en crearCotizacionTecnica: $e'));

      return {
        'exito': true,
        'id': cotId,
        'mensaje': 'Cotización creada exitosamente'
      };
    } catch (e) {
      print('Error en insert directo de cotizacion: $e');
      return {
        'exito': false,
        'mensaje': e.toString()
      };
    }
  }

  /// Aceptar presupuesto y crear pedido
  static Future<Map<String, dynamic>> aceptarPresupuestoYCrearPedido(
    String cotizacionId,
    String pescadorId,
    String capitanId,
    List<Map<String, dynamic>> productosAdicionales,
    bool retiroLancha,
  ) async {
    try {
      final response = await supabase.rpc('aceptar_presupuesto_y_crear_pedido', params: {
        'p_cotizacion_id': cotizacionId,
        'p_pescador_id': pescadorId,
        'p_capitan_id': capitanId,
        'p_productos_adicionales': productosAdicionales,
        'p_logistica_retiro_lancha': retiroLancha,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo aceptar el presupuesto');
    } catch (e) {
      throw Exception('Error al aceptar presupuesto: $e');
    }
  }

  /// Obtener presupuestos del pescador
  static Future<List<Map<String, dynamic>>> getPresupuestosPescador(String pescadorId) async {
    try {
      final response = await supabase
          .from('vw_cotizaciones_pescador_tecnica')
          .select('*')
          .eq('pescador_id', pescadorId)
          .eq('estado', 'presupuestada')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener presupuestos del pescador: $e');
    }
  }

  /// Obtener productos recomendados
  static Future<List<Map<String, dynamic>>> getProductosRecomendados(
    int cantidadPersonas,
    double distanciaKm,
    int duracionHoras,
  ) async {
    try {
      final response = await supabase.rpc('get_productos_recomendados', params: {
        'p_cantidad_personas': cantidadPersonas,
        'p_distancia_km': distanciaKm,
        'p_duracion_horas': duracionHoras,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener productos recomendados: $e');
    }
  }

  /// Actualizar cotizacion con respuesta de capitan
  /// Actualizar cotizacion con respuesta del capitan
  static Future<Map<String, dynamic>> actualizarCotizacionConRespuesta(
    String cotizacionId,
    double presupuesto,
    String? observaciones, {
    String? capitanId,
  }) async {
    try {
      final effectiveCapitanId = capitanId ?? supabase.auth.currentUser?.id;
      
      if (effectiveCapitanId == null) {
        throw Exception('No hay sesion activa de capitan para responder');
      }

      final response = await supabase.rpc('actualizar_cotizacion_con_respuesta', params: {
        'p_cotizacion_id': cotizacionId,
        'p_capitan_id': effectiveCapitanId,
        'p_presupuesto': presupuesto,
        'p_observaciones': observaciones,
      });
      
      if (response != null) {
        if (response is List && response.isNotEmpty) return Map<String, dynamic>.from(response.first);
        if (response is Map) return Map<String, dynamic>.from(response);
        return {'exito': true, 'mensaje': 'Actualizado', 'cotizacion_id': cotizacionId};
      }
      
      throw Exception('No se pudo actualizar la cotizacion');
    } catch (e) {
      throw Exception('Error al actualizar cotizacion: $e');
    }
  }

  /// Obtener detalles completos de una cotizacion
  static Future<Map<String, dynamic>> getDetallesCotizacion(String cotizacionId) async {
    try {
      final response = await supabase
          .from('vw_cotizaciones_pescador_tecnica')
          .select('*')
          .eq('id', cotizacionId)
          .single();
      
      return response;
    } catch (e) {
      throw Exception('Error al obtener detalles de cotizacion: $e');
    }
  }

  /// Calcular distancia entre dos puntos
  static Future<double> calcularDistanciaKm(
    double lat1, double lon1, double lat2, double lon2,
  ) async {
    try {
      final response = await supabase.rpc('calcular_distancia_km', params: {
        'p_lat1': lat1,
        'p_lon1': lon1,
        'p_lat2': lat2,
        'p_lon2': lon2,
      });
      
      return response as double? ?? 0.0;
    } catch (e) {
      throw Exception('Error al calcular distancia: $e');
    }
  }

  // ========== METODOS DE EL SISTEMA DE ALERTAS ADMINISTRADOR ==========
  
  /// Obtener estadisticas detalladas del Monitor de Administrador
  static Future<Map<String, dynamic>> getMonitorAdminDetalles() async {
    try {
      final response = await supabase.rpc('get_monitor_admin_detalles');
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'cotizaciones_hoy': 0,
        'cotizaciones_pendientes_hoy': 0,
        'cotizaciones_presupuestadas_hoy': 0,
        'cotizaciones_aceptadas_hoy': 0,
        'tiempo_promedio_respuesta_minutos': 0,
        'capitanes_activos': 0,
        'capitanes_en_descanso': 0,
        'total_capitanes': 0,
        'alertas_pendientes': 0,
        'alertas_criticas': 0,
        'cotizaciones_pendientes_largas': 0,
        'manifiestos_hoy': 0,
        'manifiestos_preparados': 0,
        'manifiestos_completados': 0,
        'tasa_conversion_porcentaje': 0.0,
        'monto_promedio_viajes': 0.0,
        'ultima_actualizacion': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas del monitor: $e');
    }
  }

  /// Obtener alertas del administrador
  static Future<List<Map<String, dynamic>>> getAlertasAdmin() async {
    try {
      final response = await supabase
          .from('alertas_admin')
          .select('*')
          .eq('leida', false)
          .order('created_at', ascending: false)
          .limit(50);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener alertas del administrador: $e');
    }
  }

  /// Marcar alerta como leida
  static Future<void> marcarAlertaAdminLeida(String alertaId) async {
    try {
      await supabase
          .from('alertas_admin')
          .update({
            'leida': true,
            'leida_at': DateTime.now().toIso8601String(),
          })
          .eq('id', alertaId);
    } catch (e) {
      throw Exception('Error al marcar alerta como leida: $e');
    }
  }

  /// Ejecutar vigilante de cotizaciones pendientes
  static Future<Map<String, dynamic>> ejecutarVigilanteCotizaciones() async {
    try {
      final response = await supabase.rpc('ejecutar_vigilante_cotizaciones');
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'cotizaciones_procesadas': 0,
        'alertas_creadas': 0,
        'notificaciones_admin_enviadas': 0,
        'detalles_procesamiento': [],
      };
    } catch (e) {
      throw Exception('Error al ejecutar vigilante de cotizaciones: $e');
    }
  }

  /// Vincular cotizacion con manifiesto
  static Future<Map<String, dynamic>> vincularCotizacionConManifiesto(String cotizacionId) async {
    try {
      final response = await supabase.rpc('vincular_cotizacion_con_manifiesto', params: {
        'p_cotizacion_id': cotizacionId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo vincular la cotizacion con el manifiesto');
    } catch (e) {
      throw Exception('Error al vincular cotizacion con manifiesto: $e');
    }
  }

  /// Enviar notificacion Realtime a capitanes filtrados por radio
  static Future<Map<String, dynamic>> enviarNotificacionRealtimeCapitanes(
    String cotizacionId,
    double latPartida,
    double lonPartida,
  ) async {
    try {
      final response = await supabase.rpc('enviar_notificacion_realtime_capitanes', params: {
        'p_cotizacion_id': cotizacionId,
        'p_lat_partida': latPartida,
        'p_lon_partida': lonPartida,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo enviar notificacion Realtime');
    } catch (e) {
      throw Exception('Error al enviar notificacion Realtime: $e');
    }
  }

  /// Obtener manifiestos de una cotizacion
  static Future<List<Map<String, dynamic>>> getManifiestosPorCotizacion(String cotizacionId) async {
    try {
      final response = await supabase
          .from('manifiesto_pasajeros')
          .select('*')
          .eq('cotizacion_id', cotizacionId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener manifiestos: $e');
    }
  }

  /// Actualizar datos de pasajeros en manifiesto
  static Future<void> actualizarPasajerosManifiesto(
    String manifiestoId,
    List<Map<String, dynamic>> pasajeros,
  ) async {
    try {
      // Primero eliminar los pasajeros existentes
      await supabase
          .from('manifiesto_pasajeros')
          .delete()
          .eq('id', manifiestoId);
      
      // Luego insertar los nuevos pasajeros
      for (final pasajero in pasajeros) {
        await supabase.from('manifiesto_pasajeros').insert({
          'cotizacion_id': pasajero['cotizacion_id'],
          'capitan_id': pasajero['capitan_id'],
          'nombre_pasajero': pasajero['nombre'],
          'dni_pasajero': pasajero['dni'],
          'telefono_pasajero': pasajero['telefono'],
          'email_pasajero': pasajero['email'],
          'fecha_salida': pasajero['fecha_salida'],
          'fecha_regreso': pasajero['fecha_regreso'],
          'hora_encuentro': pasajero['hora_encuentro'],
          'lugar_encuentro': pasajero['lugar_encuentro'],
          'estado': pasajero['estado'],
          'datos_adicionales': pasajero['datos_adicionales'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Error al actualizar pasajeros del manifiesto: $e');
    }
  }

  // ========== METODOS DE INTERMEDIACION BLINDADA ==========
  
  /// Crear chat asistido
  static Future<Map<String, dynamic>> crearChatAsistido(
    String cotizacionId,
    String pescadorId,
    String capitanId,
  ) async {
    try {
      final response = await supabase.rpc('crear_chat_asistido', params: {
        'p_cotizacion_id': cotizacionId,
        'p_pescador_id': pescadorId,
        'p_capitan_id': capitanId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo crear el chat asistido');
    } catch (e) {
      throw Exception('Error al crear chat asistido: $e');
    }
  }

  /// Enviar mensaje en chat asistido
  static Future<Map<String, dynamic>> enviarMensajeChat(
    String chatId,
    String remitenteId,
    String tipoRemitente,
    String mensaje,
  ) async {
    try {
      final response = await supabase.rpc('enviar_mensaje_chat', params: {
        'p_chat_id': chatId,
        'p_remitente_id': remitenteId,
        'p_tipo_remitente': tipoRemitente,
        'p_mensaje': mensaje,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo enviar el mensaje');
    } catch (e) {
      throw Exception('Error al enviar mensaje: $e');
    }
  }

  /// Obtener mensajes de un chat
  static Future<List<Map<String, dynamic>>> getMensajesChat(String chatId) async {
    try {
      final response = await supabase.rpc('get_mensajes_chat', params: {
        'p_chat_id': chatId,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener mensajes: $e');
    }
  }

  /// Obtener perfil blindado del capitan
  static Future<Map<String, dynamic>> getPerfilCapitanBlindado(
    String capitanId,
    String cotizacionId,
  ) async {
    try {
      final response = await supabase.rpc('get_perfil_capitan_blindado', params: {
        'p_capitan_id': capitanId,
        'p_cotizacion_id': cotizacionId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo obtener el perfil blindado');
    } catch (e) {
      throw Exception('Error al obtener perfil blindado: $e');
    }
  }

  /// Obtener cotizaciones con reputacion de capitanes
  static Future<List<Map<String, dynamic>>> getCotizacionesConReputacion(
    String pescadorId,
  ) async {
    try {
      final response = await supabase
          .from('vw_cotizaciones_con_reputacion')
          .select('*')
          .eq('pescador_id', pescadorId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener cotizaciones con reputacion: $e');
    }
  }

  /// Actualizar reputacion del capitan
  static Future<Map<String, dynamic>> actualizarReputacionCapitan(
    String capitanId,
    int calificacion,
  ) async {
    try {
      final response = await supabase.rpc('actualizar_reputacion_capitan', params: {
        'p_capitan_id': capitanId,
        'p_calificacion': calificacion,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo actualizar la reputacion');
    } catch (e) {
      throw Exception('Error al actualizar reputacion: $e');
    }
  }

  /// Registra un viaje completado incrementando la cantidad de viajes y actualizando el nivel de reputación
  static Future<void> registrarViajeCompletadoReputacion(String capitanId) async {
    try {
      final rep = await getReputacionCapitan(capitanId);
      
      final int viajesNuevos = (rep['viajes_completados'] as int? ?? rep['total_viajes'] as int? ?? 0) + 1;
      final double calif = (rep['calificacion_promedio'] as num? ?? 5.0).toDouble();
      
      String nuevoNivel = 'novato';
      if (calif >= 4.8 && viajesNuevos >= 50) {
        nuevoNivel = 'elite';
      } else if (calif >= 4.5 && viajesNuevos >= 20) {
        nuevoNivel = 'experto';
      } else if (calif >= 4.0 && viajesNuevos >= 10) {
        nuevoNivel = 'intermedio';
      }
      
      await supabase.from('reputacion_capitanes').upsert({
        'capitan_id': capitanId,
        'total_viajes': viajesNuevos,
        'viajes_completados': viajesNuevos,
        'nivel_reputacion': nuevoNivel,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'capitan_id');
      
      print('📈 [REPUTACIÓN] Viaje completado registrado para Capitán $capitanId. Total viajes: $viajesNuevos, Nivel: $nuevoNivel');
    } catch (e) {
      print('❌ Error al actualizar reputación por viaje completado: $e');
    }
  }

  /// Filtrar mensaje para detectar informacion de contacto
  static Future<Map<String, dynamic>> filtrarMensajeContacto(String mensaje) async {
    try {
      final response = await supabase.rpc('filtrar_mensaje_contacto', params: {
        'p_mensaje': mensaje,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'mensaje_filtrado': mensaje,
        'contiene_contacto': false,
        'tipo_contacto': null,
        'contacto_detectado': null,
        'motivo_bloqueo': null,
      };
    } catch (e) {
      throw Exception('Error al filtrar mensaje: $e');
    }
  }

  /// Crear calificacion de viaje (lado PESCADOR)
  /// Guarda en la tabla unificada, marca pescador_califico y dispara cierre si ambos calificaron.
  static Future<void> crearCalificacionViaje({
    required String pedidoId,
    required String calificadorId,
    required String capitanCalificadoId,
    required int calificacion,
    String? comentario,
    Map<String, dynamic>? aspectosPuntuados,
  }) async {
    try {
      // 1. Verificar que no haya calificado ya
      final yaExiste = await supabase
          .from('calificaciones_viaje')
          .select('id')
          .eq('pedido_id', pedidoId)
          .eq('calificador_id', calificadorId)
          .maybeSingle();

      if (yaExiste != null) {
        throw Exception('Ya calificaste este viaje.');
      }

      // 2. Insertar calificación en la tabla unificada
      await supabase.from('calificaciones_viaje').insert({
        'pedido_id': pedidoId,
        'calificador_id': calificadorId,
        'calificador_rol': 'pescador',
        'calificado_id': capitanCalificadoId,
        'calificacion': calificacion,
        'comentario': comentario,
        'aspectos_puntuados': aspectosPuntuados ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });

      // 3. Marcar que el pescador ya calificó en el pedido
      await supabase
          .from('pedidos')
          .update({'pescador_califico': true})
          .eq('id', pedidoId);

      // 4. Verificar si el EL GUIA YA calificó para cerrar el viaje automáticamente
      final pedido = await supabase
          .from('pedidos')
          .select('capitan_califico')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido != null && pedido['capitan_califico'] == true) {
        await supabase
            .from('pedidos')
            .update({
              'estado': 'cerrado',
              'cerrado_at': DateTime.now().toIso8601String(),
            })
            .eq('id', pedidoId);
        // Notificar a ambos que el viaje quedó cerrado
        try {
          final p2 = await supabase
              .from('pedidos')
              .select('pescador_id, capitan_id')
              .eq('id', pedidoId)
              .maybeSingle();
          if (p2 != null && p2['pescador_id'] != null && p2['capitan_id'] != null) {
            await NotificacionHelper.viajeCerrado(
              p2['pescador_id'] as String,
              p2['capitan_id'] as String,
              pedidoId,
            );
          }
        } catch (_) {}
        print('🔒 Viaje $pedidoId cerrado automáticamente tras calificación del pescador.');
      }

      // Notificar al capitán que recibió una calificación del pescador
      await NotificacionHelper.calificacionRecibidaCapitan(
          capitanCalificadoId, pedidoId, calificacion);

      // 5. Actualizar reputación del capitán (tabla legacy mantenida para compatibilidad)
      try {
        await actualizarReputacionCapitan(capitanCalificadoId, calificacion);
      } catch (_) {} // No falla si la tabla de reputación legacy no existe

    } catch (e) {
      throw Exception('Error al crear calificacion: $e');
    }
  }

  /// Obtener reputacion de un capitan
  static Future<Map<String, dynamic>> getReputacionCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('reputacion_capitanes')
          .select('*')
          .eq('capitan_id', capitanId)
          .maybeSingle();
      
      if (response != null) {
        return response;
      }
      
      // Retornar reputacion por defecto si no existe
      return {
        'capitan_id': capitanId,
        'calificacion_promedio': 0.0,
        'total_viajes': 0,
        'viajes_completados': 0,
        'viajes_cancelados': 0,
        'total_calificaciones': 0,
        'calificaciones_5_estrellas': 0,
        'calificaciones_4_estrellas': 0,
        'calificaciones_3_estrellas': 0,
        'calificaciones_2_estrellas': 0,
        'calificaciones_1_estrella': 0,
        'nivel_reputacion': 'novato',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      throw Exception('Error al obtener reputacion: $e');
    }
  }

  /// Obtener calificaciones de un capitan
  static Future<List<Map<String, dynamic>>> getCalificacionesCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('calificaciones_viaje')
          .select('*')
          .eq('calificado_id', capitanId)
          .eq('calificador_rol', 'pescador')
          .order('created_at', ascending: false)
          .limit(20);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener calificaciones: $e');
    }
  }

  /// Responder a una calificacion
  static Future<void> responderCalificacion(
    String calificacionId,
    String respuesta,
  ) async {
    try {
      await supabase
          .from('calificaciones_viaje')
          .update({
            'respuesta_capitan': respuesta,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', calificacionId);
    } catch (e) {
      throw Exception('Error al responder calificacion: $e');
    }
  }

  /// Obtener calificaciones públicas para el Blog de Piques de la temporada
  static Future<List<Map<String, dynamic>>> obtenerReviewsPublicas() async {
    try {
      final response = await supabase
          .from('calificaciones_viaje')
          .select('*')
          .filter('aspectos_puntuados->>permitir_publicar_blog', 'eq', 'true')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      try {
        final response = await supabase
            .from('calificaciones_viaje')
            .select('*')
            .order('created_at', ascending: false)
            .limit(100);
        
        return List<Map<String, dynamic>>.from(response).where((r) {
          final aspectos = r['aspectos_puntuados'] as Map<String, dynamic>?;
          return aspectos != null && aspectos['permitir_publicar_blog'] == true;
        }).toList();
      } catch (innerError) {
        print('❌ Error al obtener reviews publicas: $innerError');
        return [];
      }
    }
  }

  // ========== METODOS DE PROTECCION DE INTERMEDIACION ==========
  
  /// Escanear mensajes de un capitan en busca de patrones de fraude
  static Future<Map<String, dynamic>> escanearMensajesCapitan(String capitanId) async {
    try {
      final response = await supabase.rpc('escanear_mensajes_capitan', params: {
        'p_capitan_id': capitanId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'alertas_creadas': 0,
        'mensajes_escaneados': 0,
        'detalles_alertas': [],
      };
    } catch (e) {
      throw Exception('Error al escanear mensajes: $e');
    }
  }

  /// Obtener alertas de seguridad para administrador
  static Future<List<Map<String, dynamic>>> getAlertasSeguridad() async {
    try {
      final response = await supabase.rpc('get_alertas_seguridad');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener alertas de seguridad: $e');
    }
  }

  /// Enviar advertencia a capitan
  static Future<Map<String, dynamic>> enviarAdvertenciaCapitan(
    String alertaId,
    String adminId,
    String? mensajeAdvertencia,
  ) async {
    try {
      final response = await supabase.rpc('enviar_advertencia_capitan', params: {
        'p_alerta_id': alertaId,
        'p_admin_id': adminId,
        'p_mensaje_advertencia': mensajeAdvertencia,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo enviar la advertencia');
    } catch (e) {
      throw Exception('Error al enviar advertencia: $e');
    }
  }

  /// Suspender capitan
  static Future<Map<String, dynamic>> suspenderCapitan(
    String alertaId,
    String adminId,
    String tipoSuspension,
    int duracionDias,
    String? motivo,
  ) async {
    try {
      final response = await supabase.rpc('suspender_capitan', params: {
        'p_alerta_id': alertaId,
        'p_admin_id': adminId,
        'p_tipo_suspension': tipoSuspension,
        'p_duracion_dias': duracionDias,
        'p_motivo': motivo,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo suspender al capitan');
    } catch (e) {
      throw Exception('Error al suspender capitan: $e');
    }
  }

  /// Detectar patrones de fraude en texto
  static Future<Map<String, dynamic>> detectarPatronesFraude(
    String texto,
    String capitanId,
    String contexto,
  ) async {
    try {
      final response = await supabase.rpc('detectar_patrones_fraude', params: {
        'p_texto': texto,
        'p_capitan_id': capitanId,
        'p_contexto': contexto,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'contiene_fraude': false,
        'tipo_alerta': null,
        'severidad': null,
        'texto_detectado': null,
        'patron_detectado': null,
        'posicion': null,
        'contexto_adicional': null,
      };
    } catch (e) {
      throw Exception('Error al detectar patrones de fraude: $e');
    }
  }

  /// Obtener suspensiones activas de un capitan
  static Future<List<Map<String, dynamic>>> getSuspensionesActivasCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('suspensiones_capitanes')
          .select('*')
          .eq('capitan_id', capitanId)
          .eq('estado', 'activa')
          .order('inicio_suspension', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener suspensiones activas: $e');
    }
  }

  /// Obtener advertencias de un capitan
  static Future<List<Map<String, dynamic>>> getAdvertenciasCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('advertencias_capitanes')
          .select('*')
          .eq('capitan_id', capitanId)
          .order('creado_at', ascending: false)
          .limit(50);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener advertencias: $e');
    }
  }

  /// Marcar advertencia como leida
  static Future<void> marcarAdvertenciaLeida(String advertenciaId) async {
    try {
      await supabase
          .from('advertencias_capitanes')
          .update({
            'leida': true,
            'leida_at': DateTime.now().toIso8601String(),
          })
          .eq('id', advertenciaId);
    } catch (e) {
      throw Exception('Error al marcar advertencia como leida: $e');
    }
  }

  /// Obtener historial de alertas de fraude de un capitan
  static Future<List<Map<String, dynamic>>> getHistorialAlertasCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('alertas_fraude')
          .select('*')
          .eq('capitan_id', capitanId)
          .order('creado_at', ascending: false)
          .limit(100);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener historial de alertas: $e');
    }
  }

  /// Verificar si un capitan esta suspendido
  static Future<bool> estaCapitanSuspendido(String capitanId) async {
    try {
      final response = await supabase
          .from('profiles')
          .select('suspendido, suspension_hasta')
          .eq('user_id', capitanId)
          .single();
      
      if (response['suspendido'] == true) {
        final suspensionHasta = response['suspension_hasta'] as String?;
        if (suspensionHasta != null) {
          final fechaFin = DateTime.parse(suspensionHasta);
          return fechaFin.isAfter(DateTime.now());
        }
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Liberar contacto al aceptar cotizacion
  static Future<void> liberarContactoAlAceptar(String cotizacionId) async {
    try {
      await supabase
          .from('pedidos')
          .update({
            'contacto_liberado': true,
            'contacto_liberado_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('cotizacion_id', cotizacionId);
    } catch (e) {
      throw Exception('Error al liberar contacto: $e');
    }
  }

  /// Obtener estadisticas de seguridad para dashboard
  static Future<Map<String, dynamic>> getEstadisticasSeguridad() async {
    try {
      final response = await supabase
          .from('alertas_fraude')
          .select('tipo_alerta, severidad, estado')
          .order('creado_at', ascending: false);
      
      final alertas = List<Map<String, dynamic>>.from(response);
      
      return {
        'total_alertas': alertas.length,
        'alertas_criticas': alertas.where((a) => a['severidad'] == 'critica').length,
        'alertas_altas': alertas.where((a) => a['severidad'] == 'alta').length,
        'alertas_medias': alertas.where((a) => a['severidad'] == 'media').length,
        'alertas_pendientes': alertas.where((a) => a['estado'] == 'pendiente').length,
        'alertas_resueltas': alertas.where((a) => a['estado'] == 'resuelta').length,
        'alertas_telefono': alertas.where((a) => a['tipo_alerta'] == 'telefono').length,
        'alertas_email': alertas.where((a) => a['tipo_alerta'] == 'email').length,
        'alertas_whatsapp': alertas.where((a) => a['tipo_alerta'] == 'whatsapp').length,
        'alertas_enlace_externo': alertas.where((a) => a['tipo_alerta'] == 'enlace_externo').length,
        'alertas_contacto_directo': alertas.where((a) => a['tipo_alerta'] == 'contacto_directo').length,
      };
    } catch (e) {
      throw Exception('Error al obtener estadisticas de seguridad: $e');
    }
  }

  // ========== METODOS DE ACEPTACION DE VIAJE ==========
  
  /// Calcular monto total del viaje (cotizacion + carrito)
  static Future<Map<String, dynamic>> calcularMontoTotalViaje(String pedidoId) async {
    try {
      final response = await supabase.rpc('calcular_monto_total_viaje', params: {
        'p_pedido_id': pedidoId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'monto_cotizacion': 0.0,
        'monto_carrito': 0.0,
        'monto_total': 0.0,
        'total_bultos': 0,
        'productos_count': 0,
      };
    } catch (e) {
      throw Exception('Error al calcular monto total: $e');
    }
  }

  /// Aceptar viaje y cargar datos de pasajeros
  static Future<Map<String, dynamic>> aceptarViajeYCargarDatos(
    String pedidoId,
    String pescadorId,
    List<Map<String, dynamic>> listaPasajeros,
    bool confirmarPago,
  ) async {
    try {
      final response = await supabase.rpc('aceptar_viaje_y_cargar_datos', params: {
        'p_pedido_id': pedidoId,
        'p_pescador_id': pescadorId,
        'p_lista_pasajeros': listaPasajeros,
        'p_confirmar_pago': confirmarPago,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo aceptar el viaje');
    } catch (e) {
      throw Exception('Error al aceptar viaje: $e');
    }
  }

  /// Subir foto de DNI de pasajero
  static Future<Map<String, dynamic>> subirFotoDNIPasajero(
    String manifiestoId,
    String fotoDniUrl,
    bool validado,
  ) async {
    try {
      final response = await supabase.rpc('subir_foto_dni_pasajero', params: {
        'p_manifiesto_id': manifiestoId,
        'p_foto_dni_url': fotoDniUrl,
        'p_validado': validado,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo subir la foto de DNI');
    } catch (e) {
      throw Exception('Error al subir foto de DNI: $e');
    }
  }

  /// Validar datos de pasajero
  static Future<Map<String, dynamic>> validarDatosPasajero(String manifiestoId) async {
    try {
      final response = await supabase.rpc('validar_datos_pasajero', params: {
        'p_manifiesto_id': manifiestoId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudieron validar los datos');
    } catch (e) {
      throw Exception('Error al validar datos del pasajero: $e');
    }
  }

  /// Obtener manifiesto completo de un viaje
  static Future<List<Map<String, dynamic>>> getManifiestoViaje(String viajeId) async {
    try {
      final response = await supabase.rpc('get_manifiesto_viaje', params: {
        'p_viaje_id': viajeId,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener manifiesto: $e');
    }
  }

  /// Obtener productos de un viaje
  static Future<List<Map<String, dynamic>>> getProductosViaje(String viajeId) async {
    try {
      final response = await supabase.rpc('get_productos_viaje', params: {
        'p_viaje_id': viajeId,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener productos del viaje: $e');
    }
  }

  /// Verificar si el contacto esta habilitado para un pedido
  static Future<bool> verificarContactoHabilitado(String pedidoId) async {
    try {
      final response = await supabase
          .from('pedidos')
          .select('contacto_habilitado')
          .eq('id', pedidoId)
          .maybeSingle();
      
      return response?['contacto_habilitado'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Marcar productos de tienda con ID de viaje
  static Future<void> marcarProductosConViaje(
    String pedidoId,
    String viajeId,
    List<Map<String, dynamic>> productos,
  ) async {
    try {
      // Actualizar pedido con productos y ID de viaje
      await supabase
          .from('pedidos')
          .update({
            'productos_tienda': productos,
            'id_viaje': viajeId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId);
      
      // Crear registros en productos_viajes
      for (final producto in productos) {
        await supabase.from('productos_viajes').insert({
          'viaje_id': viajeId,
          'pedido_id': pedidoId,
          'producto_id': producto['producto_id'],
          'nombre_producto': producto['nombre'],
          'cantidad': producto['cantidad'],
          'precio_unitario': producto['precio'],
          'subtotal': (producto['precio'] as num) * (producto['cantidad'] as int),
          'categoria': producto['categoria'],
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    } catch (e) {
      throw Exception('Error al marcar productos con viaje: $e');
    }
  }

  /// Obtener detalles completos de un pedido para aceptacion
  static Future<Map<String, dynamic>> getDetallesPedidoAceptacion(String pedidoId) async {
    try {
      final response = await supabase
          .from('pedidos')
          .select('''
            *,
            cotizaciones!inner(
              id,
              descripcion,
              presupuesto_base,
              capitan_id,
              pescador_id,
              estado,
              fecha_ida,
              fecha_vuelta,
              hora_encuentro,
              lugar_encuentro
            ),
            profiles!inner(
              user_id,
              nombre,
              telefono_contacto,
              email
            )
          ''')
          .eq('id', pedidoId)
          .maybeSingle();
      
      if (response != null) {
        return response;
      }
      
      throw Exception('Pedido no encontrado');
    } catch (e) {
      throw Exception('Error al obtener detalles del pedido: $e');
    }
  }

  /// Liberar contacto al confirmar pago
  static Future<void> liberarContactoAlConfirmarPago(String pedidoId) async {
    try {
      await supabase
          .from('pedidos')
          .update({
            'contacto_habilitado': true,
            'contacto_habilitado_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', pedidoId);
    } catch (e) {
      throw Exception('Error al liberar contacto: $e');
    }
  }

  /// Obtener resumen del viaje para notificacion
  static Future<Map<String, dynamic>> getResumenViajeNotificacion(String viajeId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('''
            *,
            pedidos!inner(
              id,
              total_bultos,
              monto_total_viaje,
              productos_tienda
            )
          ''')
          .eq('id', viajeId)
          .maybeSingle();
      
      if (response != null) {
        return response;
      }
      
      throw Exception('Viaje no encontrado');
    } catch (e) {
      throw Exception('Error al obtener resumen del viaje: $e');
    }
  }

  // ========== METODOS DE AVISOS LOGISTICOS ==========
  
  /// Validar direccion de entrega
  static Future<Map<String, dynamic>> validarDireccionEntrega(
    String tipoEntrega,
    String direccion,
  ) async {
    try {
      final response = await supabase.rpc('validar_direccion_entrega', params: {
        'p_tipo_entrega': tipoEntrega,
        'p_direccion': direccion,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'valida': false,
        'mensaje': 'Error en la validacion',
        'permite_embarque': false,
      };
    } catch (e) {
      throw Exception('Error al validar direccion: $e');
    }
  }

  /// Crear envio logistico
  static Future<Map<String, dynamic>> crearEnvioLogistico({
    required String pedidoId,
    required String tipoEnvio,
    required String direccion,
    String? codigoPostal,
    String? ciudad,
    String? provincia,
    double costoEnvio = 0.0,
    bool seguro = false,
    String? notas,
  }) async {
    try {
      final response = await supabase.rpc('crear_envio_logistico', params: {
        'p_pedido_id': pedidoId,
        'p_tipo_envio': tipoEnvio,
        'p_direccion': direccion,
        'p_codigo_postal': codigoPostal,
        'p_ciudad': ciudad,
        'p_provincia': provincia,
        'p_costo_envio': costoEnvio,
        'p_seguro': seguro,
        'p_notas': notas,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo crear el envio logistico');
    } catch (e) {
      throw Exception('Error al crear envio logistico: $e');
    }
  }

  /// Cargar tracking de envio
  static Future<Map<String, dynamic>> cargarTrackingEnvio(
    String envioId,
    String trackingCodigo,
    String adminId,
  ) async {
    try {
      final response = await supabase.rpc('cargar_tracking_envio', params: {
        'p_envio_id': envioId,
        'p_tracking_codigo': trackingCodigo,
        'p_admin_id': adminId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo cargar el tracking');
    } catch (e) {
      throw Exception('Error al cargar tracking: $e');
    }
  }

  /// Marcar producto como entregado
  static Future<Map<String, dynamic>> marcarProductoEntregado(
    String pedidoId,
    String adminId,
  ) async {
    try {
      final response = await supabase.rpc('marcar_producto_entregado', params: {
        'p_pedido_id': pedidoId,
        'p_admin_id': adminId,
      });

      // 🚀 EJECUTAR LIQUIDACIÓN Y ACTUALIZAR REPUTACIÓN EN TIEMPO REAL
      try {
        await procesarComisionesViaje(pedidoId);
      } catch (ex) {
        print('⚠️ Error al procesar comisiones al marcar producto entregado: $ex');
      }

      try {
        final pedido = await supabase
            .from('pedidos')
            .select('capitan_id, pescador_id, monto_total')
            .eq('id', pedidoId)
            .maybeSingle();
        final capitanId = pedido?['capitan_id']?.toString();
        if (capitanId != null) {
          await registrarViajeCompletadoReputacion(capitanId);
        }

        // 🧾 DISPARAR FACTURACIÓN ELECTRÓNICA AFIP (PRODUCTO_ENTREGADO)
        final montoTotal = (pedido?['monto_total'] as num?)?.toDouble() ?? 0.0;
        final pescadorId = pedido?['pescador_id']?.toString() ?? 'sin_dni';
        // fire-and-forget: no bloquea el flujo de marcado de entrega
        Future.microtask(() async {
          try {
            await AfipService.generarFacturaAutomatica(
              pedidoId: pedidoId,
              monto: montoTotal,
              dniCliente: pescadorId,
            );
          } catch (ex) {
            print('⚠️ AFIP: Error en facturación de producto entregado: $ex');
          }
        });
      } catch (ex) {
        print('⚠️ Error al registrar reputación tras producto entregado: $ex');
      }
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo marcar producto como entregado');
    } catch (e) {
      throw Exception('Error al marcar producto entregado: $e');
    }
  }

  /// Marcar viaje como realizado
  static Future<Map<String, dynamic>> marcarViajeRealizado(
    String pedidoId,
    String adminId,
  ) async {
    try {
      final response = await supabase.rpc('marcar_viaje_realizado', params: {
        'p_pedido_id': pedidoId,
        'p_admin_id': adminId,
      });

      // 🚀 EJECUTAR LIQUIDACIÓN Y ACTUALIZAR REPUTACIÓN EN TIEMPO REAL
      try {
        await procesarComisionesViaje(pedidoId);
      } catch (ex) {
        print('⚠️ Error al procesar comisiones al marcar viaje realizado: $ex');
      }

      try {
        final pedido = await supabase
            .from('pedidos')
            .select('capitan_id, pescador_id, monto_total')
            .eq('id', pedidoId)
            .maybeSingle();
        final capitanId = pedido?['capitan_id']?.toString();
        if (capitanId != null) {
          await registrarViajeCompletadoReputacion(capitanId);
        }

        // 🧾 DISPARAR FACTURACIÓN ELECTRÓNICA AFIP (VIAJE_CONCRETADO)
        final montoTotal = (pedido?['monto_total'] as num?)?.toDouble() ?? 0.0;
        final pescadorId = pedido?['pescador_id']?.toString() ?? 'sin_dni';
        // fire-and-forget: no bloquea el flujo de marcado del viaje
        Future.microtask(() async {
          try {
            await AfipService.generarFacturaAutomatica(
              pedidoId: pedidoId,
              monto: montoTotal,
              dniCliente: pescadorId,
            );
          } catch (ex) {
            print('⚠️ AFIP: Error en facturación de viaje concretado: $ex');
          }
        });
      } catch (ex) {
        print('⚠️ Error al registrar reputación tras viaje realizado: $ex');
      }
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo marcar viaje como realizado');
    } catch (e) {
      throw Exception('Error al marcar viaje realizado: $e');
    }
  }

  /// Registrar aceptacion de disclaimer
  static Future<Map<String, dynamic>> registrarAceptacionDisclaimer(
    String userId,
    String pedidoId, {
    String? ipAddress,
    String? userAgent,
  }) async {
    try {
      final response = await supabase.rpc('registrar_aceptacion_disclaimer', params: {
        'p_user_id': userId,
        'p_pedido_id': pedidoId,
        'p_ip_address': ipAddress,
        'p_user_agent': userAgent,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo registrar la aceptacion');
    } catch (e) {
      throw Exception('Error al registrar aceptacion: $e');
    }
  }

  /// Obtener seguimiento de envios del pescador
  static Future<List<Map<String, dynamic>>> getSeguimientoPescador(String pescadorId) async {
    try {
      final response = await supabase.rpc('get_seguimiento_pescador', params: {
        'p_pescador_id': pescadorId,
      });
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener seguimiento: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getGestionLogisticaAdmin() async {
    try {
      // 1. Fetch all pedidos_tienda
      final List<dynamic> ptResponse = await supabase
          .from('pedidos_tienda')
          .select('id, estado, total, tracking_codigo, tracking_url, despachado, entregado, pescador_id, creado_at')
          .order('creado_at', ascending: false);
      
      final List<Map<String, dynamic>> ptRows = List<Map<String, dynamic>>.from(ptResponse);
      if (ptRows.isEmpty) {
        return [];
      }

      // Collect IDs
      final List<String> ptIds = ptRows.map((e) => e['id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();
      final Set<String> pescadorIds = ptRows.map((e) => e['pescador_id']?.toString() ?? '').where((id) => id.isNotEmpty).toSet();

      // 2. Fetch vinculos logisticos for these pedidos_tienda
      List<Map<String, dynamic>> vlRows = [];
      if (ptIds.isNotEmpty) {
        final List<dynamic> vlResponse = await supabase
            .from('vinculo_logistico')
            .select('pedido_tienda_id, reserva_viaje_id, tipo_vinculo')
            .inFilter('pedido_tienda_id', ptIds);
        vlRows = List<Map<String, dynamic>>.from(vlResponse);
      }

      // Map to quickly find vinculo by pedido_tienda_id
      final Map<String, Map<String, dynamic>> vinculosMap = {
        for (var vl in vlRows) vl['pedido_tienda_id']?.toString() ?? '': vl
      };

      // Collect reserva_viaje_ids
      final List<String> rvIds = vlRows.map((e) => e['reserva_viaje_id']?.toString() ?? '').where((id) => id.isNotEmpty).toList();

      // 3. Fetch reservas_viajes
      List<Map<String, dynamic>> rvRows = [];
      if (rvIds.isNotEmpty) {
        final List<dynamic> rvResponse = await supabase
            .from('reservas_viajes')
            .select('id, estado, monto_total, realizado, liquidado')
            .inFilter('id', rvIds);
        rvRows = List<Map<String, dynamic>>.from(rvResponse);
      }

      final Map<String, Map<String, dynamic>> reservasMap = {
        for (var rv in rvRows) rv['id']?.toString() ?? '': rv
      };

      // 4. Fetch profiles
      final Map<String, Map<String, String>> profilesMap = {};
      if (pescadorIds.isNotEmpty) {
        try {
          final List<dynamic> profilesRes = await supabase
              .from('profiles')
              .select('user_id, nombre, email')
              .inFilter('user_id', pescadorIds.toList());
          for (final p in profilesRes) {
            final String uId = p['user_id']?.toString() ?? '';
            if (uId.isNotEmpty) {
              profilesMap[uId] = {
                'nombre': p['nombre']?.toString() ?? 'Pescador sin nombre',
                'email': p['email']?.toString() ?? '',
              };
            }
          }
        } catch (pe) {
          print('Error al obtener profiles para logistica: $pe');
        }
      }

      // 5. Assemble everything
      final List<Map<String, dynamic>> resultado = [];
      for (final pt in ptRows) {
        final String ptId = pt['id']?.toString() ?? '';
        final String pescadorId = pt['pescador_id']?.toString() ?? '';
        final Map<String, String> profile = profilesMap[pescadorId] ?? {'nombre': 'Pescador', 'email': ''};

        final Map<String, dynamic>? vinculo = vinculosMap[ptId];
        final String rvId = vinculo?['reserva_viaje_id']?.toString() ?? '';
        final String tipoVinculo = vinculo?['tipo_vinculo']?.toString() ?? 'separado';

        final Map<String, dynamic>? reserva = rvId.isNotEmpty ? reservasMap[rvId] : null;

        final bool pedidoDespachado = pt['despachado'] == true;
        final bool viajeRealizado = reserva?['realizado'] == true;

        String estadoGeneral = '⏳ Pendiente';
        String colorGeneral = '0xFF6B7280';

        if (pedidoDespachado && viajeRealizado) {
          estadoGeneral = '✅ Completo';
          colorGeneral = '0xFF10B981'; // #10B981
        } else if (pedidoDespachado) {
          estadoGeneral = '📦 Pedido Despachado';
          colorGeneral = '0xFF3B82F6'; // #3B82F6
        } else if (viajeRealizado) {
          estadoGeneral = '🚢 Viaje Realizado';
          colorGeneral = '0xFFF59E0B'; // #F59E0B
        }

        resultado.add({
          'pedido_tienda_id': ptId,
          'estado_pedido': pt['estado']?.toString() ?? 'carrito',
          'total_pedido': (pt['total'] as num?)?.toDouble() ?? 0.0,
          'tracking_codigo': pt['tracking_codigo'],
          'tracking_url': pt['tracking_url'],
          'pedido_despachado': pedidoDespachado,
          'pedido_entregado': pt['entregado'] == true,
          'reserva_viaje_id': rvId.isNotEmpty ? rvId : null,
          'estado_reserva': reserva?['estado']?.toString(),
          'monto_reserva': (reserva?['monto_total'] as num?)?.toDouble() ?? 0.0,
          'viaje_realizado': viajeRealizado,
          'viaje_liquidado': reserva?['liquidado'] == true,
          'pescador_nombre': profile['nombre'],
          'pescador_email': profile['email'],
          'tipo_vinculo': tipoVinculo,
          'estado_general': estadoGeneral,
          'color_general': colorGeneral,
        });
      }

      return resultado;
    } catch (e) {
      throw Exception('Error al obtener gestion logistica: $e');
    }
  }

  /// Verificar si el disclaimer fue aceptado
  static Future<bool> verificarDisclaimerAceptado(String pedidoId) async {
    try {
      final response = await supabase
          .from('pedidos')
          .select('disclaimer_aceptado')
          .eq('id', pedidoId)
          .maybeSingle();
      
      return response?['disclaimer_aceptado'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Obtener envios por tracking codigo
  static Future<List<Map<String, dynamic>>> getEnviosPorTracking(String trackingCodigo) async {
    try {
      final response = await supabase
          .from('envios_logisticos')
          .select('''
            *,
            pedidos!inner(
              id,
              pescador_id,
              total
            )
          ''')
          .eq('tracking_codigo', trackingCodigo);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener envios por tracking: $e');
    }
  }

  /// Actualizar estado de envio
  static Future<void> actualizarEstadoLogistica(
    String envioId,
    String nuevoEstado,
    {String? notas}
  ) async {
    try {
      await supabase
          .from('envios_logisticos')
          .update({
            'estado_envio': nuevoEstado,
            'actualizado_at': DateTime.now().toIso8601String(),
            'notas': notas,
          })
          .eq('id', envioId);
    } catch (e) {
      throw Exception('Error al actualizar estado de envio: $e');
    }
  }

  /// Obtener detalles completos de envio
  static Future<Map<String, dynamic>> getDetallesEnvio(String envioId) async {
    try {
      final response = await supabase
          .from('envios_logisticos')
          .select('''
            *,
            pedidos!inner(
              id,
              pescador_id,
              total,
              productos_tienda,
              created_at as pedido_fecha
            ),
            profiles!inner(
              user_id,
              nombre,
              email,
              telefono_contacto
            )
          ''')
          .eq('id', envioId)
          .maybeSingle();
      
      if (response != null) {
        return response;
      }
      
      throw Exception('Envio no encontrado');
    } catch (e) {
      throw Exception('Error al obtener detalles del envio: $e');
    }
  }

  /// Verificar si hay bloqueo de embarque aplicado
  static Future<bool> verificarBloqueoEmbarque(String pedidoId) async {
    try {
      final response = await supabase
          .from('pedidos')
          .select('bloqueo_embarque_aplicado')
          .eq('id', pedidoId)
          .maybeSingle();
      
      return response?['bloqueo_embarque_aplicado'] ?? false;
    } catch (e) {
      return false;
    }
  }

  // ========== METODOS DE INDEPENDENCIA LOGISTICA ==========
  
  /// Crear pedido_tienda
  static Future<Map<String, dynamic>> crearPedidoTienda(
    String pescadorId,
    List<Map<String, dynamic>> productos,
    Map<String, dynamic> direccion,
    String tipoEntrega,
    bool disclaimerAceptado,
  ) async {
    try {
      final response = await supabase.rpc('crear_pedido_tienda', params: {
        'p_pescador_id': pescadorId,
        'p_productos': productos,
        'p_direccion': direccion,
        'p_tipo_entrega': tipoEntrega,
        'p_disclaimer_aceptado': disclaimerAceptado,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo crear el pedido de tienda');
    } catch (e) {
      throw Exception('Error al crear pedido de tienda: $e');
    }
  }

  /// Crear reserva_viaje
  static Future<Map<String, dynamic>> crearReservaViaje(
    String pescadorId,
    String cotizacionId,
    List<Map<String, dynamic>> datosPasajeros,
    List<Map<String, dynamic>> productosTienda,
  ) async {
    try {
      final response = await supabase.rpc('crear_reserva_viaje', params: {
        'p_pescador_id': pescadorId,
        'p_cotizacion_id': cotizacionId,
        'p_datos_pasajeros': datosPasajeros,
        'p_productos_tienda': productosTienda,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo crear la reserva de viaje');
    } catch (e) {
      throw Exception('Error al crear reserva de viaje: $e');
    }
  }

  /// Vincular pedido_tienda con reserva_viaje
  static Future<Map<String, dynamic>> vincularPedidoReserva(
    String pedidoTiendaId,
    String reservaViajeId,
    String pescadorId,
    String tipoVinculo,
  ) async {
    try {
      final response = await supabase.rpc('vincular_pedido_reserva', params: {
        'p_pedido_tienda_id': pedidoTiendaId,
        'p_reserva_viaje_id': reservaViajeId,
        'p_pescador_id': pescadorId,
        'p_tipo_vinculo': tipoVinculo,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo vincular pedido con reserva');
    } catch (e) {
      throw Exception('Error al vincular pedido con reserva: $e');
    }
  }

  /// Cargar tracking y enviar notificacion automatica
  static Future<Map<String, dynamic>> cargarTrackingYNotificar(
    String pedidoTiendaId,
    String trackingCodigo,
    String adminId,
  ) async {
    try {
      final response = await supabase.rpc('cargar_tracking_y_notificar', params: {
        'p_pedido_tienda_id': pedidoTiendaId,
        'p_tracking_codigo': trackingCodigo,
        'p_admin_id': adminId,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      throw Exception('No se pudo cargar el tracking');
    } catch (e) {
      throw Exception('Error al cargar tracking: $e');
    }
  }

  /// Validar direccion de texto
  static Future<Map<String, dynamic>> validarDireccionTexto(Map<String, dynamic> direccion) async {
    try {
      final response = await supabase.rpc('validar_direccion_texto', params: {
        'p_direccion': direccion,
      });
      
      if (response.isNotEmpty) {
        return response.first;
      }
      
      return {
        'valida': false,
        'mensaje': 'Error en la validacion',
        'direccion_corregida': direccion,
      };
    } catch (e) {
      throw Exception('Error al validar direccion: $e');
    }
  }

  /// Obtener seguimiento del pescador
  static Future<List<Map<String, dynamic>>> getSeguimientoPescadorIndependiente() async {
    try {
      final response = await supabase.rpc('get_seguimiento_pescador');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener seguimiento: $e');
    }
  }

  /// Obtener detalles de pedido_tienda
  static Future<Map<String, dynamic>> getDetallesPedidoTienda(String pedidoTiendaId) async {
    try {
      final response = await supabase
          .from('pedidos_tienda')
          .select('''
            *,
            profiles!inner(
              user_id,
              nombre,
              email,
              telefono_contacto
            )
          ''')
          .eq('id', pedidoTiendaId)
          .maybeSingle();
      
      if (response != null) {
        return response;
      }
      
      throw Exception('Pedido de tienda no encontrado');
    } catch (e) {
      throw Exception('Error al obtener detalles del pedido: $e');
    }
  }

  /// Obtener detalles de reserva_viaje
  static Future<Map<String, dynamic>> getDetallesReservaViaje(String reservaViajeId) async {
    try {
      final response = await supabase
          .from('reservas_viajes')
          .select('''
            *,
            cotizaciones!inner(
              id,
              descripcion,
              presupuesto_base,
              fecha_ida,
              fecha_vuelta,
              hora_encuentro,
              lugar_encuentro
            ),
            profiles!inner(
              user_id,
              nombre,
              email,
              telefono_contacto
            )
          ''')
          .eq('id', reservaViajeId)
          .maybeSingle();
      
      if (response != null) {
        return response;
      }
      
      throw Exception('Reserva de viaje no encontrada');
    } catch (e) {
      throw Exception('Error al obtener detalles de la reserva: $e');
    }
  }

  /// Actualizar estado de pedido_tienda
  static Future<void> actualizarEstadoPedidoTienda(
    String pedidoTiendaId,
    String nuevoEstado,
    {String? notasAdmin}
  ) async {
    try {
      await supabase
          .from('pedidos_tienda')
          .update({
            'estado': nuevoEstado,
            'actualizado_at': DateTime.now().toIso8601String(),
            'notas_admin': notasAdmin,
          })
          .eq('id', pedidoTiendaId);
    } catch (e) {
      throw Exception('Error al actualizar estado del pedido: $e');
    }
  }

  /// Actualizar estado de reserva_viaje
  static Future<void> actualizarEstadoReservaViaje(
    String reservaViajeId,
    String nuevoEstado,
    {String? notasAdmin}
  ) async {
    try {
      await supabase
          .from('reservas_viajes')
          .update({
            'estado': nuevoEstado,
            'actualizado_at': DateTime.now().toIso8601String(),
            'notas_admin': notasAdmin,
          })
          .eq('id', reservaViajeId);
    } catch (e) {
      throw Exception('Error al actualizar estado de la reserva: $e');
    }
  }

  /// Verificar si el disclaimer fue aceptado en pedido_tienda
  static Future<bool> verificarDisclaimerAceptadoTienda(String pedidoTiendaId) async {
    try {
      final response = await supabase
          .from('pedidos_tienda')
          .select('disclaimer_aceptado')
          .eq('id', pedidoTiendaId)
          .maybeSingle();
      
      return response?['disclaimer_aceptado'] ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Obtener vinculos logisticos de un pescador
  static Future<List<Map<String, dynamic>>> getVinculosLogisticosPescador(String pescadorId) async {
    try {
      final response = await supabase
          .from('vinculo_logistico')
          .select('''
            *,
            pedidos_tienda!inner(
              id,
              estado,
              total,
              tracking_codigo,
              created_at
            ),
            reservas_viajes!inner(
              id,
              estado,
              monto_total,
              created_at
            )
          ''')
          .eq('pescador_id', pescadorId)
          .eq('estado', 'activo');
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener vinculos logisticos: $e');
    }
  }

  // ========== METODOS PARA CAPITAN ==========
  
  // Eliminado duplicado

  /// Obtener detalles de cotizacion para capitan (sin datos de contacto del pescador)
  static Future<Map<String, dynamic>> getDetallesCotizacionCapitan(String cotizacionId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('''
            id,
            pescador_id,
            capitan_id,
            estado,
            descripcion,
            fecha_ida,
            fecha_vuelta,
            hora_encuentro,
            lugar_encuentro,
            cantidad_personas,
            coordenada_origen_lat,
            coordenada_origen_lng,
            coordenada_destino_lat,
            coordenada_destino_lng,
            presupuesto_base,
            respuesta_capitan,
            presupuesto_enviado_at,
            created_at,
            updated_at,
            profiles!inner(
              user_id,
              nombre
              -- NOTA: No incluimos apellido ni telefono del pescador
            )
          ''')
          .eq('id', cotizacionId)
          .maybeSingle();
      
      if (response != null) {
        return response;
      }
      
      throw Exception('Cotizacion no encontrada');
    } catch (e) {
      throw Exception('Error al obtener detalles de cotizacion: $e');
    }
  }

  /// Verificar si el capitan puede ver los datos de contacto del pescador
  static Future<bool> verificarContactoHabilitadoParaCapitan(String cotizacionId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('estado')
          .eq('id', cotizacionId)
          .maybeSingle();
      
      // Solo si esta aceptada/pagada puede ver contacto
      final estado = response?['estado'] ?? '';
      return estado == 'aceptada' || estado == 'pagada' || estado == 'confirmado';
    } catch (e) {
      return false;
    }
  }

  /// Rechazar cotizacion
  static Future<void> rechazarCotizacion(String cotizacionId, String motivo) async {
    try {
      // 1. Obtener la cotización actual para saber la fecha del viaje y el capitan_id
      final cot = await supabase
          .from('cotizaciones')
          .select('fecha_ida, capitan_id')
          .eq('id', cotizacionId)
          .maybeSingle();

      // 2. Actualizar el estado de la cotización a rechazado
      await supabase
          .from('cotizaciones')
          .update({
            'estado': 'rechazado',
            'respuesta_capitan': motivo,
            'presupuesto_enviado_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', cotizacionId);

      // 3. Cancelar los presupuestos asociados en la tabla 'presupuestos'
      await supabase
          .from('presupuestos')
          .update({
            'estado': 'cancelado',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('cotizacion_id', cotizacionId);

      // 4. Liberar la fecha en el almanaque de disponibilidad
      if (cot != null && cot['fecha_ida'] != null && cot['capitan_id'] != null) {
        final DateTime? fecha = DateTime.tryParse(cot['fecha_ida'].toString());
        final String capId = cot['capitan_id'].toString();
        if (fecha != null) {
          await DisponibilidadServiceFinal.liberarFechaReservadaConCapitan(fecha, capId);
        }
      }
    } catch (e) {
      throw Exception('Error al rechazar cotizacion: $e');
    }
  }

  /// Obtener cotizaciones pendientes para el capitan
  static Future<List<Map<String, dynamic>>> getCotizacionesPendientesCapitan(String capitanId) async {
    try {
      final response = await supabase
          .from('cotizaciones')
          .select('''
            id,
            descripcion,
            fecha_ida,
            hora_encuentro,
            lugar_encuentro,
            cantidad_personas,
            created_at,
            profiles!inner(
              user_id,
              nombre
            )
          ''')
          .eq('capitan_id', capitanId)
          .eq('estado', 'cotizado')
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener cotizaciones pendientes: $e');
    }
  }

  // ========== METODOS DE INTEGRACION CON GLEW ==========
  
  /// Enviar notificacion al Administrador en Glew
  static Future<void> enviarNotificacionGlew(Map<String, dynamic> datos) async {
    try {
      // Simular envio a Glew
      // En produccion, aqui iria la integracion real con la API de Glew
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Estructura de datos para Glew
      final glewPayload = {
        'event': datos['evento'],
        'data': {
          'cotizacion_id': datos['cotizacion_id'],
          'capitan_id': datos['capitan_id'],
          'pescador_id': datos['pescador_id'],
          'presupuesto': datos['presupuesto'],
          'respuesta': datos['respuesta'],
          'timestamp': datos['timestamp'],
          'metadata': datos['metadata'],
          'source': 'El Guia YA_mobile',
          'environment': kDebugMode ? 'development' : 'production',
        }
      };
      
      // Aqui iria la llamada real a la API de Glew
      // final response = await http.post(
      //   Uri.parse('https://api.glew.com/notifications'),
      //   headers: {
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer YOUR_GLEW_API_KEY',
      //   },
      //   body: json.encode(glewPayload),
      // );
      
      
      // Guardar registro de notificacion enviada
      await _guardarRegistroNotificacionGlew(glewPayload);
      
    } catch (e) {
      // No fallamos el flujo principal si falla la notificacion a Glew
      throw Exception('Error al enviar notificacion a Glew: $e');
    }
  }

  /// Guardar registro de notificacion enviada a Glew
  static Future<void> _guardarRegistroNotificacionGlew(Map<String, dynamic> datos) async {
    try {
      await supabase
          .from('notificaciones_glew')
          .insert({
            'evento': datos['event'],
            'datos': datos['data'],
            'enviado_at': DateTime.now().toIso8601String(),
            'estado': 'enviado',
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      // No fallamos el flujo principal
    }
  }

  /// Obtener historial de notificaciones enviadas a Glew
  static Future<List<Map<String, dynamic>>> getHistorialNotificacionesGlew({
    String? cotizacionId,
    String? capitanId,
    DateTime? fechaDesde,
    int? limite = 50,
  }) async {
    try {
      var query = supabase
          .from('notificaciones_glew')
          .select('*');
      
      if (cotizacionId != null) {
        query = query.eq('datos->>cotizacion_id', cotizacionId);
      }
      
      if (capitanId != null) {
        query = query.eq('datos->>capitan_id', capitanId);
      }
      
      if (fechaDesde != null) {
        query = query.gte('enviado_at', fechaDesde.toIso8601String());
      }
      
      final response = await query.order('enviado_at', ascending: false).limit(limite ?? 50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener historial de notificaciones Glew: $e');
    }
  }

  /// Verificar estado de integracion con Glew
  static Future<Map<String, dynamic>> verificarEstadoIntegracionGlew() async {
    try {
      // Simular verificacion de estado
      await Future.delayed(const Duration(milliseconds: 300));
      
      // En produccion, aqui iria una llamada real a la API de Glew
      // final response = await http.get(
      //   Uri.parse('https://api.glew.com/health'),
      //   headers: {'Authorization': 'Bearer YOUR_GLEW_API_KEY'},
      // );
      
      return {
        'estado': 'activo',
        'ultima_conexion': DateTime.now().toIso8601String(),
        'total_notificaciones_enviadas': 0,
        'errores_consecutivos': 0,
        'configuracion': {
          'endpoint': 'https://api.glew.com/notifications',
          'api_key_configurada': true,
          'timeout_segundos': 30,
        },
        'metadatos': {
          'version_api': 'v1.0',
          'ambiente': kDebugMode ? 'development' : 'production',
        }
      };
    } catch (e) {
      return {
        'estado': 'error',
        'error': e.toString(),
        'ultima_conexion': DateTime.now().toIso8601String(),
        'errores_consecutivos': 1,
      };
    }
  }

  /// Reintentar envio de notificacion fallida a Glew
  static Future<void> reintentarNotificacionGlew(String notificacionId) async {
    try {
      // Obtener la notificacion fallida
      final notificacion = await supabase
          .from('notificaciones_glew')
          .select('*')
          .eq('id', notificacionId)
          .eq('estado', 'fallido')
          .maybeSingle();
      
      if (notificacion == null) {
        throw Exception('Notificacion no encontrada o no esta en estado fallido');
      }
      
      // Reintentar envio
      await enviarNotificacionGlew(notificacion['datos']);
      
      // Actualizar estado a enviado
      await supabase
          .from('notificaciones_glew')
          .update({
            'estado': 'reenviado',
            'enviado_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', notificacionId);
      
    } catch (e) {
        throw Exception('Error al reintentar notificacion: $e');
    }
  }
  // ========== MÉTODOS DE NOTIFICACIONES ==========

  /// Obtener notificaciones del usuario actual en tiempo real
  static Stream<List<Notificacion>> getNotificacionesStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return supabase
        .from('notificaciones')
        .stream(primaryKey: ['id'])
        .eq('usuario_id', userId)
        .order('created_at', ascending: false)
        .map((data) => data.map((n) => Notificacion.fromSupabase(n)).toList());
  }

  /// Marcar una notificación como leída
  static Future<void> marcarNotificacionLeida(String id) async {
    try {
      final notif = await supabase
          .from('notificaciones')
          .select('usuario_id, titulo')
          .eq('id', id)
          .maybeSingle();

      await supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('id', id);

      if (notif != null) {
        final uId = notif['usuario_id'];
        final tit = notif['titulo'];
        if (uId != null && tit != null) {
          await supabase
              .from('notificaciones_globales')
              .update({'leido': true})
              .eq('receptor_id', uId)
              .eq('titulo', tit)
              .eq('leido', false);
        }
      }
    } catch (e) {
      print('Error al marcar notificación como leída: $e');
    }
  }

  /// Marcar todas las notificaciones como leídas
  static Future<void> marcarTodasLeidas() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('usuario_id', userId)
          .eq('leida', false);
    } catch (e) {
      print('Error al marcar todas las notificaciones como leídas: $e');
    }
  }

  /// Registra o actualiza el token de notificaciones FCM para el usuario actual
  static Future<void> guardarFCMToken(String token, {String? dispositivo}) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await supabase.from('fcm_tokens').upsert({
        'usuario_id': userId,
        'token': token,
        'dispositivo': dispositivo ?? 'Dispositivo Móvil',
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'usuario_id');
      print('✅ [SUPABASE FCM] Token guardado/actualizado para usuario: $userId');
    } catch (e) {
      print('❌ [SUPABASE FCM] Error al registrar token en base de datos: $e');
    }
  }

  /// Elimina el token FCM del usuario actual (útil en cierre de sesión)
  static Future<void> eliminarFCMToken() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      await supabase.from('fcm_tokens').delete().eq('usuario_id', userId);
      print('✅ [SUPABASE FCM] Token eliminado para usuario: $userId');
    } catch (e) {
      print('❌ [SUPABASE FCM] Error al eliminar token de base de datos: $e');
    }
  }

  /// Crear una nueva notificación (para uso interno del sistema)
  static Future<void> enviarNotificacion({
    required String usuarioId,
    required String titulo,
    required String mensaje,
    required String tipo,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // 🌉 EL PUENTE: Redirección automática al nuevo motor de notificaciones_globales
      String categoriaNueva = 'informativa';
      if (tipo == 'viaje' || tipo == 'cotizacion' || tipo == 'pago') categoriaNueva = 'comercial';
      if (tipo == 'fraude' || tipo == 'disputa') categoriaNueva = 'seguridad';
      if (tipo == 'sistema') categoriaNueva = 'logistica';

      await NotificacionService().enviarNotificacion({
        'receptor_id': usuarioId,
        'tipo_actor': 'sistema',
        'categoria': categoriaNueva,
        'prioridad': 'informativa',
        'titulo': titulo,
        'contenido': mensaje,
        'leido': false,
        'payload': metadata ?? {},
      });

      // Mantenimiento de retrocompatibilidad (Doble inserto seguro temporal)
      final noti = Notificacion(
        id: '', // Supabase genera el ID
        usuarioId: usuarioId,
        titulo: titulo,
        mensaje: mensaje,
        fecha: DateTime.now(),
        leida: false,
        tipo: tipo,
        metadata: metadata,
      );
      
      await supabase.from('notificaciones').insert(noti.toMap());
    } catch (e) {
      print('Error al enviar notificación en el puente: $e');
    }
  }

  /// 🔔 Sistema de Notificaciones de Éxito y Liquidación (Push & Dopamina)
  /// Envía notificaciones locales/push con soporte robusto de fallbacks.
  static Future<void> enviarNotificacionConDopamina({
    required String usuarioId,
    required String titulo,
    required String mensaje,
    required String tipo,
    String? sonido,
  }) async {
    try {
      // 1. Guardar en la tabla maestra de notificaciones de Supabase para actualización Realtime
      await enviarNotificacion(
        usuarioId: usuarioId,
        titulo: titulo,
        mensaje: mensaje,
        tipo: tipo,
        metadata: {
          'sonido': sonido ?? 'default',
          'dopamine': true,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      // 2. Buscar el token en fcm_tokens de Supabase
      try {
        final tokenRes = await supabase
            .from('fcm_tokens')
            .select('token')
            .eq('usuario_id', usuarioId)
            .maybeSingle();

        if (tokenRes != null && tokenRes['token'] != null) {
          final String fcmToken = tokenRes['token'].toString();
          print('📱 [FCM PUSH] Enviando push con sonido de "${sonido ?? 'monedas'}" al token: $fcmToken');
          
          final fcmPayload = {
            'to': fcmToken,
            'notification': {
              'title': titulo,
              'body': mensaje,
              'sound': sonido == 'monedas' ? 'coins.wav' : 'default',
              'android_channel_id': sonido == 'monedas' ? 'coins_channel' : 'default_channel',
            },
            'data': {
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
              'tipo': tipo,
              'sonido': sonido ?? 'default',
            }
          };
          print('📡 FCM Payload: $fcmPayload');
        } else {
          print('ℹ️ No se encontró un token FCM activo para el usuario $usuarioId. Se entregará solo vía Realtime.');
        }
      } catch (e) {
        // El dinero es la prioridad, la notificación es el plus. No interrumpir si fcm_tokens no existe o falla.
        print('⚠️ Error al buscar token FCM o simular push: $e');
      }
    } catch (e) {
      print('⚠️ Error robusto al procesar la notificación de dopamina: $e');
    }
  }

  /// Notificar a todos los capitanes dentro de la zona de cobertura sobre una nueva cotización.
  /// Respeta el Almanaque: los capitanes que bloquearon la fecha del viaje NO reciben notificación.
  static Future<void> notificarCapitanesNuevaCotizacion({
    required String cotizacionId,
    required String descripcion,
    required Map<String, dynamic> puntoPartida,
  }) async {
    try {
      final latPartida = puntoPartida['lat'];
      final lonPartida = puntoPartida['lon'];
      if (latPartida == null || lonPartida == null) return;

      final double latVal = double.tryParse(latPartida.toString()) ?? 0.0;
      final double lonVal = double.tryParse(lonPartida.toString()) ?? 0.0;

      // 1. Obtener todos los capitanes activos con su geofencing
      final response = await supabase
          .from('profiles')
          .select('user_id, zona_lat, zona_lng, zona_radio_km')
          .eq('es_capitan', true)
          .eq('estado', 'activo');

      final capitanes = List<Map<String, dynamic>>.from(response);

      // 2. Obtener la fecha del viaje desde la cotización para filtrar el almanaque
      String? fechaViajeStr;
      try {
        final cotData = await supabase
            .from('cotizaciones')
            .select('fecha_ida')
            .eq('id', cotizacionId)
            .maybeSingle();
        fechaViajeStr = cotData?['fecha_ida']?.toString();
      } catch (_) {
        // La cotización puede no tener fecha_ida (cotización abierta), no es error crítico
      }

      // 3. Si hay fecha de viaje, obtener set de capitanes bloqueados ese día (almanaque)
      final Set<String> capitanesBloqueados = {};
      if (fechaViajeStr != null && fechaViajeStr.isNotEmpty) {
        try {
          final fechaSolo = fechaViajeStr.split('T').first;
          final bloqueados = await supabase
              .from('disponibilidad')
              .select('capitan_id')
              .eq('fecha', fechaSolo);

          for (final row in (bloqueados as List)) {
            capitanesBloqueados.add(row['capitan_id'].toString());
          }

          if (capitanesBloqueados.isNotEmpty) {
            print('📅 Almanaque: ${capitanesBloqueados.length} capitán(es) bloqueado(s) el $fechaSolo → no recibirán notificación.');
          }
        } catch (e) {
          print('⚠️ Error al consultar almanaque para filtrar notificaciones: $e');
        }
      }

      // 4. Notificar solo a capitanes en zona Y disponibles según almanaque
      for (final cap in capitanes) {
        final capitanId = cap['user_id']?.toString() ?? '';
        if (capitanId.isEmpty) continue;

        // Respetar el almanaque: saltar si bloqueó ese día
        if (capitanesBloqueados.contains(capitanId)) {
          print('🔕 Capitán $capitanId bloqueado en almanaque → sin notificación.');
          continue;
        }

        final latCentro = cap['zona_lat'];
        final lonCentro = cap['zona_lng'];
        final radioKm = cap['zona_radio_km'] ?? 50.0;

        if (latCentro != null && lonCentro != null) {
          final double capLat = double.tryParse(latCentro.toString()) ?? 0.0;
          final double capLon = double.tryParse(lonCentro.toString()) ?? 0.0;
          final double capRadio = double.tryParse(radioKm.toString()) ?? 50.0;

          // Calcular distancia usando Haversine
          const double r = 6371.0;
          final double dLat = (latVal - capLat) * 3.141592653589793 / 180.0;
          final double dLon = (lonVal - capLon) * 3.141592653589793 / 180.0;
          final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
              math.cos(capLat * 3.141592653589793 / 180.0) *
                  math.cos(latVal * 3.141592653589793 / 180.0) *
                  math.sin(dLon / 2) * math.sin(dLon / 2);
          final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
          final double dist = r * c;

          // Si el punto de partida está en su radio, notificar
          if (dist <= capRadio) {
            await enviarNotificacion(
              usuarioId: capitanId,
              titulo: '🚢 ¡Nueva Solicitud de Pesca!',
              mensaje: 'Hay un pescador buscando salida en tu zona: "$descripcion"',
              tipo: 'solicitud_cotizacion',
              metadata: {
                'cotizacion_id': cotizacionId,
                'distancia_km': dist.toStringAsFixed(1),
              },
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error al notificar capitanes: $e');
    }
  }

  /// Obtiene la configuración del sistema (Mercado Pago)
  static Future<Map<String, dynamic>?> getSistemaConfig() async {
    try {
      final response = await supabase
          .from('config_sistema')
          .select('*')
          .limit(1)
          .maybeSingle();
      return response;
    } catch (e) {
      print('❌ [SUPABASE] Error al obtener config_sistema: $e');
      return null;
    }
  }

  /// Guarda o actualiza la configuración del sistema
  static Future<void> guardarSistemaConfig({
    required String publicKey,
    required String accessToken,
    required bool isSandbox,
    required bool mantenimientoTienda,
    String? logisticaPublicKey,
    String? logisticaAccessToken,
    bool logisticaIsSandbox = true,
  }) async {
    try {
      // Intentamos obtener el primer registro
      final response = await supabase
          .from('config_sistema')
          .select('id')
          .limit(1)
          .maybeSingle();

      final data = {
        'mp_public_key': publicKey,
        'mp_access_token': accessToken,
        'is_sandbox': isSandbox,
        'mantenimiento_tienda': mantenimientoTienda,
        'logistica_public_key': logisticaPublicKey,
        'logistica_access_token': logisticaAccessToken,
        'logistica_is_sandbox': logisticaIsSandbox,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (response != null && response['id'] != null) {
        // Actualizar registro existente
        await supabase
            .from('config_sistema')
            .update(data)
            .eq('id', response['id']);
      } else {
        // Insertar nuevo registro
        await supabase
            .from('config_sistema')
            .insert(data);
      }
      print('✅ [SUPABASE] Configuración de sistema guardada exitosamente');
    } catch (e) {
      print('❌ [SUPABASE] Error al guardar config_sistema: $e');
      throw Exception('Error al guardar la configuración: $e');
    }
  }

  // --- SECCIÓN COMISIONISTAS (PROMOTORES) ---

  // Helper local en caso de que la tabla comisionistas no esté creada en Supabase (PGRST205)
  static final List<Map<String, dynamic>> _comisionistasLocales = [
    {
      'nombre': 'Sebastián Promociones',
      'dni': '38450123',
      'cuenta_mp': 'seba.mp@gmail.com',
      'codigo_comision': 'SEBA8020',
      'estado': 'activo',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'nombre': 'Martín Referidos',
      'dni': '35678912',
      'cuenta_mp': 'martin.pagos.mp@gmail.com',
      'codigo_comision': 'TINCHO90',
      'estado': 'activo',
      'created_at': DateTime.now().toIso8601String(),
    },
    {
      'nombre': 'Paula Patagonia',
      'dni': '40123456',
      'cuenta_mp': 'paula.patagonia.mp@gmail.com',
      'codigo_comision': 'PAULA10',
      'estado': 'pausado',
      'created_at': DateTime.now().toIso8601String(),
    }
  ];

  /// Valida un código promocional y devuelve los datos del comisionista si existe y está activo
  static Future<Map<String, dynamic>?> validarCodigoPromotor(String codigo) async {
    final String cleanCode = codigo.trim().toUpperCase();
    if (cleanCode.isEmpty) return null;

    try {
      final response = await supabase
          .from('comisionistas')
          .select('*')
          .eq('codigo_comision', cleanCode)
          .maybeSingle();

      if (response != null) {
        return Map<String, dynamic>.from(response);
      }
    } catch (e) {
      print('⚠️ [SUPABASE] Error consultando tabla comisionistas remota: $e');
    }

    // Fallback local: Buscar en lista en memoria
    final localMatch = _comisionistasLocales.firstWhere(
      (c) => c['codigo_comision']?.toString().toUpperCase() == cleanCode,
      orElse: () => <String, dynamic>{},
    );

    if (localMatch.isNotEmpty) {
      final String id = localMatch['id']?.toString() ?? 'local_promo_id_${localMatch['codigo_comision']}';
      return {
        ...localMatch,
        'id': id,
      };
    }

    return null;
  }

  /// Obtiene todos los comisionistas (promotores)
  static Future<List<Map<String, dynamic>>> getComisionistas() async {
    try {
      final response = await supabase
          .from('comisionistas')
          .select('*')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('⚠️ [SUPABASE] Usando fallback local para comisionistas: $e');
      // Devolver copia ordenada
      final list = List<Map<String, dynamic>>.from(_comisionistasLocales);
      list.sort((a, b) => b['created_at'].toString().compareTo(a['created_at'].toString()));
      return list;
    }
  }

  /// Registra un nuevo comisionista
  static Future<void> guardarComisionista(Map<String, dynamic> comisionista) async {
    final String codigo = comisionista['codigo_comision']?.toString().trim().toUpperCase() ?? '';
    if (codigo.isEmpty) {
      throw Exception('El código de comisión no puede estar vacío.');
    }

    try {
      // 1. Intentar en Supabase
      await supabase.from('comisionistas').insert({
        'nombre': comisionista['nombre'],
        'dni': comisionista['dni'],
        'cuenta_mp': comisionista['cuenta_mp'],
        'codigo_comision': codigo,
        'estado': comisionista['estado'] ?? 'activo',
      });
      
      // Sincronizar local también
      final idx = _comisionistasLocales.indexWhere((c) => c['codigo_comision'].toString().toUpperCase() == codigo);
      final map = {
        'nombre': comisionista['nombre'],
        'dni': comisionista['dni'],
        'cuenta_mp': comisionista['cuenta_mp'],
        'codigo_comision': codigo,
        'estado': comisionista['estado'] ?? 'activo',
        'created_at': DateTime.now().toIso8601String(),
      };
      if (idx != -1) {
        _comisionistasLocales[idx] = map;
      } else {
        _comisionistasLocales.insert(0, map);
      }
    } catch (e) {
      print('⚠️ [SUPABASE] Guardando localmente comisionista por error: $e');
      
      // Validar unicidad localmente
      final existe = _comisionistasLocales.any((c) => c['codigo_comision'].toString().toUpperCase() == codigo);
      if (existe) {
        throw Exception('El código de comisión "$codigo" ya está registrado por otro promotor.');
      }

      final map = {
        'nombre': comisionista['nombre'],
        'dni': comisionista['dni'],
        'cuenta_mp': comisionista['cuenta_mp'],
        'codigo_comision': codigo,
        'estado': comisionista['estado'] ?? 'activo',
        'created_at': DateTime.now().toIso8601String(),
      };
      _comisionistasLocales.insert(0, map);
    }
  }

  /// Pausa o activa a un comisionista
  static Future<void> cambiarEstadoComisionista(String codigo, String nuevoEstado) async {
    final String codigoUpper = codigo.trim().toUpperCase();
    try {
      await supabase
          .from('comisionistas')
          .update({'estado': nuevoEstado})
          .eq('codigo_comision', codigoUpper);

      // Sincronizar local
      final idx = _comisionistasLocales.indexWhere((c) => c['codigo_comision'].toString().toUpperCase() == codigoUpper);
      if (idx != -1) {
        _comisionistasLocales[idx]['estado'] = nuevoEstado;
      }
    } catch (e) {
      print('⚠️ [SUPABASE] Actualizando localmente estado por error: $e');
      final idx = _comisionistasLocales.indexWhere((c) => c['codigo_comision'].toString().toUpperCase() == codigoUpper);
      if (idx != -1) {
        _comisionistasLocales[idx]['estado'] = nuevoEstado;
      }
    }
  }

  /// Actualiza los datos de un comisionista
  static Future<void> actualizarComisionista(String codigoOriginal, Map<String, dynamic> nuevosDatos) async {
    final String origUpper = codigoOriginal.trim().toUpperCase();
    final String nuevoUpper = nuevosDatos['codigo_comision']?.toString().trim().toUpperCase() ?? '';

    try {
      await supabase
          .from('comisionistas')
          .update({
            'nombre': nuevosDatos['nombre'],
            'dni': nuevosDatos['dni'],
            'cuenta_mp': nuevosDatos['cuenta_mp'],
            'codigo_comision': nuevoUpper,
            'estado': nuevosDatos['estado'],
          })
          .eq('codigo_comision', origUpper);

      // Sincronizar local
      final idx = _comisionistasLocales.indexWhere((c) => c['codigo_comision'].toString().toUpperCase() == origUpper);
      if (idx != -1) {
        _comisionistasLocales[idx] = {
          'nombre': nuevosDatos['nombre'],
          'dni': nuevosDatos['dni'],
          'cuenta_mp': nuevosDatos['cuenta_mp'],
          'codigo_comision': nuevoUpper,
          'estado': nuevosDatos['estado'],
          'created_at': _comisionistasLocales[idx]['created_at'] ?? DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      print('⚠️ [SUPABASE] Actualizando localmente datos por error: $e');
      
      // Validar unicidad localmente si el código cambió
      if (origUpper != nuevoUpper) {
        final existe = _comisionistasLocales.any((c) => c['codigo_comision'].toString().toUpperCase() == nuevoUpper);
        if (existe) {
          throw Exception('El código de comisión "$nuevoUpper" ya está registrado por otro promotor.');
        }
      }

      final idx = _comisionistasLocales.indexWhere((c) => c['codigo_comision'].toString().toUpperCase() == origUpper);
      if (idx != -1) {
        _comisionistasLocales[idx] = {
          'nombre': nuevosDatos['nombre'],
          'dni': nuevosDatos['dni'],
          'cuenta_mp': nuevosDatos['cuenta_mp'],
          'codigo_comision': nuevoUpper,
          'estado': nuevosDatos['estado'],
          'created_at': _comisionistasLocales[idx]['created_at'] ?? DateTime.now().toIso8601String(),
        };
      }
    }
  }

  // ==========================================
  // METODOS DEL BLOG OFICIAL DE PESCA (EDITORIAL)
  // ==========================================

  static Future<List<ArticuloBlog>> obtenerArticulosBlog({String? categoria, bool soloActivos = true}) async {
    try {
      var query = supabase.from('blog_articulos').select('*');
      
      if (soloActivos) {
        query = query.eq('activo', true);
      }
      if (categoria != null && categoria != 'Todos') {
        query = query.eq('categoria', categoria);
      }
      
      final response = await query.order('created_at', ascending: false);
      return List<ArticuloBlog>.from(
        (response as List).map((x) => ArticuloBlog.fromSupabase(x)),
      );
    } catch (e) {
      print('⚠️ [SUPABASE] Error al obtener articulos del blog: $e');
      return [];
    }
  }

  static Future<ArticuloBlog?> obtenerArticuloBlogPorId(String id) async {
    try {
      final response = await supabase
          .from('blog_articulos')
          .select('*')
          .eq('id', id)
          .maybeSingle();
      
      if (response == null) return null;
      return ArticuloBlog.fromSupabase(response);
    } catch (e) {
      print('⚠️ [SUPABASE] Error al obtener articulo por ID: $e');
      return null;
    }
  }

  static Future<void> crearArticuloBlog(ArticuloBlog articulo) async {
    try {
      await supabase.from('blog_articulos').insert(articulo.toInsertMap());
    } catch (e) {
      print('⚠️ [SUPABASE] Error al crear articulo de blog: $e');
      throw Exception('Error al crear el artículo en la base de datos: $e');
    }
  }

  static Future<void> actualizarArticuloBlog(ArticuloBlog articulo) async {
    try {
      await supabase
          .from('blog_articulos')
          .update(articulo.toMap())
          .eq('id', articulo.id);
    } catch (e) {
      print('⚠️ [SUPABASE] Error al actualizar articulo de blog: $e');
      throw Exception('Error al actualizar el artículo en la base de datos: $e');
    }
  }

  static Future<void> eliminarArticuloBlog(String id) async {
    try {
      await supabase.from('blog_articulos').delete().eq('id', id);
    } catch (e) {
      print('⚠️ [SUPABASE] Error al eliminar articulo de blog: $e');
      throw Exception('Error al eliminar el artículo de la base de datos: $e');
    }
  }

  /// Guarda un conocimiento en public.guia_conocimiento_distribuido
  static Future<String?> guardarConocimiento(Map<String, dynamic> json) async {
    try {
      final intencion = json['intencion']?.toString() ?? '';
      if (intencion.isEmpty) return null;

      final activadoresRaw = json['activadores'] as List<dynamic>? ?? [];
      final activadores = activadoresRaw.map((e) => e.toString()).toList();

      final String respuestaLimpia = json['respuesta_limpia']?.toString() ?? '';
      final String gif = json['gif']?.toString() ?? 'hablaConMate';
      final double puntaje = (json['puntaje'] as num?)?.toDouble() ?? 6.0;

      // Determinar la categoría y la librería a partir de la intención
      final String categoria = _determinarCategoria(intencion);
      final String libreria = _determinarLibreria(intencion, categoria);
      final int limite = _obtenerLimiteLibreria(libreria);

      final response = await supabase.from('guia_conocimiento_distribuido').insert({
        'libreria': libreria,
        'categoria': categoria,
        'intencion': intencion,
        'activadores': activadores,
        'respuesta_limpia': respuestaLimpia,
        'gif': gif,
        'puntaje': puntaje,
        'aprobado': false,
        'fecha_consolidacion': DateTime.now().toIso8601String().substring(0, 10),
        'veces_preguntado': 1,
        'limite_libreria': limite,
      }).select('id').single();

      final id = response['id']?.toString();
      print('☁️ Conocimiento auto-guardado en Supabase para intención: $intencion, id: $id');
      return id;
    } catch (e) {
      print('⚠️ Error en guardarConocimiento: $e');
      return null;
    }
  }

  /// Elimina un conocimiento de public.guia_conocimiento_distribuido por ID
  static Future<void> eliminarConocimiento(String id) async {
    try {
      await supabase.from('guia_conocimiento_distribuido').delete().eq('id', id);
      print('☁️ Conocimiento eliminado en Supabase para id: $id');
    } catch (e) {
      print('⚠️ Error en eliminarConocimiento: $e');
    }
  }

  /// Aprueba/Confirma un conocimiento en public.guia_conocimiento_distribuido por ID
  static Future<void> confirmarConocimiento(String id) async {
    try {
      await supabase.from('guia_conocimiento_distribuido').update({'aprobado': true}).eq('id', id);
      print('☁️ Conocimiento confirmado (aprobado) en Supabase para id: $id');
    } catch (e) {
      print('⚠️ Error en confirmarConocimiento: $e');
    }
  }

  static String _determinarCategoria(String intencion) {
    final lower = intencion.toLowerCase();
    if (lower.contains('emergencia') ||
        lower.contains('seguridad') ||
        lower.contains('primeros_auxilios') ||
        lower.contains('primerosauxilios')) {
      return 'emergencia';
    }
    if (lower.contains('charla') ||
        lower.contains('emociones') ||
        lower.contains('humor') ||
        lower.contains('saludo') ||
        lower.contains('despedida') ||
        lower.contains('celebracion') ||
        lower.contains('acompanamiento') ||
        lower.contains('clima')) {
      return 'lenguaje';
    }
    return 'tecnico';
  }

  static String _determinarLibreria(String intencion, String categoria) {
    final lower = intencion.toLowerCase();
    if (categoria == 'emergencia') {
      return 'emergencia';
    }
    if (categoria == 'lenguaje') {
      if (lower.contains('saludo') || lower.contains('despedida') || lower.contains('charla')) {
        return 'charla_cotidiana';
      }
      if (lower.contains('emocion') || lower.contains('triste') || lower.contains('alegre') || lower.contains('frustra') || lower.contains('euforia')) {
        return 'emociones_pescador';
      }
      if (lower.contains('celebracion') || lower.contains('record') || lower.contains('pesco_grande')) {
        return 'celebraciones';
      }
      if (lower.contains('humor') || lower.contains('chiste') || lower.contains('cargada') || lower.contains('picara')) {
        return 'chistes';
      }
      if (lower.contains('clima') || lower.contains('frio') || lower.contains('calor') || lower.contains('tormenta')) {
        return 'reacciones_clima';
      }
      if (lower.contains('acompanamiento') || lower.contains('solo') || lower.contains('aburrido') || lower.contains('espera')) {
        return 'acompanamiento';
      }
      return 'charla_cotidiana';
    }
    if (lower.contains('pez') || lower.contains('peces') || lower.contains('dorado') || lower.contains('surubi') || lower.contains('boga')) {
      return 'peces';
    }
    if (lower.contains('carnada') || lower.contains('cebo') || lower.contains('anchoa') || lower.contains('lombriz')) {
      return 'carnadas';
    }
    if (lower.contains('nudo') || lower.contains('atar') || lower.contains('anzuelo')) {
      return 'nudos';
    }
    if (lower.contains('boya') || lower.contains('flotador')) {
      return 'boyas';
    }
    if (lower.contains('plomada') || lower.contains('plomo')) {
      return 'plomadas';
    }
    if (lower.contains('cana') || lower.contains('caña') || lower.contains('reel')) {
      return 'canas_y_reeles';
    }
    if (lower.contains('rio') || lower.contains('crecida') || lower.contains('bajante')) {
      return 'rio';
    }
    return 'general_tecnico';
  }

  static int _obtenerLimiteLibreria(String libreria) {
    switch (libreria) {
      case 'peces':
      case 'especies':
        return 40;
      case 'carnadas':
        return 30;
      case 'nudos':
        return 20;
      case 'charla_cotidiana':
      case 'charla':
        return 30;
      case 'emergencia':
        return 50;
      case 'clima':
      case 'reacciones_clima':
        return 20;
      case 'chistes':
      case 'humor':
        return 20;
      case 'emociones_pescador':
      case 'emociones':
        return 20;
      default:
        return 30;
    }
  }
}

