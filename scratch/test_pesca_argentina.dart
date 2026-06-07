import 'package:http/http.dart' as http;

void main() async {
  print('=== INVESTIGATING PESCA ARGENTINA COM ===');
  try {
    final url = 'https://www.pescaargentina.com/';
    final res = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    print('Pesca Argentina COM status: ${res.statusCode}');
    print('Length: ${res.body.length}');
    
    // Check if it's a WordPress site by looking for wp-content or feed
    final isWP = res.body.contains('wp-content') || res.body.contains('wp-includes');
    print('Is WordPress?: $isWP');
    
    // List all links
    final regex = RegExp(r'href="([^"]+)"');
    final Set<String> links = {};
    for (final m in regex.allMatches(res.body)) {
      final link = m.group(1) ?? '';
      if (link.startsWith('http') && !link.contains('instagram') && !link.contains('wa.me') && !link.contains('facebook') && !link.contains('twitter') && !link.contains('youtube') && !link.contains('jsdelivr') && !link.contains('cloudflare') && !link.contains('fonts.')) {
        links.add(link);
      }
    }
    
    print('Links found (${links.length}):');
    for (final link in links) {
      print('  $link');
    }
    
    // Test RSS feed
    final rssUrl = 'https://www.pescaargentina.com/feed/';
    final rssRes = await http.get(Uri.parse(rssUrl)).timeout(Duration(seconds: 5));
    print('RSS Status at $rssUrl: ${rssRes.statusCode}');
    if (rssRes.statusCode == 200) {
      final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(rssRes.body);
      print('  RSS Items: ${items.length}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
