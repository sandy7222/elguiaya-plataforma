import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class GpsTrackerService {
  static final GpsTrackerService _instance = GpsTrackerService._internal();
  factory GpsTrackerService() => _instance;
  GpsTrackerService._internal();

  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;

  /// Inicia el rastreo del pescador y actualiza Supabase automáticamente
  Future<void> startTracking(String userId) async {
    if (_isTracking) return;

    bool serviceEnabled;
    LocationPermission permission;

    // Verificar si el servicio GPS está activado
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('El servicio de GPS está desactivado.');
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('Permiso de GPS denegado por el usuario.');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('Los permisos de ubicación están permanentemente denegados.');
      return;
    }

    _isTracking = true;
    
    // Configuración del stream
    late LocationSettings locationSettings;
    
    if (defaultTargetPlatform == TargetPlatform.android) {
      locationSettings = AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15, // Actualizar solo si se mueve más de 15 metros
          forceLocationManager: true,
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      locationSettings = AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 15, // Actualizar solo si se mueve más de 15 metros
        pauseLocationUpdatesAutomatically: true,
      );
    } else {
        locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15, // Actualizar solo si se mueve más de 15 metros
      );
    }

    debugPrint('🚀 [GPS] Iniciando rastreo en vivo para $userId...');

    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (Position position) async {
        debugPrint('📍 [GPS] Nueva posición detectada: ${position.latitude}, ${position.longitude}');
        
        try {
          // Usamos las columnas zona_lat y zona_lng que enganchan perfecto con el Trigger de Supabase
          await Supabase.instance.client
              .from('profiles')
              .update({
                'zona_lat': position.latitude,
                'zona_lng': position.longitude,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('user_id', userId);
              
          debugPrint('✅ [GPS] Base de datos actualizada con éxito. ¡Trigger activado!');
        } catch (e) {
          debugPrint('❌ [GPS] Error al actualizar la base de datos: $e');
        }
      },
      onError: (e) {
        debugPrint('❌ [GPS] Error leyendo el flujo GPS: $e');
      }
    );
  }

  /// Detiene el rastreo para ahorrar batería
  void stopTracking() {
    if (!_isTracking) return;
    debugPrint('🛑 [GPS] Deteniendo rastreo...');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
    _isTracking = false;
  }
}
