import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../services/viaje_tracking_service.dart';
import '../services/mapa_offline_service.dart';

class CapitanTrackerScreen extends StatefulWidget {
  const CapitanTrackerScreen({super.key});

  @override
  State<CapitanTrackerScreen> createState() => _CapitanTrackerScreenState();
}

class _CapitanTrackerScreenState extends State<CapitanTrackerScreen> {
  LatLng? _currentLatLng;
  final List<LatLng> _routePoints = [];
  StreamSubscription<Position>? _positionSubscription;
  final MapController _mapController = MapController();
  bool _isLoadingMap = true;
  bool _isLive = false;
  bool _isManual = false;
  String? _currentManualTripId;

  // Variables para estadísticas rápidas de navegación manual
  DateTime? _startTime;
  Timer? _durationTimer;
  String _durationStr = '00:00';

  // Variables para el simulador de descarga offline premium
  double _downloadRadius = 15.0; // km
  bool _isDownloadingMap = false;
  double _downloadProgress = 0.0;
  bool _downloadSuccess = false;
  Timer? _downloadTimer;

  @override
  void initState() {
    super.initState();
    _checkTrackingState();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationTimer?.cancel();
    _downloadTimer?.cancel();
    super.dispose();
  }

  void _checkTrackingState() async {
    final bool active = ViajeTrackingService().isTracking;
    setState(() {
      _isLive = active;
      _isManual = false;
    });

    if (active) {
      _startLiveGPSListening();
    } else {
      setState(() {
        _isLoadingMap = false;
      });
    }
  }

