import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_navigator.dart';
import 'notification_navigation_helper.dart';

/// Canal Android para push de campanita (cotizaciones, viajes, pagos).
class PushNotificationService {
  // v4: canal creado nativamente al abrir la app (sonido garantizado antes del push).
  static const String channelId = 'elguia_alertas_v4';
  static const String channelName = 'Alertas El Guia YA';
  static const String channelDescription =
      'Cotizaciones, viajes y alertas con sonido';
  static const String soundResource = 'elguia_alertas';

  static final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;
  static final Int64List _vibracion = Int64List.fromList([0, 400, 200, 400]);
  static const AndroidNotificationSound _sonido =
      RawResourceAndroidNotificationSound(soundResource);

  static Future<void> inicializar() async {
    if (_inicializado) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
    );

    final androidPlugin = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.deleteNotificationChannel('capitanya_mensajes');
    await androidPlugin?.deleteNotificationChannel('elguia_alertas');
    await androidPlugin?.deleteNotificationChannel('elguia_alertas_v2');
    await androidPlugin?.deleteNotificationChannel('elguia_alertas_v3');

    final channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: _sonido,
      enableVibration: true,
      vibrationPattern: _vibracion,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );

    await androidPlugin?.createNotificationChannel(channel);
    _inicializado = true;
  }

  static AndroidNotificationDetails _detallesAndroid({bool conLogo = true}) {
    return AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: _sonido,
      enableVibration: true,
      vibrationPattern: _vibracion,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      audioAttributesUsage: AudioAttributesUsage.notification,
      icon: '@mipmap/ic_launcher',
      largeIcon: conLogo
          ? const DrawableResourceAndroidBitmap('ic_elguia_logo')
          : null,
      color: const Color(0xFF1B4F72),
    );
  }

  static void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload);
      if (map is Map<String, dynamic>) {
        _navegarDesdePayload(map);
      }
    } catch (e) {
      debugPrint('PushNotificationService tap payload: $e');
    }
  }

  /// Alerta local con sonido propio (Realtime o FCM en foreground/background).
  static Future<void> mostrarAlertaLocal({
    required String titulo,
    String? cuerpo,
    Map<String, dynamic>? payload,
  }) async {
    await inicializar();
    if (titulo.isEmpty) return;

    final id = titulo.hashCode ^ (cuerpo?.hashCode ?? 0);
    final encodedPayload = payload != null ? jsonEncode(payload) : null;

    try {
      await _local.show(
        id,
        titulo,
        cuerpo,
        NotificationDetails(android: _detallesAndroid()),
        payload: encodedPayload,
      );
    } catch (e) {
      debugPrint('PushNotificationService show con logo: $e');
      await _local.show(
        id,
        titulo,
        cuerpo,
        NotificationDetails(android: _detallesAndroid(conLogo: false)),
        payload: encodedPayload,
      );
    }
  }

  /// Muestra banner + sonido cuando llega FCM.
  static Future<void> mostrarDesdeFcm(RemoteMessage message) async {
    final notification = message.notification;
    final titulo = notification?.title ?? message.data['title']?.toString();
    final cuerpo = notification?.body ?? message.data['body']?.toString();
    if (titulo == null || titulo.isEmpty) return;

    await mostrarAlertaLocal(
      titulo: titulo,
      cuerpo: cuerpo,
      payload: _extraerPayload(message),
    );
  }

  static void manejarTap(RemoteMessage message) {
    final payloadMap = _extraerPayload(message);
    if (payloadMap != null) {
      _navegarDesdePayload(payloadMap);
    } else {
      _navegarCentroAlertas();
    }
  }

  static Map<String, dynamic>? _extraerPayload(RemoteMessage message) {
    final raw = message.data['payload'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }

    if (message.data.isNotEmpty) {
      final copy = Map<String, dynamic>.from(message.data);
      copy.remove('title');
      copy.remove('body');
      copy.remove('click_action');
      if (copy.isNotEmpty) return copy;
    }
    return null;
  }

  static void _navegarDesdePayload(Map<String, dynamic> payload) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      NotificationNavigationHelper.abrirDesdePayload(context, payload);
    });
  }

  static void _navegarCentroAlertas() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context == null || !context.mounted) return;
      Navigator.pushNamed(context, '/notificaciones');
    });
  }
}
