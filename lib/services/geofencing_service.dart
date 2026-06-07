import 'dart:math';

class GeofencingService {
  /// Calcula la distancia en metros entre dos puntos geográficos (lat/lon)
  /// utilizando la fórmula de Haversine.
  static double calcularDistanciaHaversine(
    Map<String, dynamic> coord1,
    Map<String, dynamic> coord2,
  ) {
    final double? lat1 = _obtenerCoordenada(coord1, ['lat', 'latitude', 'latitud']);
    final double? lon1 = _obtenerCoordenada(coord1, ['lon', 'lng', 'longitude', 'longitud']);
    final double? lat2 = _obtenerCoordenada(coord2, ['lat', 'latitude', 'latitud']);
    final double? lon2 = _obtenerCoordenada(coord2, ['lon', 'lng', 'longitude', 'longitud']);

    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) {
      throw ArgumentError('Coordenadas inválidas o incompletas en una o ambas ubicaciones.');
    }

    const double radioTierraKm = 6371.0; // Radio medio de la Tierra en kilómetros

    final double dLat = _gradosARadianes(lat2 - lat1);
    final double dLon = _gradosARadianes(lon2 - lon1);

    final double lat1Rad = _gradosARadianes(lat1);
    final double lat2Rad = _gradosARadianes(lat2);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    final double distanciaKm = radioTierraKm * c;
    return distanciaKm * 1000.0; // Retornar en metros
  }

  /// Convierte grados sexagesimales a radianes
  static double _gradosARadianes(double grados) {
    return grados * pi / 180.0;
  }

  /// Busca de forma segura la latitud o longitud bajo múltiples claves alternativas
  static double? _obtenerCoordenada(Map<String, dynamic> coords, List<String> llaves) {
    for (final llave in llaves) {
      if (coords.containsKey(llave) && coords[llave] != null) {
        final valor = coords[llave];
        if (valor is num) {
          return valor.toDouble();
        } else if (valor is String) {
          return double.tryParse(valor);
        }
      }
    }
    return null;
  }
}
