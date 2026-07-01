

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../widgets/safe_button.dart';

class CheckoutDobleScreen extends StatefulWidget {
  final String? cotizacionId;

  const CheckoutDobleScreen({super.key, this.cotizacionId});

  @override
  State<CheckoutDobleScreen> createState() => _CheckoutDobleScreenState();
}

class _CheckoutDobleScreenState extends State<CheckoutDobleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  
  bool _disclaimerAceptado = false;
  bool _procesando = false;
  String? _pedidoTiendaId;
  String? _reservaViajeId;
  bool _checkoutTiendaCompletado = false;
  bool _checkoutViajeCompletado = false;
  
  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);

  @override
  void dispose() {
    _calleController.dispose();
    _numeroController.dispose();
    _codigoPostalController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Checkout'),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header de doble checkout
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _azulNautico,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Checkout Doble',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Procesaremos tu pedido de tienda y reserva de viaje por separado',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCheckoutStep(
                            'Tienda',
                            _checkoutTiendaCompletado,
                            Icons.shopping_cart,
                          ),
                        ),
                        Container(
                          width: 30,
                          height: 2,
                          color: Colors.white30,
                        ),
                        Expanded(
                          child: _buildCheckoutStep(
                            'Viaje',
                            _checkoutViajeCompletado,
                            Icons.directions_boat,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Seccion de productos de tienda
              _buildTiendaSection(),
              
              const SizedBox(height: 24),
              
              // Seccion de reserva de viaje
              _buildViajeSection(),
              
              const SizedBox(height: 24),
              
              // Direccion de entrega (solo texto)
              _buildDireccionSection(),
              
              const SizedBox(height: 24),
              
              // Disclaimer obligatorio
              _buildDisclaimerSection(),
              
              const SizedBox(height: 24),
              
              // Botones de checkout
              _buildCheckoutButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckoutStep(String titulo, bool completado, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: completado ? _verdeExito : Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: completado ? Colors.white : Colors.white70,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          titulo,
          style: TextStyle(
            color: completado ? Colors.white : Colors.white70,
            fontSize: 10,
            fontWeight: completado ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildTiendaSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shopping_cart, color: _azulNautico),
                const SizedBox(width: 8),
                const Text(
                  'Productos de Tienda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _checkoutTiendaCompletado ? _verdeExito : _naranjaAlerta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _checkoutTiendaCompletado ? 'Completado' : 'Pendiente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Lista de productos (simulada)
            _buildProductoItem('Carnada fresca', 2, 500.0),
            _buildProductoItem('Bebidas pack x6', 1, 800.0),
            
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Tienda',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$1,800.00',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductoItem(String nombre, int cantidad, double precio) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$nombre x$cantidad',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
              '\$${(precio * cantidad).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 14),
            ),
        ],
      ),
    );
  }

  Widget _buildViajeSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_boat, color: _azulNautico),
                const SizedBox(width: 8),
                const Text(
                  'Reserva de Viaje',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _checkoutViajeCompletado ? _verdeExito : _naranjaAlerta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _checkoutViajeCompletado ? 'Completado' : 'Pendiente',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Detalles del viaje (simulados)
            _buildViajeDetalle('Fecha', '15/03/2026'),
            _buildViajeDetalle('Horario', '08:00 AM'),
            _buildViajeDetalle('Pasajeros', '3 personas'),
            _buildViajeDetalle('Capitan', 'Juan Perez'),
            
            const Divider(),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Viaje',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '\$3,500.00',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViajeDetalle(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDireccionSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: _azulNautico),
                const SizedBox(width: 8),
                const Text(
                  'Direccion de Entrega',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Campos de texto obligatorios
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _calleController,
                    decoration: const InputDecoration(
                      labelText: 'Calle *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La calle es obligatoria';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _numeroController,
                    decoration: const InputDecoration(
                      labelText: 'NÃÂº',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _codigoPostalController,
                    decoration: const InputDecoration(
                      labelText: 'Codigo Postal *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'El CP es obligatorio';
                      }
                      if (value.length != 4 && !RegExp(r'^[A-Z]\d{4}[A-Z]{3}$').hasMatch(value)) {
                        return 'CP invalido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _localidadController,
                    decoration: const InputDecoration(
                      labelText: 'Localidad *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La localidad es obligatoria';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _provinciaController,
              decoration: const InputDecoration(
                labelText: 'Provincia',
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Aviso de bloqueo de coordenadas
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _rojoProblema.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _rojoProblema.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.block, color: _rojoProblema, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ð« No se permiten coordenadas de mapa. Use campos de texto para especificar la direcciÃ³n.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _rojoProblema,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDisclaimerSection() {
    return Container(
      decoration: BoxDecoration(
        color: _naranjaAlerta.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _naranjaAlerta.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber, color: _naranjaAlerta),
                const SizedBox(width: 8),
                const Text(
                  'Terminos y Condiciones',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _naranjaAlerta,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            const Text(
              'Acepto que la entrega de productos es exclusiva en domicilios urbanos y los tiempos son responsabilidad del correo.',
              style: TextStyle(fontSize: 12),
            ),
            
            const SizedBox(height: 8),
            
            CheckboxListTile(
              value: _disclaimerAceptado,
              onChanged: (value) {
                setState(() {
                  _disclaimerAceptado = value ?? false;
                });
              },
              title: const Text(
                'Acepto los terminos y condiciones (obligatorio)',
                style: TextStyle(fontSize: 12),
              ),
              activeColor: _azulNautico,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButtons() {
    return Column(
      children: [
        // Boton de checkout de tienda
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _checkoutTiendaCompletado || _procesando ? null : _procesarCheckoutTienda,
            style: ElevatedButton.styleFrom(
              backgroundColor: _checkoutTiendaCompletado ? _verdeExito : _azulNautico,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _procesando
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: SafeButtonText('Procesando...', style: const TextStyle(color: Colors.white))),
                    ],
                  )
                : const SafeButtonContent(icon: Icons.shopping_cart, label: 'Procesar pedido tienda'),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Boton de checkout de viaje
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _checkoutViajeCompletado || _procesando ? null : _procesarCheckoutViaje,
            style: ElevatedButton.styleFrom(
              backgroundColor: _checkoutViajeCompletado ? _verdeExito : _azulNautico,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _procesando
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: SafeButtonText('Procesando...', style: const TextStyle(color: Colors.white))),
                    ],
                  )
                : const SafeButtonContent(icon: Icons.directions_boat, label: 'Procesar reserva viaje'),
          ),
        ),
        
        const SizedBox(height: 12),
        
        // Boton de checkout combinado (solo si ambos estan completados)
        if (_checkoutTiendaCompletado && _checkoutViajeCompletado) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _verdeExito,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 32),
                SizedBox(height: 8),
                Text(
                  'Â¡Checkout Completado!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Tu pedido de tienda y reserva de viaje han sido procesados',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _procesarCheckoutTienda() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Por favor, completa los campos obligatorios')),
          backgroundColor: _rojoProblema,
        ),
      );
      return;
    }

    if (!_disclaimerAceptado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Debes aceptar los terminos y condiciones')),
          backgroundColor: _rojoProblema,
        ),
      );
      return;
    }

    setState(() => _procesando = true);

    try {
      // Crear direccion JSON
      final direccion = {
        'calle': _calleController.text,
        'numero': _numeroController.text,
        'codigo_postal': _codigoPostalController.text,
        'localidad': _localidadController.text,
        'provincia': _provinciaController.text,
      };

      // Crear productos JSON (simulado)
      final productos = [
        {
          'nombre': 'Carnada fresca',
          'precio': 500.0,
          'cantidad': 2,
        },
        {
          'nombre': 'Bebidas pack x6',
          'precio': 800.0,
          'cantidad': 1,
        },
      ];

      // Crear pedido_tienda
      final resultado = await SupabaseService.crearPedidoTienda(
        SupabaseService.currentUserId ?? '',
        productos,
        direccion,
        'domicilio',
        _disclaimerAceptado,
      );

      if (mounted) {
        if (resultado['exito'] == true) {
          setState(() {
            _pedidoTiendaId = resultado['pedido_tienda_id'];
            _checkoutTiendaCompletado = true;
            _procesando = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('â Pedido de tienda procesado exitosamente')),
              backgroundColor: _verdeExito,
            ),
          );
        } else {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('Error: ${resultado['mensaje']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _procesando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al procesar pedido: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _procesarCheckoutViaje() async {
    setState(() => _procesando = true);

    try {
      // Crear datos de pasajeros (simulado)
      final datosPasajeros = [
        {
          'nombre': 'Juan',
          'apellido': 'Perez',
          'dni': '12345678',
        },
        {
          'nombre': 'Maria',
          'apellido': 'Gomez',
          'dni': '87654321',
        },
        {
          'nombre': 'Carlos',
          'apellido': 'Lopez',
          'dni': '11223344',
        },
      ];

      // Crear productos_tienda (simulado)
      final productosTienda = [
        {
          'nombre': 'Carnada fresca',
          'precio': 500.0,
          'cantidad': 2,
        },
        {
          'nombre': 'Bebidas pack x6',
          'precio': 800.0,
          'cantidad': 1,
        },
      ];

      final pescadorId = SupabaseService.currentUserId;
      final cotizacionId = widget.cotizacionId;
      if (pescadorId == null || pescadorId.isEmpty) {
        throw Exception('IniciÃÂ³ sesiÃ¯Â¿Â½n para reservar el viaje');
      }
      if (cotizacionId == null || cotizacionId.isEmpty) {
        throw Exception('Falta la cotizaciÃÂ³n asociada al viaje');
      }

      // Crear reserva_viaje
      final resultado = await SupabaseService.crearReservaViaje(
        pescadorId,
        cotizacionId,
        datosPasajeros,
        productosTienda,
      );

      if (mounted) {
        if (resultado['exito'] == true) {
          setState(() {
            _reservaViajeId = resultado['reserva_viaje_id'];
            _checkoutViajeCompletado = true;
            _procesando = false;
          });

          // Vincular pedido_tienda con reserva_viaje
          if (_pedidoTiendaId != null) {
            await SupabaseService.vincularPedidoReserva(
              _pedidoTiendaId!,
              _reservaViajeId!,
              SupabaseService.currentUserId ?? '',
              'combinado',
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('? Reserva de viaje procesada exitosamente')),
              backgroundColor: _verdeExito,
            ),
          );
        } else {
          setState(() => _procesando = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('Error: ${resultado['mensaje']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _procesando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al procesar reserva: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
