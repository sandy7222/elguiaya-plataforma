import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../utils/view_insets.dart';
import '../widgets/radar_scanner_widget.dart';

class CapitanZonaConfigScreen extends StatefulWidget {
  const CapitanZonaConfigScreen({super.key});

  @override
  State<CapitanZonaConfigScreen> createState() =>
      _CapitanZonaConfigScreenState();
}

class _CapitanZonaConfigScreenState extends State<CapitanZonaConfigScreen> {
  final MapController _mapController = MapController();
  LatLng _centroZona = const LatLng(-34.6037, -58.3816);
  double _radioKm = 50.0;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _disponible = false;
  bool _guardandoDisponibilidad = false;

  String _rangoHorario = '08:00 - 18:00';
  List<String> _diasSeleccionados = ['Lun', 'Mar', 'Mi\u00E9', 'Jue', 'Vie'];
  final List<String> _todosLosDias = [
    'Lun',
    'Mar',
    'Mi\u00E9',
    'Jue',
    'Vie',
    'S\u00E1b',
    'Dom',
  ];

  String? _provinciaSeleccionada;
  String? _localidadSeleccionada;

  final Map<String, List<Map<String, dynamic>>> _territorios = {
    'Buenos Aires': [
      {'nombre': 'Quilmes', 'lat': -34.7248, 'lng': -58.2525},
      {'nombre': 'Bernal', 'lat': -34.7083, 'lng': -58.2833},
      {'nombre': 'Berazategui', 'lat': -34.7631, 'lng': -58.2111},
      {'nombre': 'Tigre / Delta', 'lat': -34.4251, 'lng': -58.5796},
      {'nombre': 'San Fernando', 'lat': -34.4444, 'lng': -58.5583},
      {'nombre': 'Mar del Plata', 'lat': -38.0055, 'lng': -57.5426},
      {'nombre': 'Bah\u00EDa Blanca', 'lat': -38.7183, 'lng': -62.2663},
      {'nombre': 'La Plata', 'lat': -34.9214, 'lng': -57.9545},
      {'nombre': 'San Nicol\u00E1s', 'lat': -33.3333, 'lng': -60.2167},
    ],
    'Santa Fe': [
      {'nombre': 'Rosario', 'lat': -32.9442, 'lng': -60.6505},
      {'nombre': 'Santa Fe Capital', 'lat': -31.6107, 'lng': -60.6973},
      {'nombre': 'Reconquista', 'lat': -29.15, 'lng': -59.65},
      {'nombre': 'San Lorenzo', 'lat': -32.7456, 'lng': -60.7331},
    ],
    'Corrientes': [
      {'nombre': 'Corrientes Capital', 'lat': -27.4692, 'lng': -58.8306},
      {'nombre': 'Paso de la Patria', 'lat': -27.3167, 'lng': -58.5667},
      {'nombre': 'Esquina', 'lat': -30.0147, 'lng': -59.5264},
      {'nombre': 'Goya', 'lat': -29.1441, 'lng': -59.2635},
      {'nombre': 'Ita Ibat\u00E9', 'lat': -27.4267, 'lng': -57.3403},
    ],
    'Entre R\u00EDos': [
      {'nombre': 'Paran\u00E1', 'lat': -31.7333, 'lng': -60.5333},
      {'nombre': 'Concordia', 'lat': -31.3930, 'lng': -58.0209},
      {'nombre': 'Gualeguaych\u00FA', 'lat': -33.0094, 'lng': -58.5146},
      {'nombre': 'Victoria', 'lat': -32.6184, 'lng': -60.155},
      {'nombre': 'Col\u00F3n', 'lat': -32.2228, 'lng': -58.1433},
    ],
    'Neuqu\u00E9n': [
      {'nombre': 'Neuqu\u00E9n Capital', 'lat': -38.9516, 'lng': -68.0591},
      {'nombre': 'Villa La Angostura', 'lat': -40.7621, 'lng': -71.6429},
      {'nombre': 'San Mart\u00EDn de los Andes', 'lat': -40.1556, 'lng': -71.3536},
    ],
    'Chaco': [
      {'nombre': 'Isla del Cerrito', 'lat': -27.2889, 'lng': -58.6167},
      {'nombre': 'Puerto Bermejo', 'lat': -26.9167, 'lng': -58.5},
      {'nombre': 'Resistencia', 'lat': -27.4514, 'lng': -58.9867},
      {'nombre': 'Las Palmas', 'lat': -27.05, 'lng': -58.7},
    ],
    'Formosa': [
      {'nombre': 'Formosa Capital', 'lat': -26.1858, 'lng': -58.1731},
      {'nombre': 'Herradura', 'lat': -26.4833, 'lng': -58.3167},
      {'nombre': 'Clorinda', 'lat': -25.2847, 'lng': -57.7186},
    ],
  };

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  Future<void> _cargarConfiguracion() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final perfil = await Supabase.instance.client
          .from('profiles')
          .select(
            'zona_lat, zona_lng, zona_radio_km, horario_dias, horario_rango, disponible',
          )
          .eq('user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          if (perfil['zona_lat'] != null && perfil['zona_lng'] != null) {
            _centroZona = LatLng(perfil['zona_lat'], perfil['zona_lng']);
          }
          _radioKm = (perfil['zona_radio_km'] ?? 50.0).toDouble();
          _rangoHorario = perfil['horario_rango'] ?? '08:00 - 18:00';
          if (perfil['horario_dias'] != null) {
            _diasSeleccionados = perfil['horario_dias'].toString().split(',');
          }
          _disponible = perfil['disponible'] == true;
          _isLoading = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_centroZona, 10);
        });
      }
    } catch (e) {
      debugPrint('Error al cargar zona: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _actualizarDisponibilidad(bool disponible) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _guardandoDisponibilidad = true);
    try {
      await SupabaseService.cambiarDisponibilidadCapitan(user.id, disponible);
      if (mounted) {
        setState(() => _disponible = disponible);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              disponible
                  ? 'Radar activo: recibir\u00E1s solicitudes en tu zona'
                  : 'En puerto / descanso: no recibir\u00E1s nuevas solicitudes',
            ),
            backgroundColor: disponible ? const Color(0xFF00E676) : Colors.amber,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar estado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardandoDisponibilidad = false);
    }
  }

  Future<void> _guardarConfiguracion() async {
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = {
        'zona_lat': _centroZona.latitude,
        'zona_lng': _centroZona.longitude,
        'zona_radio_km': _radioKm,
        'horario_dias': _diasSeleccionados.join(','),
        'horario_rango': _rangoHorario,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client
          .from('profiles')
          .update(data)
          .eq('user_id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('\u00A1Zona de trabajo actualizada!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _seleccionarRangoHorario() async {
    final TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'HORA DE INICIO',
    );

    if (start != null && mounted) {
      final TimeOfDay? end = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 18, minute: 0),
        helpText: 'HORA DE CIERRE',
      );

      if (end != null) {
        setState(() {
          _rangoHorario = '${start.format(context)} - ${end.format(context)}';
        });
      }
    }
  }

  void _moverMapaALocalidad(double lat, double lng) {
    setState(() => _centroZona = LatLng(lat, lng));
    _mapController.move(_centroZona, 12);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text(
          'MI ZONA Y RADAR',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: _centroZona,
                              initialZoom: 9,
                              onTap: (tapPosition, point) {
                                setState(() => _centroZona = point);
                              },
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.elguiaya.app',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: _centroZona,
                                    radius: _radioKm * 1000,
                                    useRadiusInMeter: true,
                                    color: const Color(0xFF00E676).withOpacity(0.3),
                                    borderColor: const Color(0xFF00E676),
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _centroZona,
                                    child: const Icon(
                                      Icons.anchor,
                                      color: Colors.black,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Positioned.fill(
                            child: RadarSweepAnimatedOverlay(
                              accentColor: const Color(0xFF00E676),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            right: 20,
                            bottom: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.72),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: const Color(0xFF00E676).withOpacity(0.35),
                                ),
                              ),
                              child: const PalpitandoTexto(
                                mensaje:
                                    'Radar activo - escaneando tu zona de operaci\u00F3n',
                              ),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            left: 20,
                            right: 20,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.touch_app_rounded,
                                    color: Colors.white.withOpacity(0.9),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Flexible(
                                    child: Text(
                                      'Toc\u00E1 el mapa para centrar tu puerto base',
                                      textAlign: TextAlign.center,
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
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 4,
                      child: SafeArea(
                        top: false,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Color(0xFF001F3F),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(30),
                            ),
                          ),
                          child: SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              24,
                              24,
                              24,
                              ViewInsets.systemBottomPadding(context, extra: 24),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildEstadoNavegacionSection(),
                                const SizedBox(height: 24),
                                _buildSectionTitle('UBICACI\u00D3N R\u00C1PIDA'),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _provinciaSeleccionada,
                                        hint: const Text(
                                          'Provincia',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        dropdownColor: const Color(0xFF001F3F),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white10,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        items: _territorios.keys.map((value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                        onChanged: (val) {
                                          setState(() {
                                            _provinciaSeleccionada = val;
                                            _localidadSeleccionada = null;
                                          });
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _localidadSeleccionada,
                                        hint: const Text(
                                          'Localidad',
                                          style: TextStyle(
                                            color: Colors.white54,
                                            fontSize: 12,
                                          ),
                                        ),
                                        dropdownColor: const Color(0xFF001F3F),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                        ),
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white10,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                            borderSide: BorderSide.none,
                                          ),
                                        ),
                                        items: _provinciaSeleccionada == null
                                            ? []
                                            : _territorios[_provinciaSeleccionada]!
                                                .map((loc) {
                                                return DropdownMenuItem<String>(
                                                  value: loc['nombre'],
                                                  child: Text(loc['nombre']),
                                                );
                                              }).toList(),
                                        onChanged: (val) {
                                          if (val != null) {
                                            final loc = _territorios[
                                                    _provinciaSeleccionada]!
                                                .firstWhere(
                                              (element) => element['nombre'] == val,
                                            );
                                            _moverMapaALocalidad(
                                              loc['lat'],
                                              loc['lng'],
                                            );
                                            setState(() => _localidadSeleccionada = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle(
                                  'RADIO DE ACCI\u00D3N: ${_radioKm.toInt()} KM',
                                ),
                                Slider(
                                  value: _radioKm,
                                  min: 5,
                                  max: 200,
                                  divisions: 39,
                                  activeColor: const Color(0xFF00E676),
                                  inactiveColor: Colors.white24,
                                  onChanged: (val) => setState(() => _radioKm = val),
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle('D\u00CDAS DE TRABAJO'),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  children: _todosLosDias.map((dia) {
                                    final selected =
                                        _diasSeleccionados.contains(dia);
                                    return FilterChip(
                                      label: Text(
                                        dia,
                                        style: TextStyle(
                                          color: selected ? Colors.black : Colors.white,
                                        ),
                                      ),
                                      selected: selected,
                                      onSelected: (val) {
                                        setState(() {
                                          if (val) {
                                            _diasSeleccionados.add(dia);
                                          } else {
                                            _diasSeleccionados.remove(dia);
                                          }
                                        });
                                      },
                                      selectedColor: const Color(0xFF00E676),
                                      backgroundColor: Colors.white10,
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 24),
                                _buildSectionTitle('RANGO HORARIO'),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        color: Color(0xFF00E676),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          _rangoHorario,
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: _seleccionarRangoHorario,
                                        child: const Text(
                                          'EDITAR',
                                          style: TextStyle(color: Color(0xFF00E676)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 40),
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed:
                                        _isSaving ? null : _guardarConfiguracion,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF00E676),
                                      foregroundColor: Colors.black,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: _isSaving
                                        ? const CircularProgressIndicator(
                                            color: Colors.black,
                                          )
                                        : const Text(
                                            'GUARDAR TERRITORIO',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEstadoNavegacionSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (_disponible ? const Color(0xFF00E676) : Colors.amber)
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _disponible
                  ? const Color(0xFF00E676).withOpacity(0.12)
                  : Colors.amber.withOpacity(0.1),
              border: Border.all(
                color: _disponible
                    ? const Color(0xFF00E676).withOpacity(0.3)
                    : Colors.amber.withOpacity(0.2),
              ),
            ),
            child: Icon(
              _disponible ? Icons.sailing_rounded : Icons.anchor_rounded,
              color: _disponible ? const Color(0xFF00E676) : Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTADO DE NAVEGACI\u00D3N',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _disponible
                      ? 'EN NAVEGACI\u00D3N (RADAR ACTIVO)'
                      : 'EN PUERTO / DESCANSO',
                  style: TextStyle(
                    color: _disponible ? const Color(0xFF00E676) : Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _disponible
                      ? 'Recib\u00EDs solicitudes dentro de tu radio de acci\u00F3n'
                      : 'Paus\u00E1 el radar sin cambiar tu territorio configurado',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (_guardandoDisponibilidad)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Switch.adaptive(
              value: _disponible,
              onChanged: _actualizarDisponibilidad,
              activeColor: const Color(0xFF00E676),
              activeTrackColor: const Color(0xFF00E676).withOpacity(0.3),
              inactiveThumbColor: Colors.amber,
              inactiveTrackColor: Colors.amber.withOpacity(0.2),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00E676),
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }
}
