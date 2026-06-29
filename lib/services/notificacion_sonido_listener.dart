import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/notificacion.dart';
import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Respaldo: si Realtime entrega una alerta nueva, suena aunque FCM falle.
class NotificacionSonidoListener {
  static StreamSubscription<List<Notificacion>>? _sub;
  static int _ultimoNoLeidas = 0;
  static String? _ultimoId;
  static bool _inicializado = false;
  static bool _primeraCarga = true;

  static void iniciar() {
    if (_inicializado) return;
    _inicializado = true;
    _reiniciarStream();
    SupabaseService.supabase.auth.onAuthStateChange.listen((_) {
      _primeraCarga = true;
      _reiniciarStream();
    });
  }

  /// Llamar tras login para activar el listener de sonido Realtime.
  static void reiniciar() {
    if (!_inicializado) {
      iniciar();
      return;
    }
    _primeraCarga = true;
    _reiniciarStream();
  }

  static void detener() {
    _sub?.cancel();
    _sub = null;
    _ultimoNoLeidas = 0;
    _ultimoId = null;
    _primeraCarga = true;
    _inicializado = false;
  }

  static void _reiniciarStream() {
    _sub?.cancel();
    _ultimoNoLeidas = 0;
    _ultimoId = null;
    _primeraCarga = true;

    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    _sub = SupabaseService.getNotificacionesStream().listen(
      (lista) async {
        if (lista.isEmpty) return;

        final noLeidas = lista.where((n) => !n.leida).length;
        final masReciente = lista.first;

        if (_primeraCarga) {
          _primeraCarga = false;
          _ultimoNoLeidas = noLeidas;
          _ultimoId = masReciente.id;
          return;
        }

        final esNueva = masReciente.id != _ultimoId && !masReciente.leida;
        final subioContador = noLeidas > _ultimoNoLeidas;

        if ((esNueva || subioContador) && !masReciente.leida) {
          try {
            await PushNotificationService.mostrarAlertaLocal(
              titulo: masReciente.titulo,
              cuerpo: masReciente.mensaje,
              payload: masReciente.metadata,
            );
          } catch (e) {
            debugPrint('NotificacionSonidoListener: $e');
          }
        }

        _ultimoNoLeidas = noLeidas;
        _ultimoId = masReciente.id;
      },
      onError: (e) => debugPrint('NotificacionSonidoListener stream: $e'),
    );
  }
}
