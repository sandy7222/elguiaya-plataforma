

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'seguridad_service.dart';
import 'maestro_pescador_skill.dart';
import 'emergencia_nautica_skill.dart';
import 'navegacion_gps_skill.dart';
import 'truco_argentino_skill.dart';

class AsistenteResponse {
  final String mensaje;
  final String tipo; // 'venta', 'recomendacion', 'alerta', 'moderacion'
  final Map<String, dynamic>? datos;
  final double confianza;

  AsistenteResponse({
    required this.mensaje,
    required this.tipo,
    this.datos,
    required this.confianza,
  });

  factory AsistenteResponse.fromJson(Map<String, dynamic> json) {
    return AsistenteResponse(
      mensaje: json['mensaje'] ?? '',
      tipo: json['tipo'] ?? 'general',
      datos: json['datos'],
      confianza: (json['confianza'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Modelo de recomendacion personalizada
class RecomendacionPersonalizada {
  final String guiaId;
  final String guiaNombre;
  final String especialidad;
  final String motivo;
  final double disponibilidad;
  final double precio;

  RecomendacionPersonalizada({
    required this.guiaId,
    required this.guiaNombre,
    required this.especialidad,
    required this.motivo,
    required this.disponibilidad,
    required this.precio,
  });
}

/// Modelo de deteccion de fraude
class DeteccionFraude {
  final String chatId;
  final String usuarioId;
  final String tipoViolacion; // 'evasion_comision', 'contacto_directo'
  final String mensajeDetectado;
  final String patronDetectado;
  final DateTime fechaDeteccion;
  final double severidad; // 0.0 a 1.0

  DeteccionFraude({
    required this.chatId,
    required this.usuarioId,
    required this.tipoViolacion,
    required this.mensajeDetectado,
    required this.patronDetectado,
    required this.fechaDeteccion,
    required this.severidad,
  });
}

/// Servicio de Inteligencia Artificial - Asistente El Guia YA
class GeminiAIService {
  static const String _apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: 'AIzaSy...'); // Reemplazar con API key real
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';
  static const String _model = 'gemini-2.5-flash';
  
  static String get _identidadAsistente => '''
Soy el Asistente El Guia YA, tu experto en pesca y ventas especializado en la plataforma El Guia YA. 
Mi mision es ayudarte a encontrar las mejores experiencias de pesca y garantizar transacciones seguras.
Tengo acceso a informacion en tiempo real sobre disponibilidad de guias, perfiles verificados y condiciones actuales.
Siempre me identificare como Asistente El Guia YA y ofrecere recomendaciones personalizadas basadas en tus preferencias.

\${EmergenciaNauticaSkill.protocoloEmergencia}

\${NavegacionGpsSkill.manualGps}

\${MaestroPescadorSkill.manifiestoReglas}

\${TrucoArgentinoSkill.manifiestoReglas}
''';

  /// Inicializar conversacion con identidad del Asistente El Guia YA
  static Future<AsistenteResponse> inicializarConversacion({
    required String usuarioId,
    required String rol, // 'pescador' o 'capitan'
  }) async {
    try {
      final prompt = '''
$_identidadAsistente

Contexto del usuario:
- ID: $usuarioId
- Rol: $rol
- Fecha actual: ${DateTime.now().toString().split(' ')[0]}

Genera un mensaje de bienvenida personalizado que:
1. Me identifique como Asistente El Guia YA
2. Reconozca el rol del usuario
3. Ofrezca ayuda especifica segun sus necesidades
4. Mencione que tengo acceso a disponibilidad en tiempo real
5. Sea amigable pero profesional

Responde en formato JSON:
{
  "mensaje": "texto del mensaje",
  "tipo": "bienvenida",
  "confianza": 0.95
}
''';

      final response = await _callGemini(prompt);
      return AsistenteResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error al inicializar conversacion: $e');
    }
  }

  /// Logica de ventas activa para pescadores explorando guias
  static Future<AsistenteResponse> intervenirVentaActiva({
    required String pescadorId,
    required String guiaId,
    required String contexto, // que esta viendo el usuario
  }) async {
    try {
      // Obtener datos del pescador y guia
      final pescador = await SeguridadService.getUsuarioPorId(pescadorId);
      final guia = await SeguridadService.getUsuarioPorId(guiaId);
      
      final prompt = '''
$_identidadAsistente

CONTEXTO DE VENTA ACTIVA:
- Pescador: ${pescador?.nombre ?? 'Usuario'} (ID: $pescadorId)
- Guia explorado: ${guia?.nombre ?? 'Guia'} (ID: $guiaId)
- Contexto de navegacion: $contexto
- Fecha actual: ${DateTime.now().toString().split(' ')[0]}

SITUACION:
Un pescador esta explorando guias en la plataforma. Como Asistente El Guia YA, debo intervenir proactivamente para ayudarle a tomar una decision.

OBJETIVO:
Generar un mensaje de venta activa que:
1. Me identifique como Asistente El Guia YA
2. Pregunte especificamente: "¿Buscas pesca de costa o embarcado?"
3. Mencione que puedo recomendar el mejor guia disponible hoy
4. Sea persuasivo pero no agresivo
5. Genere confianza en mi capacidad de recomendacion

ESTRATEGIA:
- Mostrar conocimiento sobre disponibilidad actual
- Personalizar segun el contexto de navegacion
- Crear urgencia positiva (disponibilidad limitada)
- Ofrecer valor anadido (recomendacion experta)

Responde en formato JSON:
{
  "mensaje": "texto completo del mensaje",
  "tipo": "venta_activa",
  "confianza": 0.90,
  "datos": {
    "estrategia": "personalizada",
    "urgencia": "media",
    "siguiente_paso": "recomendacion"
  }
}
''';

      final response = await _callGemini(prompt);
      return AsistenteResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error en intervencion de venta activa: $e');
    }
  }

  /// Recomendacion personalizada de guias
  static Future<AsistenteResponse> recomendarGuiaPersonalizado({
    required String pescadorId,
    String? tipoPesca, // 'costa', 'embarcado', 'tiburon'
    String? ubicacion,
    int? numeroPescadores,
    double? presupuesto,
  }) async {
    try {
      // Obtener datos del pescador
      final pescador = await SeguridadService.getUsuarioPorId(pescadorId);
      
      // Simular obtencion de guias disponibles (en produccion usar Supabase)
      final guiasDisponibles = await _obtenerGuiasDisponibles(
        tipoPesca: tipoPesca,
        ubicacion: ubicacion,
        numeroPescadores: numeroPescadores,
        presupuesto: presupuesto,
      );

      final prompt = '''
$_identidadAsistente

CONTEXTO DE RECOMENDACION:
- Pescador: ${pescador?.nombre ?? 'Usuario'} (ID: $pescadorId)
- Preferencias: Tipo: $tipoPesca, Ubicacion: $ubicacion, Grupo: $numeroPescadores, Presupuesto: $presupuesto
- Guias disponibles: ${guiasDisponibles.length}
- Fecha actual: ${DateTime.now().toString().split(' ')[0]}

GUIAS DISPONIBLES:
${_formatGuiasParaPrompt(guiasDisponibles)}

OBJETIVO:
Como Asistente El Guia YA, debo recomendar el mejor guia disponible basandome en:
1. Especialidad del guia vs preferencias del pescador
2. Disponibilidad confirmada
3. Relacion calidad-precio
4. Verificacion del guia
5. Experiencia previa similar

CRITERIOS DE EVALUACION:
- 40% especialidad y experiencia
- 30% disponibilidad y flexibilidad
- 20% precio y valor
- 10% verificacion y reputacion

Responde en formato JSON:
{
  "mensaje": "texto de recomendacion completa",
  "tipo": "recomendacion",
  "confianza": 0.85,
  "datos": {
    "guia_recomendado": {
      "id": "guia_id",
      "nombre": "nombre_guia",
      "motivo": "razon de la recomendacion",
      "disponibilidad": 0.9,
      "precio": 15000.0
    },
    "alternativas": ["guia_id_2", "guia_id_3"]
  }
}
''';

      final response = await _callGemini(prompt);
      return AsistenteResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error en recomendacion personalizada: $e');
    }
  }

  /// Moderacion y escaneo de fraude en chats
  static Future<DeteccionFraude?> escanearFraudeChat({
    required String chatId,
    required String usuarioId,
    required String mensaje,
  }) async {
    try {
      final prompt = '''
$_identidadAsistente

CONTEXTO DE MODERACION:
- Chat ID: $chatId
- Usuario ID: $usuarioId
- Mensaje a analizar: "$mensaje"
- Fecha: ${DateTime.now().toString()}

OBJETIVO:
Como Asistente El Guia YA con rol de seguridad, debo detectar patrones de evasion de comision en los chats.

PATRONES A DETECTAR:
1. Evasion de comision:
   - Intercambio de numeros de telefono
   - Intercambio de emails personales
   - Propuestas de pago fuera de plataforma
   - Menciones de "mejor precio si tratamos directo"
   - Coordenadas para encuentros fuera del sistema

2. Contacto directo:
   - "agregame al WhatsApp"
   - "mi numero es..."
   - "escribime a..."
   - "contactame directo..."

3. Fraude:
   - Promesas irreales
   - Precios sospechosamente bajos
   - Solicitudes de pago adelantado
   - Presion para decisiones rapidas

ANALISIS REQUERIDO:
- Identificar si hay violacion
- Clasificar el tipo de violacion
- Evaluar severidad (0.0 a 1.0)
- Extraer el patron detectado
- Determinar confianza en la deteccion

Responde en formato JSON:
{
  "hay_violacion": true/false,
  "tipo_violacion": "evasion_comision/contacto_directo/fraude",
  "patron_detectado": "descripcion del patron",
  "severidad": 0.8,
  "confianza": 0.9
}
''';

      final response = await _callGemini(prompt);
      
      if (response['hay_violacion'] == true) {
        return DeteccionFraude(
          chatId: chatId,
          usuarioId: usuarioId,
          tipoViolacion: response['tipo_violacion'] ?? 'desconocido',
          mensajeDetectado: mensaje,
          patronDetectado: response['patron_detectado'] ?? '',
          fechaDeteccion: DateTime.now(),
          severidad: (response['severidad'] as num?)?.toDouble() ?? 0.0,
        );
      }
      
      return null;
    } catch (e) {
      throw Exception('Error en escaneo de fraude: $e');
    }
  }

  /// Generar reporte automatico para Panel de Seguridad
  static Future<String> generarReporteSeguridad(DeteccionFraude deteccion) async {
    try {
      final prompt = '''
$_identidadAsistente

CONTEXTO DE REPORTE DE SEGURIDAD:
- Deteccion ID: ${deteccion.chatId}
- Usuario ID: ${deteccion.usuarioId}
- Tipo de violacion: ${deteccion.tipoViolacion}
- Mensaje detectado: "${deteccion.mensajeDetectado}"
- Patron: "${deteccion.patronDetectado}"
- Severidad: ${deteccion.severidad}
- Fecha: ${deteccion.fechaDeteccion.toString()}

OBJETIVO:
Como Asistente El Guia YA, debo generar un reporte detallado para el Panel de Seguridad que:
1. Describa claramente la violacion detectada
2. Explique el riesgo para la plataforma
3. Recomende acciones especificas
4. Priorice segun severidad
5. Incluya contexto para decision administrativa

ESTRUCTURA DEL REPORTE:
- Resumen ejecutivo
- Analisis de la violacion
- Impacto en el negocio
- Recomendaciones
- Nivel de urgencia

Genera un reporte profesional y detallado (300-500 palabras).
''';

      final response = await _callGemini(prompt);
      return response['reporte'] ?? 'Reporte no generado';
    } catch (e) {
      throw Exception('Error al generar reporte de seguridad: $e');
    }
  }

  /// Obtener guias disponibles (simulado - en produccion usar Supabase)
  static Future<List<Map<String, dynamic>>> _obtenerGuiasDisponibles({
    String? tipoPesca,
    String? ubicacion,
    int? numeroPescadores,
    double? presupuesto,
  }) async {
    // Simulacion de datos - en produccion consultar Supabase
    return [
      {
        'id': 'guia_1',
        'nombre': 'Carlos Rodriguez',
        'especialidad': 'pesca de tiburon',
        'ubicacion': 'Puerto Madryn',
        'precio': 25000.0,
        'disponibilidad': 0.9,
        'verificado': true,
        'experiencia': 10,
      },
      {
        'id': 'guia_2',
        'nombre': 'Maria Gonzalez',
        'especialidad': 'pesca desde costa',
        'ubicacion': 'Mar del Plata',
        'precio': 15000.0,
        'disponibilidad': 0.8,
        'verificado': true,
        'experiencia': 8,
      },
      {
        'id': 'guia_3',
        'nombre': 'Juan Perez',
        'especialidad': 'pesca embarcada',
        'ubicacion': 'San Clemente',
        'precio': 20000.0,
        'disponibilidad': 0.7,
        'verificado': false,
        'experiencia': 5,
      },
    ];
  }

  /// Formatear guias para el prompt
  static String _formatGuiasParaPrompt(List<Map<String, dynamic>> guias) {
    final buffer = StringBuffer();
    for (int i = 0; i < guias.length; i++) {
      final guia = guias[i];
      buffer.writeln('${i + 1}. ${guia['nombre']}');
      buffer.writeln('   - Especialidad: ${guia['especialidad']}');
      buffer.writeln('   - Ubicacion: ${guia['ubicacion']}');
      buffer.writeln('   - Precio: \$${guia['precio']}');
      buffer.writeln('   - Disponibilidad: ${(guia['disponibilidad'] * 100).toStringAsFixed(0)}%');
      buffer.writeln('   - Verificado: ${guia['verificado'] ? 'Si' : 'No'}');
      buffer.writeln('   - Experiencia: ${guia['experiencia']} anos');
      buffer.writeln('');
    }
    return buffer.toString();
  }

  /// Llamada principal a la API de Gemini con soporte opcional de búsqueda en Google e Imágenes
  static Future<Map<String, dynamic>> _callGemini(String prompt, {bool useSearch = false, String? imageBase64}) async {
    if (_apiKey == 'AIzaSy...' || _apiKey.isEmpty) {
      throw Exception('API Key de Gemini no configurada (valor por defecto detectado).');
    }

    try {
      final url = Uri.parse('$_baseUrl/$_model:generateContent?key=$_apiKey');
      
      final parts = <Map<String, dynamic>>[
        {
          'text': prompt,
        },
      ];

      if (imageBase64 != null) {
        parts.add({
          'inlineData': {
            'mimeType': 'image/jpeg',
            'data': imageBase64,
          }
        });
      }

      final body = {
        'contents': [
          {
            'parts': parts,
          },
        ],
        if (useSearch)
          'tools': [
            {
              'googleSearch': {},
            },
          ],
        'generationConfig': {
          'temperature': useSearch ? 0.3 : 0.7,
          'topK': 40,
          'topP': 0.95,
          'maxOutputTokens': 2048,
        },
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final text = data['candidates'][0]['content']['parts'][0]['text'];
        
        // Intentar parsear como JSON (objeto o arreglo)
        try {
          final objStart = text.indexOf('{');
          final arrStart = text.indexOf('[');
          
          if (arrStart != -1 && (objStart == -1 || arrStart < objStart)) {
            final arrEnd = text.lastIndexOf(']') + 1;
            if (arrEnd > arrStart) {
              final jsonStr = text.substring(arrStart, arrEnd);
              final decoded = json.decode(jsonStr);
              if (decoded is List) {
                return {'noticias': decoded};
              }
            }
          }
          
          if (objStart != -1) {
            final objEnd = text.lastIndexOf('}') + 1;
            if (objEnd > objStart) {
              final jsonStr = text.substring(objStart, objEnd);
              return json.decode(jsonStr);
            }
          }
        } catch (e) {
          // Si no es JSON válido, devolver como mensaje
          return {'mensaje': text, 'tipo': 'general', 'confianza': 0.5};
        }
        
        return {'mensaje': text, 'tipo': 'general', 'confianza': 0.5};
      } else {
        throw Exception('Error en API Gemini: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Error llamando a Gemini: $e');
    }
  }

  /// Chat general con el Asistente El Guia YA
  static Future<AsistenteResponse> chatGeneral({
    required String usuarioId,
    required String mensaje,
    List<Map<String, dynamic>>? contextoChat,
    String? imageBase64,
  }) async {
    try {
      final usuario = await SeguridadService.getUsuarioPorId(usuarioId);
      
      final prompt = '''
$_identidadAsistente

CONTEXTO DEL CHAT:
- Usuario: ${usuario?.nombre ?? 'Usuario'} (ID: $usuarioId, Rol: ${usuario?.rol ?? 'desconocido'})
- Mensaje actual: "$mensaje"
- Fecha actual: ${DateTime.now().toString().split(' ')[0]}

HISTORIAL RECIENTE:
${_formatHistorialChat(contextoChat ?? [])}

INSTRUCCIONES:
1. Responde siempre como Asistente El Guia YA
2. Se util, profesional y amigable
3. Ofrece ayuda especifica sobre pesca y la plataforma
4. Si es sobre guias, menciona que puedo verificar disponibilidad
5. Si detecto intencion de evasion, debo advertir sutilmente sobre los riesgos
6. Manten la identidad y proposito del asistente

Responde en formato JSON:
{
  "mensaje": "tu respuesta como Asistente El Guia YA",
  "tipo": "chat_general",
  "confianza": 0.9
}
''';

      final response = await _callGemini(prompt, imageBase64: imageBase64);
      return AsistenteResponse.fromJson(response);
    } catch (e) {
      throw Exception('Error en chat general: $e');
    }
  }

  /// Formatear historial de chat para el prompt
  static String _formatHistorialChat(List<Map<String, dynamic>> historial) {
    if (historial.isEmpty) return 'Sin historial reciente.';
    
    final buffer = StringBuffer();
    for (int i = historial.length - 1; i >= 0 && i >= historial.length - 3; i--) {
      final msg = historial[i];
      buffer.writeln('${msg['rol']}: ${msg['mensaje']}');
    }
    return buffer.toString();
  }

  /// Analizar una noticia web y redactar una nota estructurada para el blog
  static Future<Map<String, dynamic>> analizarYRedactarNoticia({
    required String titulo,
    required String fragmento,
    required String url,
    List<Map<String, dynamic>>? productosDisponibles,
  }) async {
    String productosPrompt = '';
    if (productosDisponibles != null && productosDisponibles.isNotEmpty) {
      productosPrompt = "PRODUCTOS DISPONIBLES EN NUESTRA TIENDA (asocia sólo sus IDs):\n";
      for (final p in productosDisponibles) {
        productosPrompt += "- ID: ${p['id']} | Nombre: ${p['nombre']} | Descripción: ${p['descripcion']}\n";
      }
    }

    final bool esVideo = url.contains('youtube.com') || url.contains('youtu.be');
    final String contextoEspecifico = esVideo
        ? 'CONTEXTO ESPECIAL: La fuente de información es un VIDEO DE YOUTUBE. Escribe la nota como un resumen editorial del video de pesca. Explica de qué se trata la jornada, qué técnicas de pesca o carnadas se utilizan, y anima al lector a reproducir el video en el reproductor interactivo al final de la página. Usa títulos para organizar la información (ej. ## Puntos clave del video, ## Equipos utilizados).'
        : 'CONTEXTO ESPECIAL: La fuente es una noticia escrita de la web. Redacta el cuerpo sintetizando el reporte.';

    final prompt = '''
$_identidadAsistente

OBJETIVO:
Actuar como un redactor deportivo experto de pesca para la plataforma EL GUIA YA. Debes compilar una noticia a partir de la fuente proporcionada.

$contextoEspecifico

DATOS DE LA NOTICIA ENCONTRADA:
- Título original/Video: $titulo
- Resumen/Fragmento: $fragmento
- URL Fuente: $url

$productosPrompt

INSTRUCCIONES DE REDACCIÓN:
1. **Título**: Escribe un título atractivo en español con emoticones (ej. "🎣 Reporte de Piques...", "🎥 Gran Pesca de...").
2. **Resumen**: Escribe un resumen breve y enganchador de 1-2 oraciones.
3. **Contenido**: Redacta el cuerpo de la nota en formato Markdown simplificado (usa títulos con #, ##, ###, viñetas -, negritas ** y citas > para destacar tips). Debe tener entre 150 y 300 palabras, un tono apasionado y dar recomendaciones útiles basadas en la noticia o video.
4. **Categoría**: Clasifica el artículo en una de estas categorías: "Piques de la Semana", "Guías de Pesca", "Tutoriales", "Novedades".
5. **Tiempo de Lectura**: Estima los minutos de lectura (número entero entre 2 y 8).
6. **Productos Sugeridos**: Analiza el texto del reporte/video y asocia una lista de IDs de los productos disponibles que tengan afinidad (por ejemplo, si habla de pesca de variada o dorado, sugiere reels, cañas o señuelos afines). Si no hay productos disponibles en la lista anterior, o no coinciden, devuelve una lista vacía [].

RESPONDE ÚNICAMENTE CON UN JSON CON LA SIGUIENTE ESTRUCTURA (sin bloques de código ```json ni texto adicional, sólo el JSON puro):
{
  "titulo": "Título de la nota redactada",
  "resumen": "Resumen corto",
  "contenido": "Cuerpo de la nota en formato Markdown",
  "categoria": "Categoría elegida",
  "minutos_lectura": 3,
  "productos_sugeridos": ["id1", "id2"]
}
''';

    try {
      final response = await _callGemini(prompt);
      return response;
    } catch (e) {
      print("Error en analizarYRedactarNoticia: $e");
      // Fallback
      return {
        "titulo": "🎣 Reporte: $titulo",
        "resumen": fragmento,
        "contenido": "# $titulo\n\n$fragmento\n\n*Nota recopilada de la web.*",
        "categoria": "Piques de la Semana",
        "minutos_lectura": 3,
        "productos_sugeridos": <String>[]
      };
    }
  }

  /// Busca noticias reales de pesca deportiva usando Google Search Grounding en Gemini
  static Future<List<Map<String, dynamic>>> buscarNoticiasRealesWeb(String query) async {
    final prompt = '''
Busca en Google noticias, reportes de piques de pesca y novedades reales de la última semana (menos de 7 días de antigüedad) para la siguiente consulta en Argentina: "$query".

IMPORTANTE: DEBES restringir tu búsqueda y extraer noticias ÚNICAMENTE de las siguientes revistas y portales oficiales:
1. site:weekend.perfil.com
2. site:www.revista-airelibre.com
3. site:revistaelpato.com
4. site:argentina.gob.ar/parquesnacionales

Devuelve una lista de hasta 5 noticias reales encontradas en formato JSON. Para cada noticia debes incluir obligatoriamente:
- "titulo": Título original del artículo o noticia.
- "fragmento": Breve fragmento o descripción de la noticia (1-2 oraciones).
- "fuente": Nombre del sitio web de origen (ej. "Revista Weekend", "Revista El Pato", "Aire Libre", "Parques Nacionales").
- "url": La URL absoluta y directa de la noticia (debe ser una URL real y válida que inicie con http:// o https://).
- "dias_atras": Un número entero del 1 al 7 que represente cuántos días atrás se publicó la nota.

Responde únicamente con un arreglo JSON con los objetos de la estructura indicada, sin bloques de código ```json ni texto adicional. Si no encuentras resultados reales de la última semana, devuelve un arreglo vacío [].
''';

    try {
      final response = await _callGemini(prompt, useSearch: true);
      // La respuesta de _callGemini intenta parsear JSON.
      if (response.containsKey('noticias')) {
        final list = response['noticias'];
        if (list is List) {
          return List<Map<String, dynamic>>.from(
            list.map((item) => Map<String, dynamic>.from(item as Map)),
          );
        }
      }
      if (response.containsKey('mensaje')) {
        final text = response['mensaje'].toString();
        // Intentar buscar un arreglo JSON en el texto
        final jsonStart = text.indexOf('[');
        final jsonEnd = text.lastIndexOf(']') + 1;
        if (jsonStart != -1 && jsonEnd > jsonStart) {
          final jsonStr = text.substring(jsonStart, jsonEnd);
          final decoded = json.decode(jsonStr);
          if (decoded is List) {
            return List<Map<String, dynamic>>.from(
              decoded.map((item) => Map<String, dynamic>.from(item as Map)),
            );
          }
        }
      }
      throw Exception('Formato de respuesta de búsqueda no reconocido.');
    } catch (e) {
      print("⚠️ [GEMINI_SEARCH] Error al buscar noticias reales: $e. Re-lanzando para fallback.");
      rethrow;
    }
  }

  /// Genera un breve comentario editorial (2 oraciones) para un video de YouTube
  /// cuando el RSS no trae descripción propia del influencer.
  /// Costo mínimo de tokens: respuesta corta, sin Google Search.
  static Future<String?> generarComentarioVideo({
    required String tituloVideo,
    required String canalNombre,
  }) async {
    try {
      final prompt = '''
Sos el redactor del blog de pesca deportiva El Guia YA.
El canal "$canalNombre" publicó un nuevo video titulado: "$tituloVideo".

Escribí UN comentario editorial de exactamente 2 oraciones (máx. 200 caracteres en total) que:
1. Resuma de qué trata el video basándote en el título.
2. Invite al pescador a verlo con entusiasmo.

Respondé únicamente con el texto del comentario, sin comillas ni formato JSON.
''';

      final response = await _callGemini(prompt);
      final texto = (response['mensaje'] ?? '').toString().trim();
      if (texto.isEmpty || texto.length < 20) return null;
      // Limpiar comillas si Gemini las agrega
      return texto
          .replaceAll(RegExp('^["\u0027]'), '')
          .replaceAll(RegExp('["\u0027]\$'), '');
    } catch (e) {
      return null;
    }
  }

  /// Verificar estado del servicio
  static Future<bool> verificarEstadoServicio() async {
    try {
      final prompt = '''
$_identidadAsistente

TEST DE CONEXION:
Responde simplemente con: {"status": "ok", "servicio": "Asistente El Guia YA"}
''';

      final response = await _callGemini(prompt);
      return response['status'] == 'ok';
    } catch (e) {
      return false;
    }
  }

  /// Obtener estadisticas de uso del asistente
  static Future<Map<String, dynamic>> obtenerEstadisticasUso() async {
    // En produccion, consultar base de datos de uso
    return {
      'consultas_hoy': 156,
      'recomendaciones_exitosas': 89,
      'detecciones_fraude': 3,
      'satisfaccion_usuarios': 4.7,
      'tiempo_respuesta_promedio': 1.2,
    };
  }
}
