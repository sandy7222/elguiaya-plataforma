import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/notificacion_service.dart';
import 'resumen_reserva_screen.dart';
import 'captain_quote_screen.dart';
import 'viajes_programados_screen.dart';

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
                    return _buildNotificacionCard(context, notificacion);
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
                if (payload != null && payload is Map) {
                  final String? cotizacionId = payload['cotizacion_id']?.toString();
                  final String? pedidoId = payload['pedido_id']?.toString();

                  if ((cotizacionId != null && cotizacionId.isNotEmpty) ||
                      (pedidoId != null && pedidoId.isNotEmpty)) {
                    
                    // Mostrar loading spinner premium
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    );

                    try {
                      final user = Supabase.instance.client.auth.currentUser;
                      if (user != null) {
                        final profile = await Supabase.instance.client
                            .from('profiles')
                            .select('es_capitan')
                            .eq('user_id', user.id)
                            .maybeSingle();

                        final bool esCapitan = profile?['es_capitan'] == true;

                        if (context.mounted) {
                          // Cerrar diálogo de carga
                          Navigator.of(context).pop();

                          if (cotizacionId != null && cotizacionId.isNotEmpty) {
                            if (esCapitan) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CaptainQuoteScreen(cotizacionId: cotizacionId),
                                ),
                              );
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ResumenReservaScreen(cotizacionId: cotizacionId),
                                ),
                              );
                            }
                          } else if (pedidoId != null && pedidoId.isNotEmpty) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViajesProgramadosScreen(esCapitan: esCapitan),
                              ),
                            );
                          }
                        }
                      } else {
                        if (context.mounted) Navigator.of(context).pop();
                      }
                    } catch (e) {
                      debugPrint('Error en navegación: $e');
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    }
                  }
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
}
