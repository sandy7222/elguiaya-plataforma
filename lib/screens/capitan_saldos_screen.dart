import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/billetera_virtual_service.dart';

class CapitanSaldosScreen extends StatefulWidget {
  final bool showAppBar;

  const CapitanSaldosScreen({
    super.key,
    this.showAppBar = true,
  });

  @override
  State<CapitanSaldosScreen> createState() => _CapitanSaldosScreenState();
}

class _CapitanSaldosScreenState extends State<CapitanSaldosScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  Map<String, dynamic> _saldos = {};
  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _retirosEnProceso = [];
  int _viajesEnProcesoMes = 0;
  double _proyectadoMes = 0.0;
  double _totalBrutoAcumulado = 0.0;
  double _totalComisionAcumulada = 0.0;
  double _totalNetoAcumulado = 0.0;
  String? _cbuCapitan;
  bool _isLoading = true;
  Timer? _actualizacionTimer;
  RealtimeChannel? _realtimeChannel;
  
  String get _capitanId => SupabaseService.currentUserId ?? '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarSaldos();
    _iniciarActualizacionAutomatica();
    _setupRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actualizacionTimer?.cancel();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarSaldos();
      _iniciarActualizacionAutomatica();
      _setupRealtime();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
      _realtimeChannel?.unsubscribe();
    }
  }

  void _setupRealtime() {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = Supabase.instance.client
        .channel('capitan-saldos-$_capitanId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'movimientos_billetera',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'capitan_id',
            value: _capitanId,
          ),
          callback: (payload) {
            if (mounted) _cargarSaldos();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'billetera_capitanes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'capitan_id',
            value: _capitanId,
          ),
          callback: (payload) {
            if (mounted) _cargarSaldos();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'liquidaciones',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'capitan_id',
            value: _capitanId,
          ),
          callback: (payload) {
            if (mounted) _cargarSaldos();
          },
        )
        .subscribe();
  }

  void _iniciarActualizacionAutomatica() {
    _actualizacionTimer?.cancel();
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarSaldos();
      }
    });
  }

  Future<void> _cargarSaldos() async {
    if (_capitanId.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      final billetera = await BilleteraVirtualService.getBilletera(_capitanId);
      final movimientos = await BilleteraVirtualService.getMovimientos(
        capitanId: _capitanId,
        limit: 50,
      );
      final retiros = await BilleteraVirtualService.getLiquidacionesCapitan(_capitanId);

      double bruto = 0;
      double comision = 0;
      double neto = 0;
      int viajesPendientes = 0;

      for (final mov in movimientos) {
        if (mov['tipo']?.toString() != 'ingreso_viaje') continue;
        bruto += (mov['monto_bruto'] as num?)?.toDouble() ?? 0.0;
        comision += (mov['comision'] as num?)?.toDouble() ?? 0.0;
        neto += (mov['monto_neto'] as num?)?.toDouble() ?? 0.0;
        if (mov['estado']?.toString() == 'pendiente') viajesPendientes++;
      }

      final saldoPendiente = (billetera['saldo_pendiente'] as num?)?.toDouble() ?? 0.0;
      final saldoDisponible = (billetera['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
      final totalViajes = movimientos.where((m) => m['tipo'] == 'ingreso_viaje').length;

      setState(() {
        _saldos = {
          'saldo_a_confirmar': saldoPendiente,
          'saldo_disponible': saldoDisponible,
          'saldo_retenido': (billetera['saldo_retenido'] as num?)?.toDouble() ?? 0.0,
          'total_viajes': totalViajes,
          'viajes_pendientes_confirmacion': viajesPendientes,
        };
        _movimientos = movimientos;
        _retirosEnProceso = retiros;
        _totalBrutoAcumulado = bruto;
        _totalComisionAcumulada = comision;
        _totalNetoAcumulado = neto;
        _isLoading = false;
      });
      _cargarProyeccionMes();
      _cargarCbuCapitan();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar saldos: $e')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _cargarCbuCapitan() async {
    try {
      final guia = await Supabase.instance.client
          .from('guias')
          .select('cbu, banco, alias')
          .eq('id', _capitanId)
          .maybeSingle();
      if (mounted) {
        setState(() {
          _cbuCapitan = guia?['cbu']?.toString();
        });
      }
    } catch (_) {}
  }

  Future<void> _cargarProyeccionMes() async {
    try {
      final now = DateTime.now();
      final desde = DateTime(now.year, now.month, 1).toIso8601String();
      final hasta = DateTime(now.year, now.month + 1, 1).toIso8601String();
      final resp = await Supabase.instance.client
          .from('pedidos')
          .select('monto_total, estado, fecha_servicio')
          .eq('capitan_id', _capitanId)
          .inFilter('estado', ['pagado', 'en_curso', 'listo_para_confirmar'])
          .gte('fecha_servicio', desde)
          .lt('fecha_servicio', hasta);
      final list = List<Map<String, dynamic>>.from(resp);
      double bruto = 0;
      for (final p in list) {
        bruto += (p['monto_total'] as num?)?.toDouble() ?? 0.0;
      }
      if (mounted) {
        setState(() {
          _viajesEnProcesoMes = list.length;
          _proyectadoMes =
              bruto * (1 - BilleteraVirtualService.comisionPorcentaje);
        });
      }
    } catch (_) {
      // Silencioso: el indicador es informativo
    }
  }

  String _enmascararCbu(String? cbu) {
    final limpio = cbu?.replaceAll(RegExp(r'[\s\-]'), '') ?? '';
    if (limpio.length < 8) return 'Sin CBU cargado';
    return '${limpio.substring(0, 4)}...${limpio.substring(limpio.length - 4)}';
  }

  Future<void> _solicitarRetiroTotal() async {
    final saldoDisponible =
        (_saldos['saldo_disponible'] as num?)?.toDouble() ?? 0.0;

    if (saldoDisponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(
            child: Text(
              'No hay saldo disponible. El dinero en "A confirmar" se libera a las ${BilleteraVirtualService.horasDisputas} hs de cada viaje.',
            ),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (saldoDisponible < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('El retiro mínimo es \$100')),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final cbu = _cbuCapitan?.trim() ?? '';
    if (cbu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(
            child: Text(
              'Cargá tu CBU/CVU en Identidad del Capitán antes de solicitar retiro',
            ),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    if (!mounted) return;

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Retiro total',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Transferir \$${saldoDisponible.toStringAsFixed(2)} completo a ${_enmascararCbu(cbu)}?\n\nEl admin procesará el pago manual en 24-48 hs hábiles.',
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
            ),
            child: const Text('Confirmar retiro total'),
          ),
        ],
      ),
    );

    if (confirmado == true) {
      await _procesarLiquidacion(saldoDisponible);
    }
  }

  Future<void> _solicitarRetiroParcial() async {
    final saldoDisponible = (_saldos['saldo_disponible'] as num?)?.toDouble() ?? 0.0;

    if (saldoDisponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('No tienes saldo disponible para transferir')),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final cbu = _cbuCapitan?.trim() ?? '';
    if (cbu.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(
            child: Text('Cargá tu CBU/CVU en Identidad del Capitán antes de solicitar transferencia'),
          ),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final montoController = TextEditingController(
      text: saldoDisponible.toStringAsFixed(0),
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final texto = montoController.text.replaceAll(',', '.');
            final montoIngresado = double.tryParse(texto) ?? 0.0;
            final restante = (saldoDisponible - montoIngresado).clamp(0.0, double.infinity);
            final montoValido = montoIngresado >= 100 && montoIngresado <= saldoDisponible;

            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: AlertDialog(
                backgroundColor: const Color(0xFF0A192F).withOpacity(0.95),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                title: const Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: Colors.cyanAccent),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Retiro parcial',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disponible para retirar: \$${saldoDisponible.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Destino: ${_enmascararCbu(cbu)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                montoController.text = saldoDisponible.toStringAsFixed(0);
                                setDialogState(() {});
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.cyanAccent,
                                side: const BorderSide(color: Colors.cyanAccent),
                              ),
                              child: const Text('Monto total', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                montoController.text = '';
                                setDialogState(() {});
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                              ),
                              child: const Text('Otro monto', style: TextStyle(fontSize: 12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: montoController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(color: Colors.cyanAccent, fontSize: 22),
                          hintText: 'Monto a retirar',
                          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.white.withOpacity(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.cyanAccent),
                          ),
                        ),
                        onChanged: (_) => setDialogState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        montoValido
                            ? 'Quedarán \$${restante.toStringAsFixed(2)} disponibles'
                            : 'Mínimo \$100 · máximo \$${saldoDisponible.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: montoValido ? Colors.white54 : Colors.orangeAccent,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'El admin transferirá manualmente desde Mercado Pago en 24-48 hs hábiles.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                  ),
                  ElevatedButton(
                    onPressed: montoValido
                        ? () {
                            Navigator.pop(context);
                            _procesarLiquidacion(montoIngresado);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                      foregroundColor: Colors.cyanAccent,
                      disabledBackgroundColor: Colors.white10,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(color: Colors.cyanAccent),
                      ),
                    ),
                    child: const Text('Solicitar retiro', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _procesarLiquidacion(double monto) async {
    final cbu = _cbuCapitan?.trim() ?? '';
    if (cbu.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(
              child: Text('Cargá tu CBU/CVU en Identidad del Capitán antes de solicitar transferencia'),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    try {
      final resultado = await BilleteraVirtualService.solicitarTransferencia(
        capitanId: _capitanId,
        monto: monto,
        cbu: cbu,
      );

      if (!mounted) return;

      if (resultado.exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                '💰 Transferencia solicitada. Estimación: ${resultado.estimacion ?? '24-48 hs hábiles'}',
              ),
            ),
            backgroundColor: const Color(0xFF00E676),
          ),
        );
        _cargarSaldos();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text(resultado.errorMsg ?? 'Error al procesar transferencia')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al procesar liquidación: $e')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Widget _buildGlassCard({
    required Widget child,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
    Color? borderColor,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor ?? Colors.white.withOpacity(0.08),
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildTotalBalanceCard(double totalBalance, double saldoDisponible, double saldoAConfirmar) {
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        children: [
          const Text(
            'SALDO TOTAL ACUMULADO',
            style: TextStyle(
              color: Colors.cyanAccent,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          
          // Gran Número Brillante
          Stack(
            alignment: Alignment.center,
            children: [
              // Brillo de fondo
              Container(
                width: 180,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.cyanAccent.withOpacity(0.12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.cyanAccent.withOpacity(0.35),
                      blurRadius: 40,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
              Text(
                '\$${totalBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      color: Colors.cyanAccent,
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          
          // Sub-saldos
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'DISPONIBLE',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${saldoDisponible.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white10),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.pending_actions_rounded, color: Colors.amberAccent, size: 12),
                        const SizedBox(width: 6),
                        Text(
                          'A CONFIRMAR',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${saldoAConfirmar.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.amberAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProyeccionMesCard() {
    return _buildGlassCard(
      padding: const EdgeInsets.all(20),
      borderColor: const Color(0xFF00B0FF).withOpacity(0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.trending_up_rounded, color: Color(0xFF00B0FF), size: 16),
              SizedBox(width: 8),
              Text(
                'ESTE MES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$_viajesEnProcesoMes',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Viajes en proceso',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '\$${_proyectadoMes.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Color(0xFF00B0FF),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Proyectado a cobrar',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Estimado neto al 90% (10% comisión plataforma). Se acredita al cerrarse cada viaje y queda disponible a las ${BilleteraVirtualService.horasDisputas}hs.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionCard() {
    const pctCapitan = 90;
    const pctPlataforma = 10;
    final bruto = _totalBrutoAcumulado;
    final comision = _totalComisionAcumulada;
    final neto = _totalNetoAcumulado;

    return _buildGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Colors.cyanAccent, size: 16),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'DISTRIBUCIÓN DE GANANCIAS (90/10)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '90% neto para vos · 10% comisión El Guía YA sobre el bruto de cada viaje',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 10,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: pctCapitan,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF0066FF), Color(0xFF00B0FF)],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    flex: pctPlataforma,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFD600), Color(0xFFFF8F00)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDistributionRow(
            color: Colors.white54,
            label: 'Bruto viajes cerrados (100%)',
            amount: bruto,
            amountColor: Colors.white,
          ),
          const SizedBox(height: 8),
          _buildDistributionRow(
            color: const Color(0xFFFFD600),
            label: 'Comisión El Guía YA ($pctPlataforma%)',
            amount: comision,
            amountColor: const Color(0xFFFFD600),
          ),
          const SizedBox(height: 8),
          _buildDistributionRow(
            color: const Color(0xFF00B0FF),
            label: 'Tu ganancia neta ($pctCapitan%)',
            amount: neto,
            amountColor: const Color(0xFF00B0FF),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionRow({
    required Color color,
    required String label,
    required double amount,
    required Color amountColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: amountColor,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(int totalViajes, int viajesPendientes) {
    final completados = totalViajes - viajesPendientes;
    
    return Row(
      children: [
        Expanded(
          child: _buildGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const Icon(Icons.sailing_rounded, color: Color(0xFF00B0FF), size: 20),
                const SizedBox(height: 6),
                Text(
                  '$totalViajes',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Total Viajes',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const Icon(Icons.hourglass_empty_rounded, color: Colors.amberAccent, size: 20),
                const SizedBox(height: 6),
                Text(
                  '$viajesPendientes',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Pendientes',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00E676), size: 20),
                const SizedBox(height: 6),
                Text(
                  '$completados',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Completados',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRetiroSection(double saldoDisponible, double saldoAConfirmar) {
    final cbuOk = (_cbuCapitan?.trim() ?? '').isNotEmpty;
    final puedeRetirar = saldoDisponible >= 100 && cbuOk;
    final saldoInsuficiente = saldoDisponible > 0 && saldoDisponible < 100;

    void onRetiroBloqueado() {
      if (saldoDisponible <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                saldoAConfirmar > 0
                    ? 'Tu saldo está en "A confirmar". Se libera a las ${BilleteraVirtualService.horasDisputas} hs de cada viaje cerrado.'
                    : 'No tenés saldo disponible para retirar.',
              ),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
      if (saldoInsuficiente) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('El retiro mínimo es \$100')),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
      if (!cbuOk) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(
              child: Text(
                'Cargá tu CBU/CVU en Identidad del Capitán antes de solicitar retiro',
              ),
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
    }

    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFF00E676).withOpacity(0.25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.payments_rounded, color: Color(0xFF00E676), size: 18),
              SizedBox(width: 8),
              Text(
                'RETIRAR DINERO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Transferencia manual a tu CBU/CVU. El admin confirma el pago en 24-48 hs hábiles.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              height: 1.35,
            ),
          ),
          if (saldoDisponible <= 0 && saldoAConfirmar > 0) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amberAccent.withOpacity(0.25)),
              ),
              child: Text(
                '\$${saldoAConfirmar.toStringAsFixed(0)} a confirmar — disponible tras ${BilleteraVirtualService.horasDisputas} hs de cada viaje.',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 11, height: 1.35),
              ),
            ),
          ],
          if (!cbuOk) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.25)),
              ),
              child: const Text(
                'Cargá tu CBU/CVU en Identidad del Capitán para habilitar retiros.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11, height: 1.35),
              ),
            ),
          ],
          if (saldoInsuficiente) ...[
            const SizedBox(height: 10),
            Text(
              'Saldo disponible \$${saldoDisponible.toStringAsFixed(2)} — mínimo de retiro \$100.',
              style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: puedeRetirar ? _solicitarRetiroTotal : onRetiroBloqueado,
                  icon: const Icon(Icons.account_balance_wallet_rounded, size: 18),
                  label: const Text('Retiro total'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E676),
                    disabledForegroundColor: Colors.white38,
                    side: BorderSide(
                      color: puedeRetirar
                          ? const Color(0xFF00E676).withOpacity(0.5)
                          : Colors.white24,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: puedeRetirar ? _solicitarRetiroParcial : onRetiroBloqueado,
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('Retiro parcial'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                    foregroundColor: const Color(0xFF00E676),
                    disabledBackgroundColor: Colors.white10,
                    disabledForegroundColor: Colors.white38,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.35)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRetirosEnProcesoSection() {
    if (_retirosEnProceso.isEmpty) return const SizedBox.shrink();

    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.orangeAccent.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent, size: 16),
              SizedBox(width: 8),
              Text(
                'RETIROS EN PROCESO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._retirosEnProceso.map((retiro) {
            final monto = (retiro['monto'] as num?)?.toDouble() ?? 0.0;
            final estado = retiro['estado']?.toString() ?? 'solicitado';
            final fecha = retiro['created_at']?.toString() ?? '';
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orangeAccent.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${monto.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Estado: ${estado == 'procesando' ? 'En proceso' : 'Solicitado'} · ${_formatFecha(fecha)}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.sync_rounded, color: Colors.orangeAccent, size: 20),
                ],
              ),
            );
          }),
          Text(
            'El administrador transferirá manualmente desde Mercado Pago.',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
          ),
        ],
      ),
    );
  }

  Widget _buildTransaccionesSection() {
    return _buildGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history_rounded, color: Colors.cyanAccent, size: 16),
              const SizedBox(width: 8),
              const Text(
                'HISTORIAL DE TRANSACCIONES',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                '${_movimientos.length} items',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _movimientos.isEmpty
              ? _buildTransaccionesVacias()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _movimientos.length,
                  itemBuilder: (context, index) {
                    final movimiento = _movimientos[index];
                    return _buildMovimientoCard(movimiento);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildMovimientoCard(Map<String, dynamic> movimiento) {
    final tipo = movimiento['tipo']?.toString() ?? 'desconocido';
    final estado = movimiento['estado']?.toString() ?? 'desconocido';
    final fecha = movimiento['created_at']?.toString() ?? '';
    final descripcion = movimiento['descripcion']?.toString() ?? 'Movimiento';
    final montoNeto = (movimiento['monto_neto'] as num?)?.toDouble() ?? 0.0;
    final montoBruto = (movimiento['monto_bruto'] as num?)?.toDouble() ?? 0.0;
    final comision = (movimiento['comision'] as num?)?.toDouble() ?? 0.0;
    final esIngresoViaje = tipo == 'ingreso_viaje';
    final esRetiro = tipo.startsWith('retiro_');
    final disponibleDesde = movimiento['disponible_desde']?.toString();
    
    Color estadoColor;
    IconData estadoIcon;
    String estadoText;
    
    if (tipo == 'retiro_completado') {
      estadoColor = const Color(0xFF00B0FF);
      estadoIcon = Icons.check_circle_rounded;
      estadoText = 'Transferido';
    } else if (tipo == 'retiro_fallido') {
      estadoColor = Colors.redAccent;
      estadoIcon = Icons.cancel_rounded;
      estadoText = 'Rechazado';
    } else if (tipo == 'retiro_solicitado') {
      estadoColor = Colors.orangeAccent;
      estadoIcon = Icons.sync_rounded;
      estadoText = 'En proceso';
    } else {
      switch (estado) {
      case 'disponible':
        estadoColor = const Color(0xFF00E676);
        estadoIcon = Icons.check_circle_rounded;
        estadoText = 'Disponible';
        break;
      case 'pendiente':
        estadoColor = Colors.amberAccent;
        estadoIcon = Icons.pending_rounded;
        estadoText = 'Pendiente';
        break;
      case 'liquidado':
      case 'completado':
        estadoColor = const Color(0xFF00B0FF);
        estadoIcon = Icons.account_balance_rounded;
        estadoText = 'Completado';
        break;
      case 'procesando':
        estadoColor = Colors.orangeAccent;
        estadoIcon = Icons.sync_rounded;
        estadoText = 'Procesando';
        break;
      case 'fallido':
        estadoColor = Colors.redAccent;
        estadoIcon = Icons.cancel_rounded;
        estadoText = 'Fallido';
        break;
      default:
        estadoColor = Colors.white54;
        estadoIcon = Icons.help_outline_rounded;
        estadoText = 'Desconocido';
      }
    }
    
    final montoDisplay = esRetiro ? -montoNeto.abs() : montoNeto;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: estadoColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(estadoIcon, color: estadoColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                if (esIngresoViaje) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Bruto \$${montoBruto.toStringAsFixed(0)} · Comisión \$${comision.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                ],
                if (esIngresoViaje && estado == 'pendiente' && disponibleDesde != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Disponible el ${_formatFecha(disponibleDesde)}',
                    style: const TextStyle(
                      fontSize: 9,
                      color: Colors.amberAccent,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  _formatFecha(fecha),
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${montoDisplay < 0 ? '-' : ''}\$${montoDisplay.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: montoDisplay < 0 ? Colors.orangeAccent : Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  estadoText,
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    color: estadoColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransaccionesVacias() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 48,
              color: Colors.white.withOpacity(0.2),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sin transacciones aún',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tus ganancias aparecerán aquí al completar tus viajes.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(String fechaString) {
    try {
      final fecha = DateTime.parse(fechaString);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fechaString;
    }
  }

  Widget _buildEmbeddedHeader() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'MIS GANANCIAS',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              letterSpacing: 1.5,
              color: Colors.white,
            ),
          ),
        ),
        IconButton(
          onPressed: _cargarSaldos,
          icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
          tooltip: 'Actualizar',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final saldoAConfirmar = (_saldos['saldo_a_confirmar'] as num?)?.toDouble() ?? 0.0;
    final saldoDisponible = (_saldos['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
    final totalViajes = (_saldos['total_viajes'] as int?) ?? 0;
    final viajesPendientes = (_saldos['viajes_pendientes_confirmacion'] as int?) ?? 0;
    
    final totalBalance = saldoDisponible + saldoAConfirmar;

    return Scaffold(
      backgroundColor: const Color(0xFF000B21),
      extendBodyBehindAppBar: widget.showAppBar,
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text(
                'MIS GANANCIAS',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  onPressed: _cargarSaldos,
                  icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                  tooltip: 'Actualizar',
                ),
              ],
            )
          : null,
      body: Stack(
        children: [
          // Capa 0: Gradiente de Fondo Ultra Premium (Diseño Sistema)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF000B21), // Azul medianoche ultra oscuro
                  Color(0xFF0A192F), // Azul marino militar
                  Color(0xFF172A45), // Azul cobalto profundo
                ],
              ),
            ),
          ),
          
          // Capa 1: Orbes Luminosos de Fondo para Profundidad Tridimensional
          Positioned(
            top: 80,
            right: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00B0FF).withOpacity(0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: 120,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            top: 350,
            left: 20,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFFD600).withOpacity(0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70.0, sigmaY: 70.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Capa 2: Contenido
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: _cargarSaldos,
                    color: Colors.cyanAccent,
                    backgroundColor: const Color(0xFF0A192F),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      children: [
                        if (!widget.showAppBar) ...[
                          _buildEmbeddedHeader(),
                          const SizedBox(height: 12),
                        ],
                        // Tarjeta Principal Glassmorphic de Saldo Total
                        _buildTotalBalanceCard(totalBalance, saldoDisponible, saldoAConfirmar),
                        const SizedBox(height: 16),

                        _buildRetiroSection(saldoDisponible, saldoAConfirmar),
                        const SizedBox(height: 16),

                        // Indicador "Este mes": viajes en proceso + proyectado
                        _buildProyeccionMesCard(),
                        const SizedBox(height: 16),
                        
                        // Desglose 90% capitán / 10% plataforma
                        _buildDistributionCard(),
                        const SizedBox(height: 16),
                        
                        // Fila de Estadísticas Rápidas
                        _buildStatsRow(totalViajes, viajesPendientes),
                        const SizedBox(height: 16),

                        if (_retirosEnProceso.isNotEmpty) ...[
                          _buildRetirosEnProcesoSection(),
                          const SizedBox(height: 16),
                        ],
                        
                        // Lista de Transacciones Históricas
                        _buildTransaccionesSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}
