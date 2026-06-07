import 'package:http/http.dart' as http;

void main() async {
  print('=== TESTING PESCARE RSS ===');
  final url = 'https://pescare.com.ar/feed/';
  try {
    final res = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    ).timeout(Duration(seconds: 10));
    print('Status: ${res.statusCode}');
    if (res.statusCode == 200) {
      final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(res.body);
      print('Items found: ${items.length}');
      int count = 0;
      for (final item in items) {
        if (count >= 3) break;
        final xml = item.group(1) ?? '';
        final title = RegExp(r'<title[^>]*>(?:<!\[CDATA\[)?(.*?)(?:\]\]>)?</title>', caseSensitive: false).firstMatch(xml)?.group(1);
        final link = RegExp(r'<link[^>]*>([^<]+)</link>', caseSensitive: false).firstMatch(xml)?.group(1);
        print('  Item $count: ${title?.trim()}');
        print('    Link: ${link?.trim()}');
        count++;
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
