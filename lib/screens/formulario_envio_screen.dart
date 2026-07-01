import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/mercado_pago_service.dart';
import '../providers/cart_provider.dart';
import 'checkout_payment_screen.dart';
import '../widgets/safe_button.dart';

/// Formulario de Envío a Domicilio.
/// Captura los datos logísticos de entrega y exige la aceptación obligatoria
/// del aviso legal de entrega fallida por ausencia.
class FormularioEnvioScreen extends StatefulWidget {
  final String pedidoId;
  final double? amount;
  final String? description;
  final String? emailPagador;

  const FormularioEnvioScreen({
    super.key,
    required this.pedidoId,
    this.amount,
    this.description,
    this.emailPagador,
  });

  @override
  State<FormularioEnvioScreen> createState() => _FormularioEnvioScreenState();
}

class _FormularioEnvioScreenState extends State<FormularioEnvioScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  bool _guardando = false;

  // Controllers
  final _nombreReceptorController = TextEditingController();
  final _telefonoReceptorController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _pisoDeptoController = TextEditingController();
  final _barrioController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _codigoPostalController = TextEditingController();
  final _instruccionesController = TextEditingController();

  bool _aceptaAvisoAusencia = false;

  static const _azul = Color(0xFF001F3F);
  static const _naranja = Color(0xFFFF6600);

  @override
  void dispose() {
    _nombreReceptorController.dispose();
    _telefonoReceptorController.dispose();
    _calleController.dispose();
    _numeroController.dispose();
    _pisoDeptoController.dispose();
    _barrioController.dispose();
    _ciudadController.dispose();
    _provinciaController.dispose();
    _codigoPostalController.dispose();
    _instruccionesController.dispose();
    super.dispose();
  }

  // --- Guardar en Supabase ---------------------------------------------------
  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_aceptaAvisoAusencia) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Debes aceptar la declaración de ausencia del correo.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    setState(() => _guardando = true);

    try {
      final user = _supabase.auth.currentUser;
      final userId = user?.id ?? '00000000-0000-0000-0000-000000000000';

      // Insertar en la tabla envio_domicilio
      await _supabase.from('envio_domicilio').upsert({
        'pedido_id': widget.pedidoId, 
        'usuario_id': userId,
        'nombre_receptor': _nombreReceptorController.text.trim(),
        'telefono_receptor': _telefonoReceptorController.text.trim(),
        'calle': _calleController.text.trim(),
        'numero': _numeroController.text.trim(),
        'piso_depto': _pisoDeptoController.text.trim().isEmpty ? null : _pisoDeptoController.text.trim(),
        'barrio': _barrioController.text.trim().isEmpty ? null : _barrioController.text.trim(),
        'ciudad': _ciudadController.text.trim(),
        'provincia': _provinciaController.text.trim(),
        'codigo_postal': _codigoPostalController.text.trim(),
        'instrucciones': _instruccionesController.text.trim().isEmpty ? null : _instruccionesController.text.trim(),
        'acepta_aviso_ausencia': _aceptaAvisoAusencia,
      });

      if (mounted) {
        if (widget.amount != null) {
          // --- PROCEDER DIRECTAMENTE A MERCADO PAGO DESDE EL FORMULARIO ---
          final preferencia = await MercadoPagoService.crearPreferencia(
            reservaId: widget.pedidoId,
            titulo: widget.description ?? 'Compra de Equipo EL GUIA YA',
            monto: widget.amount!,
            emailPagador: widget.emailPagador ?? '',
          );

          // Lanzar la URL de pago
          final uri = Uri.parse(preferencia.linkPago);
          if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            throw Exception('No se pudo abrir el navegador seguro de Mercado Pago.');
          }

          // Vaciar el carrito de forma reactiva para dejar la tienda lista
          if (mounted) {
            Provider.of<CartProvider>(context, listen: false).vaciarCarrito();
          }

          // Reemplazar la pantalla del formulario por la de espera y confirmación (imperceptible)
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CheckoutPaymentScreen(
                  amount: widget.amount!,
                  description: widget.description ?? 'Compra de Equipo EL GUIA YA',
                  reservaId: widget.pedidoId,
                  emailPagador: widget.emailPagador ?? '',
                  initPoint: preferencia.linkPago,
                  preferenceId: preferencia.preferenceId,
                ),
              ),
            );
          }
        } else {
          // Flujo estándar simple de guardado
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dirección de envío guardada correctamente'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true); // true = guardado exitoso
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Dirección de Envío',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2)),
            )
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // Banner Informativo (Modernizado)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping, color: _naranja, size: 24),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ENVÍO DIRECTO A DOMICILIO',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: _azul,
                                letterSpacing: 1),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tus compras serán despachadas a tu dirección postal por correo postal de forma segura.',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade700, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 👤 SECCIÓN 1: RECEPTOR DE LA COMPRA (Diseñado como Tarjeta Premium)
              _buildSectionCard(
                title: 'RECEPTOR DE LA COMPRA',
                icon: Icons.person_pin_rounded,
                children: [
                  _buildField(
                    controller: _nombreReceptorController,
                    label: 'Nombre y Apellido de quien recibe',
                    icon: Icons.person,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa el nombre del receptor' : null,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _telefonoReceptorController,
                    label: 'Teléfono de contacto',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa un teléfono de contacto' : null,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 📍 SECCIÓN 2: DIRECCIÓN DE DESPACHO
              _buildSectionCard(
                title: 'DIRECCIÓN DE DESPACHO',
                icon: Icons.home_work_rounded,
                children: [
                  // ⚠️ Advertencia logística sobre entregas terrestres
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 24),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'ATENCIÓN: Por cuestiones logísticas, NO se puede colocar como dirección de envío el punto de encuentro con el capitán. La entrega de los productos de la tienda se realiza de forma terrestre tradicional por una empresa de transporte externa.',
                            style: TextStyle(
                              color: Color(0xFF7F5F00),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildField(
                    controller: _calleController,
                    label: 'Calle / Avenida',
                    icon: Icons.location_on,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa la calle' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: _buildField(
                          controller: _numeroController,
                          label: 'Número',
                          prefixWidget: Container(
                            width: 48,
                            alignment: Alignment.center,
                            child: Text('Nº', style: TextStyle(color: _azul, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: _buildField(
                          controller: _pisoDeptoController,
                          label: 'Piso / Dpto (Opcional)',
                          icon: Icons.apartment,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _barrioController,
                    label: 'Barrio / Zona (Opcional)',
                    icon: Icons.map,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: _buildField(
                          controller: _ciudadController,
                          label: 'Ciudad / Localidad',
                          icon: Icons.location_city,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Ciudad requerida' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: _buildField(
                          controller: _codigoPostalController,
                          label: 'Cód. Postal',
                          icon: Icons.markunread_mailbox,
                          validator: (v) => v == null || v.trim().isEmpty ? 'C.P. requerido' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _provinciaController,
                    label: 'Provincia',
                    icon: Icons.explore,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Ingresa la provincia' : null,
                  ),
                  const SizedBox(height: 12),
                  
                  _buildField(
                    controller: _instruccionesController,
                    label: 'Referencias del Domicilio (Ej: Portón blanco, timbre roto - Opcional)',
                    icon: Icons.comment_bank_outlined,
                    maxLines: 2,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // --- AVISO LEGAL OBLIGATORIO -------------------------------------
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'POLÍTICA DE ENTREGA LOGÍSTICA',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.blue.shade900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    CheckboxListTile(
                      value: _aceptaAvisoAusencia,
                      onChanged: (v) => setState(() => _aceptaAvisoAusencia = v ?? false),
                      activeColor: Colors.blue,
                      checkColor: Colors.white,
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Acepto que si el correo realiza la visita y no encuentra a nadie en el domicilio, deberá retirar el pedido en la sucursal de correo correspondiente.',
                        style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Botón Guardar Flotante
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton(
                  onPressed: _guardando ? null : _guardar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.amount != null ? const Color(0xFF009EE3) : _azul,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 6,
                  ),
                  child: SafeButtonLoadingContent(
                    loading: _guardando,
                    icon: widget.amount != null ? Icons.payment : Icons.check_circle_outline,
                    idleLabel: widget.amount != null
                        ? 'Pagar \$${widget.amount!.toStringAsFixed(0)} con Mercado Pago'
                        : 'Confirmar dirección',
                    loadingLabel: widget.amount != null
                        ? 'Conectando con Mercado Pago...'
                        : 'Guardando despacho...',
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5, color: Colors.white),
                    spinnerColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // Tarjeta de sección premium
  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header de la Tarjeta
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _azul,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          // Contenido de la Tarjeta
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    Widget? prefixWidget,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        prefixIcon: prefixWidget ?? (icon != null ? Icon(icon, color: _azul, size: 18) : null),
        filled: true,
        fillColor: const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _azul, width: 2),
        ),
      ),
    );
  }
}
