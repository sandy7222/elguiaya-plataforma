import 'package:apsl_sun_calc/apsl_sun_calc.dart';

class SolunarInfo {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime? moonrise;
  final DateTime? moonset;
  final double moonIllumination; // 0.0 to 1.0
  final String moonPhaseName;
  final String moonPhaseIcon;
  final List<SolunarPeriod> periods;
  final double dayRating; // 0.0 (poor) to 1.0 (excellent)

  SolunarInfo({
    required this.sunrise,
    required this.sunset,
    this.moonrise,
    this.moonset,
    required this.moonIllumination,
    required this.moonPhaseName,
    required this.moonPhaseIcon,
    required this.periods,
    required this.dayRating,
  });
}

enum PeriodType { major, minor }

class SolunarPeriod {
  final String name;
  final DateTime start;
  final DateTime end;
  final PeriodType type;
  final double activityLevel; // 0.0 to 1.0 (rating of this specific period)

  SolunarPeriod({
    required this.name,
    required this.start,
    required this.end,
    required this.type,
    required this.activityLevel,
  });
}

class SolunarService {
  // Library correction: the pub.dev package subtracts 1970 instead of j1970 (2440588)
  static const int _j1970 = 2440588;
  static const int _correctionMs = (1970 - _j1970) * 24 * 60 * 60 * 1000;

  static DateTime _correctLibraryDate(DateTime rawDate) {
    return rawDate.add(const Duration(milliseconds: _correctionMs)).toLocal();
  }

