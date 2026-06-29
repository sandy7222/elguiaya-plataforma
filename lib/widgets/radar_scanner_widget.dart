import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/cotizacion.dart';

const String _tileUserAgent = 'com.example.capitanya_master';

/// Mapa táctico con barrido de radar animado (pescador buscando capitanes / capitán en zona).
class RadarScannerWidget extends StatefulWidget {
  final String mensaje;
  final Cotizacion? cotizacion;
  final LatLng? mapCenter;
  final double? mapZoom;
  final double? radioKm;
  final Color blipColor;

  const RadarScannerWidget({
    required this.mensaje,
    this.cotizacion,
    this.mapCenter,
    this.mapZoom,
    this.radioKm,
    this.blipColor = const Color(0xFF00E676),
    super.key,
  });

  @override
  State<RadarScannerWidget> createState() => _RadarScannerWidgetState();
}

class _RadarScannerWidgetState extends State<RadarScannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<RadarBlip> _blips = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    for (int i = 0; i < 4; i++) {
      _blips.add(
        RadarBlip(
          angle: _random.nextDouble() * 2 * pi,
          distance: 0.2 + _random.nextDouble() * 0.6,
          size: 3.0 + _random.nextDouble() * 3.0,
          baseOpacity: 0.3 + _random.nextDouble() * 0.7,
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng _resolveMapCenter() {
    if (widget.mapCenter != null) return widget.mapCenter!;
    if (widget.cotizacion != null && widget.cotizacion!.tieneDatosGeograficos) {
      final lat1 = widget.cotizacion!.latitudPartida;
      final lon1 = widget.cotizacion!.longitudPartida;
      final lat2 = widget.cotizacion!.latitudDestino;
      final lon2 = widget.cotizacion!.longitudDestino;
      if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
        return LatLng((lat1 + lat2) / 2, (lon1 + lon2) / 2);
      }
    }
    return const LatLng(-34.4250, -58.5796);
  }

  double _resolveMapZoom() {
    if (widget.mapZoom != null) return widget.mapZoom!;
    if (widget.radioKm != null) return _zoomFromRadioKm(widget.radioKm!);
    if (widget.cotizacion?.distanciaKm != null) {
      final dist = widget.cotizacion!.distanciaKm!;
      if (dist < 2.0) return 15.0;
      if (dist < 5.0) return 14.0;
      if (dist < 15.0) return 13.0;
      if (dist < 40.0) return 11.5;
      return 10.0;
    }
    return 13.0;
  }

  static double _zoomFromRadioKm(double radioKm) {
    if (radioKm <= 10) return 12.0;
    if (radioKm <= 25) return 11.0;
    if (radioKm <= 50) return 10.0;
    if (radioKm <= 100) return 9.0;
    return 8.0;
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter = _resolveMapCenter();
    final mapZoom = _resolveMapZoom();
    final accent = widget.blipColor;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF001F3F).withOpacity(0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 190,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.15)),
            ),
            child: Stack(
              children: [
                Container(
                  color: const Color(0xFF000B18),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: mapCenter,
                      initialZoom: mapZoom,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: _tileUserAgent,
                      ),
                      if (widget.radioKm != null)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: mapCenter,
                              radius: widget.radioKm! * 1000,
                              useRadiusInMeter: true,
                              color: accent.withOpacity(0.08),
                              borderColor: accent.withOpacity(0.45),
                              borderStrokeWidth: 1.5,
                            ),
                          ],
                        ),
                      if (widget.cotizacion != null &&
                          widget.cotizacion!.tieneDatosGeograficos) ...[
                        PolylineLayer(
                          polylines: <Polyline<Object>>[
                            if (widget.cotizacion!.trackLog != null &&
                                widget.cotizacion!.trackLog!.isNotEmpty)
                              Polyline<Object>(
                                points: widget.cotizacion!.trackLog!
                                    .map(
                                      (e) => LatLng(
                                        (e['lat'] as num).toDouble(),
                                        (e['lon'] as num).toDouble(),
                                      ),
                                    )
                                    .toList(),
                                strokeWidth: 3.0,
                                color: accent.withOpacity(0.6),
                              )
                            else
                              Polyline<Object>(
                                points: [
                                  LatLng(
                                    widget.cotizacion!.latitudPartida!,
                                    widget.cotizacion!.longitudPartida!,
                                  ),
                                  LatLng(
                                    widget.cotizacion!.latitudDestino!,
                                    widget.cotizacion!.longitudDestino!,
                                  ),
                                ],
                                strokeWidth: 2.0,
                                color: accent.withOpacity(0.4),
                              ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            if (widget.cotizacion!.latitudPartida != null &&
                                widget.cotizacion!.longitudPartida != null)
                              Marker(
                                point: LatLng(
                                  widget.cotizacion!.latitudPartida!,
                                  widget.cotizacion!.longitudPartida!,
                                ),
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: accent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accent,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (widget.cotizacion!.latitudDestino != null &&
                                widget.cotizacion!.longitudDestino != null)
                              Marker(
                                point: LatLng(
                                  widget.cotizacion!.latitudDestino!,
                                  widget.cotizacion!.longitudDestino!,
                                ),
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.redAccent,
                                        blurRadius: 4,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ] else if (widget.mapCenter != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: mapCenter,
                              width: 16,
                              height: 16,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.6),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                IgnorePointer(
                  child: Container(color: Colors.black.withOpacity(0.05)),
                ),
                _buildDegreeLabels(leftSide: true, accent: accent),
                _buildDegreeLabels(leftSide: false, accent: accent),
                Positioned.fill(
                  child: IgnorePointer(
                    child: RadarSweepOverlay(
                      controller: _controller,
                      blips: _blips,
                      accentColor: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          PalpitandoTexto(mensaje: widget.mensaje, accentColor: accent),
        ],
      ),
    );
  }

  Widget _buildDegreeLabels({required bool leftSide, required Color accent}) {
    const labelsLeft = ['300\u00B0', '285\u00B0', '270\u00B0', '255\u00B0', '240\u00B0'];
    const labelsRight = ['60\u00B0', '75\u00B0', '90\u00B0', '105\u00B0', '120\u00B0'];
    final labels = leftSide ? labelsLeft : labelsRight;
    final textStyle = TextStyle(
      color: accent.withOpacity(0.6),
      fontSize: 9,
      fontWeight: FontWeight.bold,
    );

    return Positioned(
      left: leftSide ? 12 : null,
      right: leftSide ? null : 12,
      top: 0,
      bottom: 0,
      child: IgnorePointer(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment:
              leftSide ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: labels
              .map((label) => Text(label, style: textStyle))
              .toList(),
        ),
      ),
    );
  }
}

/// Capa de barrido animado reutilizable sobre cualquier mapa.
class RadarSweepOverlay extends StatelessWidget {
  final AnimationController controller;
  final List<RadarBlip> blips;
  final Color accentColor;

  const RadarSweepOverlay({
    required this.controller,
    required this.blips,
    this.accentColor = const Color(0xFF00E676),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: RadarSweepPainter(
            sweepAngle: controller.value * 2 * pi,
            blips: blips,
            accentColor: accentColor,
          ),
        );
      },
    );
  }
}

