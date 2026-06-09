import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/supabase_service.dart';

class AdminHeatmapScreen extends StatefulWidget {
  const AdminHeatmapScreen({super.key});

  @override
  State<AdminHeatmapScreen> createState() => _AdminHeatmapScreenState();
}

class _AdminHeatmapScreenState extends State<AdminHeatmapScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _capitanes = [];
  Map<String, dynamic> _estadisticas = {};
  bool _isLoading = true;
  Timer? _actualizacionTimer;
  final MapController _mapController = MapController();
  
  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _grisDescanso = Color(0xFF64748B);
  static const Color _fondoClaro = Color(0xFFF5F7FA);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatos();
    _iniciarActualizacionAutomatica();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actualizacionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarDatos();
      _iniciarActualizacionAutomatica();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
    }
  }

  void _iniciarActualizacionAutomatica() {
    _actualizacionTimer?.cancel();
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarDatos();
      }
    });
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      // Cargar datos del mapa de calor
      final capitanes = await SupabaseService.getMapaCalorCapitanes();
      final estadisticas = await SupabaseService.getEstadisticasCoberturaTiempoReal();
      
      setState(() {
        _capitanes = capitanes;
        _estadisticas = estadisticas;
        _isLoading = false;
      });
      
      // Ajustar vista del mapa si hay capitanes
      if (_capitanes.isNotEmpty) {
        _ajustarVistaMapa();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar datos: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _ajustarVistaMapa() {
    if (_capitanes.isEmpty) return;
    
    // Calcular bounds de todos los capitanes
    double minLat = 90.0, maxLat = -90.0;
    double minLon = 180.0, maxLon = -180.0;
    
    for (final capitan in _capitanes) {
      final lat = capitan['centro_lat'] as double;
      final lon = capitan['centro_lon'] as double;
      
      minLat = math.min(minLat, lat);
      maxLat = math.max(maxLat, lat);
      minLon = math.min(minLon, lon);
      maxLon = math.max(maxLon, lon);
    }
    
    // Anadir margen
    final margin = 0.1;
    minLat -= margin;
    maxLat += margin;
    minLon -= margin;
    maxLon += margin;
    
    final bounds = LatLngBounds(LatLng(minLat, minLon), LatLng(maxLat, maxLon));
    _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: _fondoClaro,
      appBar: AppBar(
        title: const Text(
          'Mapa de Calor - Capitanes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header de estadisticas
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _azulNautico,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.map, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Monitor de Cobertura',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Actualizado: ${_formatHora(DateTime.now())}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Estadisticas principales
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Total Capitanes',
                              '${_estadisticas['total_capitanes'] ?? 0}',
                              Icons.people,
                              Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Activos',
                              '${_estadisticas['capitanes_activos'] ?? 0}',
                              Icons.power,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'En Descanso',
                              '${_estadisticas['capitanes_en_descanso'] ?? 0}',
                              Icons.power_off,
                              _grisDescanso,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Mapa de calor
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: const LatLng(-34.6037, -58.3816), // Buenos Aires
                          initialZoom: 10.0,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          // Tile layer
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.El Guia YA',
                          ),
                          
                          // Circulos de cobertura (mapa de calor)
                          CircleLayer(
                            circles: _capitanes.map((capitan) {
                              final centro = LatLng(
                                capitan['centro_lat'] as double,
                                capitan['centro_lon'] as double,
                              );
                              final radio = (capitan['radio_km'] as double) * 1000; // Convertir a metros
                              final disponible = capitan['disponible'] as bool;
                              
                              return CircleMarker(
                                point: centro,
                                radius: radio,
                                color: disponible 
                                    ? _azulNautico.withOpacity(0.3)
                                    : _grisDescanso.withOpacity(0.2),
                                borderColor: disponible 
                                    ? _azulNautico
                                    : _grisDescanso,
                                borderStrokeWidth: 2.0,
                              );
                            }).toList(),
                          ),
                          
                          // Marcadores de capitanes
                          MarkerLayer(
                            markers: _capitanes.map((capitan) {
                              final centro = LatLng(
                                capitan['centro_lat'] as double,
                                capitan['centro_lon'] as double,
                              );
                              final disponible = capitan['disponible'] as bool;
                              final nombre = capitan['nombre'] as String;
                              final cantidad = capitan['cantidad_cotizaciones'] as int;
                              
                              return Marker(
                                point: centro,
                                width: 120,
                                height: 40,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: disponible 
                                        ? _azulNautico 
                                        : _grisDescanso,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        disponible ? Icons.power : Icons.power_off,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          nombre.length > 10 
                                              ? '${nombre.substring(0, 10)}...'
                                              : nombre,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (cantidad > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$cantidad',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Leyenda y estadisticas adicionales
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Leyenda',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildLegendItem(
                              'Capitan Activo',
                              _azulNautico,
                              'Disponible para recibir solicitudes',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildLegendItem(
                              'Capitan en Descanso',
                              _grisDescanso,
                              'No recibiendo solicitudes',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatItem(
                              'Zonas con Cobertura',
                              '${_estadisticas['zonas_con_cobertura'] ?? 0}',
                              Icons.map,
                              _azulNautico,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatItem(
                              'Cotizaciones Hoy',
                              '${_estadisticas['cotizaciones_hoy'] ?? 0}',
                              Icons.receipt_long,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildStatItem(
                              'Sin Cobertura',
                              '${_estadisticas['cotizaciones_huerfanas_hoy'] ?? 0}',
                              Icons.warning,
                              Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String description) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  String _formatHora(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// Importar math para operaciones matematicas