  /// Calculates all solunar data for a given date and coordinates.
  static Future<SolunarInfo> calculateSolunar(DateTime date, double lat, double lon) async {
    // 1. Get corrected Sun times
    final rawSunTimes = await SunCalc.getTimes(date, lat, lon);
    final sunrise = _correctLibraryDate(rawSunTimes['sunrise']!);
    final sunset = _correctLibraryDate(rawSunTimes['sunset']!);

    // 2. Get Moon times
    final rawMoonTimes = SunCalc.getMoonTimes(date, lat, lon);
    final DateTime? moonrise = rawMoonTimes['rise'] != null ? (rawMoonTimes['rise'] as DateTime).toLocal() : null;
    final DateTime? moonset = rawMoonTimes['set'] != null ? (rawMoonTimes['set'] as DateTime).toLocal() : null;

    // 3. Get Moon illumination
    final moonIllum = SunCalc.getMoonIllumination(date);
    final double fraction = (moonIllum['fraction'] ?? 0.0).toDouble();
    final double phase = (moonIllum['phase'] ?? 0.0).toDouble();

    // Map moon phase name and icon
    String phaseName = 'Nueva';
    String phaseIcon = '🌑';
    double phaseScore = 0.5; // score for solunar rating (new and full moon are 1.0, quarters are 0.2)

    if (phase < 0.06 || phase >= 0.94) {
      phaseName = 'Luna Nueva';
      phaseIcon = '🌑';
      phaseScore = 1.0; // Excellent fishing!
    } else if (phase >= 0.06 && phase < 0.19) {
      phaseName = 'Creciente Cóncava';
      phaseIcon = '🌒';
      phaseScore = 0.4;
    } else if (phase >= 0.19 && phase < 0.31) {
      phaseName = 'Cuarto Creciente';
      phaseIcon = '🌓';
      phaseScore = 0.2;
    } else if (phase >= 0.31 && phase < 0.44) {
      phaseName = 'Creciente Gibosa';
      phaseIcon = '🌔';
      phaseScore = 0.5;
    } else if (phase >= 0.44 && phase < 0.56) {
      phaseName = 'Luna Llena';
      phaseIcon = '🌕';
      phaseScore = 1.0; // Excellent fishing!
    } else if (phase >= 0.56 && phase < 0.69) {
      phaseName = 'Menguante Gibosa';
      phaseIcon = '🌖';
      phaseScore = 0.5;
    } else if (phase >= 0.69 && phase < 0.81) {
      phaseName = 'Cuarto Menguante';
      phaseIcon = '🌗';
      phaseScore = 0.2;
    } else if (phase >= 0.81 && phase < 0.94) {
      phaseName = 'Menguante Cóncava';
      phaseIcon = '🌘';
      phaseScore = 0.4;
    }

    // 4. Calculate Major periods (based on transit and underfoot times)
    // Find transit (moon at highest altitude) and underfoot (moon at lowest altitude)
    final DateTime startOfDay = DateTime(date.year, date.month, date.day, 0, 0, 0);
    DateTime transitTime = startOfDay.add(const Duration(hours: 12));
    DateTime underfootTime = startOfDay.add(const Duration(hours: 0));

    double maxAlt = -999.0;
    double minAlt = 999.0;

    // Phase 1: Rough hourly scan
    for (int hour = 0; hour <= 24; hour++) {
      final checkTime = startOfDay.add(Duration(hours: hour));
      final pos = SunCalc.getMoonPosition(checkTime, lat, lon);
      final double alt = (pos['altitude'] ?? 0.0).toDouble();

      if (alt > maxAlt) {
        maxAlt = alt;
        transitTime = checkTime;
      }
      if (alt < minAlt) {
        minAlt = alt;
        underfootTime = checkTime;
      }
    }

    // Phase 2: Refined 10-minute scan around peaks
    double refinedMaxAlt = -999.0;
    DateTime refinedTransit = transitTime;
    for (int offsetMin = -60; offsetMin <= 60; offsetMin += 10) {
      final checkTime = transitTime.add(Duration(minutes: offsetMin));
      final pos = SunCalc.getMoonPosition(checkTime, lat, lon);
      final double alt = (pos['altitude'] ?? 0.0).toDouble();
      if (alt > refinedMaxAlt) {
        refinedMaxAlt = alt;
        refinedTransit = checkTime;
      }
    }

    double refinedMinAlt = 999.0;
    DateTime refinedUnderfoot = underfootTime;
    for (int offsetMin = -60; offsetMin <= 60; offsetMin += 10) {
      final checkTime = underfootTime.add(Duration(minutes: offsetMin));
      final pos = SunCalc.getMoonPosition(checkTime, lat, lon);
      final double alt = (pos['altitude'] ?? 0.0).toDouble();
      if (alt < refinedMinAlt) {
        refinedMinAlt = alt;
        refinedUnderfoot = checkTime;
      }
    }

    final List<SolunarPeriod> periods = [];

    // Major 1: Transit
    periods.add(SolunarPeriod(
      name: 'Período Mayor 1 (Luna en Cenit)',
      start: refinedTransit.subtract(const Duration(hours: 1)),
      end: refinedTransit.add(const Duration(hours: 1)),
      type: PeriodType.major,
      activityLevel: 0.8 + (phaseScore * 0.2), // peaks during new/full moon
    ));

    // Major 2: Underfoot
    periods.add(SolunarPeriod(
      name: 'Período Mayor 2 (Luna en Nadir)',
      start: refinedUnderfoot.subtract(const Duration(hours: 1)),
      end: refinedUnderfoot.add(const Duration(hours: 1)),
      type: PeriodType.major,
      activityLevel: 0.7 + (phaseScore * 0.2),
    ));

    // Minor 1: Moonrise
    if (moonrise != null) {
      periods.add(SolunarPeriod(
        name: 'Período Menor 1 (Salida Lunar)',
        start: moonrise.subtract(const Duration(minutes: 30)),
        end: moonrise.add(const Duration(minutes: 30)),
        type: PeriodType.minor,
        activityLevel: 0.5 + (phaseScore * 0.15),
      ));
    }

    // Minor 2: Moonset
    if (moonset != null) {
      periods.add(SolunarPeriod(
        name: 'Período Menor 2 (Puesta Lunar)',
        start: moonset.subtract(const Duration(minutes: 30)),
        end: moonset.add(const Duration(minutes: 30)),
        type: PeriodType.minor,
        activityLevel: 0.4 + (phaseScore * 0.15),
      ));
    }

    // Calculate daily rating
    // Best rating when phaseScore is high (New/Full Moon) and major periods overlap sunrise/sunset.
    double dayRating = 0.3 + (phaseScore * 0.4);

    // Overlap checks
    for (var p in periods) {
      // Overlap with sunrise +/- 1 hour or sunset +/- 1 hour boosts rating
      final sunriseOverlap = _overlaps(p.start, p.end, sunrise.subtract(const Duration(hours: 1)), sunrise.add(const Duration(hours: 1)));
      final sunsetOverlap = _overlaps(p.start, p.end, sunset.subtract(const Duration(hours: 1)), sunset.add(const Duration(hours: 1)));
      if (sunriseOverlap || sunsetOverlap) {
        dayRating += 0.15;
      }
    }
    if (dayRating > 1.0) dayRating = 1.0;

    return SolunarInfo(
      sunrise: sunrise,
      sunset: sunset,
      moonrise: moonrise,
      moonset: moonset,
      moonIllumination: fraction,
      moonPhaseName: phaseName,
      moonPhaseIcon: phaseIcon,
      periods: periods,
      dayRating: dayRating,
    );
  }

  static bool _overlaps(DateTime start1, DateTime end1, DateTime start2, DateTime end2) {
    return start1.isBefore(end2) && end1.isAfter(start2);
  }
}
