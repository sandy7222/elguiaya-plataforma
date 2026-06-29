import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_notification_service.dart';

/// Handler top-level: asegura canal; muestra local solo si FCM es data-only.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService.inicializar();
  if (message.notification == null) {
    await PushNotificationService.mostrarDesdeFcm(message);
  }
  debugPrint('FCM background: ${message.data['title'] ?? message.notification?.title}');
}
