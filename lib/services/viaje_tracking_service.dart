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
  String _currentRol = 'capitan';

  List<Map<String, dynamic>> _currentTrack = [];

  bool get isTracking => _trackingTimer != null;
  String? get currentTripId => _currentTripId;
  String get currentRol => _currentRol;
  List<Map<String, dynamic>> get memoryPoints =>
      List<Map<String, dynamic>>.from(_currentTrack);

  Future<void> requestPermissionSilently() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> startTracking({
    required String tripId,
    String rol = 'capitan',
  }) async {
    if (isTracking && _currentTripId == tripId && _currentRol == rol) return;

    if (isTracking) {
      await stopTracking();
    }

    _currentTripId = tripId;
    _currentRol = rol;
    _currentTrack = [];

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) return;

    await _captureLocation();

    _trackingTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      await _captureLocation();
    });

    _syncTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await _syncTrackToSupabase();
    });

    print('🛰️ Auditor GPS activado para el viaje: $tripId (rol: $rol)');
  }

  Future<void> _captureLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      final point = {
        'lat': position.latitude,
        'lng': position.longitude,
        'ts': DateTime.now().toIso8601String(),
        'rol': _currentRol,
      };

      _currentTrack.add(point);
    } catch (e) {
      print('⚠️ Error capturando ubicación: $e');
    }
  }

  Future<void> _syncTrackToSupabase() async {
    if (_currentTripId == null || _currentTrack.isEmpty) return;

    if (_currentTripId!.startsWith('manual-')) {
      print('🛰️ [TRACKING] Acumulando puntos localmente en memoria para viaje manual...');
      return;
    }

    try {
      final res = await _supabase
          .from('pedidos')
          .select('track_log')
          .eq('id', _currentTripId!)
          .single();

      List<dynamic> existingLog =
          res['track_log'] != null ? List.from(res['track_log']) : [];
      existingLog.addAll(_currentTrack);

      await _supabase
          .from('pedidos')
          .update({'track_log': existingLog})
          .eq('id', _currentTripId!);

      _currentTrack = [];
      print('✅ Sincronización GPS exitosa.');
    } catch (e) {
      print('❌ Error al sincronizar track_log: $e');
    }
  }

  Future<List<Map<String, dynamic>>> stopTracking() async {
    final collectedPoints = List<Map<String, dynamic>>.from(_currentTrack);
    await _syncTrackToSupabase();
    _trackingTimer?.cancel();
    _syncTimer?.cancel();
    _trackingTimer = null;
    _syncTimer = null;
    _currentTripId = null;
    _currentRol = 'capitan';
    _currentTrack = [];
    print('🛑 Auditor GPS detenido.');
    return collectedPoints;
  }

  static Future<List<dynamic>> fetchTrackLog(String pedidoId) async {
    try {
      final res = await Supabase.instance.client
          .from('pedidos')
          .select('track_log')
          .eq('id', pedidoId)
          .maybeSingle();
      if (res == null || res['track_log'] == null) return [];
      return List<dynamic>.from(res['track_log'] as List);
    } catch (e) {
      print('❌ Error leyendo track_log: $e');
      return [];
    }
  }

  Future<void> saveManualTrackLocal({
    required String tripId,
    required String name,
    required String durationStr,
    required List<LatLng> points,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? existingData = prefs.getString('manual_tracks');
      List<dynamic> tracksList =
          existingData != null ? json.decode(existingData) : [];

      final serializedPoints = points
          .map((p) => {
                'lat': p.latitude,
                'lng': p.longitude,
              })
          .toList();

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

  static List<LatLng> parseTrackLog(dynamic trackLog, {String? rol}) {
    if (trackLog == null || trackLog is! List) return [];

    return trackLog
        .where((point) {
          if (rol == null) return true;
          final p = point as Map<String, dynamic>;
          final pointRol = p['rol']?.toString() ?? 'capitan';
          return pointRol == rol;
        })
        .map((point) {
          final p = point as Map<String, dynamic>;
          return LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          );
        })
        .toList();
  }

  static List<LatLng> parseTrackLogCapitan(dynamic trackLog) =>
      parseTrackLog(trackLog, rol: 'capitan');

  static List<LatLng> parseTrackLogPescador(dynamic trackLog) =>
      parseTrackLog(trackLog, rol: 'pescador');
}
