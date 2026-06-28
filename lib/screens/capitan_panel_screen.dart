import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';

import '../models/cotizacion.dart';
import '../models/perfil_capitan.dart';
import '../services/supabase_service.dart';
import '../widgets/pronostico_mini_widget.dart';
import '../widgets/solunar_card_widget.dart';
import 'capitan_perfil_edit_screen.dart';
import 'capitan_identidad_screen.dart';
import 'capitan_zona_config_screen.dart';
import 'viajes_programados_screen.dart';
import '../services/viaje_lifecycle_service.dart';
import '../services/viaje_gps_coordinator.dart';
import '../services/core_business_logic.dart';
import 'solicitud_detalle_screen.dart';
import '../widgets/notification_quick_view.dart';
import '../widgets/calendario_viajes_widget.dart';
import '../utils/view_insets.dart';
import 'mi_calendario_screen.dart'; // Pantalla de administración de disponibilidad del Capitán (Almanaque)
import 'capitan_vidriera_screen.dart'; // Pantalla de la Góndola del Capitán
import '../widgets/calificacion_pescador_dialog.dart';
import '../widgets/reputacion_badge_widget.dart';
import '../widgets/safe_button.dart';
import '../widgets/radar_scanner_widget.dart';

class CapitanPanelScreen extends StatefulWidget {
  const CapitanPanelScreen({super.key});

  @override
  State<CapitanPanelScreen> createState() => _CapitanPanelScreenState();
}

