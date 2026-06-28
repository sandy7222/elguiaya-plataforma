import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cotizacion.dart';
import '../services/supabase_service.dart';
import '../widgets/reputacion_badge_widget.dart';
import '../utils/presupuesto_pescador_actions.dart';
import '../utils/view_insets.dart';
import '../widgets/safe_button.dart';
import '../widgets/el_guia_ya_home_button.dart';
import 'resumen_reserva_screen.dart';
import 'ticket_embarque_screen.dart';
import 'ficha_contractual_screen.dart';
import 'ficha_pescador_screen.dart';
import 'viajes_programados_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// MIS VIAJES SCREEN — Con datos reales de Supabase
// Organizada por secciones de estado.
// ══════════════════════════════════════════════════════════════════════════════

// ─── Paleta ──────────────────────────────────────────────────────────────────
class _C {
  static const bg         = Color(0xFF001220);
  static const surface    = Color(0xFF0A1F35);
  static const card       = Color(0xFF0D2847);
  static const cardBorder = Color(0xFF1A3A5C);
  static const azul       = Color(0xFF1565C0);
  static const azulBrillo = Color(0xFF1E88E5);
  static const verde      = Color(0xFF00C853);
  static const verdeOsc   = Color(0xFF00875A);
  static const naranja    = Color(0xFFF59E0B);
  static const rojo       = Color(0xFFEF4444);
  static const grisTexto  = Color(0xFF8BA4BC);
  static const blanco     = Colors.white;
}

// ══════════════════════════════════════════════════════════════════════════════
// WIDGET PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════════
class MisViajesScreen extends StatefulWidget {
  final VoidCallback? onNuevaSolicitud;
  const MisViajesScreen({super.key, this.onNuevaSolicitud});

  @override
  State<MisViajesScreen> createState() => _MisViajesScreenState();
}

class _MisViajesScreenState extends State<MisViajesScreen> {
  bool _isLoading = true;
  bool _historialExpandido = false;

  // Datos reales de Supabase
  List<Cotizacion> _cotizaciones = [];           // solicitudes del pescador
  List<Map<String, dynamic>> _presupuestos = []; // ofertas de capitanes
  List<Map<String, dynamic>> _pedidosActivos = [];
  List<Map<String, dynamic>> _pedidosHistorial = [];

  // IDs de cotizaciones canceladas localmente en esta sesión
  final Set<String> _cotizacionesCanceladasIds = {};

  RealtimeChannel? _presupuestosChannel;

