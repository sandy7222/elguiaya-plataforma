import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'categories_grid_screen.dart';
import 'chat_unificado_screen.dart';
import '../widgets/map_selector_widget.dart';
import '../widgets/ia_status_badge.dart';
import 'pescador_dashboard_screen.dart';
import 'mis_viajes_screen.dart';
import 'bienvenida_definitiva_screen.dart';
import '../services/supabase_service.dart';
import '../services/branding_service.dart';
import '../services/ia_router_state.dart';
import '../widgets/notification_quick_view.dart';
import 'capitan_tracker_screen.dart';

class PortalPescadorScreen extends StatefulWidget {
  const PortalPescadorScreen({super.key});

  @override
  State<PortalPescadorScreen> createState() => _PortalPescadorScreenState();
}

class _PortalPescadorScreenState extends State<PortalPescadorScreen> {
  int _selectedIndex = 0;
  String _userName = 'Cargando...';
  Map<String, dynamic>? _initialQuoteData;
  bool _gpsYaSolicitado = false; // Evita mostrar el diálogo más de una vez por sesión

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

  /// Abre el formulario de nueva cotización como modal sobre el portal,
  /// sin navegar a otra pantalla. El bottom nav sigue visible al volver.
  void _abrirFormularioNuevaSolicitud() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FormularioCotizacionTecnica(
        onSubmit: (datos) async {
          try {
            final resultado =
                await SupabaseService.crearCotizacionTecnica(datos);
            if (!mounted) return;
            Navigator.pop(context); // Cierra el modal
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Center(
                  child: Text(
                    resultado['exito'] == true
                        ? '✅ Solicitud creada. Los capitánes ya pueden cotizar.'
                        : '⚠️ ${resultado['mensaje'] ?? 'Error al crear solicitud'}',
                  ),
                ),
                backgroundColor: resultado['exito'] == true
                    ? const Color(0xFF10B981)
                    : Colors.red,
              ),
            );
          } catch (e) {
            if (!mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        initialPuntoPartida: _initialQuoteData?['partida'],
        initialPuntoDestino: _initialQuoteData?['destino'],
        initialTrackLog: _initialQuoteData?['trackLog'],
        initialDistanciaKM: _initialQuoteData?['distancia'] as double?,
      ),
    );
  }

  /// Pide permiso de GPS solo al abrir el mapa por primera vez.
  /// Muestra un diálogo propio explicativo ANTES del diálogo del sistema operativo.
  Future<void> _solicitarGPSParaMapa() async {
    // Si ya lo pedimos esta sesión, no volver a molestar
    if (_gpsYaSolicitado) return;

    // Si ya tiene permiso concedido, no hay nada que pedir
    final permiso = await Geolocator.checkPermission();
    if (permiso == LocationPermission.always ||
        permiso == LocationPermission.whileInUse) {
      _gpsYaSolicitado = true;
      return;
    }

    // Si el permiso está bloqueado permanentemente, no podemos hacer nada
    if (permiso == LocationPermission.deniedForever) {
      _gpsYaSolicitado = true;
      return;
    }

    // Mostrar diálogo propio antes de disparar el del sistema operativo
    if (!mounted) return;
    final aceptado = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF001529),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.map_rounded, color: Color(0xFF00E676), size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '¿Usamos tu ubicación?',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'Para mostrarte capitanes cerca de donde estás y trazar tu ruta de pesca, necesitamos acceder a tu GPS.\n\nSolo se activa cuando usás el mapa.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'No por ahora',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.gps_fixed_rounded, size: 18),
            label: const Text('Activar GPS'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E676),
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );

    _gpsYaSolicitado = true; // No volver a preguntar, sin importar la respuesta

    // Solo si el usuario aceptó, disparamos el diálogo real del sistema operativo
    if (aceptado == true) {
      await Geolocator.requestPermission();
    }
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _selectedIndex,
      children: [
        // Pestaña 0: Panel principal del Pescador (entrada de sesión)
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
          'EL GUIA YA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        actions: [
          const IAStatusBadge(),
          const NotificationQuickView(),
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
            onTap: (index) async {
              // Índice 1 = Mapa de Ruta: pedir GPS en contexto antes de mostrarlo
              if (index == 1) {
                await _solicitarGPSParaMapa();
              }
              if (mounted) setState(() => _selectedIndex = index);
            },
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
  int _selectedSubTab = 0; // 0 = Trazar Ruta (MapSelectorWidget), 1 = GPS Tracker (CapitanTrackerScreen)

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Sub-tabs deslizantes premium estilo glassmorphism
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
          child: Container(
            height: 44,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSubTab = 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _selectedSubTab == 0 ? const Color(0xFF00E676) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _selectedSubTab == 0
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.explore_outlined,
                            size: 16,
                            color: _selectedSubTab == 0 ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'TRAZAR RUTA',
                            style: TextStyle(
                              color: _selectedSubTab == 0 ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSubTab = 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: _selectedSubTab == 1 ? const Color(0xFF00E676) : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: _selectedSubTab == 1
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00E676).withOpacity(0.3),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                )
                              ]
                            : [],
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.radar_rounded,
                            size: 16,
                            color: _selectedSubTab == 1 ? Colors.black : Colors.white70,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'GPS TRACKER',
                            style: TextStyle(
                              color: _selectedSubTab == 1 ? Colors.black : Colors.white70,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Contenido utilizando IndexedStack para preservar el estado de ambos mapas
        Expanded(
          child: IndexedStack(
            index: _selectedSubTab,
            children: [
              // Sub-pestaña 0: Trazado de ruta
              Stack(
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
                      bottom: 90,
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
              ),
              // Sub-pestaña 1: GPS Tracker del Pescador
              const CapitanTrackerScreen(esCapitan: false),
            ],
          ),
        ),
      ],
    );
  }
}
