import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:capitanya_master/models/direccion_envio.dart';
import 'package:capitanya_master/models/manifiesto_viaje.dart';
import 'package:capitanya_master/models/user_profile.dart';
import 'package:capitanya_master/providers/cart_provider.dart';
import 'package:capitanya_master/services/storage_service.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/screens/checkout_payment_screen.dart';
// import '../widgets/product_cart_item.dart'; // Removido por no existir y no usarse

class SmartCheckoutScreen extends StatefulWidget {
  const SmartCheckoutScreen({super.key});

  @override
  State<SmartCheckoutScreen> createState() => _SmartCheckoutScreenState();
}

class _SmartCheckoutScreenState extends State<SmartCheckoutScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers para datos de envio
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _direccionController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _paisController = TextEditingController(text: 'Argentina');
  final _referenciasController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingDireccion = false;
  final bool _isLoadingManifiestos = false;
  bool _pagoProcesado = false; // true una vez que el usuario navega a pagar
  UserProfile? _userProfile;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    // Dispose controllers de envio
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    _ciudadController.dispose();
    _provinciaController.dispose();
    _codigoPostalController.dispose();
    _paisController.dispose();
    _referenciasController.dispose();
    
    super.dispose();
  }

  // Validar formulario de envio
  bool _validarFormularioEnvio() {
    if (!context.read<CartProvider>().tieneItemsTienda) return true;
    
    return _nombreController.text.trim().isNotEmpty &&
           _apellidoController.text.trim().isNotEmpty &&
           _telefonoController.text.trim().isNotEmpty &&
           _emailController.text.trim().isNotEmpty &&
           _direccionController.text.trim().isNotEmpty &&
           _ciudadController.text.trim().isNotEmpty &&
           _provinciaController.text.trim().isNotEmpty &&
           _codigoPostalController.text.trim().isNotEmpty &&
           _paisController.text.trim().isNotEmpty;
  }

  // Validar manifiestos de viaje
  bool _validarManifiestosViaje() {
    if (!context.read<CartProvider>().tieneItemsViaje) return true;
    
    final manifiestos = context.read<CartProvider>().manifiestosViaje;
    return manifiestos.isNotEmpty && manifiestos.every((m) => m.isValid);
  }

  // Guardar datos de envio
  Future<void> _guardarDireccionEnvio() async {
    if (!context.read<CartProvider>().tieneItemsTienda) return;
    
    if (!_validarFormularioEnvio()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Por favor, complete todos los campos de envio')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoadingDireccion = true);

    try {
      // Simular usuario ID (en una app real vendria de autenticacion)
      final usuarioId = 'user_${DateTime.now().millisecondsSinceEpoch}';

      final direccion = DireccionEnvio.temporal(
        usuarioId: usuarioId,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        email: _emailController.text.trim(),
        direccion: _direccionController.text.trim(),
        ciudad: _ciudadController.text.trim(),
        provincia: _provinciaController.text.trim(),
        codigoPostal: _codigoPostalController.text.trim(),
        pais: _paisController.text.trim(),
        referencias: _referenciasController.text.trim().isEmpty 
            ? null 
            : _referenciasController.text.trim(),
      );

      // Guardar en Supabase (o en estado del provider para checkout temporal)
      final direccionId = await SupabaseService.guardarDireccionEnvio(direccion);
      
      // Actualizar con ID real
      final direccionConId = DireccionEnvio(
        id: direccionId,
        usuarioId: usuarioId,
        nombre: direccion.nombre,
        apellido: direccion.apellido,
        telefono: direccion.telefono,
        email: direccion.email,
        direccion: direccion.direccion,
        ciudad: direccion.ciudad,
        provincia: direccion.provincia,
        codigoPostal: direccion.codigoPostal,
        pais: direccion.pais,
        referencias: direccion.referencias,
        esPrincipal: direccion.esPrincipal,
        createdAt: direccion.createdAt,
        updatedAt: direccion.updatedAt,
      );

      // Guardar en provider
      context.read<CartProvider>().setDireccionEnvio(direccionConId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('Datos de envio guardados')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al guardar direccion: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingDireccion = false);
    }
  }

  // Agregar pasajero al manifiesto
  void _agregarPasajero() {
    final viajeId = 'viaje_${DateTime.now().millisecondsSinceEpoch}';
    showDialog(
      context: context,
      builder: (context) => _PasajeroFormDialog(
        viajeId: viajeId,
        perfilUsuario: _userProfile, // Pasar perfil para auto-completar
        onGuardar: (manifiesto) {
          context.read<CartProvider>().addManifiestoViaje(manifiesto);
          Navigator.pop(context);
        },
      ),
    );
  }

  // Editar pasajero
  void _editarPasajero(int index) {
    final manifiesto = context.read<CartProvider>().manifiestosViaje[index];
    final viajeId = 'viaje_${DateTime.now().millisecondsSinceEpoch}';
    
    showDialog(
      context: context,
      builder: (context) => _PasajeroFormDialog(
        viajeId: viajeId,
        manifiesto: manifiesto,
        perfilUsuario: _userProfile, // Pasar perfil para auto-completar
        onGuardar: (manifiestoActualizado) {
          context.read<CartProvider>().updateManifiestoViaje(index, manifiestoActualizado);
          Navigator.pop(context);
        },
      ),
    );
  }

  // Eliminar pasajero
  void _eliminarPasajero(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Pasajero'),
        content: const Text('¿Esta seguro que quiere eliminar este pasajero?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              context.read<CartProvider>().removeManifiestoViaje(index);
              Navigator.pop(context);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Proceder al pago
  Future<void> _procederAlPago() async {
    final cartProvider = context.read<CartProvider>();
    
    if (!cartProvider.puedeProcederAlPago) {
      String mensajeError = '';
      
      if (!cartProvider.datosEnvioValidos) {
        mensajeError = 'Complete los datos de envio';
      } else if (!cartProvider.manifiestosValidos) {
        mensajeError = 'Complete la informacion de los pasajeros';
      } else {
        mensajeError = 'Verifique todos los datos requeridos';
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text(mensajeError)),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simular usuario ID
      final usuarioId = 'user_${DateTime.now().millisecondsSinceEpoch}';

      // Guardar manifiestos en Supabase si hay items de viaje
      if (cartProvider.tieneItemsViaje) {
        final manifiestosIds = await SupabaseService.guardarManifiestosViajeBatch(
          cartProvider.manifiestosViaje,
        );
        
        // Actualizar manifiestos con IDs reales
        for (int i = 0; i < manifiestosIds.length; i++) {
          final manifiestoActualizado = ManifiestoViaje(
            id: manifiestosIds[i],
            usuarioId: usuarioId,
            nombre: cartProvider.manifiestosViaje[i].nombre,
            apellido: cartProvider.manifiestosViaje[i].apellido,
            telefono: cartProvider.manifiestosViaje[i].telefono,
            email: cartProvider.manifiestosViaje[i].email,
            documento: cartProvider.manifiestosViaje[i].documento,
            numeroDocumento: cartProvider.manifiestosViaje[i].numeroDocumento,
            fechaNacimiento: cartProvider.manifiestosViaje[i].fechaNacimiento,
            nacionalidad: cartProvider.manifiestosViaje[i].nacionalidad,
            emergenciaContacto: cartProvider.manifiestosViaje[i].emergenciaContacto,
            emergenciaTelefono: cartProvider.manifiestosViaje[i].emergenciaTelefono,
            condicionesMedicas: cartProvider.manifiestosViaje[i].condicionesMedicas,
            alergias: cartProvider.manifiestosViaje[i].alergias,
            preferenciasComida: cartProvider.manifiestosViaje[i].preferenciasComida,
            createdAt: cartProvider.manifiestosViaje[i].createdAt,
            updatedAt: DateTime.now(),
          );
          cartProvider.updateManifiestoViaje(i, manifiestoActualizado);
        }
      }

      // Navegar a la pantalla de pago real con Mercado Pago
      if (mounted) {
        // Usar el ID del primer manifiesto como reserva, o generar uno temporal
        final reservaId = cartProvider.manifiestosViaje.isNotEmpty
            ? cartProvider.manifiestosViaje.first.id
            : 'reserva_${DateTime.now().millisecondsSinceEpoch}';

        final emailPagador = cartProvider.manifiestosViaje.isNotEmpty
            ? cartProvider.manifiestosViaje.first.email
            : '';

        final descripcion = cartProvider.tieneItemsViaje
            ? 'Reserva de Viaje – ${cartProvider.manifiestosViaje.length} pasajero(s)'
            : 'Compra en CapitanYA';

        // Marcar que el pago fue iniciado → bloquea los formularios
        setState(() => _pagoProcesado = true);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutPaymentScreen(
              amount: cartProvider.totalCarrito,
              description: descripcion,
              reservaId: reservaId,
              emailPagador: emailPagador,
            ),
          ),
        ).then((_) {
          // Si el usuario vuelve atrás sin pagar, desbloquear formularios
          if (mounted) setState(() => _pagoProcesado = false);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al procesar: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Checkout Inteligente',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Consumer<CartProvider>(
        builder: (context, cartProvider, child) {
          if (cartProvider.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Tu carrito esta vacio',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Seguir Comprando'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen del carrito
                  _buildResumenCarrito(cartProvider),
                  
                  const SizedBox(height: 24),

                  // Banner de pago procesado
                  if (_pagoProcesado)
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.5)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.lock_outline, color: Color(0xFF00E676), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Datos bloqueados — el pago fue iniciado. Para modificar, cancelá el proceso.',
                              style: TextStyle(color: Color(0xFF00E676), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Seccion de Datos de Envio (solo si hay items de tienda)
                  if (cartProvider.tieneItemsTienda) ...[
                    _buildSeccionEnvio(cartProvider, readOnly: _pagoProcesado),
                    const SizedBox(height: 24),
                  ],
                  
                  // Seccion de Informacion de Pasajeros (solo si hay items de viaje)
                  if (cartProvider.tieneItemsViaje) ...[
                    _buildSeccionPasajeros(cartProvider, readOnly: _pagoProcesado),
                    const SizedBox(height: 24),
                  ],
                  
                  // Boton de proceder al pago
                  _buildBotonPago(cartProvider),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumenCarrito(CartProvider cartProvider) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumen del Carrito',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),
            
            // Items de tienda
            if (cartProvider.tieneItemsTienda) ...[
              const Text(
                '📦 Productos de Tienda',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 8),
              ...cartProvider.itemsTienda.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.cantidad}x ${item.nombreProducto}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      item.subtotalFormateado,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],
            
            // Items de viaje
            if (cartProvider.tieneItemsViaje) ...[
              const Text(
                '🚢 Productos de Viaje',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 8),
              ...cartProvider.itemsViaje.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${item.cantidad}x ${item.nombreProducto}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      item.subtotalFormateado,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              )),
              const SizedBox(height: 12),
            ],
            
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  cartProvider.totalFormateado,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionEnvio(CartProvider cartProvider, {bool readOnly = false}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping, color: Color(0xFF0D47A1)),
                const SizedBox(width: 8),
                const Text(
                  'Datos de Envio',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const Spacer(),
                if (_userProfile?.hasCompleteData == true)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Text(
                      'Desde Perfil',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (cartProvider.direccionEnvio != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      'Guardado',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            
            // Indicador de datos del perfil
            if (_userProfile?.hasCompleteData == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Algunos campos fueron auto-completados desde tu perfil. Puedes modificarlos si es necesario.',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            
            const SizedBox(height: 16),
            
            // Campos del formulario
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _nombreController,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      labelText: 'Nombre *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: readOnly,
                      fillColor: readOnly ? Colors.grey.shade100 : null,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _apellidoController,
                    readOnly: readOnly,
                    decoration: InputDecoration(
                      labelText: 'Apellido *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
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
                    controller: _telefonoController,
                    decoration: InputDecoration(
                      labelText: 'Telefono *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
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
              controller: _direccionController,
              decoration: InputDecoration(
                labelText: 'Direccion *',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Requerido';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _ciudadController,
                    decoration: InputDecoration(
                      labelText: 'Ciudad *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _provinciaController,
                    decoration: InputDecoration(
                      labelText: 'Provincia *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
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
                  flex: 2,
                  child: TextFormField(
                    controller: _codigoPostalController,
                    decoration: InputDecoration(
                      labelText: 'Codigo Postal *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _paisController,
                    decoration: InputDecoration(
                      labelText: 'Pais *',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Requerido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _referenciasController,
              decoration: InputDecoration(
                labelText: 'Referencias (opcional)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Boton de guardar direccion
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoadingDireccion ? null : _guardarDireccionEnvio,
                icon: _isLoadingDireccion
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(_isLoadingDireccion ? 'Guardando...' : 'Guardar Datos de Envio'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionPasajeros(CartProvider cartProvider, {bool readOnly = false}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: Color(0xFF0D47A1)),
                const SizedBox(width: 8),
                const Text(
                  'Informacion de Pasajeros',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const Spacer(),
                if (cartProvider.manifiestosValidos)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      'Completos',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Lista de pasajeros
            if (cartProvider.manifiestosViaje.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(Icons.person_add, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 8),
                    Text(
                      'No hay pasajeros registrados',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...cartProvider.manifiestosViaje.asMap().entries.map((entry) {
                final index = entry.key;
                final manifiesto = entry.value;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFF0D47A1),
                        child: Text(
                          manifiesto.nombre.isNotEmpty ? manifiesto.nombre[0].toUpperCase() : 'P',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              manifiesto.nombreCompleto,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${manifiesto.edad} anos • ${manifiesto.documentoCompleto}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            if (manifiesto.emergenciaContacto != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Emergencia: ${manifiesto.emergenciaContacto}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: readOnly ? null : () => _editarPasajero(index),
                            icon: const Icon(Icons.edit, size: 20),
                            color: const Color(0xFF0D47A1),
                          ),
                          IconButton(
                            onPressed: readOnly ? null : () => _eliminarPasajero(index),
                            icon: const Icon(Icons.delete, size: 20),
                            color: Colors.red,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ],
            
            const SizedBox(height: 16),
            
            // Boton de agregar pasajero
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: readOnly ? null : _agregarPasajero,
                icon: const Icon(Icons.add),
                label: const Text('Agregar Pasajero'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0D47A1),
                  side: const BorderSide(color: Color(0xFF0D47A1)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonPago(CartProvider cartProvider) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 16),
      child: ElevatedButton.icon(
        onPressed: (_isLoading || !cartProvider.puedeProcederAlPago) ? null : _procederAlPago,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.lock),
        label: Text(_isLoading ? 'Procesando...' : 'Proceder al Pago'),
        style: ElevatedButton.styleFrom(
          backgroundColor: cartProvider.puedeProcederAlPago ? const Color(0xFF0D47A1) : Colors.grey,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
      ),
    );
  }
}

// Dialogo para formulario de pasajero
class _PasajeroFormDialog extends StatefulWidget {
  final ManifiestoViaje? manifiesto;
  final Function(ManifiestoViaje) onGuardar;
  final String? viajeId;
  final UserProfile? perfilUsuario;

  const _PasajeroFormDialog({
    this.manifiesto,
    required this.onGuardar,
    this.viajeId,
    this.perfilUsuario,
  });

  @override
  State<_PasajeroFormDialog> createState() => _PasajeroFormDialogState();
}

class _PasajeroFormDialogState extends State<_PasajeroFormDialog> {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _documentoController = TextEditingController(text: 'DNI');
  final _numeroDocumentoController = TextEditingController();
  final _nacionalidadController = TextEditingController(text: 'Argentina');
  final _emergenciaContactoController = TextEditingController();
  final _emergenciaTelefonoController = TextEditingController();
  final _condicionesMedicasController = TextEditingController();
  final _alergiasController = TextEditingController();
  final _preferenciasComidaController = TextEditingController();
  
  DateTime _fechaNacimiento = DateTime.now().subtract(const Duration(days: 365 * 25));
  dynamic _fotoDni;
  bool _isLoadingFoto = false;
  UserProfile? _userProfile;

  @override
  void initState() {
    super.initState();
    
    // Auto-completar desde perfil del usuario si existe
    if (widget.perfilUsuario != null) {
      final perfil = widget.perfilUsuario!;
      
      // Pre-completar telefono desde perfil
      if (perfil.telefono != null && perfil.telefono!.isNotEmpty) {
        _telefonoController.text = perfil.telefono!;
      }
      
      // Pre-completar DNI desde perfil
      if (perfil.dni != null && perfil.dni!.isNotEmpty) {
        _numeroDocumentoController.text = perfil.dni!;
      }
    }
    
    // Cargar datos del manifiesto si existe (para edicion)
    if (widget.manifiesto != null) {
      _nombreController.text = widget.manifiesto!.nombre;
      _apellidoController.text = widget.manifiesto!.apellido;
      _telefonoController.text = widget.manifiesto!.telefono;
      _emailController.text = widget.manifiesto!.email;
      _documentoController.text = widget.manifiesto!.documento ?? 'DNI';
      _numeroDocumentoController.text = widget.manifiesto!.numeroDocumento ?? '';
      _nacionalidadController.text = widget.manifiesto!.nacionalidad ?? 'Argentina';
      _emergenciaContactoController.text = widget.manifiesto!.emergenciaContacto ?? '';
      _emergenciaTelefonoController.text = widget.manifiesto!.emergenciaTelefono ?? '';
      _condicionesMedicasController.text = widget.manifiesto!.condicionesMedicas ?? '';
      _alergiasController.text = widget.manifiesto!.alergias ?? '';
      _preferenciasComidaController.text = widget.manifiesto!.preferenciasComida ?? '';
      _fechaNacimiento = widget.manifiesto!.fechaNacimiento;
      
      // Si el manifiesto tiene foto DNI, mostrarla
      if (widget.manifiesto!.tieneFotoDni) {
        _fotoDni = widget.manifiesto!.fotoDniUrl!;
      }
    }
  }

  Future<void> _cargarPerfilUsuario() async {
    try {
      // Usar user_id de prueba (sin validaciones de Auth)
      final testUserId = '00000000-0000-0000-0000-000000000000';
      final profile = await SupabaseService.getOrCreateProfile(testUserId);
      
      setState(() => _userProfile = profile);
      
      // Auto-completar datos si existen
      // Completar telefono en formulario de envio
      if (profile.telefono != null && profile.telefono!.isNotEmpty) {
        _telefonoController.text = profile.telefono!;
      }
      
      // Si hay DNI, pre-completar en formulario de pasajeros
      if (profile.dni != null && profile.dni!.isNotEmpty) {
        _numeroDocumentoController.text = profile.dni!;
      }
        } catch (e) {
      // No mostrar error critico, solo log
      print('Error al cargar perfil de usuario: $e');
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _documentoController.dispose();
    _numeroDocumentoController.dispose();
    _nacionalidadController.dispose();
    _emergenciaContactoController.dispose();
    _emergenciaTelefonoController.dispose();
    _condicionesMedicasController.dispose();
    _alergiasController.dispose();
    _preferenciasComidaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_fotoDni == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Por favor, agregue una foto del DNI')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoadingFoto = true);

    try {
      final usuarioId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final viajeId = widget.viajeId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

      // Subir foto DNI al bucket documentos_viaje
      final fotoDniUrl = await StorageService.uploadDniViaje(
        file: _fotoDni!,
        userId: usuarioId,
      );

      final manifiesto = ManifiestoViaje.temporal(
        usuarioId: usuarioId,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        telefono: _telefonoController.text.trim(),
        email: _emailController.text.trim(),
        documento: _documentoController.text.trim(),
        numeroDocumento: _numeroDocumentoController.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        nacionalidad: _nacionalidadController.text.trim(),
        emergenciaContacto: _emergenciaContactoController.text.trim().isEmpty 
            ? null 
            : _emergenciaContactoController.text.trim(),
        emergenciaTelefono: _emergenciaTelefonoController.text.trim().isEmpty 
            ? null 
            : _emergenciaTelefonoController.text.trim(),
        condicionesMedicas: _condicionesMedicasController.text.trim().isEmpty 
            ? null 
            : _condicionesMedicasController.text.trim(),
        alergias: _alergiasController.text.trim().isEmpty 
            ? null 
            : _alergiasController.text.trim(),
        preferenciasComida: _preferenciasComidaController.text.trim().isEmpty 
            ? null 
            : _preferenciasComidaController.text.trim(),
        fotoDniUrl: fotoDniUrl,
      );

      widget.onGuardar(manifiesto);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al guardar: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoadingFoto = false);
    }
  }

  // Metodos para manejo de foto DNI
  Future<void> _seleccionarFotoDni() async {
    try {
      final dynamic foto = await StorageService.pickDniImage();
      if (foto != null) {
        setState(() => _fotoDni = foto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al seleccionar foto: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _tomarFotoDni() async {
    try {
      final dynamic foto = await StorageService.captureDniImage();
      if (foto != null) {
        setState(() => _fotoDni = foto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al tomar foto: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.manifiesto == null ? 'Agregar Pasajero' : 'Editar Pasajero'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreController,
                        decoration: InputDecoration(
                          labelText: 'Nombre *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoController,
                        decoration: InputDecoration(
                          labelText: 'Apellido *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
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
                        controller: _telefonoController,
                        decoration: InputDecoration(
                          labelText: 'Telefono *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: 'Email *',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Requerido';
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
                
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _documentoController.text,
                        decoration: InputDecoration(
                          labelText: 'Tipo Documento',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        items: ManifiestoViaje.tiposDocumentos.map((tipo) {
                          return DropdownMenuItem<String>(
                            value: tipo,
                            child: Text(tipo),
                          );
                        }).toList(),
                        onChanged: (value) {
                          _documentoController.text = value ?? 'DNI';
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _numeroDocumentoController,
                        decoration: InputDecoration(
                          labelText: 'Numero Documento',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                ListTile(
                  title: const Text('Fecha de Nacimiento *'),
                  subtitle: Text('${_fechaNacimiento.day}/${_fechaNacimiento.month}/${_fechaNacimiento.year}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final fecha = await showDatePicker(
                      context: context,
                      initialDate: _fechaNacimiento,
                      firstDate: DateTime.now().subtract(const Duration(days: 365 * 120)),
                      lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                    );
                    if (fecha != null) {
                      setState(() => _fechaNacimiento = fecha);
                    }
                  },
                ),
                
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _nacionalidadController,
                  decoration: InputDecoration(
                    labelText: 'Nacionalidad',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Informacion de Emergencia',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 8),
                
                TextFormField(
                  controller: _emergenciaContactoController,
                  decoration: InputDecoration(
                    labelText: 'Contacto de Emergencia',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _emergenciaTelefonoController,
                  decoration: InputDecoration(
                    labelText: 'Telefono de Emergencia',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 12),
                
                const Text(
                  'Informacion Medica',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 8),
                
                TextFormField(
                  controller: _condicionesMedicasController,
                  decoration: InputDecoration(
                    labelText: 'Condiciones Medicas (opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _alergiasController,
                  decoration: InputDecoration(
                    labelText: 'Alergias (opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _preferenciasComidaController,
                  decoration: InputDecoration(
                    labelText: 'Preferencias de Comida (opcional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 2,
                ),
                
                const SizedBox(height: 16),
                
                // Seccion de Foto DNI
                const Text(
                  'Foto del DNI *',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                const SizedBox(height: 8),
                
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _fotoDni != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              if (_fotoDni!.path.startsWith('http'))
                                Image.network(
                                  _fotoDni!.path,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, url, error) => Container(
                                    color: Colors.grey[200],
                                    child: const Center(
                                      child: Icon(Icons.error, color: Colors.red),
                                    ),
                                  ),
                                )
                              else
                                Image.network(
                                  _fotoDni!.path,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.green[600],
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    onPressed: () => setState(() => _fotoDni = null),
                                    icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agregar foto del DNI',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _seleccionarFotoDni,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Seleccionar de Galeria'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0D47A1),
                          side: const BorderSide(color: Color(0xFF0D47A1)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _tomarFotoDni,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tomar Foto'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoadingFoto ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
          ),
          child: _isLoadingFoto
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
