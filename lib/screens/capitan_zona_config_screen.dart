import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/radar_scanner_widget.dart';

class CapitanZonaConfigScreen extends StatefulWidget {
  const CapitanZonaConfigScreen({super.key});

  @override
  State<CapitanZonaConfigScreen> createState() =>
      _CapitanZonaConfigScreenState();
}

class _CapitanZonaConfigScreenState extends State<CapitanZonaConfigScreen> {
  final MapController _mapController = MapController();
  LatLng _centroZona = const LatLng(-34.6037, -58.3816); // Buenos Aires default
  double _radioKm = 50.0;
  bool _isLoading = true;
  bool _isSaving = false;

  // Horarios
  String _rangoHorario = "08:00 - 18:00";
  List<String> _diasSeleccionados = ["Lun", "Mar", "Mie", "Jue", "Vie"];
  final List<String> _todosLosDias = [
    "Lun",
    "Mar",
    "Mie",
    "Jue",
    "Vie",
    "Sab",
    "Dom",
  ];

  // Localidades para centrado rápido
  String? _provinciaSeleccionada;
  String? _localidadSeleccionada;

  final Map<String, List<Map<String, dynamic>>> _territorios = {
    "Buenos Aires": [
      {"nombre": "Quilmes", "lat": -34.7248, "lng": -58.2525},
      {"nombre": "Bernal", "lat": -34.7083, "lng": -58.2833},
      {"nombre": "Berazategui", "lat": -34.7631, "lng": -58.2111},
      {"nombre": "Tigre / Delta", "lat": -34.4251, "lng": -58.5796},
      {"nombre": "San Fernando", "lat": -34.4444, "lng": -58.5583},
      {"nombre": "Mar del Plata", "lat": -38.0055, "lng": -57.5426},
      {"nombre": "Bahía Blanca", "lat": -38.7183, "lng": -62.2663},
      {"nombre": "La Plata", "lat": -34.9214, "lng": -57.9545},
      {"nombre": "San Nicolás", "lat": -33.3333, "lng": -60.2167},
    ],
    "Santa Fe": [
      {"nombre": "Rosario", "lat": -32.9442, "lng": -60.6505},
      {"nombre": "Santa Fe Capital", "lat": -31.6107, "lng": -60.6973},
      {"nombre": "Reconquista", "lat": -29.15, "lng": -59.65},
      {"nombre": "San Lorenzo", "lat": -32.7456, "lng": -60.7331},
    ],
    "Corrientes": [
      {"nombre": "Corrientes Capital", "lat": -27.4692, "lng": -58.8306},
      {"nombre": "Paso de la Patria", "lat": -27.3167, "lng": -58.5667},
      {"nombre": "Esquina", "lat": -30.0147, "lng": -59.5264},
      {"nombre": "Goya", "lat": -29.1441, "lng": -59.2635},
      {"nombre": "Ita Ibaté", "lat": -27.4267, "lng": -57.3403},
    ],
    "Entre Ríos": [
      {"nombre": "Paraná", "lat": -31.7333, "lng": -60.5333},
      {"nombre": "Concordia", "lat": -31.3930, "lng": -58.0209},
      {"nombre": "Gualeguaychú", "lat": -33.0094, "lng": -58.5146},
      {"nombre": "Victoria", "lat": -32.6184, "lng": -60.155},
      {"nombre": "Colón", "lat": -32.2228, "lng": -58.1433},
    ],
    "Neuquén": [
      {"nombre": "Neuquén Capital", "lat": -38.9516, "lng": -68.0591},
      {"nombre": "Villa La Angostura", "lat": -40.7621, "lng": -71.6429},
      {"nombre": "San Martín de los Andes", "lat": -40.1556, "lng": -71.3536},
    ],
    "Chaco": [
      {"nombre": "Isla del Cerrito", "lat": -27.2889, "lng": -58.6167},
      {"nombre": "Puerto Bermejo", "lat": -26.9167, "lng": -58.5},
      {"nombre": "Resistencia", "lat": -27.4514, "lng": -58.9867},
      {"nombre": "Las Palmas", "lat": -27.05, "lng": -58.7},
    ],
    "Formosa": [
      {"nombre": "Formosa Capital", "lat": -26.1858, "lng": -58.1731},
      {"nombre": "Herradura", "lat": -26.4833, "lng": -58.3167},
      {"nombre": "Clorinda", "lat": -25.2847, "lng": -57.7186},
    ]
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
            'zona_lat, zona_lng, zona_radio_km, horario_dias, horario_rango',
          )
          .eq('user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          if (perfil['zona_lat'] != null && perfil['zona_lng'] != null) {
            _centroZona = LatLng(perfil['zona_lat'], perfil['zona_lng']);
          }
          _radioKm = (perfil['zona_radio_km'] ?? 50.0).toDouble();
          _rangoHorario = perfil['horario_rango'] ?? "08:00 - 18:00";
          if (perfil['horario_dias'] != null) {
            _diasSeleccionados = perfil['horario_dias'].toString().split(',');
          }
          _isLoading = false;
        });

        // Mover mapa al centro guardado
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_centroZona, 10);
        });
      }
    } catch (e) {
      print('Error al cargar zona: $e');
      if (mounted) setState(() => _isLoading = false);
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
            content: Text('¡Zona de trabajo actualizada!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

    if (start != null) {
      final TimeOfDay? end = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 18, minute: 0),
        helpText: 'HORA DE CIERRE',
      );

      if (end != null) {
        setState(() {
          _rangoHorario = "${start.format(context)} - ${end.format(context)}";
        });
      }
    }
  }

  void _moverMapaALocalidad(double lat, double lng) {
    setState(() {
      _centroZona = LatLng(lat, lng);
    });
    _mapController.move(_centroZona, 12);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text(
          'CONFIGURACIÓN DE ZONA',
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
                constraints: const BoxConstraints(
                  maxWidth: 800,
                ), // Ancho ideal para mapa en web
                child: Column(
                  children: [
                    // El Mapa
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
                                userAgentPackageName: 'com.El Guia YA.app',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: _centroZona,
                                    radius:
                                        _radioKm *
                                        1000, // Convertir KM a Metros para el mapa
                                    useRadiusInMeter: true,
                                    color: const Color(
                                      0xFF00E676,
                                    ).withOpacity(0.3),
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
                                mensaje: 'Radar activo — escaneando tu zona de operación',
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
                              child: const Text(
                                '📍 Tocá el mapa para centrar tu puerto base',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Controles
                    Expanded(
                      flex: 4,
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: const BoxDecoration(
                          color: Color(0xFF001F3F),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(30),
                          ),
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle('UBICACIÓN RÁPIDA'),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _provinciaSeleccionada,
                                      hint: const Text('Provincia', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      dropdownColor: const Color(0xFF001F3F),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white10,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                      items: _territorios.keys.map((String value) {
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
                                      hint: const Text('Localidad', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                      dropdownColor: const Color(0xFF001F3F),
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white10,
                                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                      ),
                                      items: _provinciaSeleccionada == null 
                                        ? [] 
                                        : _territorios[_provinciaSeleccionada]!.map((loc) {
                                          return DropdownMenuItem<String>(
                                            value: loc['nombre'],
                                            child: Text(loc['nombre']),
                                          );
                                        }).toList(),
                                      onChanged: (val) {
                                        if (val != null) {
                                          final loc = _territorios[_provinciaSeleccionada]!
                                              .firstWhere((element) => element['nombre'] == val);
                                          _moverMapaALocalidad(loc['lat'], loc['lng']);
                                          setState(() => _localidadSeleccionada = val);
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              _buildSectionTitle(
                                'RADIO DE ACCIÓN: ${_radioKm.toInt()} KM',
                              ),
                              Slider(
                                value: _radioKm,
                                min: 5,
                                max: 200,
                                divisions: 39,
                                activeColor: const Color(0xFF00E676),
                                inactiveColor: Colors.white24,
                                onChanged: (val) =>
                                    setState(() => _radioKm = val),
                              ),

                              const SizedBox(height: 24),
                              _buildSectionTitle('DÍAS DE TRABAJO'),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                children: _todosLosDias.map((dia) {
                                  final selected = _diasSeleccionados.contains(
                                    dia,
                                  );
                                  return FilterChip(
                                    label: Text(
                                      dia,
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.black
                                            : Colors.white,
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
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _seleccionarRangoHorario,
                                      child: const Text(
                                        'EDITAR',
                                        style: TextStyle(
                                          color: Color(0xFF00E676),
                                        ),
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
                                  onPressed: _isSaving
                                      ? null
                                      : _guardarConfiguracion,
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
                  ],
                ),
              ),
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
