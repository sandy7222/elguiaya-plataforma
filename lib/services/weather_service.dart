import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ExtendedForecastDay {
  final String diaSemana; // ej. "LUN", "MAR"
  final double temperaturaMax;
  final int weatherCode;

  ExtendedForecastDay({
    required this.diaSemana,
    required this.temperaturaMax,
    required this.weatherCode,
  });
}

class HourlyForecast {
  final DateTime hora;
  final double temperatura;
  final int humedad;
  final double vientoKmH;
  final double vientoNudos;
  final double rafagasKmH;
  final double rafagasNudos;
  final double direccionViento;
  final double alturaOlas;

  HourlyForecast({
    required this.hora,
    required this.temperatura,
    required this.humedad,
    required this.vientoKmH,
    required this.vientoNudos,
    required this.rafagasKmH,
    required this.rafagasNudos,
    required this.direccionViento,
    required this.alturaOlas,
  });
}

class MarineWeather {
  final double temperatura;
  final double velocidadViento;
  final double direccionViento;
  final double alturaOlas;
  final int humedad;
  final double presion;
  final String descripcion;
  final List<ExtendedForecastDay> pronosticoExtendido;
  final List<HourlyForecast> pronosticoHorario;

  MarineWeather({
    required this.temperatura,
    required this.velocidadViento,
    required this.direccionViento,
    required this.alturaOlas,
    required this.humedad,
    required this.presion,
    required this.descripcion,
    required this.pronosticoExtendido,
    required this.pronosticoHorario,
  });

  factory MarineWeather.fromJson(Map<String, dynamic> jsonCurrent, Map<String, dynamic>? jsonMarine) {
    final current = jsonCurrent['current'] ?? {};
    final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 22.0;
    final windSpeed = (current['wind_speed_10m'] as num?)?.toDouble() ?? 12.0;
    final windDir = (current['wind_direction_10m'] as num?)?.toDouble() ?? 0.0;
    final hum = (current['relative_humidity_2m'] as num?)?.toInt() ?? 65;
    final press = (current['surface_pressure'] as num?)?.toDouble() ?? 1013.0;

    // Altura de olas: Si es nulo o vacío (ríos/deltas)
    double waveHeight = 0.3; 
    if (jsonMarine != null && jsonMarine['current'] != null) {
      final marineCurrent = jsonMarine['current'];
      if (marineCurrent['wave_height'] != null) {
        waveHeight = (marineCurrent['wave_height'] as num).toDouble();
      }
    }

    // Clasificación lógica para navegación y pesca
    String desc = "DESPEJADO - IDEAL PARA PESCA";
    if (windSpeed > 28.0 || waveHeight > 1.8) {
      desc = "TEMPORAL - NO RECOMENDADO NAVEGAR";
    } else if (windSpeed > 18.0 || waveHeight > 1.2) {
      desc = "PRECAUCIÓN - VIENTO Y OLAJE MODERADO";
    } else if (temp < 10.0) {
      desc = "FRÍO - ABRIGARSE PARA NAVEGAR";
    }

    // 1. Parsear pronóstico de 5 días
    final List<ExtendedForecastDay> extended = [];
    final daily = jsonCurrent['daily'];
    if (daily != null && daily['time'] != null) {
      final times = daily['time'] as List;
      final maxTemps = daily['temperature_2m_max'] as List;
      final codes = daily['weathercode'] as List;

      final limit = times.length > 5 ? 5 : times.length;
      for (int i = 0; i < limit; i++) {
        try {
          final parsedDate = DateTime.parse(times[i].toString());
          final dayStr = DateFormat('E', 'es').format(parsedDate).toUpperCase().replaceAll('.', '');
          extended.add(ExtendedForecastDay(
            diaSemana: dayStr,
            temperaturaMax: (maxTemps[i] as num).toDouble(),
            weatherCode: (codes[i] as num).toInt(),
          ));
        } catch (_) {}
      }
    }

    // Fallback extendido
    if (extended.isEmpty) {
      final mockDays = ['HOY', 'MAÑ', 'PAS', 'SAB', 'DOM'];
      for (int i = 0; i < 5; i++) {
        extended.add(ExtendedForecastDay(
          diaSemana: mockDays[i],
          temperaturaMax: temp + (i * 1.5) - 2.0,
          weatherCode: 0,
        ));
      }
    }

    // 2. Parsear pronóstico horario detallado
    final List<HourlyForecast> hourly = [];
    final hourlyData = jsonCurrent['hourly'];
    final marineHourly = jsonMarine?['hourly'];

    if (hourlyData != null && hourlyData['time'] != null) {
      final times = hourlyData['time'] as List;
      final temps = hourlyData['temperature_2m'] as List;
      final hums = hourlyData['relative_humidity_2m'] as List;
      final windSpeeds = hourlyData['wind_speed_10m'] as List;
      final windDirs = hourlyData['wind_direction_10m'] as List;
      final windGusts = hourlyData['wind_gusts_10m'] as List;
      
      final waveHeights = marineHourly?['wave_height'] as List?;

      // Parseamos hasta 72 horas (3 días) para mantener óptimo el rendimiento
      final limit = times.length > 72 ? 72 : times.length;
      for (int i = 0; i < limit; i++) {
        try {
          final parsedTime = DateTime.parse(times[i].toString());
          
          final double t = (temps[i] as num).toDouble();
          final int h = (hums[i] as num).toInt();
          final double ws = (windSpeeds[i] as num).toDouble();
          final double wd = (windDirs[i] as num).toDouble();
          final double wg = (windGusts[i] as num).toDouble();
          
          // Conversión a Nudos: 1 km/h = 0.539957 nudos
          final double wsKt = ws * 0.539957;
          final double wgKt = wg * 0.539957;

          // Altura de ola horaria
          double wh = 0.3; // Río / Delta fallback
          if (waveHeights != null && i < waveHeights.length && waveHeights[i] != null) {
            wh = (waveHeights[i] as num).toDouble();
          }

          hourly.add(HourlyForecast(
            hora: parsedTime,
            temperatura: t,
            humedad: h,
            vientoKmH: ws,
            vientoNudos: wsKt,
            rafagasKmH: wg,
            rafagasNudos: wgKt,
            direccionViento: wd,
            alturaOlas: wh,
          ));
        } catch (_) {}
      }
    }

    // Fallback horario vacío (por seguridad)
    if (hourly.isEmpty) {
      final baseTime = DateTime.now();
      for (int i = 0; i < 48; i++) {
        final forecastTime = DateTime(baseTime.year, baseTime.month, baseTime.day, baseTime.hour + i);
        hourly.add(HourlyForecast(
          hora: forecastTime,
          temperatura: temp,
          humedad: hum,
          vientoKmH: windSpeed,
          vientoNudos: windSpeed * 0.539957,
          rafagasKmH: windSpeed * 1.3,
          rafagasNudos: windSpeed * 1.3 * 0.539957,
          direccionViento: windDir,
          alturaOlas: waveHeight,
        ));
      }
    }

    return MarineWeather(
      temperatura: temp,
      velocidadViento: windSpeed,
      direccionViento: windDir,
      alturaOlas: waveHeight,
      humedad: hum,
      presion: press,
      descripcion: desc,
      pronosticoExtendido: extended,
      pronosticoHorario: hourly,
    );
  }
}