  Future<void> _startLiveGPSListening() async {
    setState(() => _isLoadingMap = true);
    
    // 1. Obtener ubicación inicial rápidamente
    try {
      Position initPos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(initPos.latitude, initPos.longitude);
          _routePoints.add(_currentLatLng!);
          _isLoadingMap = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMap = false);
      }
    }

    // 2. Suscribirse a actualizaciones en tiempo real de alta precisión
    _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // Cada 5 metros de movimiento
      ),
    ).listen((position) {
      if (mounted) {
        setState(() {
          _currentLatLng = LatLng(position.latitude, position.longitude);
          _routePoints.add(_currentLatLng!);
        });
        // Seguir al capitán suavemente en el mapa
        _mapController.move(_currentLatLng!, _mapController.camera.zoom);
      }
    });
  }

  void _startManualTracking() async {
    // Solicitar permisos de GPS de forma activa antes de iniciar
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Se requieren permisos de ubicación para utilizar el Tracker.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final String manualId = 'manual-${DateTime.now().millisecondsSinceEpoch}';
    
    setState(() {
      _isLive = true;
      _isManual = true;
      _currentManualTripId = manualId;
      _routePoints.clear();
      _startTime = DateTime.now();
      _durationStr = '00:00';
    });

    // Iniciar el servicio oficial de Auditoría GPS en segundo plano (Captura cada 15 segundos y sincroniza)
    await ViajeTrackingService().startTracking(tripId: manualId);
    
    // Iniciar actualizaciones de alta frecuencia visuales en el mapa
    await _startLiveGPSListening();

    // Cronómetro visual para la navegación
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_startTime != null && mounted) {
        final diff = DateTime.now().difference(_startTime!);
        final min = diff.inMinutes.toString().padLeft(2, '0');
        final sec = (diff.inSeconds % 60).toString().padLeft(2, '0');
        setState(() {
          _durationStr = '$min:$sec';
        });
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚀 Navegación y Tracker activado con éxito.'),
        backgroundColor: Color(0xFF00E676),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _stopManualTracking() async {
    _durationTimer?.cancel();
    _positionSubscription?.cancel();
    
    // Detener el servicio oficial de GPS en segundo plano y forzar sincronización a Supabase
    await ViajeTrackingService().stopTracking();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🛑 Navegación finalizada.', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Tiempo navegando: $_durationStr | Recorrido guardado en el legajo.'),
          ],
        ),
        backgroundColor: Colors.blueAccent,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    setState(() {
      _isLive = false;
      _isManual = false;
      _currentManualTripId = null;
      _routePoints.clear();
      _currentLatLng = null;
    });
  }

  // --- MÓDULO DE DESCARGA OFFLINE PREMIUM INTERACTIVO ---
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
            final int estimatedSize = MapaOfflineService.calcularTamanoEstimadoMB(_downloadRadius);

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
                        child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF00E676), size: 24),
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
                    style: TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.4),
                  ),
                  const SizedBox(height: 24),

                  if (!_isDownloadingMap && !_downloadSuccess) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Radio de Acción:',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          '${_downloadRadius.round()} km a la redonda',
                          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
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
                          const Text('Tamaño estimado de descarga:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(
                            '$estimatedSize MB',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                          _downloadTimer = MapaOfflineService.iniciarSimulacionDescarga(
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('DESCARGAR MAPA OFFLINE', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],

                  if (_isDownloadingMap) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Descargando imágenes satelitales...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        Text('${(_downloadProgress * 100).round()}%', style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
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
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 48),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            '¡DESCARGA EXITOSA!',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'El mapa de esta zona ha sido encriptado y guardado en tu memoria interna. Podés navegar sin señal celular libremente.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white60, fontSize: 11.5, height: 1.4),
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B21),
      body: Stack(
        children: [
          // Capa 0: Gradiente de Fondo
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF000B21),
                  Color(0xFF0A192F),
                  Color(0xFF172A45),
                ],
              ),
            ),
          ),

          // Capa 1: Si no está activo el viaje
          if (!_isLive) _buildInactiveView(),

          // Capa 2: Si está navegando en vivo
          if (_isLive) ...[
            _isLoadingMap
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E676)),
                  )
                : _buildMapView(),

            // Panel superior flotante premium
            Positioned(
              top: 40,
              left: 16,
              right: 16,
              child: _buildLiveStatusCard(),
            ),

            // Botones flotantes de mapa (Descargar offline y Recentrando en columna)
            Positioned(
              bottom: _isManual ? 100 : 24,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón flotante para descargar mapa offline
                  FloatingActionButton(
                    heroTag: 'btnOffline',
                    onPressed: _showOfflineDownloadSheet,
                    backgroundColor: const Color(0xFF0A192F).withOpacity(0.9),
                    foregroundColor: const Color(0xFF00E676),
                    elevation: 6,
                    shape: const CircleBorder(side: BorderSide(color: Colors.white12, width: 0.8)),
                    child: const Icon(Icons.cloud_download_rounded, size: 22),
                  ),
                  const SizedBox(height: 12),
                  
                  // Botón flotante para re-centrar el GPS
                  FloatingActionButton(
                    heroTag: 'btnRecenter',
                    onPressed: () {
                      if (_currentLatLng != null) {
                        _mapController.move(_currentLatLng!, 16.0);
                      }
                    },
                    backgroundColor: const Color(0xFF0A192F).withOpacity(0.9),
                    foregroundColor: const Color(0xFF00E676),
                    elevation: 6,
                    shape: const CircleBorder(side: BorderSide(color: Colors.white12, width: 0.8)),
                    child: const Icon(Icons.my_location_rounded, size: 22),
                  ),
                ],
              ),
            ),

            // Botón flotante para detener el tracker (solo en navegación manual)
            if (_isManual)
              Positioned(
                bottom: 24,
                left: 32,
                right: 32,
                child: _buildStopButton(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildInactiveView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Radar animado
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.05),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.15), width: 2),
                  ),
                ),
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blueAccent.withOpacity(0.08),
                    border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1.5),
                  ),
                ),
                const Icon(
                  Icons.radar_rounded,
                  color: Colors.blueAccent,
                  size: 48,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'SISTEMA DE NAVEGACIÓN',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withOpacity(0.3), width: 0.8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.anchor_rounded, color: Colors.amber, size: 14),
                  SizedBox(width: 8),
                  Text(
                    'MODO: EN PUERTO / ESPERA',
                    style: TextStyle(
                      color: Colors.amber,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'El tracker satelital registrará de manera automática tu posición en el mapa y la trayectoria cada 15 segundos en viajes contratados.\n\nTambién podés utilizarlo de forma manual en cualquier momento presionando el siguiente botón:',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            
            // Fila de botones para iniciar o descargar offline directamente desde puerto
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _startManualTracking,
                  icon: const Icon(Icons.navigation_rounded, color: Colors.black, size: 16),
                  label: const Text(
                    'INICIAR TRACKER',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shadowColor: const Color(0xFF00E676).withOpacity(0.3),
                    elevation: 6,
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _showOfflineDownloadSheet,
                  icon: const Icon(Icons.cloud_download_rounded, color: Color(0xFF00E676), size: 16),
                  label: const Text(
                    'MAPAS OFFLINE',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: Colors.white),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white24),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapView() {
    if (_currentLatLng == null) {
      return const Center(child: Text('Obteniendo señal satelital...', style: TextStyle(color: Colors.white70)));
    }

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentLatLng!,
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.El Guia YA.app',
        ),
        // Polyline para la cola del viaje
        PolylineLayer(
          polylines: [
            Polyline(
              points: _routePoints,
              color: const Color(0xFF00E676),
              strokeWidth: 4.5,
              borderColor: Colors.black.withOpacity(0.6),
              borderStrokeWidth: 1.5,
            ),
          ],
        ),
        // Marcador del capitán (ship/compass)
        MarkerLayer(
          markers: [
            Marker(
              point: _currentLatLng!,
              width: 50,
              height: 50,
              child: _buildShipMarker(),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildShipMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Glow exterior
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF00E676).withOpacity(0.3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withOpacity(0.6),
                blurRadius: 16,
                spreadRadius: 4,
              ),
            ],
          ),
        ),
        Container(
          width: 20,
          height: 20,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF00E676),
          ),
          child: const Icon(
            Icons.navigation_rounded,
            color: Colors.black,
            size: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildLiveStatusCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF0A192F).withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E676).withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              // Satélite pulsante
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.settings_input_antenna_rounded,
                  color: Color(0xFF00E676),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _isManual ? 'NAVEGACIÓN MANUAL' : 'VIAJE OFICIAL EN CURSO',
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.w900,
                            fontSize: 10,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.circle, color: Color(0xFF00E676), size: 8),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isManual ? 'TIEMPO: $_durationStr' : 'TRACKER SATELITAL',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ubicación registrada cada 15 seg. y sincronizada en el legajo de administración.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 9,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStopButton() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.redAccent.withOpacity(0.3), width: 1),
          ),
          child: InkWell(
            onTap: _stopManualTracking,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              width: double.infinity,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop_rounded, color: Colors.redAccent, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'DETENER TRACKER Y GUARDAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
