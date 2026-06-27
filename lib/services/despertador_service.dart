import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ══════════════════════════════════════════════════════════════════════════════
// DESPERTADOR SERVICE — "El Guia te despierta"
//
// Permite que el asistente IA programe una notificación local que funciona
// con la pantalla apagada y la app cerrada. El usuario lo pide por chat
// y puede cancelarlo en cualquier momento.
//
// Arquitectura:
//   flutter_local_notifications → delega la alarma al SO (Android/iOS)
//   SharedPreferences → guarda el estado (programado, hora, mensaje)
//   El asistente (GeminiAIService) → interpreta el pedido y llama a este servicio
// ══════════════════════════════════════════════════════════════════════════════

class DespertadorService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _inicializado = false;

  // ─── Claves SharedPreferences ─────────────────────────────────────────────
  static const _kActivo        = 'despertador_activo';
  static const _kHora          = 'despertador_hora';
  static const _kMensaje        = 'despertador_mensaje';
  static const _kPedidoId       = 'despertador_pedido_id';
  static const _kFecha          = 'despertador_fecha';

  // ─── Mensajes cálidos del Guia ────────────────────────────────────────────
  static const List<String> _mensajesGuia = [
    '🌅 Buen día chamigo, es hora de despertarse. '
    '¿Querés que vaya calentando la pava para unos mates antes del viaje? ☕⛵',

    '🌄 ¡Arriba chamigo! Hoy es el gran día. '
    'El capitán ya debe estar preparando la lancha. ¡A levantarse! 🎣',

    '☀️ Buenos días, pescador. El Guia YA te recuerda que en pocas horas '
    'zarpar a la aventura. Hora de desayunar y preparar el equipo. ⛵🐟',

    '🌊 ¡Buenas, chamigo! El mar te llama. '
    'Acordate llevar el DNI y el de tus acompañantes. ¡Que sea un gran viaje! 🎣',

    '🦅 ¡Despertate que hoy se pesca! El Guia YA manda saludos. '
    'Tomá unos mates, desayuná bien y salí con tiempo. ☕⛵',
  ];

  // ══════════════════════════════════════════════════════════════════════════
  // INICIALIZACIÓN
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> inicializar() async {
    if (_inicializado) return;

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS:     iosSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificacionTocada,
    );

    _inicializado = true;
  }

  static void _onNotificacionTocada(NotificationResponse response) {
    // Cuando el usuario toca la notificación del despertador,
    // la app se abre (si está cerrada). El payload trae el pedidoId.
    print('🔔 Despertador tocado: ${response.payload}');
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PROGRAMAR DESPERTADOR
  // Llamado desde el asistente cuando el usuario pide que lo despierten
  // ══════════════════════════════════════════════════════════════════════════

  /// Programa una notificación de despertador a la hora indicada.
  /// [hora] en formato "HH:mm" (ej: "06:00")
  /// [pedidoId] para personalizar el mensaje
  /// [nombreCliente] para el saludo personalizado
  /// [fechaViaje] la fecha del viaje (DateTime) — el despertador suena ese día a esa hora
  static Future<DespertadorResult> programar({
    required String hora,              // "06:00"
    required DateTime fechaViaje,
    required String nombreCliente,
    String? pedidoId,
    String? mensajePersonalizado,
  }) async {
    await inicializar();

    try {
      // Parsear hora
      final partes = hora.split(':');
      if (partes.length != 2) {
        return DespertadorResult.error('Hora inválida: $hora. Usá formato HH:MM');
      }
      final hh = int.tryParse(partes[0]);
      final mm = int.tryParse(partes[1]);
      if (hh == null || mm == null || hh < 0 || hh > 23 || mm < 0 || mm > 59) {
        return DespertadorResult.error('Hora fuera de rango: $hora');
      }

      // Construir DateTime objetivo en la zona horaria argentina
      final argTz = tz.getLocation('America/Argentina/Buenos_Aires');
      final ahora = tz.TZDateTime.now(argTz);

      final objetivo = tz.TZDateTime(
        argTz,
        fechaViaje.year,
        fechaViaje.month,
        fechaViaje.day,
        hh,
        mm,
      );

      if (objetivo.isBefore(ahora)) {
        return DespertadorResult.error(
            'La hora $hora del ${fechaViaje.day}/${fechaViaje.month} ya pasó.');
      }

      // Elegir mensaje
      final mensaje = mensajePersonalizado ??
          _mensajeConNombre(_mensajesGuia[DateTime.now().millisecond % _mensajesGuia.length],
              nombreCliente);

      // Canal Android de alta prioridad (se escucha con pantalla apagada)
      const androidDetails = AndroidNotificationDetails(
        'despertador_guia',
        'Despertador El Guia YA',
        channelDescription: 'Notificaciones de despertador del asistente El Guia',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        fullScreenIntent: true,       // aparece como pantalla completa (alarm-like)
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
        styleInformation: BigTextStyleInformation(''),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Programar en el SO
      await _plugin.zonedSchedule(
        _idDespertador,
        '🌅 ¡Buen día, $nombreCliente!',
        mensaje,
        objetivo,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: jsonEncode({
          'tipo': 'despertador',
          'pedido_id': pedidoId ?? '',
          'hora': hora,
        }),
      );

      // Guardar estado en SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kActivo, true);
      await prefs.setString(_kHora, hora);
      await prefs.setString(_kMensaje, mensaje);
      await prefs.setString(_kPedidoId, pedidoId ?? '');
      await prefs.setString(_kFecha, objetivo.toIso8601String());

      return DespertadorResult.ok(
        hora: hora,
        fecha: objetivo,
        mensaje: mensaje,
      );
    } catch (e) {
      return DespertadorResult.error('Error al programar el despertador: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CANCELAR DESPERTADOR
  // ══════════════════════════════════════════════════════════════════════════

  static Future<bool> cancelar() async {
    await inicializar();
    try {
      await _plugin.cancel(_idDespertador);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kActivo, false);
      await prefs.remove(_kHora);
      await prefs.remove(_kMensaje);
      await prefs.remove(_kPedidoId);
      await prefs.remove(_kFecha);

      return true;
    } catch (_) {
      return false;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ESTADO ACTUAL
  // ══════════════════════════════════════════════════════════════════════════

  static Future<DespertadorEstado> estadoActual() async {
    final prefs = await SharedPreferences.getInstance();
    final activo    = prefs.getBool(_kActivo) ?? false;
    final hora      = prefs.getString(_kHora) ?? '';
    final mensaje   = prefs.getString(_kMensaje) ?? '';
    final pedidoId  = prefs.getString(_kPedidoId) ?? '';
    final fechaStr  = prefs.getString(_kFecha) ?? '';

    DateTime? fecha;
    if (fechaStr.isNotEmpty) fecha = DateTime.tryParse(fechaStr);

    // Si la fecha ya pasó, limpiar estado
    if (activo && fecha != null && fecha.isBefore(DateTime.now())) {
      await cancelar();
      return DespertadorEstado(activo: false);
    }

    return DespertadorEstado(
      activo:   activo,
      hora:     hora,
      mensaje:  mensaje,
      pedidoId: pedidoId,
      fecha:    fecha,
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PARSEO DE INTENCIÓN — para que el asistente entienda el pedido del usuario
  // ══════════════════════════════════════════════════════════════════════════

  /// Intenta extraer la hora de un texto libre.
  /// Ej: "despertame a las 6", "poneme alarma 6:30", "a las 05:00"
  /// Retorna null si no encuentra una hora válida.
  static String? extraerHora(String texto) {
    final texto2 = texto.toLowerCase();

    // Patrones: "6:30", "06:30", "6", "6am", "las 6"
    final regExp = RegExp(
        r'(?:a las?|las?|despertame a|alarma a las?)?\s*(\d{1,2})(?::(\d{2}))?(?:\s*(?:am|hs|h))?');
    final match = regExp.firstMatch(texto2);
    if (match == null) return null;

    final hh = int.tryParse(match.group(1) ?? '');
    final mm = int.tryParse(match.group(2) ?? '0') ?? 0;
    if (hh == null || hh < 0 || hh > 23) return null;

    return '${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  /// Detecta si el mensaje del usuario contiene una intención de despertador
  static bool esPeticionDespertador(String texto) {
    final t = texto.toLowerCase();
    final keywords = [
      'despertame', 'despertarme', 'despertá', 'despertate',
      'poneme despertador', 'poneme alarma', 'programame', 'programá',
      'alarmame', 'avisame temprano', 'que me despiertes',
      'despertador', 'wake me', 'wake up',
    ];
    return keywords.any((k) => t.contains(k));
  }

  /// Detecta si el usuario quiere cancelar el despertador
  static bool esCancelacionDespertador(String texto) {
    final t = texto.toLowerCase();
    final keywords = [
      'cancela', 'cancelá', 'cancelar', 'apagar', 'desactivar',
      'borrar el despertador', 'quitá', 'saca', 'no me despiertes',
      'ya no', 'olvidalo', 'olvídalo',
    ];
    return keywords.any((k) => t.contains(k));
  }

  // ──────────────────────────────────────────────────────────────────────────
  static const int _idDespertador = 9999; // ID único para el canal de despertador

  static String _mensajeConNombre(String base, String nombre) {
    // Personalizar el primer saludo con el nombre si viene genérico
    return base.replaceFirst('chamigo', nombre.isNotEmpty ? nombre.split(' ').first : 'chamigo');
  }
}

// ─── Modelos resultado ────────────────────────────────────────────────────────

class DespertadorResult {
  final bool exito;
  final String? errorMsg;
  final String? hora;
  final DateTime? fecha;
  final String? mensaje;

  const DespertadorResult._({
    required this.exito,
    this.errorMsg,
    this.hora,
    this.fecha,
    this.mensaje,
  });

  factory DespertadorResult.ok({
    required String hora,
    required DateTime fecha,
    required String mensaje,
  }) => DespertadorResult._(exito: true, hora: hora, fecha: fecha, mensaje: mensaje);

  factory DespertadorResult.error(String msg) =>
      DespertadorResult._(exito: false, errorMsg: msg);
}

class DespertadorEstado {
  final bool activo;
  final String hora;
  final String mensaje;
  final String pedidoId;
  final DateTime? fecha;

  const DespertadorEstado({
    required this.activo,
    this.hora       = '',
    this.mensaje    = '',
    this.pedidoId   = '',
    this.fecha,
  });
}
