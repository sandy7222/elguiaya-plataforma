import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://ymgsxwfwntbqvguvbhoa.supabase.co/rest/v1';
  const apiKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InltZ3N4d2Z3bnRicXZndXZiaG9hIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc3ODgxMzQsImV4cCI6MjA5MzM2NDEzNH0.ZT2xlCIAnSyr_tR9qZAKIB7QAVQjJO2Jv0cwb51f1Uw';
  
  final headers = {
    'apikey': apiKey,
    'Authorization': 'Bearer $apiKey',
    'Content-Type': 'application/json',
  };

  print('Fetching profiles with empty coordinates...');
  try {
    final response = await http.get(
      Uri.parse('$url/profiles?select=user_id,nombre,direccion_calle,direccion_numero,localidad,provincia,zona_lat'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      print('Failed to fetch profiles: ${response.body}');
      return;
    }

    final List profiles = json.decode(response.body);
    print('Found ${profiles.length} total profiles.');

    for (var p in profiles) {
      final userId = p['user_id'];
      final nombre = p['nombre'] ?? 'Sin Nombre';
      final calle = p['direccion_calle'];
      final numero = p['direccion_numero'];
      final localidad = p['localidad'];
      final provincia = p['provincia'];
      final lat = p['zona_lat'];

      if (lat != null) {
        print('Skipping $nombre (already has coordinates: $lat)');
        continue;
      }

      if ((calle == null || calle.isEmpty) && (localidad == null || localidad.isEmpty)) {
        print('Skipping $nombre (no address or locality provided)');
        continue;
      }

      print('Geocoding address for $nombre: $calle $numero, $localidad, $provincia');
      
      final parts = <String>[];
      if (calle != null && calle.isNotEmpty) {
        parts.add(calle);
        if (numero != null && numero.isNotEmpty) {
          parts.add(numero);
        }
      }
      if (localidad != null && localidad.isNotEmpty) {
        parts.add(localidad);
      }
      if (provincia != null && provincia.isNotEmpty) {
        parts.add(provincia);
      } else {
        parts.add('Argentina');
      }

      final query = parts.join(', ');
      print('  Querying Nominatim for: "$query"');

      // Add delay to respect Nominatim usage policy (1 request/second)
      await Future.delayed(const Duration(seconds: 1));

      final geoUrl = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query.toLowerCase().trim())}&format=json&countrycodes=ar&limit=1',
      );

      final geoResponse = await http.get(
        geoUrl,
        headers: {'User-Agent': 'CapitanYA_Geocoder_Script'},
      );

      if (geoResponse.statusCode == 200) {
        var results = json.decode(geoResponse.body) as List;
        
        // Fallback a búsqueda solo por localidad si falla la dirección completa
        if (results.isEmpty && localidad != null && localidad.isNotEmpty) {
          final cleanLocalidad = localidad.replaceAll('Buolevard', 'Boulevard').trim();
          print('  Full address search returned empty. Trying fallback with locality: "$cleanLocalidad"');
          await Future.delayed(const Duration(seconds: 1));
          
          final fallbackQuery = provincia != null && provincia.isNotEmpty 
              ? '$cleanLocalidad, $provincia, Argentina' 
              : '$cleanLocalidad, Argentina';
              
          final fallbackGeoUrl = Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(fallbackQuery.toLowerCase().trim())}&format=json&countrycodes=ar&limit=1',
          );
          
          final fallbackGeoResponse = await http.get(
            fallbackGeoUrl,
            headers: {'User-Agent': 'CapitanYA_Geocoder_Script'},
          );
          
          if (fallbackGeoResponse.statusCode == 200) {
            results = json.decode(fallbackGeoResponse.body) as List;
          }
        }

        if (results.isNotEmpty) {
          final foundLat = double.tryParse(results[0]['lat'].toString());
          final foundLon = double.tryParse(results[0]['lon'].toString());
          
          if (foundLat != null && foundLon != null) {
            print('  Found coordinates: $foundLat, $foundLon. Updating in Supabase...');

            final updateResponse = await http.patch(
              Uri.parse('$url/profiles?user_id=eq.$userId'),
              headers: headers,
              body: json.encode({
                'zona_lat': foundLat,
                'zona_lng': foundLon,
                'updated_at': DateTime.now().toIso8601String(),
              }),
            );

            if (updateResponse.statusCode == 204 || updateResponse.statusCode == 200) {
              print('  Successfully updated coordinates for $nombre!');
            } else {
              print('  Failed to update coordinates: ${updateResponse.body}');
            }
          } else {
            print('  Coordinates parsed as null.');
          }
        } else {
          print('  No geocoding results found.');
        }
      } else {
        print('  Nominatim request failed: ${geoResponse.statusCode}');
      }
    }
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }
}
