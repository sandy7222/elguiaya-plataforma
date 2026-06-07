import 'package:http/http.dart' as http;

const List<Map<String, String>> revistasArgentinas = [
  {
    'nombre': 'Weekend',
    'url': 'https://weekend.perfil.com/',
    'base': 'https://weekend.perfil.com',
    'patron': r'href="((?:https://weekend\.perfil\.com)?/noticias/[^"]+\.phtml)"',
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

const List<Map<String, String>> fuentesGubernamentales = [
  {
    'nombre': 'Parques Nacionales',
    'url': 'https://www.argentina.gob.ar/parquesnacionales',
    'base': 'https://www.argentina.gob.ar',
    'patron': r'href="(/parquesnacionales/[a-z0-9\-]+)"',
  },
];

void main() async {
  print('=== STARTING ENHANCED SCRAPER TEST ===');

  final List<Map<String, dynamic>> resultado = [];

  // 1. Scraping HTML (Weekend)
  print('\n--- SCRAPING WEEKEND ---');
  try {
    final res = await http.get(
      Uri.parse(revistasArgentinas[0]['url']!),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    ).timeout(Duration(seconds: 10));
    
    final regex = RegExp(revistasArgentinas[0]['patron']!, caseSensitive: false);
    final matches = regex.allMatches(res.body);
    final Set<String> urls = {};
    for (final m in matches) {
      String link = m.group(1) ?? '';
      if (link.startsWith('/')) link = '${revistasArgentinas[0]['base']}$link';
      urls.add(link);
      if (urls.length >= 3) break;
    }
    
    print('Weekend URLs found: ${urls.length}');
    for (final url in urls) {
      try {
        final artRes = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
        ).timeout(Duration(seconds: 5));
        
        final title = _parsearTituloDeHtml(artRes.body);
        final image = _parsearImagenDeHtml(artRes.body, url, revistasArgentinas[0]['base']!);
        
        print('  Weekend Article: $title');
        print('    Image: $image');
        
        if (title.isNotEmpty && image != null) {
          resultado.add({
            'fuente': 'Weekend',
            'titulo': title,
            'imagen': image,
            'url': url,
          });
        }
      } catch (e) {
        print('    Error: $e');
      }
    }
  } catch (e) {
    print('Weekend error: $e');
  }

  // 2. WordPress RSS (El Pato, Aire Libre, Rumbo, Senti, Pescare)
  for (final wp in revistasWordPress) {
    print('\n--- SCRAPING WP RSS: ${wp['nombre']} ---');
    try {
      final res = await http.get(
        Uri.parse(wp['rss']!),
        headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
      ).timeout(Duration(seconds: 10));
      
      final items = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false).allMatches(res.body);
      print('Items in RSS: ${items.length}');
      
      int count = 0;
      for (final item in items) {
        if (count >= 2) break; // test 2 per RSS
        final xml = item.group(1) ?? '';
        
        final title = RegExp(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', caseSensitive: false, dotAll: true)
            .firstMatch(xml)?.group(1)?.trim() ?? '';
        final link = RegExp(r'<link[^>]*>([^<]+)</link>', caseSensitive: false).firstMatch(xml)?.group(1)?.trim() ?? '';
        
        if (title.isEmpty || link.isEmpty) continue;
        
        // Try getting image from RSS first
        String? image = _extraerImagenDeRssXml(xml);
        
        // If RSS image is null or placeholder or emoji, fetch page and scrape
        if (image == null || image.contains('emoji') || image.contains('150x150') || image.contains('placeholder')) {
          print('    No valid image in RSS for "$title". Fetching page to extract og:image...');
          try {
            final pageRes = await http.get(
              Uri.parse(link),
              headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
            ).timeout(Duration(seconds: 5));
            final scrapedImg = _parsearImagenDeHtml(pageRes.body, link, wp['base']!);
            if (scrapedImg != null) {
              image = scrapedImg;
              print('      Successfully scraped og:image: $image');
            }
          } catch (e) {
            print('      Error scraping page: $e');
          }
        }
        
        print('  Article: $title');
        print('    Image: $image');
        
        if (image != null) {
          resultado.add({
            'fuente': wp['nombre'],
            'titulo': title,
            'imagen': image,
            'url': link,
          });
        }
        count++;
      }
    } catch (e) {
      print('WP RSS error: $e');
    }
  }

  // 3. Parques Nacionales
  print('\n--- SCRAPING PARQUES NACIONALES ---');
  try {
    final gob = fuentesGubernamentales[0];
    final res = await http.get(
      Uri.parse(gob['url']!),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    ).timeout(Duration(seconds: 10));
    
    final regex = RegExp(gob['patron']!, caseSensitive: false);
    final matches = regex.allMatches(res.body);
    final Set<String> urls = {};
    for (final m in matches) {
      String link = m.group(1) ?? '';
      if (link.startsWith('/')) link = '${gob['base']}$link';
      urls.add(link);
      if (urls.length >= 2) break;
    }
    
    print('Parques Nacionales URLs found: ${urls.length}');
    for (final url in urls) {
      try {
        final artRes = await http.get(
          Uri.parse(url),
          headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
        ).timeout(Duration(seconds: 5));
        
        final title = _parsearTituloDeHtml(artRes.body);
        final image = _parsearImagenDeHtml(artRes.body, url, gob['base']!);
        
        print('  Gob Article: $title');
        print('    Image: $image');
        
        if (title.isNotEmpty && image != null) {
          resultado.add({
            'fuente': 'Parques Nacionales',
            'titulo': title,
            'imagen': image,
            'url': url,
          });
        }
      } catch (e) {
        print('    Error: $e');
      }
    }
  } catch (e) {
    print('Gob error: $e');
  }

  print('\n=== SUMMARY ===');
  print('Total articles successfully scraped with valid images: ${resultado.length}');
  for (var i = 0; i < resultado.length; i++) {
    print('[$i] [${resultado[i]['fuente']}] ${resultado[i]['titulo']} -> ${resultado[i]['imagen']}');
  }
}

String? _extraerImagenDeRssXml(String xml) {
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
  
  return imagen;
}

String _parsearTituloDeHtml(String html) {
  final ogTitle = RegExp(
    r'''<meta\s+(?:property|name)=["']og:title["']\s+content=["']([^"']+)["']''',
    caseSensitive: false,
  ).firstMatch(html);
  if (ogTitle != null) {
    return ogTitle.group(1) ?? '';
  }
  final titleTag = RegExp(r'<title[^>]*>(.*?)</title>', caseSensitive: false, dotAll: true).firstMatch(html);
  return titleTag?.group(1) ?? '';
}

String? _parsearImagenDeHtml(String html, String url, String base) {
  // Try og:image
  var match = RegExp(r'''<meta\s+property=["']og:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  String? src;
  if (match != null) src = match.group(1);
  
  if (src == null) {
    match = RegExp(r'''<meta\s+content=["']([^"']+)["']\s+property=["']og:image["']''', caseSensitive: false).firstMatch(html);
    if (match != null) src = match.group(1);
  }

  // If og:image is generic site image (like argentina-fb.png or similar), look for content images
  if (src == null || src.contains('argentina-fb.png')) {
    // Search body images
    final imgMatches = RegExp(r'''<img\s+[^>]*src=["']([^"']+)["']''', caseSensitive: false).allMatches(html);
    for (final m in imgMatches) {
      final s = m.group(1);
      if (s != null) {
        if (s.contains('wp-content/uploads') || s.contains('images/') || s.contains('uploads/') || s.contains('sites/default/files/')) {
          if (!s.contains('logo') && !s.contains('icon') && !s.contains('.gif') && !s.contains('argentina-fb.png')) {
            src = s;
            break;
          }
        }
      }
    }
  }

  if (src != null) {
    if (src.startsWith('//')) src = 'https:$src';
    if (src.startsWith('/')) src = '$base$src';
  }
  
  return src;
}
