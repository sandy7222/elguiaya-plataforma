import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../services/geo_service.dart';
import '../widgets/safe_button.dart';

class ComandoOperativoScreen extends StatefulWidget {
  const ComandoOperativoScreen({super.key});

  @override
  State<ComandoOperativoScreen> createState() => _ComandoOperativoScreenState();
}

class _ComandoOperativoScreenState extends State<ComandoOperativoScreen> {
  final MapController _mapController = MapController();
  final GeoService _geoService = GeoService();

  bool _verCapitanes = true;
  bool _verPescadores = true;
  bool _verCotizaciones = true;
  
  double _currentZoom = 10.0;

  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _capitanColor = Color(0x660066FF); // Azul transparente
  static const Color _pescadorColor = Color(0xFF00E676); // Verde brillante

  // Paraná, Entre Ríos, Argentina (Punto de inicio sugerido)
  final LatLng _centroInicial = const LatLng(-31.7333, -60.5333);

  // Controladores y estados para los buscadores de área
  final TextEditingController _searchNombreController = TextEditingController();
  final TextEditingController _searchLocalidadController = TextEditingController();
  final TextEditingController _searchProvinciaController = TextEditingController();

  String _searchNombre = '';
  String _searchLocalidad = '';
  String _searchProvincia = '';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchNombreController.dispose();
    _searchLocalidadController.dispose();
    _searchProvinciaController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  bool _matchesFilters(Map<String, dynamic> item, {bool isCotizacion = false, List<Map<String, dynamic>>? pescadoresList}) {
    // 1. Filtrar por Nombre
    if (_searchNombre.isNotEmpty) {
      if (isCotizacion && pescadoresList != null) {
        final pescadorId = item['pescador_id'];
        final pescador = pescadoresList.firstWhere(
          (p) => p['id'] == pescadorId,
          orElse: () => <String, dynamic>{},
        );
        final pescadorNombre = (pescador['nombre'] as String? ?? '').toLowerCase();
        if (!pescadorNombre.contains(_searchNombre)) {
          return false;
        }
      } else {
        final nombre = (item['nombre'] as String? ?? '').toLowerCase();
        if (!nombre.contains(_searchNombre)) {
          return false;
        }
      }
    }

    // 2. Filtrar por Localidad
    if (_searchLocalidad.isNotEmpty) {
      final localidad = (item['localidad'] as String? ?? '').toLowerCase();
      if (!localidad.contains(_searchLocalidad)) {
        return false;
      }
    }

    // 3. Filtrar por Provincia
    if (_searchProvincia.isNotEmpty) {
      final provincia = (item['provincia'] as String? ?? '').toLowerCase();
      if (!provincia.contains(_searchProvincia)) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: const Text('Comando Operativo (MCSTT)', style: TextStyle(color: _blancoPuro)),
        backgroundColor: _fondoOscuro,
        iconTheme: const IconThemeData(color: _blancoPuro),
      ),
      body: Stack(
        children: [
          _buildMapa(),
          _buildPanelBusqueda(),
          _buildPanelInfo(),
        ],
      ),
    );
  }

  Widget _buildMapa() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _geoService.streamCapitanesZonas(),
      builder: (context, snapshotCapitanes) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _geoService.streamPescadoresPuntos(),
          builder: (context, snapshotPescadores) {
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _geoService.streamCotizacionesActivas(),
              builder: (context, snapshotCotizaciones) {
            
            List<CircleMarker> capitanesCircles = [];
            List<Marker> capitanesMarkers = [];
            if (snapshotCapitanes.hasData) {
              for (var row in snapshotCapitanes.data!) {
                if (!_matchesFilters(row)) continue;
                final punto = _geoService.parsearPunto(row['centro_operaciones']);
                final radio = double.tryParse(row['radio_cobertura_km'].toString()) ?? 10.0;
                
                if (punto != null) {
                  capitanesCircles.add(
                    CircleMarker(
                      point: punto,
                      color: _capitanColor,
                      borderColor: Colors.blueAccent,
                      borderStrokeWidth: 2,
                      useRadiusInMeter: true,
                      radius: radio * 1000, // KM a Metros
                    )
                  );

                  final nombreCapitan = row['nombre'] as String? ?? 'Capitán';
                  final avatarUrl = row['avatar_url'] as String?;
                  final capacidad = row['capacidad_personas'] ?? 0;

                  capitanesMarkers.add(
                    Marker(
                      point: punto,
                      width: 120,
                      height: 80,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.blueAccent, width: 2),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.blue,
                                        child: const Icon(Icons.directions_boat, color: Colors.white, size: 16),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.blue,
                                      child: const Icon(Icons.directions_boat, color: Colors.white, size: 16),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 1),
                            ),
                            child: Text(
                              '$nombreCapitan (Cap: $capacidad)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            }

            List<Marker> pescadoresMarkers = [];
            if (snapshotPescadores.hasData) {
              for (var row in snapshotPescadores.data!) {
                if (!_matchesFilters(row)) continue;
                final punto = _geoService.parsearPunto(row['ubicacion_actual']);
                
                if (punto != null) {
                  final nombrePescador = row['nombre'] as String? ?? 'Pescador';
                  final avatarUrl = row['avatar_url'] as String?;

                  pescadoresMarkers.add(
                    Marker(
                      point: punto,
                      width: 120,
                      height: 80,
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.greenAccent, width: 2.5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black45,
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: avatarUrl != null && avatarUrl.isNotEmpty
                                  ? Image.network(
                                      avatarUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        color: Colors.green,
                                        child: const Icon(Icons.person, color: Colors.white, size: 18),
                                      ),
                                    )
                                  : Container(
                                      color: Colors.green,
                                      child: const Icon(Icons.person, color: Colors.white, size: 18),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.5), width: 1),
                            ),
                            child: Text(
                              nombrePescador,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
              }
            }

            List<Marker> cotizacionesMarkers = [];
            if (snapshotCotizaciones.hasData) {
              final pescadoresList = snapshotPescadores.data ?? [];
              for (var row in snapshotCotizaciones.data!) {
                if (!_matchesFilters(row, isCotizacion: true, pescadoresList: pescadoresList)) continue;
                final punto = _geoService.parsearPunto(row['ubicacion']);
                
                if (punto != null) {
                  final estado = row['estado'] as String?;
                  final monto = row['monto'];
                  final desc = row['descripcion_corta'] as String? ?? '';
                  
                   Color colorTarjeta;
                  if (estado == 'pendiente' || estado == 'solicitada') {
                    colorTarjeta = Colors.pinkAccent;
                  } else if (estado == 'presupuestado' || estado == 'presupuestada') {
                    colorTarjeta = Colors.lightBlueAccent;
                  } else if (estado == 'aceptada' || estado == 'aceptado' || estado == 'pagada' || estado == 'pagado' || estado == 'en_viaje' || estado == 'finalizado') {
                    colorTarjeta = Colors.green;
                  } else {
                    colorTarjeta = Colors.blueGrey;
                  }

                  cotizacionesMarkers.add(
                    Marker(
                      point: punto,
                      width: _currentZoom > 12 ? 150 : 30,
                      height: _currentZoom > 12 ? 70 : 30,
                      alignment: Alignment.topCenter,
                      child: _currentZoom > 12 
                        ? Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: colorTarjeta.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 2))],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(desc.length > 20 ? '${desc.substring(0, 18)}...' : desc, 
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                if (monto != null)
                                  Text('\$${monto.toStringAsFixed(0)}', 
                                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
                                if (monto == null)
                                  Text(estado?.toUpperCase() ?? 'PENDIENTE', 
                                    style: const TextStyle(color: Colors.white, fontSize: 10)),
                              ],
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: colorTarjeta,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.attach_money, color: Colors.white, size: 16),
                          )
                    )
                  );
                }
              }
            }

            return FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _centroInicial,
                initialZoom: _currentZoom,
                maxZoom: 18.0,
                minZoom: 5.0,
                onPositionChanged: (position, hasGesture) {
                  if ((position.zoom - _currentZoom).abs() > 0.5) {
                    setState(() {
                      _currentZoom = position.zoom;
                    });
                  }
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.El Guia YA.master',
                ),
                if (_verCapitanes) CircleLayer(circles: capitanesCircles),
                if (_verCapitanes) MarkerLayer(markers: capitanesMarkers),
                if (_verPescadores) MarkerLayer(markers: pescadoresMarkers),
                if (_verCotizaciones) MarkerLayer(markers: cotizacionesMarkers),
              ],
            );
          },
        );
      },
    );
  },
);
}

  Widget _buildPanelBusqueda() {
    final bool hasActiveFilters = _searchNombre.isNotEmpty ||
        _searchLocalidad.isNotEmpty ||
        _searchProvincia.isNotEmpty;

    void ejecutarBusqueda() {
      FocusScope.of(context).unfocus();
      setState(() {
        _searchNombre = _searchNombreController.text.trim().toLowerCase();
        _searchLocalidad = _searchLocalidadController.text.trim().toLowerCase();
        _searchProvincia = _searchProvinciaController.text.trim().toLowerCase();
      });
    }

    return Positioned(
      top: 16,
      left: 12,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 10,
              offset: Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Buscador',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (hasActiveFilters)
                  GestureDetector(
                    onTap: () {
                      _searchNombreController.clear();
                      _searchLocalidadController.clear();
                      _searchProvinciaController.clear();
                      setState(() {
                        _searchNombre = '';
                        _searchLocalidad = '';
                        _searchProvincia = '';
                      });
                    },
                    child: const Text(
                      'Limpiar',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildSearchTextField(
              controller: _searchNombreController,
              hint: 'Nombre',
              icon: Icons.person_search,
              onSubmitted: (_) => ejecutarBusqueda(),
            ),
            const SizedBox(height: 6),
            _buildSearchTextField(
              controller: _searchLocalidadController,
              hint: 'Localidad',
              icon: Icons.location_city,
              onSubmitted: (_) => ejecutarBusqueda(),
            ),
            const SizedBox(height: 6),
            _buildSearchTextField(
              controller: _searchProvinciaController,
              hint: 'Provincia',
              icon: Icons.map_outlined,
              onSubmitted: (_) => ejecutarBusqueda(),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 32,
              child: SafeElevatedIconButton(
  onPressed: ejecutarBusqueda,
  icon: Icons.search,
  iconSize: 12,
  iconColor: Colors.black,
  label: 'BUSCAR',
  textStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black),
  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  elevation: 2,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: const Color(0xFF262626),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 11),
        cursorColor: Colors.greenAccent,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38, fontSize: 10),
          prefixIcon: Icon(icon, color: Colors.white54, size: 14),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }

  Widget _buildPanelInfo() {
    return Positioned(
      top: 16,
      right: 12,
      child: Container(
        width: 115,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Filtros', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _leyendaFiltro(Colors.blueAccent, 'Capitanes', _verCapitanes, (val) {
              setState(() => _verCapitanes = val);
            }),
            const SizedBox(height: 6),
            _leyendaFiltro(_pescadorColor, 'Pescadores', _verPescadores, (val) {
              setState(() => _verPescadores = val);
            }),
            const SizedBox(height: 6),
            _leyendaFiltro(Colors.pinkAccent, 'Cotizaciones', _verCotizaciones, (val) {
              setState(() => _verCotizaciones = val);
            }),
          ],
        ),
      ),
    );
  }

  Widget _leyendaFiltro(Color color, String texto, bool isActivo, Function(bool) onChanged) {
    return InkWell(
      onTap: () => onChanged(!isActivo),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: isActivo ? color : Colors.transparent,
              border: Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                color: isActivo ? Colors.white : Colors.white30,
                fontSize: 10,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
