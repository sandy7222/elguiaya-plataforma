import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/cotizacion.dart';
import '../services/supabase_service.dart';
import '../widgets/map_selector_widget.dart';
import 'chat_asistido_screen.dart';
import '../widgets/pronostico_mini_widget.dart';
import '../widgets/solunar_card_widget.dart';
import '../widgets/notification_quick_view.dart';
import 'pescador_perfil_edit_screen.dart';
import 'viajes_programados_screen.dart';
import '../services/core_business_logic.dart';
import '../services/viaje_lifecycle_service.dart';
import '../widgets/oferta_capitan_card.dart';
import 'resumen_reserva_screen.dart';
import '../services/gps_tracker_service.dart';
import 'capitan_tracker_screen.dart';

class PescadorDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? initialQuoteData;

  const PescadorDashboardScreen({super.key, this.initialQuoteData});

  @override
  State<PescadorDashboardScreen> createState() =>
      _PescadorDashboardScreenState();
}

class _PescadorDashboardScreenState extends State<PescadorDashboardScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Cotizacion> _cotizaciones = [];
  List<Map<String, dynamic>> _presupuestos = [];
  final List<Map<String, dynamic>> _productosRecomendados = [];
  bool _isLoading = true;
  RealtimeChannel? _cotizacionesChannel;

  // ID de prueba para el pescador
  String? _pescadorId;
  String _nombrePescador = 'Pescador';
  String? _avatarUrl;

  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);

  bool _isProcessingDeal = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatos();
    _configurarRealtime();

    if (widget.initialQuoteData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarFormularioCotizacion(initialData: widget.initialQuoteData);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cotizacionesChannel?.unsubscribe();
    GpsTrackerService().stopTracking();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configurarRealtime();
    }
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);

      // Obtener ID real
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        print('⚠️ [DASHBOARD] No hay usuario logueado. Usando modo invitado.');
        setState(() => _isLoading = false);
        return;
      }

      _pescadorId = user.id;

      // Cargar datos de perfil completo para la cabecera y auto-sincronización legada
      final perfil = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('user_id', _pescadorId!)
          .maybeSingle();

      if (perfil != null && perfil['estado'] == 'activo') {
        // Auto-sincronizar el perfil del pescador en la tabla legada 'pescadores'.
        // Esto se ejecuta bajo la sesión activa del pescador, superando las restricciones RLS.
        SupabaseService.traspasarSocioALegado(perfil).catchError((e) {
          print('⚠️ [AUTO-SYNC] Error en auto-sincronización del pescador: $e');
        });
      }

      // Cargar cotizaciones y presupuestos
      final cotizaciones = await SupabaseService.getCotizacionesPescador(
        _pescadorId!,
      );
      final presupuestos = await SupabaseService.getPresupuestosPescador(
        _pescadorId!,
      );

      if (mounted) {
        setState(() {
          if (perfil != null) {
            _nombrePescador = perfil['nombre'] ?? perfil['full_name'] ?? 'Pescador';
            _avatarUrl = perfil['avatar_url'];
          }
          _cotizaciones = cotizaciones;
          _presupuestos = presupuestos;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar datos: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _configurarRealtime() {
    _cotizacionesChannel?.unsubscribe();

    _cotizacionesChannel = Supabase.instance.client
        .channel('cotizaciones_pescador_$_pescadorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'cotizaciones',
          filter: PostgresChangeFilter(
            column: 'pescador_id',
            type: PostgresChangeFilterType.eq,
            value: _pescadorId,
          ),
          callback: (payload) {
            if (mounted) _cargarDatos();
          },
        )
        .subscribe();
  }

  void _mostrarFormularioCotizacion({Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FormularioCotizacionTecnica(
        onSubmit: _crearCotizacionTecnica,
        initialPuntoPartida: initialData?['partida'],
        initialPuntoDestino: initialData?['destino'],
        initialTrackLog: initialData?['trackLog'],
        initialDistanciaKM: initialData?['distancia'],
      ),
    );
  }

  Future<void> _crearCotizacionTecnica(Map<String, dynamic> datos) async {
    try {
      final resultado = await SupabaseService.crearCotizacionTecnica(datos);

      if (mounted) {
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('✅ Cotizacion creada exitosamente')),
              backgroundColor: _verdeExito,
            ),
          );
          Navigator.pop(context); // Cerrar el formulario
          _cargarDatos(); // Recargar datos
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('Error: ${resultado['mensaje']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al crear cotizacion: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _aceptarPresupuestoReal(Map<String, dynamic> oferta) async {
    try {
      setState(() => _isProcessingDeal = true);

      // Usamos el servicio disponible para cerrar el viaje
      final pedidoId = await ViajeLifecycleService.aceptarPresupuesto(
        presupuesto: oferta,
        pescadorId: _pescadorId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                '✅ ¡VIAJE CONFIRMADO! ID: ${pedidoId.substring(0, 8)}',
              ),
            ),
            backgroundColor: _verdeExito,
          ),
        );

        // Navegar a la agenda de viajes programados
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const ViajesProgramadosScreen(esCapitan: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingDeal = false);
    }
  }

  void _mostrarDialogoProductosAdicionales(Map<String, dynamic> presupuesto) {
    showDialog(
      context: context,
      builder: (context) => _ProductosAdicionalesDialog(
        presupuesto: presupuesto,
        onConfirm: (productos, retiroLancha) {
          Navigator.pop(context); // Cerrar dialogo de productos
          _mostrarManifiestoTripulantes(presupuesto, productos, retiroLancha);
        },
      ),
    );
  }

  void _mostrarManifiestoTripulantes(
    Map<String, dynamic> presupuesto,
    List<Map<String, dynamic>> productos,
    bool retiroLancha,
  ) {
    final int cantidadPersonas = presupuesto['cantidad_personas'] ?? 1;

    showDialog(
      context: context,
      barrierDismissible: false, // Obligatorio completar
      builder: (context) => _ManifiestoTripulantesDialog(
        amountOfPeople: cantidadPersonas,
        onConfirm: (tripulantes) {
          _procesarAceptacionPresupuesto(
            presupuesto,
            productos,
            retiroLancha,
            tripulantes,
          );
        },
      ),
    );
  }

  Future<void> _procesarAceptacionPresupuesto(
    Map<String, dynamic> presupuesto,
    List<Map<String, dynamic>> productos,
    bool retiroLancha,
    List<Map<String, String>> tripulantes,
  ) async {
    try {
      setState(() => _isLoading = true);

      final pedidoId = await ViajeLifecycleService.aceptarPresupuesto(
        presupuesto: presupuesto,
        pescadorId: _pescadorId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                '✅ ¡VIAJE PROGRAMADO! ID: ${pedidoId.substring(0, 8)}',
              ),
            ),
            backgroundColor: _verdeExito,
          ),
        );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const ViajesProgramadosScreen(esCapitan: false),
          ),
        );

        _cargarDatos();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text(
          'Panel del Pescador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          const NotificationQuickView(),
          IconButton(
            icon: const Icon(Icons.calendar_month, color: Color(0xFF00E676)),
            tooltip: 'Mis Viajes Programados',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ViajesProgramadosScreen(esCapitan: false),
              ),
            ),
          ),

          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'Recargar',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserInfoHeader(),
                    const SizedBox(height: 20),
                    const PronosticoMiniWidget(),
                    const SizedBox(height: 12),
                    const SolunarCardWidget(),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _azulNautico,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.sailing,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '¡Bienvenido al Panel!',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Solicita tu viaje y recibe presupuestos en tiempo real',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _mostrarFormularioCotizacion,
                              icon: const Icon(Icons.add),
                              label: const Text('Nueva Solicitud de Viaje'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: _azulNautico,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_cotizaciones.isNotEmpty)
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: Supabase.instance.client
                            .from('presupuestos')
                            .stream(primaryKey: ['id'])
                            .eq('cotizacion_id', _cotizaciones.first.id)
                            .map(
                              (maps) => List<Map<String, dynamic>>.from(maps),
                            ),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return _buildRadarSearchingState(
                              'Reconectando radar...',
                            );
                          }

                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF00E676),
                              ),
                            );
                          }

                          final ofertas = snapshot.data ?? [];
                          if (ofertas.isEmpty) {
                            return _buildRadarSearchingState(
                              'Buscando capitanes en la zona...',
                            );
                          }

                          return Column(
                            children: ofertas
                                .map((o) => _buildPresupuestoCard(o))
                                .toList(),
                          );
                        },
                      ),

                    if (_cotizaciones.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Solicitudes Pendientes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._cotizaciones.map(
                        (cotizacion) => _buildCotizacionCard(cotizacion),
                      ),
                    ],

                    if (_presupuestos.isEmpty && _cotizaciones.isEmpty) ...[
                      const SizedBox(height: 40),
                      _buildEstadoVacio(),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUserInfoHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              color: Color(0xFF00E676),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 35,
              backgroundColor: const Color(0xFF001F3F),
              backgroundImage: _avatarUrl != null
                  ? NetworkImage(_avatarUrl!)
                  : null,
              child: _avatarUrl == null
                  ? const Icon(Icons.person, color: Colors.white, size: 30)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Hola, $_nombrePescador!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PescadorPerfilEditScreen(),
                    ),
                  ).then((_) => _cargarDatos()),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF00E676).withOpacity(0.5),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.manage_accounts,
                          color: Color(0xFF00E676),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'MI IDENTIDAD PESCADOR',
                            style: TextStyle(
                              color: Color(0xFF00E676),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresupuestoCard(Map<String, dynamic> oferta) {
    return OfertaCapitanCard(
      oferta: oferta,
      isProcessing: _isProcessingDeal,
      onAccept: () => _aceptarPresupuestoReal(oferta),
    );
  }

  Widget _buildCotizacionCard(Cotizacion cotizacion) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.pending, color: _naranjaAlerta, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cotizacion.descripcion,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF001F3F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.black12, height: 1, thickness: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Estado',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Esperando presupuesto...',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Tiempo Restante',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    _buildAuctionTimer(cotizacion.createdAt),
                  ],
                ),
              ],
            ),
            if (cotizacion.tieneDatosGeograficos) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Distancia: ${cotizacion.distanciaFormateada}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _azulNautico.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.sailing_outlined, size: 64, color: _azulNautico),
          ),
          const SizedBox(height: 24),
          const Text(
            'No tienes solicitudes activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primera solicitud de viaje\ny recibe presupuestos en tiempo real',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _mostrarFormularioCotizacion,
            icon: const Icon(Icons.add),
            label: const Text('Nueva Solicitud de Viaje'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulNautico,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuctionTimer(DateTime createdAt) {
    final expiraEn = createdAt.add(const Duration(hours: 24));

    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final ahora = DateTime.now();
        final diferencia = expiraEn.difference(ahora);

        if (diferencia.isNegative) {
          return const Text(
            'Subasta terminada',
            style: TextStyle(
              color: Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          );
        }

        final h = diferencia.inHours.toString().padLeft(2, '0');
        final m = (diferencia.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diferencia.inSeconds % 60).toString().padLeft(2, '0');

        return Text(
          'Expira en: $h:$m:$s',
          style: const TextStyle(
            color: Color(0xFF10B981),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  }

  Widget _buildRadarSearchingState(String mensaje) {
    return RadarScannerWidget(
      mensaje: mensaje,
      cotizacion: _cotizaciones.isNotEmpty ? _cotizaciones.first : null,
    );
  }
}

class RadarScannerWidget extends StatefulWidget {
  final String mensaje;
  final Cotizacion? cotizacion;
  const RadarScannerWidget({
    required this.mensaje,
    this.cotizacion,
    super.key,
  });

  @override
  State<RadarScannerWidget> createState() => _RadarScannerWidgetState();
}

class _RadarScannerWidgetState extends State<RadarScannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_RadarBlip> _blips = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    // Generar blips aleatorios simulando capitanes en la zona
    for (int i = 0; i < 4; i++) {
      final angle = _random.nextDouble() * 2 * pi;
      final distance = 0.2 + _random.nextDouble() * 0.6; // Entre 20% y 80% del radio
      _blips.add(_RadarBlip(
        angle: angle,
        distance: distance,
        size: 3.0 + _random.nextDouble() * 3.0,
        baseOpacity: 0.3 + _random.nextDouble() * 0.7,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  LatLng getMapCenter() {
    if (widget.cotizacion != null && widget.cotizacion!.tieneDatosGeograficos) {
      final lat1 = widget.cotizacion!.latitudPartida;
      final lon1 = widget.cotizacion!.longitudPartida;
      final lat2 = widget.cotizacion!.latitudDestino;
      final lon2 = widget.cotizacion!.longitudDestino;
      if (lat1 != null && lon1 != null && lat2 != null && lon2 != null) {
        return LatLng((lat1 + lat2) / 2, (lon1 + lon2) / 2);
      }
    }
    return const LatLng(-34.4250, -58.5796); // San Fernando por defecto
  }

  double getMapZoom() {
    if (widget.cotizacion != null && widget.cotizacion!.distanciaKm != null) {
      final dist = widget.cotizacion!.distanciaKm!;
      if (dist < 2.0) return 15.0;
      if (dist < 5.0) return 14.0;
      if (dist < 15.0) return 13.0;
      if (dist < 40.0) return 11.5;
      return 10.0;
    }
    return 13.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF001F3F).withOpacity(0.6), // Fondo oscuro náutico
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00E676).withOpacity(0.03),
            blurRadius: 15,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        children: [
          // Plato del radar rectangular (Full-Width)
          Container(
            height: 190,
            width: double.infinity,
            clipBehavior: Clip.antiAlias, // Recorta todos los hijos al radio de borde!
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00E676).withOpacity(0.15)),
            ),
            child: Stack(
              children: [
                // Capa de mapa recortada rectangularmente con esquinas redondeadas
                Container(
                  color: const Color(0xFF000B18), // Fondo azul oscuro ultra profundo
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: getMapCenter(),
                      initialZoom: getMapZoom(),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.none, // Deshabilitar interacciones
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.El Guia YA',
                      ),
                      if (widget.cotizacion != null && widget.cotizacion!.tieneDatosGeograficos) ...[
                        PolylineLayer(
                          polylines: <Polyline<Object>>[
                            if (widget.cotizacion!.trackLog != null && widget.cotizacion!.trackLog!.isNotEmpty)
                              Polyline<Object>(
                                points: widget.cotizacion!.trackLog!
                                    .map((e) => LatLng((e['lat'] as num).toDouble(), (e['lon'] as num).toDouble()))
                                    .toList(),
                                strokeWidth: 3.0,
                                color: const Color(0xFF00E676).withOpacity(0.6),
                              )
                            else
                              Polyline<Object>(
                                points: [
                                  LatLng(widget.cotizacion!.latitudPartida!, widget.cotizacion!.longitudPartida!),
                                  LatLng(widget.cotizacion!.latitudDestino!, widget.cotizacion!.longitudDestino!),
                                ],
                                strokeWidth: 2.0,
                                color: const Color(0xFF00E676).withOpacity(0.4),
                              ),
                          ],
                        ),
                        MarkerLayer(
                          markers: [
                            if (widget.cotizacion!.latitudPartida != null && widget.cotizacion!.longitudPartida != null)
                              Marker(
                                point: LatLng(widget.cotizacion!.latitudPartida!, widget.cotizacion!.longitudPartida!),
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00E676),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Color(0xFF00E676), blurRadius: 4, spreadRadius: 1),
                                    ],
                                  ),
                                ),
                              ),
                            if (widget.cotizacion!.latitudDestino != null && widget.cotizacion!.longitudDestino != null)
                              Marker(
                                point: LatLng(widget.cotizacion!.latitudDestino!, widget.cotizacion!.longitudDestino!),
                                width: 12,
                                height: 12,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(color: Colors.redAccent, blurRadius: 4, spreadRadius: 1),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                // Superposición de tinte muy suave para integrar el mapa con la consola táctica sin oscurecerlo
                IgnorePointer(
                  child: Container(
                    color: Colors.black.withOpacity(0.05),
                  ),
                ),
                // Indicadores de grados laterales a la izquierda
                Positioned(
                  left: 12,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('300°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('285°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('270°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('255°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('240°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // Indicadores de grados laterales a la derecha
                Positioned(
                  right: 12,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('60°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('75°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('90°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('105°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                        Text('120°', style: TextStyle(color: const Color(0xFF00E676).withOpacity(0.6), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                // Superposición del Painter de Radar (anillos, haz rotativo y blips)
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _controller,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _RadarPainter(
                            sweepAngle: _controller.value * 2 * pi,
                            blips: _blips,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Texto palpitante
          _PalpitandoTexto(mensaje: widget.mensaje),
        ],
      ),
    );
  }
}

class _RadarBlip {
  final double angle;
  final double distance;
  final double size;
  final double baseOpacity;

  _RadarBlip({
    required this.angle,
    required this.distance,
    required this.size,
    required this.baseOpacity,
  });
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final List<_RadarBlip> blips;

  _RadarPainter({required this.sweepAngle, required this.blips});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;
    // Teorema de Pitágoras para obtener el radio máximo hasta las esquinas del rectángulo
    final maxRadius = sqrt(size.width * size.width + size.height * size.height) / 2;

    // Fondo del radar (translúcido verde)
    final bgPaint = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.02)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // Círculos concéntricos de la grilla
    final gridPaint = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius, gridPaint);
    canvas.drawCircle(center, radius * 0.75, gridPaint);
    canvas.drawCircle(center, radius * 0.5, gridPaint);
    canvas.drawCircle(center, radius * 0.25, gridPaint);

    // Ejes cartesianos cruzados del radar (se extienden por toda la superficie)
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), gridPaint);
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), gridPaint);

    // (Líneas auxiliares de 45° eliminadas para mayor claridad visual del mapa)

    // Pintar los Blips de capitanes (puntos verdes palpitantes distribuidos a lo ancho)
    for (final blip in blips) {
      double diff = (sweepAngle - blip.angle) % (2 * pi);
      if (diff < 0) diff += 2 * pi;

      double opacity = 0.0;
      if (diff < pi / 2) {
        opacity = (1.0 - (diff / (pi / 2))) * blip.baseOpacity;
      } else if (diff > 1.5 * pi) {
        opacity = 0.05;
      } else {
        opacity = 0.05;
      }

      if (opacity > 0.0) {
        final blipX = center.dx + cos(blip.angle) * maxRadius * blip.distance;
        final blipY = center.dy + sin(blip.angle) * maxRadius * blip.distance;

        final blipPaint = Paint()
          ..color = const Color(0xFF00E676).withOpacity(opacity)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(blipX, blipY), blip.size, blipPaint);

        final glowPaint = Paint()
          ..color = const Color(0xFF00E676).withOpacity(opacity * 0.4)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(Offset(blipX, blipY), blip.size * 2.2, glowPaint);
      }
    }

    // Dibujar el haz/barrido del radar cubriendo TODO el rectángulo (Sweep Gradient)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * pi,
        colors: [
          const Color(0xFF00E676).withOpacity(0.25),
          const Color(0xFF00E676).withOpacity(0.08),
          const Color(0xFF00E676).withOpacity(0.0),
          const Color(0xFF00E676).withOpacity(0.0),
        ],
        stops: const [0.0, 0.15, 0.4, 1.0],
        transform: GradientRotation(sweepAngle - 0.2),
      ).createShader(Rect.fromCircle(center: center, radius: maxRadius))
      ..style = PaintingStyle.fill;

    // Pintar sobre el rectángulo completo
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), sweepPaint);

    // Aguja brillante al frente del haz que llega hasta los bordes y esquinas
    final sweepLinePaint = Paint()
      ..color = const Color(0xFF00E676).withOpacity(0.7)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;
    
    final lineEndX = center.dx + cos(sweepAngle) * maxRadius;
    final lineEndY = center.dy + sin(sweepAngle) * maxRadius;
    canvas.drawLine(center, Offset(lineEndX, lineEndY), sweepLinePaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}

class _PalpitandoTexto extends StatefulWidget {
  final String mensaje;
  const _PalpitandoTexto({required this.mensaje});

  @override
  State<_PalpitandoTexto> createState() => _PalpitandoTextoState();
}

class _PalpitandoTextoState extends State<_PalpitandoTexto>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_fadeController);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF00E676),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Color(0xFF00E676),
                  blurRadius: 6,
                  spreadRadius: 2,
                )
              ]
            ),
          ),
          const SizedBox(width: 10),
          Text(
            widget.mensaje,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  color: Color(0xFF00E676),
                  blurRadius: 4,
                )
              ]
            ),
          ),
        ],
      ),
    );
  }
}

