import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/mercado_pago_service.dart';
import '../services/guia_copilot_brain.dart';
import '../services/copilot_channel.dart';
import '../services/viaje_lifecycle_service.dart';
import 'ficha_contractual_screen.dart';
import 'ficha_pescador_screen.dart';

/// Pantalla de pago real con Mercado Pago Checkout Pro.
/// Flujo:
///   1. Crea preferencia → abre init_point en browser externo.
///   2. Usuario vuelve → busca el pago en API de MP por external_reference.
///   3. Actualiza tabla 'reservas' en Supabase con el estado real.
///   4. Muestra pantalla de resultado + bloquea datos.
class CheckoutPaymentScreen extends StatefulWidget {
  final double amount;
  final String description;
  final String reservaId;   // ID en Supabase = external_reference en MP
  final String emailPagador;
  final String? preferenceId;
  final String? initPoint;
  final String? dniPagador;

  const CheckoutPaymentScreen({
    super.key,
    required this.amount,
    required this.description,
    required this.reservaId,
    this.emailPagador = '',
    this.preferenceId,
    this.initPoint,
    this.dniPagador,
  });

  @override
  State<CheckoutPaymentScreen> createState() => _CheckoutPaymentScreenState();
}

class _CheckoutPaymentScreenState extends State<CheckoutPaymentScreen> {
  bool _isProcessing = false;
  _Pantalla _pantalla = _Pantalla.inicial;
  String? _errorMessage;
  EstadoPagoMP? _pagoConfirmado;
  /// Visible en debug o mientras Mercado Pago esté en sandbox (etapa de evaluación).
  bool _mostrarSimulador = kDebugMode;

  // ── Polling automático ───────────────────────────────────────────────────
  Timer? _pollingTimer;
  int _pollingSegundos = 10; // cuenta regresiva visual
  static const int _intervaloSegundos = 10;
  static const int _maxIntentos = 18; // máx 3 minutos (18 x 10s)
  int _intentosPoll = 0;

