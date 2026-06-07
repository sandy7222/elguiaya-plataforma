import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'dart:typed_data';

class GeoService {
  final _client = Supabase.instance.client;

  /// Retorna un stream con las zonas de los capitanes activos
  Stream<List<Map<String, dynamic>>> streamCapitanesZonas() {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .map((list) {
          return list
              .where((p) => p['es_capitan'] == true && p['zona_lat'] != null && p['disponible'] == true)
              .map((p) => {
                'id': p['user_id'],
                'activo': p['disponible'],
                'centro_operaciones': {
                  'lat': p['zona_lat'],
                  'lon': p['zona_lng'],
                },
                'radio_cobertura_km': p['zona_radio_km'],
                'nombre': p['nombre'] ?? p['telefono'] ?? 'Capitán',
                'avatar_url': p['avatar_url'],
                'capacidad_personas': p['capacidad_personas'],
                'localidad': p['localidad'],
                'provincia': p['provincia'],
              })
              .toList();
        });
  }

  /// Retorna un stream con los puntos de los pescadores activos
  Stream<List<Map<String, dynamic>>> streamPescadoresPuntos() {
    return _client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .map((list) {
          return list
              .where((p) => (p['es_capitan'] == false || p['es_capitan'] == null) && p['zona_lat'] != null)
              .map((p) => {
                'id': p['user_id'],
                'activo': true,
                'ubicacion_actual': {
                  'lat': p['zona_lat'],
                  'lon': p['zona_lng'],
                },
                'nombre': p['nombre'] ?? p['telefono'] ?? 'Pescador',
                'avatar_url': p['avatar_url'],
                'localidad': p['localidad'],
                'provincia': p['provincia'],
              })
              .toList();
        });
  }

  /// Retorna un stream con las cotizaciones activas
  Stream<List<Map<String, dynamic>>> streamCotizacionesActivas() {
    return _client
        .from('cotizaciones')
        .stream(primaryKey: ['id'])
        .map((list) {
          final now = DateTime.now();
          return list
              .where((c) {
                if (c['punto_partida'] == null) return false;
                if (c['expira_en'] != null) {
                  try {
                    final exp = DateTime.parse(c['expira_en'].toString());
                    if (exp.isBefore(now)) return false; // Expired!
                  } catch (_) {}
                }
                if (c['created_at'] != null) {
                  try {
                    final createdAt = DateTime.parse(c['created_at'].toString());
                    if (now.difference(createdAt).inHours >= 24) {
                      return false; // Expired! (Older than 24 hours)
                    }
                  } catch (_) {}
                }
                return true;
              })
              .map((c) => {
                'id': c['id'],
                'ubicacion': c['punto_partida'],
                'estado': c['estado'],
                'monto': c['presupuesto_monto'],
                'descripcion_corta': c['descripcion'],
                'pescador_id': c['pescador_id'],
                'localidad': c['localidad_partida'],
                'provincia': c['provincia_partida'],
              })
              .toList();
        });
  }

  /// Extrae LatLng desde el formato Point(lon lat) de PostGIS, json, o WKB
  LatLng? parsearPunto(dynamic dato) {
    if (dato == null) return null;
    
    // Si viene como Map (GeoJSON o simple con lat/lon)
    if (dato is Map) {
      if (dato['type'] == 'Point') {
        final coords = dato['coordinates'] as List;
        return LatLng(coords[1] as double, coords[0] as double); // lat, lon
      }
      final latVal = dato['lat'] ?? dato['latitude'];
      final lonVal = dato['lon'] ?? dato['lng'] ?? dato['longitude'];
      if (latVal != null && lonVal != null) {
        return LatLng(double.parse(latVal.toString()), double.parse(lonVal.toString()));
      }
    }
    
    // Si viene como string 'POINT(lon lat)'
    if (dato is String && dato.startsWith('POINT(')) {
      final contenido = dato.replaceAll('POINT(', '').replaceAll(')', '');
      final partes = contenido.split(' ');
      if (partes.length >= 2) {
        return LatLng(double.parse(partes[1]), double.parse(partes[0]));
      }
    }
    
    // Si viene como WKB Hex (PostGIS default binary stream)
    if (dato is String && dato.startsWith('01010000')) {
      try {
        // Formato con SRID (4326): 0101000020E6100000 + lon + lat
        int offset = dato.startsWith('0101000020') ? 18 : 10;
        
        if (dato.length >= offset + 32) {
          final lonHex = dato.substring(offset, offset + 16);
          final latHex = dato.substring(offset + 16, offset + 32);
          
          double parseHexDouble(String hex) {
            final buffer = _parseHexStr(hex);
            return ByteData.view(buffer.buffer).getFloat64(0, Endian.little);
          }
          
          return LatLng(parseHexDouble(latHex), parseHexDouble(lonHex));
        }
      } catch (e) {
        print("Error parseando EWKB: $e");
      }
    }
    
    return null;
  }

  static Uint8List _parseHexStr(String hexStr) {
    final result = Uint8List(hexStr.length ~/ 2);
    for (int i = 0; i < result.length; i++) {
      result[i] = int.parse(hexStr.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
