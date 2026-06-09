import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/cotizaciones_service.dart';
import '../services/supabase_service.dart';
import 'sala_espera_pescador_screen.dart';

class CotizacionesFormularioScreen extends StatefulWidget {
  final String? cotizacionId; // Para modo edicion
  
  const CotizacionesFormularioScreen({super.key, this.cotizacionId});

  @override
  State<CotizacionesFormularioScreen> createState() => _CotizacionesFormularioScreenState();
}

class _CotizacionesFormularioScreenState extends State<CotizacionesFormularioScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;
  
  // Controladores del formulario
  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _montoController = TextEditingController();
  final _vigenciaDiasController = TextEditingController(text: '7');
  String _tipoSubasta = 'estandar'; // 'rapida' o 'estandar'
  final _pescadorIdController = TextEditingController();
  final _viajeIdController = TextEditingController();
  
  // Lista de items del presupuesto
  List<Map<String, dynamic>> _items = [];
  
  // Campos adicionales
  final _incluyeController = TextEditingController();
  final _noIncluyeController = TextEditingController();
  final _especialidadController = TextEditingController();
  final _experienciaController = TextEditingController();
  
  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _rojoFuerte = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _isEditing = widget.cotizacionId != null;
    
    if (_isEditing) {
      _cargarCotizacionExistente();
    } else {
      _agregarItemVacio(); // Agregar primer item vacio
    }
  }

  Future<void> _cargarCotizacionExistente() async {
    if (widget.cotizacionId == null) return;
    
    final cotizacion = await CotizacionesService.obtenerCotizacionPorId(widget.cotizacionId!);
    if (cotizacion == null) return;
    setState(() {
      _tituloController.text = cotizacion['titulo'] ?? '';
      _descripcionController.text = cotizacion['descripcion'] ?? '';
      _montoController.text = (cotizacion['monto_total'] ?? '').toString();
      _pescadorIdController.text = cotizacion['pescador_id'] ?? '';
      _viajeIdController.text = cotizacion['viaje_id'] ?? '';
      
      final detalles = cotizacion['detalles'] ?? {};
      _items = List<Map<String, dynamic>>.from(detalles['items'] ?? []);
      _incluyeController.text = (detalles['incluye'] as List?)?.join(', ') ?? '';
      _noIncluyeController.text = (detalles['no_incluye'] as List?)?.join(', ') ?? '';
      _especialidadController.text = detalles['especialidad'] ?? '';
      _experienciaController.text = detalles['experiencia'] ?? '';
    });
  }

  void _agregarItemVacio() {
    setState(() {
      _items.add({
        'descripcion': '',
        'cantidad': 1,
        'precio_unitario': 0.0,
        'subtotal': 0.0,
      });
    });
  }

  void _eliminarItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _actualizarItem(int index, String campo, dynamic valor) {
    setState(() {
      _items[index][campo] = valor;
      
      // Recalcular subtotal si cambian cantidad o precio unitario
      if (campo == 'cantidad' || campo == 'precio_unitario') {
        final cantidad = _items[index]['cantidad'] as int;
        final precioUnitario = _items[index]['precio_unitario'] as double;
        _items[index]['subtotal'] = cantidad * precioUnitario;
      }
    });
  }

  double _calcularTotal() {
    return _items.fold<double>(0, (total, item) {
      return total + (item['subtotal'] as double);
    });
  }

  Future<void> _guardarCotizacion() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Por favor completa todos los campos requeridos'),
          backgroundColor: _rojoFuerte,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = SupabaseService.currentUserId;
      
      if (userId == null) throw Exception('Usuario no autenticado');

      final int horasSubasta = _tipoSubasta == 'rapida' ? 12 : 24;
      final DateTime expiraEn = DateTime.now().add(Duration(hours: horasSubasta));

      // 1. Insertar en Supabase real con expiración
      final response = await supabase.from('cotizaciones').insert({
        'pescador_id': userId,
        'descripcion': _descripcionController.text.trim(),
        'estado': 'pendiente',
        'expira_en': expiraEn.toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
        'provincia_partida': 'Buenos Aires',
        'localidad_partida': 'Tigre',
      }).select().single();

      final String cotizacionId = response['id'];

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🚀 Solicitud enviada al radar de capitanes'),
          backgroundColor: Colors.green,
        ),
      );

      // 2. Navegar a la Sala de Espera
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => SalaEsperaPescadorScreen(cotizacionId: cotizacionId),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Editar Cotizacion' : 'Nueva Cotizacion',
          style: const TextStyle(
            color: _blancoPuro,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
        actions: [
          if (_isEditing) ...[
            IconButton(
              onPressed: () {
                // Enviar mensaje al pescador
                _enviarMensajePescador();
              },
              icon: const Icon(Icons.message, color: _blancoPuro),
              tooltip: 'Enviar mensaje',
            ),
          ],
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informacion basica
                _buildSectionCard(
                  title: '📋 Informacion Basica',
                  children: [
                    TextFormField(
                      controller: _descripcionController,
                      maxLines: 4,
                      decoration: _buildInputDecoration('Descripcion del Viaje'),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La descripcion es requerida';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pescadorIdController,
                          decoration: _buildInputDecoration('ID del Pescador'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El ID del pescador es requerido';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _viajeIdController,
                          decoration: _buildInputDecoration('ID del Viaje'),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'El ID del viaje es requerido';
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
                          controller: _vigenciaDiasController,
                          decoration: _buildInputDecoration('Vigencia (dias)'),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'La vigencia es requerida';
                            }
                            final dias = int.tryParse(value);
                            if (dias == null || dias < 1 || dias > 30) {
                              return 'La vigencia debe ser entre 1 y 30 dias';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Total: \$${_calcularTotal().toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _azulVibrante,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
              
              const SizedBox(height: 16),
              
              // Items del presupuesto
              _buildSectionCard(
                title: '💰 Items del Presupuesto',
                children: [
                  ..._items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return _buildItemCard(index, item);
                  }),
                  
                  const SizedBox(height: 12),
                  const Text('DURACIÓN DE LA SUBASTA', 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildSubastaOption('Rápida (12h)', 'rapida', Icons.bolt),
                      const SizedBox(width: 12),
                      _buildSubastaOption('Estándar (24h)', 'estandar', Icons.schedule),
                    ],
                  ),
                  const SizedBox(height: 20),
                    
                  ElevatedButton.icon(
                    onPressed: _agregarItemVacio,
                    icon: const Icon(Icons.add, color: _blancoPuro),
                    label: const Text('Agregar Item'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _azulVibrante,
                      foregroundColor: _blancoPuro,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Informacion adicional
              _buildSectionCard(
                title: '📝 Informacion Adicional',
                children: [
                  TextFormField(
                    controller: _incluyeController,
                    decoration: _buildInputDecoration('¿Que incluye? (separado por comas)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noIncluyeController,
                    decoration: _buildInputDecoration('¿Que NO incluye? (separado por comas)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _especialidadController,
                    decoration: _buildInputDecoration('Especialidad'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _experienciaController,
                    decoration: _buildInputDecoration('Experiencia adicional'),
                    maxLines: 2,
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Botones de accion
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _rojoFuerte),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'CANCELAR',
                        style: TextStyle(color: _rojoFuerte),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _guardarCotizacion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _azulVibrante,
                        foregroundColor: _blancoPuro,
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                                Text('Guardando...'),
                              ],
                            )
                          : Text(_isEditing ? 'ACTUALIZAR COTIZACION' : 'CREAR COTIZACION'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _blancoPuro,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildItemCard(int index, Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fondoOscuro.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _blancoPuro.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item['descripcion'],
                  decoration: InputDecoration(
                    labelText: 'Descripcion',
                    labelStyle: TextStyle(color: _blancoPuro.withValues(alpha: 0.7)),
                    border: const OutlineInputBorder(),
                  ),
                  style: const TextStyle(color: _blancoPuro),
                  onChanged: (value) => _actualizarItem(index, 'descripcion', value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item['cantidad'].toString(),
                  decoration: InputDecoration(
                    labelText: 'Cantidad',
                    labelStyle: TextStyle(color: _blancoPuro.withValues(alpha: 0.7)),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: _blancoPuro),
                  onChanged: (value) => _actualizarItem(index, 'cantidad', int.tryParse(value) ?? 1),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item['precio_unitario'].toString(),
                  decoration: InputDecoration(
                    labelText: 'Precio Unitario',
                    labelStyle: TextStyle(color: _blancoPuro.withValues(alpha: 0.7)),
                    border: const OutlineInputBorder(),
                    prefixText: '\$',
                  ),
                  keyboardType: TextInputType.number,
                  style: const TextStyle(color: _blancoPuro),
                  onChanged: (value) => _actualizarItem(index, 'precio_unitario', double.tryParse(value) ?? 0.0),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _eliminarItem(index),
                icon: const Icon(Icons.delete, color: _rojoFuerte),
                tooltip: 'Eliminar item',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                'Subtotal: \$${(item['subtotal'] as double).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: _naranjaIntenso,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
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

  void _enviarMensajePescador() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '📤 Enviar Mensaje al Pescador',
          style: TextStyle(
            color: _fondoOscuro,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextFormField(
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Escribe tu mensaje aqui...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Aqui iria la logica para enviar mensaje
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Mensaje enviado correctamente'),
                  backgroundColor: _verdeBrillante,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulVibrante,
              foregroundColor: _blancoPuro,
            ),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubastaOption(String label, String value, IconData icon) {
    final bool isSelected = _tipoSubasta == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _tipoSubasta = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF6600) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSelected ? Colors.white : Colors.white24),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white54),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}