  @override
  void initState() {
    super.initState();

    GuiaCopilotBrain.instance.pantallaCargada(
      ScreenContext.pago,
      datosLocales: {'amount': widget.amount, 'reservaId': widget.reservaId},
    );
    GuiaCopilotBrain.instance.iniciarAccion(AppAction.pagando);

    CopilotChannel.registrar('pago', (payload) {
      if (payload['accion'] == 'solicitar_confirmacion_pago') {
        _iniciarPago();
      }
    });

    // En modo prueba (debug) NO abrimos Mercado Pago automáticamente:
    // mostramos la pantalla inicial para que el tester pueda usar
    // el botón "SIMULAR PAGO". En producción, comportamiento normal.
    if (!kDebugMode && widget.initPoint != null && widget.initPoint!.isNotEmpty) {
      _pantalla = _Pantalla.esperando;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _lanzarUrlPago(widget.initPoint!);
        _iniciarPolling(); // arrancar polling automático
      });
    }

    _resolverVisibilidadSimulador();
  }

  /// En evaluación: simulador disponible si MP está en sandbox o en build debug.
  /// Al pasar MP a producción (is_sandbox = false), se oculta automáticamente.
  Future<void> _resolverVisibilidadSimulador() async {
    try {
      await MercadoPagoService.cargarCredenciales();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _mostrarSimulador = kDebugMode || MercadoPagoService.isSandbox;
    });
  }

  @override
  void dispose() {
    CopilotChannel.desregistrar('pago');
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ── Polling automático cada 10 segundos ──────────────────────────────────
  void _iniciarPolling() {
    _pollingTimer?.cancel();
    _intentosPoll = 0;
    _pollingSegundos = _intervaloSegundos;

    // Cuenta regresiva cada segundo
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) { timer.cancel(); return; }

      setState(() => _pollingSegundos--);

      if (_pollingSegundos <= 0) {
        // Resetear cuenta regresiva
        setState(() => _pollingSegundos = _intervaloSegundos);
        _intentosPoll++;

        // Parar si superamos el máximo de intentos
        if (_intentosPoll > _maxIntentos) {
          timer.cancel();
          setState(() => _errorMessage =
              'No detectamos tu pago automáticamente. Tocá "Verificar" si ya pagaste.');
          return;
        }

        // Verificar con MP en segundo plano (sin spinner de pantalla completa)
        try {
          final pago = await MercadoPagoService.buscarPagoPorReferencia(widget.reservaId);
          if (pago != null && mounted) {
            final estadoMP = MercadoPagoService.parsearEstado(pago.status);
            if (estadoMP != EstadoReservaMP.pendiente) {
              // Pago resuelto: actualizar y salir del polling
              timer.cancel();
              await _confirmarPagoEnPedido(pago, estadoMP);
              if (mounted) {
                setState(() {
                  _pagoConfirmado = pago;
                  _pantalla = estadoMP == EstadoReservaMP.aprobado
                      ? _Pantalla.aprobado
                      : _Pantalla.rechazado;
                });
              }
            }
          }
        } catch (_) {
          // Silencioso: el usuario puede verificar manualmente
        }
      }
    });
  }

  Future<void> _lanzarUrlPago(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el navegador externo.');
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error al abrir pasarela de pagos: $e';
      });
    }
  }

  // ─── PASO 1: CREAR PREFERENCIA Y ABRIR MERCADO PAGO ─────────────────────
  Future<void> _iniciarPago() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final preferencia = await MercadoPagoService.crearPreferencia(
        reservaId: widget.reservaId,
        titulo: widget.description,
        monto: widget.amount,
        emailPagador: widget.emailPagador,
      );

      // Abrir el browser externo con el link de pago real de MP
      final uri = Uri.parse(preferencia.linkPago);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('No se pudo abrir el navegador. Verificá que tenés un browser instalado.');
      }

      if (mounted) {
        setState(() {
          _pantalla = _Pantalla.esperando;
          _isProcessing = false;
        });
        _iniciarPolling(); // arrancar polling automático
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // ─── PASO 2: VERIFICAR ESTADO EN API DE MP (SIN WEBHOOK) ─────────────────
  /// Consulta directamente la API de MP buscando por external_reference.
  /// Luego actualiza la tabla 'reservas' en Supabase y muestra el resultado.
  Future<void> _verificarYActualizar() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Buscar el pago en MP por external_reference (= reservaId)
      final pago = await MercadoPagoService.buscarPagoPorReferencia(widget.reservaId);

      if (pago == null) {
        // No encontramos pago todavía — quizás tardó en acreditarse
        setState(() {
          _isProcessing = false;
          _errorMessage = 'No encontramos el pago aún. Si ya pagaste, esperá unos segundos e intentá de nuevo.';
        });
        return;
      }

      final estadoMP = MercadoPagoService.parsearEstado(pago.status);

      // Actualizar la tabla 'reservas' en Supabase con el estado real
      await _confirmarPagoEnPedido(pago, estadoMP);

      // Pago resuelto manualmente → parar el polling
      _pollingTimer?.cancel();

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _pagoConfirmado = pago;
          switch (estadoMP) {
            case EstadoReservaMP.aprobado:
              _pantalla = _Pantalla.aprobado;
              break;
            case EstadoReservaMP.pendiente:
              _pantalla = _Pantalla.pendiente;
              break;
            case EstadoReservaMP.rechazado:
              _pantalla = _Pantalla.rechazado;
              break;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  // ─── ACTUALIZAR SUPABASE ──────────────────────────────────────────────────
  Future<void> _confirmarPagoEnPedido(
    EstadoPagoMP pago,
    EstadoReservaMP estado,
  ) async {
    final ok = await ViajeLifecycleService.confirmarPagoPedido(
      pedidoId: widget.reservaId,
      pago: pago,
      estado: estado,
      preferenceId: widget.preferenceId,
      dniPagador: widget.dniPagador,
      montoFallback: widget.amount,
    );

    if (!ok) {
      throw Exception(
        'No se encontró el pedido del viaje. Volvé al carrito y aceptá la reserva nuevamente.',
      );
    }
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001F3F), Color(0xFF003580)],
          ),
        ),
        child: SafeArea(
          child: switch (_pantalla) {
            _Pantalla.aprobado   => _buildResultado(
              icon: Icons.check_circle_outline,
              color: const Color(0xFF00E676),
              titulo: '¡Pago Aprobado!',
              subtitulo: 'Tu reserva quedó confirmada. El capitán recibirá la notificación y te contactará pronto.',
              detalle: _pagoConfirmado != null
                  ? 'ID de pago: ${_pagoConfirmado!.id}\nMétodo: ${_pagoConfirmado!.paymentMethodId.toUpperCase()}'
                  : null,
              botonLabel: 'VOLVER AL INICIO',
              onBoton: () => Navigator.of(context).popUntil((r) => r.isFirst),
              botonSecundarioLabel: 'Ver ficha contractual',
              onBotonSecundario: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FichaContractualScreen(
                      pedidoId: widget.reservaId,
                    ),
                  ),
                );
              },
            ),
            _Pantalla.pendiente  => _buildResultado(
              icon: Icons.hourglass_top_rounded,
              color: Colors.amber,
              titulo: 'Pago en Proceso',
              subtitulo: 'Mercado Pago está procesando tu pago (ej: pago en efectivo). Te notificaremos cuando se acredite.',
              botonLabel: 'VOLVER',
              onBoton: () => Navigator.pop(context),
            ),
            _Pantalla.rechazado  => _buildResultado(
              icon: Icons.cancel_outlined,
              color: Colors.redAccent,
              titulo: 'Pago No Procesado',
              subtitulo: 'El pago fue rechazado o cancelado. Podés intentarlo con otro método de pago.',
              botonLabel: 'INTENTAR DE NUEVO',
              onBoton: () => setState(() {
                _pantalla = _Pantalla.inicial;
                _errorMessage = null;
              }),
            ),
            _Pantalla.esperando  => _buildEsperando(),
            _Pantalla.inicial    => _buildInicial(),
          },
        ),
      ),
    );
  }

  // ─── PANTALLA INICIAL ─────────────────────────────────────────────────────
  Widget _buildInicial() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                _buildTicket(),
                const SizedBox(height: 28),
                if (_errorMessage != null) _buildError(_errorMessage!),
                _buildBotonMP(),
                if (_mostrarSimulador) ...[
                  const SizedBox(height: 14),
                  _buildBotonSimularPago(),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const Text(
            'CONFIRMAR PAGO',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicket() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.anchor, color: Color(0xFF0D47A1), size: 22),
              const SizedBox(width: 8),
              const Text(
                'El Guia YA',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'RESUMEN DE COMPRA',
            style: TextStyle(fontSize: 10, color: Colors.grey, letterSpacing: 2),
          ),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          _row('Concepto', widget.description),
          _row(
            'Referencia',
            widget.reservaId.length > 12
                ? '${widget.reservaId.substring(0, 12).toUpperCase()}...'
                : widget.reservaId.toUpperCase(),
          ),
          _row('Fecha', _fechaHoy()),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(
                '\$ ${_formatMonto(widget.amount)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonMP() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isProcessing ? null : _iniciarPago,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF009EE3), // Azul oficial de MP
          disabledBackgroundColor: Colors.grey.shade700,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 8,
        ),
        child: _isProcessing
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(width: 18, height: 18,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  SizedBox(width: 12),
                  Text('Generando link de pago...', style: TextStyle(color: Colors.white)),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.payment, color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text(
                    'PAGAR CON MERCADO PAGO',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBotonSimularPago() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton.icon(
        onPressed: _isProcessing ? null : _simularPagoExitoso,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.orangeAccent, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.bug_report_outlined, color: Colors.orangeAccent),
        label: const Text(
          'SIMULAR PAGO (MODO TEST)',
          style: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Future<void> _simularPagoExitoso() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final mockPago = EstadoPagoMP(
        id: 'mock_mp_${DateTime.now().millisecondsSinceEpoch}',
        status: 'approved',
        statusDetail: 'accredited',
        transactionAmount: widget.amount,
        paymentMethodId: 'visa',
        dateApproved: DateTime.now(),
      );

      // Actualizar en Supabase
      await _confirmarPagoEnPedido(mockPago, EstadoReservaMP.aprobado);

      _pollingTimer?.cancel();

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _pagoConfirmado = mockPago;
          _pantalla = _Pantalla.aprobado;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _errorMessage = 'Error en simulación: $e';
        });
      }
    }
  }

  // ─── PANTALLA ESPERANDO ───────────────────────────────────────────────────
  Widget _buildEsperando() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.open_in_browser_rounded, color: Colors.white, size: 70),
          ),
          const SizedBox(height: 32),
          const Text(
            'Completá el pago\nen Mercado Pago',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, height: 1.3),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Column(
              children: [
                _Paso(numero: '1', texto: 'Usá la tarjeta VISA terminada en 3704'),
                SizedBox(height: 10),
                _Paso(numero: '2', texto: 'Completá el pago en la pantalla de MP'),
                SizedBox(height: 10),
                _Paso(numero: '3', texto: 'Volvé aquí y tocá "Verificar mi pago"'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // ── Indicador de polling automático ──────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
                const SizedBox(width: 10),
                Text(
                  'Verificando automáticamente en $_pollingSegundos s...',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_errorMessage != null) ...[
            _buildError(_errorMessage!),
            const SizedBox(height: 16),
          ],
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _verificarYActualizar,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                disabledBackgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
              ),
              child: _isProcessing
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Verificando con MP...', style: TextStyle(color: Colors.white)),
                      ],
                    )
                  : const Text(
                      '✓  VERIFICAR MI PAGO',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
            ),
          ),
          const SizedBox(height: 14),
          if (_mostrarSimulador) ...[
            _buildBotonSimularPago(),
            const SizedBox(height: 10),
          ],
          TextButton(
            onPressed: () => setState(() {
              _pantalla = _Pantalla.inicial;
              _errorMessage = null;
            }),
            child: const Text('← Cancelar y volver', style: TextStyle(color: Colors.white38)),
          ),
        ],
      ),
    );
  }

  // ─── PANTALLA DE RESULTADO ────────────────────────────────────────────────
  Widget _buildResultado({
    required IconData icon,
    required Color color,
    required String titulo,
    required String subtitulo,
    String? detalle,
    required String botonLabel,
    required VoidCallback onBoton,
    String? botonSecundarioLabel,
    VoidCallback? onBotonSecundario,
  }) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 96),
          const SizedBox(height: 24),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          Text(
            subtitulo,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.6),
          ),
          if (detalle != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                detalle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                  fontFamily: 'monospace',
                  height: 1.6,
                ),
              ),
            ),
          ],
          const SizedBox(height: 40),
          SizedBox(
            width: double.infinity,
            height: 58,
            child: ElevatedButton(
              onPressed: onBoton,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
              child: Text(
                botonLabel,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
          if (botonSecundarioLabel != null && onBotonSecundario != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: onBotonSecundario,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  botonSecundarioLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── HELPERS ──────────────────────────────────────────────────────────────
  Widget _buildError(String msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  String _fechaHoy() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}/${n.month.toString().padLeft(2, '0')}/${n.year}';
  }

  String _formatMonto(double monto) {
    return monto
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  }
}

// ─── WIDGET AUXILIAR: PASO ───────────────────────────────────────────────────
class _Paso extends StatelessWidget {
  final String numero;
  final String texto;
  const _Paso({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF009EE3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(numero,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(texto, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }
}

enum _Pantalla { inicial, esperando, aprobado, pendiente, rechazado }
