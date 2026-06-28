import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/safe_button.dart';

class AdminLiquidacionScreen extends StatefulWidget {
  const AdminLiquidacionScreen({super.key});

  @override
  State<AdminLiquidacionScreen> createState() => _AdminLiquidacionScreenState();
}

class _AdminLiquidacionScreenState extends State<AdminLiquidacionScreen> {
  List<Map<String, dynamic>> _liquidaciones = [];
  List<Map<String, dynamic>> _comisionesLogs = [];
  bool _mostrarComisiones = false;
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  /// 🛡️ Validar seguridad del Rol Admin
  void _checkSecurity() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final String? email = user.email;
      final String? role = user.userMetadata?['rol']?.toString() ?? user.userMetadata?['role']?.toString();
      
      if (email == 'admin@capitanya.com' || role == 'admin') {
        setState(() {
          _isAdmin = true;
        });
        _cargarLiquidaciones();
      } else {
        setState(() {
          _isAdmin = false;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _isAdmin = false;
        _isLoading = false;
      });
    }
  }

  /// 📥 Cargar datos (liquidaciones pendientes o logs de comisiones)
  Future<void> _cargarLiquidaciones() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      if (_mostrarComisiones) {
        final logs = await SupabaseService.fetchLogsComisionesAdmin();
        if (mounted) {
          setState(() {
            _comisionesLogs = logs;
            _isLoading = false;
          });
        }
      } else {
        final liquidaciones = await SupabaseService.fetchPendingLiquidacionesAdmin();
        if (mounted) {
          setState(() {
            _liquidaciones = liquidaciones;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 💼 Confirmar el pago y ejecutar la transacción atómica
  Future<void> _confirmarPago(Map<String, dynamic> liquidacion) async {
    final String liqId = liquidacion['id']?.toString() ?? '';
    final String capId = (liquidacion['capitan_id'] ?? liquidacion['usuario_id'])?.toString() ?? '';
    final String nombre = liquidacion['nombre'] ?? 'Usuario';
    final String cbu = liquidacion['cbu'] ?? '';
    final double monto = (liquidacion['monto'] as num?)?.toDouble() ?? 0.0;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001A33).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.payment_rounded, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text(
                'CONFIRMAR RETIRO',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Confirmas que ya realizaste la transferencia bancaria por este retiro?',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitante: $nombre',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'CBU / CVU destino:\n$cbu',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Monto: \$${monto.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Esta acción es atómica, restará el saldo, guardará el historial de pagos y enviará una notificación Push instantánea al dispositivo del usuario.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11, height: 1.3, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _procesarPagoBackend(liqId, capId, monto, cbu);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text('CONFIRMAR Y PAGAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  /// ⚙️ Procesar pago en Supabase de forma segura con prevención de clics dobles
  Future<void> _procesarPagoBackend(
    String liquidacionId,
    String usuarioId,
    double monto,
    String cbu,
  ) async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);

    try {
      await SupabaseService.procesarLiquidacionAdmin(
        liquidacionId: liquidacionId,
        usuarioId: usuarioId,
        monto: monto,
        cbuDestino: cbu,
      );

      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.black),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Transferencia liquidada y notificada con éxito!',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00E676),
            duration: const Duration(seconds: 4),
          ),
        );
        _cargarLiquidaciones();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al liquidar fondos: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// 📋 Copiar CBU al portapapeles
  void _copiarCbu(String cbu) {
    Clipboard.setData(ClipboardData(text: cbu));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡CBU/CVU copiado al portapapeles! 📋'),
        backgroundColor: Colors.cyan,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🛡️ Filtro de seguridad para acceso de Administrador
    if (!_isAdmin && !_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF000A1A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.security, color: Colors.redAccent, size: 80),
              SizedBox(height: 16),
              Text(
                'ACCESO DENEGADO',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
              SizedBox(height: 8),
              Text(
                'Solo los administradores con privilegios pueden acceder a este panel.',
                style: TextStyle(color: Colors.white54, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Permite ver el fondo con orbes de luz del Dashboard
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Encabezado del panel
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.cyan.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.cyan.withOpacity(0.3)),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.cyanAccent, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Módulo de Liquidaciones',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pendientes de aprobación y envío de fondos',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Colors.cyanAccent),
                      onPressed: _cargarLiquidaciones,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 🎛️ Selector de Vista (Liquidaciones vs Comisiones)
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mostrarComisiones = false;
                            });
                            _cargarLiquidaciones();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: !_mostrarComisiones
                                  ? Colors.cyan.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: !_mostrarComisiones
                                  ? Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.0)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'LIQUIDACIONES PENDIENTES',
                                style: TextStyle(
                                  color: !_mostrarComisiones ? Colors.cyanAccent : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _mostrarComisiones = true;
                            });
                            _cargarLiquidaciones();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _mostrarComisiones
                                  ? Colors.cyan.withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: _mostrarComisiones
                                  ? Border.all(color: Colors.cyanAccent.withOpacity(0.4), width: 1.0)
                                  : null,
                            ),
                            child: Center(
                              child: Text(
                                'HISTORIAL COMISIONES',
                                style: TextStyle(
                                  color: _mostrarComisiones ? Colors.cyanAccent : Colors.white60,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Lista Principal
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Colors.cyanAccent))
                      : _mostrarComisiones
                          ? _buildComisionesTab()
                          : _liquidaciones.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_outline_rounded, color: Colors.white24, size: 70),
                                      const SizedBox(height: 16),
                                      const Text(
                                        '¡Todo al día!',
                                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'No hay solicitudes de retiros pendientes.',
                                        style: TextStyle(color: Colors.white54, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                )
                              : RefreshIndicator(
                                  color: Colors.cyanAccent,
                                  onRefresh: _cargarLiquidaciones,
                                  child: ListView.builder(
                                    physics: const AlwaysScrollableScrollPhysics(),
                                    itemCount: _liquidaciones.length,
                                    itemBuilder: (context, index) {
                                      final liq = _liquidaciones[index];
                                      final nombre = liq['nombre'] ?? 'Usuario';
                                      final avatarUrl = liq['avatar_url'];
                                      final rol = liq['rol'] ?? 'Capitán';
                                      final double monto = (liq['monto'] as num?)?.toDouble() ?? 0.0;
                                      final cbu = liq['cbu'] ?? '';
                                      final saldoDisponible = (liq['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
                                      final bool saldoValido = liq['saldo_valido'] == true;

                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF001A33).withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: saldoValido ? Colors.cyan.withOpacity(0.2) : Colors.redAccent.withOpacity(0.3),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(20),
                                          child: BackdropFilter(
                                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                            child: Container(
                                              padding: const EdgeInsets.all(18),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.cyan.withOpacity(0.02),
                                                    Colors.transparent,
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Fila Superior (Perfil y Rol)
                                                  Row(
                                                    children: [
                                                      CircleAvatar(
                                                        radius: 20,
                                                        backgroundColor: Colors.cyan.withOpacity(0.2),
                                                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                                                        child: avatarUrl == null
                                                            ? const Icon(Icons.person, color: Colors.cyanAccent)
                                                            : null,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              nombre,
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.bold,
                                                                fontSize: 15,
                                                                fontFamily: 'Outfit',
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Row(
                                                              children: [
                                                                // Rol Badge
                                                                Container(
                                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                                  decoration: BoxDecoration(
                                                                    color: (rol == 'Capitán' ? Colors.orange : Colors.purple).withOpacity(0.15),
                                                                    borderRadius: BorderRadius.circular(8),
                                                                    border: Border.all(
                                                                      color: (rol == 'Capitán' ? Colors.orangeAccent : Colors.purpleAccent).withOpacity(0.4),
                                                                      width: 0.5,
                                                                    ),
                                                                  ),
                                                                  child: Text(
                                                                    rol.toUpperCase(),
                                                                    style: TextStyle(
                                                                      color: rol == 'Capitán' ? Colors.orangeAccent : Colors.purpleAccent,
                                                                      fontSize: 9,
                                                                      fontWeight: FontWeight.bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(width: 8),
                                                                // Validación de Saldo Disponible
                                                                Text(
                                                                  'Saldo Disp: \$${saldoDisponible.toStringAsFixed(2)}',
                                                                  style: TextStyle(
                                                                    color: saldoValido ? Colors.white54 : Colors.redAccent,
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 18),

                                                  // Monto Solicitado en estilo HeadlineMedium
                                                  Text(
                                                    '\$${monto.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 28,
                                                      fontWeight: FontWeight.bold,
                                                      letterSpacing: 0.5,
                                                      fontFamily: 'Outfit',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 14),

                                                  // Campo CBU/CVU con Botón Copiar
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white.withOpacity(0.04),
                                                      borderRadius: BorderRadius.circular(12),
                                                      border: Border.all(color: Colors.white10),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(Icons.account_balance_outlined, color: Colors.cyanAccent, size: 18),
                                                        const SizedBox(width: 10),
                                                        Expanded(
                                                          child: Text(
                                                            cbu.isNotEmpty ? cbu : 'CBU no cargado por el usuario',
                                                            style: const TextStyle(
                                                              color: Colors.white70,
                                                              fontSize: 12,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        if (cbu.isNotEmpty)
                                                          GestureDetector(
                                                            onTap: () => _copiarCbu(cbu),
                                                            child: Container(
                                                              padding: const EdgeInsets.all(6),
                                                              decoration: BoxDecoration(
                                                                color: Colors.cyan.withOpacity(0.1),
                                                                borderRadius: BorderRadius.circular(8),
                                                              ),
                                                              child: const Icon(Icons.copy_rounded, color: Colors.cyanAccent, size: 16),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 16),

                                                  // Validación de saldo alerta
                                                  if (!saldoValido) ...[
                                                    Container(
                                                      margin: const EdgeInsets.only(bottom: 12),
                                                      padding: const EdgeInsets.all(10),
                                                      decoration: BoxDecoration(
                                                        color: Colors.redAccent.withOpacity(0.08),
                                                        borderRadius: BorderRadius.circular(10),
                                                        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                                                      ),
                                                      child: Row(
                                                        children: const [
                                                          Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              'Saldo insuficiente en cuenta para procesar esta liquidación.',
                                                              style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],

                                                  // Botón Confirmar Transferencia Realizada
                                                  SizedBox(
                                                    width: double.infinity,
                                                    child: SafeElevatedIconButton(
  onPressed: () => _confirmarPago(liq),
  icon: Icons.check_circle_outline_rounded,
  iconSize: 18,
  label: 'CONFIRMAR TRANSFERENCIA REALIZADA',
  style: ElevatedButton.styleFrom(
                                                        backgroundColor: const Color(0xFF00E676),
                                                        foregroundColor: Colors.black87,
                                                        textStyle: const TextStyle(
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: 12,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                                        elevation: 6,
                                                      ),
),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                ),
              ],
            ),
          ),
          
          // Indicador de Carga Global para evitar clics dobles en transacciones
          if (_isProcessing)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                color: Colors.black45,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: Colors.cyanAccent),
                      SizedBox(height: 16),
                      Text(
                        'Procesando transferencia y registrando historial...',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 📊 Tab de Historial de Comisiones
  Widget _buildComisionesTab() {
    if (_comisionesLogs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.history_toggle_off_rounded, color: Colors.white24, size: 70),
            SizedBox(height: 16),
            Text(
              'Sin comisiones registradas',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 6),
            Text(
              'Las comisiones procesadas aparecerán aquí.',
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _comisionesLogs.length,
      itemBuilder: (context, index) {
        final log = _comisionesLogs[index];
        final String escenario = log['escenario'] ?? 'SIN_REFERENCIA';
        final double montoViaje = (log['monto_viaje'] as num?)?.toDouble() ?? 0.0;
        final double comisionApp = (log['comision_app'] as num?)?.toDouble() ?? 0.0;
        final double pagoVendedor = (log['pago_vendedor'] as num?)?.toDouble() ?? 0.0;
        final double netaApp = (log['neta_app'] as num?)?.toDouble() ?? 0.0;
        final String? vendedorId = log['vendedor_id']?.toString();
        final String fecha = log['created_at'] != null 
            ? DateTime.tryParse(log['created_at'].toString())?.toLocal().toString().substring(0, 16) ?? ''
            : '';

        // Badge styling
        Color badgeColor;
        String badgeText;
        switch (escenario) {
          case 'MATCH':
            badgeColor = const Color(0xFF00E676);
            badgeText = 'MATCH PERFECTO (100%)';
            break;
          case 'CAPITAN':
            badgeColor = Colors.cyanAccent;
            badgeText = 'REC. CAPITÁN (70%)';
            break;
          case 'PESCADOR':
            badgeColor = Colors.indigoAccent;
            badgeText = 'REC. PESCADOR (20%)';
            break;
          case 'EXPIRADO_O_REPETIDO':
            badgeColor = Colors.orangeAccent;
            badgeText = 'VENCIDO / REPETIDO';
            break;
          default:
            badgeColor = Colors.white38;
            badgeText = 'SIN REFERENCIA';
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF001A33).withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: badgeColor.withOpacity(0.25),
              width: 1.5,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      badgeColor.withOpacity(0.03),
                      Colors.transparent,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: Escenario y Fecha
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: badgeColor.withOpacity(0.4), width: 0.5),
                          ),
                          child: Text(
                            badgeText,
                            style: TextStyle(
                              color: badgeColor,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Text(
                          fecha,
                          style: const TextStyle(color: Colors.white38, fontSize: 10),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Vendedor info (Clickable to view detail)
                    if (vendedorId != null) ...[
                      InkWell(
                        onTap: () => _mostrarPerfilComisionista(vendedorId),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.3), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.stars_rounded, color: Colors.amberAccent, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                'Código de Promotor: $vendedorId',
                                style: const TextStyle(
                                  color: Colors.amberAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.info_outline_rounded, color: Colors.amberAccent, size: 12),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Tabla de comisiones
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildMontoCol('Total Viaje', montoViaje, Colors.white),
                        _buildMontoCol('Comisión App (10%)', comisionApp, Colors.cyanAccent),
                        _buildMontoCol('Pago Vendedor', pagoVendedor, const Color(0xFF00E676)),
                        _buildMontoCol('Ganancia Neta App', netaApp, Colors.orangeAccent),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMontoCol(String titulo, double valor, Color valorColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${valor.toStringAsFixed(2)}',
          style: TextStyle(
            color: valorColor,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  /// 🌟 Mostrar ficha de comisionista/promotor de forma glassmórfica premium
  Future<void> _mostrarPerfilComisionista(String? selector) async {
    if (selector == null || selector.trim().isEmpty) return;

    // Mostrar diálogo de carga glassmórfico
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      ),
    );

    Map<String, dynamic>? promotor;
    try {
      // Intentar buscar por código de promotor
      promotor = await SupabaseService.validarCodigoPromotor(selector);

      // Si no se encuentra directamente, buscar en todos los comisionistas
      if (promotor == null) {
        final list = await SupabaseService.getComisionistas();
        final match = list.firstWhere(
          (c) => c['id']?.toString() == selector || c['codigo_comision']?.toString().toUpperCase() == selector.toUpperCase(),
          orElse: () => <String, dynamic>{},
        );
        if (match.isNotEmpty) {
          promotor = match;
        }
      }
    } catch (e) {
      print('Error al buscar perfil de comisionista: $e');
    }

    // Cerrar diálogo de carga
    if (mounted) Navigator.pop(context);

    if (promotor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se encontraron los datos de perfil para este promotor.'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final String nombre = promotor['nombre'] ?? 'Sin Nombre';
    final String dni = promotor['dni'] ?? 'Sin DNI';
    final String cuentaMp = promotor['cuenta_mp'] ?? 'Sin Cuenta';
    final String codigo = promotor['codigo_comision'] ?? 'Sin Código';
    final String estado = promotor['estado'] ?? 'activo';
    final bool esActivo = estado.toLowerCase() == 'activo';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001A33).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: Colors.cyanAccent, width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.badge_rounded, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text(
                'PERFIL PROMOTOR',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFichaRow('Nombre y Apellido:', nombre),
              _buildFichaRow('DNI:', dni),
              _buildFichaRow('Cuenta Mercado Pago:', cuentaMp),
              _buildFichaRow('Código Único:', codigo),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Estado: ',
                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: esActivo ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: esActivo ? Colors.greenAccent : Colors.orangeAccent,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      estado.toUpperCase(),
                      style: TextStyle(
                        color: esActivo ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'CERRAR',
                style: TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFichaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.cyanAccent, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
