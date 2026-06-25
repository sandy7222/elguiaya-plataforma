import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/branding_service.dart';
import '../widgets/admin_telemetry_fab.dart';
import '../widgets/notification_quick_view.dart';
import 'admin_home_tab.dart';
import 'admin_nautico_tab.dart';
import 'admin_tienda_tab.dart';
import 'admin_finanzas_tab.dart';
import 'admin_sistema_tab.dart';
import 'admin_creador_notificaciones_screen.dart';
import 'admin_bitacora_alertas_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;
  String? _backgroundUrl;
  // ignore: unused_field

  final _modules = const [
    _AdminModule(
      icon: Icons.dashboard_rounded,
      label: 'Home',
      color: Color(0xFF00E676),
    ),
    _AdminModule(
      icon: Icons.anchor_rounded,
      label: 'Náutico',
      color: Color(0xFF29B6F6),
    ),
    _AdminModule(
      icon: Icons.storefront_rounded,
      label: 'Tienda',
      color: Color(0xFF9C27B0),
    ),
    _AdminModule(
      icon: Icons.payments_rounded,
      label: 'Finanzas',
      color: Color(0xFFFFD700),
    ),
    _AdminModule(
      icon: Icons.settings_rounded,
      label: 'Sistema',
      color: Color(0xFF78909C),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _cargarBranding();
  }

  Future<void> _cargarBranding() async {
    try {
      final config = await BrandingService.getLoginConfig();
      if (mounted) setState(() => _backgroundUrl = config.backgroundUrl);
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF001830),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('¿Cerrar sesión?', style: TextStyle(color: Colors.white)),
        content: const Text('Volverás al login.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFF0D47A1),
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Container(
        decoration: _buildBg(),
        child: SafeArea(
          child: IndexedStack(
            index: _selectedIndex,
            children: const [
              AdminHomeTab(),
              AdminNauticoTab(),
              AdminTiendaTab(),
              AdminFinanzasTab(),
              AdminSistemaTab(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: const AdminTelemetryFAB(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final mod = _modules[_selectedIndex];
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1).withOpacity(0.85),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.12), width: 0.5),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Menú hamburguesa
                    Builder(
                      builder: (ctx) => GestureDetector(
                        onTap: () => Scaffold.of(ctx).openDrawer(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: mod.color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: mod.color.withOpacity(0.3)),
                          ),
                          child: Icon(Icons.menu_rounded, color: mod.color, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Título del módulo activo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'EL GUIA YA',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            mod.label.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: mod.color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Acciones rápidas
                    _appBarAction(Icons.campaign_rounded, 'Notificar', () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AdminCreadorNotificacionesScreen()));
                    }),
                    const NotificationQuickView(),
                    _appBarAction(Icons.history_edu_rounded, 'Bitácora', () {
                      Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const AdminBitacoraAlertasScreen()));
                    }),
                    _appBarAction(Icons.logout_rounded, 'Salir', _signOut),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF001830),
      child: Column(
        children: [
          // Header del drawer
          Container(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D47A1), Color(0xFF001830)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.5), width: 2),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFF00E676), size: 28),
                ),
                const SizedBox(height: 12),
                Text('Admin Master',
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('CENTRO ADMINISTRATIVO',
                    style: GoogleFonts.outfit(
                        color: Colors.white38, fontSize: 10, letterSpacing: 1.5)),
              ],
            ),
          ),

          // Módulos
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
              itemCount: _modules.length,
              itemBuilder: (_, i) {
                final mod = _modules[i];
                final selected = _selectedIndex == i;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedIndex = i);
                    Navigator.pop(context);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      color: selected ? mod.color.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? mod.color.withOpacity(0.4) : Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(mod.icon,
                            color: selected ? mod.color : Colors.white38, size: 22),
                        const SizedBox(width: 14),
                        Text(
                          mod.label,
                          style: GoogleFonts.outfit(
                            color: selected ? Colors.white : Colors.white60,
                            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 15,
                          ),
                        ),
                        if (selected) ...[
                          const Spacer(),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(color: mod.color, shape: BoxShape.circle),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Cerrar sesión al fondo
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _signOut();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 20),
                    const SizedBox(width: 14),
                    Text('Cerrar Sesión',
                        style: GoogleFonts.outfit(
                            color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0A1628),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -2)),
        ],
      ),
      child: Row(
        children: List.generate(_modules.length, (i) {
          final mod = _modules[i];
          final selected = _selectedIndex == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedIndex = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: selected ? mod.color : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(mod.icon,
                        color: selected ? mod.color : Colors.white24,
                        size: selected ? 24 : 20),
                    const SizedBox(height: 3),
                    Text(
                      mod.label,
                      style: GoogleFonts.outfit(
                        color: selected ? mod.color : Colors.white24,
                        fontSize: 9,
                        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _appBarAction(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, color: Colors.white60, size: 20),
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
    );
  }

  BoxDecoration _buildBg() {
    if (_backgroundUrl != null && _backgroundUrl!.isNotEmpty) {
      return BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(_backgroundUrl!),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            const Color(0xFF0D47A1).withOpacity(0.7),
            BlendMode.multiply,
          ),
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF0D2B6B), Color(0xFF001030)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
  }
}

class _AdminModule {
  final IconData icon;
  final String label;
  final Color color;
  const _AdminModule({required this.icon, required this.label, required this.color});
}
