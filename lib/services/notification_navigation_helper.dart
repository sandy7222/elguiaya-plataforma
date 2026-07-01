import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screens/captain_quote_screen.dart';
import '../screens/resumen_reserva_screen.dart';
import '../screens/viajes_programados_screen.dart';

/// Navegación compartida al tocar una notificación (campanita o centro de alertas).
class NotificationNavigationHelper {
  static Future<void> abrirDesdePayload(
    BuildContext context,
    Map<String, dynamic>? payload,
  ) async {
    if (!context.mounted) return;

    if (payload == null || payload.isEmpty) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute != '/notificaciones') {
        Navigator.pushNamed(context, '/notificaciones');
      }
      return;
    }

    final cotizacionId = payload['cotizacion_id']?.toString();
    final pedidoId = payload['pedido_id']?.toString();

    final tieneDestino = (cotizacionId != null && cotizacionId.isNotEmpty) ||
        (pedidoId != null && pedidoId.isNotEmpty);

    if (!tieneDestino) {
      final currentRoute = ModalRoute.of(context)?.settings.name;
      if (currentRoute != '/notificaciones') {
        Navigator.pushNamed(context, '/notificaciones');
      }
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      ),
    );

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('es_capitan')
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));

      if (!context.mounted) return;

      final esCapitan = profile?['es_capitan'] == true;

      if (cotizacionId != null && cotizacionId.isNotEmpty) {
        if (esCapitan) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CaptainQuoteScreen(cotizacionId: cotizacionId),
            ),
          );
        } else {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ResumenReservaScreen(cotizacionId: cotizacionId),
            ),
          );
        }
        return;
      }

      if (pedidoId != null && pedidoId.isNotEmpty) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ViajesProgramadosScreen(esCapitan: esCapitan),
          ),
        );
      }
    } catch (e) {
      debugPrint('⚠️ NotificationNavigationHelper: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No pudimos abrir el detalle. Revisá en Centro de Alertas.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pushNamed(context, '/notificaciones');
      }
    } finally {
      cerrarLoading(context);
    }
  }

  static void cerrarLoading(BuildContext context) {
    if (!context.mounted) return;
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }
}
