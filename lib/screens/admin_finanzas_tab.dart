import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_liquidacion_screen.dart';
import 'admin_reembolsos_screen.dart';
import 'admin_disputas_screen.dart';
import 'admin_comisionistas_screen.dart';
import 'admin_sales_monitor_screen.dart';
import 'admin_cierres_screen.dart';

class AdminFinanzasTab extends StatelessWidget {
  const AdminFinanzasTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildSectionHeader('💰 MÓDULO FINANZAS', 'Liquidaciones, pagos, disputas y comisiones'),
        const SizedBox(height: 16),

        _buildNavCard(
          context,
          icon: Icons.payments_rounded,
          color: const Color(0xFF00E676),
          title: 'Liquidaciones',
          subtitle: 'Gestión de pagos a capitanes por período',
          screen: const AdminLiquidacionScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.bar_chart_rounded,
          color: Colors.blueAccent,
          title: 'Monitor de Ventas',
          subtitle: 'Estadísticas y rendimiento comercial',
          screen: const AdminSalesMonitorScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.lock_clock_rounded,
          color: const Color(0xFF0D47A1),
          title: 'Cierres de Caja',
          subtitle: 'Cierres diarios y períodos contables',
          screen: const AdminCierresScreen(),
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('GESTIÓN DE CONFLICTOS'),
        const SizedBox(height: 10),

        _buildNavCard(
          context,
          icon: Icons.gavel_rounded,
          color: Colors.redAccent,
          title: 'Disputas',
          subtitle: 'Resolver conflictos entre pescadores y capitanes',
          screen: const AdminDisputasScreen(),
          urgentBadge: true,
        ),
        _buildNavCard(
          context,
          icon: Icons.settings_backup_restore_rounded,
          color: Colors.orangeAccent,
          title: 'Reembolsos',
          subtitle: 'Solicitudes de devolución y compensaciones',
          screen: const AdminReembolsosScreen(),
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('RED COMERCIAL'),
        const SizedBox(height: 10),

        _buildNavCard(
          context,
          icon: Icons.supervised_user_circle_rounded,
          color: Colors.purple,
          title: 'Promotores y Comisionistas',
          subtitle: 'Gestión de la red de referidos y comisiones',
          screen: const AdminComisionistasScreen(),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(subtitle, style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.outfit(
            color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5));
  }

  Widget _buildNavCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
    bool urgentBadge = false,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: urgentBadge ? color.withOpacity(0.1) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: urgentBadge ? color.withOpacity(0.4) : Colors.white.withOpacity(0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
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
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
