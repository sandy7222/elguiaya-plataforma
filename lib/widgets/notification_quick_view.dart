
import 'package:flutter/material.dart';
import '../models/notificacion.dart';
import '../services/supabase_service.dart';
import '../screens/resumen_reserva_screen.dart';
import '../screens/captain_quote_screen.dart';
import '../screens/viajes_programados_screen.dart';

class NotificationQuickView extends StatelessWidget {
  const NotificationQuickView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Notificacion>>(
      stream: SupabaseService.getNotificacionesStream(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? [];
        final unreadCount = notifications.where((n) => !n.leida).length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(
                Icons.notifications_outlined,
                color: unreadCount > 0 ? Colors.amber : Colors.white,
                size: 28,
              ),
              onPressed: () => _showQuickView(context, notifications),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showQuickView(BuildContext context, List<Notificacion> notifications) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Notifications',
      barrierColor: Colors.black.withValues(alpha: 0.5),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.topRight,
          child: Container(
            margin: const EdgeInsets.only(top: 100, right: 20),
            width: 300,
            constraints: const BoxConstraints(maxHeight: 400),
            decoration: BoxDecoration(
              color: const Color(0xFF001A33),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: const [
                        Text(
                          'Notificaciones',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                  if (notifications.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No hay novedades', style: TextStyle(color: Colors.white54)),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        itemCount: notifications.length > 5 ? 5 : notifications.length,
                        separatorBuilder: (context, index) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                        itemBuilder: (context, index) {
                          final n = notifications[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue.withValues(alpha: 0.2),
                              radius: 15,
                              child: Icon(n.icon, color: Colors.white, size: 16),
                            ),
                            title: Text(
                              n.titulo,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: n.leida ? FontWeight.normal : FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              n.mensaje,
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () async {
                              Navigator.pop(context);
                              SupabaseService.marcarNotificacionLeida(n.id);

                              final metadata = n.metadata;
                              if (metadata != null) {
                                final String? cotizacionId = metadata['cotizacion_id']?.toString();
                                final String? pedidoId = metadata['pedido_id']?.toString();

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
                                    final user = SupabaseService.supabase.auth.currentUser;
                                    if (user != null) {
                                      final profile = await SupabaseService.supabase
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
                                    debugPrint('Error en navegación quick view: $e');
                                    if (context.mounted) {
                                      Navigator.of(context).pop();
                                      Navigator.pushNamed(context, '/notificaciones');
                                    }
                                  }
                                  return;
                                }
                              }

                              if (context.mounted) {
                                Navigator.pushNamed(context, '/notificaciones');
                              }
                            },
                          );
                        },
                      ),
                    ),
                  const Divider(color: Colors.white12, height: 1),
                  InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/notificaciones');
                    },
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      child: const Text(
                        'Ver todas las notificaciones',
                        style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: anim1,
            alignment: Alignment.topRight,
            child: child,
          ),
        );
      },
    );
  }
}
