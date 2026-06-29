

import 'package:flutter/material.dart';

import 'inbox_capitan_screen.dart';
import 'capitan_panel_screen.dart';
import 'categories_grid_screen.dart';
import 'capitan_tracker_screen.dart';
import 'capitan_saldos_screen.dart';
import 'portal_capitan_suspendido_screen.dart';
import 'viajes_programados_screen.dart';
import 'bienvenida_definitiva_screen.dart';
import '../services/fcm_service.dart';
import '../services/branding_service.dart';
import '../services/supabase_service.dart';
import '../utils/view_insets.dart';
import '../widgets/el_guia_ya_home_button.dart';
import '../widgets/notification_quick_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PortalCapitanScreen extends StatefulWidget {
  const PortalCapitanScreen({super.key});

  @override
  State<PortalCapitanScreen> createState() => _PortalCapitanScreenState();
}

class _PortalCapitanScreenState extends State<PortalCapitanScreen> {
  int _selectedIndex = 0;
  String _estado = 'activo';
  final GlobalKey<CapitanSaldosScreenState> _saldosKey =
      GlobalKey<CapitanSaldosScreenState>();
  
  // Branding variables
  String? _backgroundUrl;
  double _opacity = 0.5;
  double _brightness = 1.0;
  final Color _azulVibrante = const Color(0xFF0066FF);
  final Color _blancoPuro = const Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _verificarAcceso(); // CANDADO DE SEGURIDAD
    _cargarBranding();
  }

  Future<void> _verificarAcceso() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _expulsar();
        return;
      }

      // Garantizar que el token FCM esté registrado para push notifications fuera de la app
      FCMService.registrarDispositivo();

      // Consultar estado en tiempo real
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('estado')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profile == null) {
        _expulsar();
        return;
      }

      final String estado = profile['estado'] ?? 'pendiente';
      
      if (mounted) {
        setState(() {
          _estado = estado;
        });
      }

      if (estado != 'activo' && estado != 'suspendido' && estado != 'en_revision') {
        print('🚫 [SEGURIDAD] Acceso no autorizado al Portal. Estado: $estado');
        _expulsar();
      }
    } catch (e) {
      print('⚠️ Error en verificación de acceso: $e');
      _expulsar();
    }
  }

  void _expulsar() async {
    await SupabaseService.signOut();
    if (mounted) {
      Navigator.of(context).pushNamedAndRemoveUntil('/bienvenida', (route) => false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Acceso Restringido: Tu perfil está siendo revisado por un administrador.'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cargarBranding() async {
    try {
      final config = await BrandingService.getLoginConfig();
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
          _brightness = config.brightness;
        });
      }
    } catch (e) {
      print('Error al cargar branding en Portal Capitan: $e');
    }
  }

  void _irAlPanel() {
    setState(() => _selectedIndex = 0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      extendBody: true,
      appBar: AppBar(
        title: ElGuiaYaHomeButton(
          onTap: _irAlPanel,
          tooltip: 'Ir al Principal',
          semanticsLabel: 'Ir al Panel del Capitán',
        ),
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        actions: [
          const NotificationQuickView(),
          IconButton(
            icon: const Icon(Icons.event_available, color: Color(0xFF00E676)),
            tooltip: 'Mi Agenda de Viajes',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ViajesProgramadosScreen(esCapitan: true),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await SupabaseService.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(
                    builder: (context) => const BienvenidaDefinitivaScreen(),
                  ),
                  (route) => false,
                );
              }
            },
          ),
          SizedBox(width: ViewInsets.portalHeaderHorizontal),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF001F3F), // Azul Capitan Profundo
              Color(0xFF003366), // Azul Navy
            ],
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            const CapitanPanelScreen(),
            const CategoriesGridScreen(),
            CapitanSaldosScreen(key: _saldosKey, showAppBar: false),
            _estado == 'activo'
                ? const InboxCapitanScreen(showAppBar: false)
                : const PortalCapitanSuspendidoScreen(),
            const CapitanTrackerScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          // Margen de seguridad para alejar los botones digitales del celular
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: _blancoPuro.withOpacity(0.1), width: 0.5),
            ),
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() {
                _selectedIndex = index;
              });
              if (index == 2) {
                _saldosKey.currentState?.refrescar();
              }
            },
            backgroundColor: Colors.black.withOpacity(0.8),
            selectedItemColor: _azulVibrante,
            unselectedItemColor: Colors.white.withOpacity(0.5),
            type: BottomNavigationBarType.fixed,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_outlined),
                activeIcon: Icon(Icons.dashboard),
                label: 'Principal',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.shopping_bag_outlined),
                activeIcon: Icon(Icons.shopping_bag),
                label: 'Tienda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_balance_wallet_outlined),
                activeIcon: Icon(Icons.account_balance_wallet),
                label: 'Ganancias',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.request_quote_outlined),
                activeIcon: Icon(Icons.request_quote),
                label: 'Cotizaciones',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_outlined),
                activeIcon: Icon(Icons.map),
                label: 'Tracker',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
