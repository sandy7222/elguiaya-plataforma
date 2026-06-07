import 'package:http/http.dart' as http;

void main() async {
  print('=== INVESTIGATING PARQUES NACIONALES ===');
  final url = 'https://www.argentina.gob.ar/parquesnacionales/otono-2026-planea-tu-visita';
  try {
    final res = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    );
    print('Status: ${res.statusCode}');
    
    // Let's print all <meta> tags that contain image
    final metaRegex = RegExp(r'<meta[^>]*>');
    print('Meta tags with image:');
    for (final m in metaRegex.allMatches(res.body)) {
      final tag = m.group(0) ?? '';
      if (tag.contains('image')) {
        print('  $tag');
      }
    }
    
    // Let's print the first few <img> tags in the body
    final imgRegex = RegExp(r'<img[^>]*>');
    print('\nImg tags (first 10):');
    int count = 0;
    for (final m in imgRegex.allMatches(res.body)) {
      final tag = m.group(0) ?? '';
      if (!tag.contains('logo') && !tag.contains('icon') && !tag.contains('escudo') && !tag.contains('firma')) {
        print('  $tag');
        count++;
        if (count >= 10) break;
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
