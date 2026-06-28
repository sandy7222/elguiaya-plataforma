import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/safe_button.dart';

import '../services/supabase_service.dart';
import '../services/billetera_virtual_service.dart';

class CapitanSaldosScreen extends StatefulWidget {
  const CapitanSaldosScreen({super.key});

  @override
  State<CapitanSaldosScreen> createState() => _CapitanSaldosScreenState();
}

class _CapitanSaldosScreenState extends State<CapitanSaldosScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  Map<String, dynamic> _saldos = {};
  List<Map<String, dynamic>> _transacciones = [];
  int _viajesEnProcesoMes = 0;
  double _proyectadoMes = 0.0;
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
          table: 'liquidaciones',
          callback: (payload) {
            // Recargar saldos en tiempo real cuando se actualiza cualquier liquidación
            if (mounted) _cargarSaldos();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'transacciones_capitanes',
          callback: (payload) {
            // Recargar saldos en tiempo real cuando se actualiza cualquier transacción
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
    try {
      setState(() => _isLoading = true);
      
      final saldos = await SupabaseService.getSaldosCapitan(_capitanId);
      final transacciones = await SupabaseService.getTransaccionesCapitan(_capitanId);
      
      setState(() {
        _saldos = saldos;
        _transacciones = transacciones;
        _isLoading = false;
      });
      _cargarProyeccionMes();
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

  Future<void> _solicitarLiquidacion() async {
    final saldoDisponible = (_saldos['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
    
    if (saldoDisponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('No tienes saldo disponible para liquidar')),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
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
              Text(
                'Solicitar Liquidación',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Estás por solicitar la liquidación de:',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
              const SizedBox(height: 12),
              Text(
                '\$${saldoDisponible.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyanAccent,
                  shadows: [
                    Shadow(color: Colors.cyanAccent, blurRadius: 10),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.cyanAccent.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.cyanAccent.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.cyanAccent, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'El dinero será transferido a tu cuenta bancaria registrada en 24-48 horas hábiles.',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _procesarLiquidacion(saldoDisponible);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent.withOpacity(0.2),
                foregroundColor: Colors.cyanAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: const BorderSide(color: Colors.cyanAccent),
                ),
              ),
              child: const Text('Confirmar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarLiquidacion(double monto) async {
    try {
      await SupabaseService.solicitarLiquidacion(_capitanId, monto);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('💰 Liquidación solicitada exitosamente')),
            backgroundColor: Color(0xFF00E676),
          ),
        );
        _cargarSaldos();
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
            'Estimado neto (luego de comisión). Se acredita al cerrarse cada viaje y queda disponible a las ${BilleteraVirtualService.horasDisputas}hs.',
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

  Widget _buildDistributionCard(double totalBalance, double viajasPropiosAmount, double comisionesAmount) {
    return _buildGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.pie_chart_rounded, color: Colors.cyanAccent, size: 16),
              SizedBox(width: 8),
              Text(
                'DISTRIBUCIÓN DE GANANCIAS (80/20)',
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
          
          // Visual Split progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  Expanded(
                    flex: 80,
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
                    flex: 20,
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
          
          // Detalle de Viajes propios
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF00B0FF),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Viajes Propios (80%)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${viajasPropiosAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFF00B0FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Detalle de comisiones referidos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFFFD600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Comisiones de Referidos (20%)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '\$${comisionesAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
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

  Widget _buildLiquidationButton(double saldoDisponible) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withOpacity(0.15),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeElevatedIconButton(
  onPressed: _solicitarLiquidacion,
  icon: Icons.account_balance_wallet_rounded,
  iconSize: 18,
  label: 'SOLICITAR LIQUIDACIÓN',
  textStyle: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
  style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
              foregroundColor: const Color(0xFF00E676),
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
                side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.3)),
              ),
            ),
),
        ),
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
                '${_transacciones.length} items',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _transacciones.isEmpty
              ? _buildTransaccionesVacias()
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _transacciones.length,
                  itemBuilder: (context, index) {
                    final transaccion = _transacciones[index];
                    return _buildTransaccionCard(transaccion);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildTransaccionCard(Map<String, dynamic> transaccion) {
    final monto = (transaccion['monto'] as num?)?.toDouble() ?? 0.0;
    final tipo = transaccion['tipo'] as String? ?? 'desconocido';
    final estado = transaccion['estado'] as String? ?? 'desconocido';
    final fecha = transaccion['created_at'] as String? ?? '';
    final descripcion = transaccion['descripcion'] as String? ?? 'Transacción';
    
    Color estadoColor;
    IconData estadoIcon;
    String estadoText;
    
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
        estadoColor = const Color(0xFF00B0FF);
        estadoIcon = Icons.account_balance_rounded;
        estadoText = 'Liquidado';
        break;
      default:
        estadoColor = Colors.white54;
        estadoIcon = Icons.help_outline_rounded;
        estadoText = 'Desconocido';
    }
    
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
                '\$${monto.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final saldoAConfirmar = (_saldos['saldo_a_confirmar'] as num?)?.toDouble() ?? 0.0;
    final saldoDisponible = (_saldos['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
    final totalViajes = (_saldos['total_viajes'] as int?) ?? 0;
    final viajesPendientes = (_saldos['viajes_pendientes_confirmacion'] as int?) ?? 0;
    
    final totalBalance = saldoDisponible + saldoAConfirmar;
    
    // Split 80/20 dynamic calculation
    final viajasPropiosAmount = totalBalance * 0.80;
    final comisionesAmount = totalBalance * 0.20;

    return Scaffold(
      backgroundColor: const Color(0xFF000B21),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
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
      ),
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
                        // Tarjeta Principal Glassmorphic de Saldo Total
                        _buildTotalBalanceCard(totalBalance, saldoDisponible, saldoAConfirmar),
                        const SizedBox(height: 16),

                        // Indicador "Este mes": viajes en proceso + proyectado
                        _buildProyeccionMesCard(),
                        const SizedBox(height: 16),
                        
                        // Tarjeta Glassmorphic de Distribución 80/20
                        _buildDistributionCard(totalBalance, viajasPropiosAmount, comisionesAmount),
                        const SizedBox(height: 16),
                        
                        // Fila de Estadísticas Rápidas
                        _buildStatsRow(totalViajes, viajesPendientes),
                        const SizedBox(height: 16),
                        
                        // Botón de Liquidación Premium (si hay saldo)
                        if (saldoDisponible > 0) ...[
                          _buildLiquidationButton(saldoDisponible),
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
