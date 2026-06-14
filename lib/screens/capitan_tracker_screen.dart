import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/viaje_tracking_service.dart';
import '../services/mapa_offline_service.dart';

class CapitanTrackerScreen extends StatefulWidget {
  final bool esCapitan;
  const CapitanTrackerScreen({super.key, this.esCapitan = true});

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

  // Variables de historial y visualización
  List<Map<String, dynamic>> _savedTracks = [];
  bool _showingHistory = false;
  List<LatLng>? _selectedHistoryRoute;
  String? _selectedHistoryName;
  String? _perfilNombre;

  @override
  void initState() {
    super.initState();
    _checkTrackingState();
    _loadSavedTracks();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('nombre')
            .eq('user_id', user.id)
            .maybeSingle();
        if (profile != null && mounted) {
          setState(() {
            _perfilNombre = profile['nombre'];
          });
        }
      }
    } catch (_) {}
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

  Future<void> _loadSavedTracks() async {
    final tracks = await ViajeTrackingService().getManualTracksLocal();
    if (mounted) {
      setState(() {
        _savedTracks = tracks;
      });
    }
  }

  void _stopManualTracking() async {
    _durationTimer?.cancel();
    _positionSubscription?.cancel();

    final TextEditingController nameController = TextEditingController(
      text: 'Ruta ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Guardar Trayecto', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ingresá un nombre para recordar este trayecto en tu historial local:', 
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ej. Salida de pesca Cañas',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _finishManualTracking(null);
            },
            child: const Text('DESCARTAR', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _finishManualTracking(nameController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _finishManualTracking(String? name) async {
    final pointsCopy = List<LatLng>.from(_routePoints);
    final durationCopy = _durationStr;
    final tripIdCopy = _currentManualTripId;

    await ViajeTrackingService().stopTracking();

    if (name != null && name.isNotEmpty && tripIdCopy != null && pointsCopy.isNotEmpty) {
      await ViajeTrackingService().saveManualTrackLocal(
        tripId: tripIdCopy,
        name: name,
        durationStr: durationCopy,
        points: pointsCopy,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💾 Trayecto "$name" guardado en tu caché local.'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🛑 Trayecto finalizado sin guardar.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    setState(() {
      _isLive = false;
      _isManual = false;
      _currentManualTripId = null;
      _routePoints.clear();
      _currentLatLng = null;
    });

    _loadSavedTracks();
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

  void _showPanicConfigDialog({VoidCallback? onSaved}) async {
    final prefs = await SharedPreferences.getInstance();
    final phoneController = TextEditingController(text: prefs.getString('panic_contact_phone') ?? '');
    final nameController = TextEditingController(text: prefs.getString('panic_contact_name') ?? '');
    final messageController = TextEditingController(
      text: prefs.getString('panic_custom_message') ?? 'Estoy navegando y sufrí un inconveniente, por favor contactame.'
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.contact_phone_outlined, color: Color(0xFF00E676)),
            SizedBox(width: 10),
            Text('Contacto de Confianza', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Configurá la persona a la que le llegará la alerta en caso de emergencia:',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Nombre del Contacto',
                  labelStyle: TextStyle(color: Colors.white60, fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Número (con código de país, ej: +54911...)',
                  labelStyle: TextStyle(color: Colors.white60, fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: messageController,
                style: const TextStyle(color: Colors.white),
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Mensaje Pregrabado',
                  labelStyle: TextStyle(color: Colors.white60, fontSize: 13),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF00E676))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (phoneController.text.trim().isEmpty || nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Por favor, completa todos los campos.')),
                );
                return;
              }
              await prefs.setString('panic_contact_phone', phoneController.text.trim());
              await prefs.setString('panic_contact_name', nameController.text.trim());
              await prefs.setString('panic_custom_message', messageController.text.trim());
              Navigator.pop(context);
              if (onSaved != null) onSaved();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showPanicAction() async {
    final prefs = await SharedPreferences.getInstance();
    final String? phone = prefs.getString('panic_contact_phone');
    final String? name = prefs.getString('panic_contact_name');
    final String? customMsg = prefs.getString('panic_custom_message');

    if (phone == null || phone.isEmpty || name == null || name.isEmpty) {
      _showPanicConfigDialog(onSaved: _showPanicAction);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 10),
            Text('🚨 Alerta y Responsabilidad', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por favor lee y acepta los siguientes términos antes de disparar la alerta:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Text(
                'Entiendo y acepto que El Guía YA es un gestor intermediario y facilitador técnico. La plataforma NO es responsable de mi seguridad ni realiza tareas de rescate o auxilio de personas.\n\nEsta función únicamente facilita el envío de mis coordenadas GPS a mi contacto de confianza para que este gestione de forma privada mi rescate o encuentro con las autoridades oficiales competentes (Prefectura Naval Argentina / Policía).',
                style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.4),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _sendPanicAlert(phone, name, customMsg ?? '');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('ACEPTAR Y ENVIAR', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendPanicAlert(String phone, String name, String customMsg) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      final String mapUrl = 'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      final String fullMessage = 
          '🚨 ALERTA ANTIPÁNICO de ${_perfilNombre ?? "Usuario"}. Necesito asistencia en el agua.\n'
          'Ubicación GPS: $mapUrl\n'
          'Mensaje pregrabado: "$customMsg"\n'
          'Por favor, comunícate de inmediato y gestiona el encuentro/rescate con Prefectura.';

      final Uri whatsappUri = Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(fullMessage)}');
      final Uri smsUri = Uri.parse('sms:$phone?body=${Uri.encodeComponent(fullMessage)}');

      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(smsUri)) {
        await launchUrl(smsUri);
      } else {
        throw 'No se pudo abrir WhatsApp ni SMS.';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al enviar alerta: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showCoordinatesDialog() async {
    setState(() => _isLoadingMap = true);
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      if (mounted) {
        setState(() => _isLoadingMap = false);
        final String coordsText = 'Lat: ${position.latitude}\nLng: ${position.longitude}';
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0A192F),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.settings_input_antenna_rounded, color: Color(0xFF00E676)),
                SizedBox(width: 10),
                Text('Coordenadas GPS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tus coordenadas actuales de alta precisión:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(
                    coordsText,
                    style: const TextStyle(
                      color: Color(0xFF00E676),
                      fontSize: 18,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Útil en zonas inhóspitas sin conexión a internet ni mapas satelitales.',
                  style: TextStyle(color: Colors.white30, fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CERRAR', style: TextStyle(color: Colors.white54)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: 'https://maps.google.com/?q=${position.latitude},${position.longitude}'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Coordenadas copiadas al portapapeles.'),
                      backgroundColor: Color(0xFF00E676),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('COPIAR MAPS'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMap = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al obtener GPS: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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

            // Botones flotantes de mapa (Descargar offline, Consulta GPS y Recentrando en columna)
            Positioned(
              bottom: _isManual ? 100 : 24,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Botón flotante para consultar coordenadas GPS rápidas
                  FloatingActionButton(
                    heroTag: 'btnCoords',
                    onPressed: _showCoordinatesDialog,
                    backgroundColor: const Color(0xFF0A192F).withOpacity(0.9),
                    foregroundColor: const Color(0xFF00E676),
                    elevation: 6,
                    shape: const CircleBorder(side: BorderSide(color: Colors.white12, width: 0.8)),
                    child: const Icon(Icons.settings_input_antenna_rounded, size: 22),
                  ),
                  const SizedBox(height: 12),

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
    return SafeArea(
      child: Column(
        children: [
          // Toggle de navegación superior
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        _showingHistory = false;
                        _selectedHistoryRoute = null;
                        _selectedHistoryName = null;
                      }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: !_showingHistory ? const Color(0xFF00E676) : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '🧭 NUEVO VIAJE',
                          style: TextStyle(
                            color: !_showingHistory ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showingHistory = true;
                          _selectedHistoryRoute = null;
                          _selectedHistoryName = null;
                        });
                        _loadSavedTracks();
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: _showingHistory ? const Color(0xFF00E676) : Colors.transparent,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '📂 HISTORIAL LOCAL',
                          style: TextStyle(
                            color: _showingHistory ? Colors.black : Colors.white60,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Expanded(
            child: _showingHistory 
              ? _selectedHistoryRoute != null 
                ? _buildHistoryRouteViewer() 
                : _buildHistoryList()
              : _buildRadarDashboard(),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarDashboard() {
    return Center(
      child: SingleChildScrollView(
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
            Text(
              widget.esCapitan ? 'SISTEMA DE NAVEGACIÓN' : 'SISTEMA DE SEGUIMIENTO PESCADOR',
              textAlign: TextAlign.center,
              style: const TextStyle(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.anchor_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 8),
                  Text(
                    widget.esCapitan ? 'MODO: EN PUERTO / ESPERA' : 'MODO: PESCADOR DEPORTIVO',
                    style: const TextStyle(
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
              widget.esCapitan
                  ? 'El tracker satelital registrará de manera automática tu posición en el mapa y la trayectoria cada 15 segundos en viajes contratados.\n\nTambién podés utilizarlo de forma manual en cualquier momento presionando el siguiente botón:'
                  : 'El tracker registrará tu posición en el mapa y tu trayectoria de pesca cada 15 segundos de forma automática para mayor seguridad.\n\nIniciá tu salida de pesca presionando el siguiente botón:',
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
                  label: Text(
                    widget.esCapitan ? 'INICIAR TRACKER' : 'INICIAR SALIDA',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, letterSpacing: 0.5),
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
            const SizedBox(height: 24),
            // Botones GPS de consulta rápida y SOS Antipánico
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _showCoordinatesDialog,
                  icon: const Icon(Icons.settings_input_antenna_rounded, color: Color(0xFF00E676), size: 18),
                  label: const Text(
                    '📍 GPS RÁPIDO',
                    style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _showPanicAction,
                  icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 18),
                  label: const Text(
                    '🚨 SOS ANTIPÁNICO',
                    style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _showPanicConfigDialog(),
                  icon: const Icon(Icons.settings, color: Colors.white54, size: 18),
                  tooltip: 'Configurar Contacto SOS',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_savedTracks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: Colors.white.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text(
              'No hay trayectos guardados',
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tus trayectos finalizados aparecerán aquí.',
              style: TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      itemCount: _savedTracks.length,
      itemBuilder: (context, index) {
        final track = _savedTracks[index];
        final String nombre = track['nombre'] ?? 'Sin Nombre';
        final String fechaRaw = track['fecha'] ?? '';
        final String duracion = track['duracion'] ?? '00:00';
        final List<dynamic> puntos = track['puntos'] ?? [];
        
        String fechaStr = fechaRaw;
        try {
          final dt = DateTime.parse(fechaRaw);
          fechaStr = DateFormat('dd/MM/yyyy - HH:mm').format(dt);
        } catch (_) {}

        return Card(
          color: const Color(0xFF0A192F).withOpacity(0.8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white10),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              nombre,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text(fechaStr, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 12, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text('Duración: $duracion', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    const SizedBox(width: 16),
                    const Icon(Icons.location_on_outlined, size: 12, color: Colors.white54),
                    const SizedBox(width: 6),
                    Text('${puntos.length} pts', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.map_outlined, color: Color(0xFF00E676)),
                  tooltip: 'Ver en Mapa',
                  onPressed: () {
                    final List<LatLng> latLngList = puntos.map((p) {
                      final map = p as Map<String, dynamic>;
                      return LatLng(map['lat'] as double, map['lng'] as double);
                    }).toList();
                    setState(() {
                      _selectedHistoryRoute = latLngList;
                      _selectedHistoryName = nombre;
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                  tooltip: 'Eliminar',
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF0A192F),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('¿Eliminar trayecto?', style: TextStyle(color: Colors.white)),
                        content: Text('¿Seguro que deseas eliminar "$nombre"? Esto no se puede deshacer.', style: const TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await ViajeTrackingService().deleteManualTrackLocal(track['id']);
                              Navigator.pop(context);
                              _loadSavedTracks();
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                            child: const Text('ELIMINAR'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHistoryRouteViewer() {
    if (_selectedHistoryRoute == null || _selectedHistoryRoute!.isEmpty) {
      return const Center(child: Text('No hay datos de ruta', style: TextStyle(color: Colors.white)));
    }
    
    return Stack(
      children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: _selectedHistoryRoute!.first,
            initialZoom: 14.0,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.El Guia YA.app',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: _selectedHistoryRoute!,
                  color: const Color(0xFF00E676),
                  strokeWidth: 4.5,
                  borderColor: Colors.black.withOpacity(0.6),
                  borderStrokeWidth: 1.5,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                // Marcador de inicio
                Marker(
                  point: _selectedHistoryRoute!.first,
                  width: 32,
                  height: 32,
                  child: const Icon(Icons.play_circle_fill, color: Color(0xFF00E676), size: 28),
                ),
                // Marcador de fin
                Marker(
                  point: _selectedHistoryRoute!.last,
                  width: 32,
                  height: 32,
                  child: const Icon(Icons.stop_circle_rounded, color: Colors.redAccent, size: 28),
                ),
              ],
            ),
          ],
        ),
        
        // Panel flotante superior con el nombre
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0A192F).withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _selectedHistoryName ?? 'Ruta Visualizada',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _selectedHistoryRoute = null;
                      _selectedHistoryName = null;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ],
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
                          _isManual 
                              ? (widget.esCapitan ? 'NAVEGACIÓN MANUAL' : 'SALIDA DE PESCA') 
                              : 'VIAJE OFICIAL EN CURSO',
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
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: _showPanicAction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: const Icon(Icons.warning_amber_rounded, size: 20),
                  ),
                  const SizedBox(height: 4),
                  const Text('SOS', style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                ],
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
