

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/supabase_service.dart';

class ManifiestoPasajerosScreen extends StatefulWidget {
  final String viajeId;
  final String? pedidoId;
  final String? nombreLancha;

  const ManifiestoPasajerosScreen({
    super.key,
    required this.viajeId,
    this.pedidoId,
    this.nombreLancha,
  });

  @override
  State<ManifiestoPasajerosScreen> createState() => _ManifiestoPasajerosScreenState();
}

class _ManifiestoPasajerosScreenState extends State<ManifiestoPasajerosScreen> {
  List<Map<String, dynamic>> _pasajeros = [];
  List<Map<String, dynamic>> _productosViaje = [];
  bool _isLoading = true;
  bool _isSaving = false;
  final ImagePicker _imagePicker = ImagePicker();
  
  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      final pasajeros = await SupabaseService.getManifiestoViaje(widget.viajeId);
      final productos = await SupabaseService.getProductosViaje(widget.viajeId);
      
      setState(() {
        _pasajeros = pasajeros;
        _productosViaje = productos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar datos: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _agregarPasajero() {
    showDialog(
      context: context,
      builder: (context) => _PasajeroFormDialog(
        onSaved: _guardarPasajero,
      ),
    );
  }

  Future<void> _guardarPasajero(Map<String, dynamic> pasajero) async {
    try {
      setState(() => _isSaving = true);
      
      // Aqui implementariamos la logica para guardar el pasajero
      // Por ahora, solo agregamos a la lista local
      setState(() {
        _pasajeros.add({
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
          'nombre_pasajero': pasajero['nombre'],
          'apellido_pasajero': pasajero['apellido'],
          'dni_pasajero': pasajero['dni'],
          'foto_dni_url': pasajero['foto_dni_url'],
          'foto_dni_subida_at': DateTime.now().toIso8601String(),
          'datos_validados': false,
          'estado_datos': '📷 Foto subida',
          'color_estado': _naranjaAlerta,
          'created_at': DateTime.now().toIso8601String(),
        });
        _isSaving = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('✅ Pasajero agregado exitosamente')),
            backgroundColor: _verdeExito,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al guardar pasajero: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _subirFotoDNI(String pasajeroId) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (image != null) {
        // Simular subida de imagen
        final fotoUrl = 'https://example.com/fotos_dni/${pasajeroId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        // Actualizar pasajero con foto
        setState(() {
          final index = _pasajeros.indexWhere((p) => p['id'] == pasajeroId);
          if (index != -1) {
            _pasajeros[index]['foto_dni_url'] = fotoUrl;
            _pasajeros[index]['foto_dni_subida_at'] = DateTime.now().toIso8601String();
            _pasajeros[index]['estado_datos'] = '📷 Foto subida';
            _pasajeros[index]['color_estado'] = _naranjaAlerta;
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('📷 Foto de DNI subida exitosamente')),
              backgroundColor: _verdeExito,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al subir foto: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _validarDatosPasajero(String pasajeroId) {
    final pasajero = _pasajeros.firstWhere((p) => p['id'] == pasajeroId);
    
    // Verificar que todos los datos esten completos
    if (pasajero['nombre_pasajero'] != null &&
        pasajero['apellido_pasajero'] != null &&
        pasajero['dni_pasajero'] != null &&
        pasajero['foto_dni_url'] != null) {
      
      setState(() {
        final index = _pasajeros.indexWhere((p) => p['id'] == pasajeroId);
        if (index != -1) {
          _pasajeros[index]['datos_validados'] = true;
          _pasajeros[index]['estado_datos'] = '✅ Completos';
          _pasajeros[index]['color_estado'] = _verdeExito;
        }
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('✅ Datos del pasajero validados')),
            backgroundColor: _verdeExito,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('❌ Faltan datos por completar')),
            backgroundColor: _rojoProblema,
          ),
        );
      }
    }
  }

  Future<void> _aceptarViaje() async {
    try {
      setState(() => _isSaving = true);
      
      // Preparar lista de pasajeros
      final listaPasajeros = _pasajeros.map((p) => {
        'nombre': p['nombre_pasajero'],
        'apellido': p['apellido_pasajero'],
        'dni': p['dni_pasajero'],
        'foto_dni_url': p['foto_dni_url'],
      }).toList().toList();
      
      final resultado = await SupabaseService.aceptarViajeYCargarDatos(
        widget.pedidoId ?? '',
        '11111111-1111-1111-1111-111111111111', // ID de prueba pescador
        listaPasajeros,
        true, // Confirmar pago
      );
      
      if (mounted) {
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text(
                '🎉 ¡Viaje aceptado!\n'
                'Monto total: \$${resultado['monto_total']?.toStringAsFixed(2)}\n'
                'Total bultos: ${resultado['total_bultos']}\n'
                'Pasajeros: ${resultado['pasajeros_cargados']}'
              )),
              backgroundColor: _verdeExito,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context); // Volver al dashboard
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('Error: ${resultado['mensaje']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al aceptar viaje: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Manifiesto de Pasajeros'),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header con informacion del viaje
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _azulNautico,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Informacion del Viaje',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildInfoCard(
                              'Pasajeros',
                              '${_pasajeros.length}',
                              Icons.people,
                              Colors.white,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoCard(
                              'Bultos',
                              '${_productosViaje.length}',
                              Icons.inventory_2,
                              Colors.white,
                            ),
                          ),
                          Expanded(
                            child: _buildInfoCard(
                              'Estado',
                              _pasajeros.every((p) => p['datos_validados'] == true) ? 'Completo' : 'Pendiente',
                              Icons.check_circle,
                              _pasajeros.every((p) => p['datos_validados'] == true) ? _verdeExito : _naranjaAlerta,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Lista de pasajeros
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Lista de Pasajeros',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: _azulNautico,
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: _agregarPasajero,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar Pasajero'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _azulNautico,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        ..._pasajeros.map((pasajero) => _buildPasajeroCard(pasajero)),
                        
                        // Productos del viaje
                        if (_productosViaje.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const Text(
                            'Productos para Entregar',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _azulNautico,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ..._productosViaje.map((producto) => _buildProductoCard(producto)),
                        ],
                      ],
                    ),
                  ),
                ),
                
                // Boton de aceptacion
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(top: BorderSide(color: Colors.grey[300]!)),
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving || _pasajeros.isEmpty ? null : _aceptarViaje,
                      icon: _isSaving 
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_circle),
                      label: Text(_isSaving ? 'Procesando...' : 'Aceptar Viaje'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verdeExito,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasajeroCard(Map<String, dynamic> pasajero) {
    final estadoColor = (pasajero['color_estado'] is Color) 
        ? pasajero['color_estado'] as Color 
        : Colors.grey;
    final estadoIcon = pasajero['datos_validados'] == true 
        ? Icons.check_circle 
        : pasajero['foto_dni_url'] != null 
            ? Icons.photo_camera 
            : Icons.person_outline;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header con foto y estado
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _azulNautico.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _azulNautico, width: 2),
                  ),
                  child: pasajero['foto_dni_url'] != null
                      ? ClipOval(
                          child: Image.network(
                            pasajero['foto_dni_url'],
                            width: 46,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(estadoIcon, color: _azulNautico);
                            },
                          ),
                        )
                      : Icon(estadoIcon, color: _azulNautico),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${pasajero['nombre_pasajero'] ?? ''} ${pasajero['apellido_pasajero'] ?? ''}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      Text(
                        'DNI: ${pasajero['dni_pasajero'] ?? 'Pendiente'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: estadoColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    pasajero['estado_datos'] ?? '❌ Incompletos',
                    style: TextStyle(
                      color: estadoColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Acciones
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _subirFotoDNI(pasajero['id']),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Subir DNI'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulNautico,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _validarDatosPasajero(pasajero['id']),
                    icon: const Icon(Icons.verified),
                    label: const Text('Validar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verdeExito,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoCard(Map<String, dynamic> producto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _naranjaAlerta.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.inventory, color: _naranjaAlerta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre_producto'] ?? 'Producto',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Cantidad: ${producto['cantidad']} | Precio: \$${producto['precio_unitario']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${producto['subtotal']?.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasajeroFormDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onSaved;

  const _PasajeroFormDialog({required this.onSaved});

  @override
  State<_PasajeroFormDialog> createState() => _PasajeroFormDialogState();
}

class _PasajeroFormDialogState extends State<_PasajeroFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _dniController = TextEditingController();
  String? _fotoDniUrl;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Agregar Pasajero'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa el nombre';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apellidoController,
              decoration: const InputDecoration(
                labelText: 'Apellido',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa el apellido';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _dniController,
              decoration: const InputDecoration(
                labelText: 'DNI',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa el DNI';
                }
                if (value.length < 7 || value.length > 8) {
                  return 'El DNI debe tener entre 7 y 8 digitos';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              widget.onSaved({
                'nombre': _nombreController.text,
                'apellido': _apellidoController.text,
                'dni': _dniController.text,
                'foto_dni_url': _fotoDniUrl,
              });
              Navigator.pop(context);
            }
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
