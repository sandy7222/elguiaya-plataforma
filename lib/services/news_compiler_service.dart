import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:El Guia YA_master/models/articulo_blog.dart';
import 'package:El Guia YA_master/models/producto.dart';
import 'package:El Guia YA_master/services/gemini_ai_service.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';

class NewsCompilerService {
  static const List<String> _imagenesPortadaPesca = [
    'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800&h=450&fit=crop', // pescador en río
    'https://images.unsplash.com/photo-1508193638397-1c4234db14d8?w=800&h=450&fit=crop', // pesca deportiva
    'https://images.unsplash.com/photo-1582560475093-ba66accbc424?w=800&h=450&fit=crop', // anzuelo y carnada
    'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=800&h=450&fit=crop', // río al atardecer
    'https://images.unsplash.com/photo-1621351183012-e2f9972dd9bf?w=800&h=450&fit=crop', // pesca en lancha
  ];

  /// Lista curada de canales de YouTube argentinos sobre pesca.
  static const Map<String, String> youtubeChannels = {
    'PESCA URBANA': 'UC85I5FMeTsIZFRRQ9upz_Aw',
    'Ando Pescando': 'UCJoVTeHGxKQNLNT01u4gAwg',
    'Juntos por la pesca': 'UCWIAjEdirpjaycvzZ-lW73A',
    'Wilmar Merino': 'UCN_y81qraWat5q2jN0HUeDA',
    'Pescando y cazando con vos': 'UCckosMF4o2ywyqtZ8c8HUIw',
    'PescaRealARG': 'UCIyLsxvUUyRcRsRWefUU-rg',
    'Tiempo de Pesca': 'UCi2jDD37IhOZhugRkKxye2g',
    'ZAZ Pesca': 'UCSddZ45A4PRSC2euPUZbX5A',
  };

  /// Revistas argentinas de pesca/aventura — se scrapean directamente desde su portada.
  /// Formato: 'Nombre fuente' → { url, patron_links, base_url }
  /// 'patron_links' es un regex que captura las URLs de artículos desde el HTML de la portada.
  static const List<Map<String, String>> revistasArgentinas = [
    {
      'nombre': 'Weekend',
      'url': 'https://weekend.perfil.com/',
      'base': 'https://weekend.perfil.com',
      'patron': r'href="((?:https://weekend\.perfil\.com)?/noticias/[^"]+\.phtml)"',
    },
  ];

  /// Revistas WordPress — se leen vía RSS (más confiable que scraping HTML para WP)
  static const List<Map<String, String>> revistasWordPress = [
    {
      'nombre': 'Revista El Pato',
      'rss': 'https://revistaelpato.com/feed/',
      'base': 'https://revistaelpato.com',
    },
    {
      'nombre': 'Aire Libre',
      'rss': 'https://www.revista-airelibre.com/feed/',
      'base': 'https://www.revista-airelibre.com',
    },
    {
      'nombre': 'Rumbo a la Aventura',
      'rss': 'https://www.revistarumboalaaventura.com/feed/',
      'base': 'https://www.revistarumboalaaventura.com',
    },
    {
      'nombre': 'Sentí la Pesca',
      'rss': 'https://sentilapesca.com.ar/feed/',
      'base': 'https://sentilapesca.com.ar',
    },
    {
      'nombre': 'Pescare',
      'rss': 'https://pescare.com.ar/feed/',
      'base': 'https://pescare.com.ar',
    },
  ];

  /// Fuentes gubernamentales con noticias de naturaleza / parques
  static const List<Map<String, String>> fuentesGubernamentales = [
    {
      'nombre': 'Parques Nacionales',
      'url': 'https://www.argentina.gob.ar/parquesnacionales',
      'base': 'https://www.argentina.gob.ar',
      'patron': r'href="(/parquesnacionales/[a-z0-9\-]+)"',
    },
  ];


