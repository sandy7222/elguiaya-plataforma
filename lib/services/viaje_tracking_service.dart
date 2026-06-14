import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ViajeTrackingService {
  static final ViajeTrackingService _instance = ViajeTrackingService._internal();
  factory ViajeTrackingService() => _instance;
  ViajeTrackingService._internal();

  final _supabase = Supabase.instance.client;
  Timer? _trackingTimer;
  Timer? _syncTimer;
  String? _currentTripId;
  
  // Acumulador de puntos en memoria para ahorro de batería
  List<Map<String, dynamic>> _currentTrack = [];

  bool get isTracking => _trackingTimer != null;

  /// SOLICITUD SILENCIOSA DE PERMISOS
  Future<void> requestPermissionSilently() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  /// INICIO DEL RASTREO (Se activa al cambiar a 'En Curso')
  Future<void> startTracking({required String tripId}) async {
    if (isTracking) return;
    
    _currentTripId = tripId;
    _currentTrack = [];
    
    // 1. Verificar permisos de forma silenciosa
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    
    if (permission == LocationPermission.deniedForever) return;

    // 2. Timer de Captura (Cada 15 segundos)
    _trackingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _captureLocation();
    });

    // 3. Timer de Sincronización (Cada 5 minutos)
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _syncTrackToSupabase();
    });
    
    print('🛰️ Auditor GPS activado para el viaje: $tripId');
  }

  /// CAPTURA SILENCIOSA
  Future<void> _captureLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Balance entre precisión y batería
      );
      
      final point = {
        'lat': position.latitude,
        'lng': position.longitude,
        'ts': DateTime.now().toIso8601String(),
      };
      
      _currentTrack.add(point);
    } catch (e) {
      print('⚠️ Error capturando ubicación: $e');
    }
  }

  /// SINCRONIZACIÓN EN BLOQUE (JSON)
  Future<void> _syncTrackToSupabase() async {
    if (_currentTripId == null || _currentTrack.isEmpty) return;
    
    // Si es un viaje manual, no lo subimos a Supabase de esta forma (se guarda localmente al finalizar)
    if (_currentTripId!.startsWith('manual-')) {
      print('🛰️ [TRACKING] Acumulando puntos localmente en memoria para viaje manual...');
      return;
    }
    
    try {
      // Obtenemos el log actual para no sobreescribir (opcional, pero seguro)
      final res = await _supabase
          .from('pedidos')
          .select('track_log')
          .eq('id', _currentTripId!)
          .single();
      
      List<dynamic> existingLog = res['track_log'] != null ? List.from(res['track_log']) : [];
      existingLog.addAll(_currentTrack);

      await _supabase
          .from('pedidos')
          .update({'track_log': existingLog})
          .eq('id', _currentTripId!);
      
      // Limpiamos el acumulador de memoria tras sincronizar con éxito
      _currentTrack = [];
      print('✅ Sincronización GPS exitosa.');
    } catch (e) {
      print('❌ Error al sincronizar track_log: $e');
    }
  }

  /// FIN DEL RASTREO (Retorna los puntos acumulados para poder procesarlos en memoria si es manual)
  Future<List<Map<String, dynamic>>> stopTracking() async {
    final collectedPoints = List<Map<String, dynamic>>.from(_currentTrack);
    await _syncTrackToSupabase(); // Última sincronización antes de cerrar
    _trackingTimer?.cancel();
    _syncTimer?.cancel();
    _trackingTimer = null;
    _syncTimer = null;
    _currentTripId = null;
    _currentTrack = [];
    print('🛑 Auditor GPS detenido.');
    return collectedPoints;
  }

  // --- MÉTODOS DE CACHÉ LOCAL (COMPRADOR / CAPITÁN) ---

  /// Guarda una ruta manual en SharedPreferences
  Future<void> saveManualTrackLocal({
    required String tripId,
    required String name,
    required String durationStr,
    required List<LatLng> points,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString('manual_tracks');
      List<dynamic> tracksList = existingData != null ? json.decode(existingData) : [];
      
      final serializedPoints = points.map((p) => {
        'lat': p.latitude,
        'lng': p.longitude,
      }).toList();

      final newTrack = {
        'id': tripId,
        'nombre': name,
        'fecha': DateTime.now().toIso8601String(),
        'duracion': durationStr,
        'puntos': serializedPoints,
      };
      
      tracksList.add(newTrack);
      await prefs.setString('manual_tracks', json.encode(tracksList));
      print('💾 Ruta manual guardada localmente: $name ($tripId)');
    } catch (e) {
      print('❌ Error guardando ruta manual localmente: $e');
    }
  }

  /// Obtiene la lista de rutas manuales guardadas localmente
  Future<List<Map<String, dynamic>>> getManualTracksLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString('manual_tracks');
      if (existingData == null) return [];
      
      final List<dynamic> decoded = json.decode(existingData);
      return List<Map<String, dynamic>>.from(decoded);
    } catch (e) {
      print('❌ Error al obtener rutas manuales: $e');
      return [];
    }
  }

  /// Elimina una ruta manual guardada localmente
  Future<void> deleteManualTrackLocal(String tripId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString('manual_tracks');
      if (existingData == null) return;
      
      List<dynamic> tracksList = json.decode(existingData);
      tracksList.removeWhere((track) => track['id'] == tripId);
      await prefs.setString('manual_tracks', json.encode(tracksList));
      print('🗑️ Ruta manual eliminada: $tripId');
    } catch (e) {
      print('❌ Error al eliminar ruta manual: $e');
    }
  }

  // --- HERRAMIENTAS PARA EL ADMIN ---

  /// Transforma el track_log JSON en una lista de LatLng para dibujar en el mapa
  static List<LatLng> parseTrackLog(dynamic trackLog) {
    if (trackLog == null || trackLog is! List) return [];
    
    return trackLog.map((point) {
      final p = point as Map<String, dynamic>;
      return LatLng(p['lat'] as double, p['lng'] as double);
    }).toList();
  }
}
