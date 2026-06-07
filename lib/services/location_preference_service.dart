import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';

class LocationDetails {
  final double latitude;
  final double longitude;
  final String name;
  final bool isGps;

  LocationDetails({
    required this.latitude,
    required this.longitude,
    required this.name,
    this.isGps = false,
  });
}

class LocationPreferenceService {
  static const String _keyLat = 'predefined_lat';
  static const String _keyLon = 'predefined_lon';
  static const String _keyName = 'predefined_name';

  // Default Puerto San Fernando, BA
  static const double defaultLat = -34.442;
  static const double defaultLon = -58.558;
  static const String defaultName = 'SAN FERNANDO, BA';

  /// Saves coordinates as user's predefined default.
  static Future<void> savePredefinedLocation(double lat, double lon, String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLon, lon);
    await prefs.setString(_keyName, name);
  }

  /// Retrieves the saved predefined location, or defaults to San Fernando.
  static Future<LocationDetails> getPredefinedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final double? lat = prefs.getDouble(_keyLat);
    final double? lon = prefs.getDouble(_keyLon);
    final String? name = prefs.getString(_keyName);

    if (lat != null && lon != null && name != null) {
      return LocationDetails(latitude: lat, longitude: lon, name: name);
    }

    return LocationDetails(
      latitude: defaultLat,
      longitude: defaultLon,
      name: defaultName,
    );
  }

  /// Tries to fetch current GPS coordinates.
  static Future<LocationDetails> getCurrentGPSLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return LocationDetails(
          latitude: defaultLat,
          longitude: defaultLon,
          name: '$defaultName (GPS Apagado)',
        );
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return LocationDetails(
            latitude: defaultLat,
            longitude: defaultLon,
            name: '$defaultName (Permiso Denegado)',
          );
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return LocationDetails(
          latitude: defaultLat,
          longitude: defaultLon,
          name: '$defaultName (Permiso Bloqueado)',
        );
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      return LocationDetails(
        latitude: position.latitude,
        longitude: position.longitude,
        name: 'MI UBICACIÓN ACTUAL',
        isGps: true,
      );
    } catch (e) {
      return LocationDetails(
        latitude: defaultLat,
        longitude: defaultLon,
        name: '$defaultName (Error GPS: $e)',
      );
    }
  }
}
