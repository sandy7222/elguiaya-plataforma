import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

// Configuración directa de fuentes para evitar importar Flutter
const List<Map<String, String>> revistasWordPress = [
  {'nombre': 'Revista El Pato', 'rss': 'https://revistaelpato.com/feed/'},
  {'nombre': 'Aire Libre', 'rss': 'https://www.revista-airelibre.com/feed/'},
  {'nombre': 'Rumbo a la Aventura', 'rss': 'https://www.revistarumboalaaventura.com/feed/'},
  {'nombre': 'Sentí la Pesca', 'rss': 'https://sentilapesca.com.ar/feed/'},
  {'nombre': 'Pescare', 'rss': 'https://pescare.com.ar/feed/'},
];

const List<Map<String, String>> youtubeChannels = [
  {'nombre': 'PESCA URBANA', 'id': 'UC85I5FMeTsIZFRRQ9upz_Aw'},
  {'nombre': 'Ando Pescando', 'id': 'UCJoVTeHGxKQNLNT01u4gAwg'},
  {'nombre': 'Juntos por la pesca', 'id': 'UCWIAjEdirpjaycvzZ-lW73A'},
  {'nombre': 'Wilmar Merino', 'id': 'UCN_y81qraWat5q2jN0HUeDA'},
  {'nombre': 'Pescando y cazando con vos', 'id': 'UCckosMF4o2ywyqtZ8c8HUIw'},
  {'nombre': 'PescaRealARG', 'id': 'UCIyLsxvUUyRcRsRWefUU-rg'},
  {'nombre': 'Tiempo de Pesca', 'id': 'UCi2jDD37IhOZhugRkKxye2g'},
  {'nombre': 'ZAZ Pesca', 'id': 'UCSddZ45A4PRSC2euPUZbX5A'},
];

