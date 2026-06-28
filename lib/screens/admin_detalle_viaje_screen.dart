import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/viaje_lifecycle_service.dart';
import '../services/viaje_tracking_service.dart';
import '../widgets/reputacion_badge_widget.dart';
import '../widgets/auditor_map_widget.dart';
import '../widgets/viaje_track_auditor_sheet.dart';
import '../widgets/safe_button.dart';
import 'manifiesto_pasajeros_screen.dart';

/// Pantalla de auditoría profunda de un viaje individual (vista Admin).
/// Muestra timeline de estados, calificaciones de ambas partes, KPIs y acciones de control.
class AdminDetalleViajeScreen extends StatefulWidget {
  final Map<String, dynamic> viaje;

  const AdminDetalleViajeScreen({super.key, required this.viaje});

  @override
  State<AdminDetalleViajeScreen> createState() => _AdminDetalleViajeScreenState();
}

class _AdminDetalleViajeScreenState extends State<AdminDetalleViajeScreen> {
  static const Color _verde = Color(0xFF00E676);
  static const Color _azul = Color(0xFF0D47A1);
  static const Color _fondo = Color(0xFF000B21);

  bool _isLoading = false;
  List<Map<String, dynamic>> _calificaciones = [];
  List<dynamic> _trackLog = [];
  Timer? _trackRefreshTimer;

  String get _codigoViaje {
    final rawId = widget.viaje['id']?.toString() ?? '--------';
    return '#VJ-${rawId.replaceAll('-', '').toUpperCase().substring(0, 4)}';
  }

