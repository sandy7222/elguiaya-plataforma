

import 'package:flutter/material.dart';

class PortalPescadorScreen extends StatefulWidget {
  const PortalPescadorScreen({super.key});

  @override
  State<PortalPescadorScreen> createState() => _PortalPescadorScreenState();
}

class _PortalPescadorScreenState extends State<PortalPescadorScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  
  // Controladores del formulario
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _viajeFechaController = TextEditingController();
  final _viajeDuracionController = TextEditingController();
  final _numeroPescadoresController = TextEditingController(text: '1');
  final _presupuestoController = TextEditingController();
  final _mensajeController = TextEditingController();
  
  // Variables seleccionadas
  String _viajeTipo = 'desde costa';
  String _experienciaNivel = 'principiante';
  final List<String> _equipamientoSeleccionado = [];
  
  // Mapa simplificado (sin flutter_map)
  final List<Map<String, dynamic>> _puntosPesca = [
    {'nombre': 'Puerto Madryn', 'lat': -42.775, 'lng': -65.03},
    {'nombre': 'Mar del Plata', 'lat': -36.6167, 'lng': -56.6833},
    {'nombre': 'San Clemente', 'lat': -36.8333, 'lng': -54.8333},
    {'nombre': 'Neuquen', 'lat': -38.9516, 'lng': -68.0591},
    {'nombre': 'Ushuaia', 'lat': -54.8, 'lng': -68.3},
  ];
  
  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _rojoFuerte = Color(0xFFFF0000);

  final List<String> _tiposViaje = [
    'desde costa',
    'desde embarcacion',
    'pesca de tiburon',
    'pesca nocturna',
    'pesca de pejerrey',
    'pesca de dorado',
  ];

  final List<String> _nivelesExperiencia = [
    'principiante',
    'intermedio',
    'avanzado',
  ];

  final List<String> _equipamientoOpciones = [
    'cana',
    'carrete',
    'anzuelos',
    'equipo completo',
    'cana nocturna',
    'sonar',
    'silla de pesca',
    'carnada',
  ];

  @override
  void initState() {
    super.initState();
    // Establecer fecha por defecto (manana)
    final manana = DateTime.now().add(const Duration(days: 1));
    _viajeFechaController.text = '${manana.day}/${manana.month}/${manana.year}';
    _viajeDuracionController.text = '8';
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor completa todos los campos requeridos'),
          backgroundColor: _rojoFuerte,
        ),
      );
      return;
    }

    if (_equipamientoSeleccionado.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor selecciona al menos un equipo'),
          backgroundColor: _rojoFuerte,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simular envio a Supabase
      await Future.delayed(const Duration(milliseconds: 1500));
      
      final solicitud = {
        'id': 'sol-${DateTime.now().millisecondsSinceEpoch}',
        'pescador_nombre': _nombreController.text.trim(),
        'pescador_email': _emailController.text.trim(),
        'pescador_telefono': _telefonoController.text.trim(),
        'viaje_tipo': _viajeTipo,
        'viaje_fecha_solicitada': _viajeFechaController.text.trim(),
        'viaje_duracion': '${_viajeDuracionController.text.trim()} horas',
        'numero_pescadores': int.tryParse(_numeroPescadoresController.text) ?? 1,
        'equipamiento_requerido': _equipamientoSeleccionado,
        'experiencia_nivel': _experienciaNivel,
        'presupuesto_estimado': double.tryParse(_presupuestoController.text) ?? 0,
        'mensaje_pescador': _mensajeController.text.trim(),
        'status': 'pendiente',
        'fecha_solicitud': DateTime.now().toIso8601String(),
      };

      // En un entorno real, aqui se enviaria a Supabase
      print('✅ Solicitud enviada: ${solicitud['id']}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Solicitud enviada correctamente! Te responderemos pronto.'),
          backgroundColor: _verdeBrillante,
          duration: const Duration(seconds: 3),
        ),
      );

      // Limpiar formulario
      _limpiarFormulario();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar solicitud: $e'),
          backgroundColor: _rojoFuerte,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _limpiarFormulario() {
    _formKey.currentState?.reset();
    _nombreController.clear();
    _emailController.clear();
    _telefonoController.clear();
    final manana = DateTime.now().add(const Duration(days: 1));
    _viajeFechaController.text = '${manana.day}/${manana.month}/${manana.year}';
    _viajeDuracionController.text = '8';
    _numeroPescadoresController.text = '1';
    _presupuestoController.clear();
    _mensajeController.clear();
    _viajeTipo = 'desde costa';
    _experienciaNivel = 'principiante';
    _equipamientoSeleccionado.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.sailing, color: _blancoPuro, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Portal del Pescador',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mapa simplificado (50% de pantalla)
              Container(
                height: MediaQuery.of(context).size.height * 0.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _blancoPuro.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _azulVibrante.withOpacity(0.3)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    children: [
                      // Header del mapa
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _azulVibrante.withOpacity(0.1),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.map, color: _azulVibrante),
                            const SizedBox(width: 8),
                            const Text(
                              '🗺️ Zonas de Pesca Disponibles',
                              style: TextStyle(
                                color: _azulVibrante,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_puntosPesca.length} zonas',
                              style: TextStyle(
                                color: _blancoPuro.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Lista de puntos de pesca
                      Expanded(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _puntosPesca.length,
                          itemBuilder: (context, index) {
                            final punto = _puntosPesca[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _blancoPuro.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: _blancoPuro.withOpacity(0.1)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.location_on,
                                    color: _naranjaIntenso,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          punto['nombre'],
                                          style: const TextStyle(
                                            color: _blancoPuro,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Text(
                                          'Lat: ${punto['lat']}, Lng: ${punto['lng']}',
                                          style: TextStyle(
                                            color: _blancoPuro.withOpacity(0.6),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      _mostrarDialogoUbicacion(punto);
                                    },
                                    icon: const Icon(
                                      Icons.info_outline,
                                      color: _azulVibrante,
                                    ),
                                    tooltip: 'Informacion',
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Formulario de solicitud
              _buildSeccionDatosPersonales(),
              const SizedBox(height: 16),
              _buildSeccionViaje(),
              const SizedBox(height: 16),
              _buildSeccionEquipamiento(),
              const SizedBox(height: 16),
              _buildSeccionMensaje(),
              const SizedBox(height: 24),
              _buildBotonEnviar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeccionDatosPersonales() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '👤 Datos Personales',
            style: TextStyle(
              color: _blancoPuro,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _nombreController,
                  decoration: _buildInputDecoration('Nombre Completo'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El nombre es requerido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _emailController,
                  decoration: _buildInputDecoration('Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El email es requerido';
                    }
                    if (!value.contains('@')) {
                      return 'Email invalido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _telefonoController,
            decoration: _buildInputDecoration('Telefono'),
            keyboardType: TextInputType.phone,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'El telefono es requerido';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionViaje() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🚢 Detalles del Viaje',
            style: TextStyle(
              color: _blancoPuro,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _viajeTipo,
                  decoration: _buildInputDecoration('Tipo de Pesca'),
                  items: _tiposViaje.map((String tipo) {
                    return DropdownMenuItem<String>(
                      value: tipo,
                      child: Text(
                        tipo,
                        style: const TextStyle(color: _blancoPuro),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() => _viajeTipo = value!);
                  },
                  dropdownColor: _fondoOscuro,
                  style: const TextStyle(color: _blancoPuro),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _viajeFechaController,
                  decoration: _buildInputDecoration('Fecha (dd/mm/yyyy)'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La fecha es requerida';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _viajeDuracionController,
                  decoration: _buildInputDecoration('Duracion (horas)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'La duracion es requerida';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _numeroPescadoresController,
                  decoration: _buildInputDecoration('N° Pescadores'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El numero es requerido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _experienciaNivel,
                  decoration: _buildInputDecoration('Nivel de Experiencia'),
                  items: _nivelesExperiencia.map((String nivel) {
                    return DropdownMenuItem<String>(
                      value: nivel,
                      child: Text(
                        nivel,
                        style: const TextStyle(color: _blancoPuro),
                      ),
                    );
                  }).toList(),
                  onChanged: (String? value) {
                    setState(() => _experienciaNivel = value!);
                  },
                  dropdownColor: _fondoOscuro,
                  style: const TextStyle(color: _blancoPuro),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _presupuestoController,
                  decoration: _buildInputDecoration('Presupuesto Estimado (\$)'),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'El presupuesto es requerido';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionEquipamiento() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎣 Equipamiento Requerido',
            style: TextStyle(
              color: _blancoPuro,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _equipamientoOpciones.map((opcion) {
              final isSelected = _equipamientoSeleccionado.contains(opcion);
              return FilterChip(
                label: Text(opcion),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _equipamientoSeleccionado.add(opcion);
                    } else {
                      _equipamientoSeleccionado.remove(opcion);
                    }
                  });
                },
                backgroundColor: isSelected ? _azulVibrante : _blancoPuro.withOpacity(0.1),
                labelStyle: TextStyle(
                  color: isSelected ? _blancoPuro : _blancoPuro.withOpacity(0.7),
                ),
                side: BorderSide(
                  color: isSelected ? _azulVibrante : _blancoPuro.withOpacity(0.3),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionMensaje() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '📝 Mensaje Adicional',
            style: TextStyle(
              color: _blancoPuro,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mensajeController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Cuentanos mas sobre tu experiencia, lo que esperas del viaje, o cualquier requisito especial...',
              hintStyle: TextStyle(color: _blancoPuro.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _blancoPuro.withOpacity(0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: _azulVibrante, width: 2),
              ),
              filled: true,
              fillColor: _blancoPuro.withOpacity(0.1),
            ),
            style: const TextStyle(color: _blancoPuro),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonEnviar() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _enviarSolicitud,
        style: ElevatedButton.styleFrom(
          backgroundColor: _azulVibrante,
          foregroundColor: _blancoPuro,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_blancoPuro),
                    ),
                  ),
                  SizedBox(width: 8),
                  Text('Enviando...'),
                ],
              )
            : const Text(
                'SOLICITAR COTIZACION',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _blancoPuro.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: _blancoPuro.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _azulVibrante, width: 2),
      ),
      filled: true,
      fillColor: _blancoPuro.withOpacity(0.1),
    );
  }

  void _mostrarDialogoUbicacion(Map<String, dynamic> punto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '📍 Ubicacion Seleccionada',
          style: TextStyle(
            color: _fondoOscuro,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Latitud: ${punto['lat']}',
              style: const TextStyle(color: _fondoOscuro),
            ),
            Text(
              'Longitud: ${punto['lng']}',
              style: const TextStyle(color: _fondoOscuro),
            ),
            const SizedBox(height: 8),
            const Text(
              '¿Deseas solicitar cotizacion para esta zona?',
              style: TextStyle(
                color: _azulVibrante,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Aqui podrias pre-llenar el formulario con la ubicacion
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Ubicacion guardada: ${punto['lat']}, ${punto['lng']}'),
                  backgroundColor: _azulVibrante,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulVibrante,
              foregroundColor: _blancoPuro,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }
}