void main() async {
  print('🚀 [PUBLISHER] Iniciando el robot publicador de Blogger (Edición Consola)...');

  // 1. Cargar el archivo .env
  final env = loadEnv('.env');
  final bloggerEmail = env['BLOGGER_PUBLISH_EMAIL'] ?? '';
  final smtpEmail = env['SMTP_EMAIL'] ?? '';
  final smtpPassword = env['SMTP_PASSWORD']?.replaceAll(' ', '') ?? ''; // Quitar espacios si los hay
  final geminiApiKey = env['GEMINI_API_KEY'] ?? '';

  if (bloggerEmail.isEmpty || smtpEmail.isEmpty || smtpPassword.isEmpty) {
    print('❌ [ERROR] Faltan configuraciones en tu archivo .env.');
    print('Asegurate de tener BLOGGER_PUBLISH_EMAIL, SMTP_EMAIL y SMTP_PASSWORD configurados.');
    exit(1);
  }

  if (geminiApiKey.isEmpty) {
    print('⚠️ [ADVERTENCIA] No se encontró GEMINI_API_KEY en el archivo .env.');
    print('Por favor, obtené una clave gratuita en: https://aistudio.google.com/');
    print('E ingresala en el archivo .env como: GEMINI_API_KEY=tu_clave_aca');
    exit(1);
  }

  // 2. Obtener títulos de publicaciones existentes en Blogger para no duplicar
  print('🔍 [PUBLISHER] Obteniendo publicaciones actuales de capitanya.blogspot.com...');
  final titulosExistentes = await obtenerTitulosBlogger('capitanya.blogspot.com');
  print('📰 [PUBLISHER] Se encontraron ${titulosExistentes.length} publicaciones en el blog.');

  // 3. Recopilar nuevos candidatos de noticias y videos de forma directa
  print('🎣 [PUBLISHER] Buscando noticias y videos recientes de forma directa...');
  final candidatos = await obtenerCandidatosRecientes();
  print('✨ [PUBLISHER] Se recopilaron ${candidatos.length} ítems en total de los feeds.');

  // 4. Filtrar candidatos duplicados
  final List<Map<String, dynamic>> nuevosCandidatos = [];
  for (final item in candidatos) {
    final titulo = item['titulo'] as String? ?? '';
    if (titulo.isEmpty) continue;
    final tituloNorm = normalizarTexto(titulo);
    if (!titulosExistentes.contains(tituloNorm)) {
      nuevosCandidatos.add(item);
    }
  }

  print('✨ [PUBLISHER] Total de novedades sin publicar encontradas: ${nuevosCandidatos.length}');

  if (nuevosCandidatos.isEmpty) {
    print('✅ [PUBLISHER] Tu blog ya está al día. No hay notas nuevas para publicar hoy.');
    exit(0);
  }

  // Tomar el primer candidato (el más reciente/nuevo) para procesar
  final itemAPublicar = nuevosCandidatos.first;
  final tituloOriginal = itemAPublicar['titulo'] as String? ?? 'Novedades de Pesca';
  final fragmentoOriginal = itemAPublicar['fragmento'] as String? ?? '';
  final urlOriginal = itemAPublicar['url'] as String? ?? '';
  final imagenOriginal = itemAPublicar['imagen'] as String? ?? '';
  final esVideo = itemAPublicar['is_video'] == true;

  print('📝 [PUBLISHER] Procesando nueva publicación: "$tituloOriginal"');

  // 5. Llamar a la API de Gemini para redactar el post en HTML
  print('🤖 [PUBLISHER] Solicitando redacción a Gemini AI...');
  final htmlCuerpo = await redactarConGemini(
    apiKey: geminiApiKey,
    titulo: tituloOriginal,
    fragmento: fragmentoOriginal,
    url: urlOriginal,
    imagen: imagenOriginal,
    esVideo: esVideo,
  );

  if (htmlCuerpo == null || htmlCuerpo.isEmpty) {
    print('❌ [ERROR] Gemini no pudo redactar la nota.');
    exit(1);
  }

  // 6. Enviar el correo a Blogger usando SMTP de Gmail
  print('✉️ [PUBLISHER] Enviando nota a Blogger por correo electrónico...');
  final exito = await enviarEmail(
    smtpEmail: smtpEmail,
    smtpPassword: smtpPassword,
    destinationEmail: bloggerEmail,
    subject: tituloOriginal,
    htmlContent: htmlCuerpo,
  );

  if (exito) {
    print('🎉 [PUBLISHER] ¡Publicación exitosa! La nota estará disponible en Blogger en unos instantes.');
  } else {
    print('❌ [ERROR] Falló el envío del correo de publicación.');
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Map<String, String> loadEnv(String path) {
  final file = File(path);
  if (!file.existsSync()) return {};
  final lines = file.readAsLinesSync();
  final Map<String, String> env = {};
  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final index = trimmed.indexOf('=');
    if (index == -1) continue;
    final key = trimmed.substring(0, index).trim();
    final value = trimmed.substring(index + 1).trim();
    env[key] = value;
  }
  return env;
}

String normalizarTexto(String text) {
  return text
      .toLowerCase()
      .replaceAll(RegExp(r'[áàäâ]'), 'a')
      .replaceAll(RegExp(r'[éèëê]'), 'e')
      .replaceAll(RegExp(r'[íìïî]'), 'i')
      .replaceAll(RegExp(r'[óòöô]'), 'o')
      .replaceAll(RegExp(r'[úùüû]'), 'u')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String limpiarTextoXml(String text) {
  return text
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Future<Set<String>> obtenerTitulosBlogger(String blogspotUrl) async {
  final Set<String> titulos = {};
  try {
    final feedUrl = 'https://$blogspotUrl/feeds/posts/default?alt=json';
    final response = await http.get(Uri.parse(feedUrl));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final feed = data['feed'];
      if (feed != null) {
        final entries = feed['entry'] as List?;
        if (entries != null) {
          for (final entry in entries) {
            final title = entry['title']?['\$t'] as String? ?? '';
            if (title.isNotEmpty) {
              titulos.add(normalizarTexto(title));
            }
          }
        }
      }
    }
  } catch (e) {
    print('⚠️ Error obteniendo títulos de Blogger: $e');
  }
  return titulos;
}

Future<List<Map<String, dynamic>>> obtenerCandidatosRecientes() async {
  final List<Map<String, dynamic>> resultado = [];

  // 1. Obtener de WordPress RSS
  for (final wp in revistasWordPress) {
    try {
      final response = await http.get(Uri.parse(wp['rss']!)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final xml = response.body;
        final items = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false).allMatches(xml);
        for (final item in items) {
          final itemXml = item.group(1) ?? '';
          final title = RegExp(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', caseSensitive: false, dotAll: true)
              .firstMatch(itemXml)?.group(1)?.trim() ?? '';
          final link = RegExp(r'<link[^>]*>([^<]+)</link>', caseSensitive: false)
              .firstMatch(itemXml)?.group(1)?.trim() ?? '';
          final desc = RegExp(r'<description[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?</description>', caseSensitive: false)
              .firstMatch(itemXml)?.group(1)?.trim() ?? '';

          if (title.isNotEmpty && link.isNotEmpty) {
            // Intentar extraer una imagen
            String? image;
            final imgMatch = RegExp(r'src="(https?://[^"]+\.(?:jpg|jpeg|png|webp))"', caseSensitive: false).firstMatch(itemXml);
            if (imgMatch != null) {
              image = imgMatch.group(1);
            }

            resultado.add({
              'titulo': limpiarTextoXml(title),
              'fragmento': limpiarTextoXml(desc),
              'url': link,
              'imagen': image ?? '',
              'fuente': wp['nombre']!,
              'is_video': false,
            });
          }
        }
      }
    } catch (_) {}
  }

  // 2. Obtener de YouTube RSS
  for (final canal in youtubeChannels) {
    try {
      final url = 'https://www.youtube.com/feeds/videos.xml?channel_id=${canal['id']}';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final xml = response.body;
        final entries = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(xml);
        for (final entry in entries) {
          final entryStr = entry.group(1) ?? '';
          final videoId = RegExp(r'<yt:videoId>(.*?)</yt:videoId>').firstMatch(entryStr)?.group(1);
          final title = RegExp(r'<title>(.*?)</title>').firstMatch(entryStr)?.group(1) ?? '';

          if (videoId != null && title.isNotEmpty) {
            resultado.add({
              'titulo': limpiarTextoXml(title),
              'fragmento': 'Video de pesca de ${canal['nombre']!}.',
              'url': 'https://www.youtube.com/watch?v=$videoId',
              'imagen': 'https://img.youtube.com/vi/$videoId/0.jpg',
              'fuente': canal['nombre']!,
              'is_video': true,
            });
          }
        }
      }
    } catch (_) {}
  }

  return resultado;
}

Future<String?> redactarConGemini({
  required String apiKey,
  required String titulo,
  required String fragmento,
  required String url,
  required String imagen,
  required bool esVideo,
}) async {
  final endpoint = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey';

  final prompt = '''
Sos el redactor estrella de la sección de blog y novedades de la tienda de pesca y náutica "Capitán-YA Pesca" de Argentina.
Tu tarea es redactar una entrada de blog espectacular y profesional en español rioplatense (cálido, cercano y apasionado por la pesca, usando modismos locales sutiles como "pescar", "pique", "compadre").
Basate en este contenido original:
- Título original: $titulo
- Fragmento/Detalle: $fragmento
- URL Fuente original: $url

INSTRUCCIONES DE FORMATO Y ESTILO:
1. El artículo se publicará vía email en Blogger, por lo que debes responder ÚNICAMENTE con el código HTML del cuerpo de la entrada (sin bloques de código ```html ni explicaciones de ningún tipo, solo el HTML puro).
2. Estructura en HTML que debés generar:
   - Una breve entradilla introductoria entusiasmando al lector.
   - Si hay una imagen válida ($imagen), colocala arriba con una etiqueta <img src="$imagen" style="width:100%; max-width:650px; height:auto; border-radius:16px; margin:15px 0; box-shadow:0 8px 16px rgba(0,0,0,0.15);" alt="Portada de Pesca" />.
   - Párrafos bien estructurados usando etiquetas <p> describiendo las novedades del pique, consejos y técnicas.
   - Usar subtítulos <h3> (ej. <h3>📍 Zonas recomendadas</h3> o <h3>🎣 Consejos del Capitán</h3>).
   - Usar viñetas <ul> y <li> para listar equipos sugeridos, carnadas recomendadas o tips útiles.
   - Un cierre amigable animando al lector a visitar la tienda física o digital de Capitán-YA para conseguir sus equipos y carnadas en pesos.
   - Si es un video de YouTube, aclarale al usuario que puede abrir la app móvil de Capitán-YA para reproducir este video en el reproductor interactivo integrado y sin publicidad.
   - Al final de todo, agregá un botón o enlace de lectura al artículo original: <p style="margin-top:20px;"><a href="$url" style="background-color:#00E5FF; color:#0A0E12; padding:10px 18px; border-radius:8px; text-decoration:none; font-weight:bold; display:inline-block;">Leer Artículo Completo ➔</a></p>

Generá el código HTML limpio, estético y listo para publicar en Blogger.
''';

  try {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.7,
          'maxOutputTokens': 2048,
        }
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final text = data['candidates'][0]['content']['parts'][0]['text'] as String? ?? '';
      
      // Limpiar marcas de bloques de código markdown que Gemini suele poner
      return text
          .replaceAll('```html', '')
          .replaceAll('```', '')
          .trim();
    } else {
      print('❌ Error de API de Gemini: ${response.statusCode} - ${response.body}');
    }
  } catch (e) {
    print('❌ Excepción llamando a Gemini: $e');
  }
  return null;
}

Future<bool> enviarEmail({
  required String smtpEmail,
  required String smtpPassword,
  required String destinationEmail,
  required String subject,
  required String htmlContent,
}) async {
  final smtpServer = gmail(smtpEmail, smtpPassword);

  final message = Message()
    ..from = Address(smtpEmail, 'Capitán-YA Auto-Publisher')
    ..recipients.add(destinationEmail)
    ..subject = subject
    ..html = htmlContent;

  try {
    final sendReport = await send(message, smtpServer);
    print('✉️ Correo enviado con éxito. Reporte: $sendReport');
    return true;
  } catch (e) {
    print('❌ Error al enviar correo por SMTP: $e');
    return false;
  }
}
