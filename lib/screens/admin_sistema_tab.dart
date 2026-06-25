import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_sistema_screen.dart';
import 'branding_editor_screen.dart';
import 'seguridad_admin_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_bitacora_alertas_screen.dart';
import 'admin_creador_notificaciones_screen.dart';
import 'admin_megafono_screen.dart';
import 'admin_guia_educador_screen.dart';
import 'admin_alertas_seguridad_screen.dart';

class AdminSistemaTab extends StatelessWidget {
  const AdminSistemaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildSectionHeader('🔧 MÓDULO SISTEMA', 'Configuración, seguridad y herramientas'),
        const SizedBox(height: 16),

        // Configuración principal
        _buildNavCard(
          context,
          icon: Icons.settings_rounded,
          color: Colors.blueGrey,
          title: 'Configuración General',
          subtitle: 'API keys, Mercado Pago, parámetros de la app',
          screen: const AdminSistemaScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.palette_rounded,
          color: Colors.purple,
          title: 'Branding & Apariencia',
          subtitle: 'Logo, colores, fondo de pantalla, tipografía',
          screen: const BrandingEditorScreen(),
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('SEGURIDAD Y ACCESO'),
        const SizedBox(height: 10),

        _buildNavCard(
          context,
          icon: Icons.security_rounded,
          color: Colors.redAccent,
          title: 'Seguridad & Roles',
          subtitle: 'Permisos, roles admin y control de acceso',
          screen: const SeguridadAdminScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.shield_rounded,
          color: Colors.orange,
          title: 'Alertas de Seguridad',
          subtitle: 'Intentos de acceso, anomalías y reportes',
          screen: const AdminAlertasSeguridadScreen(),
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('COMUNICACIONES'),
        const SizedBox(height: 10),

        _buildNavCard(
          context,
          icon: Icons.campaign_rounded,
          color: const Color(0xFF00E676),
          title: 'Crear Notificación',
          subtitle: 'Enviar notificación a un usuario específico',
          screen: const AdminCreadorNotificacionesScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.cell_tower_rounded,
          color: Colors.teal,
          title: 'Megáfono — Broadcast',
          subtitle: 'Notificaciones masivas a todos los usuarios',
          screen: const AdminMegafonoScreen(),
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('AUDITORÍA Y LOGS'),
        const SizedBox(height: 10),

        _buildNavCard(
          context,
          icon: Icons.receipt_long_rounded,
          color: Colors.blueAccent,
          title: 'Logs del Sistema',
          subtitle: 'Registro de operaciones y errores técnicos',
          screen: const AdminLogsScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.history_edu_rounded,
          color: Colors.amber,
          title: 'Bitácora de Alertas',
          subtitle: 'Historial de alertas y eventos del sistema',
          screen: const AdminBitacoraAlertasScreen(),
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('FORMACIÓN'),
        const SizedBox(height: 10),

        _buildNavCard(
          context,
          icon: Icons.school_rounded,
          color: const Color(0xFF6B73FF),
          title: 'El Guía Educador',
          subtitle: 'Contenido educativo — modo copiloto offline',
          screen: const AdminGuiaEducadorScreen(),
          badge: 'IA GROQ',
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
    String? badge,
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
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: color.withOpacity(0.5)),
                          ),
                          child: Text(badge,
                              style: GoogleFonts.outfit(
                                  color: color,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ],
                  ),
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