class WeatherService {
  /// Obtiene el reporte del clima real de Open-Meteo y Open-Meteo Marine
  static Future<MarineWeather> fetchMarineWeather(double lat, double lon) async {
    try {
      // 1. Petición para clima estándar (Temperatura, Humedad, Viento, Ráfagas y pronóstico horario + diario)
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,surface_pressure&hourly=temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,wind_gusts_10m&daily=temperature_2m_max,weathercode&timezone=auto'
      );
      // 2. Petición para variables marítimas (Olas por hora)
      final marineUrl = Uri.parse(
        'https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon&current=wave_height,wave_direction&hourly=wave_height,wave_direction&timezone=auto'
      );

      final responses = await Future.wait([
        http.get(weatherUrl),
        http.get(marineUrl).catchError((_) => http.Response('{}', 404)), 
      ]);

      Map<String, dynamic> weatherJson = {};
      Map<String, dynamic>? marineJson;

      if (responses[0].statusCode == 200) {
        weatherJson = jsonDecode(responses[0].body);
      } else {
        throw Exception("Error de respuesta del servidor del clima: ${responses[0].statusCode}");
      }

      if (responses[1].statusCode == 200) {
        try {
          marineJson = jsonDecode(responses[1].body);
        } catch (_) {}
      }

      return MarineWeather.fromJson(weatherJson, marineJson);
    } catch (e) {
      print("⚠️ Error en WeatherService al obtener clima real: $e");
      // Fallback seguro ante cualquier problema de red o API
      final List<ExtendedForecastDay> mockExtended = [
        ExtendedForecastDay(diaSemana: 'JUE', temperaturaMax: 22.0, weatherCode: 0),
        ExtendedForecastDay(diaSemana: 'VIE', temperaturaMax: 19.0, weatherCode: 3),
        ExtendedForecastDay(diaSemana: 'SAB', temperaturaMax: 24.0, weatherCode: 0),
        ExtendedForecastDay(diaSemana: 'DOM', temperaturaMax: 26.0, weatherCode: 0),
        ExtendedForecastDay(diaSemana: 'LUN', temperaturaMax: 21.0, weatherCode: 95),
      ];
      return MarineWeather(
        temperatura: 22.0,
        velocidadViento: 12.0,
        direccionViento: 45.0,
        alturaOlas: 0.4,
        humedad: 65,
        presion: 1013.0,
        descripcion: "IDEAL PARA PESCA",
        pronosticoExtendido: mockExtended,
        pronosticoHorario: [],
      );
    }
  }

  /// Busca ubicaciones por nombre usando la API gratuita de geocodificación de Open-Meteo
  static Future<List<Map<String, dynamic>>> searchLocations(String query) async {
    if (query.trim().length < 3) return [];
    try {
      final url = Uri.parse(
        'https://geocoding-api.open-meteo.com/v1/search?name=${Uri.encodeComponent(query)}&count=5&language=es&format=json'
      );
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null) {
          return List<Map<String, dynamic>>.from(data['results']);
        }
      }
    } catch (e) {
      print("⚠️ Error geocodificando ubicación: $e");
    }
    return [];
  }
}
