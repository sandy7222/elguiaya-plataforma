import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final handles = [
    'PESCAURBANAOFICIAL',
    'andopescando',
    'juntosporlapesca-w',
    'wilmarmerino',
    'Pescandoycazandoconvos',
    'PescaRealARG',
    'tiempodepesca2026',
    'ZAZPesca',
  ];

  print('Searching YouTube Channel IDs...');
  for (final handle in handles) {
    try {
      final url = 'https://www.youtube.com/@$handle';
      final response = await http.get(Uri.parse(url), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      });
      if (response.statusCode == 200) {
        final html = response.body;
        // Search for channelId in JSON or meta tag
        final match = RegExp(r'"channelId":"(UC[^"]+)"').firstMatch(html) ??
                      RegExp(r'meta itemprop="channelId" content="(UC[^"]+)"').firstMatch(html) ??
                      RegExp(r'itemprop="identifier" content="(UC[^"]+)"').firstMatch(html);
        if (match != null) {
          print('$handle: ${match.group(1)}');
        } else {
          // Look for other patterns
          final altMatch = RegExp(r'youtube\.com/channel/(UC[a-zA-Z0-9_-]+)').firstMatch(html);
          if (altMatch != null) {
            print('$handle: ${altMatch.group(1)}');
          } else {
            print('$handle: NOT_FOUND');
          }
        }
      } else {
        print('$handle: ERROR_${response.statusCode}');
      }
    } catch (e) {
      print('$handle: EXCEPTION_$e');
    }
  }
}
