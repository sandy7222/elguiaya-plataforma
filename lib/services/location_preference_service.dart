import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

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

  /// Retrieves the saved predefined location, or performs the location cascade if not set.
  static Future<LocationDetails> getPredefinedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final double? lat = prefs.getDouble(_keyLat);
    final double? lon = prefs.getDouble(_keyLon);
    final String? name = prefs.getString(_keyName);

    if (lat != null && lon != null && name != null) {
      return LocationDetails(latitude: lat, longitude: lon, name: name);
    }

    return await obtenerUbicacionCascada();
  }

  /// Obtiene la ubicación usando la cascada especificada:
  /// 1. Geolocator (LocationAccuracy.low, timeout 5s) + Nominatim Reverse Geocoding
  /// 2. IP geolocalización (http://ip-api.com/json)
  /// 3. Predeterminada (San Fernando)
  static Future<LocationDetails> obtenerUbicacionCascada() async {
    // ── Paso 1: Geolocator con Low Accuracy y timeout de 5 segundos ──
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission == LocationPermission.whileInUse ||
            permission == LocationPermission.always) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
            timeLimit: const Duration(seconds: 5),
          );
          final name = await _reverseGeocode(position.latitude, position.longitude, defaultName: 'MI UBICACIÓN (GPS)');
          final loc = LocationDetails(
            latitude: position.latitude,
            longitude: position.longitude,
            name: name,
            isGps: true,
          );
          // Guardamos para futuras llamadas
          await savePredefinedLocation(loc.latitude, loc.longitude, loc.name);
          return loc;
        }
      }
    } catch (e) {
      // Ignorar fallos de GPS para continuar en la cascada
    }

    // ── Paso 2: Ubicación por IP usando http://ip-api.com/json ──
    try {
      final response = await http.get(Uri.parse('http://ip-api.com/json')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data != null && data['status'] == 'success') {
          final double lat = (data['lat'] as num).toDouble();
          final double lon = (data['lon'] as num).toDouble();
          final String city = data['city']?.toString() ?? 'DESCONOCIDA';
          final String regionName = data['regionName']?.toString() ?? '';
          final String name = regionName.isNotEmpty ? '$city, $regionName' : city;

          final loc = LocationDetails(
            latitude: lat,
            longitude: lon,
            name: name.toUpperCase(),
            isGps: false,
          );
          // Guardamos para futuras llamadas
          await savePredefinedLocation(loc.latitude, loc.longitude, loc.name);
          return loc;
        }
      }
    } catch (e) {
      // Ignorar fallos de red para ir al fallback predeterminado
    }

    // ── Paso 3: Localidad predeterminada (San Fernando) ──
    return LocationDetails(
      latitude: defaultLat,
      longitude: defaultLon,
      name: defaultName,
      isGps: false,
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

      final name = await _reverseGeocode(position.latitude, position.longitude, defaultName: 'MI UBICACIÓN ACTUAL');

      return LocationDetails(
        latitude: position.latitude,
        longitude: position.longitude,
        name: name,
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

  /// Realiza geocodificación inversa para obtener la localidad y provincia de coordenadas lat/lon
  static Future<String> _reverseGeocode(double lat, double lon, {required String defaultName}) async {
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=10',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'El Guia YA_App'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final address = data['address'] as Map<String, dynamic>?;
        if (address != null) {
          final String city = address['city']?.toString() ??
              address['town']?.toString() ??
              address['village']?.toString() ??
              address['municipality']?.toString() ??
              address['county']?.toString() ??
              '';
          final String province = address['state']?.toString() ?? '';

          if (city.isNotEmpty && province.isNotEmpty) {
            return '$city, $province'.toUpperCase();
          } else if (city.isNotEmpty) {
            return city.toUpperCase();
          } else if (province.isNotEmpty) {
            return province.toUpperCase();
          }
        }
      }
    } catch (e) {
      // Ignorar errores y retornar el valor por defecto
    }
    return defaultName;
  }
}
