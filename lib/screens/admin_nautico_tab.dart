import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_viajes_screen.dart';
import 'admin_tracking_screen.dart';
import 'admin_calificaciones_screen.dart';
import 'admin_perfiles_aprobacion_screen.dart';
import 'documentos_pendientes_screen.dart';
import 'admin_centro_computos_screen.dart';
import 'comando_operativo_screen.dart';
import 'admin_alertas_screen.dart';

class AdminNauticoTab extends StatelessWidget {
  const AdminNauticoTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildSectionHeader('⚓ MÓDULO NÁUTICO', 'Gestión de viajes, capitanes y documentación'),
        const SizedBox(height: 16),

        _buildNavCard(
          context,
          icon: Icons.sailing_rounded,
          color: const Color(0xFF00E676),
          title: 'Viajes e Invitados',
          subtitle: 'Monitorear todos los viajes programados y en curso',
          badge: null,
          screen: const AdminViajesScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.local_shipping_rounded,
          color: Colors.blueGrey,
          title: 'Seguimiento envíos tienda',
          subtitle: 'Códigos de tracking de pedidos de la tienda',
          badge: null,
          screen: const AdminTrackingScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.gps_fixed_rounded,
          color: Colors.blueAccent,
          title: 'Recorrido GPS de viajes',
          subtitle: 'Auditoría de rutas náuticas en curso o finalizadas',
          badge: null,
          screen: const AdminViajesScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.verified_user_rounded,
          color: Colors.orange,
          title: 'Aprobación de Perfiles',
          subtitle: 'Validar capitanes y pescadores nuevos',
          badge: 'URGENTE',
          screen: const AdminPerfilValidationScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.description_rounded,
          color: Colors.purple,
          title: 'Documentos Pendientes',
          subtitle: 'Revisar habilitaciones náuticas y documentación',
          badge: null,
          screen: const DocumentosPendientesScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.monitor_heart_rounded,
          color: Colors.orangeAccent,
          title: 'Centro de Cómputos',
          subtitle: 'Vencimientos, suspensiones y auditoría náutica',
          badge: null,
          screen: const AdminCentroComputosScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.star_rounded,
          color: const Color(0xFFFFD700),
          title: 'Calificaciones',
          subtitle: 'Ranking y moderación de reseñas de capitanes',
          badge: null,
          screen: const AdminCalificacionesScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.radar_rounded,
          color: Colors.redAccent,
          title: 'Alertas Náuticas',
          subtitle: 'Avisos de condiciones climáticas y seguridad',
          badge: null,
          screen: const AdminAlertasScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.map_rounded,
          color: Colors.teal,
          title: 'Comando Geoespacial',
          subtitle: 'Inteligencia de flota, territorio y zonas de pesca',
          badge: null,
          screen: const ComandoOperativoScreen(),
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
        Text(subtitle,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildNavCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String? badge,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            style: GoogleFonts.outfit(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                          ),
                          child: Text(badge,
                              style: GoogleFonts.outfit(
                                  color: Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
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
