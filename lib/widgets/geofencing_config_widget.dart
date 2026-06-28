

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'safe_button.dart';

import '../models/perfil_capitan.dart';

class GeofencingConfigWidget extends StatefulWidget {
  final PerfilCapitan perfil;
  final Function(PerfilCapitan) onPerfilUpdated;

  const GeofencingConfigWidget({
    super.key,
    required this.perfil,
    required this.onPerfilUpdated,
  });

  @override
  State<GeofencingConfigWidget> createState() => _GeofencingConfigWidgetState();
}

class _GeofencingConfigWidgetState extends State<GeofencingConfigWidget> {
  final MapController _mapController = MapController();
  final _radioController = TextEditingController();
  final _nombreCentroController = TextEditingController();
  
  LatLng? _centroOperacion;
  double _radioOperacion = 25.0;
  final bool _editandoRadio = false;
  
  // Coordenadas de Buenos Aires por defecto
  static const LatLng _defaultCenter = LatLng(-34.6037, -58.3816);
  static const double _defaultZoom = 11.0;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  void _inicializarDatos() {
    // Cargar datos existentes
    if (widget.perfil.centroOperacionLatLong != null) {
      _centroOperacion = LatLng(
        widget.perfil.latitudCentro ?? _defaultCenter.latitude,
        widget.perfil.longitudCentro ?? _defaultCenter.longitude,
      );
      _nombreCentroController.text = widget.perfil.nombreCentroOperacion;
    } else {
      _centroOperacion = _defaultCenter;
      _nombreCentroController.text = 'Buenos Aires';
    }
    
    _radioOperacion = widget.perfil.radioOperacionKm ?? 25.0;
    _radioController.text = _radioOperacion.toStringAsFixed(1);
    
    // Centrar mapa en el punto de operacion
    _mapController.move(_centroOperacion!, 12.0);
  }

  void _onTapMap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _centroOperacion = point;
    });
    
    _mapController.move(point, 12.0);
    
    // Mostrar dialogo para confirmar y nombrar el punto
    _mostrarDialogoConfirmarCentro(point);
  }

  void _mostrarDialogoConfirmarCentro(LatLng point) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Centro de Operacion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Coordenadas seleccionadas:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              '${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nombreCentroController,
              decoration: const InputDecoration(
                labelText: 'Nombre del lugar',
                border: OutlineInputBorder(),
                hintText: 'Ej: Puerto de Buenos Aires',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _guardarConfiguracion();
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoRadio() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Radio de Operacion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Define el radio en kilometros desde tu centro de operacion:',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _radioController,
              decoration: InputDecoration(
                labelText: 'Radio (km)',
                border: OutlineInputBorder(),
                suffixText: 'km',
                helperText: 'Minimo: 1 km, Maximo: 100 km',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            // Opciones rapidas
            Text(
              'Opciones rapidas:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [10, 25, 50, 75, 100].map((radio) {
                return ActionChip(
                  label: Text('${radio}km'),
                  onPressed: () {
                    _radioController.text = radio.toString();
                  },
                  backgroundColor: _radioOperacion == radio 
                      ? const Color(0xFF0D47A1) 
                      : null,
                  labelStyle: TextStyle(
                    color: _radioOperacion == radio ? Colors.white : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final radio = double.tryParse(_radioController.text);
              if (radio != null && radio >= 1 && radio <= 100) {
                setState(() {
                  _radioOperacion = radio;
                });
                Navigator.pop(context);
                _guardarConfiguracion();
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  void _guardarConfiguracion() {
    final radio = double.tryParse(_radioController.text) ?? 25.0;
    final nombre = _nombreCentroController.text.trim().isEmpty 
        ? 'Centro de Operacion' 
        : _nombreCentroController.text.trim();
    
    final centroOperacionData = {
      'lat': _centroOperacion!.latitude,
      'lon': _centroOperacion!.longitude,
      'nombre': nombre,
    };
    
    final perfilActualizado = widget.perfil.copyWith(
      radioOperacionKm: radio,
      centroOperacionLatLong: centroOperacionData,
    );
    
    widget.onPerfilUpdated(perfilActualizado);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Configuracion de geofencing actualizada')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.location_searching, color: Color(0xFF0D47A1)),
              const SizedBox(width: 8),
              const Text(
                'Zona de Trabajo',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const Spacer(),
              if (widget.perfil.tieneGeofencingConfigurado)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Configurado',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Informacion actual
          if (widget.perfil.tieneGeofencingConfigurado) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 8),
                      Text(
                        'Centro: ${widget.perfil.nombreCentroOperacion}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.radio_button_unchecked, color: Color(0xFF0D47A1)),
                      const SizedBox(width: 8),
                      Text(
                        'Radio: ${widget.perfil.radioOperacionFormateado}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          // Mapa
          Container(
            height: 300,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _centroOperacion!,
                  initialZoom: _defaultZoom,
                  onTap: _onTapMap,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.El Guia YA',
                  ),
                  
                  // Circulo de operacion
                  if (_centroOperacion != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _centroOperacion!,
                          radius: _radioOperacion * 1000, // Convertir km a metros
                          color: const Color(0xFF0D47A1).withOpacity(0.2),
                          borderColor: const Color(0xFF0D47A1),
                          borderStrokeWidth: 2.0,
                        ),
                      ],
                    ),
                  
                  // Marcador del centro
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _centroOperacion!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D47A1),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_city,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Controles
          Row(
            children: [
              Expanded(
                child: SafeOutlinedIconButton(
  onPressed: () => _mostrarDialogoRadio(),
  icon: Icons.radio_button_checked,
  label: 'Radio',
  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0D47A1),
                    side: const BorderSide(color: Color(0xFF0D47A1)),
                  ),
),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SafeElevatedIconButton(
  onPressed: _guardarConfiguracion,
  icon: Icons.save,
  label: 'Guardar',
  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                  ),
),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // Instrucciones
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Toca el mapa para seleccionar tu centro de operacion',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
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
}
