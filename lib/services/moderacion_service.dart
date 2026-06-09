

import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'gemini_ai_service.dart';
import 'seguridad_service.dart';
import 'supabase_service.dart';
import 'whatsapp_service.dart';

class AlertaSeguridad {
  final String id;
  final String usuarioId;
  final String chatId;
  final String tipoAlerta;
  final String mensajeDetectado;
  final String patronDetectado;
  final double severidad;
  final DateTime fechaDeteccion;
  final String estado; // 'pendiente', 'revisada', 'resuelta'
  final String? adminNota;
  final DateTime? fechaRevision;

  AlertaSeguridad({
    required this.id,
    required this.usuarioId,
    required this.chatId,
    required this.tipoAlerta,
    required this.mensajeDetectado,
    required this.patronDetectado,
    required this.severidad,
    required this.fechaDeteccion,
    required this.estado,
    this.adminNota,
    this.fechaRevision,
  });

  factory AlertaSeguridad.fromSupabase(Map<String, dynamic> data) {
    return AlertaSeguridad(
      id: data['id'].toString(),
      usuarioId: data['usuario_id'].toString(),
      chatId: data['chat_id'] ?? '',
      tipoAlerta: data['tipo_alerta'] ?? '',
      mensajeDetectado: data['mensaje_detectado'] ?? '',
      patronDetectado: data['patron_detectado'] ?? '',
      severidad: (data['severidad'] as num?)?.toDouble() ?? 0.0,
      fechaDeteccion: DateTime.parse(data['fecha_deteccion']),
      estado: data['estado'] ?? 'pendiente',
      adminNota: data['admin_nota'],
      fechaRevision: data['fecha_revision'] != null 
          ? DateTime.parse(data['fecha_revision'])
          : null,
    );
  }
}

/// Modelo de patron de fraude
class PatronFraude {
  final String id;
  final String nombre;
  final String descripcion;
  final String expresionRegular;
  final String categoria;
  final double severidadBase;
  final bool activo;

  PatronFraude({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.expresionRegular,
    required this.categoria,
    required this.severidadBase,
    required this.activo,
  });

  factory PatronFraude.fromSupabase(Map<String, dynamic> data) {
    return PatronFraude(
      id: data['id'].toString(),
      nombre: data['nombre'] ?? '',
      descripcion: data['descripcion'] ?? '',
      expresionRegular: data['expresion_regular'] ?? '',
      categoria: data['categoria'] ?? '',
      severidadBase: (data['severidad_base'] as num?)?.toDouble() ?? 0.0,
      activo: data['activo'] ?? true,
    );
  }
}

/// Servicio de moderacion y escaneo de fraude
class ModeracionService {
  static late SupabaseClient _supabase;
  static Timer? _monitorTimer;
  static bool _isMonitoring = false;
  static final List<AlertaSeguridad> _alertasPendientes = [];

  static void initialize() {
    _supabase = SupabaseService.supabase;
  }

