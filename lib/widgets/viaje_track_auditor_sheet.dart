import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/viaje_tracking_service.dart';
import '../widgets/auditor_map_widget.dart';
import '../widgets/safe_button.dart';
import '../screens/manifiesto_pasajeros_screen.dart';

/// Bottom sheet de auditoría GPS de un viaje (admin).
class ViajeTrackAuditorSheet extends StatefulWidget {
  final Map<String, dynamic> viaje;

  const ViajeTrackAuditorSheet({super.key, required this.viaje});

  static Future<void> show(BuildContext context, Map<String, dynamic> viaje) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ViajeTrackAuditorSheet(viaje: viaje),
    );
  }

  @override
  State<ViajeTrackAuditorSheet> createState() => _ViajeTrackAuditorSheetState();
}

class _ViajeTrackAuditorSheetState extends State<ViajeTrackAuditorSheet> {
  Timer? _refreshTimer;
  List<dynamic> _trackLog = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _trackLog = List<dynamic>.from(widget.viaje['track_log'] as List? ?? []);
    if (_isEnCurso) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        _reloadTrackLog();
      });
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  bool get _isEnCurso => widget.viaje['estado']?.toString() == 'en_curso';

  Future<void> _reloadTrackLog() async {
    final pedidoId = widget.viaje['id']?.toString() ?? '';
    if (pedidoId.isEmpty) return;
    setState(() => _loading = true);
    final log = await ViajeTrackingService.fetchTrackLog(pedidoId);
    if (mounted) {
      setState(() {
        _trackLog = log;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final viaje = widget.viaje;
    double distanciaTotal = 0;
    Duration duracion = Duration.zero;

    if (_trackLog.length > 1) {
      for (int i = 0; i < _trackLog.length - 1; i++) {
        final a = _trackLog[i] as Map<String, dynamic>;
        final b = _trackLog[i + 1] as Map<String, dynamic>;
        distanciaTotal += Geolocator.distanceBetween(
          (a['lat'] as num).toDouble(),
          (a['lng'] as num).toDouble(),
          (b['lat'] as num).toDouble(),
          (b['lng'] as num).toDouble(),
        );
      }
      distanciaTotal = distanciaTotal / 1000;

      final ts0 = _trackLog.first['ts']?.toString();
      final ts1 = _trackLog.last['ts']?.toString();
      if (ts0 != null && ts1 != null) {
        duracion = DateTime.parse(ts1).difference(DateTime.parse(ts0));
      }
    }

    final rawId = viaje['id']?.toString() ?? '--------';
    final codigo = '#VJ-${rawId.replaceAll('-', '').toUpperCase().substring(0, 4)}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Color(0xFF001F3F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'AUDITORÍA DE VIAJE',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    codigo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    ),
                  IconButton(
                    onPressed: _reloadTrackLog,
                    icon: const Icon(Icons.refresh, color: Colors.white54),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
          if (_isEnCurso)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Viaje en curso — actualización automática cada 45 s',
                style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 11),
              ),
            ),
          const SizedBox(height: 16),
          AuditorMapWidget(trackLog: _trackLog, showRolesSeparately: true),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _kpi('DISTANCIA', '${distanciaTotal.toStringAsFixed(2)} KM', Icons.straighten),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _kpi('DURACIÓN', '${duracion.inMinutes} MIN', Icons.timer),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _infoRow('CAPITÁN', viaje['capitan']?['nombre'] ?? 'N/A'),
          _infoRow('CLIENTE', viaje['pescador']?['nombre'] ?? 'N/A'),
          _infoRow(
            'ESTADO',
            viaje['estado']?.toString().toUpperCase() ?? 'N/A',
            color: Colors.greenAccent,
          ),
          const Spacer(),
          SafeElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ManifiestoPasajerosScreen(
                    pedidoId: viaje['id']?.toString() ?? '',
                  ),
                ),
              );
            },
            icon: Icons.assignment,
            label: 'Ver manifiesto de pasajeros',
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.1),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            iconColor: Colors.white,
            textStyle: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpi(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
          Text(value,
              style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