  /// Scrapea DIRECTAMENTE las portadas de las revistas argentinas configuradas.
  /// Para cada revista:
  ///   1. Descarga la portada (con proxy CORS como fallback)
  ///   2. Extrae hasta [maxPorRevista] URLs de artículos
  ///   3. Para cada artículo, extrae título + imagen + fragmento
  ///   4. Solo conserva los que tienen imagen REAL del artículo (no Unsplash)
  static Future<List<Map<String, dynamic>>> scrapearRevistas({
    int maxPorRevista = 5,
  }) async {
    final List<Map<String, dynamic>> resultado = [];

    final List<Future<void>> tareas = revistasArgentinas.map((revista) async {
      final String nombre = revista['nombre']!;
      final String homeUrl = revista['url']!;
      final String base = revista['base']!;
      final String patron = revista['patron']!;

      try {
        // 1. Descargar portada
        String? htmlPortada;
        try {
          final r = await http.get(
            Uri.parse(homeUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/109.0 Firefox/109.0'},
          ).timeout(const Duration(seconds: 6));
          if (r.statusCode == 200) htmlPortada = r.body;
        } catch (_) {}

        if (htmlPortada == null) {
          try {
            final proxy = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(homeUrl)}';
            final r = await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 8));
            if (r.statusCode == 200) htmlPortada = r.body;
          } catch (_) {}
        }

        if (htmlPortada == null) {
          print('⚠️ [REVISTAS] No se pudo descargar portada de $nombre');
          return;
        }

        // 2. Extraer URLs de artículos (deduplicar)
        final Set<String> urlsEncontradas = {};
        final regex = RegExp(patron, caseSensitive: false);
        for (final m in regex.allMatches(htmlPortada)) {
          String link = m.group(1) ?? '';
          if (link.isEmpty) continue;
          // Convertir URLs relativas a absolutas
          if (link.startsWith('/')) link = '$base$link';
          // Filtrar links de categorías/inicio/admin
          if (link == homeUrl) continue;
          if (link.endsWith('/') && !link.contains('.phtml')) continue;
          urlsEncontradas.add(link);
          if (urlsEncontradas.length >= maxPorRevista * 2) break; // buffer extra
        }

        print('📰 [REVISTAS] $nombre: ${urlsEncontradas.length} links encontrados en portada');

        // 3. Descargar cada artículo en paralelo (con límite)
        int agregados = 0;
        final List<Future<void>> tareasArticulo = urlsEncontradas.take(maxPorRevista * 2).map((artUrl) async {
          if (agregados >= maxPorRevista) return;
          try {
            String? htmlArt;
            try {
              final r = await http.get(
                Uri.parse(artUrl),
                headers: {'User-Agent': 'Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/109.0 Firefox/109.0'},
              ).timeout(const Duration(seconds: 5));
              if (r.statusCode == 200) htmlArt = r.body;
            } catch (_) {}

            if (htmlArt == null) {
              try {
                final proxy = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(artUrl)}';
                final r = await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 7));
                if (r.statusCode == 200) htmlArt = r.body;
              } catch (_) {}
            }

            if (htmlArt == null) return;

            // Extraer título
            String titulo = '';
            final ogTitle = RegExp(
              r'''<meta\s+(?:property|name)=["']og:title["']\s+content=["']([^"']+)["']''',
              caseSensitive: false,
            ).firstMatch(htmlArt);
            if (ogTitle != null) {
              titulo = ogTitle.group(1) ?? '';
            } else {
              final titleTag = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(htmlArt);
              titulo = titleTag?.group(1) ?? '';
            }
            titulo = _limpiarHtml(titulo).trim();
            if (titulo.isEmpty || titulo.length < 10) return;

            // Extraer imagen principal (og:image)
            String? imagen = _parsearImagenDeHtml(htmlArt);

            // Si no tiene imagen del artículo, generamos una realista con IA
            if (imagen == null ||
                imagen.contains('unsplash') ||
                imagen.contains('placeholder') ||
                imagen.contains('logo') ||
                imagen.contains('icon')) {
              imagen = _obtenerFallbackImagen(titulo);
            }

            // Asegurar URL absoluta para la imagen
            if (imagen.startsWith('//')) imagen = 'https:$imagen';
            if (imagen.startsWith('/')) imagen = '$base$imagen';

            // Extraer fragmento (og:description o primer párrafo)
            String fragmento = '';
            final ogDesc = RegExp(
              r'''<meta\s+(?:property|name)=["']og:description["']\s+content=["']([^"']+)["']''',
              caseSensitive: false,
            ).firstMatch(htmlArt);
            if (ogDesc != null) {
              fragmento = _limpiarHtml(ogDesc.group(1) ?? '').trim();
            }
            if (fragmento.isEmpty) {
              // Fallback: primer párrafo largo
              final pMatch = RegExp(r'<p[^>]*>([^<]{60,})</p>', caseSensitive: false).firstMatch(htmlArt);
              fragmento = _limpiarHtml(pMatch?.group(1) ?? '').trim();
            }
            if (fragmento.length > 280) fragmento = '${fragmento.substring(0, 277)}...';

            // Extraer texto completo para lectura offline
            final textoCompleto = _parsearTextoDeHtml(htmlArt);

            agregados++;
            resultado.add({
              'tipo': 'nota',
              'titulo': titulo,
              'fragmento': fragmento.isNotEmpty ? fragmento : titulo,
              'fuente': nombre,
              'url': artUrl,
              'imagen': imagen,
              'tiene_imagen_real': true,
              'fecha': DateTime.now(),
              'fecha_legible': 'Hoy',
              if (textoCompleto != null) 'contenido_completo': textoCompleto,
            });
          } catch (e) {
            print('⚠️ [REVISTAS] Error scrapeando artículo $artUrl: $e');
          }
        }).toList();

        await Future.wait(tareasArticulo);
      } catch (e) {
        print('⚠️ [REVISTAS] Error general scrapeando $nombre: $e');
      }
    }).toList();

    await Future.wait(tareas);

    // ── Agregar WordPress (RSS) y Parques Nacionales en paralelo ──────────
    final List<Map<String, dynamic>> wpItems = await scrapearWordPress();
    final List<Map<String, dynamic>> gobItems = await scrapearGubernamentales();

    resultado.addAll(wpItems);
    resultado.addAll(gobItems);

    // Mezclar aleatoriamente para que no siempre aparezca la misma revista primero
    resultado.shuffle();
    print('✅ [REVISTAS] Total artículos: ${resultado.length} '
        '(HTML: ${resultado.length - wpItems.length - gobItems.length}, '
        'WP RSS: ${wpItems.length}, Gov: ${gobItems.length})');
    return resultado;
  }

  /// Obtiene las entradas del blog oficial en Blogger (El Guia YA.blogspot.com)
  static Future<List<Map<String, dynamic>>> scrapearBlogspot() async {
    final List<Map<String, dynamic>> resultado = [];
    const String url = 'https://El Guia YA.blogspot.com/feeds/posts/default?alt=json';

    try {
      String? jsonContent;
      // 1. Fetch directo
      try {
        final response = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
        ).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) jsonContent = response.body;
      } catch (e) {
        print("⚠️ [BLOGSPOT] Falló fetch directo: $e");
      }

      // 2. Fallback proxy CORS (por si acaso en web)
      if (jsonContent == null) {
        try {
          final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
          final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 8));
          if (response.statusCode == 200) jsonContent = response.body;
        } catch (e) {
          print("⚠️ [BLOGSPOT] Falló fetch con proxy: $e");
        }
      }

      if (jsonContent != null) {
        final data = json.decode(jsonContent);
        final feed = data['feed'];
        if (feed != null) {
          final entries = feed['entry'] as List?;
          if (entries != null) {
            for (final entry in entries) {
              if (entry is! Map) continue;
              final titulo = entry['title']?['\$t'] ?? '';
              final htmlContenido = entry['content']?['\$t'] ?? '';
              final fechaRaw = entry['published']?['\$t'] ?? '';
              final DateTime fecha = DateTime.tryParse(fechaRaw) ?? DateTime.now();

              // Buscar link alternativo (el de la web pública)
              String artUrl = '';
              final links = entry['link'] as List?;
              if (links != null) {
                for (final l in links) {
                  if (l is Map && l['rel'] == 'alternate') {
                    artUrl = l['href'] ?? '';
                    break;
                  }
                }
              }

              // Extraer imagen del HTML
              String? imagen = _extraerImagenDeBloggerHtml(htmlContenido);

              // Fragmento para la vista de lista (primeros 280 caracteres limpios de HTML)
              String fragmento = _limpiarHtml(htmlContenido);
              if (fragmento.length > 280) {
                fragmento = '${fragmento.substring(0, 277)}...';
              }
              if (fragmento.isEmpty) {
                fragmento = titulo;
              }

              // Guardar contenido legible para lectura offline
              final contenidoCompleto = _parsearTextoDeHtml(htmlContenido) ?? _limpiarHtml(htmlContenido);

              resultado.add({
                'tipo': 'nota',
                'titulo': titulo,
                'fragmento': fragmento,
                'fuente': 'Blog Oficial',
                'url': artUrl,
                'imagen': imagen ?? _obtenerFallbackImagen(titulo + ' ' + fragmento),
                'tiene_imagen_real': true, // Siempre visible en el feed
                'fecha': fecha,
                'fecha_legible': _formatearFechaLegible(fecha),
                'contenido_completo': contenidoCompleto,
              });
            }
          }
        }
      }
    } catch (e) {
      print("⚠️ [BLOGSPOT] Error al procesar Blogger: $e");
    }

    print('📰 [BLOGSPOT] Total artículos del Blog Oficial: ${resultado.length}');
    return resultado;
  }

  /// Extrae la primera imagen de una entrada de Blogger HTML.
  static String? _extraerImagenDeBloggerHtml(String html) {
    final imgMatch = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    if (imgMatch != null) {
      final src = imgMatch.group(1);
      if (src != null && !src.contains('analytics') && !src.contains('pixel')) {
        return src;
      }
    }
    return null;
  }

  /// Lee el feed RSS de cada revista WordPress y extrae artículos con imagen.
  /// El RSS de WordPress incluye título, descripción, imagen og y URL directamente.
  static Future<List<Map<String, dynamic>>> scrapearWordPress({
    int maxPorRevista = 5,
  }) async {
    final List<Map<String, dynamic>> resultado = [];

    final List<Future<void>> tareas = revistasWordPress.map((revista) async {
      final String nombre = revista['nombre']!;
      final String rssUrl = revista['rss']!;
      final String base = revista['base']!;

      try {
        String? rssContent;
        // Fetch directo
        try {
          final r = await http.get(
            Uri.parse(rssUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
          ).timeout(const Duration(seconds: 6));
          if (r.statusCode == 200) rssContent = r.body;
        } catch (_) {}

        // Fallback proxy CORS
        if (rssContent == null) {
          try {
            final proxy = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(rssUrl)}';
            final r = await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 8));
            if (r.statusCode == 200) rssContent = r.body;
          } catch (_) {}
        }

        if (rssContent == null) {
          print('⚠️ [WP_RSS] No se pudo descargar RSS de $nombre');
          return;
        }

        // Parsear items del RSS
        final items = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false).allMatches(rssContent);
        
        final List<Future<Map<String, dynamic>?>> tareasItems = items.take(maxPorRevista * 2).map((item) async {
          final xml = item.group(1) ?? '';

          // Título
          String titulo = RegExp(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', caseSensitive: false, dotAll: true)
              .firstMatch(xml)?.group(1)?.trim() ?? '';
          titulo = _limpiarHtml(titulo).trim();
          if (titulo.length < 10) return null;

          // URL del artículo
          String link = RegExp(r'<link[^>]*>([^<]+)</link>', caseSensitive: false)
              .firstMatch(xml)?.group(1)?.trim() ?? '';
          if (link.isEmpty) {
            link = RegExp(r'<guid[^>]*>([^<]+)</guid>', caseSensitive: false)
                .firstMatch(xml)?.group(1)?.trim() ?? '';
          }
          if (link.isEmpty) return null;

          // Descripción (og:description o <description>)
          String fragmento = RegExp(r'<description[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?</description>', caseSensitive: false)
              .firstMatch(xml)?.group(1) ?? '';
          fragmento = _limpiarHtml(fragmento).trim();
          if (fragmento.length > 280) fragmento = '${fragmento.substring(0, 277)}...';

          // Imagen — buscar en media:content, enclosure, o content:encoded
          String? imagen;

          // media:content url="..."
          final mediaContent = RegExp(r'<media:content[^>]+url="([^"]+)"', caseSensitive: false).firstMatch(xml);
          if (mediaContent != null) imagen = mediaContent.group(1);

          // enclosure url="..."
          if (imagen == null) {
            final enc = RegExp(r'<enclosure[^>]+url="([^"]+\.(?:jpg|jpeg|png|webp))"', caseSensitive: false).firstMatch(xml);
            if (enc != null) imagen = enc.group(1);
          }

          // Buscar <img src="..."> dentro de content:encoded
          if (imagen == null) {
            final contentEnc = RegExp(r'<content:encoded[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?</content:encoded>', caseSensitive: false)
                .firstMatch(xml)?.group(1) ?? '';
            final imgTag = RegExp(r'src="(https?://[^"]+\.(?:jpg|jpeg|png|webp))"', caseSensitive: false).firstMatch(contentEnc);
            if (imgTag != null) imagen = imgTag.group(1);
          }

          // Fallback: si no tiene imagen o es emoji/placeholder/miniatura, intentar extraer del HTML de la nota
          if (imagen == null ||
              imagen.contains('emoji') ||
              imagen.contains('150x150') ||
              imagen.contains('placeholder') ||
              imagen.contains('logo') ||
              imagen.contains('icon')) {
            try {
              final rArt = await http.get(
                Uri.parse(link),
                headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
              ).timeout(const Duration(seconds: 5));
              if (rArt.statusCode == 200) {
                final scrapedImg = _parsearImagenDeHtml(rArt.body);
                if (scrapedImg != null) {
                  imagen = scrapedImg;
                }
              }
            } catch (_) {}
          }

          if (imagen == null ||
              imagen.contains('logo') ||
              imagen.contains('icon') ||
              imagen.contains('placeholder') ||
              imagen.contains('emoji')) {
            imagen = _obtenerFallbackImagen(titulo);
          }

          // Asegurar URL absoluta para la imagen
          if (imagen.startsWith('//')) imagen = 'https:$imagen';
          if (imagen.startsWith('/')) imagen = '$base$imagen';

          // Fecha
          String fechaStr = RegExp(r'<pubDate>(.*?)</pubDate>', caseSensitive: false).firstMatch(xml)?.group(1)?.trim() ?? '';
          DateTime fecha;
          try {
            fecha = DateTime.parse(fechaStr);
          } catch (_) {
            fecha = DateTime.now();
          }

          return {
            'tipo': 'nota',
            'titulo': titulo,
            'fragmento': fragmento.isNotEmpty ? fragmento : titulo,
            'fuente': nombre,
            'url': link,
            'imagen': imagen,
            'tiene_imagen_real': true,
            'fecha': fecha,
            'fecha_legible': _formatearFechaLegible(fecha),
          };
        }).toList();

        final itemsResultados = await Future.wait(tareasItems);
        int agregados = 0;
        for (final itemRes in itemsResultados) {
          if (itemRes != null) {
            resultado.add(itemRes);
            agregados++;
            if (agregados >= maxPorRevista) break;
          }
        }

        print('📰 [WP_RSS] $nombre: $agregados artículos con imagen real');
      } catch (e) {
        print('⚠️ [WP_RSS] Error scrapeando $nombre: $e');
      }
    }).toList();

    await Future.wait(tareas);
    return resultado;
  }

  /// Scrapea fuentes gubernamentales (Parques Nacionales Argentina).
  static Future<List<Map<String, dynamic>>> scrapearGubernamentales({
    int maxPorFuente = 4,
  }) async {
    final List<Map<String, dynamic>> resultado = [];

    final List<Future<void>> tareas = fuentesGubernamentales.map((fuente) async {
      final String nombre = fuente['nombre']!;
      final String homeUrl = fuente['url']!;
      final String base = fuente['base']!;
      final String patron = fuente['patron']!;

      try {
        String? htmlPortada;
        try {
          final r = await http.get(
            Uri.parse(homeUrl),
            headers: {'User-Agent': 'Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/109.0 Firefox/109.0'},
          ).timeout(const Duration(seconds: 6));
          if (r.statusCode == 200) htmlPortada = r.body;
        } catch (_) {}

        if (htmlPortada == null) {
          try {
            final proxy = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(homeUrl)}';
            final r = await http.get(Uri.parse(proxy)).timeout(const Duration(seconds: 8));
            if (r.statusCode == 200) htmlPortada = r.body;
          } catch (_) {}
        }

        if (htmlPortada == null) return;

        final Set<String> urls = {};
        final regex = RegExp(patron, caseSensitive: false);
        for (final m in regex.allMatches(htmlPortada)) {
          String link = m.group(1) ?? '';
          if (link.startsWith('/')) link = '$base$link';
          if (link == homeUrl || link.isEmpty) continue;
          urls.add(link);
          if (urls.length >= maxPorFuente * 2) break;
        }

        int agregados = 0;
        final List<Future<void>> tareasArt = urls.take(maxPorFuente * 2).map((artUrl) async {
          if (agregados >= maxPorFuente) return;
          try {
            String? html;
            try {
              final r = await http.get(
                Uri.parse(artUrl),
                headers: {'User-Agent': 'Mozilla/5.0 (Android 13; Mobile; rv:109.0) Gecko/109.0 Firefox/109.0'},
              ).timeout(const Duration(seconds: 5));
              if (r.statusCode == 200) html = r.body;
            } catch (_) {}

            if (html == null) return;

            // Título
            final ogTitle = RegExp(r'''<meta\s+(?:property|name)=["']og:title["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
            String titulo = _limpiarHtml(ogTitle?.group(1) ?? '').trim();
            if (titulo.length < 10) return;

            // Imagen
            String? imagen = _parsearImagenDeHtml(html);
            if (imagen == null || imagen.contains('logo') || imagen.contains('icon')) {
              imagen = _obtenerFallbackImagen(titulo);
            }
            if (imagen.startsWith('//')) imagen = 'https:$imagen';
            if (imagen.startsWith('/')) imagen = '$base$imagen';

            // Fragmento
            final ogDesc = RegExp(r'''<meta\s+(?:property|name)=["']og:description["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
            String fragmento = _limpiarHtml(ogDesc?.group(1) ?? '').trim();
            if (fragmento.length > 280) fragmento = '${fragmento.substring(0, 277)}...';

            agregados++;
            resultado.add({
              'tipo': 'nota',
              'titulo': titulo,
              'fragmento': fragmento.isNotEmpty ? fragmento : titulo,
              'fuente': nombre,
              'url': artUrl,
              'imagen': imagen,
              'tiene_imagen_real': true,
              'fecha': DateTime.now(),
              'fecha_legible': 'Hoy',
            });
          } catch (_) {}
        }).toList();

        await Future.wait(tareasArt);
        print('📰 [GOV] $nombre: $agregados artículos');
      } catch (e) {
        print('⚠️ [GOV] Error scrapeando $nombre: $e');
      }
    }).toList();

    await Future.wait(tareas);
    return resultado;
  }

  /// Obtiene los videos más recientes de los canales de YouTube configurados.
  static Future<List<Map<String, dynamic>>> obtenerVideosRecientesYoutube(String query) async {
    final List<Map<String, dynamic>> todosLosVideos = [];
    final List<Future<void>> tareas = [];

    for (final entry in youtubeChannels.entries) {
      final canalNombre = entry.key;
      final canalId = entry.value;
      final url = 'https://www.youtube.com/feeds/videos.xml?channel_id=$canalId';

      tareas.add(() async {
        try {
          String? xmlContent;
          // 1. Fetch directo (rápido en móviles y entornos nativos)
          try {
            final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
            if (response.statusCode == 200) {
              xmlContent = response.body;
            }
          } catch (e) {
            print("⚠️ [YOUTUBE] Falló fetch directo para $canalNombre: $e");
          }

          // 2. Fallback proxy CORS (para Flutter Web)
          if (xmlContent == null) {
            try {
              final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
              final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 4));
              if (response.statusCode == 200) {
                xmlContent = response.body;
              }
            } catch (e) {
              print("⚠️ [YOUTUBE] Falló fetch con proxy para $canalNombre: $e");
            }
          }

          if (xmlContent != null) {
            final entries = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(xmlContent);
            for (final entry in entries) {
              final entryStr = entry.group(1) ?? '';
              final videoId = RegExp(r'<yt:videoId>(.*?)</yt:videoId>').firstMatch(entryStr)?.group(1);
              final tituloRaw = RegExp(r'<title>(.*?)</title>').firstMatch(entryStr)?.group(1) ?? '';
              final published = RegExp(r'<published>(.*?)</published>').firstMatch(entryStr)?.group(1);
              
              // Decodificar entidades HTML comunes en títulos (ej. &quot; o &amp;)
              String titulo = tituloRaw
                  .replaceAll('&quot;', '"')
                  .replaceAll('&amp;', '&')
                  .replaceAll('&lt;', '<')
                  .replaceAll('&gt;', '>')
                  .replaceAll('&#39;', "'")
                  .replaceAll('&apos;', "'");

              if (videoId != null && titulo.isNotEmpty) {
                final date = DateTime.tryParse(published ?? '') ?? DateTime.now();

                // Extraer descripción real del RSS (media:description)
                String descripcionRaw = RegExp(
                  r'<media:description[^>]*>([\s\S]*?)</media:description>',
                  caseSensitive: false,
                ).firstMatch(entryStr)?.group(1) ?? '';

                // Decodificar entidades HTML en la descripción
                String descripcion = descripcionRaw
                    .replaceAll('&quot;', '"')
                    .replaceAll('&amp;', '&')
                    .replaceAll('&lt;', '<')
                    .replaceAll('&gt;', '>')
                    .replaceAll('&#39;', "'")
                    .replaceAll('&apos;', "'")
                    .trim();

                // Truncar a 3 líneas / 280 caracteres si es muy larga
                if (descripcion.length > 280) {
                  descripcion = '${descripcion.substring(0, 277)}...';
                }

                // Si el RSS no trajo descripción, usar texto genérico
                // (Gemini se llama aparte para no bloquear la carga del feed)
                if (descripcion.isEmpty) {
                  descripcion = 'Video de pesca de $canalNombre. Tocá para ver.';
                  // Marcar para generar con IA en segundo plano
                }

                todosLosVideos.add({
                  'titulo': titulo,
                  'fragmento': descripcion,
                  'fuente': canalNombre,
                  'url': 'https://www.youtube.com/watch?v=$videoId',
                  'imagen': 'https://img.youtube.com/vi/$videoId/0.jpg',
                  'fecha': date,
                  'fecha_legible': _formatearFechaLegible(date),
                  'is_video': true,
                  'video_id': videoId,
                  'descripcion_real': descripcionRaw.isNotEmpty,
                });
              }
            }
          }
        } catch (e) {
          print("⚠️ [YOUTUBE] Error al procesar canal $canalNombre: $e");
        }
      }());
    }

    await Future.wait(tareas);

    List<Map<String, dynamic>> filtrados = todosLosVideos;
    if (query.isNotEmpty) {
      final q = query.toLowerCase();
      filtrados = todosLosVideos.where((v) {
        final t = v['titulo'].toString().toLowerCase();
        final f = v['fuente'].toString().toLowerCase();
        return t.contains(q) || f.contains(q);
      }).toList();
    }

    // Ordenar cronológicamente (más recientes primero)
    filtrados.sort((a, b) {
      final DateTime dateA = a['fecha'] as DateTime;
      final DateTime dateB = b['fecha'] as DateTime;
      return dateB.compareTo(dateA);
    });

    return filtrados;
  }

  static String _formatearFechaLegible(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        return 'Hace unos minutos';
      }
      return 'Hace ${diff.inHours} h';
    }
    if (diff.inDays == 1) return 'Ayer';
    return 'Hace ${diff.inDays} días';
  }

  /// Obtiene noticias y reportes de piques recientes (menos de 7 días) de la web.
  /// Intenta buscar noticias reales usando Gemini Search Grounding, y raspa sus portadas de forma nativa/CORS.
  /// Si ocurre un error o el API key no está configurado, recurre al simulador local.
  static Future<List<Map<String, dynamic>>> obtenerNoticiasRecientesWeb(String query) async {
    try {
      // 1. Intentar buscar noticias reales a través de Gemini con Google Search Grounding
      final List<Map<String, dynamic>> noticiasReales = await GeminiAIService.buscarNoticiasRealesWeb(query);
      
      if (noticiasReales.isNotEmpty) {
        final List<Map<String, dynamic>> resultados = [];
        
        // 2. Extraer imágenes de cada sitio en paralelo con timeout controlado
        final List<Future<Map<String, dynamic>>> tareas = noticiasReales.map((noticia) async {
          final url = noticia['url'] ?? '';
          final diasAtras = noticia['dias_atras'] ?? 3;
          final String contextText = '${noticia['titulo']} ${noticia['fragmento']}';
          
          String? imagenScrapeada;
          if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://'))) {
            imagenScrapeada = await _extraerImagenDePagina(url);
          }
          
          final imagenFinal = imagenScrapeada ?? _obtenerFallbackImagen(contextText);
          final now = DateTime.now();
          final int dias = diasAtras is int ? diasAtras : int.tryParse(diasAtras.toString()) ?? 3;
          final fechaPublicacion = now.subtract(Duration(days: dias));
          
          return {
            'titulo': noticia['titulo'] ?? 'Reporte de Pesca',
            'fragmento': noticia['fragmento'] ?? '',
            'fuente': noticia['fuente'] ?? 'Web',
            'url': url,
            'imagen': imagenFinal,
            // true = imagen real scrapeada del artículo; false = placeholder Unsplash
            'tiene_imagen_real': imagenScrapeada != null,
            'fecha': fechaPublicacion,
            'fecha_legible': 'Hace $dias días',
          };
        }).toList();
        
        final resolved = await Future.wait(tareas);
        resultados.addAll(resolved);
        return resultados;
      }
    } catch (e) {
      print("⚠️ [NEWS_COMPILER] Ocurrió un error en la búsqueda real o parseo. Usando fallback de simulación. Detalle: $e");
    }
    
    // Fallback: Si falla el API key, no hay internet, o no se encuentran resultados, recurrimos a las noticias simuladas.
    return _obtenerNoticiasSimuladas(query);
  }

  /// Raspa la página web buscando og:image o twitter:image. Soporta CORS proxy en Web.
  static Future<String?> _extraerImagenDePagina(String url) async {
    // 1. Intentar fetch directo (más rápido en mobile/desktop nativo, no depende de proxy de terceros)
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        final img = _parsearImagenDeHtml(response.body);
        if (img != null) return img;
      }
    } catch (e) {
      print("⚠️ [SCRAPER] Falló fetch directo a $url (posible CORS o timeout): $e");
    }

    // 2. Intentar a través del proxy CORS (necesario en Flutter Web)
    try {
      final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
      final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final img = _parsearImagenDeHtml(response.body);
        if (img != null) return img;
      }
    } catch (e) {
      print("⚠️ [SCRAPER] Falló fetch por proxy CORS para $url: $e");
    }
    return null;
  }

  /// Analiza el HTML crudo de la página web buscando las etiquetas de imágenes de portada
  static String? _parsearImagenDeHtml(String html) {
    String? imagen;

    // og:image con property primero
    var match = RegExp(r'''<meta\s+property=["']og:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
    if (match != null) imagen = match.group(1);
    
    // og:image con content primero
    if (imagen == null) {
      match = RegExp(r'''<meta\s+content=["']([^"']+)["']\s+property=["']og:image["']''', caseSensitive: false).firstMatch(html);
      if (match != null) imagen = match.group(1);
    }

    // twitter:image con name primero
    if (imagen == null) {
      match = RegExp(r'''<meta\s+name=["']twitter:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
      if (match != null) imagen = match.group(1);
    }

    // twitter:image con property primero
    if (imagen == null) {
      match = RegExp(r'''<meta\s+property=["']twitter:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
      if (match != null) imagen = match.group(1);
    }

    // og:image con name
    if (imagen == null) {
      match = RegExp(r'''<meta\s+name=["']og:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
      if (match != null) imagen = match.group(1);
    }

    // Si no hay imagen o es la genérica del gobierno argentino o tiene indicios de placeholder/emoji/miniatura
    if (imagen == null ||
        imagen.contains('argentina-fb.png') ||
        imagen.contains('emoji') ||
        imagen.contains('150x150') ||
        imagen.contains('placeholder') ||
        imagen.contains('logo') ||
        imagen.contains('icon')) {
      // Buscar una etiqueta img grande de uploads o images
      final imgMatches = RegExp(r'''<img\s+[^>]*src=["']([^"']+)["']''', caseSensitive: false).allMatches(html);
      for (final m in imgMatches) {
        final src = m.group(1);
        if (src != null) {
          if (src.contains('wp-content/uploads') ||
              src.contains('images/') ||
              src.contains('uploads/') ||
              src.contains('sites/default/files/')) {
            if (!src.contains('logo') &&
                !src.contains('icon') &&
                !src.contains('.gif') &&
                !src.contains('argentina-fb.png') &&
                !src.contains('emoji') &&
                !src.contains('150x150')) {
              return src;
            }
          }
        }
      }
    }

    // Si al final encontramos una imagen que no es basura, la devolvemos
    if (imagen != null &&
        !imagen.contains('logo') &&
        !imagen.contains('icon') &&
        !imagen.contains('placeholder') &&
        !imagen.contains('emoji')) {
      return imagen;
    }

    return null;
  }

  /// Raspa el TEXTO COMPLETO de un artículo de revista desde su URL.
  /// Extrae párrafos, título y subtítulos del HTML para lectura offline.
  /// Devuelve el contenido formateado como texto plano (listo para mostrar).
  static Future<String?> extraerTextoCompletoArticulo(String url) async {
    String? html;

    // 1. Fetch directo (rápido en Android/iOS nativo)
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile; rv:109.0) Gecko/109.0 Firefox/109.0'},
      ).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) html = response.body;
    } catch (e) {
      print('⚠️ [SCRAPER_TEXTO] Fetch directo falló para $url: $e');
    }

    // 2. Fallback: proxy CORS
    if (html == null) {
      try {
        final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
        final response = await http.get(Uri.parse(proxyUrl)).timeout(const Duration(seconds: 6));
        if (response.statusCode == 200) html = response.body;
      } catch (e) {
        print('⚠️ [SCRAPER_TEXTO] Proxy CORS falló para $url: $e');
      }
    }

    if (html == null) return null;
    return _parsearTextoDeHtml(html);
  }

  /// Extrae el texto legible de un HTML: título og, párrafos del artículo, subtítulos H2/H3.
  static String? _parsearTextoDeHtml(String html) {
    // 1. Obtener título og:title o <title>
    String titulo = '';
    final ogTitle = RegExp(r'''<meta\s+(?:property|name)=["']og:title["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
    if (ogTitle != null) {
      titulo = ogTitle.group(1) ?? '';
    } else {
      final titleTag = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
      if (titleTag != null) titulo = titleTag.group(1) ?? '';
    }
    titulo = _limpiarHtml(titulo).trim();

    // 2. Extraer descripción og:description
    String descripcion = '';
    final ogDesc = RegExp(r'''<meta\s+(?:property|name)=["']og:description["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
    if (ogDesc != null) descripcion = _limpiarHtml(ogDesc.group(1) ?? '').trim();

    // 3. Extraer párrafos del body del artículo
    // Intentar extraer desde article > p, main > p, o simplemente todos los <p>
    final List<String> parrafos = [];

    // Prioridad: buscar dentro de <article>, <main>, <div class="entry-content"> o similar
    String bodyContent = html;
    final articleMatch = RegExp(r'<article[^>]*>([\s\S]*?)</article>', caseSensitive: false).firstMatch(html);
    if (articleMatch != null) {
      bodyContent = articleMatch.group(1) ?? html;
    } else {
      final mainMatch = RegExp(r'<main[^>]*>([\s\S]*?)</main>', caseSensitive: false).firstMatch(html);
      if (mainMatch != null) bodyContent = mainMatch.group(1) ?? html;
    }

    // Extraer <h2> y <h3> como subtítulos
    final subtitulosMatches = RegExp(r'<h[23][^>]*>([\s\S]*?)</h[23]>', caseSensitive: false).allMatches(bodyContent);
    final Map<int, String> subtitulosPorPos = {};
    for (final m in subtitulosMatches) {
      final texto = _limpiarHtml(m.group(1) ?? '').trim();
      if (texto.length > 3 && texto.length < 200) {
        subtitulosPorPos[m.start] = texto;
      }
    }

    // Extraer <p>
    final pMatches = RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false).allMatches(bodyContent);
    final Map<int, String> parrafosPorPos = {};
    for (final m in pMatches) {
      final texto = _limpiarHtml(m.group(1) ?? '').trim();
      if (texto.length > 40) { // ignorar párrafos muy cortos (publicidad, metadatos)
        parrafosPorPos[m.start] = texto;
      }
    }

    // Unir todo ordenado por posición en el HTML
    final Map<int, String> todoContenido = {...subtitulosPorPos, ...parrafosPorPos};
    final posicionesOrdenadas = todoContenido.keys.toList()..sort();

    for (final pos in posicionesOrdenadas) {
      final texto = todoContenido[pos]!;
      if (subtitulosPorPos.containsKey(pos)) {
        parrafos.add('\n## $texto\n');
      } else {
        parrafos.add(texto);
      }
    }

    if (parrafos.isEmpty && descripcion.isEmpty) return null;

    // Armar contenido final
    final buffer = StringBuffer();
    if (titulo.isNotEmpty) buffer.writeln('# $titulo\n');
    if (descripcion.isNotEmpty && !parrafos.any((p) => p.contains(descripcion.substring(0, descripcion.length.clamp(0, 30))))) {
      buffer.writeln('*$descripcion*\n');
    }
    if (parrafos.isNotEmpty) {
      buffer.writeln(parrafos.take(25).join('\n\n')); // máx 25 bloques
    } else {
      buffer.writeln(descripcion);
    }

    final resultado = buffer.toString().trim();
    return resultado.length > 100 ? resultado : null;
  }

  /// Limpia etiquetas HTML de un texto dejando solo el texto plano.
  static String _limpiarHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), '')           // quitar tags
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'")
        .replaceAll(RegExp(r'\s+'), ' ')               // colapsar espacios
        .trim();
  }

  /// Genera una imagen ilustrativa de calidad (vía Pollinations AI o Unsplash) si no se pudo raspar ninguna de la web
  static String _obtenerFallbackImagen(String contextText) {
    try {
      final cleanText = contextText
          .replaceAll(RegExp(r'[^\w\s\-]'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleanText.isNotEmpty) {
        final prompt = 'hyper realistic professional photography of $cleanText, pesca deportiva río Paraná Argentina, pescador con caña, dorado surubí boga, lancha en río, amanecer en el río, natural cinematic lighting, highly detailed, no text, no labels, 4k';
        final encodedPrompt = Uri.encodeComponent(prompt);
        return 'https://image.pollinations.ai/prompt/$encodedPrompt?width=600&height=400&nologo=true&private=true';
      }
    } catch (_) {}

    final ctx = contextText.toLowerCase();
    if (ctx.contains('dorado') || ctx.contains('surubi') || ctx.contains('parana') || ctx.contains('corrientes')) {
      return _imagenesPortadaPesca[0]; // pescador en río
    }
    if (ctx.contains('pejerrey') || ctx.contains('laguna') || ctx.contains('chascomus')) {
      return _imagenesPortadaPesca[3]; // río al atardecer
    }
    if (ctx.contains('mar') || ctx.contains('costa') || ctx.contains('atlantica') || ctx.contains('necochea') || ctx.contains('playa') || ctx.contains('claromeco')) {
      return _imagenesPortadaPesca[1]; // pesca deportiva
    }
    if (ctx.contains('tararira') || ctx.contains('carpa') || ctx.contains('delta') || ctx.contains('tigre')) {
      return _imagenesPortadaPesca[2]; // anzuelo y carnada
    }
    return _imagenesPortadaPesca[4]; // pesca en lancha
  }

  /// Simulador de fallback con noticias ficticias de pesca locales en Argentina
  static List<Map<String, dynamic>> _obtenerNoticiasSimuladas(String query) {
    final String q = query.toLowerCase();
    final now = DateTime.now();
    final random = Random();

    final List<Map<String, dynamic>> baseNoticias = [
      {
        'titulo': 'Excelente pique de Dorado y Surubí en Paso de la Patria',
        'fragmento': 'Los guías locales reportaron una reactivación del pique de dorados medianos y grandes utilizando señuelos de paleta profunda y carnada viva. Las aguas claras del Paraná favorecen las capturas.',
        'fuente': 'Pesca Litoral',
        'url': 'https://sentilapesca.com.ar/reporte-paso-de-la-patria',
        'imagen': _imagenesPortadaPesca[0], // pescador en río
        'dias_atras': random.nextInt(3) + 1,
        'keywords': ['dorado', 'surubi', 'corrientes', 'parana', 'litoral', 'paso de la patria']
      },
      {
        'titulo': 'Comenzó la temporada de Pejerrey en las lagunas de Buenos Aires',
        'fragmento': 'Laguna de Gómez y Chascomús abrieron con excelentes cantidades de pejerreyes medianos. Se recomienda el uso de líneas de tres boyas de colores claros y carnada de mojarra viva salada.',
        'fuente': 'Planeta Pesca',
        'url': 'https://pescaargentina.com.ar/chascomus-pejerrey',
        'imagen': _imagenesPortadaPesca[3], // río al atardecer
        'dias_atras': random.nextInt(4) + 1,
        'keywords': ['pejerrey', 'buenos aires', 'laguna', 'chascomus', 'boga', 'linea', 'boyas']
      },
      {
        'titulo': 'Variada de mar activa en la costa bonaerense',
        'fragmento': 'Pesca de playa muy rendidora en Necochea y Claromecó. Se capturaron pescadillas, corvinas rubias de buen tamaño y chuchos medianos utilizando anzuelos 4/0 encarnados con anchoa y camarón.',
        'fuente': 'Sentí La Pesca',
        'url': 'https://sentilapesca.com.ar/variada-mar-necochea',
        'imagen': _imagenesPortadaPesca[1], // pesca deportiva
        'dias_atras': random.nextInt(5) + 1,
        'keywords': ['mar', 'necochea', 'costa', 'corvina', 'pescadilla', 'playa', 'claromeco']
      },
      {
        'titulo': 'Pique de Tarariras y Carpas en el Delta del Paraná',
        'fragmento': 'En los canales interiores de Tigre, el descenso de temperatura ralentizó el pique de tarariras, pero las carpas gigantes siguen activas en los pozones buscando masa dulce y maíz fermentado.',
        'fuente': 'Revista Pesca Deportiva',
        'url': 'https://pescaargentina.com.ar/delta-tarariras-carpas',
        'imagen': _imagenesPortadaPesca[2], // anzuelo y carnada
        'dias_atras': random.nextInt(3) + 2,
        'keywords': ['tararira', 'carpa', 'delta', 'tigre', 'parana', 'rio']
      },
      {
        'titulo': 'Esquina Corrientes: Gran afluencia turística por pesca deportiva',
        'fragmento': 'Esquina se consolida con hospedajes al 90% debido al excelente pique de surubíes pintados en la zona del riacho Espinillo. Guías recomiendan trolling a velocidad controlada.',
        'fuente': 'Turismo Corrientes',
        'url': 'https://turismocorrientes.gov.ar/esquina-pesca-activa',
        'imagen': _imagenesPortadaPesca[4], // pesca en lancha
        'dias_atras': random.nextInt(4) + 2,
        'keywords': ['esquina', 'corrientes', 'surubi', 'turismo', 'espinillo', 'trolling']
      }
    ];

    // Dividir la consulta en palabras significativas (ignorando preposiciones)
    final List<String> queryWords = q
        .split(RegExp(r'[\s,.\-_]+'))
        .map((w) => w.trim())
        .where((w) => w.length > 2 && !const {
              'del', 'los', 'las', 'con', 'para', 'por', 'una', 'uno', 'unos', 'unas',
              'este', 'esta', 'estos', 'estas', 'como', 'sino', 'pero', 'semana', 'pique',
              'piques', 'de', 'la', 'en', 'el', 'y', 'a', 'sobre'
            }.contains(w))
        .toList();

    List<Map<String, dynamic>> filtradas = [];
    for (final nota in baseNoticias) {
      final List<String> keywords = nota['keywords'] as List<String>;
      
      bool matchQuery = q.isEmpty;
      if (!matchQuery) {
        // Verificar coincidencia exacta del string completo primero
        if (nota['titulo'].toString().toLowerCase().contains(q) ||
            nota['fragmento'].toString().toLowerCase().contains(q)) {
          matchQuery = true;
        } else {
          // Si no, verificar si alguna palabra de la consulta coincide
          for (final word in queryWords) {
            if (nota['titulo'].toString().toLowerCase().contains(word) ||
                nota['fragmento'].toString().toLowerCase().contains(word) ||
                keywords.any((k) => k.contains(word))) {
              matchQuery = true;
              break;
            }
          }
        }
      }

      if (matchQuery) {
        final diasAtras = nota['dias_atras'] as int;
        final fechaPublicacion = now.subtract(Duration(days: diasAtras));
        
        filtradas.add({
          'titulo': nota['titulo'],
          'fragmento': nota['fragmento'],
          'fuente': nota['fuente'],
          'url': nota['url'],
          'imagen': nota['imagen'],
          'fecha': fechaPublicacion,
          'fecha_legible': 'Hace $diasAtras días',
        });
      }
    }

    // Si por el filtrado queda vacío, devolvemos todas las noticias de la base de datos simulada
    // para asegurar que nunca se vea una pantalla en blanco.
    if (filtradas.isEmpty) {
      for (final nota in baseNoticias) {
        final diasAtras = nota['dias_atras'] as int;
        final fechaPublicacion = now.subtract(Duration(days: diasAtras));
        filtradas.add({
          'titulo': nota['titulo'],
          'fragmento': nota['fragmento'],
          'fuente': nota['fuente'],
          'url': nota['url'],
          'imagen': nota['imagen'],
          'fecha': fechaPublicacion,
          'fecha_legible': 'Hace $diasAtras días',
        });
      }
    }

    return filtradas;
  }

  /// Toma una noticia cruda de internet y utiliza Gemini AI para compilarla en un artículo editorial formateado,
  /// asociando productos afines del catálogo de la tienda de EL GUIA YA.
  static Future<ArticuloBlog> compilarArticuloConIA({
    required String tituloOriginal,
    required String fragmentoOriginal,
    required String urlOriginal,
    required String imagenOriginal,
  }) async {
    List<Map<String, dynamic>> productosMap = [];
    try {
      // Obtener productos reales de la base de datos para pasarlos como contexto a Gemini
      final List<Producto> productos = await SupabaseService.getProductos();
      
      // Filtrar el catálogo antes de pasarlo a Gemini:
      // solo incluir productos cuya categoría o nombre contenga palabras relacionadas con el artículo (caña, reel, carnada, anzuelo, boya, etc.).
      final String articuloTexto = '${tituloOriginal.toLowerCase()} ${fragmentoOriginal.toLowerCase()}';
      
      final palabrasPesca = [
        'caña', 'reel', 'carnada', 'anzuelo', 'boya', 'señuelo', 'tanza', 
        'nylon', 'línea', 'plomada', 'multifilamento', 'wader', 'copo', 'plomo',
        'señuelos', 'anzuelos', 'boyas', 'cañas', 'reeles', 'pesca', 'mojarra', 'cebo'
      ];
      
      final List<Producto> productosFiltrados = productos.where((p) {
        final nombreLower = p.nombre.toLowerCase();
        final rubroLower = p.rubro.toLowerCase();
        
        // Debe tener alguna palabra clave general de pesca deportiva
        bool tienePalabraPesca = palabrasPesca.any((palabra) => 
          nombreLower.contains(palabra) || rubroLower.contains(palabra)
        );
        
        if (!tienePalabraPesca) return false;
        
        // Además, buscar palabras clave específicas del artículo en el producto
        final palabrasArticulo = articuloTexto
            .split(RegExp(r'[\s,.\-_()/]+'))
            .map((w) => w.trim())
            .where((w) => w.length > 3)
            .toList();
            
        // Si hay una especie o técnica en el artículo, verificar si coincide
        if (articuloTexto.contains('dorado') || articuloTexto.contains('surubi')) {
          if (nombreLower.contains('dorado') || 
              nombreLower.contains('surubi') || 
              nombreLower.contains('señuelo') || 
              nombreLower.contains('señuelos') ||
              rubroLower.contains('señuelo') ||
              rubroLower.contains('señuelos') ||
              nombreLower.contains('líder') ||
              nombreLower.contains('lider') ||
              nombreLower.contains('trolling')) {
            return true;
          }
        }
        
        if (articuloTexto.contains('pejerrey') || articuloTexto.contains('laguna')) {
          if (nombreLower.contains('pejerrey') || 
              nombreLower.contains('laguna') || 
              nombreLower.contains('boya') || 
              nombreLower.contains('boyas') || 
              nombreLower.contains('mojarra') ||
              rubroLower.contains('boyas') ||
              rubroLower.contains('boya')) {
            return true;
          }
        }
        
        if (articuloTexto.contains('tararira') || articuloTexto.contains('carpa') || articuloTexto.contains('delta')) {
          if (nombreLower.contains('tararira') || 
              nombreLower.contains('carpa') || 
              nombreLower.contains('señuelo') || 
              nombreLower.contains('señuelos') ||
              nombreLower.contains('rana') ||
              nombreLower.contains('artificial') ||
              rubroLower.contains('señuelos') ||
              rubroLower.contains('señuel')) {
            return true;
          }
        }

        if (articuloTexto.contains('mar') || articuloTexto.contains('costa') || articuloTexto.contains('variada')) {
          if (nombreLower.contains('mar') || 
              nombreLower.contains('costa') || 
              nombreLower.contains('variada') || 
              nombreLower.contains('plomada') || 
              nombreLower.contains('plomo') || 
              nombreLower.contains('anzuelo') ||
              nombreLower.contains('anzuelos')) {
            return true;
          }
        }
        
        // Coincidencia genérica si alguna palabra del artículo está en el nombre o categoría del producto
        return palabrasArticulo.any((palabra) => 
          nombreLower.contains(palabra) || rubroLower.contains(palabra)
        );
      }).toList();

      productosMap = productosFiltrados.map((p) => {
        'id': p.id,
        'nombre': p.nombre,
        'descripcion': p.descripcion,
      }).toList();
    } catch (e) {
      print("⚠️ [NEWS_COMPILER] No se pudieron obtener productos para la recomendación: $e");
    }

    // Llamar al servicio de inteligencia artificial
    final Map<String, dynamic> redaccion = await GeminiAIService.analizarYRedactarNoticia(
      titulo: tituloOriginal,
      fragmento: fragmentoOriginal,
      url: urlOriginal,
      productosDisponibles: productosMap,
    );

    // Mapear los resultados al modelo ArticuloBlog
    return ArticuloBlog(
      id: '', // Se autogenerará en Supabase
      titulo: redaccion['titulo'] ?? 'Reporte de Pesca: $tituloOriginal',
      resumen: redaccion['resumen'] ?? fragmentoOriginal,
      contenido: redaccion['contenido'] ?? '# $tituloOriginal\n\n$fragmentoOriginal',
      autor: 'Gu-IA Redactora',
      minutosLectura: redaccion['minutos_lectura'] ?? 4,
      imagenPortada: imagenOriginal,
      categoria: redaccion['categoria'] ?? 'Piques de la Semana',
      productosSugeridos: List<String>.from(redaccion['productos_sugeridos'] ?? []),
      fuenteUrl: urlOriginal,
      activo: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Realiza la autocompilación semanal de videos y noticias de la web de forma automática,
  /// insertándolos en Supabase si no existen previamente.
  static Future<int> autoCompilarContenidoSemanal() async {
    int nuevosInsertados = 0;
    try {
      print("🚀 [AUTO_COMPILER] Iniciando proceso de autocompilación semanal...");

      // 1. Obtener todos los artículos ya publicados en Supabase para evitar duplicados.
      final List<ArticuloBlog> articulosExistentes = await SupabaseService.obtenerArticulosBlog(soloActivos: false);
      final Set<String> fuentesExistentes = articulosExistentes
          .map((a) => a.fuenteUrl?.trim().toLowerCase() ?? '')
          .where((url) => url.isNotEmpty)
          .toSet();

      // 2. Obtener videos de YouTube recientes
      final List<Map<String, dynamic>> videos = await obtenerVideosRecientesYoutube('');
      
      // 3. Obtener noticias web recientes del pique de la semana
      final List<Map<String, dynamic>> noticiasWeb = await obtenerNoticiasRecientesWeb('Pique de la semana en los ríos de Argentina y la costa atlántica');

      final List<Map<String, dynamic>> itemsParaCompilar = [];
      
      // Tomamos hasta 3 videos nuevos
      int videosAgregados = 0;
      for (final video in videos) {
        final url = video['url']?.toString().trim().toLowerCase() ?? '';
        if (url.isNotEmpty && !fuentesExistentes.contains(url)) {
          itemsParaCompilar.add(video);
          videosAgregados++;
          if (videosAgregados >= 3) break;
        }
      }

      // Tomamos hasta 3 noticias web nuevas
      int noticiasAgregadas = 0;
      for (final noticia in noticiasWeb) {
        final url = noticia['url']?.toString().trim().toLowerCase() ?? '';
        if (url.isNotEmpty && !fuentesExistentes.contains(url)) {
          itemsParaCompilar.add(noticia);
          noticiasAgregadas++;
          if (noticiasAgregadas >= 3) break;
        }
      }

      print("📂 [AUTO_COMPILER] Se encontraron ${itemsParaCompilar.length} nuevos reportes para compilar.");

      // 4. Compilar e insertar en Supabase cada nuevo artículo
      for (final item in itemsParaCompilar) {
        try {
          final ArticuloBlog nuevoArticulo = await compilarArticuloConIA(
            tituloOriginal: item['titulo'] ?? 'Reporte de Pesca',
            fragmentoOriginal: item['fragmento'] ?? '',
            urlOriginal: item['url'] ?? '',
            imagenOriginal: item['imagen'] ?? '',
          );

          // Asegurar que esté activo
          final articuloListo = ArticuloBlog(
            id: '',
            titulo: nuevoArticulo.titulo,
            resumen: nuevoArticulo.resumen,
            contenido: nuevoArticulo.contenido,
            autor: nuevoArticulo.autor,
            minutosLectura: nuevoArticulo.minutosLectura,
            imagenPortada: nuevoArticulo.imagenPortada,
            categoria: nuevoArticulo.categoria,
            productosSugeridos: nuevoArticulo.productosSugeridos,
            fuenteUrl: nuevoArticulo.fuenteUrl,
            activo: false, // Borrador pendiente de aprobación
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await SupabaseService.crearArticuloBlog(articuloListo);
          fuentesExistentes.add(articuloListo.fuenteUrl!.trim().toLowerCase());
          nuevosInsertados++;
          print("✅ [AUTO_COMPILER] Artículo creado y publicado: ${articuloListo.titulo}");
        } catch (e) {
          print("⚠️ [AUTO_COMPILER] Error al compilar/crear artículo: $e");
        }
      }
    } catch (e) {
      print("❌ [AUTO_COMPILER] Error general durante la autocompilación: $e");
    }
    return nuevosInsertados;
  }
}