  String get _refId {
    final rawId = widget.viaje['id']?.toString() ?? '--------';
    return rawId.substring(0, 8).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _trackLog = List<dynamic>.from(widget.viaje['track_log'] as List? ?? []);
    _cargarCalificaciones();
    if (widget.viaje['estado']?.toString() == 'en_curso') {
      _trackRefreshTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        _reloadTrackLog();
      });
    }
  }

  @override
  void dispose() {
    _trackRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _reloadTrackLog() async {
    final pedidoId = widget.viaje['id']?.toString() ?? '';
    if (pedidoId.isEmpty) return;
    final log = await ViajeTrackingService.fetchTrackLog(pedidoId);
    if (mounted) setState(() => _trackLog = log);
  }

  Future<void> _cargarCalificaciones() async {
    try {
      final res = await Supabase.instance.client
          .from('calificaciones_viaje')
          .select('*')
          .eq('pedido_id', widget.viaje['id'] ?? '');
      setState(() => _calificaciones = List<Map<String, dynamic>>.from(res));
    } catch (_) {}
  }

  Future<void> _forzarCierre() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0A192F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Forzar Cierre', style: TextStyle(color: Colors.white)),
        content: Text(
          '¿Deseas forzar el cierre del viaje $_codigoViaje? Esta acción es irreversible.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('FORZAR CIERRE'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await ViajeLifecycleService.cerrarViaje(widget.viaje['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔒 Viaje $_codigoViaje cerrado forzosamente'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final estado = widget.viaje['estado']?.toString() ?? 'desconocido';
    final capitanNombre = widget.viaje['capitan']?['nombre'] ?? 'N/A';
    final pescadorNombre = widget.viaje['pescador']?['nombre'] ?? 'N/A';
    final capitanId = widget.viaje['capitan_id']?.toString() ?? '';
    final pescadorId = widget.viaje['pescador_id']?.toString() ?? '';
    final monto = widget.viaje['monto_total']?.toString() ?? '—';
    final createdAt = widget.viaje['created_at']?.toString().substring(0, 10) ?? '—';

    final calCapitan = _calificaciones.where((c) => c['calificador_rol'] == 'capitan').firstOrNull;
    final calPescador = _calificaciones.where((c) => c['calificador_rol'] == 'pescador').firstOrNull;

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _azul,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_codigoViaje, style: const TextStyle(color: _verde, fontWeight: FontWeight.w900, letterSpacing: 1)),
            Text('AUDITORÍA DE VIAJE', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, letterSpacing: 1.5)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.viaje['id']?.toString() ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('ID copiado'), duration: Duration(seconds: 1), behavior: SnackBarBehavior.floating),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 20),
            tooltip: 'Copiar ID completo',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _verde))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header del viaje
                  _buildGlassCard(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('REFERENCIA', style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 1)),
                                Text(_refId, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                              ],
                            ),
                            _buildEstadoChip(estado),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildInfoTile('Fecha', createdAt, Icons.calendar_today)),
                            Expanded(child: _buildInfoTile('Monto', '\$$monto', Icons.attach_money)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Timeline de estados
                  _buildSectionTitle('TIMELINE DEL VIAJE'),
                  _buildTimeline(estado),
                  const SizedBox(height: 12),

                  _buildSectionTitle('RECORRIDO GPS'),
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AuditorMapWidget(trackLog: _trackLog, showRolesSeparately: true),
                        const SizedBox(height: 12),
                        SafeOutlinedIconButton(
                          onPressed: () => ViajeTrackAuditorSheet.show(context, {
                            ...widget.viaje,
                            'track_log': _trackLog,
                          }),
                          icon: Icons.fullscreen_rounded,
                          iconSize: 18,
                          label: 'Ver auditoría completa',
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _verde,
                            side: BorderSide(color: _verde.withOpacity(0.5)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Partes
                  _buildSectionTitle('PARTES INVOLUCRADAS'),
                  _buildGlassCard(
                    child: Column(
                      children: [
                        _buildParteRow('⚓ Capitán', capitanNombre, capitanId,
                            ReputacionTipo.capitan),
                        const Divider(color: Colors.white10, height: 20),
                        _buildParteRow('🎣 Pescador', pescadorNombre, pescadorId,
                            ReputacionTipo.pescador),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Calificaciones
                  _buildSectionTitle('CALIFICACIONES'),
                  Row(
                    children: [
                      Expanded(child: _buildCalificacionCard('Del Capitán\nal Pescador', calCapitan)),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCalificacionCard('Del Pescador\nal Capitán', calPescador)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Reputación acumulada
                  if (capitanId.isNotEmpty || pescadorId.isNotEmpty) ...[ 
                    _buildSectionTitle('REPUTACIÓN ACUMULADA'),
                    _buildGlassCard(
                      child: Row(
                        children: [
                          if (capitanId.isNotEmpty)
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Capitán', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  const SizedBox(height: 6),
                                  ReputacionBadgeWidget(
                                    userId: capitanId,
                                    tipo: ReputacionTipo.capitan,
                                    compact: false,
                                  ),
                                ],
                              ),
                            ),
                          if (capitanId.isNotEmpty && pescadorId.isNotEmpty)
                            Container(width: 1, height: 60, color: Colors.white10),
                          if (pescadorId.isNotEmpty)
                            Expanded(
                              child: Column(
                                children: [
                                  const Text('Pescador', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  const SizedBox(height: 6),
                                  ReputacionBadgeWidget(
                                    userId: pescadorId,
                                    tipo: ReputacionTipo.pescador,
                                    compact: false,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Acciones de admin
                  _buildSectionTitle('ACCIONES DE ADMINISTRADOR'),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          'VER MANIFIESTO',
                          Icons.assignment_outlined,
                          Colors.blueAccent,
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ManifiestoPasajerosScreen(
                                pedidoId: widget.viaje['id']?.toString() ?? '',
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildActionButton(
                          'FORZAR CIERRE',
                          Icons.lock_rounded,
                          Colors.redAccent,
                          estado == 'cerrado' ? null : _forzarCierre,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildGlassCard({required Widget child, Color? borderColor}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildEstadoChip(String estado) {
    final colorMap = {
      'cerrado': _verde,
      'en_curso': Colors.blueAccent,
      'listo_para_confirmar': Colors.orangeAccent,
      'finalizado': Colors.orangeAccent,
      'pagado': Colors.teal,
      'en_disputa': Colors.redAccent,
    };
    final color = colorMap[estado] ?? Colors.white38;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        estado.toUpperCase().replaceAll('_', ' '),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildTimeline(String estadoActual) {
    final pasos = ['programado', 'pagado', 'en_curso', 'listo_para_confirmar', 'cerrado'];
    final indiceActual = pasos.indexOf(estadoActual);

    return _buildGlassCard(
      child: Row(
        children: List.generate(pasos.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Conector
            final completado = i ~/ 2 < indiceActual;
            return Expanded(
              child: Container(
                height: 2,
                color: completado ? _verde : Colors.white10,
              ),
            );
          } else {
            final pasoIndex = i ~/ 2;
            final completado = pasoIndex <= indiceActual;
            final iconos = [Icons.check_circle_outline, Icons.payments_outlined, Icons.anchor_rounded, Icons.flag_rounded, Icons.lock_rounded];
            final labels = ['Prog.', 'Pago', 'Viaje', 'Fin.', 'Cerrado'];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: completado ? _verde : Colors.white10,
                    border: Border.all(color: completado ? _verde : Colors.white.withOpacity(0.2)),
                  ),
                  child: Icon(iconos[pasoIndex], size: 14, color: completado ? Colors.black : Colors.white30),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[pasoIndex],
                  style: TextStyle(color: completado ? _verde : Colors.white30, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              ],
            );
          }
        }),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white38),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white38, fontSize: 9, letterSpacing: 0.5)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ],
    );
  }

  Widget _buildParteRow(
    String rol,
    String nombre,
    String userId,
    ReputacionTipo tipo,
  ) {
    return Row(
      children: [
        Text(rol, style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              if (userId.isNotEmpty)
                Text(userId.substring(0, 8).toUpperCase(), style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
            ],
          ),
        ),
        if (userId.isNotEmpty)
          ReputacionBadgeWidget(userId: userId, tipo: tipo, compact: true),
      ],
    );
  }

  Widget _buildCalificacionCard(String titulo, Map<String, dynamic>? cal) {
    return _buildGlassCard(
      borderColor: cal != null ? _verde.withOpacity(0.3) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (cal == null)
            const Text('Pendiente', style: TextStyle(color: Colors.white30, fontSize: 12))
          else ...[
            Row(
              children: List.generate(5, (i) {
                return Icon(
                  Icons.anchor_rounded,
                  size: 14,
                  color: i < (cal['calificacion'] as int? ?? 0) ? _verde : Colors.white10,
                );
              }),
            ),
            const SizedBox(height: 4),
            if (cal['comentario'] != null && (cal['comentario'] as String).isNotEmpty)
              Text(
                '"${cal['comentario']}"',
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11, fontStyle: FontStyle.italic),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: onTap == null ? 0.4 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.4)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
