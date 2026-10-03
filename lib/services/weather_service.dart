import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  final bool datosDisponibles;

  /// Falso cuando el proveedor no devolvió altura de olas: [alturaOlas] no es
  /// un dato real y la UI/IA no deben presentarlo como medición.
  final bool olajeDisponible;

  /// Hora del último intento de obtener datos.
  final DateTime obtenidoEn;

  /// Fuente de los datos; vacío cuando no hay datos.
  final String fuente;
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
    this.datosDisponibles = true,
    this.olajeDisponible = true,
    DateTime? obtenidoEn,
    this.fuente = 'Open-Meteo',
    required this.temperatura,
    required this.velocidadViento,
    required this.direccionViento,
    required this.alturaOlas,
    required this.humedad,
    required this.presion,
    required this.descripcion,
    required this.pronosticoExtendido,
    required this.pronosticoHorario,
  }) : obtenidoEn = obtenidoEn ?? DateTime.now();

  /// Copia completa para el caché (paso 1.0b): actual + horario + diario.
  Map<String, dynamic> toCacheJson() => {
        'datosDisponibles': datosDisponibles,
        'olajeDisponible': olajeDisponible,
        'obtenidoEn': obtenidoEn.toIso8601String(),
        'fuente': fuente,
        'temperatura': temperatura,
        'velocidadViento': velocidadViento,
        'direccionViento': direccionViento,
        'alturaOlas': alturaOlas,
        'humedad': humedad,
        'presion': presion,
        'descripcion': descripcion,
        'diario': [
          for (final d in pronosticoExtendido)
            {'dia': d.diaSemana, 'max': d.temperaturaMax, 'codigo': d.weatherCode},
        ],
        'horario': [
          for (final h in pronosticoHorario)
            {
              'hora': h.hora.toIso8601String(),
              't': h.temperatura,
              'h': h.humedad,
              'v': h.vientoKmH,
              'r': h.rafagasKmH,
              'd': h.direccionViento,
              'o': h.alturaOlas,
            },
        ],
      };

  /// Inversa de [toCacheJson]. Devuelve null si el JSON no es utilizable.
  static MarineWeather? fromCacheJson(Map<String, dynamic> j) {
    try {
      if (j['datosDisponibles'] != true) return null;
      return MarineWeather(
        olajeDisponible: j['olajeDisponible'] == true,
        obtenidoEn: DateTime.parse(j['obtenidoEn'] as String),
        fuente: (j['fuente'] as String?) ?? '',
        temperatura: (j['temperatura'] as num).toDouble(),
        velocidadViento: (j['velocidadViento'] as num).toDouble(),
        direccionViento: (j['direccionViento'] as num).toDouble(),
        alturaOlas: (j['alturaOlas'] as num).toDouble(),
        humedad: (j['humedad'] as num).toInt(),
        presion: (j['presion'] as num).toDouble(),
        descripcion: (j['descripcion'] as String?) ?? '',
        pronosticoExtendido: [
          for (final d in (j['diario'] as List? ?? const []))
            ExtendedForecastDay(
              diaSemana: d['dia'] as String,
              temperaturaMax: (d['max'] as num).toDouble(),
              weatherCode: (d['codigo'] as num).toInt(),
            ),
        ],
        pronosticoHorario: [
          for (final h in (j['horario'] as List? ?? const []))
            HourlyForecast(
              hora: DateTime.parse(h['hora'] as String),
              temperatura: (h['t'] as num).toDouble(),
              humedad: (h['h'] as num).toInt(),
              vientoKmH: (h['v'] as num).toDouble(),
              vientoNudos: (h['v'] as num).toDouble() * 0.539957,
              rafagasKmH: (h['r'] as num).toDouble(),
              rafagasNudos: (h['r'] as num).toDouble() * 0.539957,
              direccionViento: (h['d'] as num).toDouble(),
              alturaOlas: (h['o'] as num).toDouble(),
            ),
        ],
      );
    } catch (_) {
      return null;
    }
  }

  factory MarineWeather.fromJson(Map<String, dynamic> jsonCurrent, Map<String, dynamic>? jsonMarine) {
    final current = jsonCurrent['current'];
    // Nunca clasificar navegación/pesca a partir de defaults: sin temperatura
    // o viento reales no existe un pronóstico utilizable.
    if (current is! Map ||
        current['temperature_2m'] is! num ||
        current['wind_speed_10m'] is! num) {
      return WeatherService.datosNoDisponibles();
    }
    final temp = (current['temperature_2m'] as num).toDouble();
    final windSpeed = (current['wind_speed_10m'] as num).toDouble();
    final windDir = (current['wind_direction_10m'] as num?)?.toDouble() ?? 0.0;
    final hum = (current['relative_humidity_2m'] as num?)?.toInt() ?? 0;
    final press = (current['surface_pressure'] as num?)?.toDouble() ?? 0;

    // Altura de olas: en ríos/deltas el proveedor suele no informarla. Sin dato
    // real NO se asume un valor "tranquilo": queda 0 y olajeDisponible=false.
    double waveHeight = 0.0;
    bool olajeDisponible = false;
    if (jsonMarine != null && jsonMarine['current'] is Map) {
      final marineCurrent = jsonMarine['current'] as Map;
      if (marineCurrent['wave_height'] is num) {
        waveHeight = (marineCurrent['wave_height'] as num).toDouble();
        olajeDisponible = true;
      }
    }

    // Clasificación: solo se emiten alertas. Nunca se califica una salida como
    // "ideal" o segura; la decisión final es del capitán con el parte oficial.
    String desc;
    if (windSpeed > 28.0 || waveHeight > 1.8) {
      desc = "TEMPORAL - NO RECOMENDADO NAVEGAR";
    } else if (windSpeed > 18.0 || waveHeight > 1.2) {
      desc = "PRECAUCIÓN - VIENTO Y OLAJE MODERADO";
    } else if (temp < 10.0) {
      desc = "FRÍO - ABRIGARSE PARA NAVEGAR";
    } else if (!olajeDisponible) {
      desc = "SIN ALERTAS DE VIENTO - OLAJE NO DISPONIBLE, CONSULTAR PARTE OFICIAL";
    } else {
      desc = "SIN ALERTAS SEGÚN DATOS DISPONIBLES - CONSULTAR PARTE OFICIAL";
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

    // Sin pronóstico diario real la lista queda vacía: no se fabrican días.

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
          double wh = 0.0; // sin dato real de olas (ríos/deltas)
          if (waveHeights != null && i < waveHeights.length && waveHeights[i] is num) {
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

    // Sin pronóstico horario real la lista queda vacía: no se repite el valor actual.

    return MarineWeather(
      olajeDisponible: olajeDisponible,
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

/// Última respuesta COMPLETA del clima, guardada en el celular (paso 1.0b).
/// La escribe `WeatherService.fetchMarineWeather` cada vez que baja datos, así que
/// la pantalla de pronóstico, el mini widget del panel y el Guía comparten el mismo
/// caché. Sin señal, el Guía responde con esto, diciendo de cuándo es.
class ClimaGuardado {
  final MarineWeather clima;
  final DateTime descargadoEn;
  final double lat;
  final double lon;

  const ClimaGuardado({
    required this.clima,
    required this.descargadoEn,
    required this.lat,
    required this.lon,
  });

  String get fuente => clima.fuente;
}

class ClimaCache {
  static const String clave = 'clima_cache_v1';

  static Future<void> guardar(MarineWeather clima, double lat, double lon, {DateTime? ahora}) async {
    if (!clima.datosDisponibles) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        clave,
        jsonEncode({
          'descargadoEn': (ahora ?? DateTime.now()).toIso8601String(),
          'lat': lat,
          'lon': lon,
          'clima': clima.toCacheJson(),
        }),
      );
    } catch (_) {}
  }

  static Future<ClimaGuardado?> leer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo == null) return null;
      final j = jsonDecode(crudo) as Map<String, dynamic>;
      final clima = MarineWeather.fromCacheJson(j['clima'] as Map<String, dynamic>);
      if (clima == null) return null;
      return ClimaGuardado(
        clima: clima,
        descargadoEn: DateTime.parse(j['descargadoEn'] as String),
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
      );
    } catch (_) {
      return null;
    }
  }
}

class WeatherService {
  static MarineWeather datosNoDisponibles() => MarineWeather(
        datosDisponibles: false,
        olajeDisponible: false,
        fuente: '',
        temperatura: 0,
        velocidadViento: 0,
        direccionViento: 0,
        alturaOlas: 0,
        humedad: 0,
        presion: 0,
        descripcion: 'DATOS METEOROLÓGICOS NO DISPONIBLES — NO USAR PARA NAVEGAR',
        pronosticoExtendido: const [],
        pronosticoHorario: const [],
      );

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

      final clima = MarineWeather.fromJson(weatherJson, marineJson);
      await ClimaCache.guardar(clima, lat, lon);
      return clima;
    } catch (e) {
      print("⚠️ Error en WeatherService al obtener clima real: $e");
      return datosNoDisponibles();
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