  String? _pescadorId;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _presupuestosChannel?.unsubscribe();
    super.dispose();
  }

  void _suscribirPresupuestos(String pescadorId) {
    _presupuestosChannel?.unsubscribe();
    _presupuestosChannel = Supabase.instance.client
        .channel('mis_viajes_presupuestos_$pescadorId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'presupuestos',
          callback: (_) {
            if (mounted) _cargarDatos();
          },
        )
        .subscribe();
  }

  // ─── Carga de datos ───────────────────────────────────────────────────────
  Future<void> _cargarDatos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      _pescadorId = user.id;

      // Cargar cotizaciones del pescador (solicitudes de viaje)
      final cotizaciones = await SupabaseService.getCotizacionesPescador(_pescadorId!);

      // Cargar presupuestos recibidos (ofertas de capitanes)
      final presupuestos = await SupabaseService.getPresupuestosPescador(_pescadorId!);

      final todosPedidos = await _cargarPedidosPescador();

      const estadosActivos = {
        'programado',
        'pagado',
        'confirmado',
        'pago_pendiente',
        'pendiente_pago',
        'en_curso',
        'en_viaje',
        'listo_para_confirmar',
      };
      const estadosHistorial = {'cerrado', 'finalizado', 'cancelado'};

      final pedidosActivos = todosPedidos
          .where((p) => estadosActivos.contains(p['estado']?.toString()))
          .toList();
      final pedidosHist = todosPedidos
          .where((p) => estadosHistorial.contains(p['estado']?.toString()))
          .toList();

      if (mounted) {
        setState(() {
          _cotizaciones = cotizaciones;
          _presupuestos = presupuestos
              .where((p) => p['estado']?.toString() != 'descartado')
              .toList();
          _pedidosActivos = pedidosActivos;
          _pedidosHistorial = pedidosHist;
          if (pedidosHist.isNotEmpty) _historialExpandido = true;
          _isLoading = false;
        });
        _suscribirPresupuestos(_pescadorId!);
      }
    } catch (e) {
      debugPrint('❌ MisViajesScreen._cargarDatos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _cargarPedidosPescador() async {
    try {
      // Sin join embebido: evita fallos silenciosos si falta la FK cotizacion_id.
      final response = await Supabase.instance.client
          .from('pedidos')
          .select('*')
          .eq('pescador_id', _pescadorId!)
          .order('created_at', ascending: false);

      final pedidos = List<Map<String, dynamic>>.from(response);

      for (final pedido in pedidos) {
        final cotId = pedido['cotizacion_id']?.toString();
        if (cotId != null && cotId.isNotEmpty) {
          try {
            final cot = await Supabase.instance.client
                .from('cotizaciones')
                .select(
                    'descripcion, coordenadas_partida, coordenadas_destino, fecha_ida, cantidad_personas, localidad_partida')
                .eq('id', cotId)
                .maybeSingle();
            if (cot != null) pedido['cotizaciones'] = cot;
          } catch (_) {}
        }

        final capitanId = pedido['capitan_id']?.toString();
        if (capitanId != null && capitanId.isNotEmpty) {
          try {
            final capitan = await Supabase.instance.client
                .from('profiles')
                .select('nombre, avatar_url, telefono')
                .eq('user_id', capitanId)
                .maybeSingle();
            if (capitan != null) pedido['capitan_profile'] = capitan;
          } catch (_) {}
        }
      }

      return pedidos;
    } catch (e) {
      debugPrint('⚠️ Error cargando pedidos del pescador: $e');
      return [];
    }
  }

  // ─── Lógica de filtrado ───────────────────────────────────────────────────
  /// Cotizaciones sin presupuestos aún (esperando oferta de capitán)
  List<Cotizacion> get _esperando {
    final conPresupuesto = _presupuestos
        .map((p) => p['cotizacion_id']?.toString() ?? '')
        .toSet();
    return _cotizaciones
        .where((c) =>
            !conPresupuesto.contains(c.id) &&
            !_cotizacionesCanceladasIds.contains(c.id) &&
            c.estado != Cotizacion.ESTADO_ACEPTADO &&
            c.estado != Cotizacion.ESTADO_FINALIZADO)
        .toList();
  }

  /// Presupuestos pendientes (ya filtrados en Supabase y al cargar).
  List<Map<String, dynamic>> get _presupuestosFiltrados => _presupuestos;

  List<Map<String, dynamic>> get _pedidosProximos => _pedidosActivos;

  List<Map<String, dynamic>> get _historialCombinado => _pedidosHistorial;

  // ─── Acciones ─────────────────────────────────────────────────────────────
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

  // ─── Cancelar cotización esperando ────────────────────────────────────────
  Future<void> _cancelarCotizacion(Cotizacion cotizacion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => AlertDialog(
        backgroundColor: _C.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('¿Cancelar solicitud?',
            style: GoogleFonts.inter(
                color: _C.blanco, fontWeight: FontWeight.w700)),
        content: Text(
          'Se cancelará "${cotizacion.descripcionCorta}". Si ya hay capitanes mirándola, dejarán de verla.',
          style: GoogleFonts.inter(color: _C.grisTexto, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Mantener', style: GoogleFonts.inter(color: _C.grisTexto)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _C.rojo, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Sí, cancelar', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;

    // Ocultar inmediatamente en la UI
    setState(() => _cotizacionesCanceladasIds.add(cotizacion.id));

    // Actualizar estado en Supabase
    try {
      await Supabase.instance.client
          .from('cotizaciones')
          .update({'estado': 'cancelada'})
          .eq('id', cotizacion.id);
    } catch (e) {
      debugPrint('⚠️ Error cancelando cotización ${cotizacion.id}: $e');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🗑️ Solicitud cancelada'),
          backgroundColor: _C.surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(12),
        ),
      );
    }
  }

  void _verDetallesYReservar(Map<String, dynamic> presupuesto) {
    final cotizacionId = presupuesto['cotizacion_id']?.toString() ?? '';
    if (cotizacionId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ No se pudo obtener el ID de la solicitud'),
          backgroundColor: _C.rojo,
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResumenReservaScreen(cotizacionId: cotizacionId),
      ),
    ).then((_) => _cargarDatos());
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _C.bg,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _cargarDatos,
        color: _C.verde,
        backgroundColor: _C.surface,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _C.verde))
            : ListView(
                padding: ViewInsets.scrollPadding(
                  context,
                  hasPortalBottomNav: false,
                ),
                children: [
                  _buildNuevaSolicitudBanner(),
                  const SizedBox(height: 20),
                  _buildSeccionEsperando(),
                  const SizedBox(height: 16),
                  _buildSeccionPresupuestos(),
                  const SizedBox(height: 16),
                  _buildSeccionConfirmados(),
                  const SizedBox(height: 16),
                  _buildSeccionHistorial(),
                ],
              ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: _C.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      title: Row(
        children: [
          ElGuiaYaHomeButton(
            height: 30,
            onTap: () => Navigator.pop(context, 'panel'),
          ),
          const SizedBox(width: 12),
          const Icon(Icons.folder_open_rounded, color: _C.verde, size: 22),
          const SizedBox(width: 10),
          Text('Mis Viajes',
              style: GoogleFonts.inter(
                  color: _C.blanco, fontWeight: FontWeight.w700, fontSize: 18)),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: _C.grisTexto),
          tooltip: 'Recargar',
          onPressed: _cargarDatos,
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _C.cardBorder),
      ),
    );
  }

  // ─── Banner CTA ───────────────────────────────────────────────────────────
  Widget _buildNuevaSolicitudBanner() {
    return GestureDetector(
      onTap: widget.onNuevaSolicitud,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0A3D62), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.azulBrillo.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
                color: _C.azul.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.add_circle_outline_rounded,
                  color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nueva Solicitud de Viaje',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                  Text('Publicá tu salida y recibí cotizaciones de capitanes',
                      style: GoogleFonts.inter(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white54, size: 16),
          ],
        ),
      ),
    );
  }

  // ─── Header de sección ────────────────────────────────────────────────────
  Widget _buildSectionHeader(
      String emoji, String titulo, int badge, Color badgeColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Text(titulo,
              style: GoogleFonts.inter(
                  color: _C.blanco,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2)),
          const SizedBox(width: 8),
          if (badge > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('$badge',
                  style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 11)),
            ),
        ],
      ),
    );
  }

  // ─── Sección: Esperando presupuestos ─────────────────────────────────────
  Widget _buildSeccionEsperando() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            '⏳', 'Esperando presupuestos', _esperando.length, _C.naranja),
        if (_esperando.isEmpty)
          _EmptySection(
            mensaje: 'No tenés solicitudes esperando respuesta.',
            icono: Icons.hourglass_empty_rounded,
            onNuevaSolicitud: widget.onNuevaSolicitud,
          )
        else
          ..._esperando.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EsperandoCard(
                  cotizacion: c,
                  onCancelar: () => _cancelarCotizacion(c),
                ),
              )),
      ],
    );
  }

  // ─── Sección: Presupuestos recibidos ──────────────────────────────────────
  Widget _buildSeccionPresupuestos() {
    final visibles = _presupuestosFiltrados;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            '💰', 'Presupuestos recibidos', visibles.length, _C.azulBrillo),
        if (visibles.isEmpty)
          _EmptySection(
            mensaje: 'Ningún capitán cotizó tus viajes aún.',
            icono: Icons.inbox_rounded,
            onNuevaSolicitud: widget.onNuevaSolicitud,
          )
        else
          ...visibles.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _PresupuestoCard(
                  presupuesto: p,
                  onDescartar: () => _descartarPresupuesto(p),
                  onReservar: () => _verDetallesYReservar(p),
                ),
              )),
      ],
    );
  }

  // ─── Sección: Próximos (solo viajes futuros confirmados) ─────────────────
  Widget _buildSeccionConfirmados() {
    final proximos = _pedidosProximos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
            '📅', 'Próximos viajes', proximos.length, _C.verde),
        if (proximos.isEmpty)
          _EmptySection(
            mensaje: 'No tenés viajes confirmados próximos.',
            icono: Icons.event_available_rounded,
            onNuevaSolicitud: widget.onNuevaSolicitud,
          )
        else
          ...proximos.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ConfirmadoCard(pedido: p),
              )),
      ],
    );
  }

  // ─── Sección: Historial (colapsable) ─────────────────────────────────────
  Widget _buildSeccionHistorial() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () =>
              setState(() => _historialExpandido = !_historialExpandido),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _C.cardBorder),
            ),
            child: Row(
              children: [
                const Text('🏁', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Historial',
                      style: GoogleFonts.inter(
                          color: _C.blanco,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
                if (_historialCombinado.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                        color: _C.grisTexto.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text('${_historialCombinado.length}',
                        style: GoogleFonts.inter(
                            color: _C.grisTexto,
                            fontWeight: FontWeight.w700,
                            fontSize: 11)),
                  ),
                const SizedBox(width: 8),
                Icon(
                  _historialExpandido
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: _C.grisTexto,
                ),
              ],
            ),
          ),
        ),
        if (_historialExpandido) ...[
          const SizedBox(height: 10),
          if (_historialCombinado.isEmpty)
            const _EmptySection(
              mensaje: 'No tenés viajes en el historial aún.',
              icono: Icons.history_rounded,
            )
          else
            ..._historialCombinado.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _HistorialCard(pedido: p),
                )),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// CARDS — con datos reales
