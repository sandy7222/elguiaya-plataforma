import 'dart:ui';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_user.dart';
import '../models/dashboard_kpi.dart';
import '../services/branding_service.dart';
import '../services/supabase_service.dart';
import 'branding_editor_screen.dart';
import 'seguridad_admin_screen.dart';
import 'admin_categorias_screen.dart';
import 'admin_banners_screen.dart';
import 'bienvenida_definitiva_screen.dart';
import 'categories_grid_screen.dart';
import 'admin_perfiles_aprobacion_screen.dart';
import 'admin_atributos_screen.dart';
import 'admin_sistema_screen.dart';
import 'admin_guia_educador_screen.dart';
import 'solicitud_detalle_screen.dart';
import 'admin_centro_computos_screen.dart';
import '../widgets/pronostico_mini_widget.dart';
import 'admin_liquidacion_screen.dart';
import 'admin_comisionistas_screen.dart';
import 'admin_reembolsos_screen.dart';
import 'admin_blog_screen.dart';
import 'admin_bitacora_alertas_screen.dart';
import 'admin_creador_notificaciones_screen.dart';
import '../widgets/notification_quick_view.dart';
import 'admin_disputas_screen.dart';
import 'admin_tracking_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_calificaciones_screen.dart';
import 'admin_viajes_screen.dart';
import 'comando_operativo_screen.dart';
import '../widgets/admin_telemetry_fab.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  AdminUser? _adminUser;
  bool _isLoading = true;
  Map<String, KPIData> _kpis = {};
  
  // Branding variables
  String? _backgroundUrl;
  double _opacity = 0.7;
  RealtimeChannel? _realtimeChannel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 15, vsync: this); // Actualizado a 15 pestañas
    _cargarDatosAdmin();
    _cargarKPIs();
    _cargarBrandingConfig();
    _setupRealtime();
  }

  void _setupRealtime() {
    _realtimeChannel = Supabase.instance.client
        .channel('admin-kpis')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cotizaciones',
          callback: (payload) {
            _cargarKPIs();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _cargarDatosAdmin() async {
    try {
      // Dar un margen para la recuperacion de sesion asincrona
      await Future.delayed(const Duration(milliseconds: 500));
      
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        // Si no hay usuario, redirigir al login para asegurar la sesion
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sesion no encontrada. Por favor inicia sesion.'),
              backgroundColor: Colors.orange,
            ),
          );
          // Opcional: Navegar al login
          // Navigator.of(context).pushReplacementNamed('/'); 
        }
        setState(() => _isLoading = false);
        return;
      }
      
      // Si hay usuario, procedemos
      _adminUser = AdminUser(
        id: user.id,
        email: user.email ?? '',
        nombre: 'Admin Master',
        rol: AdminUser.ROL_ADMIN_MASTER,
        activo: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar datos: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarKPIs() async {
    try {
      setState(() => _isLoading = true);

      // Modulo Nautico
      final documentosPendientes = await _getDocumentosPendientes();
      final capitanesActivos = await _getCapitanesActivos();
      final invitadosHoy = await _getInvitadosHoy();

      // Modulo E-Commerce (simulados por ahora)
      final ventasSemana = await _getVentasSemana();
      final pedidosPendientes = await _getPedidosPendientes();

      // Generales
      final usuariosTotales = await _getUsuariosTotales();
      final ingresosMes = await _getIngresosMes();
      
      // NUEVO: Cotizaciones Reales
      final totalCotizaciones = await SupabaseService.getContadorCotizaciones();

      setState(() {
        _kpis = {
          'viajesHoy': KPIData.viajesHoy.copyWith(valor: 12),
          'documentosPendientes': KPIData.documentosPendientes.copyWith(
            valor: documentosPendientes.toDouble(),
          ),
          'capitanesActivos': KPIData.capitanesActivos.copyWith(
            valor: capitanesActivos.toDouble(),
          ),
          'cotizaciones': KPIData.invitadosHoy.copyWith(
            titulo: 'Cotizaciones',
            valor: totalCotizaciones.toDouble(),
            icono: Icons.request_quote_rounded,
            color: Colors.purple,
            descripcion: 'Total de pedidos de viaje',
          ),
          'ventasSemana': KPIData.ventasSemana.copyWith(
            valor: ventasSemana,
          ),
          'pedidosPendientes': KPIData.pedidosPendientes.copyWith(
            valor: pedidosPendientes.toDouble(),
          ),
          'usuariosTotales': KPIData.usuariosTotales.copyWith(
            valor: usuariosTotales.toDouble(),
          ),
          'ingresosMes': KPIData.ingresosMes.copyWith(
            valor: ingresosMes,
          ),
          'clientes': KPIData.usuariosTotales.copyWith(
            titulo: 'Clientes / Pescadores',
            valor: usuariosTotales.toDouble(),
            icono: Icons.people_alt,
            color: Colors.indigo,
          ),
          'capitanes': KPIData.capitanesActivos.copyWith(
            titulo: 'Capitanes Activos',
            valor: capitanesActivos.toDouble(),
            icono: Icons.anchor,
            color: const Color(0xFF0D47A1),
          ),
        };
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar KPIs: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<int> _getDocumentosPendientes() async {
    try {
      final pendientes = await SupabaseService.getPerfilesPendientes();
      return pendientes.length;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getCapitanesActivos() async {
    try {
      final guias = await SupabaseService.getGuias();
      return guias.length; // Simplificado: todos los guias estan activos
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getInvitadosHoy() async {
    try {
      final hoy = DateTime.now();
      final invitados = await SupabaseService.getInvitadosPorPescador('');
      return invitados.where((inv) => 
        inv.createdAt.day == hoy.day &&
        inv.createdAt.month == hoy.month &&
        inv.createdAt.year == hoy.year
      ).length;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _cargarBrandingConfig() async {
    try {
      final config = await BrandingService.getLoginConfig();
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
        });
      }
    } catch (e) {
      // Si falla, usar valores por defecto
      print('Error al cargar branding: $e');
    }
  }

  Future<double> _getVentasSemana() async {
    try {
      final stats = await SupabaseService.getEstadisticasVentas();
      return (stats['total_ventas'] as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<int> _getPedidosPendientes() async {
    try {
      final stats = await SupabaseService.getEstadisticasVentas();
      return (stats['pedidos_pendientes'] as num?)?.toInt() ?? 0;
    } catch (e) {
      return 0;
    }
  }

  Future<int> _getUsuariosTotales() async {
    try {
      final guias = await SupabaseService.getGuias();
      final pescadores = await SupabaseService.getPescadores();
      return guias.length + pescadores.length;
    } catch (e) {
      return 0;
    }
  }

  Future<double> _getIngresosMes() async {
    // Simulado - deberias conectar con tu sistema de facturacion
    return 45680.75;
  }

  Future<void> _signOut() async {
    // Mostrar dialogo de confirmacion
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesion'),
        content: const Text('¿Cerrar sesion?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );

    // Si el usuario confirma, cerrar sesion
    if (confirmado == true) {
      try {
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al cerrar sesion: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildKPICard(KPIData kpi) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: kpi.color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: kpi.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(kpi.icono, color: kpi.color, size: 20),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                kpi.valor.toString(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: kpi.color,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                kpi.titulo.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: Colors.black.withOpacity(0.6),
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactKPICard(KPIData kpi) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
        border: Border.all(color: kpi.color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kpi.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(kpi.icono, color: kpi.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    kpi.valor.toString(),
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: kpi.color),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    kpi.titulo.toUpperCase(),
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.black54, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Header con info del admin
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0D47A1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Icon(Icons.admin_panel_settings, color: Color(0xFF0D47A1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _adminUser?.nombre ?? 'Admin',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _adminUser?.getRolNombre() ?? 'Sin Rol',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _cargarKPIs,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 15),
          
          // Monitor Meteorológico Industrial - Encuadrado
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: const PronosticoMiniWidget(),
          ),
          
          const SizedBox(height: 12),
          
          // KPIs principales responsivos
          if (_kpis.isNotEmpty) ...[
            LayoutBuilder(
              builder: (context, constraints) {
                final bool isMobile = constraints.maxWidth < 600;
                final int crossAxisCount = isMobile ? 2 : 3;
                return GridView.count(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: isMobile ? 1.2 : 1.4, // Proporción rectangular horizontal
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  children: [
                    _buildKPICard(_kpis['viajesHoy']!),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/admin/documentos_pendientes'),
                      child: _buildKPICard(_kpis['documentosPendientes']!),
                    ),
                    _buildKPICard(_kpis['ventasSemana']!),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/admin/directorio_pescadores'),
                      child: _buildKPICard(_kpis['clientes']!),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, '/admin/directorio_capitanes'),
                      child: _buildKPICard(_kpis['capitanes']!),
                    ),
                    GestureDetector(
                      onTap: () => _tabController.animateTo(6), // Tab SOLICITUDES
                      child: _buildKPICard(_kpis['cotizaciones']!),
                    ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNauticalModule() {
    if (_adminUser != null && !_adminUser!.tieneAccesoNautico()) {
      return const Center(
        child: Text('No tienes acceso al Modulo Nautico'),
      );
    }

    return Column(
      children: [
        // KPIs del modulo nautico
        if (_kpis.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: _buildKPICard(_kpis['capitanesActivos']!)),
              Expanded(child: _buildKPICard(_kpis['cotizaciones']!)),
            ],
          ),
        ],
        
        const SizedBox(height: 24),

        // SECCIÓN DE ESTADÍSTICAS EMPRESARIALES (NUEVA)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: const Text(
                      'RENDIMIENTO DE NEGOCIO',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          const Text('LIVE', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildBusinessStatsSection(),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Secciones del modulo - Lista responsiva
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (constraints.maxWidth > 600) 
                    // Modo Horizontal: En fila
                    Row(
                      children: [
                        Expanded(child: _buildModuleCard(
                          'Gestion de Documentos',
                          'Revisar y aprobar',
                          Icons.description,
                          Colors.blue,
                          () => Navigator.pushNamed(context, '/admin/documentos_pendientes'),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _buildModuleCard(
                          'Aprobacion de Perfiles',
                          'Validar perfiles',
                          Icons.verified_user,
                          Colors.green,
                          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPerfilValidationScreen())),
                        )),
                      ],
                    )
                  else ...[
                    // Modo Vertical: Uno sobre otro
                    _buildModuleCard(
                      'Gestion de Documentos',
                      'Revisar y aprobar documentacion de capitanes',
                      Icons.description,
                      Colors.blue,
                      () => Navigator.pushNamed(context, '/admin/documentos_pendientes'),
                    ),
                    _buildModuleCard(
                      'Aprobacion de Perfiles',
                      'Validar perfiles de capitanes y pescadores',
                      Icons.verified_user,
                      Colors.green,
                      () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminPerfilValidationScreen())),
                    ),
                  ],
                  _buildModuleCard(
                    'Viajes e Invitados',
                    'Monitorear viajes y acompanantes',
                    Icons.group,
                    Colors.purple,
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminViajesScreen())),
                  ),
                  _buildModuleCard(
                    'Calificaciones',
                    'Ranking y moderación de calificaciones',
                    Icons.anchor_rounded,
                    const Color(0xFF00E676),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCalificacionesScreen())),
                  ),
                  _buildModuleCard(
                    'Centro de Cómputos',
                    'Auditar vencimientos y suspensiones náuticas',
                    Icons.monitor_heart_rounded,
                    Colors.orangeAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminCentroComputosScreen())),
                  ),
                  _buildModuleCard(
                    'Comando Operativo (MCSTT)',
                    'Inteligencia geoespacial, Flota y Territorio',
                    Icons.map,
                    Colors.redAccent,
                    () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ComandoOperativoScreen())),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBusinessStatsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildStatBar('Tasa de Conversión', 0.65, '65%', Colors.greenAccent),
          const SizedBox(height: 20),
          _buildStatBar('Caja Náutica Mensual', 0.42, '\$185k', Colors.blueAccent),
          const SizedBox(height: 20),
          _buildStatBar('Capacidad de Flota', 0.85, '85%', Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildStatBar(String label, double percent, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
            Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 10),
        Stack(
          children: [
            // Fondo de la barra
            Container(
              height: 8,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            // Progreso con Gradiente y Brillo
            AnimatedContainer(
              duration: const Duration(seconds: 1),
              curve: Curves.easeOutCubic,
              height: 8,
              width: ((MediaQuery.of(context).size.width - 72) * percent).clamp(0.0, double.infinity),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.6), color],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(color: color.withOpacity(0.4), blurRadius: 12, spreadRadius: 1),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEcommerceModule() {
    if (_adminUser != null && !_adminUser!.tieneAccesoEcommerce()) {
      return const Center(
        child: Text('No tienes acceso al Modulo E-Commerce'),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 25), // Espacio para que no lo tape el header
        // 1. EL VIGÍA: DASHBOARD DE ALERTA TEMPRANA (NUEVO)
        _buildVigiaDashboard(),

        // KPIs del modulo e-commerce - VERSION COMPACTA
        if (_kpis.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(child: _buildCompactKPICard(_kpis['pedidosPendientes']!)),
                Expanded(child: _buildCompactKPICard(_kpis['ingresosMes']!)),
              ],
            ),
          ),
        ],
        
        const SizedBox(height: 12),
        
        // Grilla de 2 columnas para modulos e-commerce
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
              children: [
                _buildEcommerceCard(
                  'Catalogo',
                  'Administrar productos',
                  Icons.inventory_2_outlined,
                  const Color(0xFF6B73FF),
                  const Color(0xFFE8E9FF),
                  () => Navigator.pushNamed(context, '/admin/catalogo'),
                ),
                _buildEcommerceCard(
                  'Inventario',
                  'Control de stock',
                  Icons.warehouse_outlined,
                  const Color(0xFFFF6B6B),
                  const Color(0xFFFFE8E8),
                  () => Navigator.pushNamed(context, '/admin/inventario'),
                ),
                _buildEcommerceCard(
                  'Pedidos',
                  'Gestion de pedidos',
                  Icons.shopping_cart_outlined,
                  const Color(0xFF4ECDC4),
                  const Color(0xFFE8F9F8),
                  () => Navigator.pushNamed(context, '/admin/pedidos'),
                ),
                _buildEcommerceCard(
                  'Envios',
                  'Seguimiento',
                  Icons.local_shipping_outlined,
                  const Color(0xFF45B7D1),
                  const Color(0xFFE8F4F8),
                  () => Navigator.pushNamed(context, '/admin/envios'),
                ),
                _buildEcommerceCard(
                  'Categorías',
                  'Gestionar jerarquía',
                  Icons.category_outlined,
                  const Color(0xFFFF922B),
                  const Color(0xFFFFF4E6),
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminCategoriasScreen())),
                ),
                _buildEcommerceCard(
                  'Publicaciones y Banners',
                  'Productos y publicidad',
                  Icons.view_carousel_outlined,
                  const Color(0xFF9C27B0),
                  const Color(0xFFF3E5F5),
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminBannersScreen())),
                ),
                _buildEcommerceCard(
                  'Diccionario',
                  'Atributos técnicos',
                  Icons.text_snippet_outlined,
                  const Color(0xFF0D47A1),
                  const Color(0xFFE3F2FD),
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminAtributosScreen())),
                ),
                _buildEcommerceCard(
                  'Blog de Pesca',
                  'Artículos e IA redactora',
                  Icons.article_outlined,
                  const Color(0xFF00B0FF),
                  const Color(0xFFE0F7FA),
                  () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminBlogScreen())),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEcommerceCard(
    String title,
    String description,
    IconData icon,
    Color primaryColor,
    Color backgroundColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: backgroundColor,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Center(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icono minimalista
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icon,
                        size: 24,
                        color: primaryColor,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Titulo compacto
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        height: 1.1,
                      ),
                    ),
                    
                    const SizedBox(height: 2),
                    
                    // Descripcion minimalista
                    Text(
                      description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard(String titulo, String descripcion, IconData icono, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        descripcion,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: Colors.grey[400]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: _buildBackgroundDecoration(),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D47A1), // Azul Profundo El Guia YA
                border: Border(
                  bottom: BorderSide(color: Colors.white.withOpacity(0.2), width: 0.5),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Header Superior
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'EL GUIA YA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  //
                                ),
                                Text(
                                  'CENTRO ADMINISTRATIVO DE CONTROL',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          const SizedBox(width: 8),
                          _buildHeaderAction(Icons.campaign_rounded, 'Notificar', () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminCreadorNotificacionesScreen()));
                          }),
                          const NotificationQuickView(), // La campanita receptora
                          _buildHeaderAction(Icons.history_edu_rounded, 'Bitácora', () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminBitacoraAlertasScreen()));
                          }),
                          _buildHeaderAction(Icons.refresh, 'Refrescar', _cargarKPIs),
                          _buildHeaderAction(Icons.logout, 'Salir', _signOut),
                        ],
                      ),
                    ),
                    
                    // TabBar Moderno
                    Expanded(
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        indicator: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            colors: [Colors.white.withOpacity(0.3), Colors.white.withOpacity(0.1)],
                          ),
                          border: Border.all(color: Colors.white.withOpacity(0.4)),
                        ),
                        indicatorPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: -12), // Ajustado para abrazar mejor el texto
                        labelColor: Colors.white,
                        unselectedLabelColor: Colors.white54,
                        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                        tabs: [
                          _buildModernTab(Icons.dashboard_rounded, 'DASHBOARD'),
                          _buildModernTab(Icons.storefront_rounded, 'TIENDA'),
                          _buildModernTab(Icons.sailing_rounded, 'NÁUTICO'),
                          _buildModernTab(Icons.shopping_cart_rounded, 'E-COMMERCE'),
                          _buildModernTab(Icons.settings_backup_restore_rounded, 'REEMBOLSOS'),
                          _buildModernTab(Icons.palette_rounded, 'BRANDING'),
                          _buildModernTab(Icons.request_quote_rounded, 'SOLICITUDES'),
                          _buildModernTab(Icons.payments_rounded, 'LIQUIDACIONES'),
                          _buildModernTab(Icons.gavel_rounded, 'DISPUTAS'),
                          _buildModernTab(Icons.local_shipping_rounded, 'TRAZABILIDAD'),
                          _buildModernTab(Icons.receipt_long_rounded, 'LOGS'),
                          _buildModernTab(Icons.supervised_user_circle_rounded, 'PROMOTORES'),
                          _buildModernTab(Icons.security_rounded, 'SEGURIDAD'),
                          _buildModernTab(Icons.settings_rounded, 'SISTEMA'),
                          _buildModernTab(Icons.school_rounded, 'EDUCADOR'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Container(
        decoration: _buildBackgroundDecoration(),
        child: Column(
          children: [
            // Body con contenedor translucido
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTranslucentTab(_buildMainDashboard()),
                  const Padding(
                    padding: EdgeInsets.only(top: 130),
                    child: CategoriesGridScreen(), // Tienda espejo real sin marcos
                  ),
                  _buildTranslucentTab(_buildNauticalModule()),
                  _buildTranslucentTab(_buildEcommerceModule()),
                  _buildTranslucentTab(const AdminReembolsosScreen()),
                  _buildTranslucentTab(const BrandingEditorScreen()),
                  _buildTranslucentTab(_buildSolicitudesViajeTab()),
                  const AdminLiquidacionScreen(),
                  _buildTranslucentTab(const AdminDisputasScreen(embedMode: true)),
                  _buildTranslucentTab(const AdminTrackingScreen(embedMode: true)),
                  _buildTranslucentTab(const AdminLogsScreen(embedMode: true)),
                  _buildTranslucentTab(const AdminComisionistasScreen()),
                  _buildTranslucentTab(const SeguridadAdminScreen()),
                  _buildTranslucentTab(const AdminSistemaScreen()),
                  _buildTranslucentTab(const AdminGuiaEducadorScreen()),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: const AdminTelemetryFAB(),
    );
  }

  BoxDecoration _buildBackgroundDecoration() {
    if (_backgroundUrl != null && _backgroundUrl!.isNotEmpty) {
      return BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(_backgroundUrl!),
          fit: BoxFit.cover,
        ),
      );
    }
    return const BoxDecoration(
      color: Color(0xFF0D47A1), // Azul Profundo El Guia YA Sólido
    );
  }

  Widget _buildTranslucentTab(Widget child) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: child,
        ),
      ),
    );
  }

  Widget _buildHeaderAction(IconData icon, String tooltip, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      tooltip: tooltip,
    );
  }

  Widget _buildModernTab(IconData icon, String text) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  Widget _buildVigiaDashboard() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getAlertasStockPredictivas(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

        final alertas = snapshot.data!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF001F3F).withOpacity(0.9), // Azul Marino Profundo
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.orange.withOpacity(0.5), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.orange.withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, color: Colors.orange, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'EL VIGÍA DEL CAPITÁN',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 2,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${alertas.length} ALERTAS',
                      style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: alertas.length,
                  itemBuilder: (context, index) {
                    final alerta = alertas[index];
                    final isCritical = alerta['prioridad'] == 'CRITICA' || alerta['prioridad'] == 'ALTA';
                    
                    return Container(
                      width: 280,
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isCritical ? Colors.redAccent.withOpacity(0.5) : Colors.orange.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isCritical ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                                color: isCritical ? Colors.redAccent : Colors.orange,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  alerta['producto'],
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            alerta['mensaje'],
                            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11),
                            maxLines: 2,
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () {
                              _mostrarDialogoPedido(alerta['producto']);
                            },
                            child: Text(
                              'GENERAR PEDIDO ➔',
                              style: TextStyle(
                                color: isCritical ? Colors.redAccent : Colors.orange,
                                fontWeight: FontWeight.w900,
                                fontSize: 10,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _mostrarDialogoPedido(String producto) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F3F),
        title: const Text('ORDEN AL PROVEEDOR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Deseas generar una solicitud de reposición para: $producto?', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Orden enviada al proveedor exitosamente.')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('CONFIRMAR PEDIDO', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSolicitudesViajeTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getTodasLasSolicitudes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orangeAccent));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.anchor_rounded,
                      color: Colors.orangeAccent,
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SIN SOLICITUDES ACTIVAS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No hay solicitudes de viaje registradas en la base de datos o vigentes.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final solicitudes = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: solicitudes.length,
          itemBuilder: (context, index) {
            final sol = solicitudes[index];
            final perfil = sol['profiles'];
            final partida = sol['coordenadas_partida'];
            final destino = sol['coordenadas_destino'];
            final track = sol['track_log'] as List?;

            final nombrePescador = perfil?['nombre']?.toString() ?? 'NUEVO PESCADOR';
            final telefonoPescador = perfil?['telefono']?.toString() ?? sol['pescador_telefono']?.toString() ?? 'No declarado';
            final emailPescador = perfil?['email']?.toString() ?? 'No declarado';
            final avatarUrl = perfil?['avatar_url']?.toString();

            return Card(
              color: const Color(0xFF001F3F).withOpacity(0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: ExpansionTile(
                iconColor: Colors.orangeAccent,
                collapsedIconColor: Colors.white70,
                title: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blueAccent.withOpacity(0.2),
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: avatarUrl == null || avatarUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.blueAccent, size: 20)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sol['descripcion'] ?? 'SOLICITUD DE VIAJE',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Cliente: $nombrePescador',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: sol['estado'] == 'pendiente'
                              ? Colors.green.withOpacity(0.2)
                              : Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: sol['estado'] == 'pendiente'
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          (sol['estado'] ?? 'pendiente').toString().toUpperCase(),
                          style: TextStyle(
                            color: sol['estado'] == 'pendiente'
                                ? Colors.greenAccent
                                : Colors.orangeAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.group, color: Colors.white54, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        '${sol['cantidad_personas'] ?? 1} pers.',
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                children: [
                  const Divider(color: Colors.white10, height: 1),
                  
                  // 🗺️ MAPA
                  if (partida != null && destino != null)
                    Container(
                      height: 200,
                      margin: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: FlutterMap(
                          options: MapOptions(
                            initialCenter: LatLng(
                              (partida['lat'] as num).toDouble(),
                              (partida['lon'] as num).toDouble(),
                            ),
                            initialZoom: 11.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                            ),
                            if (track != null)
                              PolylineLayer(
                                polylines: [
                                  Polyline(
                                    points: track.map((p) {
                                      if (p is Map) {
                                        return LatLng((p['lat'] as num).toDouble(), (p['lon'] as num).toDouble());
                                      } else if (p is List && p.length >= 2) {
                                        return LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble());
                                      }
                                      return const LatLng(0, 0);
                                    }).where((p) => p.latitude != 0).toList(),
                                    strokeWidth: 4,
                                    color: Colors.blueAccent,
                                  ),
                                ],
                              ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(
                                    (partida['lat'] as num).toDouble(),
                                    (partida['lon'] as num).toDouble(),
                                  ),
                                  child: const Icon(Icons.location_on, color: Colors.green, size: 24),
                                ),
                                Marker(
                                  point: LatLng(
                                    (destino['lat'] as num).toDouble(),
                                    (destino['lon'] as num).toDouble(),
                                  ),
                                  child: const Icon(Icons.flag, color: Colors.red, size: 24),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 👤 SECCIÓN: CONTACTO & AUDITORÍA
                        const Row(
                          children: [
                            Icon(Icons.person_pin_rounded, color: Colors.orangeAccent, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'DATOS OPERATIVOS DEL CLIENTE',
                              style: TextStyle(
                                color: Colors.orangeAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.account_circle, 'Nombre Completo', nombrePescador),
                        _buildDetailRow(Icons.phone_iphone, 'Teléfono Declarado', telefonoPescador),
                        _buildDetailRow(Icons.mail_outline, 'Correo Electrónico', emailPescador),
                        
                        const SizedBox(height: 16),
                        
                        // ⛵ SECCIÓN: LOGÍSTICA DEL VIAJE
                        const Row(
                          children: [
                            Icon(Icons.sailing_rounded, color: Colors.cyanAccent, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'DETALLE LOGÍSTICO Y RUTAS',
                              style: TextStyle(
                                color: Colors.cyanAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.calendar_today, 'Fecha de Ida', sol['fecha_ida'] != null ? _formatFechaCompacta(sol['fecha_ida']) : 'A confirmar'),
                        _buildDetailRow(Icons.calendar_month, 'Fecha de Vuelta', sol['fecha_vuelta'] != null ? _formatFechaCompacta(sol['fecha_vuelta']) : 'Solo ida / A confirmar'),
                        _buildDetailRow(Icons.access_time, 'Hora de Encuentro', sol['hora_encuentro'] ?? 'No declarada'),
                        _buildDetailRow(Icons.place, 'Punto de Encuentro', sol['lugar_encuentro'] ?? 'No especificado'),
                        _buildDetailRow(Icons.my_location, 'Localidad Origen', '${sol['localidad_partida'] ?? 'N/D'}, ${sol['provincia_partida'] ?? ''}'),
                        _buildDetailRow(Icons.flag_outlined, 'Localidad Destino', '${sol['localidad_destino'] ?? 'N/D'}, ${sol['provincia_destino'] ?? ''}'),
                        _buildDetailRow(
                          Icons.inventory_2,
                          '¿Transporta Carga?',
                          sol['tiene_mercaderia'] == true || sol['carga'] != null ? 'Sí, requiere bodega de carga' : 'No transporta mercadería',
                        ),
                        _buildDetailRow(
                          Icons.handyman,
                          'Equipamiento',
                          perfil?['trae_equipo_propio'] == true ? 'Trae propio equipo de pesca' : 'Requiere alquiler de cañas/equipamiento',
                        ),

                        const SizedBox(height: 16),
                        
                        // 📊 SECCIÓN: AUDITORÍA DE TRATO
                        const Row(
                          children: [
                            Icon(Icons.analytics_outlined, color: Colors.greenAccent, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'AUDITORÍA DE PRECIOS & CAPITANES',
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(Icons.straighten, 'Distancia de Navegación', sol['distancia_km'] != null ? '${sol['distancia_km']} KM (${sol['distancia_millas'] ?? '0'} mi)' : 'Cálculo pendiente'),
                        _buildDetailRow(Icons.timelapse, 'Duración de Viaje', sol['duracion_estimada_minutos'] != null ? '${sol['duracion_estimada_minutos']} Minutos' : 'Pendiente'),
                        _buildDetailRow(
                          Icons.sports_kabaddi,
                          'Capitán Adjudicado',
                          sol['capitan_id'] != null ? 'ID Capitán: ${sol['capitan_id']}' : 'Ninguno (En subasta abierta)',
                        ),
                        _buildDetailRow(
                          Icons.monetization_on,
                          'Presupuesto Adjudicado',
                          sol['presupuesto_monto'] != null ? '\$${sol['presupuesto_monto']} ARS' : 'Sin oferta aceptada aún',
                        ),
                        _buildDetailRow(Icons.schedule, 'Creada el', sol['created_at'] != null ? _formatFechaCompleta(sol['created_at']) : 'N/D'),
                        
                        if (sol['descripcion'] != null && sol['descripcion'].toString().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Text(
                              'Comentarios del pescador: "${sol['descripcion']}"',
                              style: const TextStyle(color: Colors.white70, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                        
                        // Botón de visualización interactiva del Capitán
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => SolicitudDetalleScreen(
                                    lead: sol,
                                    capitanId: sol['capitan_id'] ?? '',
                                    onOfertaEnviada: () {},
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.remove_red_eye, size: 18),
                            label: const Text('VER VISTA COMPLETA DEL CAPITÁN'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black87,
                              textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 0.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 14),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          Expanded(
            flex: 6,
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatFechaCompacta(dynamic raw) {
    if (raw == null) return 'A confirmar';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  String _formatFechaCompleta(dynamic raw) {
    if (raw == null) return 'N/D';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw.toString();
    }
  }

  Future<List<Map<String, dynamic>>> _getTodasLasSolicitudes() async {
    try {
      final res = await Supabase.instance.client
          .from('cotizaciones')
          .select('*, profiles:pescador_id(*)')
          .order('created_at', ascending: false);
          
      final ahora = DateTime.now();
      
      // Ocultar las solicitudes pendientes que superaron las 24 horas (vencidas)
      final validas = List<Map<String, dynamic>>.from(res).where((sol) {
        final estado = sol['estado'] ?? 'pendiente';
        if (estado == 'pendiente' && sol['created_at'] != null) {
          try {
            final createdAt = DateTime.parse(sol['created_at'].toString());
            if (ahora.difference(createdAt).inHours >= 24) {
              return false; // Filtrada
            }
          } catch (_) {}
        }
        return true;
      }).toList();

      return validas;
    } catch (e) {
      return [];
    }
  }

  Widget _buildLiquidacionesTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: SupabaseService.getLiquidacionesAdmin(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.cyanAccent));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.payments_outlined, color: Colors.white30, size: 64),
                SizedBox(height: 16),
                Text(
                  'No hay solicitudes de liquidación registradas',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }

        final liquidaciones = snapshot.data!;
        return RefreshIndicator(
          color: Colors.cyanAccent,
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: liquidaciones.length,
            itemBuilder: (context, index) {
              final liq = liquidaciones[index];
              final liqId = liq['id']?.toString() ?? '';
              final capId = liq['capitan_id']?.toString() ?? '';
              final nombre = liq['capitan_nombre'] ?? 'Capitán';
              final cbu = liq['capitan_cbu'] ?? 'No declarado';
              final monto = (liq['monto'] as num?)?.toDouble() ?? 0.0;
              final estado = liq['estado']?.toString() ?? 'pendiente';
              final fecha = liq['created_at'] != null ? _formatFechaCompleta(liq['created_at']) : 'N/D';

              final isPendiente = estado == 'pendiente';

              return Card(
                color: const Color(0xFF001F3F).withOpacity(0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: isPendiente ? Colors.orangeAccent.withOpacity(0.3) : Colors.greenAccent.withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                margin: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      colors: isPendiente
                          ? [Colors.orangeAccent.withOpacity(0.05), Colors.transparent]
                          : [Colors.greenAccent.withOpacity(0.03), Colors.transparent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isPendiente ? Colors.orange.withOpacity(0.12) : Colors.green.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isPendiente ? Icons.pending_rounded : Icons.check_circle_rounded,
                                    color: isPendiente ? Colors.orangeAccent : Colors.greenAccent,
                                    size: 20,
                                  ),
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
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'ID Capitán: ${capId.substring(0, 8)}...',
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.5),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isPendiente ? Colors.orange.withOpacity(0.2) : Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isPendiente ? Colors.orangeAccent : Colors.greenAccent,
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              estado.toUpperCase(),
                              style: TextStyle(
                                color: isPendiente ? Colors.orangeAccent : Colors.greenAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 12),
                      
                      _buildDetailRow(Icons.account_balance, 'CBU / CVU / Alias', cbu),
                      _buildDetailRow(Icons.calendar_today, 'Fecha Solicitud', fecha),
                      _buildDetailRow(Icons.monetization_on, 'Monto Solicitado', '\$${monto.toStringAsFixed(2)}'),

                      if (isPendiente) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                           width: double.infinity,
                           child: ElevatedButton.icon(
                             onPressed: () => _confirmarPagoDialog(liqId, capId, nombre, monto, cbu),
                             icon: const Icon(Icons.payment_rounded, size: 18),
                             label: const Text('CONFIRMAR TRANSFERENCIA / PAGO'),
                             style: ElevatedButton.styleFrom(
                               backgroundColor: const Color(0xFF00E676),
                               foregroundColor: Colors.black87,
                               textStyle: const TextStyle(
                                 fontWeight: FontWeight.bold,
                                 fontSize: 12,
                                 letterSpacing: 0.5,
                               ),
                               padding: const EdgeInsets.symmetric(vertical: 14),
                               shape: RoundedRectangleBorder(
                                 borderRadius: BorderRadius.circular(12),
                               ),
                               elevation: 8,
                               shadowColor: const Color(0xFF00E676).withOpacity(0.4),
                             ),
                           ),
                         ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _confirmarPagoDialog(
    String liquidacionId,
    String capitanId,
    String nombre,
    double monto,
    String cbu,
  ) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001F3F).withOpacity(0.9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.cyanAccent.withOpacity(0.3), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.payment_rounded, color: Colors.cyanAccent),
              SizedBox(width: 10),
              Text(
                'CONFIRMAR PAGO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '¿Confirmas que ya has realizado la transferencia bancaria por este retiro?',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Capitán: $nombre',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'CBU/CVU: $cbu',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Monto: \$${monto.toStringAsFixed(2)}',
                      style: const TextStyle(color: Color(0xFF00E676), fontSize: 16, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Al confirmar, el saldo del capitán se actualizará en tiempo real en su aplicación.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _procesarConfirmacionPago(liquidacionId, capitanId, nombre, monto);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('CONFIRMAR Y NOTIFICAR', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarConfirmacionPago(
    String liquidacionId,
    String capitanId,
    String nombre,
    double monto,
  ) async {
    try {
      setState(() => _isLoading = true);
      
      await SupabaseService.confirmarPagoLiquidacion(liquidacionId, capitanId);
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.black),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¡Pago de \$${monto.toStringAsFixed(2)} a $nombre confirmado y sincronizado!',
                    style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF00E676),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al confirmar pago: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
