import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/safe_button.dart';
import '../services/supabase_service.dart';
import '../services/viaje_lifecycle_service.dart';
import '../utils/view_insets.dart';

/// Inbox de Solicitudes del Capitán — Datos 100% reales desde Supabase.
/// Usa StreamBuilder para actualizaciones en tiempo real.
class InboxCapitanScreen extends StatefulWidget {
  const InboxCapitanScreen({super.key});

  @override
  State<InboxCapitanScreen> createState() => _InboxCapitanScreenState();
}

class _InboxCapitanScreenState extends State<InboxCapitanScreen> {
  String _filtroEstado = 'todos';

  // ── STREAM REAL DE SUPABASE ──
  Stream<List<Map<String, dynamic>>> get _solicitudesStream {
    var query = SupabaseService.supabase
        .from('cotizaciones')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
    return query.map((rows) => List<Map<String, dynamic>>.from(rows));
  }

  List<Map<String, dynamic>> _aplicarFiltro(List<Map<String, dynamic>> rows) {
    if (_filtroEstado == 'todos') return rows;
    
    return rows.where((r) {
      String estado = r['estado'] ?? 'pendiente';
      if (estado == 'pendiente' && r['created_at'] != null) {
        try {
          final createdAt = DateTime.parse(r['created_at'].toString());
          if (DateTime.now().difference(createdAt).inHours >= 24) {
            estado = 'vencido';
          }
        } catch (_) {}
      }
      return estado == _filtroEstado;
    }).toList();
  }

  String _formatFecha(dynamic raw) {
    if (raw == null) return 'A confirmar';
    try {
      final dt = DateTime.parse(raw.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return raw.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001429),
      appBar: AppBar(
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
        title: Row(
          children: [
            const Icon(Icons.inbox_rounded, color: Color(0xFF00E676), size: 22),
            const SizedBox(width: 10),
            Text(
              'Inbox de Solicitudes',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            tooltip: 'Actualizar',
            onPressed: () => setState(() {}),
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.white70),
            tooltip: 'Cerrar Sesión',
            onPressed: () async {
              await SupabaseService.supabase.auth.signOut();
              if (mounted) Navigator.pushReplacementNamed(context, '/login');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── FILTROS ──
          _buildFiltros(),

          // ── LISTA EN TIEMPO REAL ──
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _solicitudesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E676)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'Error: ${snapshot.error}',
                          style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }

                final todas = snapshot.data ?? [];
                final solicitudes = _aplicarFiltro(todas);

                if (solicitudes.isEmpty) {
                  return _buildVacio(todas.isEmpty);
                }

                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    ViewInsets.systemBottomPadding(context, extra: 16),
                  ),
                  itemCount: solicitudes.length,
                  itemBuilder: (context, index) =>
                      _buildCard(solicitudes[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTROS ──
  Widget _buildFiltros() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chipFiltro('todos', 'Todos'),
            const SizedBox(width: 8),
            _chipFiltro('pendiente', 'Pendientes'),
            const SizedBox(width: 8),
            _chipFiltro('respondido', 'Respondidos'),
            const SizedBox(width: 8),
            _chipFiltro('vencido', 'Vencidos'),
          ],
        ),
      ),
    );
  }

