import 'package:http/http.dart' as http;

void main() async {
  print('=== TESTING SCRAPER IMPROVEMENTS ===');

  // 1. Weekend regex test
  try {
    print('\n--- WEEKEND REGEX TEST ---');
    final res = await http.get(
      Uri.parse('https://weekend.perfil.com/'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    final patron = r'href="((?:https://weekend\.perfil\.com)?/noticias/[^"]+\.phtml)"';
    final regex = RegExp(patron, caseSensitive: false);
    final matches = regex.allMatches(res.body);
    print('Weekend matches found: ${matches.length}');
    for (int i = 0; i < matches.length && i < 3; i++) {
      print('  Match $i: ${matches.elementAt(i).group(1)}');
    }
  } catch (e) {
    print('Weekend error: $e');
  }

  // 2. Sentí la Pesca RSS feed check
  try {
    print('\n--- SENTI LA PESCA RSS FEED ---');
    final res = await http.get(
      Uri.parse('https://sentilapesca.com.ar/feed/'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    print('RSS Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final items = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false).allMatches(res.body);
      print('Items found: ${items.length}');
      if (items.isNotEmpty) {
        final xml = items.first.group(1) ?? '';
        final title = RegExp(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', caseSensitive: false).firstMatch(xml)?.group(1);
        final link = RegExp(r'<link[^>]*>([^<]+)</link>', caseSensitive: false).firstMatch(xml)?.group(1);
        print('  First Item: $title');
        print('  Link: $link');
      }
    }
  } catch (e) {
    print('Senti la Pesca RSS error: $e');
  }

  // 3. El Pato article page og:image test
  try {
    print('\n--- EL PATO ARTICLE OG:IMAGE TEST ---');
    final artUrl = 'https://revistaelpato.com/2026/04/30/el-tesoro-escondido-de-arroyo-leyes/';
    final res = await http.get(
      Uri.parse(artUrl),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    print('Article status: ${res.statusCode}');
    final image = _parsearImagenDeHtml(res.body);
    print('Extracted og:image: $image');
  } catch (e) {
    print('El Pato article error: $e');
  }

  // 4. Rumbo a la Aventura og:image test
  try {
    print('\n--- RUMBO A LA AVENTURA ARTICLE OG:IMAGE TEST ---');
    final artUrl = 'https://www.revistarumboalaaventura.com/www-revistarumboalaaventura-com-aventura-4x4-chile/';
    final res = await http.get(
      Uri.parse(artUrl),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    print('Article status: ${res.statusCode}');
    final image = _parsearImagenDeHtml(res.body);
    print('Extracted og:image: $image');
  } catch (e) {
    print('Rumbo a la Aventura article error: $e');
  }

  // 5. Pesca Argentina all href links listing
  try {
    print('\n--- PESCA ARGENTINA LINKS ---');
    final res = await http.get(
      Uri.parse('https://www.pescaargentina.com.ar/'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    final regex = RegExp(r'href="([^"]+)"');
    print('Total href links on homepage: ${regex.allMatches(res.body).length}');
    // Let's print some links that could be articles
    for (final m in regex.allMatches(res.body)) {
      final link = m.group(1) ?? '';
      if (link.startsWith('http') && !link.contains('instagram') && !link.contains('wa.me') && !link.contains('facebook') && !link.contains('twitter') && !link.contains('youtube')) {
        print('  Link: $link');
      }
    }
  } catch (e) {
    print('Pesca Argentina error: $e');
  }
}

String? _parsearImagenDeHtml(String html) {
  var match = RegExp(r'''<meta\s+property=["']og:image["']\s+content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
  if (match != null) return match.group(1);
  return null;
}
