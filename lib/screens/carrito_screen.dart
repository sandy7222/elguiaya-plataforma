import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import '../services/branding_service.dart';
import '../services/mercado_pago_service.dart';
import '../widgets/safe_product_image.dart';
import 'checkout_payment_screen.dart';

class CarritoScreen extends StatefulWidget {
  const CarritoScreen({super.key});

  @override
  State<CarritoScreen> createState() => _CarritoScreenState();
}

class _CarritoScreenState extends State<CarritoScreen> {
  bool _isCreatingPreference = false;

  // ─── Envíos ───────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _serviciosEnvio = [];
  Map<String, dynamic>? _envioSeleccionado;
  bool _cargandoEnvios = true;

  @override
  void initState() {
    super.initState();
    _cargarServiciosEnvio();
  }

  Future<void> _cargarServiciosEnvio() async {
    try {
      final data = await Supabase.instance.client
          .from('envios_tarifas')
          .select()
          .eq('activo', true)
          .order('tarifa');
      if (mounted) {
        setState(() {
          _serviciosEnvio = List<Map<String, dynamic>>.from(data);
          // Pre-seleccionar el más barato
          if (_serviciosEnvio.isNotEmpty) _envioSeleccionado = _serviciosEnvio.first;
          _cargandoEnvios = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoEnvios = false);
    }
  }

  double get _tarifaEnvio =>
      (_envioSeleccionado?['tarifa'] as num?)?.toDouble() ?? 0;

  // ─── Pago ─────────────────────────────────────────────────────────────────
  Future<void> _procesarPago(CartProvider cart) async {
    if (_envioSeleccionado == null && _serviciosEnvio.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Por favor seleccioná un servicio de envío.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    setState(() => _isCreatingPreference = true);

    try {
      final reservaId = 'reserva_${DateTime.now().millisecondsSinceEpoch}';
      final emailSilencioso =
          Supabase.instance.client.auth.currentUser?.email ?? '';
      final totalConEnvio = cart.totalCarrito + _tarifaEnvio;

      final preferencia = await MercadoPagoService.crearPreferencia(
        reservaId: reservaId,
        titulo: 'Compra EL GUIA YA',
        monto: totalConEnvio,
        emailPagador: emailSilencioso,
      );

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutPaymentScreen(
              amount: totalConEnvio,
              description: 'Compra EL GUIA YA',
              reservaId: reservaId,
              emailPagador: emailSilencioso,
              initPoint: preferencia.linkPago,
              preferenceId: preferencia.preferenceId,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al conectar con Mercado Pago: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCreatingPreference = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        title: Image.asset(
          'assets/images/logo_elguiaya.png', 
          height: 40, 
          fit: BoxFit.contain,
          errorBuilder: (c, e, s) => const Text('MI CANASTO', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: cart.items.isEmpty 
          ? _buildEmptyState(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: cart.items.length,
                    itemBuilder: (context, index) {
                      final item = cart.items[index];
                      return _buildCartItem(item, cart);
                    },
                  ),
                ),
                _buildTotalSection(cart, context),
              ],
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 100, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text('Tu red está vacía', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1)),
            child: const Text('VOLVER A LA TIENDA', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItem item, CartProvider cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SafeProductImage(
              imagenUrl: item.producto.imagenUrl,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.producto.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(item.producto.precioFormateado, style: const TextStyle(color: Color(0xFF00C853), fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildQtyBtn(Icons.remove, () => cart.decrementarCantidad(item.producto.id)),
                    const SizedBox(width: 15),
                    Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(width: 15),
                    _buildQtyBtn(Icons.add, () => cart.incrementarCantidad(item.producto.id)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => cart.eliminarDelCarrito(item.producto.id),
              ),
              const SizedBox(height: 10),
              Text(item.subtotalFormateado, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF0D47A1))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildTotalSection(CartProvider cart, BuildContext context) {
    final totalConEnvio = cart.totalCarrito + _tarifaEnvio;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Selector de Envío ──────────────────────────────────────────
            const Text('Servicio de Envío',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey)),
            const SizedBox(height: 10),
            if (_cargandoEnvios)
              const Center(
                  child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0D47A1))))
            else if (_serviciosEnvio.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Sin servicios de envío activos.',
                          style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ),
                  ],
                ),
              )
            else
              ...(_serviciosEnvio.map((s) {
                final seleccionado = _envioSeleccionado?['id'] == s['id'];
                final tarifa = (s['tarifa'] as num?)?.toDouble() ?? 0;
                return GestureDetector(
                  onTap: () => setState(() => _envioSeleccionado = s),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: seleccionado
                          ? const Color(0xFFE8F5FF)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: seleccionado
                            ? const Color(0xFF009EE3)
                            : Colors.grey.shade200,
                        width: seleccionado ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          seleccionado
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: seleccionado
                              ? const Color(0xFF009EE3)
                              : Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.local_shipping_outlined,
                            size: 18,
                            color: seleccionado
                                ? const Color(0xFF009EE3)
                                : Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s['nombre_servicio']?.toString() ?? '',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: seleccionado
                                          ? const Color(0xFF001F3F)
                                          : Colors.black87)),
                              if ((s['descripcion']?.toString() ?? '').isNotEmpty)
                                Text(s['descripcion'].toString(),
                                    style: const TextStyle(
                                        fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        Text(
                          tarifa == 0
                              ? 'GRATIS'
                              : '\$ ${tarifa.toStringAsFixed(0)}',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: tarifa == 0
                                  ? Colors.green
                                  : const Color(0xFF0D47A1)),
                        ),
                      ],
                    ),
                  ),
                );
              })).toList(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // ── Resumen de totales ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Subtotal',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text('\$ ${cart.totalCarrito.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Envío (${_envioSeleccionado?['nombre_servicio'] ?? '-'})',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                Text(
                  _tarifaEnvio == 0
                      ? 'GRATIS'
                      : '\$ ${_tarifaEnvio.toStringAsFixed(0)}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: _tarifaEnvio == 0
                          ? Colors.green
                          : Colors.black87),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('TOTAL',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        color: Color(0xFF001F3F))),
                Text(
                  '\$ ${totalConEnvio.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 26,
                      color: Color(0xFF0D47A1)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // ── Botón MP ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed:
                    _isCreatingPreference ? null : () => _procesarPago(cart),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009EE3),
                  disabledBackgroundColor: Colors.grey.shade400,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                ),
                child: _isCreatingPreference
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5)),
                          SizedBox(width: 14),
                          Text('CONECTANDO CON MP...',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  letterSpacing: 1)),
                        ],
                      )
                    : const Text('PAGAR CON MERCADO PAGO',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 17,
                            letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
