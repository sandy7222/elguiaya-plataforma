import 'package:flutter/material.dart';
import 'dart:ui';
import '../services/solunar_service.dart';
import '../services/location_preference_service.dart';

class SolunarCardWidget extends StatefulWidget {
  const SolunarCardWidget({super.key});

  @override
  State<SolunarCardWidget> createState() => _SolunarCardWidgetState();
}

class _SolunarCardWidgetState extends State<SolunarCardWidget> {
  bool _isExpanded = false;
  bool _isLoading = true;
  SolunarInfo? _solunarInfo;
  LocationDetails? _location;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final loc = await LocationPreferenceService.getPredefinedLocation();
    final info = await SolunarService.calculateSolunar(DateTime.now(), loc.latitude, loc.longitude);
    if (mounted) {
      setState(() {
        _location = loc;
        _solunarInfo = info;
        _isLoading = false;
      });
    }
  }

  Future<void> _recargarConGPS() async {
    setState(() => _isLoading = true);
    final gpsLoc = await LocationPreferenceService.getCurrentGPSLocation();
    final info = await SolunarService.calculateSolunar(DateTime.now(), gpsLoc.latitude, gpsLoc.longitude);
    if (mounted) {
      setState(() {
        _location = gpsLoc;
        _solunarInfo = info;
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ubicación GPS sincronizada: ${gpsLoc.latitude.toStringAsFixed(3)}, ${gpsLoc.longitude.toStringAsFixed(3)}'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF001F3F).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: const CircularProgressIndicator(color: Colors.amber),
      );
    }

    final info = _solunarInfo!;
    final loc = _location!;

    // Puntuación de pesca del día (1 a 4 peces según dayRating)
    int fishIcons = 1;
    String ratingText = 'Baja';
    Color ratingColor = Colors.grey;

    if (info.dayRating >= 0.8) {
      fishIcons = 4;
      ratingText = 'Excelente';
      ratingColor = const Color(0xFF00E676); // Green
    } else if (info.dayRating >= 0.6) {
      fishIcons = 3;
      ratingText = 'Muy Buena';
      ratingColor = Colors.cyanAccent;
    } else if (info.dayRating >= 0.4) {
      fishIcons = 2;
      ratingText = 'Buena';
      ratingColor = Colors.amber;
    } else {
      fishIcons = 1;
      ratingText = 'Regular';
      ratingColor = Colors.orangeAccent;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF0A192F).withValues(alpha: 0.95),
                const Color(0xFF172A45).withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        info.moonPhaseIcon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TABLA SOLUNAR',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Text(
                                ratingText.toUpperCase(),
                                style: TextStyle(
                                  color: ratingColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildPescaFishRating(fishIcons, ratingColor),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.gps_fixed, color: Colors.amber, size: 16),
                      onPressed: _recargarConGPS,
                      tooltip: 'Sincronizar GPS',
                    ),
                    Icon(
                      _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                    ),
                  ],
                ),
              ),

              // Expandable content
              if (_isExpanded) ...[
                const SizedBox(height: 16),
                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 16),

                // Location name indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'ZONA: ${loc.name}',
                      style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
                    ),
                    InkWell(
                      onTap: _cargarDatos,
                      child: const Icon(Icons.refresh, color: Colors.white54, size: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Orbit Trajectory Custom Paint Illustration
                Container(
                  height: 90,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                  ),
                  child: CustomPaint(
                    painter: _OrbitPainter(
                      sunrise: info.sunrise,
                      sunset: info.sunset,
                      moonrise: info.moonrise,
                      moonset: info.moonset,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Detailed information grid (Sunrise, Sunset, Moon phase)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildTimeDetail('Salida Sol', info.sunrise, Icons.wb_sunny_rounded, Colors.amber),
                    _buildTimeDetail('Puesta Sol', info.sunset, Icons.wb_twilight_rounded, Colors.orangeAccent),
                    _buildMoonPhaseDetail(info.moonPhaseName, info.moonPhaseIcon, info.moonIllumination),
                  ],
                ),
                const SizedBox(height: 16),

                // Collapsible active fishing periods list
                const Text(
                  'PERÍODOS DE ACTIVIDAD (HORAS PICO)',
                  style: TextStyle(
                    color: Colors.white54,
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                ...info.periods.map((period) => _buildPeriodTile(period)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPescaFishRating(int filled, Color color) {
    return Row(
      children: List.generate(4, (index) {
        final active = index < filled;
        return Padding(
          padding: const EdgeInsets.only(right: 1),
          child: Icon(
            active ? Icons.set_meal_rounded : Icons.set_meal_outlined,
            color: active ? color : Colors.white10,
            size: 14,
          ),
        );
      }),
    );
  }

  Widget _buildTimeDetail(String label, DateTime time, IconData icon, Color color) {
    final String timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 48),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            timeStr,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildMoonPhaseDetail(String name, String icon, double illumination) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(icon, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 6),
          const Text(
            'Fase Lunar',
            style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${(illumination * 100).toStringAsFixed(0)}% $name',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodTile(SolunarPeriod period) {
    final startStr = '${period.start.hour.toString().padLeft(2, '0')}:${period.start.minute.toString().padLeft(2, '0')}';
    final endStr = '${period.end.hour.toString().padLeft(2, '0')}:${period.end.minute.toString().padLeft(2, '0')}';
    final isMajor = period.type == PeriodType.major;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMajor ? const Color(0xFF00E676).withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMajor ? const Color(0xFF00E676).withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                isMajor ? Icons.offline_bolt_rounded : Icons.flash_on_rounded,
                color: isMajor ? const Color(0xFF00E676) : Colors.amber,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                period.name,
                style: TextStyle(
                  color: isMajor ? Colors.white : Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            '$startStr - $endStr',
            style: TextStyle(
              color: isMajor ? const Color(0xFF00E676) : Colors.amber,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime? moonrise;
  final DateTime? moonset;

  _OrbitPainter({
    required this.sunrise,
    required this.sunset,
    this.moonrise,
    this.moonset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintHorizon = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final paintSunArc = Paint()
      ..color = Colors.amber.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw horizon line
    canvas.drawLine(
      Offset(10, size.height - 15),
      Offset(size.width - 10, size.height - 15),
      paintHorizon,
    );

    // Draw Sun Arc
    final pathSun = Path();
    pathSun.moveTo(20, size.height - 15);
    pathSun.quadraticBezierTo(
      size.width / 2,
      10,
      size.width - 20,
      size.height - 15,
    );
    canvas.drawPath(pathSun, paintSunArc);

    // Calculate current Sun position on arc
    final now = DateTime.now();
    final totalSunMinutes = sunset.difference(sunrise).inMinutes;
    final currentMinutes = now.difference(sunrise).inMinutes;

    if (currentMinutes >= 0 && currentMinutes <= totalSunMinutes && totalSunMinutes > 0) {
      final double t = currentMinutes / totalSunMinutes; // 0.0 to 1.0
      final double x = 20 + t * (size.width - 40);
      final double y = (size.height - 15) - 4 * (10 - (size.height - 15)) * t * (t - 1); // parabolic equation

      final paintSun = Paint()
        ..color = Colors.amber
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 12, paintSun);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
