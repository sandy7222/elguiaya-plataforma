import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notificacion_service.dart';
import '../services/notification_navigation_helper.dart';

class NotificacionesScreen extends StatelessWidget {
  final String? usuarioId;

  const NotificacionesScreen({super.key, this.usuarioId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12), // Fondo náutico oscuro
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Centro de Alertas',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Marcar todo como leído',
            icon: const Icon(Icons.done_all, color: Color(0xFF00E5FF)),
            onPressed: () async {
              final uid = (usuarioId != null && usuarioId!.isNotEmpty)
                  ? usuarioId!
                  : (Supabase.instance.client.auth.currentUser?.id ?? '');
              if (uid.isNotEmpty) {
                await NotificacionService().marcarTodasComoLeidas(uid);
              }
            },
          ),
          IconButton(
            tooltip: 'Vaciar bandeja',
            icon: const Icon(Icons.delete_sweep_outlined, color: Colors.white70),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: const Color(0xFF0F172A),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: Colors.white12),
                  ),
                  title: Text(
                    '¿Vaciar alertas?',
                    style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  content: Text(
                    'Se eliminarán permanentemente todas las alertas de tu bandeja.',
                    style: GoogleFonts.outfit(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancelar',
                        style: GoogleFonts.outfit(color: Colors.white54),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final uid = (usuarioId != null && usuarioId!.isNotEmpty)
                            ? usuarioId!
                            : (Supabase.instance.client.auth.currentUser?.id ?? '');
                        if (uid.isNotEmpty) {
                          await NotificacionService().limpiarBandeja(uid);
                        }
                      },
                      child: Text(
                        'Vaciar',
                        style: GoogleFonts.outfit(color: Colors.redAccent, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Fondo degradado sutil
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF0A0E12),
                    Color(0xFF020617),
                    Color(0xFF0F172A),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: NotificacionService().escucharNotificaciones(
                (usuarioId != null && usuarioId!.isNotEmpty)
                    ? usuarioId!
                    : (Supabase.instance.client.auth.currentUser?.id ?? ''),
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Ocurrió un error al cargar las alertas.',
                      style: GoogleFonts.outfit(color: Colors.redAccent),
                    ),
                  );
                }

                final notificaciones = snapshot.data ?? [];

                if (notificaciones.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.sailing_outlined,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Río calmo, patrón.\nNo hay alertas por ahora.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: notificaciones.length,
                  itemBuilder: (context, index) {
                    final notificacion = notificaciones[index];
                    final String notificacionId = notificacion['id'];
                    return Dismissible(
                      key: Key(notificacionId),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                        ),
                        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                      onDismissed: (direction) {
                        NotificacionService().eliminarNotificacion(notificacionId);
                      },
                      child: _buildNotificacionCard(context, notificacion),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificacionCard(BuildContext context, Map<String, dynamic> notificacion) {
    final bool leido = notificacion['leido'] ?? false;
    final String categoria = notificacion['categoria'] ?? 'informativa';
    final String id = notificacion['id'];
    
    // Configuración de bordes y destellos neón
    Color neonColor;
    if (!leido) {
      neonColor = const Color(0xFF00E5FF); // Cyan brillante neón
    } else {
      neonColor = Colors.white.withValues(alpha: 0.1); // Gris apagado
    }

    // Configuración de Iconos por Categoría
    IconData iconData;
    switch (categoria.toLowerCase()) {
      case 'comercial':
        iconData = Icons.attach_money;
        break;
      case 'logistica':
        iconData = Icons.anchor;
        break;
      case 'seguridad':
        iconData = Icons.warning_amber_rounded;
        break;
      case 'marketing':
        iconData = Icons.campaign;
        break;
      default:
        iconData = Icons.notifications_none;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Sombra de destello externo si no está leída
        boxShadow: !leido
            ? [
                BoxShadow(
                  color: neonColor.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () async {
                if (!leido) {
                  NotificacionService().marcarComoLeida(id);
                }

                final payload = notificacion['payload'];
                final payloadMap = payload is Map<String, dynamic>
                    ? payload
                    : (payload is Map ? Map<String, dynamic>.from(payload) : null);

                final cotizacionId = payloadMap?['cotizacion_id']?.toString();
                final pedidoId = payloadMap?['pedido_id']?.toString();
                final tieneDestino = (cotizacionId != null && cotizacionId.isNotEmpty) ||
                    (pedidoId != null && pedidoId.isNotEmpty);

                if (tieneDestino) {
                  await NotificationNavigationHelper.abrirDesdePayload(
                    context,
                    payloadMap,
                  );
                } else {
                  // Si no tiene destino para navegar, mostramos un diálogo con el detalle
                  _mostrarDetalleInformativo(context, notificacion);
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05), // Fondo vidrio
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: leido ? Colors.white.withValues(alpha: 0.08) : neonColor.withValues(alpha: 0.6),
                    width: leido ? 1.0 : 1.5,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icono de Categoría
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: leido ? Colors.white.withValues(alpha: 0.05) : neonColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, color: leido ? Colors.white54 : neonColor, size: 24),
                    ),
                    const SizedBox(width: 16),
                    
                    // Contenido (Título y Texto)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            notificacion['titulo'] ?? 'Aviso',
                            style: GoogleFonts.outfit(
                              color: leido ? Colors.white.withValues(alpha: 0.7) : Colors.white,
                              fontSize: 16,
                              fontWeight: leido ? FontWeight.w500 : FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            notificacion['contenido'] ?? '',
                            style: GoogleFonts.outfit(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Puntito rojo neón si no está leído
                    if (!leido) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 12,
                        height: 12,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.redAccent.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
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
      ),
    );
  }

  void _mostrarDetalleInformativo(BuildContext context, Map<String, dynamic> notificacion) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF00E5FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  notificacion['titulo'] ?? 'Aviso',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              notificacion['contenido'] ?? '',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 15),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Entendido',
                style: GoogleFonts.outfit(color: const Color(0xFF00E5FF), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
