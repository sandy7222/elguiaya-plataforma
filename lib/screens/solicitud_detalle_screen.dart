import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import '../services/viaje_lifecycle_service.dart';

/// Pantalla de detalle completo de una solicitud de viaje para el Capitán.
/// Diseño Nautical Premium con Glassmorphism.
class SolicitudDetalleScreen extends StatefulWidget {
  final Map<String, dynamic> lead;
  final String capitanId;
  final VoidCallback onOfertaEnviada;

  const SolicitudDetalleScreen({
    super.key,
    required this.lead,
    required this.capitanId,
    required this.onOfertaEnviada,
  });

  @override
  State<SolicitudDetalleScreen> createState() => _SolicitudDetalleScreenState();
}

class _SolicitudDetalleScreenState extends State<SolicitudDetalleScreen>
    with TickerProviderStateMixin {
  final _montoController = TextEditingController();
  bool _enviando = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Datos del lead (por legibilidad) ──
  Map<String, dynamic> get _lead => widget.lead;
  Map<String, dynamic>? get _partida => _lead['coordenadas_partida'];
  Map<String, dynamic>? get _destino => _lead['coordenadas_destino'];
  List? get _track => _lead['track_log'] as List?;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _montoController.dispose();
    super.dispose();
  }

  // ── HELPERS ──
  List<LatLng> get _routePoints {
    final dynamic trackData = _lead['track_log'];
    
    if (trackData == null) {
      // Si no hay track_log, usamos partida y destino como respaldo
      final points = <LatLng>[];
      if (_partida != null) {
        points.add(LatLng((_partida!['lat'] as num).toDouble(), (_partida!['lon'] as num).toDouble()));
      }
      if (_destino != null) {
        points.add(LatLng((_destino!['lat'] as num).toDouble(), (_destino!['lon'] as num).toDouble()));
      }
      return points;
    }

    if (trackData is List) {
      return trackData.map((p) {
        if (p is Map) {
          return LatLng((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble());
        } else if (p is List && p.length >= 2) {
          return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
        }
        return const LatLng(0, 0);
      }).where((p) => p.latitude != 0).toList();
    }

    if (trackData is String && trackData.isNotEmpty) {
      // Intentar decodificar si es una cadena (Polyline Algorithm)
      return _decodePolyline(trackData);
    }

    return [];
  }

  String? get _staticMapUrl {
    if (_partida == null || _destino == null) return null;
    final lat1 = _partida!['lat'];
    final lon1 = _partida!['lon'];
    final lat2 = _destino!['lat'];
    final lon2 = _destino!['lon'];
    if (lat1 == null || lon1 == null || lat2 == null || lon2 == null) return null;

    final partidaStr = '$lon1,$lat1,pm2gnm';
    final destinoStr = '$lon2,$lat2,pm2rdm';
    
    String url = 'https://static-maps.yandex.ru/1.x/?l=sat&size=450,220&pt=$partidaStr~$destinoStr';
    
    final points = _routePoints;
    if (points.isNotEmpty) {
      final polyPoints = <String>[];
      final step = (points.length / 15).clamp(1, double.infinity).ceil();
      for (int i = 0; i < points.length; i += step) {
        polyPoints.add('${points[i].longitude},${points[i].latitude}');
      }
      polyPoints.add('${points.last.longitude},${points.last.latitude}');
      url += '&pl=color:0000ff80,width:4,${polyPoints.join(',')}';
    }
    return url;
  }

  Widget _buildInteractiveMap() {
    final points = _routePoints;
    final hasRoute = points.length >= 2;
    return FlutterMap(
      options: MapOptions(
        initialCameraFit: hasRoute 
          ? CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(40),
            )
          : null,
        initialCenter: !hasRoute ? _mapCenter : points.first,
        initialZoom: !hasRoute ? 12.0 : 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.El Guia YA',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: 10.0,
              color: Colors.blueAccent.withOpacity(0.3),
            ),
            Polyline(
              points: points,
              strokeWidth: 5.0,
              color: Colors.blueAccent,
              borderColor: Colors.white.withOpacity(0.7),
              borderStrokeWidth: 1.0,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            Marker(
              point: points.first,
              width: 36,
              height: 36,
              child: _mapPin(Colors.green, Icons.anchor),
            ),
            Marker(
              point: points.last,
              width: 36,
              height: 36,
              child: _mapPin(Colors.red, Icons.flag_rounded),
            ),
          ],
        ),
      ],
    );
  }

  /// Decodificador simple del algoritmo de polilíneas de Google
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  LatLng get _mapCenter {
    if (_routePoints.isNotEmpty) return _routePoints.first;
    return const LatLng(-34.7248, -58.2525); // Quilmes por defecto
  }

  String _formatFecha(String? raw) {
    if (raw == null) return 'A confirmar';
    try {
      final dt = DateTime.parse(raw);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw;
    }
  }

  // ── ENVIAR OFERTA ──
  Future<void> _enviarOferta() async {
    final monto = double.tryParse(_montoController.text.replaceAll(',', '.'));
    if (monto == null || monto <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingresá un monto válido'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _enviando = true);
    HapticFeedback.mediumImpact();

    try {
      await ViajeLifecycleService.enviarPresupuesto(
        cotizacionId: _lead['id'],
        capitanId: widget.capitanId,
        monto: monto,
        detalles: 'Servicio náutico profesional. Datos de contacto y detalles completos disponibles automáticamente al confirmar la reserva.',
      );

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(
                  '✅ Oferta de \$${monto.toStringAsFixed(0)} enviada!',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00C853),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onOfertaEnviada();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ── BUILD ──
  @override
  Widget build(BuildContext context) {
    final perfil = _lead['profiles'];
    final nombrePescador = perfil?['nombre']?.toString() ?? 'NUEVO PESCADOR';
    final descripcion = _lead['descripcion'] ?? 'Sin descripción';
    final cantidad = _lead['cantidad_personas'] ?? 1;
    final fechaIda = _formatFecha(_lead['fecha_ida']);
    final fechaVuelta = _formatFecha(_lead['fecha_vuelta']);
    final horaEncuentro = _lead['hora_encuentro'] ?? '--:--';
    final localidad = _lead['localidad_partida'] ?? 'N/D';
    final provincia = _lead['provincia_partida'] ?? '';
    final mensaje = _lead['mensaje'] ?? _lead['descripcion'] ?? '';
    final hasCarga = _lead['tiene_mercaderia'] == true || _lead['carga'] != null;
    final hasEquipo = perfil?['trae_equipo_propio'] ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF001429),
      body: Stack(
        children: [
          // ── FONDO DEGRADÉ NÁUTICO ──
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF001429),
                  Color(0xFF0D2B55),
                  Color(0xFF001F3F),
                ],
              ),
            ),
          ),

          // ── BURBUJAS DECORATIVAS ──
          Positioned(
            top: -60, right: -40,
            child: _glowOrb(Colors.blueAccent.withOpacity(0.15), 200),
          ),
          Positioned(
            bottom: 100, left: -50,
            child: _glowOrb(Colors.cyanAccent.withOpacity(0.08), 160),
          ),

          // ── CONTENIDO PRINCIPAL ──
          SafeArea(
            child: Column(
              children: [
                // Header
                _buildHeader(nombrePescador, descripcion),

                // Cuerpo scrollable
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),

                        // 1. MAPA DEL TRAYECTO
                        _buildMapaSection(),
                        const SizedBox(height: 16),

                        // 2. LOGÍSTICA DEL VIAJE
                        _buildLogisticaSection(
                          fechaIda, fechaVuelta, horaEncuentro,
                          cantidad, localidad, provincia,
                          hasEquipo, hasCarga,
                        ),
                        const SizedBox(height: 16),

                        // 3. MENSAJE DEL PESCADOR
                        if (mensaje.isNotEmpty) _buildMensajeSection(mensaje),
                        const SizedBox(height: 16),

                        // 4. FORMULARIO DE OFERTA
                        _buildFormularioOferta(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── SECCIÓN: HEADER ──
  Widget _buildHeader(String nombre, String descripcion) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            border: Border(
              bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 18),
                onPressed: () => Navigator.pop(context),
              ),
              // Live indicator pulsante
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Color(0xFF00E676), blurRadius: 8, spreadRadius: 2),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      descripcion.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Cliente: $nombre',
                      style: GoogleFonts.outfit(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _buildEstadoBadge(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEstadoBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF00E676).withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5)),
      ),
      child: Text(
        'PENDIENTE',
        style: GoogleFonts.outfit(
          color: const Color(0xFF00E676),
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  // ── SECCIÓN: MAPA ──
  Widget _buildMapaSection() {
    final points = _routePoints;
    final hasRoute = points.length >= 2;

    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.route_rounded, 'TRAZADO DE RUTA'),
          const SizedBox(height: 12),
          if (hasRoute)
            () {
              bool showInteractive = false;
              return StatefulBuilder(
                builder: (context, setMapState) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 220,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: showInteractive || _staticMapUrl == null
                                ? _buildInteractiveMap()
                                : Image.network(
                                    _staticMapUrl!,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.blueAccent,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return _buildInteractiveMap();
                                    },
                                  ),
                          ),
                          if (_staticMapUrl != null)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () {
                                  setMapState(() {
                                    showInteractive = !showInteractive;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        showInteractive ? Icons.satellite_alt_rounded : Icons.map_rounded,
                                        color: const Color(0xFF00E676),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        showInteractive ? 'VER SATÉLITE' : 'VER INTERACTIVO',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }()
          else
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map_outlined, color: Colors.white24, size: 32),
                    const SizedBox(height: 8),
                    Text(
                      'Sin trazado disponible\n(el pescador no dibujó la ruta)',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),

          // Leyenda
          if (hasRoute) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _legendItem(Colors.green, _lead['localidad_partida'] ?? 'Partida'),
                const Spacer(),
                _legendItem(Colors.red, _lead['localidad_destino'] ?? 'Destino'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── SECCIÓN: LOGÍSTICA ──
  Widget _buildLogisticaSection(
    String fechaIda, String fechaVuelta, String hora,
    int cantidad, String localidad, String provincia,
    bool hasEquipo, bool hasCarga,
  ) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.event_note_rounded, 'LOGÍSTICA DEL VIAJE'),
          const SizedBox(height: 16),
          // Grid de datos
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.8,
            children: [
              _dataChip(Icons.calendar_today_rounded, 'IDA', fechaIda, Colors.blueAccent),
              _dataChip(Icons.calendar_month_rounded, 'VUELTA', fechaVuelta, Colors.cyanAccent),
              _dataChip(Icons.access_time_rounded, 'ENCUENTRO', hora, Colors.amberAccent),
              _dataChip(Icons.group_rounded, 'PASAJEROS', '$cantidad personas', Colors.purpleAccent),
              _dataChip(Icons.location_on_rounded, 'ZONA', '$localidad, $provincia', Colors.orangeAccent),
              _dataChip(
                hasEquipo ? Icons.check_circle_rounded : Icons.shopping_bag_rounded,
                'EQUIPO',
                hasEquipo ? 'Trae propio' : 'Necesita alquiler',
                hasEquipo ? Colors.greenAccent : Colors.orangeAccent,
              ),
            ],
          ),
          if (hasCarga) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.inventory_2_rounded, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '⚠️ Viaje con carga/mercadería incluida',
                    style: GoogleFonts.outfit(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── SECCIÓN: MENSAJE ──
  Widget _buildMensajeSection(String mensaje) {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.chat_bubble_outline_rounded, 'MENSAJE DEL PESCADOR'),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Text(
              '"$mensaje"',
              style: GoogleFonts.outfit(
                color: Colors.white70,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Advertencia zero-leak
          Row(
            children: [
              const Icon(Icons.lock_outline, color: Colors.amber, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Los datos de contacto se revelan solo tras el pago. Sistema Zero-Leak.',
                  style: GoogleFonts.outfit(color: Colors.amber.withOpacity(0.7), fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── SECCIÓN: FORMULARIO DE OFERTA ──
  Widget _buildFormularioOferta() {
    return _glassCard(
      borderColor: const Color(0xFF00E676).withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(Icons.monetization_on_rounded, 'TU OFERTA AL PESCADOR', color: const Color(0xFF00E676)),
          const SizedBox(height: 16),

          // Campo de monto
          TextField(
            controller: _montoController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,\.]'))],
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
            decoration: InputDecoration(
              hintText: '0',
              hintStyle: GoogleFonts.outfit(color: Colors.white24, fontSize: 24),
              prefixText: '\$ ',
              prefixStyle: GoogleFonts.outfit(
                color: const Color(0xFF00E676),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              suffixText: 'ARS',
              suffixStyle: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
              filled: true,
              fillColor: Colors.white.withOpacity(0.06),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF00E676), width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          ),
          const SizedBox(height: 12),
          // Se eliminó la caja de texto para mantener la plataforma Zero-Leak

          // Botón Premium
          GestureDetector(
            onTap: _enviando ? null : _enviarOferta,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _enviando
                    ? LinearGradient(colors: [Colors.grey.shade700, Colors.grey.shade600])
                    : const LinearGradient(
                        colors: [Color(0xFF00C853), Color(0xFF00E676)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                boxShadow: _enviando
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFF00E676).withOpacity(0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
              ),
              child: Center(
                child: _enviando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.send_rounded, color: Colors.black87, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'ENVIAR OFERTA AL PESCADOR',
                              style: GoogleFonts.outfit(
                                color: Colors.black87,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── WIDGETS UTILITARIOS ──

  Widget _glassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _sectionLabel(IconData icon, String text, {Color? color}) {
    return Row(
      children: [
        Icon(icon, color: color ?? Colors.white60, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: GoogleFonts.outfit(
            color: color ?? Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _dataChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label,
                    style: GoogleFonts.outfit(
                        color: color.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 1)),
                Text(value,
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapPin(Color color, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: 2)],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(color: Colors.white60, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _glowOrb(Color color, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
