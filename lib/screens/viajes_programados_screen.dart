import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/supabase_service.dart';
import '../services/mercado_pago_service.dart';
import '../services/viaje_lifecycle_service.dart';
import '../widgets/safe_button.dart';
import '../widgets/failsafe_background.dart';
import '../widgets/calificacion_pescador_dialog.dart';
import '../widgets/reputacion_badge_widget.dart';
import '../utils/fecha_nacimiento_utils.dart';
import '../widgets/descargar_despacho_pna_button.dart';
import 'ficha_contractual_screen.dart';
import 'ficha_pescador_screen.dart';
import 'chat_screen.dart';
import 'confirmar_finalizacion_screen.dart';
import 'checkout_payment_screen.dart';

class ViajesProgramadosScreen extends StatefulWidget {
  final bool esCapitan;
  const ViajesProgramadosScreen({super.key, required this.esCapitan});

  @override
  State<ViajesProgramadosScreen> createState() =>
      _ViajesProgramadosScreenState();
}

class _ViajesProgramadosScreenState extends State<ViajesProgramadosScreen> {
  List<Map<String, dynamic>> _viajes = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarViajes();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {}); // Refresh para la cuenta regresiva
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarViajes() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final query = SupabaseService.supabase.from('pedidos').select('''
        *,
        presupuestos (*),
        profiles:pescador_id (nombre, avatar_url, telefono),
        capitan:capitan_id (nombre, avatar_url, telefono)
      ''');

      final response =
          await (widget.esCapitan
                  ? query.eq('capitan_id', userId)
                  : query.eq('pescador_id', userId))
              .order('fecha_servicio', ascending: true);

      setState(() {
        _viajes = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando viajes: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _abrirCheckoutPago(Map<String, dynamic> viaje) async {
    final pedidoId = viaje['id']?.toString() ?? '';
    if (pedidoId.isEmpty) return;

    final monto = (viaje['monto_total'] as num?)?.toDouble() ?? 0.0;
    final email = SupabaseService.supabase.auth.currentUser?.email ?? '';

    try {
      final preferencia = await MercadoPagoService.crearPreferencia(
        reservaId: pedidoId,
        titulo: 'Viaje EL GUIA YA',
        monto: monto,
        emailPagador: email,
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckoutPaymentScreen(
            amount: monto,
            description: 'Viaje EL GUIA YA',
            reservaId: pedidoId,
            emailPagador: email,
            initPoint: preferencia.linkPago,
            preferenceId: preferencia.preferenceId,
          ),
        ),
      );

      if (mounted) _cargarViajes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al abrir el pago: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  String _codigoViaje(String id) {
    if (id.isEmpty) return 'VJ-----';
    final clean = id.replaceAll('-', '').toUpperCase();
    final n = clean.length >= 4 ? 4 : clean.length;
    return 'VJ-${clean.substring(0, n)}';
  }

  /// GPS OBLIGATORIO para el capitán: valida servicio + permiso antes de iniciar.
  /// Devuelve true solo si la ubicación está disponible.
  Future<bool> _asegurarUbicacionCapitan() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        _mostrarDialogoUbicacion(
          'Activá la ubicación del celular',
          'Para iniciar el viaje necesitás encender el GPS del dispositivo. '
              'Es obligatorio para registrar el recorrido y poder cobrar tus viajes.',
          abrirConfig: () => Geolocator.openLocationSettings(),
        );
      }
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        _mostrarDialogoUbicacion(
          'Permiso de ubicación requerido',
          'Necesitamos tu ubicación para registrar el recorrido del viaje. '
              'Permití el acceso para poder iniciar y cobrar tus viajes.',
        );
      }
      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        _mostrarDialogoUbicacion(
          'Permiso de ubicación bloqueado',
          'El permiso está bloqueado. Activalo manualmente en los ajustes de '
              'la app para poder iniciar viajes.',
          abrirConfig: () => Geolocator.openAppSettings(),
        );
      }
      return false;
    }

    return true;
  }

  void _mostrarDialogoUbicacion(String titulo, String mensaje,
      {VoidCallback? abrirConfig}) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: Colors.orangeAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(titulo,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(mensaje,
            style: const TextStyle(color: Colors.white70, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido',
                style: TextStyle(color: Colors.white54)),
          ),
          if (abrirConfig != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                abrirConfig();
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black),
              child: const Text('Abrir ajustes'),
            ),
        ],
      ),
    );
  }

  Future<void> _iniciarViajeCapitan(Map<String, dynamic> viaje) async {
    final pedidoId = viaje['id']?.toString() ?? '';
    final capitanId = SupabaseService.currentUserId ?? '';
    if (pedidoId.isEmpty || capitanId.isEmpty) return;

    // GPS obligatorio: si no hay ubicación disponible, no se inicia el viaje.
    final ubicacionOk = await _asegurarUbicacionCapitan();
    if (!ubicacionOk) return;

    try {
      await ViajeLifecycleService.iniciarViaje(
          pedidoId: pedidoId, capitanId: capitanId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('⛵ Viaje iniciado'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating));
        _cargarViajes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al iniciar: $e'),
            backgroundColor: Colors.redAccent));
      }
    }
  }

  Future<void> _finalizarViajeCapitan(Map<String, dynamic> viaje) async {
    final pedidoId = viaje['id']?.toString() ?? '';
    final capitanId = SupabaseService.currentUserId ?? '';
    if (pedidoId.isEmpty || capitanId.isEmpty) return;
    try {
      await ViajeLifecycleService.finalizarViaje(
          pedidoId: pedidoId, capitanId: capitanId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('🏁 Viaje finalizado. Calificá al pescador.'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating));
        _cargarViajes();
        _calificarPescador(viaje);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Error al finalizar: $e'),
            backgroundColor: Colors.redAccent));
      }
    }
  }

  void _calificarPescador(Map<String, dynamic> viaje) {
    final pedidoId = viaje['id']?.toString() ?? '';
    final capitanId = SupabaseService.currentUserId ?? '';
    final pescadorId = viaje['pescador_id']?.toString() ?? '';
    final nombre = (viaje['profiles']?['nombre'])?.toString() ?? 'Pescador';
    if (pedidoId.isEmpty || pescadorId.isEmpty) return;
    CalificacionPescadorDialog.mostrar(
      context: context,
      pedidoId: pedidoId,
      capitanId: capitanId,
      pescadorId: pescadorId,
      pescadorNombre: nombre,
      codigoViaje: _codigoViaje(pedidoId),
      onCalificacionGuardada: _cargarViajes,
    );
  }

  Widget _accionBoton(
      String label, IconData icon, Color color, VoidCallback onTap) {
    return SafeElevatedButton(
      onPressed: onTap,
      icon: icon,
      label: label,
      iconColor: Colors.black87,
      textStyle: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
        fontSize: 13,
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        minimumSize: const Size(double.infinity, 46),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
    );
  }

  Widget _buildAccionesCapitan(Map<String, dynamic> viaje, String estado) {
    Widget? boton;
    bool mostrarLeyendaGps = false;
    if (estado == 'pagado' || estado == 'confirmado') {
      mostrarLeyendaGps = true;
      boton = _accionBoton('INICIAR VIAJE', Icons.play_arrow_rounded,
          const Color(0xFF00E676), () => _iniciarViajeCapitan(viaje));
    } else if (estado == 'en_curso' || estado == 'en_viaje') {
      boton = _accionBoton('FINALIZAR VIAJE', Icons.flag_rounded,
          Colors.orangeAccent, () => _finalizarViajeCapitan(viaje));
    } else if (estado == 'listo_para_confirmar' || estado == 'finalizado') {
      final yaCalifico = viaje['capitan_califico'] == true;
      if (!yaCalifico) {
        boton = _accionBoton('CALIFICAR PESCADOR', Icons.star_rate_rounded,
            const Color(0xFF00E676), () => _calificarPescador(viaje));
      }
    }
    if (boton == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          boton,
          if (mostrarLeyendaGps) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gps_fixed_rounded,
                    color: Colors.amberAccent, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Activá tu GPS antes de zarpar: es necesario para validar y cobrar tus viajes.',
                    style: TextStyle(
                      color: Colors.amberAccent.withOpacity(0.9),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _irAConfirmarFinalizacion() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => const ConfirmarFinalizacionScreen()),
    ).then((_) => _cargarViajes());
  }

  /// Acciones del PESCADOR cuando el viaje fue finalizado por el capitán
  /// (o ya pasó la fecha): calificar al capitán + reportar problema.
  /// Enruta al reporte completo (alimenta Blog de Piques + IA).
  Widget _buildAccionesPescador(
      Map<String, dynamic> viaje, String estado, bool hasPassed) {
    final listoParaCalificar = estado == 'listo_para_confirmar' ||
        estado == 'finalizado' ||
        hasPassed;
    final yaCalifico = viaje['pescador_califico'] == true;
    if (!listoParaCalificar || yaCalifico) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          _accionBoton('CALIFICAR CAPITÁN', Icons.star_rate_rounded,
              const Color(0xFF00E676), _irAConfirmarFinalizacion),
          const SizedBox(height: 8),
          SafeOutlinedButton(
            onPressed: _irAConfirmarFinalizacion,
            icon: Icons.warning_amber_rounded,
            label: 'Reportar un problema',
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.orangeAccent),
              foregroundColor: Colors.orangeAccent,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
          ),
        ],
      ),
    );
  }

  String _getCuentaRegresiva(String fechaIso) {
    final fecha = DateTime.parse(fechaIso);
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora);

    if (diferencia.isNegative) return "EN CURSO / FINALIZADO";

    final dias = diferencia.inDays;
    final horas = diferencia.inHours % 24;
    final minutos = diferencia.inMinutes % 60;
    final segundos = diferencia.inSeconds % 60;

    return "${dias}d ${horas}h ${minutos}m ${segundos}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: Text(
          widget.esCapitan ? 'MIS SERVICIOS' : 'MIS VIAJES',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FailsafeBackground(
        opacity: 0.8,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676)),
              )
            : _viajes.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _viajes.length,
                itemBuilder: (context, index) =>
                    _buildViajeCard(_viajes[index]),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.anchor_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay viajes programados aún.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> viaje) {
    final bool pagado =
        ViajeLifecycleService.esEstadoPagado(viaje['estado']?.toString());
    final bool pendientePago =
        !pagado && ViajeLifecycleService.requierePago(viaje['estado']?.toString());
    final String estado = viaje['estado']?.toString().toLowerCase() ?? '';
    final bool yaAbonado = pagado ||
        const ['en_curso', 'en_viaje', 'listo_para_confirmar', 'finalizado', 'cerrado']
            .contains(estado);
    final String countdown = _getCuentaRegresiva(viaje['fecha_servicio']);
    final Map<String, dynamic> contraparte = (widget.esCapitan
        ? viaje['profiles']
        : viaje['capitan']) ?? {};
    final String contraparteId = widget.esCapitan
        ? viaje['pescador_id']?.toString() ?? ''
        : viaje['capitan_id']?.toString() ?? '';

    final String fechaServicioStr = viaje['fecha_servicio']?.toString() ?? '';
    bool hasPassed = false;
    if (fechaServicioStr.isNotEmpty) {
      try {
        final DateTime dateServicio = DateTime.parse(fechaServicioStr);
        final DateTime endOfServiceDay = DateTime(dateServicio.year, dateServicio.month, dateServicio.day).add(const Duration(days: 1));
        hasPassed = DateTime.now().isAfter(endOfServiceDay);
      } catch (e) {
        print('Error al parsear fecha de servicio: $e');
      }
    }

    return GestureDetector(
      onTap: () {
        // Al tocar la tarjeta, abrimos el desglose de manifiesto de pasajeros y mercadería
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF001F3F),
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => _ViajeDetallesSheetContent(
              viajeId: viaje['id']?.toString() ?? '',
              scrollController: scrollController,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: yaAbonado
                ? const Color(0xFF00E676).withOpacity(0.3)
                : Colors.white10,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header: Cuenta Regresiva
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                color: yaAbonado
                    ? const Color(0xFF00E676).withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ZARPE EN:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      countdown,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white10,
                          backgroundImage: contraparte['avatar_url'] != null
                              ? NetworkImage(contraparte['avatar_url'])
                              : null,
                          child: contraparte['avatar_url'] == null
                              ? const Icon(Icons.person, color: Colors.white54)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contraparte['nombre'] ?? 'Usuario',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.esCapitan
                                    ? 'Pescador (Tocar para ver manifiesto)'
                                    : 'Capitán Responsable',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                              if (contraparteId.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                ReputacionBadgeWidget(
                                  userId: contraparteId,
                                  tipo: widget.esCapitan
                                      ? ReputacionTipo.pescador
                                      : ReputacionTipo.capitan,
                                  compact: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${viaje['monto_total']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              yaAbonado ? 'PAGADO' : 'PENDIENTE',
                              style: TextStyle(
                                color: yaAbonado
                                    ? const Color(0xFF00E676)
                                    : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(color: Colors.white10),
                    ),

                    // SECCIÓN SEGURA: Datos de contacto
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: yaAbonado
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.phone,
                                  color: Color(0xFF00E676),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  contraparte['telefono'] ?? 'Sin teléfono',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                if (yaAbonado && !widget.esCapitan)
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FichaContractualScreen(
                                            pedidoId: viaje['id']?.toString() ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.description_outlined,
                                      color: Color(0xFF00E676),
                                    ),
                                    tooltip: 'Ficha contractual',
                                  ),
                                if (yaAbonado)
                                  IconButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => FichaPescadorScreen(
                                            pedidoId: viaje['id']?.toString() ?? '',
                                          ),
                                        ),
                                      );
                                    },
                                    icon: Icon(
                                      Icons.assignment_ind_outlined,
                                      color: widget.esCapitan
                                          ? Colors.amberAccent
                                          : const Color(0xFF00E676),
                                    ),
                                    tooltip: 'Planilla del pescador',
                                  ),
                                IconButton(
                                  onPressed: () {
                                    if (hasPassed) {
                                      showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: const Color(0xFF001F3F),
                                          title: const Text(
                                            'Viaje Finalizado',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          content: const Text(
                                            'Este viaje ya ha finalizado y la comunicación activa por chat está cerrada. ¿Deseas ver el historial o calificar tu experiencia?',
                                            style: TextStyle(color: Colors.white70),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context),
                                              child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                                            ),
                                            TextButton(
                                              onPressed: () {
                                                Navigator.pop(context); // Cerrar diálogo
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => ChatScreen(
                                                      reservaId: viaje['id']?.toString() ?? '',
                                                      nombreServicio: viaje['presupuestos'] != null 
                                                          ? viaje['presupuestos']['titulo'] ?? 'Viaje de Pesca'
                                                          : 'Viaje de Pesca',
                                                      nombreCliente: contraparte['nombre'] ?? 'Usuario',
                                                    ),
                                                  ),
                                                );
                                              },
                                              child: const Text('Ver Chat', style: TextStyle(color: Color(0xFF00E676))),
                                            ),
                                            if (!widget.esCapitan)
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context); // Cerrar diálogo
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => const ConfirmarFinalizacionScreen(),
                                                    ),
                                                  ).then((_) => _cargarViajes());
                                                },
                                                child: const Text('Calificar', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
                                              ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            reservaId: viaje['id']?.toString() ?? '',
                                            nombreServicio: viaje['presupuestos'] != null 
                                                ? viaje['presupuestos']['titulo'] ?? 'Viaje de Pesca'
                                                : 'Viaje de Pesca',
                                            nombreCliente: contraparte['nombre'] ?? 'Usuario',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.message,
                                    color: Color(0xFF00E676),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Contacto oculto hasta confirmar el pago',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: pendientePago
                                      ? () => _abrirCheckoutPago(viaje)
                                      : null,
                                  child: const Text(
                                    'PAGAR',
                                    style: TextStyle(
                                      color: Color(0xFF00E676),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                    ),
                    if (widget.esCapitan) _buildAccionesCapitan(viaje, estado),
                    if (!widget.esCapitan)
                      _buildAccionesPescador(viaje, estado, hasPassed),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── HOJA DE DETALLES PREMIUM (MANIFIESTO + MERCADERÍA) ───────────────────────
class _ViajeDetallesSheetContent extends StatefulWidget {
  final String viajeId;
  final ScrollController scrollController;

  const _ViajeDetallesSheetContent({
    required this.viajeId,
    required this.scrollController,
  });

  @override
  State<_ViajeDetallesSheetContent> createState() => _ViajeDetallesSheetContentState();
}

class _ViajeDetallesSheetContentState extends State<_ViajeDetallesSheetContent> {
  bool _loading = true;
  List<Map<String, dynamic>> _pasajeros = [];
  List<Map<String, dynamic>> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final supabase = SupabaseService.supabase;

      // 1. Cargar manifiesto de pasajeros
      final resPasajeros = await supabase
          .from('viajes_invitados')
          .select()
          .eq('pedido_id', widget.viajeId)
          .order('es_titular', ascending: false);

      // 2. Cargar items del pedido
      final resItems = await supabase
          .from('pedido_items')
          .select('*, productos(*)')
          .eq('pedido_id', widget.viajeId);

      if (mounted) {
        setState(() {
          _pasajeros = List<Map<String, dynamic>>.from(resPasajeros);
          _items = List<Map<String, dynamic>>.from(resItems);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _verFotoDNI(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF001F3F),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Foto DNI Pasajero', style: TextStyle(fontSize: 14)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No se pudo cargar la imagen del DNI',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Indicador de arrastre
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_ind, color: Color(0xFF00E676), size: 24),
              SizedBox(width: 10),
              Text(
                'MANIFIESTO Y CARGA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reserva ID: ${widget.viajeId.toUpperCase().substring(0, 12)}...',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : _error != null
                    ? Center(
                        child: Text(
                          'Error al obtener detalles: $_error',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : ListView(
                        controller: widget.scrollController,
                        children: [
                          // ─── SECCIÓN 1: PASAJEROS ──────────────────────────────
                          _buildSeccionHeader('MANIFIESTO DE PASAJEROS (DDJJ)', Icons.people),
                          const SizedBox(height: 10),
                          if (_pasajeros.isEmpty)
                            _buildEmptyState('Aún no se han declarado pasajeros.')
                          else
                            ..._pasajeros.map((p) {
                              final bool esTitular = p['es_titular'] == true;
                              final String? fotoUrl = p['foto_dni_url'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: esTitular
                                        ? const Color(0xFF00E676).withOpacity(0.4)
                                        : Colors.white10,
                                    width: esTitular ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: esTitular
                                          ? const Color(0xFF00E676).withOpacity(0.2)
                                          : Colors.white10,
                                      child: Icon(
                                        esTitular ? Icons.star : Icons.person_outline,
                                        color: esTitular ? const Color(0xFF00E676) : Colors.white60,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'DNI: ${p['dni'] ?? 'Sin DNI'}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                          if (p['fecha_nacimiento'] != null)
                                            Text(
                                              'Nac.: ${FechaNacimientoUtils.formatearLegible(p['fecha_nacimiento'])}',
                                              style: const TextStyle(
                                                color: Colors.white38,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (fotoUrl != null && fotoUrl.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.badge, color: Color(0xFF00E676)),
                                        tooltip: 'Ver foto DNI',
                                        onPressed: () => _verFotoDNI(fotoUrl),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),

                          const SizedBox(height: 16),
                          DescargarDespachoPnaButton(
                            pedidoId: widget.viajeId,
                            compact: true,
                          ),

                          const SizedBox(height: 24),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 10),

                          // ─── SECCIÓN 2: MERCADERÍA ─────────────────────────────
                          _buildSeccionHeader('MERCADERÍA A PREPARAR A BORDO', Icons.shopping_bag_outlined),
                          const SizedBox(height: 6),
                          const Text(
                            '⚠️ Preparar en la lancha antes de salir de Glew',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_items.isEmpty)
                            _buildEmptyState('Solo servicio de lancha (sin mercadería extra).')
                          else
                            ..._items.map((item) {
                              final prod = item['productos'] ?? {};
                              final String nombreProd = prod['nombre'] ?? 'Producto';
                              final String imgUrl = prod['imagen_url'] ?? '';
                              final int cant = (item['cantidad'] as num?)?.toInt() ?? 1;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: imgUrl.isNotEmpty
                                          ? Image.network(
                                              imgUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.image_not_supported_outlined,
                                                  color: Colors.white24),
                                            )
                                          : const Icon(Icons.shopping_bag, color: Colors.white24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nombreProd,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cant: $cant x \$${item['precio_unitario'] ?? '0'}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'x$cant',
                                        style: const TextStyle(
                                          color: Color(0xFF00E676),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 40),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
