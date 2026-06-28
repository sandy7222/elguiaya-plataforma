import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'gps_tracker_service.dart';
import 'viaje_tracking_service.dart';

/// Rol del usuario en el tracking del viaje.
enum ViajeGpsRol {
  capitan('capitan'),
  pescador('pescador');

  const ViajeGpsRol(this.value);
  final String value;

  static ViajeGpsRol? fromString(String? raw) {
    if (raw == null) return null;
    for (final r in ViajeGpsRol.values) {
      if (r.value == raw) return r;
    }
    return null;
  }
}

/// Orquesta GPS en vivo + auditoría de ruta al iniciar/finalizar un viaje.
class ViajeGpsCoordinator {
  static final ViajeGpsCoordinator _instance = ViajeGpsCoordinator._internal();
  factory ViajeGpsCoordinator() => _instance;
  ViajeGpsCoordinator._internal();

  static const _prefsGpsViajeKey = 'gps_viaje_aceptado';
  static const _prefsActiveTripKey = 'active_trip_pedido_id';
  static const _prefsActiveRolKey = 'active_trip_rol';

  final _supabase = Supabase.instance.client;

  String? _activePedidoId;
  ViajeGpsRol? _activeRol;

  String? get activePedidoId => _activePedidoId ?? ViajeTrackingService().currentTripId;
  ViajeGpsRol? get activeRol => _activeRol;

  bool get isActive =>
      ViajeTrackingService().isTracking || GpsTrackerService().isTracking;

  /// Inicia tracking silencioso (sin UI). Capitán y pescador.
  Future<void> startForTrip({
    required String pedidoId,
    required String userId,
    required ViajeGpsRol rol,
    bool requestPermissionIfNeeded = true,
  }) async {
    if (pedidoId.isEmpty || userId.isEmpty) return;

    if (ViajeTrackingService().isTracking &&
        ViajeTrackingService().currentTripId == pedidoId) {
      _activePedidoId = pedidoId;
      _activeRol = rol;
      return;
    }

    if (requestPermissionIfNeeded) {
      final ok = rol == ViajeGpsRol.pescador
          ? await _ensurePescadorPermission()
          : await _ensureLocationPermission();
      if (!ok) {
        debugPrint('⚠️ [ViajeGps] Permiso GPS no concedido ($rol)');
        return;
      }
    }

    _activePedidoId = pedidoId;
    _activeRol = rol;
    await _persistActiveTrip(pedidoId, rol);

    await GpsTrackerService().startTracking(userId);
    await ViajeTrackingService().startTracking(
      tripId: pedidoId,
      rol: rol.value,
    );

    debugPrint('🛰️ [ViajeGps] Tracking activo pedido=$pedidoId rol=${rol.value}');
  }

  /// Detiene tracking y sincroniza el último bloque de puntos.
  Future<void> stopForTrip() async {
    await ViajeTrackingService().stopTracking();
    GpsTrackerService().stopTracking();
    _activePedidoId = null;
    _activeRol = null;
    await _clearActiveTrip();
    debugPrint('🛑 [ViajeGps] Tracking detenido');
  }

  /// Reanuda tracking si hay un viaje `en_curso`; detiene si ya no corresponde.
  Future<void> resumeIfNeeded() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final capitanTrip = await _supabase
          .from('pedidos')
          .select('id')
          .eq('capitan_id', userId)
          .eq('estado', 'en_curso')
          .maybeSingle();

      if (capitanTrip != null) {
        final pedidoId = capitanTrip['id']?.toString() ?? '';
        if (pedidoId.isNotEmpty) {
          await startForTrip(
            pedidoId: pedidoId,
            userId: userId,
            rol: ViajeGpsRol.capitan,
          );
          return;
        }
      }

      final pescadorTrip = await _supabase
          .from('pedidos')
          .select('id')
          .eq('pescador_id', userId)
          .eq('estado', 'en_curso')
          .maybeSingle();

      if (pescadorTrip != null) {
        final pedidoId = pescadorTrip['id']?.toString() ?? '';
        if (pedidoId.isNotEmpty) {
          await startForTrip(
            pedidoId: pedidoId,
            userId: userId,
            rol: ViajeGpsRol.pescador,
          );
          return;
        }
      }

      if (isActive) {
        await stopForTrip();
      }
    } catch (e) {
      debugPrint('⚠️ [ViajeGps] resumeIfNeeded: $e');
    }
  }

  Future<Map<String, dynamic>?> findActiveTripForUser(String userId) async {
    try {
      final capitan = await _supabase
          .from('pedidos')
          .select('id, estado, capitan_id, pescador_id')
          .eq('capitan_id', userId)
          .eq('estado', 'en_curso')
          .maybeSingle();
      if (capitan != null) return Map<String, dynamic>.from(capitan);

      final pescador = await _supabase
          .from('pedidos')
          .select('id, estado, capitan_id, pescador_id')
          .eq('pescador_id', userId)
          .eq('estado', 'en_curso')
          .maybeSingle();
      if (pescador != null) return Map<String, dynamic>.from(pescador);
    } catch (_) {}
    return null;
  }

  Future<bool> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Pescador: pedir permiso una sola vez (flag en SharedPreferences).
  Future<bool> _ensurePescadorPermission() async {
    final prefs = await SharedPreferences.getInstance();
    final yaAcepto = prefs.getBool(_prefsGpsViajeKey) ?? false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (!yaAcepto) {
        permission = await Geolocator.requestPermission();
      }
    } else if (!yaAcepto) {
      await prefs.setBool(_prefsGpsViajeKey, true);
    }

    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (granted && !yaAcepto) {
      await prefs.setBool(_prefsGpsViajeKey, true);
    }

    return granted;
  }

  Future<void> _persistActiveTrip(String pedidoId, ViajeGpsRol rol) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsActiveTripKey, pedidoId);
    await prefs.setString(_prefsActiveRolKey, rol.value);
  }

  Future<void> _clearActiveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsActiveTripKey);
    await prefs.remove(_prefsActiveRolKey);
  }
}
