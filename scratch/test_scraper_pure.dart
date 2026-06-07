import 'package:http/http.dart' as http;
import 'dart:convert';

const List<Map<String, String>> revistasArgentinas = [
  {
    'nombre': 'Weekend',
    'url': 'https://weekend.perfil.com/',
    'base': 'https://weekend.perfil.com',
    'patron': r'href="(/noticias/[^"]+\.phtml)"',
  },
  {
    'nombre': 'Sentí la Pesca',
    'url': 'https://sentilapesca.com.ar/',
    'base': 'https://sentilapesca.com.ar',
    'patron': r'href="(https://sentilapesca\.com\.ar/[a-z0-9\-/]+)"',
  },
  {
    'nombre': 'Pesca Argentina',
    'url': 'https://www.pescaargentina.com.ar/',
    'base': 'https://www.pescaargentina.com.ar',
    'patron': r'href="(https://www\.pescaargentina\.com\.ar/[a-z0-9\-/]+)"',
  },
  {
    'nombre': 'AquaHunter',
    'url': 'https://www.aquahunter.com.ar/',
    'base': 'https://www.aquahunter.com.ar',
    'patron': r'href="(/[a-z0-9\-]+\.html)"',
  },
  {
    'nombre': 'Portal de Pesca',
    'url': 'https://www.portaldepesca.com/',
    'base': 'https://www.portaldepesca.com',
    'patron': r'href="(https://www\.portaldepesca\.com/[a-z0-9\-/]+)"',
  },
];

const List<Map<String, String>> revistasWordPress = [
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
];

const List<Map<String, String>> fuentesGubernamentales = [
  {
    'nombre': 'Parques Nacionales',
    'url': 'https://www.argentina.gob.ar/parquesnacionales',
    'base': 'https://www.argentina.gob.ar',
    'patron': r'href="(/parquesnacionales/[a-z0-9\-]+)"',
  },
];

