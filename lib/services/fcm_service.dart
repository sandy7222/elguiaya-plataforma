import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:permission_handler/permission_handler.dart';

import 'push_notification_service.dart';
import 'supabase_service.dart';

/// Registro de token FCM real (Android) y handlers de push con sonido.
class FCMService {
  static const String tag = '[FCM_SERVICE]';
  static bool _inicializado = false;

  static bool get _soportaPushAndroid =>
      !kIsWeb && Platform.isAndroid;

  static String obtenerPlataformaDispositivo() {
    if (kIsWeb) return 'Web (Browser)';
    try {
      if (Platform.isAndroid) return 'Android';
      if (Platform.isIOS) return 'iOS';
    } catch (e) {
      debugPrint('$tag Error detectando plataforma: $e');
    }
    return 'Dispositivo Movil';
  }

  /// Inicializa Firebase Messaging en Android (permisos, listeners, token).
  static Future<void> inicializar() async {
    if (!_soportaPushAndroid || _inicializado) return;

    try {
      await Firebase.initializeApp();
      await PushNotificationService.inicializar();

      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      await Permission.notification.request();

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        PushNotificationService.mostrarDesdeFcm(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        PushNotificationService.manejarTap(message);
      });

      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        PushNotificationService.manejarTap(initial);
      }

      messaging.onTokenRefresh.listen(_persistirToken);

      // Escuchar cambios de autenticación para registrar token en cuanto haya usuario activo
      SupabaseService.supabase.auth.onAuthStateChange.listen((data) {
        if (data.session?.user != null) {
          debugPrint('$tag Sesión detectada (${data.event.name}): registrando FCM token...');
          registrarDispositivo();
        }
      });

      _inicializado = true;
      debugPrint('$tag Push Android inicializado.');
      await registrarDispositivo();
    } catch (e) {
      debugPrint('$tag Error inicializando push: $e');
    }
  }

  static bool _esTokenSimulado(String token) {
    // Tokens viejos generados antes de Firebase real (generarTokenFCMFiel)
    return RegExp(r'^f[a-f0-9]{6}:APA91b', caseSensitive: false).hasMatch(token);
  }

  static Future<void> registrarDispositivo() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) {
      debugPrint('$tag Sin sesion: omitiendo registro de token.');
      return;
    }

    if (!_soportaPushAndroid) {
      debugPrint('$tag Push solo Android; omitiendo en esta plataforma.');
      return;
    }

    try {
      if (!_inicializado) {
        await inicializar();
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('$tag No se obtuvo token FCM.');
        return;
      }

      if (_esTokenSimulado(token)) {
        debugPrint('$tag Token simulado detectado, reintentando...');
        await FirebaseMessaging.instance.deleteToken();
        final nuevo = await FirebaseMessaging.instance.getToken();
        if (nuevo == null || nuevo.isEmpty || _esTokenSimulado(nuevo)) {
          debugPrint('$tag No se pudo obtener token FCM real.');
          return;
        }
        await _persistirToken(nuevo);
        return;
      }

      await _persistirToken(token);
    } catch (e) {
      debugPrint('$tag Error registrando dispositivo: $e');
    }
  }

  static Future<void> _persistirToken(String token) async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      final plataforma = obtenerPlataformaDispositivo();
      await SupabaseService.guardarFCMToken(token, dispositivo: plataforma);
      debugPrint('$tag Token FCM guardado ($plataforma).');
    } catch (e) {
      debugPrint('$tag Error guardando token: $e');
    }
  }

  static Future<void> removerDispositivo() async {
    final userId = SupabaseService.currentUserId;
    if (userId == null) return;

    try {
      await SupabaseService.eliminarFCMToken();
      debugPrint('$tag Token removido de Supabase.');
    } catch (e) {
      debugPrint('$tag Error removiendo token: $e');
    }
  }
}
