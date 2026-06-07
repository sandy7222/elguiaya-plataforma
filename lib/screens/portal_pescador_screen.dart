import 'dart:async';
import 'package:flutter/material.dart';
import 'categories_grid_screen.dart';
import 'chat_unificado_screen.dart';
import '../widgets/map_selector_widget.dart';
import '../widgets/ia_status_badge.dart';
import 'pescador_dashboard_screen.dart';
import 'bienvenida_definitiva_screen.dart';
import '../services/supabase_service.dart';
import '../services/branding_service.dart';
import '../services/ia_router_state.dart';
import '../widgets/notification_quick_view.dart';

class PortalPescadorScreen extends StatefulWidget {
  const PortalPescadorScreen({super.key});

  @override
  State<PortalPescadorScreen> createState() => _PortalPescadorScreenState();
}

class _PortalPescadorScreenState extends State<PortalPescadorScreen> {
  int _selectedIndex = 0;
  String _userName = 'Cargando...';
  Map<String, dynamic>? _initialQuoteData;

  // Branding
  String? _backgroundUrl;
  double _opacity = 0.5;
  double _brightness = 1.0;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _cargarBranding();
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
      debugPrint('Error al cargar branding en Portal Pescador: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = SupabaseService.supabase.auth.currentUser;
      if (user != null) {
        final metaNombre = user.userMetadata?['nombre'] ?? user.userMetadata?['full_name'];
        if (metaNombre != null && mounted) {
          setState(() => _userName = metaNombre);
          return;
        }
        final profile = await SupabaseService.supabase
            .from('profiles')
            .select('es_capitan, estado')
            .eq('user_id', user.id)
            .maybeSingle();
        if (profile != null && mounted) {
          setState(() => _userName = 'Laura');
        }
      }
    } catch (e) {
      debugPrint('Error cargando perfil: $e');
      if (mounted) setState(() => _userName = 'Laura');
    }
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        PescadorDashboardScreen(initialQuoteData: _initialQuoteData),
        _MapSection(
          onRequestQuote: (partida, destino, trackLog, distancia) {
            setState(() {
              _initialQuoteData = {
                'partida': partida,
                'destino': destino,
                'trackLog': trackLog,
                'distancia': distancia,
              };
              _selectedIndex = 0;
            });
          },
        ),
        const CategoriesGridScreen(),
        const ChatUnificadoScreen(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      extendBody: true,
      appBar: AppBar(
        title: const Text(
          'Capitan YA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        actions: [
          const IAStatusBadge(),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Cerrar Sesion',
            onPressed: () async {
              await SupabaseService.supabase.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const BienvenidaDefinitivaScreen()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF001529), Color(0xFF001F3F)],
          ),
        ),
        child: _buildBody(),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            backgroundColor: const Color(0xFF001529).withOpacity(0.95),
            selectedItemColor: const Color(0xFF00E676),
            unselectedItemColor: Colors.white60,
            type: BottomNavigationBarType.fixed,
            elevation: 0,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.sailing_rounded),
                label: 'Mis Viajes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.map_rounded),
                label: 'Mapa de Ruta',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.grid_view_rounded),
                label: 'Tienda',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.smart_toy_rounded),
                label: 'El Guía',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Sub-widget para la seccion de Mapa
class _MapSection extends StatefulWidget {
  final Function(Map<String, dynamic> partida, Map<String, dynamic> destino, List<Map<String, dynamic>> trackLog, double distancia) onRequestQuote;

  const _MapSection({required this.onRequestQuote});

  @override
  State<_MapSection> createState() => _MapSectionState();
}

class _MapSectionState extends State<_MapSection> {
  Map<String, dynamic>? _partida;
  Map<String, dynamic>? _destino;
  List<Map<String, dynamic>> _trackLog = [];
  double _distancia = 0.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MapSelectorWidget(
          onRouteSelected: (p0, p1, p2) {
            setState(() {
              _partida = p0;
              _destino = p1;
              _trackLog = p2;
            });
          },
          onDistanceChanged: (dist) {
            setState(() {
              _distancia = dist;
            });
          },
        ),
        if (_partida != null && _destino != null)
          Positioned(
            bottom: 80,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: () {
                widget.onRequestQuote(_partida!, _destino!, _trackLog, _distancia);
              },
              icon: const Icon(Icons.request_quote),
              label: const Text('PEDIR PRESUPUESTO AHORA'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
              ),
            ),
          ),
      ],
    );
  }
}
