

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;


class WhatsAppMessage {
  final String to;
  final String templateName;
  final Map<String, dynamic> templateData;
  final String? customMessage;

  WhatsAppMessage({
    required this.to,
    required this.templateName,
    required this.templateData,
    this.customMessage,
  });
}

/// Modelo de respuesta de WhatsApp API
class WhatsAppResponse {
  final bool success;
  final String messageId;
  final String? error;
  final DateTime timestamp;

  WhatsAppResponse({
    required this.success,
    required this.messageId,
    this.error,
    required this.timestamp,
  });
}

/// Servicio de WhatsApp para comunicaciones automaticas
class WhatsAppService {
  // Configuracion de WhatsApp Business API
  static const String _baseUrl = 'https://graph.facebook.com/v18.0';
  static const String _phoneNumberId = 'YOUR_PHONE_NUMBER_ID'; // Reemplazar
  static const String _accessToken = 'YOUR_ACCESS_TOKEN'; // Reemplazar
  static const String _version = 'v18.0';

  /// Plantillas de mensajes predefinidas
  static const Map<String, String> _plantillas = {
    'confirmacion_pago': '''
?? *EL GUIA YA - Confirmacion de Pago*

¡Hola {{nombre_cliente}}! Soy el Asistente El Guia YA.

? *Pago Confirmado*
 Reserva: {{codigo_reserva}}
 Monto: \${{monto}}
 Fecha: {{fecha_pago}}
 Metodo: {{metodo_pago}}

?? *Detalles de tu Salida*
 Capitan: {{nombre_capitan}}
 Fecha: {{fecha_salida}}
 Hora: {{hora_salida}}
 Ubicacion: {{punto_encuentro}}

?? *Proximos Pasos*
1. Te enviaremos un recordatorio 24hs antes
2. El capitan te contactara para confirmar detalles
3. Presenta este codigo al llegar: {{codigo_acceso}}

?? *¡Nos vemos en el agua!*

_Asistente El Guia YA_
Tu experto en pesca segura
    ''',

    'recordatorio_salida': '''
? *EL GUIA YA - Recordatorio de Salida*

¡Hola {{nombre_cliente}}! Soy el Asistente El Guia YA.

?? *Manana es tu dia de pesca*
 Salida: {{fecha_salida}}
 Hora: {{hora_salida}}
 Punto: {{punto_encuentro}}
 Capitan: {{nombre_capitan}}

?? * checklist para manana:*
? Protector solar
? Gorra y lentes
? Ropa comoda
? Camara (opcional)
? Animo y energia

?? *Contacto del Capitan*
 {{telefono_capitan}}
 {{whatsapp_capitan}}

??? *Estado del tiempo*
{{pronostico_clima}}

?? *Importante*
- Llegar 15 minutos antes
- Confirmar asistencia al capitan
- Seguir sus indicaciones de seguridad

_Asistente El Guia YA_
¡Preparate para una gran aventura!
    ''',

    'alerta_seguridad': '''
?? *EL GUIA YA - Alerta de Seguridad*

¡Hola Admin! Soy el Asistente El Guia YA.

?? *Deteccion de Actividad Sospechosa*

?? *Detalles del Incidente*
 Tipo: {{tipo_alerta}}
 Usuario: {{nombre_usuario}}
 Chat ID: {{chat_id}}
 Severidad: {{severidad}}/10
 Hora: {{fecha_hora}}

?? *Patron Detectado*
{{descripcion_patron}}

?? *Mensaje Analizado*
"{{mensaje_detectado}}"

?? *Recomendacion*
{{accion_recomendada}}

?? *Acciones Inmediatas*
1. Revisar el chat: {{enlace_chat}}
2. Evaluar sancion: {{opciones_sancion}}
3. Contactar usuario si es necesario

?? *Proteccion de la Plataforma*
Esta alerta ayuda a mantener la integridad y seguridad de El Guia YA.

_Asistente El Guia YA_
Vigilando tu comunidad
    ''',

    'cancelacion_reserva': '''
? *EL GUIA YA - Cancelacion de Reserva*

¡Hola {{nombre_cliente}}! Soy el Asistente El Guia YA.

?? *Cancelacion Procesada*
 Reserva: {{codigo_reserva}}
 Fecha cancelacion: {{fecha_cancelacion}}
 Motivo: {{motivo_cancelacion}}

?? *Informacion de Reembolso*
{{detalle_reembolso}}

?? *¿Necesitas ayuda?*
 Contacta soporte: {{telefono_soporte}}
 Email: {{email_soporte}}
 WhatsApp: {{whatsapp_soporte}}

?? *¿Quieres reagendar?*
Visita nuestra web o habla con tu Asistente El Guia YA

_Asistente El Guia YA_
Aqui para ayudarte
    ''',

    'bienvenida_pescador': '''
?? *¡Bienvenido a EL GUIA YA!*

¡Hola {{nombre}}! Soy el Asistente El Guia YA, tu experto personal en pesca.

?? *¿Lista para tu proxima aventura?*

? *¿Que puedo hacer por ti?*
 Encontrar el capitan perfecto
 Verificar disponibilidad en tiempo real
 Recomendaciones personalizadas
 Asistencia 24/7

?? *Tip Rapido*
¿Buscas pesca de costa o embarcada? Preguntame y te recomiendo el mejor guia disponible hoy.

?? *Comunicate conmigo*
Escribe "ayuda" o dime que tipo de pesca te interesa.

_Asistente El Guia YA_
Tu puerta de entrada al mundo de la pesca
    ''',

    'bienvenida_capitan': '''
? *¡Bienvenido Capitan a EL GUIA YA!*

¡Hola {{nombre}}! Soy el Asistente El Guia YA, aqui para potenciar tu negocio.

?? *Herramientas para tu exito*

? *¿Que puedo hacer por ti?*
 Gestionar tu calendario de disponibilidad
 Conectar con pescadores calificados
 Optimizar tus reservas
 Asistencia con pagos y logistica

?? *Tips para Capitanes*
 Manten tu perfil actualizado
 Responde rapidamente a las consultas
 Solicita verificacion para mas confianza

?? *¿Listo para mas reservas?*
Dime "disponibilidad" y te ayudo a gestionar tu agenda.

_Asistente El Guia YA_
Tu partner en el exito
    ''',
  };

