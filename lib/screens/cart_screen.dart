import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import '../services/mercado_pago_service.dart';
import '../widgets/safe_product_image.dart';
import 'checkout_payment_screen.dart';
import 'formulario_pasajeros_screen.dart';
import 'formulario_envio_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  // ─── Estado ────────────────────────────────────────────────────────────────
  String? _avatarUrl;
  bool _isCreatingPreference = false;
  
  // Reserva y Control de Formularios Logísticos
  String? _reservaId;
  bool _pasajerosCompletados = false;
  bool _envioCompletado = false;

  // ─── Envíos ────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _serviciosEnvio = [];
  Map<String, dynamic>? _envioSeleccionado;
  bool _cargandoEnvios = true;

  static const _azul = Color(0xFF001F3F);
  static const _mpAzul = Color(0xFF009EE3);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncReservaIdFromCart();
  }

  void _syncReservaIdFromCart() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.tieneItemsViaje && cart.pedidoViajeId != null) {
      _reservaId = cart.pedidoViajeId;
    } else if (_reservaId == null) {
      _reservaId = const Uuid().v4();
    }
  }

  Future<void> _cargarDatos() async {
    await Future.wait([_cargarAvatar(), _cargarServiciosEnvio()]);
  }

  Future<void> _cargarAvatar() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final data = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url')
            .eq('user_id', user.id)
            .single();
        if (mounted && data['avatar_url'] != null) {
          setState(() => _avatarUrl = data['avatar_url']);
        }
      }
    } catch (_) {}
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

  // ─── Métodos Auxiliares para Formularios ────────────────────────────────────
  Future<void> _abrirFormularioPasajeros(CartProvider cart) async {
    final user = Supabase.instance.client.auth.currentUser;
    String nombre = '';
    String apellido = '';
    String dni = '';

    if (user != null) {
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('nombre, dni')
            .eq('user_id', user.id)
            .maybeSingle();
        if (profile != null) {
          final nombreRaw = profile['nombre']?.toString() ?? '';
          final parts = nombreRaw.trim().split(' ');
          if (parts.length > 1) {
            nombre = parts.sublist(0, parts.length - 1).join(' ');
            apellido = parts.last;
          } else {
            nombre = nombreRaw;
            apellido = '';
          }
          dni = profile['dni']?.toString() ?? '';
        }
      } catch (_) {}
    }

    if (!mounted) return;

    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioPasajerosScreen(
          pedidoId: _reservaId!,
          nombreTitular: nombre,
          apellidoTitular: apellido,
          dniTitular: dni,
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _pasajerosCompletados = true;
      });
    }
  }

  Future<void> _abrirFormularioEnvio(CartProvider cart) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => FormularioEnvioScreen(
          pedidoId: _reservaId!,
          amount: null, // Evitar cobro inmediato desde el formulario
          description: 'Compra de Equipo EL GUIA YA',
          emailPagador: Supabase.instance.client.auth.currentUser?.email ?? '',
        ),
      ),
    );

    if (result == true) {
      setState(() {
        _envioCompletado = true;
      });
    }
  }

  void _desistirViaje(CartProvider cart) {
    final viajes = cart.itemsViaje;
    for (var item in viajes) {
      cart.eliminarDelCarrito(item.producto.id);
    }
    setState(() {
      _pasajerosCompletados = false;
    });
  }

  void _desistirTienda(CartProvider cart) {
    final tienda = cart.itemsTienda;
    for (var item in tienda) {
      cart.eliminarDelCarrito(item.producto.id);
    }
    setState(() {
      _envioCompletado = false;
    });
  }

  // ─── Procesar Pago Real ────────────────────────────────────────────────────
  Future<void> _procesarPago(CartProvider cart) async {
    if (cart.tieneItemsViaje &&
        (cart.pedidoViajeId == null || cart.pedidoViajeId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Aceptá la reserva desde el resumen del viaje antes de pagar.',
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    _syncReservaIdFromCart();

    if (cart.tieneItemsTienda && _envioSeleccionado == null && _serviciosEnvio.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Seleccioná un servicio de envío para continuar.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    setState(() => _isCreatingPreference = true);
    try {
      final emailSilencioso = Supabase.instance.client.auth.currentUser?.email ?? '';
      final totalConEnvio = cart.totalCarrito + (cart.tieneItemsTienda ? _tarifaEnvio : 0.0);

      // Crear preferencia en Mercado Pago
      final preferencia = await MercadoPagoService.crearPreferencia(
        reservaId: _reservaId!,
        titulo: 'Compra EL GUIA YA',
        monto: totalConEnvio,
        emailPagador: emailSilencioso,
      );

      // Vaciar el carrito de forma reactiva
      cart.vaciarCarrito();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CheckoutPaymentScreen(
              amount: totalConEnvio,
              description: 'Compra EL GUIA YA',
              reservaId: _reservaId!,
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

  // ─── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: _buildAppBar(),
      body: cart.items.isEmpty
          ? _buildEmptyState()
          : _buildCheckout(cart),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: _azul,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(
        'Tu Pedido',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      actions: [
        if (_avatarUrl != null)
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage(_avatarUrl!),
            ),
          ),
      ],
    );
  }

  // ─── CARRITO VACÍO ─────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 90, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text('Tu carrito está vacío',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey)),
          const SizedBox(height: 8),
          const Text('Agregá productos desde la tienda.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _azul,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('VOLVER A LA TIENDA',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ─── CHECKOUT PRINCIPAL ────────────────────────────────────────────────────
  Widget _buildCheckout(CartProvider cart) {
    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth > 720;
      if (isDesktop) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildProductList(cart)),
            Expanded(flex: 2, child: _buildResumenPanel(cart)),
          ],
        );
      }
      return Column(
        children: [
          Expanded(child: _buildProductList(cart)),
          _buildResumenPanel(cart),
        ],
      );
    });
  }

  // ─── LISTA DE PRODUCTOS ────────────────────────────────────────────────────
  Widget _buildProductList(CartProvider cart) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cart.items.length,
      itemBuilder: (_, i) => _buildProductCard(cart.items[i], cart),
    );
  }

  Widget _buildProductCard(CartItem item, CartProvider cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SafeProductImage(
              imagenUrl: item.producto.imagenUrl,
              width: 72,
              height: 72,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.producto.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(item.producto.precioFormateado,
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 13)),
                const SizedBox(height: 10),
                // Controles de cantidad
                Row(
                  children: [
                    _buildQtyBtn(Icons.remove,
                        () => cart.decrementarCantidad(item.producto.id)),
                    Container(
                      width: 36,
                      alignment: Alignment.center,
                      child: Text('${item.cantidad}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                    _buildQtyBtn(Icons.add,
                        () => cart.incrementarCantidad(item.producto.id)),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: () => cart.eliminarDelCarrito(item.producto.id),
                icon: const Icon(Icons.close, color: Colors.redAccent, size: 20),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 8),
              Text(item.subtotalFormateado,
                  style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: _azul)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 18, color: _azul),
      ),
    );
  }

  // ─── PANEL RESUMEN + ENVÍO + PAGO ─────────────────────────────────────────
  Widget _buildResumenPanel(CartProvider cart) {
    final totalConEnvio = cart.totalCarrito + (cart.tieneItemsTienda ? _tarifaEnvio : 0.0);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20)],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Pago seguro con MP ──────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _mpAzul.withOpacity(0.25)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline, color: _mpAzul, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Pago seguro con ',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _azul)),
                              const Text('mercado',
                                  style: TextStyle(
                                      color: _mpAzul,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13)),
                              const Text('pago',
                                  style: TextStyle(
                                      color: _azul,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Ingresás los datos de tu tarjeta directamente en la plataforma de Mercado Pago. Nosotros nunca los vemos.',
                            style: TextStyle(fontSize: 10, color: Colors.grey, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              // Logos de tarjetas
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const FaIcon(FontAwesomeIcons.ccVisa,
                      color: Color(0xFF1A1F71), size: 28),
                  const SizedBox(width: 12),
                  const FaIcon(FontAwesomeIcons.ccMastercard,
                      color: Color(0xFFFF5F00), size: 28),
                  const SizedBox(width: 12),
                  const FaIcon(FontAwesomeIcons.ccAmex,
                      color: Color(0xFF2E77BC), size: 28),
                  const SizedBox(width: 12),
                  FaIcon(FontAwesomeIcons.creditCard,
                      color: Colors.grey.shade400, size: 24),
                ],
              ),
              const SizedBox(height: 20),

              // ── Selector de Envío (Solo si lleva productos de la tienda) ──
              if (cart.tieneItemsTienda) ...[
                const Text('Servicio de Envío',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.grey)),
                const SizedBox(height: 10),
                if (_cargandoEnvios)
                  const Center(
                      child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: _mpAzul),
                  ))
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
                        Icon(Icons.warning_amber_outlined,
                            color: Colors.orange, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sin servicios de envío activos. Configuralos desde el Panel Admin.',
                            style: TextStyle(color: Colors.orange, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...(_serviciosEnvio.map((s) {
                    final sel = _envioSeleccionado?['id'] == s['id'];
                    final tarifa = (s['tarifa'] as num?)?.toDouble() ?? 0;
                    return GestureDetector(
                      onTap: () => setState(() => _envioSeleccionado = s),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel
                              ? const Color(0xFFE8F5FF)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? _mpAzul : Colors.grey.shade200,
                            width: sel ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              sel
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              color: sel ? _mpAzul : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.local_shipping_outlined,
                                size: 18, color: Colors.grey),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s['nombre_servicio']?.toString() ?? '',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: sel ? _azul : Colors.black87)),
                                  if ((s['descripcion']?.toString() ?? '')
                                      .isNotEmpty)
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
                                      : _azul),
                            ),
                          ],
                        ),
                      ),
                    );
                  })).toList(),
              ],

              // ── Requisitos Logísticos Checklist ──────────────────────────
              _buildChecklistLogistica(cart),

              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 10),

              // ── Desglose de totales ─────────────────────────────────────
              _buildTotalRow('Subtotal',
                  '\$ ${cart.totalCarrito.toStringAsFixed(0)}',
                  bold: false),
              const SizedBox(height: 6),
              if (cart.tieneItemsTienda)
                _buildTotalRow(
                  'Envío (${_envioSeleccionado?['nombre_servicio'] ?? '-'})',
                  _tarifaEnvio == 0
                      ? 'GRATIS'
                      : '\$ ${_tarifaEnvio.toStringAsFixed(0)}',
                  bold: false,
                  valueColor:
                      _tarifaEnvio == 0 ? Colors.green : Colors.black87,
                ),
              const SizedBox(height: 10),
              _buildTotalRow(
                'TOTAL',
                '\$ ${totalConEnvio.toStringAsFixed(0)}',
                bold: true,
                fontSize: 22,
                valueColor: _azul,
              ),

              const SizedBox(height: 22),

              // ── Botón Principal Dinámico de Pago / Completado ──────────────────
              _buildBotonPagoDinamico(cart, totalConEnvio),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistLogistica(CartProvider cart) {
    if (!cart.tieneItemsViaje && !cart.tieneItemsTienda) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Requisitos Logísticos',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: _azul,
          ),
        ),
        const SizedBox(height: 8),
        if (cart.tieneItemsViaje) _buildChecklistItem(
          icon: _pasajerosCompletados ? Icons.check_circle : Icons.info_outline,
          iconColor: _pasajerosCompletados ? Colors.green : Colors.orange,
          titulo: 'Declaración Jurada de Pasajeros',
          subtitulo: _pasajerosCompletados ? 'Datos registrados' : 'Pendiente de registrar acompañantes',
          btnText: _pasajerosCompletados ? 'Editar' : 'Completar',
          onTapBtn: () => _abrirFormularioPasajeros(cart),
          onTapDesistir: () => _desistirViaje(cart),
          desistirLabel: 'Desistir de Viaje',
        ),
        if (cart.tieneItemsViaje && cart.tieneItemsTienda) const SizedBox(height: 8),
        if (cart.tieneItemsTienda) _buildChecklistItem(
          icon: _envioCompletado ? Icons.check_circle : Icons.info_outline,
          iconColor: _envioCompletado ? Colors.green : Colors.orange,
          titulo: 'Dirección de Envío',
          subtitulo: _envioCompletado ? 'Dirección registrada' : 'Requerido para el despacho de productos',
          btnText: _envioCompletado ? 'Editar' : 'Completar',
          onTapBtn: () => _abrirFormularioEnvio(cart),
          onTapDesistir: () => _desistirTienda(cart),
          desistirLabel: 'Desistir de Compra',
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildChecklistItem({
    required IconData icon,
    required Color iconColor,
    required String titulo,
    required String subtitulo,
    required String btnText,
    required VoidCallback onTapBtn,
    required VoidCallback onTapDesistir,
    required String desistirLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _azul),
                    ),
                    Text(
                      subtitulo,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: onTapBtn,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azul,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(btnText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onTapDesistir,
                icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                label: Text(
                  desistirLabel,
                  style: const TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPagoDinamico(CartProvider cart, double totalConEnvio) {
    final necesitaPasajeros = cart.tieneItemsViaje && !_pasajerosCompletados;
    final necesitaEnvio = cart.tieneItemsTienda && !_envioCompletado;
    final tienePendientes = necesitaPasajeros || necesitaEnvio;

    String text;
    IconData icon;
    Color color;
    VoidCallback action;

    if (tienePendientes) {
      text = 'PROCESO DE PAGO';
      icon = Icons.assignment_outlined;
      color = const Color(0xFF0D47A1); // Deep blue
      action = () {
        if (necesitaPasajeros) {
          _abrirFormularioPasajeros(cart);
        } else if (necesitaEnvio) {
          _abrirFormularioEnvio(cart);
        }
      };
    } else {
      text = 'PAGAR CON MERCADO PAGO  \$ ${totalConEnvio.toStringAsFixed(0)}';
      icon = Icons.payment_outlined;
      color = _mpAzul;
      action = () => _procesarPago(cart);
    }

    return SizedBox(
      width: double.infinity,
      height: 62,
      child: ElevatedButton(
        onPressed: _isCreatingPreference ? null : action,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          disabledBackgroundColor: Colors.grey.shade300,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          elevation: 6,
        ),
        child: _isCreatingPreference
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  ),
                  SizedBox(width: 14),
                  Text('CONECTANDO...',
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: 1)),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                        letterSpacing: 0.5),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    String value, {
    bool bold = false,
    double fontSize = 14,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                color: bold ? _azul : Colors.grey,
                fontWeight: bold ? FontWeight.w900 : FontWeight.normal,
                fontSize: bold ? 16 : 13)),
        Text(value,
            style: TextStyle(
                color: valueColor ?? Colors.black87,
                fontWeight: bold ? FontWeight.w900 : FontWeight.w600,
                fontSize: fontSize)),
      ],
    );
  }
}
