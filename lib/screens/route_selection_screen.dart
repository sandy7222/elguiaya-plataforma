

import 'package:flutter/material.dart';
import '../widgets/safe_button.dart';

import '../widgets/map_selector_widget.dart';

class RouteSelectionScreen extends StatefulWidget {
  final Function(Map<String, dynamic>, Map<String, dynamic>, String) onRouteSelected;

  const RouteSelectionScreen({
    super.key,
    required this.onRouteSelected,
  });

  @override
  State<RouteSelectionScreen> createState() => _RouteSelectionScreenState();
}

class _RouteSelectionScreenState extends State<RouteSelectionScreen> {
  final _descripcionController = TextEditingController();
  Map<String, dynamic>? _puntoPartida;
  Map<String, dynamic>? _puntoDestino;
  bool _rutaSeleccionada = false;

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  void _onRouteSelected(Map<String, dynamic> partida, Map<String, dynamic> destino, List<Map<String, dynamic>> trackLog) {
    setState(() {
      _puntoPartida = partida;
      _puntoDestino = destino;
      _rutaSeleccionada = true;
    });
  }

  void _enviarSolicitud() {
    final descripcion = _descripcionController.text.trim();
    
    if (descripcion.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Por favor, describe tu solicitud')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!_rutaSeleccionada) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Por favor, selecciona una ruta completa')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    widget.onRouteSelected(_puntoPartida!, _puntoDestino!, descripcion);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Nueva Solicitud de Viaje',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close),
        ),
      ),
      body: Column(
        children: [
          // Formulario de descripcion
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Describe tu solicitud',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descripcionController,
                  decoration: InputDecoration(
                    hintText: 'Ej: Viaje de pesca de 4 horas con equipo completo...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          
          // Indicador de progreso
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: _rutaSeleccionada ? 0.5 : 0.25,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _rutaSeleccionada ? Colors.green : Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _rutaSeleccionada ? '50%' : '25%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _rutaSeleccionada ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          
          // Mapa selector
          Expanded(
            child: MapSelectorWidget(
              onRouteSelected: _onRouteSelected,
            ),
          ),
          
          // Boton de envio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                if (_rutaSeleccionada) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ruta seleccionada: ${_puntoPartida?['nombre']} → ${_puntoDestino?['nombre']}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.green,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: SafeElevatedIconButton(
  onPressed: _enviarSolicitud,
  icon: Icons.send,
  label: 'Enviar Solicitud de Cotizacion',
  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
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
