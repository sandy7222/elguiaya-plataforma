import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import '../services/branding_service.dart';
import 'dart:ui';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  int _currentStep = 0;
  bool _isProcessing = false;

  // Controllers para Envío Pro
  final _nombreEnvioController = TextEditingController();
  final _direccionController = TextEditingController();
  final _notasEnvioController = TextEditingController();
  final _cpController = TextEditingController();
  double _costoEnvio = 0.0;

  // Estado de Tripulantes
  final List<Map<String, dynamic>> _tripulantes = [];

  // Colores Pro 2026
  static const Color _capitanBlue = Color(0xFF0D47A1);
  static const Color _vibrantGreen = Color(0xFF00E676);
  static const Color _deepOcean = Color(0xFF001F3F);

  @override
  void initState() {
    super.initState();
    _cpController.addListener(_calcularEnvio);
    _tripulantes.add({'nombre': '', 'dni': '', 'foto': null});
  }

  @override
  void dispose() {
    _nombreEnvioController.dispose();
    _direccionController.dispose();
    _notasEnvioController.dispose();
    _cpController.dispose();
    super.dispose();
  }

  void _calcularEnvio() {
    if (_cpController.text.length >= 4) {
      setState(() {
        int cp = int.tryParse(_cpController.text) ?? 0;
        if (cp < 2000) {
          _costoEnvio = 4500.0;
        } else if (cp < 5000) _costoEnvio = 6800.0;
        else _costoEnvio = 8200.0;
      });
    }
  }

  bool get _requiereEnvio => context.read<CartProvider>().tieneItemsTienda;
  bool get _requiereManifiesto => context.read<CartProvider>().tieneItemsViaje;

  bool get _pasoEnvioValido {
    if (!_requiereEnvio) return true;
    return _nombreEnvioController.text.isNotEmpty &&
           _direccionController.text.isNotEmpty &&
           _cpController.text.isNotEmpty;
  }

  bool get _pasoManifiestoValido {
    if (!_requiereManifiesto) return true;
    return _tripulantes.every((t) => t['nombre'].isNotEmpty && t['dni'].isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    List<Step> steps = _buildSteps(cart);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Image.network(
          BrandingService.defaultLogoUrl, 
          height: 35, 
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => const Text('CHECKOUT PRO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        ),
        backgroundColor: _deepOcean,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildSmartProgress(steps.length),
          Expanded(
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(primary: _capitanBlue),
              ),
              child: Stepper(
                type: StepperType.horizontal,
                currentStep: _currentStep,
                elevation: 0,
                onStepContinue: () => _handleSmartContinue(steps.length),
                onStepCancel: () => _currentStep > 0 ? setState(() => _currentStep--) : Navigator.pop(context),
                controlsBuilder: (context, details) => _buildSmartControls(details, steps.length),
                steps: steps,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Step> _buildSteps(CartProvider cart) {
    List<Step> steps = [];
    
    steps.add(Step(
      title: const Icon(Icons.shopping_cart_outlined, size: 18),
      content: _buildResumenStep(cart),
      isActive: _currentStep >= 0,
      state: _currentStep > 0 ? StepState.complete : StepState.indexed,
    ));

    if (_requiereEnvio) {
      steps.add(Step(
        title: const Icon(Icons.local_shipping_outlined, size: 18),
        content: _buildEnvioStepPro(),
        isActive: _currentStep >= steps.length,
        state: _currentStep > steps.length ? StepState.complete : StepState.indexed,
      ));
    }

    if (_requiereManifiesto) {
      steps.add(Step(
        title: const Icon(Icons.anchor_outlined, size: 18),
        content: _buildManifiestoStepPro(),
        isActive: _currentStep >= steps.length,
        state: _currentStep > steps.length ? StepState.complete : StepState.indexed,
      ));
    }

    steps.add(Step(
      title: const Icon(Icons.payment_outlined, size: 18),
      content: _buildPagoStep(cart),
      isActive: _currentStep == steps.length,
    ));

    return steps;
  }

  Widget _buildResumenStep(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('TU SELECCIÓN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _deepOcean)),
        const SizedBox(height: 16),
        ...cart.items.map((item) => _buildCartItemTile(item)),
        const Divider(height: 40),
        _buildSummaryRow('Subtotal Items', cart.totalFormateado),
        if (_requiereEnvio)
          _buildSummaryRow('Envío (Estimado CP)', '\$ ${_costoEnvio.toStringAsFixed(0)}', isPromo: _costoEnvio == 0),
      ],
    );
  }

  Widget _buildEnvioStepPro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ESTACIÓN LOGÍSTICA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _deepOcean)),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildTextField(_cpController, 'Código Postal', Icons.local_post_office_rounded)),
            const SizedBox(width: 12),
            _buildCostDisplay(),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(_nombreEnvioController, 'Nombre del receptor', Icons.person),
        const SizedBox(height: 12),
        _buildTextField(_direccionController, 'Calle y Altura', Icons.location_on),
        const SizedBox(height: 12),
        _buildTextField(_notasEnvioController, 'Referencia (Ej: Portón blanco)', Icons.visibility, maxLines: 2),
      ],
    );
  }

  Widget _buildManifiestoStepPro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ESTACIÓN DE SEGURIDAD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: _deepOcean)),
        const SizedBox(height: 12),
        _buildCriticalBanner(),
        const SizedBox(height: 24),
        ...List.generate(_tripulantes.length, (index) => _buildTripulanteCard(index)),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () => setState(() => _tripulantes.add({'nombre': '', 'dni': '', 'foto': null})),
          icon: const Icon(Icons.person_add_alt_1),
          label: const Text('AÑADIR ACOMPAÑANTE'),
        ),
      ],
    );
  }

  Widget _buildPagoStep(CartProvider cart) {
    double totalFinal = cart.totalCarrito + _costoEnvio;
    return Column(
      children: [
        const Icon(Icons.verified_user_rounded, color: _vibrantGreen, size: 60),
        const SizedBox(height: 16),
        const Text('LISTO PARA ZARPAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: _deepOcean, borderRadius: BorderRadius.circular(20)),
          child: Column(
            children: [
              _buildFinalRow('SUBTOTAL', cart.totalFormateado),
              if (_costoEnvio > 0) _buildFinalRow('ENVÍO', '\$ ${_costoEnvio.toStringAsFixed(0)}'),
              const Divider(color: Colors.white24),
              _buildFinalRow('TOTAL FINAL', '\$ ${totalFinal.toStringAsFixed(2)}', isTotal: true),
            ],
          ),
        ),
      ],
    );
  }

  // WIDGETS DE APOYO
  Widget _buildSmartProgress(int totalSteps) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      color: _deepOcean,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalSteps, (index) {
          bool isCurrent = index == _currentStep;
          bool isPast = index < _currentStep;
          return Row(
            children: [
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: isPast ? _vibrantGreen : (isCurrent ? Colors.white : Colors.white24),
                  shape: BoxShape.circle,
                ),
                child: Center(child: Text('${index + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isCurrent ? _deepOcean : Colors.white))),
              ),
              if (index < totalSteps - 1) Container(width: 30, height: 1, color: isPast ? _vibrantGreen : Colors.white24),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildTripulanteCard(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          Row(
            children: [
              Text('${index + 1}.', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(child: TextField(
                onChanged: (v) => _tripulantes[index]['nombre'] = v,
                decoration: const InputDecoration(hintText: 'Nombre Completo', border: InputBorder.none, isDense: true),
              )),
              if (index > 0) IconButton(onPressed: () => setState(() => _tripulantes.removeAt(index)), icon: const Icon(Icons.close, size: 18)),
            ],
          ),
          const Divider(height: 8),
          TextField(
            onChanged: (v) => _tripulantes[index]['dni'] = v,
            decoration: const InputDecoration(hintText: 'Documento (DNI)', border: InputBorder.none, isDense: true),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: const Text(
        'ATENCIÓN: Los productos se envían a domicilio. No se entregan en el punto de encuentro.',
        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildCostDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: _vibrantGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          const Text('COSTO ENVÍO', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
          Text('\$ ${_costoEnvio.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, color: _vibrantGreen)),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: _capitanBlue),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        isDense: true,
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isPromo = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: isPromo ? _vibrantGreen : Colors.black, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFinalRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isTotal ? Colors.white : Colors.white70, fontWeight: isTotal ? FontWeight.w900 : FontWeight.normal)),
          Text(value, style: TextStyle(color: isTotal ? _vibrantGreen : Colors.white, fontSize: isTotal ? 20 : 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildCartItemTile(CartItem item) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(item.producto.imagenUrl, width: 40, height: 40, fit: BoxFit.cover),
      ),
      title: Text(item.producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
      trailing: Text(item.subtotalFormateado, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildSmartControls(ControlsDetails details, int totalSteps) {
    bool isLast = _currentStep == totalSteps - 1;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(child: OutlinedButton(onPressed: details.onStepCancel, child: const Text('VOLVER'))),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: details.onStepContinue,
              style: ElevatedButton.styleFrom(backgroundColor: isLast ? _vibrantGreen : _capitanBlue, foregroundColor: Colors.white),
              child: Text(isLast ? 'PAGAR AHORA' : 'CONTINUAR'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSmartContinue(int totalSteps) {
    bool pasoValido = true;
    // La lógica de navegación dinámica ajusta los índices:
    // Paso 0: Resumen, Paso 1: Logística (si aplica), Paso 2: Embarque (si aplica), etc.
    if (_currentStep == 1 && _requiereEnvio) pasoValido = _pasoEnvioValido;
    // Si requiere ambos, el paso de manifiesto sería el 2.
    if (_requiereEnvio && _requiereManifiesto && _currentStep == 2) pasoValido = _pasoManifiestoValido;
    if (!_requiereEnvio && _requiereManifiesto && _currentStep == 1) pasoValido = _pasoManifiestoValido;

    if (pasoValido) {
      if (_currentStep < totalSteps - 1) {
        setState(() => _currentStep++);
      } else {
        _finalizarPedidoPro();
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa los campos obligatorios.')));
    }
  }

  Future<void> _finalizarPedidoPro() async {
    setState(() => _isProcessing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      _mostrarExito();
      context.read<CartProvider>().vaciarCarrito();
    }
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: _vibrantGreen, size: 60),
              const SizedBox(height: 16),
              const Text('¡PEDIDO EXITOSO!', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('VOLVER')),
            ],
          ),
        ),
      ),
    );
  }
}
