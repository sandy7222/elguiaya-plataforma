import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../widgets/safe_button.dart';

import '../models/cotizacion.dart';
import '../services/supabase_service.dart';
import '../widgets/map_selector_widget.dart';
import 'chat_asistido_screen.dart';
import '../widgets/pronostico_mini_widget.dart';
import '../widgets/solunar_card_widget.dart';
import '../widgets/notification_quick_view.dart';
import 'pescador_perfil_edit_screen.dart';
import 'viajes_programados_screen.dart';
import '../widgets/reputacion_badge_widget.dart';
import '../services/core_business_logic.dart';
import '../services/viaje_lifecycle_service.dart';
import '../widgets/oferta_capitan_card.dart';
import '../utils/presupuesto_pescador_actions.dart';
import '../utils/view_insets.dart';
import '../widgets/radar_scanner_widget.dart';
import 'resumen_reserva_screen.dart';
import '../services/gps_tracker_service.dart';
import 'capitan_tracker_screen.dart';
import 'checkout_payment_screen.dart';

class PescadorDashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? initialQuoteData;
  /// Si es true, abre el formulario de cotización al cargar la pantalla
  final bool openFormOnLoad;

  const PescadorDashboardScreen({
    super.key,
    this.initialQuoteData,
    this.openFormOnLoad = false,
  });

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

    if (widget.initialQuoteData != null || widget.openFormOnLoad) {
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
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'presupuestos',
          callback: (payload) {
            if (mounted) _cargarDatos();
          },
        )
        .subscribe();
  }

  Future<void> _descartarPresupuesto(Map<String, dynamic> presupuesto) async {
    final pid = PresupuestoPescadorActions.idDe(presupuesto);
    if (pid.isEmpty) return;

    final resultado = await PresupuestoPescadorActions.descartarConConfirmacion(
      context,
      presupuesto,
    );
    if (resultado == null || !mounted) return;
    if (!resultado) {
      PresupuestoPescadorActions.mostrarSnackError(context);
      return;
    }

    setState(() {
      _presupuestos.removeWhere((p) => p['id']?.toString() == pid);
    });

    PresupuestoPescadorActions.mostrarSnackDescartado(context, presupuesto);
  }

  void _mostrarFormularioCotizacion({Map<String, dynamic>? initialData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FormularioCotizacionTecnica(
          onSubmit: _crearCotizacionTecnica,
          initialPuntoPartida: initialData?['partida'],
          initialPuntoDestino: initialData?['destino'],
          initialTrackLog: initialData?['trackLog'],
          initialDistanciaKM: initialData?['distancia'],
        ),
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
            builder: (context) => CheckoutPaymentScreen(
              amount: (presupuesto['monto'] as num?)?.toDouble() ?? 0.0,
              description: 'Viaje EL GUIA YA',
              reservaId: pedidoId,
              emailPagador:
                  Supabase.instance.client.auth.currentUser?.email ?? '',
            ),
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
                padding: ViewInsets.scrollPadding(
                  context,
                  top: 8,
                  extra: 28,
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
                            child: SafeElevatedIconButton(
  onPressed: _mostrarFormularioCotizacion,
  icon: Icons.add,
  label: 'Nueva Solicitud de Viaje',
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

                    if (_cotizaciones.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          final cotIds =
                              _cotizaciones.map((c) => c.id).toSet();
                          final ofertas = _presupuestos
                              .where(
                                (o) => cotIds.contains(
                                  o['cotizacion_id']?.toString(),
                                ),
                              )
                              .toList();

                          final cotMapa = _cotizacionParaMapa(ofertas);

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildRadarSearchingState(
                                ofertas.isEmpty
                                    ? 'Buscando capitanes en la zona...'
                                    : '${ofertas.length} presupuesto(s) recibido(s)',
                                cotizacion: cotMapa,
                              ),
                              if (ofertas.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                ...ofertas.map(
                                  (o) => OfertaCapitanCard(
                                    key: ValueKey(o['id']?.toString() ?? ''),
                                    oferta: o,
                                    isProcessing: _isProcessingDeal,
                                    onDiscard: () => _descartarPresupuesto(o),
                                    onAccept: () {
                                      final cotizacionId =
                                          o['cotizacion_id']?.toString() ?? '';
                                      if (cotizacionId.isNotEmpty) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                ResumenReservaScreen(
                                              cotizacionId: cotizacionId,
                                            ),
                                          ),
                                        ).then((_) => _cargarDatos());
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],

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
                if (_pescadorId != null && _pescadorId!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  ReputacionBadgeWidget(
                    userId: _pescadorId!,
                    tipo: ReputacionTipo.pescador,
                    compact: true,
                  ),
                ],
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
      onDiscard: () => _descartarPresupuesto(oferta),
      onAccept: () {
        final cotizacionId = (oferta['cotizacion_id']?.toString()) ?? 
            (_cotizaciones.isNotEmpty ? _cotizaciones.first.id : '');
        if (cotizacionId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ResumenReservaScreen(cotizacionId: cotizacionId),
            ),
          ).then((_) => _cargarDatos());
        }
      },
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

  double? _coord(Map<String, dynamic>? punto, String key) {
    if (punto == null) return null;
    final value = punto[key] ?? (key == 'lon' ? punto['lng'] : null);
    return value != null ? (value as num).toDouble() : null;
  }

  List<LatLng> _puntosTrackLog(List<Map<String, dynamic>>? trackLog) {
    if (trackLog == null || trackLog.isEmpty) return [];
    return trackLog
        .where((e) => e['lat'] != null && (e['lon'] != null || e['lng'] != null))
        .map(
          (e) => LatLng(
            (e['lat'] as num).toDouble(),
            ((e['lon'] ?? e['lng']) as num).toDouble(),
          ),
        )
        .toList();
  }

  Cotizacion? _cotizacionParaMapa(List<Map<String, dynamic>> ofertas) {
    if (_cotizaciones.isEmpty) return null;
    if (ofertas.isNotEmpty) {
      final cotId = ofertas.first['cotizacion_id']?.toString();
      for (final cot in _cotizaciones) {
        if (cot.id == cotId) return cot;
      }
    }
    return _cotizaciones.first;
  }

  Widget _buildRadarSearchingState(
    String mensaje, {
    Cotizacion? cotizacion,
  }) {
    return RadarScannerWidget(
      mensaje: mensaje,
      cotizacion: cotizacion ?? (_cotizaciones.isNotEmpty ? _cotizaciones.first : null),
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
  final ScrollController _scrollController = ScrollController();
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
  void dispose() {
    _scrollController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    super.dispose();
  }

  void _cerrarTeclado() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _setStatePreservandoScroll(VoidCallback actualizar) {
    final offset =
        _scrollController.hasClients ? _scrollController.offset : null;
    setState(actualizar);
    if (offset == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final maxExtent = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(0.0, maxExtent));
    });
  }

  void _ejecutarSinTeclado(VoidCallback accion) {
    _cerrarTeclado();
    Future.microtask(accion);
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
              child: NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification is ScrollStartNotification &&
                      notification.dragDetails != null) {
                    _cerrarTeclado();
                  }
                  return false;
                },
                child: SingleChildScrollView(
                  controller: _scrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
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
                            textInputAction: TextInputAction.next,
                            scrollPadding: const EdgeInsets.only(bottom: 140),
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
                            textInputAction: TextInputAction.done,
                            scrollPadding: const EdgeInsets.only(bottom: 140),
                            onFieldSubmitted: (_) => _cerrarTeclado(),
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
                      child: SafeElevatedIconButton(
  onPressed: () {
                          _cerrarTeclado();
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
  icon: Icons.location_searching,
  label: 'LOCALIZAR EN MAPA',
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
                            _setStatePreservandoScroll(() {
                              _puntoPartida = partida;
                              _puntoDestino = destino;
                              _trackLog = track;
                            });
                          },
                          onDistanceChanged: (dist) {
                            _setStatePreservandoScroll(() => _distanciaKM = dist);
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
                                  onTap: () => _ejecutarSinTeclado(() async {
                                    final fecha = await showDatePicker(
                                      context: context,
                                      initialDate: DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime.now().add(
                                        const Duration(days: 365),
                                      ),
                                    );
                                    if (fecha != null) {
                                      _setStatePreservandoScroll(
                                        () => _fechaIda = fecha,
                                      );
                                    }
                                  }),
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
                                  onTap: () => _ejecutarSinTeclado(() async {
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
                                    if (fecha != null) {
                                      _setStatePreservandoScroll(
                                        () => _fechaVuelta = fecha,
                                      );
                                    }
                                  }),
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
                            onTap: () => _ejecutarSinTeclado(() async {
                              final hora = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (hora != null) {
                                _setStatePreservandoScroll(
                                  () => _horaEncuentro = hora,
                                );
                              }
                            }),
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
                                    ? () => _setStatePreservandoScroll(
                                          () => _cantidadPersonas--,
                                        )
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
                                onTap: () => _setStatePreservandoScroll(
                                      () => _cantidadPersonas++,
                                    ),
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
      onTap: () => _setStatePreservandoScroll(
            () => _actividadSeleccionada = label,
          ),
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
  final List<DateTime?> _fechasNacimiento = [];
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.amountOfPeople; i++) {
      _nombreControllers.add(TextEditingController());
      _dniControllers.add(TextEditingController());
      _fechasNacimiento.add(null);
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
                      const SizedBox(height: 8),
                      _buildFechaNacimiento(index),
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
              for (int i = 0; i < widget.amountOfPeople; i++) {
                if (_fechasNacimiento[i] == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Seleccioná la fecha de nacimiento del tripulante ${i + 1}',
                      ),
                      backgroundColor: Colors.orangeAccent,
                    ),
                  );
                  return;
                }
              }
              final List<Map<String, String>> tripulantes = [];
              for (int i = 0; i < widget.amountOfPeople; i++) {
                tripulantes.add({
                  'nombre': _nombreControllers[i].text.trim(),
                  'dni': _dniControllers[i].text.trim(),
                  'fecha_nacimiento':
                      _fechasNacimiento[i]!.toIso8601String().split('T').first,
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

  Widget _buildFechaNacimiento(int index) {
    final fecha = _fechasNacimiento[index];
    final label = fecha == null
        ? 'Fecha de nacimiento *'
        : '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate:
              fecha ?? DateTime.now().subtract(const Duration(days: 365 * 30)),
          firstDate: DateTime.now().subtract(const Duration(days: 365 * 120)),
          lastDate: DateTime.now(),
          helpText: 'Fecha de nacimiento',
        );
        if (picked != null) {
          setState(() => _fechasNacimiento[index] = picked);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: fecha == null ? Colors.white24 : Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
            const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }
}
