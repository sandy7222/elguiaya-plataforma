import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/viaje_tracking_service.dart';

class AuditorMapWidget extends StatelessWidget {
  final dynamic trackLog;
  final LatLng? puntoInicial;

  const AuditorMapWidget({
    super.key, 
    required this.trackLog,
    this.puntoInicial,
  });

  @override
  Widget build(BuildContext context) {
    final List<LatLng> puntos = ViajeTrackingService.parseTrackLog(trackLog);
    
    // Si no hay puntos, mostrar un estado vacío elegante
    if (puntos.isEmpty) {
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
              Text('No hay registros de GPS para este viaje aún.', 
                style: TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
        ),
      );
    }

    // Calcular el centro del mapa basado en el primer punto si no se provee uno
    final center = puntoInicial ?? puntos.first;

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
            // La Polilínea del Auditor
            PolylineLayer(
              polylines: [
                Polyline(
                  points: puntos,
                  color: const Color(0xFF00E676),
                  strokeWidth: 4.0,
                ),
              ],
            ),
            // Marcadores de inicio y fin
            MarkerLayer(
              markers: [
                Marker(
                  point: puntos.first,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.anchor, color: Colors.blue, size: 30),
                ),
                Marker(
                  point: puntos.last,
                  width: 40,
                  height: 40,
                  child: const Icon(Icons.location_on, color: Colors.red, size: 30),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
