
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../services/supabase_service.dart';
import '../services/core_business_logic.dart';
import '../widgets/boton_premium.dart';
import 'viaje_confirmado_screen.dart';
import '../models/manifiesto_viaje.dart';
import '../models/direccion_envio.dart';

class HybridCheckoutScreen extends StatefulWidget {
  const HybridCheckoutScreen({super.key});

  @override
  State<HybridCheckoutScreen> createState() => _HybridCheckoutScreenState();
}

class _HybridCheckoutScreenState extends State<HybridCheckoutScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;

  // Form Controllers
  final _formKeyDojo = GlobalKey<FormState>();
  final _formKeyEnvio = GlobalKey<FormState>();
  
  // Controllers Envio
  final _calleController = TextEditingController();
  final _alturaController = TextEditingController();
  final _localidadController = TextEditingController();
  
  // Controllers Manifiesto
  final _nombrePasajeroController = TextEditingController();
  final _dniPasajeroController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final List<Widget> steps = _buildSteps(cart);

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('CHECKOUT HÍBRIDO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        onStepContinue: () => _handleContinue(cart, steps.length),
        onStepCancel: () => _currentStep > 0 ? setState(() => _currentStep--) : Navigator.pop(context),
        steps: _buildStepperSteps(cart),
        controlsBuilder: (context, controls) {
          return Padding(
            padding: const EdgeInsets.only(top: 20),
            child: Row(
              children: [
                Expanded(
                  child: BotonPremium(
                    label: _currentStep == steps.length - 1 ? 'CONFIRMAR PAGO' : 'CONTINUAR',
                    onPressed: _isProcessing ? null : controls.onStepContinue,
                    color: const Color(0xFF00E676),
                  ),
                ),
                if (_currentStep > 0) ...[
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: controls.onStepCancel,
                    child: const Text('VOLVER', style: TextStyle(color: Colors.white54)),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  List<Step> _buildStepperSteps(CartProvider cart) {
    List<Step> steps = [];

    // Paso 1: Declaración Jurada (Solo si hay viajes)
    if (cart.tieneItemsViaje) {
      steps.add(Step(
        title: const Text('Manifiesto', style: TextStyle(color: Colors.white, fontSize: 10)),
        content: _buildManifiestoForm(),
        isActive: _currentStep >= steps.length,
      ));
    }

    // Paso 2: Dirección de Envío (Solo si hay productos)
    if (cart.tieneItemsTienda) {
      steps.add(Step(
        title: const Text('Envío', style: TextStyle(color: Colors.white, fontSize: 10)),
        content: _buildEnvioForm(),
        isActive: _currentStep >= steps.length,
      ));
    }

    // Paso Final: Resumen Desglosado
    steps.add(Step(
      title: const Text('Pago', style: TextStyle(color: Colors.white, fontSize: 10)),
      content: _buildResumenPago(cart),
      isActive: _currentStep >= steps.length,
    ));

    return steps;
  }

  List<Widget> _buildSteps(CartProvider cart) {
    List<Widget> widgets = [];
    if (cart.tieneItemsViaje) widgets.add(_buildManifiestoForm());
    if (cart.tieneItemsTienda) widgets.add(_buildEnvioForm());
    widgets.add(_buildResumenPago(cart));
    return widgets;
  }

  Widget _buildManifiestoForm() {
    return PassengerManifestoWidget(
      formKey: _formKeyDojo,
      nombreController: _nombrePasajeroController,
      dniController: _dniPasajeroController,
    );
  }

  Widget _buildEnvioForm() {
    return ShippingAddressWidget(
      formKey: _formKeyEnvio,
      calleController: _calleController,
      alturaController: _alturaController,
      localidadController: _localidadController,
    );
  }

  Widget _buildResumenPago(CartProvider cart) {
    final subtotalViajes = cart.itemsViaje.fold(0.0, (sum, i) => sum + i.subtotal);
    final subtotalTienda = cart.itemsTienda.fold(0.0, (sum, i) => sum + i.subtotal);
    final costoEnvio = cart.tieneItemsTienda ? 450.0 : 0.0;
    final total = subtotalViajes + subtotalTienda + costoEnvio;

    return Column(
      children: [
        _buildResumenRow('SERVICIO DE VIAJE', subtotalViajes),
        if (cart.tieneItemsTienda) ...[
          _buildResumenRow('PRODUCTOS TIENDA', subtotalTienda),
          _buildResumenRow('LOGÍSTICA / ENVÍO', costoEnvio),
        ],
        const Divider(color: Colors.white24, height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('TOTAL A PAGAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            Text('\$${total.toStringAsFixed(2)}', 
              style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 24)),
          ],
        ),
      ],
    );
  }

  Widget _buildResumenRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text('\$${amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
    );
  }

  void _handleContinue(CartProvider cart, int totalSteps) {
    if (_currentStep == totalSteps - 1) {
      _finalizarPago(cart);
      return;
    }

    // Validar paso actual
    bool valid = true;
    if (_currentStep == 0 && cart.tieneItemsViaje) {
      valid = _formKeyDojo.currentState?.validate() ?? false;
    } else if ((_currentStep == 0 && !cart.tieneItemsViaje && cart.tieneItemsTienda) || 
               (_currentStep == 1 && cart.tieneItemsViaje && cart.tieneItemsTienda)) {
      valid = _formKeyEnvio.currentState?.validate() ?? false;
    }

    if (valid) setState(() => _currentStep++);
  }

  Future<void> _finalizarPago(CartProvider cart) async {
    try {
      setState(() => _isProcessing = true);
      
      final userId = SupabaseService.currentUserId;
      if (userId == null) throw Exception('Sesión no válida');

      // 1. Recolectar datos
      final itemsViaje = cart.itemsViaje.map((i) => {
        'producto_id': i.producto.id,
        'subtotal': i.subtotal,
        'capitan_id': 'capitan-id-real', // Aquí vendría del item o cotización vinculada
      }).toList();

      final itemsTienda = cart.itemsTienda.map((i) => {
        'producto_id': i.producto.id,
        'subtotal': i.subtotal,
        'cantidad': i.cantidad,
      }).toList();

      final manifiestos = [{
        'nombre': _nombrePasajeroController.text.trim(),
        'dni': _dniPasajeroController.text.trim(),
        'fecha_declaracion': DateTime.now().toIso8601String(),
      }];

      final datosEnvio = {
        'calle': _calleController.text.trim(),
        'altura': _alturaController.text.trim(),
        'localidad': _localidadController.text.trim(),
        'costo_envio': 450.0,
      };

      final total = cart.totalCarrito + (cart.tieneItemsTienda ? 450.0 : 0.0);

      // 2. Ejecutar Split en DB
      await MasterConnectionSkill.procesarPagoHibrido(
        userId: userId,
        itemsViaje: itemsViaje,
        itemsTienda: itemsTienda,
        datosEnvio: cart.tieneItemsTienda ? datosEnvio : null,
        manifiestos: cart.tieneItemsViaje ? manifiestos : [],
        total: total,
      );

      if (mounted) {
        cart.vaciarCarrito();
        
        // REDIRECCIÓN PREMIUM A CONFIRMACIÓN
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => ViajeConfirmadoScreen(
              datosViaje: {'total': total},
              datosEnvio: cart.tieneItemsTienda ? datosEnvio : null,
              manifiesto: manifiestos,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error en procesamiento: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }
}

// --- WIDGETS ESPECIALIZADOS (Brain & Beauty) ---

class PassengerManifestoWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nombreController;
  final TextEditingController dniController;

  const PassengerManifestoWidget({
    super.key,
    required this.formKey,
    required this.nombreController,
    required this.dniController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('MANIFESTO DE PASAJEROS (DDJJ)', 
            style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildField('NOMBRE Y APELLIDO COMPLETO', nombreController),
          const SizedBox(height: 12),
          _buildField('DNI / PASAPORTE', dniController, keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.security, color: Colors.blueAccent, size: 16),
              SizedBox(width: 8),
              Text('Incluye Seguro de Navegación de Riesgo', style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Al proceder, usted declara bajo juramento la veracidad de estos datos para el despacho oficial.', 
            style: TextStyle(color: Colors.white38, fontSize: 10, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Dato requerido por Prefectura' : null,
    );
  }
}

class ShippingAddressWidget extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController calleController;
  final TextEditingController alturaController;
  final TextEditingController localidadController;

  const ShippingAddressWidget({
    super.key,
    required this.formKey,
    required this.calleController,
    required this.alturaController,
    required this.localidadController,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('LOGÍSTICA TERRESTRE - ENVÍO', 
            style: TextStyle(color: Color(0xFFFF6600), fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildField('CALLE / AVENIDA', calleController),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildField('ALTURA', alturaController, keyboardType: TextInputType.number)),
              const SizedBox(width: 12),
              Expanded(child: _buildField('LOCALIDAD / CIUDAD', localidadController)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.local_shipping, color: Color(0xFFFF6600)),
                SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('COSTO DE ENVÍO', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
                    Text('\$450.00', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: (v) => v == null || v.trim().isEmpty ? 'Dato logístico requerido' : null,
    );
  }
}