void main() async {
  print('=== STARTING SCRAPER TEST (PURE DART) ===');
  
  for (final rev in revistasArgentinas) {
    print('\n--- HTML SCRAPING: ${rev['nombre']} ---');
    try {
      final res = await http.get(
        Uri.parse(rev['url']!),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
      ).timeout(Duration(seconds: 10));
      print('Portada Status: ${res.statusCode}');
      if (res.statusCode != 200) {
        print('Skipping due to status code.');
        continue;
      }
      
      final regex = RegExp(rev['patron']!, caseSensitive: false);
      final matches = regex.allMatches(res.body);
      print('Regex matches found: ${matches.length}');
      
      final Set<String> urls = {};
      for (final m in matches) {
        String link = m.group(1) ?? '';
        if (link.startsWith('/')) link = '${rev['base']}$link';
        urls.add(link);
        if (urls.length >= 3) break;
      }
      
      print('URLs to test: $urls');
      for (final url in urls) {
        try {
          final artRes = await http.get(
            Uri.parse(url),
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
          ).timeout(Duration(seconds: 5));
          print('  URL: $url -> Status: ${artRes.statusCode}');
          
          final image = _parsearImagenDeHtml(artRes.body);
          print('  Extracted Image: $image');
        } catch (e) {
          print('  Error fetching article $url: $e');
        }
      }
    } catch (e) {
      print('Error scraping HTML ${rev['nombre']}: $e');
    }
  }

  for (final rev in revistasWordPress) {
    print('\n--- WORDPRESS RSS: ${rev['nombre']} ---');
    try {
      final res = await http.get(
        Uri.parse(rev['rss']!),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
      ).timeout(Duration(seconds: 10));
      print('RSS Status: ${res.statusCode}');
      if (res.statusCode != 200) {
        print('Skipping WP RSS due to status.');
        continue;
      }

      final items = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false).allMatches(res.body);
      print('RSS Items found: ${items.length}');
      
      int count = 0;
      for (final item in items) {
        if (count >= 3) break;
        final xml = item.group(1) ?? '';
        
        final title = RegExp(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', caseSensitive: false, dotAll: true)
            .firstMatch(xml)?.group(1)?.trim() ?? '';
        
        final link = RegExp(r'<link[^>]*>([^<]+)</link>', caseSensitive: false).firstMatch(xml)?.group(1)?.trim() ?? '';
        
        String? imagen;
        final mediaContent = RegExp(r'<media:content[^>]+url="([^"]+)"', caseSensitive: false).firstMatch(xml);
        if (mediaContent != null) imagen = mediaContent.group(1);

        if (imagen == null) {
          final enc = RegExp(r'<enclosure[^>]+url="([^"]+\.(?:jpg|jpeg|png|webp))"', caseSensitive: false).firstMatch(xml);
          if (enc != null) imagen = enc.group(1);
        }

        if (imagen == null) {
          final contentEnc = RegExp(r'<content:encoded[^>]*>(?:<!\[CDATA\[)?([\s\S]*?)(?:\]\]>)?</content:encoded>', caseSensitive: false)
              .firstMatch(xml)?.group(1) ?? '';
          final imgTag = RegExp(r'src="(https?://[^"]+\.(?:jpg|jpeg|png|webp))"', caseSensitive: false).firstMatch(contentEnc);
          if (imgTag != null) imagen = imgTag.group(1);
        }

        print('  [$count] Title: $title');
        print('      Link: $link');
        print('      Image: $imagen');
        count++;
      }
    } catch (e) {
      print('Error WP RSS ${rev['nombre']}: $e');
    }
  }

  for (final source in fuentesGubernamentales) {
    print('\n--- GOB: ${source['nombre']} ---');
    try {
      final res = await http.get(
        Uri.parse(source['url']!),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
      ).timeout(Duration(seconds: 10));
      print('GOB Status: ${res.statusCode}');
      if (res.statusCode != 200) {
        continue;
      }
      
      final regex = RegExp(source['patron']!, caseSensitive: false);
      final matches = regex.allMatches(res.body);
      print('Regex matches found: ${matches.length}');
      
      final Set<String> urls = {};
      for (final m in matches) {
        String link = m.group(1) ?? '';
        if (link.startsWith('/')) link = '${source['base']}$link';
        urls.add(link);
        if (urls.length >= 3) break;
      }
      
      print('URLs to test: $urls');
      for (final url in urls) {
        try {
          final artRes = await http.get(
            Uri.parse(url),
            headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
          ).timeout(Duration(seconds: 5));
          print('  URL: $url -> Status: ${artRes.statusCode}');
          
          final image = _parsearImagenDeHtml(artRes.body);
          print('  Extracted Image: $image');
        } catch (e) {
          print('  Error fetching article $url: $e');
        }
      }
    } catch (e) {
      print('Error GOB ${source['nombre']}: $e');
    }
  }
}

String? _parsearImagenDeHtml(String html) {
  var match = RegExp(r'''<meta\s+property=["']og:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  if (match != null) return match.group(1);
  
  match = RegExp(r'''<meta\s+content=["']([^"']+)["']\s+property=["']og:image["']''', caseSensitive: false).firstMatch(html);
  if (match != null) return match.group(1);

  match = RegExp(r'''<meta\s+name=["']twitter:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  if (match != null) return match.group(1);

  match = RegExp(r'''<meta\s+property=["']twitter:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  if (match != null) return match.group(1);

  match = RegExp(r'''<meta\s+name=["']og:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  if (match != null) return match.group(1);

  final imgMatches = RegExp(r'''<img\s+[^>]*src=["']([^"']+)["']''', caseSensitive: false).allMatches(html);
  for (final m in imgMatches) {
    final src = m.group(1);
    if (src != null) {
      if (src.contains('wp-content/uploads') || src.contains('images/') || src.contains('uploads/')) {
        if (!src.contains('logo') && !src.contains('icon') && !src.contains('.gif')) {
          return src;
        }
      }
    }
  }
  return null;
}