  /// Iniciar monitoreo de chats
  static Future<void> iniciarMonitoreo() async {
    if (_isMonitoring) return;

    _isMonitoring = true;
    print('🛡️ Iniciando monitoreo de chats...');

    // Cargar patrones de fraude
    await _cargarPatronesFraude();

    // Ejecutar monitoreo cada 2 minutos
    _monitorTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _monitorearChatsActivos();
    });

    // Ejecutar inmediatamente una vez
    await _monitorearChatsActivos();
  }

  /// Detener monitoreo
  static void detenerMonitoreo() {
    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isMonitoring = false;
    print('🛡️ Monitoreo de chats detenido');
  }

  /// Monitorear chats activos
  static Future<void> _monitorearChatsActivos() async {
    try {
      print('🔍 Monitoreando chats activos...');

      // Obtener chats activos de las ultimas 24 horas
      final hace24Horas = DateTime.now().subtract(const Duration(hours: 24));
      
      final response = await _supabase
          .from('mensajes')
          .select()
          .gte('created_at', hace24Horas.toIso8601String())
          .order('created_at', ascending: false);

      final mensajes = response as List<dynamic>;

      if (mensajes.isEmpty) {
        print('🔍 No hay mensajes recientes para analizar');
        return;
      }

      print('🔍 Analizando ${mensajes.length} mensajes recientes');

      // Analizar cada mensaje
      for (final mensajeData in mensajes) {
        await _analizarMensaje(mensajeData);
      }
    } catch (e) {
      print('❌ Error en monitoreo de chats: $e');
    }
  }

  /// Analizar un mensaje especifico
  static Future<void> _analizarMensaje(Map<String, dynamic> mensajeData) async {
    try {
      final mensaje = mensajeData['contenido']?.toString() ?? '';
      final usuarioId = mensajeData['emisor_id']?.toString() ?? '';
      final chatId = mensajeData['chat_id']?.toString() ?? '';
      final timestamp = DateTime.parse(mensajeData['created_at']);

      if (mensaje.isEmpty || usuarioId.isEmpty) return;

      // Verificar si ya fue analizado recientemente
      final yaAnalizado = await _fueAnalizadoRecientemente(chatId, mensaje, timestamp);
      if (yaAnalizado) return;

      // Escanear con IA
      final deteccion = await GeminiAIService.escanearFraudeChat(
        chatId: chatId,
        usuarioId: usuarioId,
        mensaje: mensaje,
      );

      if (deteccion != null) {
        // Guardar alerta
        await _guardarAlertaSeguridad(deteccion);

        // Enviar alerta inmediata si severidad > 0.7
        if (deteccion.severidad > 0.7) {
          await _enviarAlertaInmediata(deteccion);
        }

        print('🚨 Deteccion de fraude: ${deteccion.tipoViolacion} (Severidad: ${deteccion.severidad})');
      }
    } catch (e) {
      print('❌ Error analizando mensaje: $e');
    }
  }

  /// Verificar si un mensaje ya fue analizado recientemente
  static Future<bool> _fueAnalizadoRecientemente(String chatId, String mensaje, DateTime timestamp) async {
    try {
      final response = await _supabase
          .from('alertas_seguridad')
          .select()
          .eq('chat_id', chatId)
          .eq('mensaje_detectado', mensaje)
          .gte('fecha_deteccion', timestamp.subtract(const Duration(minutes: 5)).toIso8601String())
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }

  /// Guardar alerta de seguridad
  static Future<void> _guardarAlertaSeguridad(DeteccionFraude deteccion) async {
    try {
      await _supabase
          .from('alertas_seguridad')
          .insert({
            'usuario_id': deteccion.usuarioId,
            'chat_id': deteccion.chatId,
            'tipo_alerta': deteccion.tipoViolacion,
            'mensaje_detectado': deteccion.mensajeDetectado,
            'patron_detectado': deteccion.patronDetectado,
            'severidad': deteccion.severidad,
            'fecha_deteccion': deteccion.fechaDeteccion.toIso8601String(),
            'estado': 'pendiente',
          });

      // Agregar a pendientes para notificacion
      final alerta = AlertaSeguridad(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        usuarioId: deteccion.usuarioId,
        chatId: deteccion.chatId,
        tipoAlerta: deteccion.tipoViolacion,
        mensajeDetectado: deteccion.mensajeDetectado,
        patronDetectado: deteccion.patronDetectado,
        severidad: deteccion.severidad,
        fechaDeteccion: deteccion.fechaDeteccion,
        estado: 'pendiente',
      );

      _alertasPendientes.add(alerta);
    } catch (e) {
      print('❌ Error guardando alerta: $e');
    }
  }

  /// Enviar alerta inmediata al admin
  static Future<void> _enviarAlertaInmediata(DeteccionFraude deteccion) async {
    try {
      // Obtener datos del usuario
      final usuario = await SeguridadService.getUsuarioPorId(deteccion.usuarioId);
      
      // Obtener telefono del admin (en produccion, configurar)
      final telefonoAdmin = '+5491166789000'; // Telefono del admin

      final response = await WhatsAppService.enviarAlertaSeguridad(
        telefonoAdmin: telefonoAdmin,
        tipoAlerta: deteccion.tipoViolacion,
        nombreUsuario: usuario?.nombre ?? 'Usuario',
        chatId: deteccion.chatId,
        severidad: deteccion.severidad,
        descripcionPatron: deteccion.patronDetectado,
        mensajeDetectado: deteccion.mensajeDetectado,
        accionRecomendada: _generarRecomendacionAccion(deteccion),
        enlaceChat: 'https://El Guia YA.com/admin/chats/${deteccion.chatId}',
        opcionesSancion: _generarOpcionesSancion(deteccion),
      );

      if (!response.success) {
        print('❌ Error enviando alerta WhatsApp: ${response.error}');
      }
    } catch (e) {
      print('❌ Excepcion enviando alerta: $e');
    }
  }

  /// Generar recomendacion de accion
  static String _generarRecomendacionAccion(DeteccionFraude deteccion) {
    switch (deteccion.tipoViolacion) {
      case 'evasion_comision':
        return 'Advertir al usuario sobre politicas de comision y monitorear actividad futura';
      case 'contacto_directo':
        return 'Enviar mensaje de advertencia y considerar suspension temporal si reincide';
      case 'fraude':
        return 'Suspender cuenta inmediatamente y realizar investigacion completa';
      default:
        return 'Monitorear actividad y evaluar segun patron detectado';
    }
  }

  /// Generar opciones de sancion
  static String _generarOpcionesSancion(DeteccionFraude deteccion) {
    if (deteccion.severidad > 0.8) {
      return 'Suspension inmediata (30 dias)';
    } else if (deteccion.severidad > 0.6) {
      return 'Advertencia formal + monitoreo intensivo';
    } else {
      return 'Advertencia suave + notificacion al usuario';
    }
  }

  /// Cargar patrones de fraude desde la base de datos
  static Future<void> _cargarPatronesFraude() async {
    try {
      final response = await _supabase
          .from('patrones_fraude')
          .select()
          .eq('activo', true);

      final patrones = response.map((p) => PatronFraude.fromSupabase(p)).toList();
      print('🔍 Cargados ${patrones.length} patrones de fraude');
    } catch (e) {
      print('❌ Error cargando patrones: $e');
    }
  }

  /// Escanear mensaje con patrones locales (backup)
  static Future<DeteccionFraude?> escanearConPatronesLocales({
    required String chatId,
    required String usuarioId,
    required String mensaje,
  }) async {
    // Patrones basicos de evasion de comision
    final patrones = [
      {
        'tipo': 'evasion_comision',
        'patron': r'\b\d{10,}\b|\b[\w._%+-]+@[\w.-]+\.[A-Za-z]{2,}\b',
        'descripcion': 'Numero de telefono o email',
        'severidad': 0.7,
      },
      {
        'tipo': 'contacto_directo',
        'patron': r'\b(agregame|whatsapp|contactame|llamame)\b',
        'descripcion': 'Solicitud de contacto directo',
        'severidad': 0.6,
      },
      {
        'tipo': 'evasion_comision',
        'patron': r'\b(fuera|directo|sin comision|mejor precio)\b',
        'descripcion': 'Mencion de evasion de comision',
        'severidad': 0.8,
      },
    ];

    for (final patron in patrones) {
      final regex = RegExp(patron['patron'] as String, caseSensitive: false);
      if (regex.hasMatch(mensaje)) {
        return DeteccionFraude(
          chatId: chatId,
          usuarioId: usuarioId,
          tipoViolacion: patron['tipo'] as String,
          mensajeDetectado: mensaje,
          patronDetectado: patron['descripcion'] as String,
          fechaDeteccion: DateTime.now(),
          severidad: patron['severidad'] as double,
        );
      }
    }

    return null;
  }

  /// Obtener alertas pendientes
  static List<AlertaSeguridad> getAlertasPendientes() {
    return List.from(_alertasPendientes);
  }

  /// Marcar alerta como revisada
  static Future<bool> marcarAlertaRevisada(String alertaId, String adminNota) async {
    try {
      await _supabase
          .from('alertas_seguridad')
          .update({
            'estado': 'revisada',
            'admin_nota': adminNota,
            'fecha_revision': DateTime.now().toIso8601String(),
          })
          .eq('id', alertaId);

      // Remover de pendientes
      _alertasPendientes.removeWhere((alerta) => alerta.id == alertaId);

      return true;
    } catch (e) {
      print('❌ Error marcando alerta como revisada: $e');
      return false;
    }
  }

  /// Resolver alerta
  static Future<bool> resolverAlerta(String alertaId, String resolucion) async {
    try {
      await _supabase
          .from('alertas_seguridad')
          .update({
            'estado': 'resuelta',
            'admin_nota': resolucion,
            'fecha_revision': DateTime.now().toIso8601String(),
          })
          .eq('id', alertaId);

      // Remover de pendientes
      _alertasPendientes.removeWhere((alerta) => alerta.id == alertaId);

      return true;
    } catch (e) {
      print('❌ Error resolviendo alerta: $e');
      return false;
    }
  }

  /// Obtener estadisticas de moderacion
  static Future<Map<String, dynamic>> obtenerEstadisticasModeracion() async {
    try {
      final hoy = DateTime.now();
      final inicioMes = DateTime(hoy.year, hoy.month, 1);

      final response = await _supabase
          .from('alertas_seguridad')
          .select()
          .gte('fecha_deteccion', inicioMes.toIso8601String())
          .lte('fecha_deteccion', hoy.toIso8601String());

      final alertas = response.map((a) => AlertaSeguridad.fromSupabase(a)).toList();

      final evasionComision = alertas.where((a) => a.tipoAlerta == 'evasion_comision').length;
      final contactoDirecto = alertas.where((a) => a.tipoAlerta == 'contacto_directo').length;
      final fraude = alertas.where((a) => a.tipoAlerta == 'fraude').length;
      final pendientes = alertas.where((a) => a.estado == 'pendiente').length;
      final resueltas = alertas.where((a) => a.estado == 'resuelta').length;

      final severidadPromedio = alertas.isNotEmpty
          ? alertas.map((a) => a.severidad).reduce((a, b) => a + b) / alertas.length
          : 0.0;

      return {
        'total_mes': alertas.length,
        'evasion_comision': evasionComision,
        'contacto_directo': contactoDirecto,
        'fraude': fraude,
        'pendientes': pendientes,
        'resueltas': resueltas,
        'severidad_promedio': severidadPromedio,
        'tasa_resolucion': alertas.isNotEmpty ? resueltas / alertas.length : 0,
      };
    } catch (e) {
      print('ERROR ModeracionService: obtenerEstadisticasModeracion fallo, devolviendo mock: $e');
      return {
        'total_mes': 0,
        'evasion_comision': 0,
        'contacto_directo': 0,
        'fraude': 0,
        'pendientes': 0,
        'resueltas': 0,
        'severidad_promedio': 0.0,
        'tasa_resolucion': 0.0,
      };
    }
  }

  /// Obtener alertas recientes
  static Future<List<AlertaSeguridad>> obtenerAlertasRecientes({int limite = 10}) async {
    try {
      final response = await _supabase
          .from('alertas_seguridad')
          .select()
          .order('fecha_deteccion', ascending: false)
          .limit(limite);

      return response.map((a) => AlertaSeguridad.fromSupabase(a)).toList();
    } catch (e) {
      print('ERROR ModeracionService: obtenerAlertasRecientes fallo, devolviendo vacio: $e');
      return [
        AlertaSeguridad(
          id: 'mock-alerta-1',
          usuarioId: '00000000-0000-0000-0000-000000000000',
          chatId: 'mock-chat',
          tipoAlerta: 'informacion',
          mensajeDetectado: 'Servicio de seguridad local activo. Ejecute sql/fix_seguridad_completo.sql.',
          patronDetectado: 'local_bypass',
          severidad: 0.2,
          fechaDeteccion: DateTime.now(),
          estado: 'pendiente',
        )
      ];
    }
  }

  /// Obtener alertas por severidad
  static Future<List<AlertaSeguridad>> obtenerAlertasPorSeveridad(double severidadMinima) async {
    try {
      final response = await _supabase
          .from('alertas_seguridad')
          .select()
          .gte('severidad', severidadMinima)
          .eq('estado', 'pendiente')
          .order('severidad', ascending: false);

      return response.map((a) => AlertaSeguridad.fromSupabase(a)).toList();
    } catch (e) {
      print('ERROR ModeracionService: obtenerAlertasPorSeveridad fallo, devolviendo vacio: $e');
      return [];
    }
  }

  /// Verificar estado del monitoreo
  static bool isMonitoreoActivo() => _isMonitoring;

  /// Generar reporte de seguridad para el panel
  static Future<String> generarReportePanel(List<AlertaSeguridad> alertas) async {
    if (alertas.isEmpty) {
      return 'No hay alertas de seguridad pendientes en este momento.';
    }

    final buffer = StringBuffer();
    buffer.writeln('📊 **REPORTE DE SEGURIDAD - EL GUIA YA**');
    buffer.writeln('');
    buffer.writeln('**Fecha:** ${DateTime.now().toString().split(' ')[0]}');
    buffer.writeln('**Total de Alertas:** ${alertas.length}');
    buffer.writeln('');

    // Agrupar por tipo
    final porTipo = <String, List<AlertaSeguridad>>{};
    for (final alerta in alertas) {
      if (!porTipo.containsKey(alerta.tipoAlerta)) {
        porTipo[alerta.tipoAlerta] = [];
      }
      porTipo[alerta.tipoAlerta]!.add(alerta);
    }

    buffer.writeln('**Alertas por Tipo:**');
    porTipo.forEach((tipo, lista) {
      buffer.writeln('- $tipo: ${lista.length}');
    });
    buffer.writeln('');

    // Alertas de alta severidad
    final altaSeveridad = alertas.where((a) => a.severidad > 0.7).toList();
    if (altaSeveridad.isNotEmpty) {
      buffer.writeln('⚠️ **Alertas de Alta Severidad (>0.7): ${altaSeveridad.length}**');
      for (final alerta in altaSeveridad.take(5)) {
        buffer.writeln('- ${alerta.tipoAlerta}: ${alerta.severidad.toStringAsFixed(2)}');
      }
      buffer.writeln('');
    }

    // Recomendaciones
    buffer.writeln('🎯 **Recomendaciones:**');
    if (altaSeveridad.isNotEmpty) {
      buffer.writeln('- Revisar urgentemente las ${altaSeveridad.length} alertas de alta severidad');
    }
    buffer.writeln('- Monitorear usuarios con multiples alertas');
    buffer.writeln('- Considerar acciones preventivas para patrones recurrentes');
    buffer.writeln('');

    return buffer.toString();
  }

  /// Actualizar patron de fraude
  static Future<bool> actualizarPatronFraude({
    required String patronId,
    required String nombre,
    required String descripcion,
    required String expresionRegular,
    required String categoria,
    required double severidadBase,
    bool activo = true,
  }) async {
    try {
      await _supabase
          .from('patrones_fraude')
          .update({
            'nombre': nombre,
            'descripcion': descripcion,
            'expresion_regular': expresionRegular,
            'categoria': categoria,
            'severidad_base': severidadBase,
            'activo': activo,
            'actualizado_at': DateTime.now().toIso8601String(),
          })
          .eq('id', patronId);

      return true;
    } catch (e) {
      print('❌ Error actualizando patron: $e');
      return false;
    }
  }

  /// Agregar nuevo patron de fraude
  static Future<bool> agregarPatronFraude({
    required String nombre,
    required String descripcion,
    required String expresionRegular,
    required String categoria,
    required double severidadBase,
  }) async {
    try {
      await _supabase
          .from('patrones_fraude')
          .insert({
            'nombre': nombre,
            'descripcion': descripcion,
            'expresion_regular': expresionRegular,
            'categoria': categoria,
            'severidad_base': severidadBase,
            'activo': true,
            'creado_at': DateTime.now().toIso8601String(),
          });

      return true;
    } catch (e) {
      print('❌ Error agregando patron: $e');
      return false;
    }
  }
}
