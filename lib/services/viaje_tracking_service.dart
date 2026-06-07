import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

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

  /// FIN DEL RASTREO
  Future<void> stopTracking() async {
    await _syncTrackToSupabase(); // Última sincronización antes de cerrar
    _trackingTimer?.cancel();
    _syncTimer?.cancel();
    _trackingTimer = null;
    _syncTimer = null;
    _currentTripId = null;
    print('🛑 Auditor GPS detenido.');
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