class FormularioCotizacionTecnica extends StatefulWidget {
  final Function(Map<String, dynamic>) onSubmit;
  final Map<String, dynamic>? initialPuntoPartida;
  final Map<String, dynamic>? initialPuntoDestino;
  final List<Map<String, dynamic>>? initialTrackLog;
  final double? initialDistanciaKM;

  const FormularioCotizacionTecnica({
    required this.onSubmit,
    this.initialPuntoPartida,
    this.initialPuntoDestino,
    this.initialTrackLog,
    this.initialDistanciaKM,
    super.key,
  });

  @override
  State<FormularioCotizacionTecnica> createState() =>
      FormularioCotizacionTecnicaState();
}

class FormularioCotizacionTecnicaState
    extends State<FormularioCotizacionTecnica> {
  final _formKey = GlobalKey<FormState>();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  String _actividadSeleccionada = 'Turismo';

  final GlobalKey<MapSelectorWidgetState> _mapSelectorKey = GlobalKey();
  Map<String, dynamic>? _puntoPartida;
  Map<String, dynamic>? _puntoDestino;
  double _distanciaKM = 0.0;
  DateTime? _fechaIda;
  DateTime? _fechaVuelta;
  TimeOfDay? _horaEncuentro;
  int _cantidadPersonas = 1;
  List<Map<String, dynamic>> _trackLog = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _puntoPartida = widget.initialPuntoPartida;
    _puntoDestino = widget.initialPuntoDestino;
    if (widget.initialTrackLog != null) {
      _trackLog = List.from(widget.initialTrackLog!);
    }
    _distanciaKM = widget.initialDistanciaKM ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.sailing,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Solicitud de Viaje',
                        style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      Text(
                        'Configura tu próxima experiencia',
                        style: GoogleFonts.outfit(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('¿Qué quieres hacer?'),
                    const SizedBox(height: 12),
                    runActivityChips(),

                    const SizedBox(height: 16),
                    _buildSectionTitle('Zona de Operación'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _localidadController,
                            style: GoogleFonts.outfit(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Localidad / Ciudad',
                              labelStyle: GoogleFonts.outfit(fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              prefixIcon: const Icon(
                                Icons.location_city,
                                color: Color(0xFF1565C0),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _provinciaController,
                            style: GoogleFonts.outfit(fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Provincia',
                              labelStyle: GoogleFonts.outfit(fontSize: 14),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty)
                                return 'Requerido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final query =
                              '${_localidadController.text} ${_provinciaController.text}';
                          if (query.trim().length > 3) {
                            _mapSelectorKey.currentState?.searchAndZoom(query);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Ingresa una localidad y provincia',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.location_searching),
                        label: const Text('LOCALIZAR EN MAPA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildSectionTitle('Trazado del Recorrido'),
                        if (_distanciaKM > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_distanciaKM.toStringAsFixed(1)} KM',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF1565C0),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      'Toca el mapa para definir el punto de inicio y destino',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 400,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: MapSelectorWidget(
                          key: _mapSelectorKey,
                          partidaInicial: widget.initialPuntoPartida,
                          destinoInicial: widget.initialPuntoDestino,
                          trackLogInicial: widget.initialTrackLog,
                          onRouteSelected: (partida, destino, track) {
                            setState(() {
                              _puntoPartida = partida;
                              _puntoDestino = destino;
                              _trackLog = track;
                            });
                          },
                          onDistanceChanged: (dist) {
                            setState(() => _distanciaKM = dist);
                          },
                        ),
                      ),
                    ),

                    if (_distanciaKM > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF1565C0).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.straighten,
                                color: Color(0xFF1565C0),
                              ),
                              const SizedBox(width: 12),
                              Flexible(
                                child: Text(
                                  'DISTANCIA ESTIMADA: ${_distanciaKM.toStringAsFixed(2)} KM',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1565C0),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    _buildSectionTitle('Cronograma del Viaje'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDateTimePicker(
                                  title: 'Fecha Ida',
                                  value: _fechaIda != null
                                      ? DateFormat('dd MMM').format(_fechaIda!)
                                      : 'Selec.',
                                  icon: Icons.calendar_today,
                                  onTap: () async {
                                    final fecha = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (fecha != null)
                                      setState(() => _fechaIda = fecha);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDateTimePicker(
                                  title: 'Fecha Vuelta',
                                  value: _fechaVuelta != null
                                      ? DateFormat(
                                          'dd MMM',
                                        ).format(_fechaVuelta!)
                                      : 'Selec.',
                                  icon: Icons.calendar_today,
                                  onTap: () async {
                                    final fecha = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _fechaIda?.add(
                                            const Duration(days: 1),
                                          ) ??
                                          DateTime.now().add(
                                            const Duration(days: 1),
                                          ),
                                      firstDate: _fechaIda ?? DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (fecha != null)
                                      setState(() => _fechaVuelta = fecha);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          _buildDateTimePicker(
                            title: 'Hora de Encuentro',
                            value: _horaEncuentro != null
                                ? _horaEncuentro!.format(context)
                                : 'Seleccionar hora',
                            icon: Icons.access_time,
                            isFullWidth: true,
                            onTap: () async {
                              final hora = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (hora != null)
                                setState(() => _horaEncuentro = hora);
                            },
                          ),
                        ],
                      ),
                    ),

                    _buildSectionTitle('Capacidad'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.people,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cant. personas',
                                  style: GoogleFonts.outfit(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'Ajusta el total de pasajeros',
                                  style: GoogleFonts.outfit(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              _buildStepperButton(
                                icon: Icons.remove,
                                onTap: _cantidadPersonas > 1
                                    ? () => setState(() => _cantidadPersonas--)
                                    : null,
                              ),
                              Container(
                                width: 45,
                                alignment: Alignment.center,
                                child: Text(
                                  '$_cantidadPersonas',
                                  style: GoogleFonts.outfit(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1565C0),
                                  ),
                                ),
                              ),
                              _buildStepperButton(
                                icon: Icons.add,
                                onTap: () =>
                                    setState(() => _cantidadPersonas++),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    Container(
                      width: double.infinity,
                      height: 58,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        gradient: LinearGradient(
                          colors: _isLoading
                              ? [Colors.grey, Colors.grey[400]!]
                              : [
                                  const Color(0xFF1565C0),
                                  const Color(0xFF0D47A1),
                                ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _isLoading ? null : _enviarSolicitud,
                          borderRadius: BorderRadius.circular(18),
                          child: Center(
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'ENVIAR SOLICITUD',
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget runActivityChips() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _buildActivityChip('Pesca Deportiva', Icons.phishing),
        _buildActivityChip('Viajes a la Isla', Icons.directions_ferry),
        _buildActivityChip('Turismo', Icons.camera_alt),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: const Color(0xFF1565C0),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildActivityChip(String label, IconData icon) {
    final bool isSelected = _actividadSeleccionada == label;
    return GestureDetector(
      onTap: () => setState(() => _actividadSeleccionada = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1565C0) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF1565C0) : Colors.grey[300]!,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimePicker({
    required String title,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1565C0)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperButton({required IconData icon, VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
              color: onTap == null
                  ? Colors.grey[300]!
                  : const Color(0xFF1565C0).withOpacity(0.5),
            ),
            borderRadius: BorderRadius.circular(10),
            color: onTap == null ? Colors.grey[50] : Colors.white,
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null ? Colors.grey : const Color(0xFF1565C0),
          ),
        ),
      ),
    );
  }

  Future<void> _enviarSolicitud() async {
    if (!_formKey.currentState!.validate()) return;
    final supabase = Supabase.instance.client;

    if (_fechaIda == null || _fechaVuelta == null || _horaEncuentro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(
            child: Text('Por favor, completa el cronograma del viaje'),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final datos = {
        'pescador_id': userId,
        'descripcion': _actividadSeleccionada,
        'coordenadas_partida': _puntoPartida,
        'coordenadas_destino': _puntoDestino,
        'localidad_partida': _localidadController.text,
        'provincia_partida': _provinciaController.text,
        'localidad_destino': _localidadController.text,
        'provincia_destino': _provinciaController.text,
        'lugar_encuentro': 'A convenir tras el pago',
        'distancia_km': _distanciaKM,
        'fecha_ida': _fechaIda!.toIso8601String(),
        'fecha_vuelta': _fechaVuelta!.toIso8601String(),
        'hora_encuentro':
            '${_horaEncuentro!.hour.toString().padLeft(2, '0')}:${_horaEncuentro!.minute.toString().padLeft(2, '0')}:00',
        'cantidad_personas': _cantidadPersonas,
        'track_log': _trackLog,
      };

      await widget.onSubmit(datos);
    } catch (e) {
      // Error manejado
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

class _ProductosAdicionalesDialog extends StatefulWidget {
  final Map<String, dynamic> presupuesto;
  final Function(List<Map<String, dynamic>>, bool) onConfirm;

  const _ProductosAdicionalesDialog({
    required this.presupuesto,
    required this.onConfirm,
  });

  @override
  State<_ProductosAdicionalesDialog> createState() =>
      _ProductosAdicionalesDialogState();
}

class _ProductosAdicionalesDialogState
    extends State<_ProductosAdicionalesDialog> {
  final List<Map<String, dynamic>> _productosSeleccionados = [];
  bool _retiroLancha = false;
  final bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Productos Adicionales'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Agrega productos adicionales a tu viaje',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),

            CheckboxListTile(
              title: const Text('Retirar en la lancha'),
              subtitle: const Text(
                'El capitan llevara los productos seleccionados',
              ),
              value: _retiroLancha,
              onChanged: (value) {
                setState(() => _retiroLancha = value!);
              },
            ),

            const Divider(),

            const Text(
              'Productos recomendados',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            SizedBox(
              height: 200,
              child: ListView(
                children: [
                  _buildProductoItem('Carnada fresca', 500.0, 'carnada'),
                  _buildProductoItem('Bebidas (pack x6)', 800.0, 'bebidas'),
                  _buildProductoItem('Equipo de pesca', 1200.0, 'equipos'),
                  _buildProductoItem('Chaleco salvavidas', 300.0, 'seguridad'),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading
              ? null
              : () {
                  widget.onConfirm(_productosSeleccionados, _retiroLancha);
                },
          child: _isLoading
              ? const CircularProgressIndicator()
              : const Text('Confirmar'),
        ),
      ],
    );
  }

  Widget _buildProductoItem(String nombre, double precio, String categoria) {
    final isSelected = _productosSeleccionados.any(
      (p) => p['nombre'] == nombre,
    );

    return CheckboxListTile(
      title: Text(nombre),
      subtitle: Text('\$${precio.toStringAsFixed(2)}'),
      value: isSelected,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            _productosSeleccionados.add({
              'nombre': nombre,
              'precio': precio,
              'categoria': categoria,
              'cantidad': 1,
            });
          } else {
            _productosSeleccionados.removeWhere((p) => p['nombre'] == nombre);
          }
        });
      },
    );
  }
}

class _ManifiestoTripulantesDialog extends StatefulWidget {
  final int amountOfPeople;
  final Function(List<Map<String, String>>) onConfirm;

  const _ManifiestoTripulantesDialog({
    required this.amountOfPeople,
    required this.onConfirm,
  });

  @override
  State<_ManifiestoTripulantesDialog> createState() =>
      _ManifiestoTripulantesDialogState();
}

class _ManifiestoTripulantesDialogState
    extends State<_ManifiestoTripulantesDialog> {
  final List<TextEditingController> _nombreControllers = [];
  final List<TextEditingController> _dniControllers = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.amountOfPeople; i++) {
      _nombreControllers.add(TextEditingController());
      _dniControllers.add(TextEditingController());
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF001F3F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Column(
        children: [
          const Icon(
            Icons.assignment_rounded,
            color: Color(0xFF00E676),
            size: 40,
          ),
          const SizedBox(height: 12),
          const Text(
            'MANIFIESTO DE DESPACHO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'Ingresá los datos para el seguro del viaje',
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.amountOfPeople,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TRIPULANTE #${index + 1}${index == 0 ? " (TITULAR)" : ""}',
                        style: const TextStyle(
                          color: Color(0xFF00E676),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildField(
                        'Nombre y Apellido',
                        _nombreControllers[index],
                      ),
                      const SizedBox(height: 8),
                      _buildField(
                        'DNI / Pasaporte',
                        _dniControllers[index],
                        isDni: true,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text(
            'CANCELAR',
            style: TextStyle(color: Colors.white54),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              final List<Map<String, String>> tripulantes = [];
              for (int i = 0; i < widget.amountOfPeople; i++) {
                tripulantes.add({
                  'nombre': _nombreControllers[i].text.trim(),
                  'dni': _dniControllers[i].text.trim(),
                });
              }
              widget.onConfirm(tripulantes);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E676),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'PASAR AL PAGO',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String hint,
    TextEditingController controller, {
    bool isDni = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      keyboardType: isDni ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white24),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
    );
  }
}