class _CapitanPanelScreenState extends State<CapitanPanelScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // -- VARIABLES DE ESTADO UNIFICADAS --
  List<Cotizacion> _cotizaciones = [];
  final List<Cotizacion> _cotizacionesPendientes = [];
  List<Map<String, dynamic>> _leads = [];
  Set<String> _cotizacionesPresupuestadas = {};
  int _unreadLeadsCount = 0;
  bool _isLoading = true;
  bool _guardando = false;
  PerfilCapitan? _perfil;
  RealtimeChannel? _cotizacionesChannel;
  StreamSubscription? _routeNotificationSub;
  String? _mensajeAlertaRuta;
  String _estadoCuenta = 'activo';

  String get _capitanId => SupabaseService.currentUserId ?? '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatos();
    _configurarRealtime();
    _escucharNotificacionesRuta();
    // GPS NO se pide aquí — solo cuando el capitán inicia un tracker de viaje
  }

  void _escucharNotificacionesRuta() {
    _routeNotificationSub = SupabaseService.notificacionesStream.listen((msg) {
      if (mounted) {
        setState(() => _mensajeAlertaRuta = msg);
        // Desaparecer después de 8 segundos
        Future.delayed(const Duration(seconds: 8), () {
          if (mounted) setState(() => _mensajeAlertaRuta = null);
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cotizacionesChannel?.unsubscribe();
    _routeNotificationSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configurarRealtime();
    }
  }

  // -- LÓGICA DE DATOS --

  Future<void> _cargarDatos() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      final perfil = await SupabaseService.getPerfilCapitan(_capitanId);
      _perfil = perfil;

      // Cargar datos de perfil completo para auto-sincronización legada
      final perfilFull = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('user_id', _capitanId)
          .maybeSingle();

      if (perfilFull != null) {
        _estadoCuenta = perfilFull['estado'] ?? 'pendiente';
      }

      if (perfilFull != null && perfilFull['estado'] == 'activo') {
        // Auto-sincronizar el perfil del capitán en la tabla legada 'guias'.
        // Esto se ejecuta bajo la sesión activa del capitán, superando restricciones RLS.
        SupabaseService.traspasarSocioALegado(perfilFull).catchError((e) {
          print('⚠️ [AUTO-SYNC] Error en auto-sincronización del capitán: $e');
        });
      }

      // Auditoría Automática de Vencimientos para el Capitán (Proximidad 5 días)
      if (perfilFull != null) {
        final hoy = DateTime.now();
        
        // 1. Seguro de Embarcación
        if (perfilFull['vencimiento_seguro'] != null) {
          try {
            final fechaSeguro = DateTime.parse(perfilFull['vencimiento_seguro']);
            final diasRestantes = fechaSeguro.difference(hoy).inDays;
            if (diasRestantes >= 0 && diasRestantes <= 5) {
              final formattedDate = '${fechaSeguro.day.toString().padLeft(2, '0')}/${fechaSeguro.month.toString().padLeft(2, '0')}/${fechaSeguro.year}';
              final titulo = '🚨 Vencimiento de Seguro Próximo';
              final mensaje = 'Tu Seguro de Embarcación vencerá el $formattedDate. Por favor renuévalo para evitar la suspensión de tu cuenta.';
              
              final existeNoti = await Supabase.instance.client
                  .from('notificaciones')
                  .select('id')
                  .eq('usuario_id', _capitanId)
                  .eq('titulo', titulo)
                  .eq('leida', false)
                  .maybeSingle();
                  
              if (existeNoti == null) {
                await SupabaseService.enviarNotificacion(
                  usuarioId: _capitanId,
                  titulo: titulo,
                  mensaje: mensaje,
                  tipo: 'viaje',
                );
              }
            }
          } catch (e) {
            print('⚠️ Error al procesar notificación de vencimiento de seguro: $e');
          }
        }
        
        // 2. Carnet de Timonel
        if (perfilFull['vencimiento_carnet'] != null) {
          try {
            final fechaCarnet = DateTime.parse(perfilFull['vencimiento_carnet']);
            final diasRestantes = fechaCarnet.difference(hoy).inDays;
            if (diasRestantes >= 0 && diasRestantes <= 5) {
              final formattedDate = '${fechaCarnet.day.toString().padLeft(2, '0')}/${fechaCarnet.month.toString().padLeft(2, '0')}/${fechaCarnet.year}';
              final titulo = '🚨 Vencimiento de Carnet Próximo';
              final mensaje = 'Tu Carnet de Timonel vencerá el $formattedDate. Por favor renuévalo para evitar la suspensión de tu cuenta.';
              
              final existeNoti = await Supabase.instance.client
                  .from('notificaciones')
                  .select('id')
                  .eq('usuario_id', _capitanId)
                  .eq('titulo', titulo)
                  .eq('leida', false)
                  .maybeSingle();
                  
              if (existeNoti == null) {
                await SupabaseService.enviarNotificacion(
                  usuarioId: _capitanId,
                  titulo: titulo,
                  mensaje: mensaje,
                  tipo: 'viaje',
                );
              }
            }
          } catch (e) {
            print('⚠️ Error al procesar notificación de vencimiento de carnet: $e');
          }
        }
      }

      // 1. Cargar Cotizaciones Propias (las que ya envió)
      final cotizaciones = await SupabaseService.getCotizacionesCapitan(_capitanId);

      // 2. RADAR GEOFENCING: Cargar Leads cercanos (Solicitudes de Pescadores)
      List<Map<String, dynamic>> leads = [];
      if (perfil != null && perfil.latitudCentro != null && perfil.longitudCentro != null && _estadoCuenta == 'activo') {
        leads = await MasterConnectionSkill.getCotizacionesEnZona(
          capitanLat: perfil.latitudCentro!,
          capitanLon: perfil.longitudCentro!,
          radioKm: perfil.radioOperacionKm ?? 50.0,
        );
      } else {
        // Sin zona configurada o cuenta no activa: No hay leads automáticos
        leads = [];
      }

      // 3. Cargar IDs de cotizaciones ya presupuestadas por este capitán
      Set<String> cotizacionesPresupuestadas = {};
      try {
        final responsePresupuestos = await Supabase.instance.client
            .from('presupuestos')
            .select('cotizacion_id')
            .eq('capitan_id', _capitanId);
        
        if (responsePresupuestos != null) {
          cotizacionesPresupuestadas = (responsePresupuestos as List)
              .map((p) => p['cotizacion_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
        }
      } catch (e) {
        print('⚠️ Error al cargar presupuestos del capitán: $e');
      }

      if (mounted) {
        // Contar solicitudes nuevas (leads)
        final nuevasSolicitudes = leads.where((l) => l['estado'] == 'pendiente' || l['estado'] == 'solicitada').length;
        
        // Contar tratos cerrados (pagados o aceptados) que el capitán aún no ha gestionado
        final tratosCerrados = cotizaciones.where((c) => c.estado == 'pagado' || c.estado == 'aceptado').length;

        setState(() {
          _cotizaciones = cotizaciones;
          _leads = leads;
          _cotizacionesPresupuestadas = cotizacionesPresupuestadas;
          _unreadLeadsCount = nuevasSolicitudes + tratosCerrados;
          _isLoading = false;
        });
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar datos: $e', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }



  void _configurarRealtime() {
    _cotizacionesChannel?.unsubscribe();
    _cotizacionesChannel = SupabaseService.cotizacionesChannel(
      capitanId: _capitanId,
      onCotizacionCreada: (cot) {
        // Notificación para nuevos leads (cuando no tienen capitán asignado aún)
        if (cot['capitan_id'] == null) {
          final lat = cot['coordenadas_partida']?['lat'];
          final lon = cot['coordenadas_partida']?['lon'];
          
          if (lat != null && lon != null && _perfil != null && _perfil!.tieneGeofencingConfigurado) {
            final dist = MasterConnectionSkill.calcularDistancia(
              _perfil!.latitudCentro!, _perfil!.longitudCentro!,
              lat, lon
            );
            
            if (dist <= (_perfil!.radioOperacionKm ?? 50.0)) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.radar, color: Colors.white),
                        SizedBox(width: 12),
                        Expanded(child: Text('🔔 ¡NUEVA SOLICITUD EN TU ZONA! Revisa tu radar.')),
                      ],
                    ),
                    backgroundColor: Color(0xFF00E676),
                    duration: Duration(seconds: 5),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            }
          }
        }
        _cargarDatos();
      },
      onCotizacionActualizada: (_) => _cargarDatos(),
    );
    _cotizacionesChannel?.subscribe();
  }

  Future<void> _actualizarDisponibilidad(bool disponible) async {
    try {
      setState(() {
        _guardando = true;
        if (_perfil != null) {
          _perfil = _perfil!.copyWith(disponible: disponible);
        }
      });
      
      await SupabaseService.cambiarDisponibilidadCapitan(
        _capitanId,
        disponible,
      );
      _cargarDatos();
    } catch (e) {
      print('Error al cambiar disponibilidad: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // -- UI BUILDERS --

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF000B21),
      appBar: AppBar(
        title: const Text(
          'Panel de Control El Guia YA',
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
              await Supabase.instance.client.auth.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
          const SizedBox(width: 8),
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
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80.0, sigmaY: 80.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent.withOpacity(0.08),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70.0, sigmaY: 70.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Capa 2: Contenido
          _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.blueAccent),
                )
              : RefreshIndicator(
                  onRefresh: _cargarDatos,
                  color: Colors.blueAccent,
                  backgroundColor: const Color(0xFF0A192F),
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      ViewInsets.systemBottomPadding(context, extra: 24),
                    ),
                    children: [
                      _buildUserInfoHeader(),
                      const SizedBox(height: 12),
                      if (_estadoCuenta == 'suspendido' || _estadoCuenta == 'en_revision')
                        _buildCuentaPausadaBanner(),
                      const PronosticoMiniWidget(),
                      const SizedBox(height: 12),
                      const SolunarCardWidget(),
                      const SizedBox(height: 12),
                      _buildDisponibilidadHeader(),
                      const SizedBox(height: 12),
                      
                      // Declaración de Servicio (Boton Primario Estilizado)
                      _buildGestionPerfilButton(),
                      
                      // Configuración de Radar de Operación
                      _buildZonaConfigButton(),
                      
                      _buildMiCalendarioButton(),
                      _buildMiVidrieraButton(),
                      const SizedBox(height: 16),
                      
                      // Almanaque del Capitán (Se renderiza directamente para optimizar el ancho en pantallas móviles y evitar overflows)
                      _buildSectionHeader('CALENDARIO DE DISPONIBILIDAD', Icons.calendar_today_rounded),
                      CalendarioViajesWidget(capitanId: _capitanId),
                      const SizedBox(height: 16),
                      
                      if (_mensajeAlertaRuta != null)
                        _buildRouteAlertBubble(),

                      _buildRadarOperacionActiva() ?? const SizedBox.shrink(),
                        
                      _buildLeadsSection(),
                      _buildCotizacionesPendientes(),
                      
                      _buildHistoryHeader(),
                      _buildListaCotizaciones(),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent, size: 14),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.blueAccent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisponibilidadHeader() {
    final bool isDisp = _perfil?.disponible ?? false;
    return _buildGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          // Indicador Glow LED
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDisp 
                  ? const Color(0xFF00E676).withOpacity(0.12)
                  : Colors.amber.withOpacity(0.1),
              border: Border.all(
                color: isDisp 
                    ? const Color(0xFF00E676).withOpacity(0.3)
                    : Colors.amber.withOpacity(0.2),
              ),
            ),
            child: Icon(
              isDisp ? Icons.sailing_rounded : Icons.anchor_rounded,
              color: isDisp ? const Color(0xFF00E676) : Colors.amber,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ESTADO DE NAVEGACIÓN',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isDisp ? 'EN NAVEGACIÓN (RADAR ACTIVO)' : 'EN PUERTO / DESCANSO',
                  style: TextStyle(
                    color: isDisp ? const Color(0xFF00E676) : Colors.amber,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isDisp,
            onChanged: _guardando ? null : (v) => _actualizarDisponibilidad(v),
            activeColor: const Color(0xFF00E676),
            activeTrackColor: const Color(0xFF00E676).withOpacity(0.3),
            inactiveThumbColor: Colors.amber,
            inactiveTrackColor: Colors.amber.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget? _buildRadarOperacionActiva() {
    final perfil = _perfil;
    if (perfil == null ||
        perfil.latitudCentro == null ||
        perfil.longitudCentro == null ||
        _estadoCuenta != 'activo') {
      return null;
    }

    final bool disponible = perfil.disponible;
    final int leadsActivos = _leads.length;
    final String mensaje = !disponible
        ? 'Radar en pausa — activá disponibilidad para recibir solicitudes'
        : leadsActivos == 0
            ? 'Escaneando radar en tu zona...'
            : '$leadsActivos solicitud(es) detectadas en tu radar';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: RadarScannerWidget(
        mensaje: mensaje,
        mapCenter: LatLng(perfil.latitudCentro!, perfil.longitudCentro!),
        radioKm: perfil.radioOperacionKm ?? 50.0,
        blipColor: disponible
            ? const Color(0xFF00E676)
            : Colors.amberAccent,
      ),
    );
  }

  Widget _buildLeadsSection() {
    final bool tieneZona = _perfil != null && _perfil!.latitudCentro != null;
    
    if (!tieneZona) {
      return _buildGlassCard(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(24),
        borderColor: Colors.redAccent.withOpacity(0.2),
        child: Column(
          children: [
            // Icono holográfico de radar inactivo
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withOpacity(0.1),
                    border: Border.all(color: Colors.redAccent.withOpacity(0.2), width: 1.5),
                  ),
                ),
                const Icon(Icons.radar_rounded, color: Colors.redAccent, size: 36),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Text(
              'RADAR INACTIVO',
              style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              'Configurá tu zona de operación de pesca para abrir canal de comunicación con pescadores.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CapitanZonaConfigScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('CONFIGURAR ZONA AHORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    if (_leads.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar_rounded, color: Color(0xFF00E676), size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'SOLICITUDES EN TU RADAR',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    color: Color(0xFF00E676),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_leads.length} ACTIVAS',
                  style: const TextStyle(color: Color(0xFF00E676), fontSize: 9, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _leads.length,
            separatorBuilder: (_, _) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              final lead = _leads[index];
              final isUnread = lead['estado'] == 'pendiente';
              final createdAtStr = lead['created_at'];
              final createdAt = createdAtStr != null ? DateTime.parse(createdAtStr) : DateTime.now();
              final expiraEn = lead['expira_en'] != null 
                  ? DateTime.parse(lead['expira_en']) 
                  : createdAt.add(const Duration(hours: 24));
              
              final bool yaExpiro = expiraEn.isBefore(DateTime.now());
              
              final bool yaOfertado = _cotizacionesPresupuestadas.contains(lead['id']);
              
              return ListTile(
                onTap: (yaExpiro || yaOfertado) ? null : () => _mostrarDetalleLead(lead),
                contentPadding: EdgeInsets.zero,
                leading: Badge(
                  isLabelVisible: isUnread && !yaOfertado,
                  backgroundColor: Colors.blueAccent,
                  child: CircleAvatar(
                    backgroundColor: (yaExpiro || yaOfertado) ? Colors.white10 : const Color(0xFF0A192F),
                    radius: 20,
                    child: Icon(
                      yaExpiro ? Icons.timer_off_rounded : (yaOfertado ? Icons.check_circle_outline : Icons.person_rounded), 
                      color: yaExpiro ? Colors.white30 : (yaOfertado ? const Color(0xFF00E676) : Colors.white),
                      size: 20,
                    ),
                  ),
                ),
                title: Text(
                  lead['profiles']?['nombre'] ?? 'NUEVA SOLICITUD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    color: (yaExpiro || yaOfertado) ? Colors.white38 : Colors.white,
                    fontSize: 14,
                    decoration: yaExpiro ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: yaExpiro 
                  ? const Text('Plazo de subasta finalizado', style: TextStyle(color: Colors.white30, fontSize: 11))
                  : yaOfertado
                      ? const Text('Propuesta enviada con éxito', style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold))
                      : _buildLeadCountdown(expiraEn),
                trailing: yaExpiro 
                  ? const Text('EXPIRADO', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5))
                  : yaOfertado
                      ? const Text('OFERTADO', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5))
                      : const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCotizacionesPendientes() {
    if (_cotizacionesPendientes.isEmpty) return const SizedBox.shrink();
    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderColor: Colors.orangeAccent.withOpacity(0.2),
      child: Column(
        children: _cotizacionesPendientes
            .map(
              (cot) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  cot.descripcionCorta,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                trailing: ElevatedButton(
                  onPressed: _cotizacionesPresupuestadas.contains(cot.id)
                      ? null
                      : () => _mostrarDialogoPresupuestar(cot),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _cotizacionesPresupuestadas.contains(cot.id)
                        ? Colors.grey
                        : Colors.orangeAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    _cotizacionesPresupuestadas.contains(cot.id)
                        ? 'Enviado'
                        : 'Cotizar',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildHistoryHeader() {
    return _buildSectionHeader('HISTORIAL DE OFERTAS Y VIAJES', Icons.history_rounded);
  }

  Widget _buildListaCotizaciones() {
    if (_cotizaciones.isEmpty) return const SizedBox.shrink();
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _cotizaciones.length,
      itemBuilder: (context, index) {
        final cot = _cotizaciones[index];
        final stateColor = _getEstadoColor(cot.estado);
        
        return _buildGlassCard(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(8),
          child: ListTile(
            onTap: () => _mostrarGestionCotizacion(cot),
            leading: CircleAvatar(
              backgroundColor: stateColor.withOpacity(0.12),
              radius: 20,
              child: Text(cot.estadoIcono, style: const TextStyle(fontSize: 16)),
            ),
            title: Text(
              cot.descripcionCorta,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
            subtitle: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cot.estadoFormateado,
                  style: TextStyle(color: stateColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    cot.codigoCorto,
                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      cot.hasPresupuesto ? cot.presupuestoFormateado : '-',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTimeAgo(cot.createdAt?.toIso8601String()),
                      style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right_rounded, color: Colors.white30),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case Cotizacion.ESTADO_ACEPTADO:
      case 'pagado':
        return const Color(0xFF00E676); // Verde Esmeralda Náutico
      case Cotizacion.ESTADO_RECHAZADO:
        return Colors.redAccent;
      case Cotizacion.ESTADO_PRESUPUESTADO:
        return Colors.blueAccent;
      case Cotizacion.ESTADO_EN_VIAJE:
        return Colors.indigoAccent;
      case Cotizacion.ESTADO_FINALIZADO:
        return Colors.tealAccent;
      default:
        return Colors.orangeAccent;
    }
  }

  Widget _buildInteractiveMap(Cotizacion cot) {
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(cot.latitudPartida!, cot.longitudPartida!),
        initialZoom: 11.0,
        interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.El Guia YA',
        ),
        if (cot.trackLog != null && cot.trackLog!.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: cot.trackLog!.map((pt) => LatLng((pt['lat'] as num).toDouble(), (pt['lon'] as num).toDouble())).toList(),
                strokeWidth: 3.5,
                color: Colors.blueAccent,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: LatLng(cot.latitudPartida!, cot.longitudPartida!),
              width: 24,
              height: 24,
              child: const Icon(Icons.location_pin, color: Colors.greenAccent, size: 20),
            ),
            Marker(
              point: LatLng(cot.latitudDestino!, cot.longitudDestino!),
              width: 24,
              height: 24,
              child: const Icon(Icons.location_pin, color: Colors.redAccent, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCotizacionDetalles(Cotizacion cot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DETALLE DE LA SOLICITUD',
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(
              cot.descripcion == 'Pesca Deportiva'
                  ? Icons.phishing_rounded
                  : cot.descripcion == 'Viajes a la Isla'
                      ? Icons.directions_ferry_rounded
                      : Icons.camera_alt_rounded,
              color: const Color(0xFF00E676),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              cot.descripcion.isEmpty 
                  ? 'Sin especificar' 
                  : cot.descripcion,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Cronograma y Participantes
        const Text(
          'CRONOGRAMA Y PARTICIPANTES',
          style: TextStyle(
            color: Colors.blueAccent,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Fecha Ida: ${cot.fechaIda != null ? DateFormat('dd MMM yyyy', 'es').format(cot.fechaIda!) : 'No especificada'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Fecha Vuelta: ${cot.fechaVuelta != null ? DateFormat('dd MMM yyyy', 'es').format(cot.fechaVuelta!) : 'No especificada'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.access_time_rounded, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Hora Encuentro: ${cot.horaEncuentro ?? 'No especificada'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.people_alt_rounded, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'Cantidad de Personas: ${cot.cantidadPersonas ?? 1}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (cot.tieneDatosGeograficos) ...[
          const Text(
            'RECORRIDO Y DISTANCIA',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.redAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Partida: ${cot.nombrePartida}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.flag_outlined, color: Colors.greenAccent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Destino: ${cot.nombreDestino}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
          if (cot.distanciaKm != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.straighten, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  'Distancia: ${cot.distanciaKm!.toStringAsFixed(1)} KM',
                  style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          
          // Mapa de trayectoria
          () {
            bool showInteractive = false;
            return StatefulBuilder(
              builder: (context, setMapState) {
                return Container(
                  height: 140,
                  margin: const EdgeInsets.only(top: 6, bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: showInteractive || cot.staticMapUrl == null
                              ? _buildInteractiveMap(cot)
                              : Image.network(
                                  cot.staticMapUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.blueAccent,
                                      ),
                                    );
                                  },
                                  errorBuilder: (context, error, stackTrace) {
                                    return _buildInteractiveMap(cot);
                                  },
                                ),
                        ),
                        if (cot.staticMapUrl != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () {
                                setMapState(() {
                                  showInteractive = !showInteractive;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.7),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white24),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      showInteractive ? Icons.satellite_alt_rounded : Icons.map_rounded,
                                      color: const Color(0xFF00E676),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      showInteractive ? 'VER SATÉLITE' : 'VER INTERACTIVO',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
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
                );
              },
            );
          }(),
        ],
      ],
    );
  }

  void _mostrarDetalleLead(Map<String, dynamic> leadMap) {
    final cot = Cotizacion.fromSupabase(leadMap);
    final profile = leadMap['profiles'] as Map<String, dynamic>?;
    final nombrePescador = profile?['nombre'] ?? 'Pescador Anónimo';
    final avatarUrl = profile?['avatar_url']?.toString();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0A192F).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.1),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        radius: 24,
                        child: avatarUrl == null 
                            ? const Icon(Icons.person_rounded, color: Colors.blueAccent)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombrePescador,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Solicitud de Cotización en Radar',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildCotizacionDetalles(cot),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _cotizacionesPresupuestadas.contains(cot.id)
                          ? null
                          : () {
                              Navigator.pop(context);
                              _mostrarDialogoPresupuestar(cot);
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _cotizacionesPresupuestadas.contains(cot.id)
                            ? Colors.grey
                            : Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _cotizacionesPresupuestadas.contains(cot.id)
                            ? 'PROPUESTA YA ENVIADA'
                            : 'ENVIAR PROPUESTA (PRESUPUESTO)',
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _mostrarGestionCotizacion(Cotizacion cot) {
    final stateColor = _getEstadoColor(cot.estado);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: const Color(0xFF0A192F).withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(cot.estadoIcono, style: const TextStyle(fontSize: 44)),
                  const SizedBox(height: 16),
                  Text(
                    'Estado: ${cot.estadoFormateado}',
                    style: TextStyle(color: stateColor, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  // Código del viaje destacado
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: stateColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: stateColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tag_rounded, color: stateColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          cot.codigoCorto,
                          style: TextStyle(color: stateColor, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.copy_rounded, color: stateColor.withOpacity(0.5), size: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildCotizacionDetalles(cot),
                  const SizedBox(height: 24),
                  if (cot.estado == Cotizacion.ESTADO_PENDIENTE) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildGestionButton(
                            label: 'RECHAZAR SOLICITUD',
                            color: Colors.redAccent,
                            icon: Icons.close_rounded,
                            onTap: () {
                              Navigator.pop(context);
                              _actualizarEstadoCotizacion(
                                cot.id,
                                Cotizacion.ESTADO_RECHAZADO,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGestionButton(
                            label: 'PRESUPUESTAR',
                            color: const Color(0xFF00E676),
                            textColor: Colors.black,
                            icon: Icons.attach_money,
                            onTap: () {
                              Navigator.pop(context);
                              _mostrarDialogoPresupuestar(cot);
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else if (cot.estado == Cotizacion.ESTADO_PRESUPUESTADO) ...[
                    Row(
                      children: [
                        Expanded(
                          child: _buildGestionButton(
                            label: 'DESCARTAR PRESUPUESTO',
                            color: Colors.redAccent,
                            icon: Icons.cancel_outlined,
                            onTap: () {
                              Navigator.pop(context);
                              _actualizarEstadoCotizacion(
                                cot.id,
                                Cotizacion.ESTADO_RECHAZADO,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ] else if (cot.estado == 'pagado' || cot.estado == Cotizacion.ESTADO_ACEPTADO) ...[
                    _buildGestionButton(
                      label: 'INICIAR VIAJE',
                      color: const Color(0xFF00E676),
                      textColor: Colors.black,
                      icon: Icons.play_arrow_rounded,
                      onTap: () async {
                        Navigator.pop(context);
                        try {
                          await ViajeLifecycleService.iniciarViaje(
                            pedidoId: cot.id,
                            capitanId: _capitanId,
                          );
                          _cargarDatos();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('⛵ Viaje ${cot.codigoCorto} iniciado'),
                                backgroundColor: const Color(0xFF00E676),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
                        }
                      },
                    ),
                  ] else if (cot.estado == 'en_curso' || cot.estado == 'en_viaje') ...[
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.gps_fixed_rounded, color: Color(0xFF00E676), size: 16),
                              SizedBox(width: 8),
                              Text('GPS ACTIVO — Viaje en curso', style: TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        _buildGestionButton(
                          label: 'FINALIZAR VIAJE',
                          color: Colors.orangeAccent,
                          textColor: Colors.black,
                          icon: Icons.stop_rounded,
                          onTap: () async {
                            Navigator.pop(context);
                            try {
                              await ViajeLifecycleService.finalizarViaje(
                                pedidoId: cot.id,
                                capitanId: _capitanId,
                              );
                              _cargarDatos();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('✅ Viaje ${cot.codigoCorto} FINALIZADO — El pescador recibirá notificación'),
                                    backgroundColor: Colors.orangeAccent,
                                    behavior: SnackBarBehavior.floating,
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating));
                            }
                          },
                        ),
                      ],
                    ),
                  ] else if (cot.estado == 'listo_para_confirmar' || cot.estado == Cotizacion.ESTADO_FINALIZADO) ...[
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.orangeAccent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.hourglass_top_rounded, color: Colors.orangeAccent, size: 20),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Esperando que el pescador confirme y califique el viaje...',
                                  style: TextStyle(color: Colors.white70, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildGestionButton(
                          label: 'CALIFICAR AL PESCADOR',
                          color: Colors.blueAccent,
                          icon: Icons.star_rounded,
                          onTap: () {
                            Navigator.pop(context);
                            CalificacionPescadorDialog.mostrar(
                              context: context,
                              pedidoId: cot.id,
                              capitanId: _capitanId,
                              pescadorId: cot.pescadorId,
                              pescadorNombre: 'Pescador',
                              codigoViaje: cot.codigoCorto,
                              onCalificacionGuardada: _cargarDatos,
                            );
                          },
                        ),
                      ],
                    ),
                  ] else if (cot.estado == 'cerrado') ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_rounded, color: Color(0xFF00E676), size: 22),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('VIAJE CERRADO', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                                const SizedBox(height: 2),
                                Text('Código: ${cot.codigoCorto}', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                                const SizedBox(height: 4),
                                ReputacionBadgeWidget(userId: _capitanId, compact: true),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: _getEstadoColor(cot.estado)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Estado ${cot.estadoFormateado} — ${cot.codigoCorto}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGestionButton({
    required String label,
    required Color color,
    Color textColor = Colors.white,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: textColor, size: 24),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: SafeButtonText(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _actualizarEstadoCotizacion(
    String id,
    String nuevoEstado,
  ) async {
    setState(() {
      final index = _cotizaciones.indexWhere((c) => c.id == id);
      if (index != -1) {
        final cot = _cotizaciones[index];
        _cotizaciones[index] = Cotizacion(
          id: cot.id,
          pescadorId: cot.pescadorId,
          capitanId: cot.capitanId,
          descripcion: cot.descripcion,
          estado: nuevoEstado,
          createdAt: cot.createdAt,
          updatedAt: DateTime.now(),
          presupuestoMonto: cot.presupuestoMonto,
        );
      }
    });

    try {
      if (nuevoEstado == Cotizacion.ESTADO_RECHAZADO) {
        await SupabaseService.rechazarCotizacion(id, 'Descartado por el Capitán');
        await _cargarDatos();
      }
    } catch (e) {
      print('⚠️ Error al actualizar estado de cotización: $e');
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Cotización ${nuevoEstado.toUpperCase()}'),
        backgroundColor: _getEstadoColor(nuevoEstado),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarDialogoPresupuestar(Cotizacion cot) {
    final montoController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: const Color(0xFF0A192F).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: Colors.white.withOpacity(0.08)),
            ),
            title: Text(
              'PRESUPUESTAR: ${cot.descripcionCorta.toUpperCase()}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VALOR ESTIMADO DEL SERVICIO',
                  style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: montoController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    prefixText: '\$ ',
                    prefixStyle: const TextStyle(color: Color(0xFF00E676), fontSize: 24, fontWeight: FontWeight.bold),
                    hintText: '0.00',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.15)),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(color: Color(0xFF00E676), width: 2),
                    ),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.security_rounded, color: Colors.amber, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Por seguridad, no se permite el envío de números o datos de contacto externos.',
                          style: TextStyle(color: Colors.white70, fontSize: 10, height: 1.3),
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
                child: const Text(
                  'CANCELAR',
                  style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final monto = double.tryParse(montoController.text);
                  if (monto != null) {
                    Navigator.pop(context);
                    try {
                      await ViajeLifecycleService.enviarPresupuesto(
                        cotizacionId: cot.id,
                        capitanId: _capitanId,
                        monto: monto,
                        detalles: 'Servicio de guía profesional (Contacto privado hasta el pago)',
                      );
                      _cargarDatos();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Propuesta enviada al pescador'),
                          backgroundColor: Color(0xFF00E676),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.redAccent,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('ENVIAR OFERTA', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  Widget _buildGestionPerfilButton() {
    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CapitanPerfilEditScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF00E676).withOpacity(0.12),
                const Color(0xFF00E676).withOpacity(0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF00E676).withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF00E676), size: 24),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DECLARACIÓN DE SERVICIO',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Actualizá tus servicios y tarifas para pescadores',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF00E676)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZonaConfigButton() {
    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CapitanZonaConfigScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.cyan.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.radar_rounded, color: Colors.cyan, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MI ZONA Y RADAR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Definí tu radio de acción y cobertura',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiVidrieraButton() {
    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CapitanVidrieraScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.purpleAccent, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MI VIDRIERA (KIOSKO)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Gestiona tus productos y extras (leña, carnada, alojamiento)',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiCalendarioButton() {
    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const MiCalendarioScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit_calendar_rounded, color: Colors.orangeAccent, size: 20),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'BLOQUEO DE ALMANAQUE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Configurá tus días libres de navegación',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserInfoHeader() {
    final String nombre =
        _perfil?.nombre ??
        SupabaseService.currentUserEmail?.split('@')[0] ??
        'Capitán';
    final String email =
        SupabaseService.currentUserEmail ?? 'Sesión Activa';

    return _buildGlassCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CapitanIdentidadScreen(),
          ),
        ),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF0A192F),
                    backgroundImage: _perfil?.avatarUrl != null
                        ? NetworkImage(_perfil!.avatarUrl!)
                        : null,
                    child: _perfil?.avatarUrl == null
                        ? const Icon(Icons.person_rounded, color: Colors.white, size: 26)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.black, size: 10),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MI IDENTIDAD Y DOCUMENTOS • VER MÁS',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      nombre.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              
              // Indicador GPS en vivo o Chevron simple
              if (ViajeGpsCoordinator().isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.3), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.radar_rounded, color: Color(0xFF00E676), size: 12),
                      SizedBox(width: 4),
                      Text(
                        'GPS ACTIVO',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRouteAlertBubble() {
    return _buildGlassCard(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      borderColor: const Color(0xFF00E676).withOpacity(0.3),
      child: Row(
        children: [
          const Icon(Icons.radar_rounded, color: Color(0xFF00E676), size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OPORTUNIDAD DETECTADA EN RADAR',
                  style: TextStyle(
                    color: Color(0xFF00E676),
                    fontWeight: FontWeight.bold,
                    fontSize: 9,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _mensajeAlertaRuta!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
            onPressed: () => setState(() => _mensajeAlertaRuta = null),
          ),
        ],
      ),
    );
  }

  Widget _buildLeadCountdown(DateTime? expiraEn) {
    if (expiraEn == null) return const Text('Sin límite de tiempo', style: TextStyle(fontSize: 11));
    
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final ahora = DateTime.now();
        final diferencia = expiraEn.difference(ahora);
        
        if (diferencia.isNegative) {
          return const Text('Oferta terminada', style: TextStyle(color: Colors.redAccent, fontSize: 11));
        }

        final h = diferencia.inHours.toString().padLeft(2, '0');
        final m = (diferencia.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diferencia.inSeconds % 60).toString().padLeft(2, '0');

        return Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: Color(0xFF00E676), size: 12),
            const SizedBox(width: 4),
            Text(
              'Cierre de subasta: $h:$m:$s', 
              style: const TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlassCard({
    required Widget child, 
    EdgeInsetsGeometry? margin, 
    EdgeInsetsGeometry? padding,
    Color? borderColor,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.08)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildCuentaPausadaBanner() {
    final bool enRevision = _estadoCuenta == 'en_revision';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: enRevision 
            ? Colors.blueAccent.withOpacity(0.12)
            : Colors.redAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: enRevision ? Colors.blueAccent : Colors.redAccent,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            enRevision ? Icons.hourglass_empty_rounded : Icons.warning_amber_rounded,
            color: enRevision ? Colors.blueAccent : Colors.redAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  enRevision ? 'DOCUMENTACIÓN EN REVISIÓN' : 'CUENTA PAUSADA',
                  style: TextStyle(
                    color: enRevision ? Colors.blueAccent : Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  enRevision
                      ? 'Tu documentación está siendo revisada por la administración. No recibirás nuevas cotizaciones hasta que sea aprobada.'
                      : 'Tu cuenta está pausada temporalmente. Para recibir nuevas cotizaciones y viajes, por favor regularizá tu situación y cargá la documentación desde la pestaña "Cotizaciones".',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