  /// Enviar mensaje de WhatsApp
  static Future<WhatsAppResponse> enviarMensaje(WhatsAppMessage message) async {
    try {
      final url = Uri.parse('$_baseUrl/$_phoneNumberId/messages');
      
      final body = {
        'messaging_product': 'whatsapp',
        'to': message.to,
        'type': 'template',
        'template': {
          'name': message.templateName,
          'language': {'code': 'es'},
          'components': [
            {
              'type': 'body',
              'parameters': _buildTemplateParameters(message.templateData),
            }
          ],
        },
      };

      // Si hay mensaje personalizado, agregarlo
      if (message.customMessage != null) {
        final template = body['template'] as Map;
        final components = template['components'] as List;
        components.add({
          'type': 'body',
          'parameters': [
            {'type': 'text', 'text': message.customMessage!}
          ],
        });
      }

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return WhatsAppResponse(
          success: true,
          messageId: data['messages'][0]['id'],
          timestamp: DateTime.now(),
        );
      } else {
        return WhatsAppResponse(
          success: false,
          messageId: '',
          error: 'Error ${response.statusCode}: ${response.body}',
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      return WhatsAppResponse(
        success: false,
        messageId: '',
        error: 'Exception: $e',
        timestamp: DateTime.now(),
      );
    }
  }

  /// Construir parametros para template
  static List<Map<String, dynamic>> _buildTemplateParameters(Map<String, dynamic> data) {
    final parameters = <Map<String, dynamic>>[];
    
    data.forEach((key, value) {
      parameters.add({
        'type': 'text',
        'text': value.toString(),
      });
    });
    
    return parameters;
  }

  /// Confirmacion de pago instantanea
  static Future<WhatsAppResponse> enviarConfirmacionPago({
    required String telefonoCliente,
    required String nombreCliente,
    required String codigoReserva,
    required double monto,
    required DateTime fechaPago,
    required String metodoPago,
    required String nombreCapitan,
    required DateTime fechaSalida,
    required String horaSalida,
    required String puntoEncuentro,
    required String codigoAcceso,
  }) async {
    final message = WhatsAppMessage(
      to: telefonoCliente,
      templateName: 'confirmacion_pago',
      templateData: {
        'nombre_cliente': nombreCliente,
        'codigo_reserva': codigoReserva,
        'monto': monto.toStringAsFixed(2),
        'fecha_pago': _formatDate(fechaPago),
        'metodo_pago': metodoPago,
        'nombre_capitan': nombreCapitan,
        'fecha_salida': _formatDate(fechaSalida),
        'hora_salida': horaSalida,
        'punto_encuentro': puntoEncuentro,
        'codigo_acceso': codigoAcceso,
      },
    );

    return await enviarMensaje(message);
  }

  /// Recordatorio de salida 24hs antes
  static Future<WhatsAppResponse> enviarRecordatorioSalida({
    required String telefonoCliente,
    required String nombreCliente,
    required DateTime fechaSalida,
    required String horaSalida,
    required String puntoEncuentro,
    required String nombreCapitan,
    required String telefonoCapitan,
    required String whatsappCapitan,
    required String pronosticoClima,
  }) async {
    final message = WhatsAppMessage(
      to: telefonoCliente,
      templateName: 'recordatorio_salida',
      templateData: {
        'nombre_cliente': nombreCliente,
        'fecha_salida': _formatDate(fechaSalida),
        'hora_salida': horaSalida,
        'punto_encuentro': puntoEncuentro,
        'nombre_capitan': nombreCapitan,
        'telefono_capitan': telefonoCapitan,
        'whatsapp_capitan': whatsappCapitan,
        'pronostico_clima': pronosticoClima,
      },
    );

    return await enviarMensaje(message);
  }

  /// Alerta de seguridad directo a WhatsApp del Admin
  static Future<WhatsAppResponse> enviarAlertaSeguridad({
    required String telefonoAdmin,
    required String tipoAlerta,
    required String nombreUsuario,
    required String chatId,
    required double severidad,
    required String descripcionPatron,
    required String mensajeDetectado,
    required String accionRecomendada,
    required String enlaceChat,
    required String opcionesSancion,
  }) async {
    final message = WhatsAppMessage(
      to: telefonoAdmin,
      templateName: 'alerta_seguridad',
      templateData: {
        'tipo_alerta': tipoAlerta,
        'nombre_usuario': nombreUsuario,
        'chat_id': chatId,
        'severidad': severidad.toStringAsFixed(1),
        'fecha_hora': _formatDateTime(DateTime.now()),
        'descripcion_patron': descripcionPatron,
        'mensaje_detectado': mensajeDetectado,
        'accion_recomendada': accionRecomendada,
        'enlace_chat': enlaceChat,
        'opciones_sancion': opcionesSancion,
      },
    );

    return await enviarMensaje(message);
  }

  /// Mensaje de bienvenida para pescadores
  static Future<WhatsAppResponse> enviarBienvenidaPescador({
    required String telefono,
    required String nombre,
  }) async {
    final message = WhatsAppMessage(
      to: telefono,
      templateName: 'bienvenida_pescador',
      templateData: {
        'nombre': nombre,
      },
    );

    return await enviarMensaje(message);
  }

  /// Mensaje de bienvenida para capitanes
  static Future<WhatsAppResponse> enviarBienvenidaCapitan({
    required String telefono,
    required String nombre,
  }) async {
    final message = WhatsAppMessage(
      to: telefono,
      templateName: 'bienvenida_capitan',
      templateData: {
        'nombre': nombre,
      },
    );

    return await enviarMensaje(message);
  }

  /// Mensaje de cancelacion
  static Future<WhatsAppResponse> enviarCancelacionReserva({
    required String telefonoCliente,
    required String nombreCliente,
    required String codigoReserva,
    required DateTime fechaCancelacion,
    required String motivoCancelacion,
    required String detalleReembolso,
    required String telefonoSoporte,
    required String emailSoporte,
    required String whatsappSoporte,
  }) async {
    final message = WhatsAppMessage(
      to: telefonoCliente,
      templateName: 'cancelacion_reserva',
      templateData: {
        'nombre_cliente': nombreCliente,
        'codigo_reserva': codigoReserva,
        'fecha_cancelacion': _formatDate(fechaCancelacion),
        'motivo_cancelacion': motivoCancelacion,
        'detalle_reembolso': detalleReembolso,
        'telefono_soporte': telefonoSoporte,
        'email_soporte': emailSoporte,
        'whatsapp_soporte': whatsappSoporte,
      },
    );

    return await enviarMensaje(message);
  }

  /// Programar recordatorios automaticos
  static Future<void> programarRecordatorios() async {
    try {
      // Obtener todas las reservas proximas (proximas 48 horas)
      final reservas = await _obtenerReservasProximas();

      for (final reserva in reservas) {
        final fechaSalida = DateTime.parse(reserva['fecha_salida']);
        final ahora = DateTime.now();
        final diferencia = fechaSalida.difference(ahora);

        // Si es dentro de 24-26 horas, enviar recordatorio
        if (diferencia.inHours >= 24 && diferencia.inHours <= 26) {
          await enviarRecordatorioSalida(
            telefonoCliente: reserva['telefono_cliente'],
            nombreCliente: reserva['nombre_cliente'],
            fechaSalida: fechaSalida,
            horaSalida: reserva['hora_salida'],
            puntoEncuentro: reserva['punto_encuentro'],
            nombreCapitan: reserva['nombre_capitan'],
            telefonoCapitan: reserva['telefono_capitan'],
            whatsappCapitan: reserva['whatsapp_capitan'],
            pronosticoClima: await _obtenerPronosticoClima(reserva['ubicacion']),
          );
        }
      }
    } catch (e) {
      print('Error programando recordatorios: $e');
    }
  }

  /// Obtener reservas proximas (simulado)
  static Future<List<Map<String, dynamic>>> _obtenerReservasProximas() async {
    // En produccion, consultar Supabase
    return [
      {
        'id': 'reserva_1',
        'telefono_cliente': '+5491166789123',
        'nombre_cliente': 'Juan Perez',
        'fecha_salida': DateTime.now().add(const Duration(hours: 25)).toIso8601String(),
        'hora_salida': '08:00',
        'punto_encuentro': 'Puerto de Mar del Plata',
        'nombre_capitan': 'Carlos Rodriguez',
        'telefono_capitan': '+5491166789456',
        'whatsapp_capitan': '+5491166789456',
        'ubicacion': 'mar_del_plata',
      },
    ];
  }

  /// Obtener pronostico del clima (simulado)
  static Future<String> _obtenerPronosticoClima(String ubicacion) async {
    // En produccion, integrar con API de clima
    return '?? Soleado, 22°C, viento 10km/h, olas 1.5m. Condiciones excelentes para la pesca.';
  }

  /// Verificar estado del servicio
  static Future<bool> verificarEstadoServicio() async {
    try {
      final url = Uri.parse('$_baseUrl/$_version/');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $_accessToken'},
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Obtener estadisticas de mensajes
  static Future<Map<String, dynamic>> obtenerEstadisticasMensajes() async {
    // En produccion, consultar base de datos
    return {
      'mensajes_enviados_hoy': 245,
      'confirmaciones_pago': 89,
      'recordatorios_enviados': 156,
      'alertas_seguridad': 3,
      'tasa_entrega': 0.98,
      'respuesta_promedio_segundos': 15,
    };
  }

  /// Formatear fecha para mensajes
  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// Formatear fecha y hora para mensajes
  static String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Validar numero de telefono
  static bool validarTelefono(String telefono) {
    // Formato: +549XXYYYYYYYY (Argentina)
    final regex = RegExp(r'^\+549\d{10}$');
    return regex.hasMatch(telefono);
  }

  /// Sanitizar mensaje para WhatsApp
  static String sanitizarMensaje(String mensaje) {
    // Reemplazar caracteres problematicos
    return mensaje
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  /// Obtener plantilla personalizada
  static String? obtenerPlantilla(String nombrePlantilla) {
    return _plantillas[nombrePlantilla];
  }

  /// Agregar nueva plantilla
  static void agregarPlantilla(String nombre, String contenido) {
    _plantillas[nombre] = contenido;
  }

  /// Lista de todas las plantillas disponibles
  static List<String> get plantillasDisponibles => _plantillas.keys.toList();
}
