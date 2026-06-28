import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/viaje_tracking_service.dart';

class AuditorMapWidget extends StatelessWidget {
  final dynamic trackLog;
  final LatLng? puntoInicial;
  final bool showRolesSeparately;

  const AuditorMapWidget({
    super.key,
    required this.trackLog,
    this.puntoInicial,
    this.showRolesSeparately = false,
  });

  @override
  Widget build(BuildContext context) {
    final capitanPts = ViajeTrackingService.parseTrackLogCapitan(trackLog);
    final pescadorPts = ViajeTrackingService.parseTrackLogPescador(trackLog);
    final allPts = showRolesSeparately && pescadorPts.isNotEmpty
        ? [...capitanPts, ...pescadorPts]
        : ViajeTrackingService.parseTrackLog(trackLog);

    if (allPts.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.gps_off, color: Colors.white24, size: 40),
              SizedBox(height: 12),
              Text(
                'No hay registros de GPS para este viaje a�n.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    final center = puntoInicial ?? allPts.first;
    final polylines = <Polyline>[];

    if (showRolesSeparately && capitanPts.isNotEmpty) {
      polylines.add(Polyline(
        points: capitanPts,
        color: const Color(0xFF00E676),
        strokeWidth: 4.0,
      ));
    }
    if (showRolesSeparately && pescadorPts.isNotEmpty) {
      polylines.add(Polyline(
        points: pescadorPts,
        color: Colors.blueAccent,
        strokeWidth: 3.5,
      ));
    }
    if (!showRolesSeparately || polylines.isEmpty) {
      polylines.add(Polyline(
        points: allPts,
        color: const Color(0xFF00E676),
        strokeWidth: 4.0,
      ));
    }

    final markers = <Marker>[];
    if (capitanPts.isNotEmpty) {
      markers.add(Marker(
        point: capitanPts.first,
        width: 40,
        height: 40,
        child: const Icon(Icons.anchor, color: Colors.blue, size: 30),
      ));
    }
    final endPts = pescadorPts.isNotEmpty ? pescadorPts : capitanPts;
    if (endPts.isNotEmpty) {
      markers.add(Marker(
        point: endPts.last,
        width: 40,
        height: 40,
        child: const Icon(Icons.location_on, color: Colors.red, size: 30),
      ));
    }

    return Container(
      height: 300,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.El Guia YA.app',
            ),
            PolylineLayer(polylines: polylines),
            if (markers.isNotEmpty) MarkerLayer(markers: markers),
          ],
        ),
      ),
    );
  }
}