  Widget _chipFiltro(String valor, String label) {
    final selected = _filtroEstado == valor;
    return GestureDetector(
      onTap: () => setState(() => _filtroEstado = valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF00E676).withOpacity(0.2) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF00E676) : Colors.white24,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            color: selected ? const Color(0xFF00E676) : Colors.white60,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── ESTADO VACÍO ──
  Widget _buildVacio(bool sinDatos) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sinDatos ? Icons.inbox_outlined : Icons.filter_list_off_rounded,
            color: Colors.white24,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            sinDatos ? 'No hay solicitudes aún' : 'Sin resultados para este filtro',
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            sinDatos
                ? 'Las solicitudes de los pescadores aparecerán aquí en tiempo real'
                : 'Probá con otro filtro',
            style: GoogleFonts.outfit(color: Colors.white30, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── TARJETA DE SOLICITUD ──
  Widget _buildCard(Map<String, dynamic> row) {
    String estadoVisual = row['estado'] ?? 'pendiente';
    if (estadoVisual == 'pendiente' && row['created_at'] != null) {
      try {
        final createdAt = DateTime.parse(row['created_at'].toString());
        if (DateTime.now().difference(createdAt).inHours >= 24) {
          estadoVisual = 'vencido';
        }
      } catch (_) {}
    }

    final descripcion = row['descripcion'] ?? 'Solicitud de viaje';
    final localidad = row['localidad_partida'] ?? 'Sin localidad';
    final provincia = row['provincia_partida'] ?? '';
    final cantidad = row['cantidad_personas'] ?? 1;
    final fechaIda = _formatFecha(row['fecha_ida']);
    final horaEncuentro = row['hora_encuentro'] ?? '--:--';
    final monto = (row['monto'] as num?)?.toDouble() ?? (row['presupuesto_base'] as num?)?.toDouble() ?? 0.0;
    final pescadorId = (row['pescador_id'] ?? '').toString();
    final pescadorTag = pescadorId.length >= 8
        ? 'Pescador #${pescadorId.substring(0, 8).toUpperCase()}'
        : 'Pescador';

    final Color statusColor;
    final String statusText;
    final IconData statusIcon;

    switch (estadoVisual) {
      case 'respondido':
      case 'aceptado':
        statusColor = const Color(0xFF00E676);
        statusText = '✅ Respondido';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'pagado':
        statusColor = Colors.purpleAccent;
        statusText = '💳 Pagado';
        statusIcon = Icons.payment_rounded;
        break;
      case 'cancelado':
        statusColor = Colors.redAccent;
        statusText = '❌ Cancelado';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'vencido':
        statusColor = Colors.grey;
        statusText = '⌛ Vencida';
        statusIcon = Icons.timer_off_rounded;
        break;
      default:
        statusColor = Colors.orangeAccent;
        statusText = '⏳ Pendiente';
        statusIcon = Icons.pending_rounded;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: statusColor.withOpacity(0.25)),
          ),
          child: ExpansionTile(
            iconColor: statusColor,
            collapsedIconColor: Colors.white38,
            leading: CircleAvatar(
              backgroundColor: statusColor.withOpacity(0.15),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            title: Text(
              '$descripcion — $localidad',
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pescadorTag,
                    style: GoogleFonts.outfit(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$cantidad personas • $provincia',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF2196F3),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            trailing: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  monto > 0 ? '\$${monto.toStringAsFixed(0)}' : 'Sin monto',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: GoogleFonts.outfit(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            children: [_buildDetalle(row, estadoVisual, fechaIda, horaEncuentro, cantidad, localidad, provincia)],
          ),
        ),
      ),
    );
  }

  // ── DETALLE EXPANDIDO ──
  Widget _buildDetalle(
    Map<String, dynamic> row,
    String estado,
    String fechaIda,
    String hora,
    int cantidad,
    String localidad,
    String provincia,
  ) {
    final mensaje = row['mensaje'] ?? row['descripcion'] ?? 'Sin mensaje.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(color: Colors.white12),
          const SizedBox(height: 8),

          // Grid de datos
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _datoBadge(Icons.calendar_today_rounded, 'FECHA', fechaIda, Colors.blueAccent),
              _datoBadge(Icons.access_time_rounded, 'HORA', hora, Colors.amberAccent),
              _datoBadge(Icons.group_rounded, 'PERSONAS', '$cantidad', Colors.purpleAccent),
              _datoBadge(Icons.location_on_rounded, 'ZONA', '$localidad, $provincia', Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 12),

          // Mensaje del pescador
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📝 MENSAJE DEL PESCADOR',
                  style: GoogleFonts.outfit(
                    color: Colors.white38,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mensaje,
                  style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Zero-Leak badge
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, color: Colors.amber, size: 12),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Datos de contacto del pescador ocultos (sistema Zero-Leak)',
                  style: GoogleFonts.outfit(color: Colors.amber.withOpacity(0.6), fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Botón de oferta (solo si está pendiente)
          if (estado == 'pendiente')
            _buildBotonOferta(row),
        ],
      ),
    );
  }

  Widget _datoBadge(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: GoogleFonts.outfit(color: color.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(value,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  // ── BOTÓN + FORM DE OFERTA INLINE ──
  Widget _buildBotonOferta(Map<String, dynamic> row) {
    final montoController = TextEditingController();
    bool enviando = false;

    return StatefulBuilder(
      builder: (context, setLocalState) {
        return Column(
          children: [
            TextField(
              controller: montoController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                hintText: 'Tu precio en ARS',
                hintStyle: GoogleFonts.outfit(color: Colors.white24),
                prefixText: '\$ ',
                prefixStyle: GoogleFonts.outfit(color: const Color(0xFF00E676), fontSize: 16, fontWeight: FontWeight.bold),
                filled: true,
                fillColor: Colors.white.withOpacity(0.06),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF00E676), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: enviando
                    ? null
                    : () async {
                        final monto = double.tryParse(montoController.text);
                        if (monto == null || monto <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Ingresá un monto válido'), backgroundColor: Colors.orange),
                          );
                          return;
                        }
                        setLocalState(() => enviando = true);
                        HapticFeedback.mediumImpact();
                        try {
                          await ViajeLifecycleService.enviarPresupuesto(
                            cotizacionId: row['id'],
                            capitanId: SupabaseService.currentUserId ?? '',
                            monto: monto,
                            detalles: 'Oferta del capitán',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('✅ Oferta de \$${monto.toStringAsFixed(0)} enviada!'),
                                backgroundColor: const Color(0xFF00C853),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                            );
                          }
                        } finally {
                          setLocalState(() => enviando = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C853),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: enviando
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: SafeButtonText(
                              'Enviando...',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1),
                            ),
                          ),
                        ],
                      )
                    : SafeButtonContent(
                        icon: Icons.send_rounded,
                        iconSize: 18,
                        label: 'Enviar oferta',
                        textStyle: GoogleFonts.outfit(fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}