// ══════════════════════════════════════════════════════════════════════════════

// ─── Esperando presupuesto ────────────────────────────────────────────────────
class _EsperandoCard extends StatelessWidget {
  final Cotizacion cotizacion;
  final VoidCallback? onCancelar;
  const _EsperandoCard({required this.cotizacion, this.onCancelar});

  @override
  Widget build(BuildContext context) {
    final origen = cotizacion.nombrePartida;
    final destino = cotizacion.nombreDestino;
    final fecha = cotizacion.fechaIda;
    final personas = cotizacion.cantidadPersonas ?? 1;

    return _BaseCard(
      leftAccent: _C.naranja,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cotizacion.descripcion.isNotEmpty
                      ? cotizacion.descripcionCorta
                      : 'Solicitud de viaje',
                  style: GoogleFonts.inter(
                      color: _C.blanco,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              const _StatusBadge(
                  label: 'Sin cotizaciones',
                  color: _C.naranja,
                  icon: Icons.hourglass_top_rounded),
              // 🗑️ Botón para cancelar esta solicitud
              if (onCancelar != null)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: GestureDetector(
                    onTap: onCancelar,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _C.rojo.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _C.rojo.withOpacity(0.25)),
                      ),
                      child: const Icon(Icons.delete_outline_rounded,
                          color: _C.rojo, size: 16),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _RouteRow(origen: origen, destino: destino),
          const SizedBox(height: 6),
          _MetaRow(
            fecha: fecha ?? cotizacion.createdAt,
            personas: personas,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _C.naranja,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: _C.naranja.withOpacity(0.5), blurRadius: 6)
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('Buscando capitanes disponibles...',
                  style: GoogleFonts.inter(
                      color: _C.naranja,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Presupuesto recibido ─────────────────────────────────────────────────────
class _PresupuestoCard extends StatelessWidget {
  final Map<String, dynamic> presupuesto;
  final VoidCallback onDescartar;
  final VoidCallback onReservar;

  const _PresupuestoCard({
    required this.presupuesto,
    required this.onDescartar,
    required this.onReservar,
  });

  @override
  Widget build(BuildContext context) {
    final capitanNombre = presupuesto['profiles']?['nombre']?.toString() ??
        presupuesto['capitan_nombre']?.toString() ??
        'Capitán';
    final monto = (presupuesto['monto_total'] as num?)?.toDouble() ?? 0.0;
    final barcoNombre = presupuesto['barco_nombre']?.toString() ??
        presupuesto['embarcacion_nombre']?.toString() ??
        'Embarcación Principal';
    final capitanId = presupuesto['capitan_id']?.toString() ?? '';
    final viajesRealizados = (presupuesto['viajes_realizados'] as num?)?.toInt() ?? 0;
    final bioTexto = presupuesto['bio_pescador']?.toString() ?? '';
    final descripcionServicio = presupuesto['descripcion']?.toString() ??
        presupuesto['bio_pescador']?.toString() ??
        'Servicio de guía profesional';
    final montoFmt = NumberFormat.currency(
            locale: 'es_AR', symbol: '\$', decimalDigits: 0)
        .format(monto);

    return _BaseCard(
      leftAccent: _C.azulBrillo,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Capitán row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: _C.azul,
                backgroundImage: presupuesto['profiles']?['avatar_url'] != null
                    ? NetworkImage(presupuesto['profiles']['avatar_url'])
                    : null,
                child: presupuesto['profiles']?['avatar_url'] == null
                    ? Text(
                        capitanNombre.isNotEmpty
                            ? capitanNombre[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            capitanNombre,
                            style: GoogleFonts.inter(
                                color: _C.blanco,
                                fontWeight: FontWeight.w700,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _C.verde.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                            border:
                                Border.all(color: _C.verde.withOpacity(0.4)),
                          ),
                          child: Text('✓ VERIFICADO',
                              style: GoogleFonts.inter(
                                  color: _C.verde,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    if (capitanId.isNotEmpty)
                      ReputacionBadgeWidget(userId: capitanId, compact: true)
                    else
                      Text('Sin calificaciones aún',
                          style: GoogleFonts.inter(
                              color: _C.grisTexto, fontSize: 11)),
                    if (viajesRealizados > 0) ...[
                      const SizedBox(height: 2),
                      Text('$viajesRealizados viajes',
                          style: GoogleFonts.inter(
                              color: _C.grisTexto, fontSize: 11)),
                    ],
                    if (barcoNombre.isNotEmpty)
                      Text('⛵ $barcoNombre',
                          style: GoogleFonts.inter(
                              color: _C.grisTexto, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(montoFmt,
                      style: GoogleFonts.inter(
                          color: _C.verde,
                          fontWeight: FontWeight.w900,
                          fontSize: 20)),
                  Text('total',
                      style: GoogleFonts.inter(
                          color: _C.grisTexto, fontSize: 10)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Descripción del servicio
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _C.cardBorder),
            ),
            child: Text(
              descripcionServicio.isNotEmpty
                  ? descripcionServicio
                  : 'Servicio de guía profesional (Contacto privado hasta el pago)',
              style: GoogleFonts.inter(
                  color: _C.grisTexto, fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          // Botones
          Row(
            children: [
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  onPressed: onDescartar,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    side: BorderSide(color: _C.rojo.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: SafeButtonContent(
                    icon: Icons.delete_outline_rounded,
                    label: 'Descartar',
                    iconSize: 16,
                    iconColor: _C.rojo,
                    textStyle: GoogleFonts.inter(
                        color: _C.rojo,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: onReservar,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    backgroundColor: _C.verdeOsc,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: SafeButtonContent(
                    icon: Icons.anchor_rounded,
                    label: 'Ver y reservar',
                    iconSize: 16,
                    iconColor: Colors.white,
                    textStyle: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Confirmado ───────────────────────────────────────────────────────────────
class _ConfirmadoCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _ConfirmadoCard({required this.pedido});

  String _etiquetaEstado(String estado) {
    switch (estado) {
      case 'pagado':
        return '✅ Pagado';
      case 'programado':
        return '📋 Programado';
      case 'en_curso':
      case 'en_viaje':
        return '🚢 En curso';
      case 'listo_para_confirmar':
        return '⭐ Calificar';
      case 'pago_pendiente':
      case 'pendiente_pago':
        return '💳 Pendiente de pago';
      default:
        return '✅ Confirmado';
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'en_curso':
      case 'en_viaje':
        return _C.azulBrillo;
      case 'listo_para_confirmar':
        return _C.naranja;
      case 'pago_pendiente':
      case 'pendiente_pago':
        return _C.naranja;
      default:
        return _C.verde;
    }
  }

  @override
  Widget build(BuildContext context) {
    final monto = (pedido['monto_total'] as num?)?.toDouble() ?? 0.0;
    final montoFmt = NumberFormat.currency(
            locale: 'es_AR', symbol: '\$', decimalDigits: 0)
        .format(monto);

    final cot = pedido['cotizaciones'] as Map<String, dynamic>?;
    final descripcion = cot?['descripcion']?.toString() ??
        pedido['descripcion']?.toString() ??
        'Viaje confirmado';

    DateTime? fechaViaje;
    final fechaStr = cot?['fecha_ida']?.toString() ??
        pedido['fecha_servicio']?.toString() ??
        pedido['fecha_viaje']?.toString();
    if (fechaStr != null) fechaViaje = DateTime.tryParse(fechaStr);
    fechaViaje ??=
        DateTime.tryParse(pedido['created_at']?.toString() ?? '') ??
            DateTime.now();

    final diasRestantes = fechaViaje.difference(DateTime.now()).inDays;
    final capitanId = pedido['capitan_id']?.toString() ?? '';
    final capitanProfile =
        pedido['capitan_profile'] as Map<String, dynamic>?;
    final capitanNombre =
        capitanProfile?['nombre']?.toString() ?? 'Capitán asignado';
    final pedidoId = pedido['id']?.toString() ?? '';
    final esHoy = diasRestantes == 0;
    final estado = pedido['estado']?.toString() ?? 'confirmado';

    return _BaseCard(
      leftAccent: _colorEstado(estado),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  descripcion.length > 50
                      ? '${descripcion.substring(0, 47)}...'
                      : descripcion,
                  style: GoogleFonts.inter(
                      color: _C.blanco,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
              _StatusBadge(
                  label: _etiquetaEstado(estado),
                  color: _colorEstado(estado),
                  icon: Icons.check_circle_rounded),
            ],
          ),
          if (capitanId.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: _C.azul,
                  backgroundImage: capitanProfile?['avatar_url'] != null
                      ? NetworkImage(capitanProfile!['avatar_url'])
                      : null,
                  child: capitanProfile?['avatar_url'] == null
                      ? Text(
                          capitanNombre.isNotEmpty
                              ? capitanNombre[0].toUpperCase()
                              : '?',
                          style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.w800))
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(capitanNombre,
                          style: GoogleFonts.inter(
                              color: _C.blanco,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                      ReputacionBadgeWidget(userId: capitanId, compact: true),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          if (cot != null)
            _RouteRow(
              origen: (cot['coordenadas_partida'] as Map?)?['nombre']?.toString() ??
                  cot['localidad_partida']?.toString() ?? 'Origen',
              destino: (cot['coordenadas_destino'] as Map?)?['nombre']?.toString() ?? 'Destino',
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              _InfoChip(label: montoFmt, color: _C.verde),
              const SizedBox(width: 8),
              if (capitanId.isNotEmpty)
                _InfoChip(label: '⚓ Capitán asignado', color: _C.azulBrillo),
              const Spacer(),
              if (diasRestantes >= 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: esHoy
                        ? _C.rojo.withOpacity(0.15)
                        : diasRestantes <= 1
                            ? _C.naranja.withOpacity(0.15)
                            : _C.verde.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: esHoy
                          ? _C.rojo.withOpacity(0.5)
                          : diasRestantes <= 1
                              ? _C.naranja.withOpacity(0.5)
                              : _C.verde.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    esHoy ? '🚨 ¡HOY!' : 'en $diasRestantes días',
                    style: GoogleFonts.inter(
                      color: esHoy ? _C.rojo : diasRestantes <= 1 ? _C.naranja : _C.verde,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          // ─── Botones de acción ────────────────────────────────────────
          if (pedidoId.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const ViajesProgramadosScreen(esCapitan: false),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  foregroundColor: _C.azulBrillo,
                  side: BorderSide(color: _C.azulBrillo.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: SafeButtonContent(
                  icon: Icons.sailing_rounded,
                  label: estado == 'listo_para_confirmar'
                      ? 'Calificar capitán y cerrar viaje'
                      : estado == 'en_curso' || estado == 'en_viaje'
                          ? 'Ver viaje en curso'
                          : 'Ver detalle del viaje',
                  iconSize: 16,
                  textStyle: GoogleFonts.inter(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  iconColor: _C.azulBrillo,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (const {'pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado'}
                .contains(estado))
              SafeOutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        FichaContractualScreen(pedidoId: pedidoId),
                  ),
                ),
                icon: Icons.description_outlined,
                label: 'Ver ficha contractual',
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  foregroundColor: const Color(0xFF0D2847),
                  side: BorderSide(
                      color: const Color(0xFF0D2847).withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            if (const {'pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado'}
                .contains(estado))
              const SizedBox(height: 8),
            if (const {'pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado'}
                .contains(estado))
              SafeOutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FichaPescadorScreen(pedidoId: pedidoId),
                  ),
                ),
                icon: Icons.assignment_ind_outlined,
                label: 'Ver planilla del pescador',
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  foregroundColor: const Color(0xFF00875A),
                  side: BorderSide(
                      color: const Color(0xFF00875A).withOpacity(0.4)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            if (const {'pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado'}
                .contains(estado))
              const SizedBox(height: 8),
            SafeElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TicketEmbarqueScreen(pedidoId: pedidoId),
                ),
              ),
              icon: Icons.confirmation_number_rounded,
              label: esHoy
                  ? 'Ver ticket — ¡Hoy es el día!'
                  : 'Ver ticket de embarque',
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                backgroundColor: esHoy ? _C.rojo : _C.azulBrillo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              iconColor: Colors.white,
              textStyle: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Historial ────────────────────────────────────────────────────────────────
class _HistorialCard extends StatelessWidget {
  final Map<String, dynamic> pedido;
  const _HistorialCard({required this.pedido});

  @override
  Widget build(BuildContext context) {
    final monto = (pedido['monto_total'] as num?)?.toDouble();
    final montoFmt = monto != null
        ? NumberFormat.currency(
                locale: 'es_AR', symbol: '\$', decimalDigits: 0)
            .format(monto)
        : '—';
    final cot = pedido['cotizaciones'] as Map<String, dynamic>?;
    final descripcion = cot?['descripcion']?.toString() ??
        pedido['descripcion']?.toString() ??
        'Viaje finalizado';
    final fechaStr = pedido['updated_at']?.toString() ??
        pedido['created_at']?.toString() ?? '';
    final fecha = DateTime.tryParse(fechaStr) ?? DateTime.now();
    final estado = pedido['estado']?.toString() ?? 'cerrado';

    return _BaseCard(
      leftAccent: _C.grisTexto,
      opacity: 0.75,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descripcion.length > 50
                      ? '${descripcion.substring(0, 47)}...'
                      : descripcion,
                  style: GoogleFonts.inter(
                      color: _C.blanco.withOpacity(0.8),
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('d MMM yyyy', 'es').format(fecha),
                  style: GoogleFonts.inter(
                      color: _C.grisTexto, fontSize: 12),
                ),
                Text(
                  estado.toUpperCase(),
                  style: GoogleFonts.inter(
                      color: _C.grisTexto,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                ),
              ],
            ),
          ),
          Text(montoFmt,
              style: GoogleFonts.inter(
                  color: _C.grisTexto,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// HELPER WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _BaseCard extends StatelessWidget {
  final Widget child;
  final Color leftAccent;
  final double opacity;
  const _BaseCard(
      {required this.child, required this.leftAccent, this.opacity = 1.0});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.cardBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: leftAccent,
                  borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(14)),
                ),
              ),
              Expanded(
                child: Padding(
                    padding: const EdgeInsets.all(14), child: child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteRow extends StatelessWidget {
  final String origen;
  final String destino;
  const _RouteRow({required this.origen, required this.destino});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.trip_origin, color: _C.verde, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(origen,
              style: GoogleFonts.inter(color: _C.grisTexto, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child:
              Icon(Icons.arrow_forward_rounded, color: _C.grisTexto, size: 12),
        ),
        const Icon(Icons.location_on_rounded, color: _C.rojo, size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(destino,
              style: GoogleFonts.inter(color: _C.grisTexto, fontSize: 12),
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final DateTime fecha;
  final int personas;
  const _MetaRow({required this.fecha, required this.personas});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.calendar_today_rounded,
            color: _C.grisTexto, size: 13),
        const SizedBox(width: 4),
        Text(DateFormat('EEE d MMM', 'es').format(fecha),
            style: GoogleFonts.inter(color: _C.grisTexto, fontSize: 12)),
        const SizedBox(width: 14),
        const Icon(Icons.people_alt_rounded, color: _C.grisTexto, size: 13),
        const SizedBox(width: 4),
        Text('$personas ${personas == 1 ? "persona" : "personas"}',
            style: GoogleFonts.inter(color: _C.grisTexto, fontSize: 12)),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusBadge(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final Color color;
  const _InfoChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final String mensaje;
  final IconData icono;
  final VoidCallback? onNuevaSolicitud;

  const _EmptySection({
    required this.mensaje,
    required this.icono,
    this.onNuevaSolicitud,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, color: _C.grisTexto, size: 36),
          const SizedBox(height: 10),
          Text(mensaje,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _C.grisTexto, fontSize: 13)),
          if (onNuevaSolicitud != null) ...[
            const SizedBox(height: 12),
            SafeTextIconButton(
  onPressed: onNuevaSolicitud,
  icon: Icons.add_rounded,
  iconSize: 16,
  iconColor: _C.azulBrillo,
  label: 'Nueva Solicitud',
  textStyle: GoogleFonts.inter(
                      color: _C.azulBrillo,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
),
          ],
        ],
      ),
    );
  }
}
