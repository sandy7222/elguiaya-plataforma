import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import '../services/supabase_service.dart';
import '../services/mapa_offline_service.dart';

class MapSelectorWidget extends StatefulWidget {
  final Function(
    Map<String, dynamic> partida,
    Map<String, dynamic> destino,
    List<Map<String, dynamic>> trackLog,
  )
  onRouteSelected;
  final Function(double distanceKm)? onDistanceChanged;
  final Map<String, dynamic>? partidaInicial;
  final Map<String, dynamic>? destinoInicial;
  final List<Map<String, dynamic>>? trackLogInicial;

  const MapSelectorWidget({
    super.key,
    required this.onRouteSelected,
    this.onDistanceChanged,
    this.partidaInicial,
    this.destinoInicial,
    this.trackLogInicial,
  });

  @override
  State<MapSelectorWidget> createState() => MapSelectorWidgetState();
}

class MapSelectorWidgetState extends State<MapSelectorWidget>
    with SingleTickerProviderStateMixin {
  static const String _tileUserAgent = 'com.example.capitanya_master';

  final MapController _mapController = MapController();
  final Distance _distanceCalculator = const Distance();
  bool _mapReady = false;

  // Recorrido multi-puntos
  final List<LatLng> _routePoints = [];
  double _totalDistance = 0.0;
  // Mapas Offline States
  bool _isDownloadingMap = false;
  double _downloadProgress = 0.0;
  bool _downloadSuccess = false;
  double _downloadRadius = 15.0;
  Timer? _downloadTimer;

  // 🚀 UNIFICADO: Solo un initState prolijo que contempla todos los casos iniciales
  @override
  void initState() {
    super.initState();

    if (widget.trackLogInicial != null && widget.trackLogInicial!.isNotEmpty) {
      for (var pt in widget.trackLogInicial!) {
        if (pt['lat'] != null && pt['lon'] != null) {
          _routePoints.add(LatLng(pt['lat'], pt['lon']));
        }
      }
      _actualizarDesdePuntos();
    } else if (widget.partidaInicial != null && widget.destinoInicial != null) {
      if (widget.partidaInicial!['lat'] != null &&
          widget.partidaInicial!['lon'] != null) {
        _routePoints.add(
          LatLng(widget.partidaInicial!['lat'], widget.partidaInicial!['lon']),
        );
      }
      if (widget.destinoInicial!['lat'] != null &&
          widget.destinoInicial!['lon'] != null) {
        _routePoints.add(
          LatLng(widget.destinoInicial!['lat'], widget.destinoInicial!['lon']),
        );
      }
      if (_routePoints.isNotEmpty) {
        _actualizarDesdePuntos();
      }
    }
  }

  void _refreshMapAfterLayout() {
    if (!mounted || !_mapReady) return;
    final center = _routePoints.isNotEmpty ? _routePoints.first : _defaultCenter;
    _mapController.move(center, _defaultZoom);
  }

  @override
  void dispose() {
    _downloadTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _showOfflineDownloadSheet() {
    setState(() {
      _isDownloadingMap = false;
      _downloadProgress = 0.0;
      _downloadSuccess = false;
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final int estimatedSize =
                MapaOfflineService.calcularTamanoEstimadoMB(_downloadRadius);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              decoration: const BoxDecoration(
                color: Color(0xFF0A192F),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border(
                  top: BorderSide(color: Colors.white10, width: 1.5),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.cloud_download_rounded,
                          color: Color(0xFF00E676),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      const Text(
                        'MAPAS OFFLINE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Descargá la geografía y trazados del río para poder navegar con total precisión en el mapa, incluso sin señal de celular ni consumo de datos.',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (!_isDownloadingMap && !_downloadSuccess) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Radio de Acción:',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '${_downloadRadius.round()} km a la redonda',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _downloadRadius,
                      min: 5.0,
                      max: 50.0,
                      divisions: 9,
                      activeColor: const Color(0xFF00E676),
                      inactiveColor: Colors.white10,
                      onChanged: (value) {
                        setSheetState(() {
                          _downloadRadius = value;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tamaño estimado de descarga:',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$estimatedSize MB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setSheetState(() {
                            _isDownloadingMap = true;
                            _downloadProgress = 0.0;
                          });

                          _downloadTimer?.cancel();
                          _downloadTimer =
                              MapaOfflineService.iniciarSimulacionDescarga(
                                radioKm: _downloadRadius,
                                onProgreso: (progreso) {
                                  if (mounted) {
                                    setSheetState(() {
                                      _downloadProgress = progreso;
                                    });
                                  }
                                },
                                onCompletado: () {
                                  if (mounted) {
                                    setSheetState(() {
                                      _isDownloadingMap = false;
                                      _downloadSuccess = true;
                                    });
                                  }
                                },
                              );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'DESCARGAR MAPA OFFLINE',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],

                  if (_isDownloadingMap) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Descargando imágenes satelitales...',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          '${(_downloadProgress * 100).round()}%',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: _downloadProgress,
                        backgroundColor: Colors.white10,
                        color: const Color(0xFF00E676),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text(
                        'Guardando en base de datos offline local...',
                        style: TextStyle(color: Colors.white30, fontSize: 9.5),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  if (_downloadSuccess) ...[
                    Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF00E676),
                              size: 48,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '¡DESCARGA EXITOSA!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'El mapa de esta zona ha sido encriptado y guardado en tu memoria interna. Podés navegar sin señal celular libremente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'ENTENDIDO',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  static const LatLng _defaultCenter = LatLng(
    -34.7245,
    -58.2598,
  ); // Quilmes por defecto
  static const double _defaultZoom = 13.0;

  Future<void> searchAndZoom(String query) async {
    if (query.length < 3) return;

    try {
      final cleanQuery = query.toLowerCase().trim();

      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(cleanQuery)}&format=json&countrycodes=ar&limit=1',
      );
      final response = await http.get(
        url,
        headers: {'User-Agent': 'El Guia YA_App'},
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lon = double.parse(results[0]['lon']);
          final target = LatLng(lat, lon);

          _animatedMapMove(target, 14.0);
        }
      }
    } catch (e) {
      debugPrint('Error en búsqueda geográfica: $e');
    }
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
      begin: _mapController.camera.center.latitude,
      end: destLocation.latitude,
    );
    final lngTween = Tween<double>(
      begin: _mapController.camera.center.longitude,
      end: destLocation.longitude,
    );
    final zoomTween = Tween<double>(
      begin: _mapController.camera.zoom,
      end: destZoom,
    );

    final controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    final animation = CurvedAnimation(
      parent: controller,
      curve: Curves.fastOutSlowIn,
    );

    controller.addListener(() {
      _mapController.move(
        LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
        zoomTween.evaluate(animation),
      );
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _actualizarDesdePuntos() {
    if (_routePoints.isEmpty) {
      setState(() => _totalDistance = 0.0);
      widget.onDistanceChanged?.call(0.0);
      return;
    }

    double dist = 0.0;
    for (int i = 0; i < _routePoints.length - 1; i++) {
      dist += _distanceCalculator.as(
        LengthUnit.Meter,
        _routePoints[i],
        _routePoints[i + 1],
      );
    }

    setState(() => _totalDistance = dist / 1000.0);
    widget.onDistanceChanged?.call(_totalDistance);

    final List<Map<String, dynamic>> trackLog = _routePoints
        .map((pt) => {'lat': pt.latitude, 'lon': pt.longitude})
        .toList();

    widget.onRouteSelected(
      {
        'lat': _routePoints.first.latitude,
        'lon': _routePoints.first.longitude,
        'nombre': 'Punto de Inicio',
      },
      {
        'lat': _routePoints.last.latitude,
        'lon': _routePoints.last.longitude,
        'nombre': 'Punto de Destino',
      },
      trackLog,
    );
  }

  void _onMapTap(LatLng point) {
    setState(() {
      _routePoints.add(point);
      _actualizarDesdePuntos();
    });
    SupabaseService.simularNuevaRutaTrazada();
  }

  List<Marker> _buildMarkers() {
    final List<Marker> markers = [];
    if (_routePoints.isEmpty) return markers;

    markers.add(
      Marker(
        point: _routePoints.first,
        width: 40,
        height: 40,
        child: Stack(
          alignment: Alignment.topCenter,
          children: [
            const Icon(Icons.location_pin, color: Color(0xFF00C853), size: 36),
            Positioned(
              top: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'A',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (_routePoints.length > 2) {
      for (int i = 1; i < _routePoints.length - 1; i++) {
        markers.add(
          Marker(
            point: _routePoints[i],
            width: 10,
            height: 10,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.blueAccent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (_routePoints.length > 1) {
      markers.add(
        Marker(
          point: _routePoints.last,
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              const Icon(Icons.location_pin, color: Colors.redAccent, size: 36),
              Positioned(
                top: 2,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'B',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return markers;
  }

  Widget _buildTelemetriaCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.straighten_rounded,
            color: Colors.blueAccent,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            '${_totalDistance.toStringAsFixed(1)} KM',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              fontSize: 11,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.greenAccent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'RUTA OK',
              style: TextStyle(
                color: Colors.black,
                fontSize: 7,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mapCenter =
        _routePoints.isNotEmpty ? _routePoints.first : _defaultCenter;

    Widget mapWidget = SizedBox.expand(
      child: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: mapCenter,
          initialZoom: _defaultZoom,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all,
          ),
          onMapReady: () {
            if (!mounted) return;
            setState(() => _mapReady = true);
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _refreshMapAfterLayout(),
            );
          },
          onTap: (_, point) => _onMapTap(point),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: _tileUserAgent,
          ),
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 4.0,
                color: Colors.blueAccent.withOpacity(0.85),
                borderColor: Colors.white,
                borderStrokeWidth: 1.5,
              ),
            ],
          ),
          MarkerLayer(markers: _buildMarkers()),
        ],
      ),
    );

    String instructStr = _routePoints.isEmpty
        ? '📍 Toca para colocar Punto A'
        : '📌 Toca para agregar más puntos';

    return Stack(
      children: [
        mapWidget,

        Positioned(
          top: 8,
          left: 8,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.70),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              instructStr,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        if (_totalDistance > 0)
          Positioned(bottom: 12, left: 8, child: _buildTelemetriaCard()),

        Positioned(
          bottom: 12,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'btnOfflineSelector',
                onPressed: _showOfflineDownloadSheet,
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                child: const Icon(Icons.cloud_download_rounded, size: 18),
              ),
              const SizedBox(width: 8),
              if (_routePoints.isNotEmpty) ...[
                FloatingActionButton.small(
                  heroTag: 'btnUndoSelector',
                  onPressed: () {
                    setState(() {
                      _routePoints.removeLast();
                      _actualizarDesdePuntos();
                    });
                  },
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.undo_rounded, size: 18),
                ),
                const SizedBox(width: 8),
              ],
              FloatingActionButton.extended(
                heroTag: 'btnResetSelector',
                onPressed: () {
                  setState(() {
                    _routePoints.clear();
                    _actualizarDesdePuntos();
                  });
                },
                backgroundColor: const Color(0xFF0D47A1),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'LIMPIAR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
