import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/pronostico_mini_widget.dart';
import 'admin_viajes_screen.dart';
import 'admin_perfiles_aprobacion_screen.dart';
import 'admin_disputas_screen.dart';
import 'admin_tracking_screen.dart';

class AdminHomeTab extends StatefulWidget {
  const AdminHomeTab({super.key});

  @override
  State<AdminHomeTab> createState() => _AdminHomeTabState();
}

class _AdminHomeTabState extends State<AdminHomeTab> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;

  // KPIs reales
  int _viajesActivos = 0;
  int _cotizacionesPendientes = 0;
  int _perfilesPendientes = 0;
  int _disputasAbiertas = 0;
  double _ingresosMes = 0;
  int _totalPescadores = 0;
  int _totalCapitanes = 0;
  int _viajesHoy = 0;

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _cargarKPIs();
    _setupRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _setupRealtime() {
    _channel = _supabase
        .channel('admin-home-kpis')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedidos',
          callback: (_) => _cargarKPIs(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cotizaciones',
          callback: (_) => _cargarKPIs(),
        )
        .subscribe();
  }

  Future<void> _cargarKPIs() async {
    try {
      final ahora = DateTime.now();
      final inicioMes = DateTime(ahora.year, ahora.month, 1).toIso8601String();
      final hoyInicio = DateTime(ahora.year, ahora.month, ahora.day).toIso8601String();
      final hoyFin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59).toIso8601String();

      // Viajes activos
      final viajesActivos = await _supabase
          .from('pedidos')
          .select('id')
          .eq('estado', 'en_curso');

      // Viajes de hoy
      final viajesHoy = await _supabase
          .from('pedidos')
          .select('id')
          .gte('fecha_servicio', hoyInicio)
          .lte('fecha_servicio', hoyFin);

      // Cotizaciones esperando respuesta del capitán
      final cotPendientes = await _supabase
          .from('cotizaciones')
          .select('id')
          .eq('estado', 'pendiente');

      // Perfiles capitán pendientes de verificación
      final perfilesPend = await _supabase
          .from('profiles')
          .select('user_id')
          .eq('es_capitan', true)
          .or('estado.eq.pendiente,estado.eq.en_revision');

      // Disputas abiertas
      int disputas = 0;
      try {
        final disp = await _supabase
            .from('disputas')
            .select('id')
            .eq('estado', 'abierta');
        disputas = (disp as List).length;
      } catch (_) {}

      // Ingresos del mes (suma de pedidos cerrados)
      double ingresos = 0;
      try {
        final pagos = await _supabase
            .from('pedidos')
            .select('monto_total')
            .inFilter('estado', ['cerrado', 'pagado', 'listo_para_confirmar'])
            .gte('created_at', inicioMes);
        for (final p in (pagos as List)) {
          ingresos += (p['monto_total'] as num?)?.toDouble() ?? 0;
        }
      } catch (_) {}

      // Usuarios totales
      int pescadores = 0;
      int capitanes = 0;
      try {
        final perfs = await _supabase.from('profiles').select('es_capitan');
        for (final p in (perfs as List)) {
          if (p['es_capitan'] == true) {
            capitanes++;
          } else {
            pescadores++;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _viajesActivos = (viajesActivos as List).length;
          _viajesHoy = (viajesHoy as List).length;
          _cotizacionesPendientes = (cotPendientes as List).length;
          _perfilesPendientes = (perfilesPend as List).length;
          _disputasAbiertas = disputas;
          _ingresosMes = ingresos;
          _totalPescadores = pescadores;
          _totalCapitanes = capitanes;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargarKPIs,
      color: const Color(0xFF00E676),
      backgroundColor: const Color(0xFF0D47A1),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── ALERTA URGENTE (si hay algo crítico) ─────────────────
            if (_perfilesPendientes > 0 || _disputasAbiertas > 0)
              _buildUrgencyBanner(),

            const SizedBox(height: 16),

            // ── PRONÓSTICO ────────────────────────────────────────────
            const PronosticoMiniWidget(),

            const SizedBox(height: 20),

            // ── KPIs OPERATIVOS (grid 2x2) ───────────────────────────
            _buildSectionTitle('⚡ OPERACIONES EN TIEMPO REAL'),
            const SizedBox(height: 12),
            _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpi(
                              icon: Icons.sailing_rounded,
                              label: 'Viajes activos',
                              value: _viajesActivos.toString(),
                              color: const Color(0xFF00E676),
                              urgent: _viajesActivos > 0,
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const AdminViajesScreen())),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpi(
                              icon: Icons.today_rounded,
                              label: 'Viajes hoy',
                              value: _viajesHoy.toString(),
                              color: Colors.blueAccent,
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => const AdminViajesScreen())),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildKpi(
                              icon: Icons.request_quote_rounded,
                              label: 'Cotizaciones pendientes',
                              value: _cotizacionesPendientes.toString(),
                              color: Colors.orangeAccent,
                              urgent: _cotizacionesPendientes > 5,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildKpi(
                              icon: Icons.gavel_rounded,
                              label: 'Disputas abiertas',
                              value: _disputasAbiertas.toString(),
                              color: Colors.redAccent,
                              urgent: _disputasAbiertas > 0,
                              onTap: _disputasAbiertas > 0
                                  ? () => Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => const AdminDisputasScreen()))
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

            const SizedBox(height: 24),

            // ── INGRESOS + USUARIOS ───────────────────────────────────
            _buildSectionTitle('💰 RESUMEN DEL MES'),
            const SizedBox(height: 12),
            _buildIngresosCard(),

            const SizedBox(height: 24),

            // ── COMUNIDAD ─────────────────────────────────────────────
            _buildSectionTitle('👥 COMUNIDAD'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildKpi(
                    icon: Icons.people_rounded,
                    label: 'Pescadores',
                    value: _totalPescadores.toString(),
                    color: Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildKpi(
                    icon: Icons.anchor_rounded,
                    label: 'Capitanes',
                    value: _totalCapitanes.toString(),
                    color: const Color(0xFF0D47A1),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── ACCESOS RÁPIDOS URGENTES ──────────────────────────────
            _buildSectionTitle('🚨 ACCIONES RÁPIDAS'),
            const SizedBox(height: 12),
            _buildAccionesRapidas(),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyBanner() {
    final msgs = <String>[];
    if (_perfilesPendientes > 0) msgs.add('$_perfilesPendientes perfil(es) esperan verificación');
    if (_disputasAbiertas > 0) msgs.add('$_disputasAbiertas disputa(s) sin resolver');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '⚠️ REQUIERE ATENCIÓN',
                  style: GoogleFonts.outfit(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
                ...msgs.map((m) => Text(m,
                    style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.outfit(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildKpi({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool urgent = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: urgent ? color.withOpacity(0.18) : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: urgent ? color.withOpacity(0.6) : Colors.white.withOpacity(0.1),
            width: urgent ? 1.5 : 1,
          ),
          boxShadow: urgent
              ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 8, spreadRadius: 1)]
              : [],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                if (onTap != null) ...[
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 12),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: GoogleFonts.outfit(
                color: color,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngresosCard() {
    final fmt = NumberFormat.currency(locale: 'es_AR', symbol: '\$', decimalDigits: 0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00E676).withOpacity(0.15),
            const Color(0xFF0066FF).withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INGRESOS DEL MES',
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _loading ? '...' : fmt.format(_ingresosMes),
                  style: GoogleFonts.outfit(
                    color: const Color(0xFF00E676),
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'Suma de viajes cerrados y pagados',
                  style: GoogleFonts.outfit(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.trending_up_rounded, color: Color(0xFF00E676), size: 40),
        ],
      ),
    );
  }

  Widget _buildAccionesRapidas() {
    final acciones = [
      (
        Icons.verified_user_rounded,
        'Verificar Capitanes',
        _perfilesPendientes > 0 ? '$_perfilesPendientes pendientes' : 'Sin pendientes',
        Colors.orange,
        _perfilesPendientes > 0,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminPerfilValidationScreen())),
      ),
      (
        Icons.gps_fixed_rounded,
        'Tracking GPS',
        'Ver viajes en mapa',
        Colors.blueAccent,
        false,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminTrackingScreen())),
      ),
      (
        Icons.gavel_rounded,
        'Disputas',
        _disputasAbiertas > 0 ? '$_disputasAbiertas sin resolver' : 'Todo ok',
        Colors.redAccent,
        _disputasAbiertas > 0,
        () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const AdminDisputasScreen())),
      ),
    ];

    return Column(
      children: acciones.map((a) {
        final icon = a.$1;
        final title = a.$2;
        final subtitle = a.$3;
        final color = a.$4;
        final urgent = a.$5;
        final onTap = a.$6;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: urgent ? color.withOpacity(0.12) : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: urgent ? color.withOpacity(0.5) : Colors.white.withOpacity(0.08),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(subtitle,
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ),
                if (urgent)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
