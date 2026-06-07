import 'package:http/http.dart' as http;

void main() async {
  print('=== INVESTIGATING SOURCES ===');

  // 1. Weekend Perfil HTML inspect
  try {
    print('\n--- WEEKEND HOME ---');
    final res = await http.get(
      Uri.parse('https://weekend.perfil.com/'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    print('Weekend content length: ${res.body.length}');
    // Let's print some links containing /noticias/
    final regex = RegExp(r'href="([^"]+)"');
    int count = 0;
    for (final m in regex.allMatches(res.body)) {
      final link = m.group(1) ?? '';
      if (link.contains('/noticias/')) {
        print('  Found link: $link');
        count++;
        if (count >= 10) break;
      }
    }
  } catch (e) {
    print('Error Weekend: $e');
  }

  // 2. Pesca Argentina HTML inspect
  try {
    print('\n--- PESCA ARGENTINA HOME ---');
    final res = await http.get(
      Uri.parse('https://www.pescaargentina.com.ar/'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    print('Pesca Argentina content length: ${res.body.length}');
    final regex = RegExp(r'href="([^"]+)"');
    int count = 0;
    for (final m in regex.allMatches(res.body)) {
      final link = m.group(1) ?? '';
      if (link.contains('pescaargentina.com.ar') && link.length > 35) {
        print('  Found link: $link');
        count++;
        if (count >= 10) break;
      }
    }
  } catch (e) {
    print('Error Pesca Argentina: $e');
  }

  // 3. Sentí la Pesca proxy check
  try {
    print('\n--- SENTI LA PESCA PROXY CHECK ---');
    final url = 'https://sentilapesca.com.ar/';
    final proxy = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(url)}';
    final res = await http.get(Uri.parse(proxy)).timeout(Duration(seconds: 10));
    print('Senti la Pesca Proxy Status: ${res.statusCode}');
    print('Content Length: ${res.body.length}');
    final regex = RegExp(r'href="([^"]+)"');
    int count = 0;
    for (final m in regex.allMatches(res.body)) {
      final link = m.group(1) ?? '';
      if (link.contains('sentilapesca.com.ar') && link.length > 30) {
        print('  Found link: $link');
        count++;
        if (count >= 5) break;
      }
    }
  } catch (e) {
    print('Error Senti la Pesca proxy: $e');
  }

  // 4. Revista El Pato RSS sample
  try {
    print('\n--- REVISTA EL PATO RSS SAMPLE ---');
    final res = await http.get(
      Uri.parse('https://revistaelpato.com/feed/'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    final items = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false).allMatches(res.body);
    if (items.isNotEmpty) {
      final firstItem = items.first.group(1) ?? '';
      print('First item content snippet (up to 2000 chars):');
      print(firstItem.length > 2000 ? firstItem.substring(0, 2000) : firstItem);
    } else {
      print('No items found in El Pato RSS.');
    }
  } catch (e) {
    print('Error El Pato RSS: $e');
  }

  // 5. Rumbo a la Aventura RSS sample
  try {
    print('\n--- RUMBO A LA AVENTURA RSS SAMPLE ---');
    final res = await http.get(
      Uri.parse('https://www.revistarumboalaaventura.com/feed/'),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    final items = RegExp(r'<item>([\s\S]*?)</item>', caseSensitive: false).allMatches(res.body);
    if (items.isNotEmpty) {
      final firstItem = items.first.group(1) ?? '';
      print('First item content snippet:');
      print(firstItem.length > 1500 ? firstItem.substring(0, 1500) : firstItem);
    } else {
      print('No items found in Rumbo a la Aventura RSS.');
    }
  } catch (e) {
    print('Error Rumbo a la Aventura RSS: $e');
  }
}