/// Overlay autónomo con animación propia (p. ej. pantalla de configuración de zona).
class RadarSweepAnimatedOverlay extends StatefulWidget {
  final Color accentColor;
  final int blipCount;

  const RadarSweepAnimatedOverlay({
    this.accentColor = const Color(0xFF00E676),
    this.blipCount = 4,
    super.key,
  });

  @override
  State<RadarSweepAnimatedOverlay> createState() =>
      _RadarSweepAnimatedOverlayState();
}

class _RadarSweepAnimatedOverlayState extends State<RadarSweepAnimatedOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<RadarBlip> _blips;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    final random = Random();
    _blips = List.generate(widget.blipCount, (_) {
      return RadarBlip(
        angle: random.nextDouble() * 2 * pi,
        distance: 0.2 + random.nextDouble() * 0.6,
        size: 3.0 + random.nextDouble() * 3.0,
        baseOpacity: 0.3 + random.nextDouble() * 0.7,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          RadarSweepOverlay(
            controller: _controller,
            blips: _blips,
            accentColor: widget.accentColor,
          ),
          Positioned(
            left: 12,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: ['300\u00B0', '285\u00B0', '270\u00B0', '255\u00B0', '240\u00B0']
                  .map(
                    (label) => Text(
                      label,
                      style: TextStyle(
                        color: widget.accentColor.withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          Positioned(
            right: 12,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: ['60\u00B0', '75\u00B0', '90\u00B0', '105\u00B0', '120\u00B0']
                  .map(
                    (label) => Text(
                      label,
                      style: TextStyle(
                        color: widget.accentColor.withOpacity(0.6),
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class PalpitandoTexto extends StatefulWidget {
  final String mensaje;
  final Color accentColor;

  const PalpitandoTexto({
    required this.mensaje,
    this.accentColor = const Color(0xFF00E676),
    super.key,
  });

  @override
  State<PalpitandoTexto> createState() => _PalpitandoTextoState();
}

class _PalpitandoTextoState extends State<PalpitandoTexto>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_fadeController);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: widget.accentColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor,
                  blurRadius: 6,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              widget.mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: widget.accentColor,
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RadarBlip {
  final double angle;
  final double distance;
  final double size;
  final double baseOpacity;

  const RadarBlip({
    required this.angle,
    required this.distance,
    required this.size,
    required this.baseOpacity,
  });
}

class RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final List<RadarBlip> blips;
  final Color accentColor;

  RadarSweepPainter({
    required this.sweepAngle,
    required this.blips,
    this.accentColor = const Color(0xFF00E676),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    final maxRadius =
        sqrt(size.width * size.width + size.height * size.height) / 2;

    final bgPaint = Paint()
      ..color = accentColor.withOpacity(0.02)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final gridPaint = Paint()
      ..color = accentColor.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.75, gridPaint);
    canvas.drawCircle(center, radius * 0.5, gridPaint);
    canvas.drawCircle(center, radius * 0.25, gridPaint);
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      gridPaint,
    );

    for (final blip in blips) {
      double diff = (sweepAngle - blip.angle) % (2 * pi);
      if (diff < 0) diff += 2 * pi;

      double opacity = 0.0;
      if (diff < pi / 2) {
        opacity = (1.0 - (diff / (pi / 2))) * blip.baseOpacity;
      } else if (diff > 1.5 * pi) {
        opacity = 0.05;
      } else {
        opacity = 0.05;
      }

      if (opacity > 0.0) {
        final blipX = center.dx + cos(blip.angle) * maxRadius * blip.distance;
        final blipY = center.dy + sin(blip.angle) * maxRadius * blip.distance;

        final blipPaint = Paint()
          ..color = accentColor.withOpacity(opacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(blipX, blipY), blip.size, blipPaint);

        final glowPaint = Paint()
          ..color = accentColor.withOpacity(opacity * 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(blipX, blipY), blip.size * 2.2, glowPaint);
      }
    }

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          accentColor.withOpacity(0.25),
          accentColor.withOpacity(0.08),
          accentColor.withOpacity(0.0),
          accentColor.withOpacity(0.0),
        ],
        stops: const [0.0, 0.15, 0.4, 1.0],
        transform: GradientRotation(sweepAngle - 0.2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweepPaint);

    final sweepLinePaint = Paint()
      ..color = accentColor.withOpacity(0.7)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final lineEndX = center.dx + cos(sweepAngle) * maxRadius;
    final lineEndY = center.dy + sin(sweepAngle) * maxRadius;
    canvas.drawLine(center, Offset(lineEndX, lineEndY), sweepLinePaint);
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.accentColor != accentColor;
  }
}
