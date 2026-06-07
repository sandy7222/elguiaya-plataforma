import 'package:http/http.dart' as http;

void main() async {
  final channelId = 'UC85I5FMeTsIZFRRQ9upz_Aw'; // PESCAURBANAOFICIAL
  final url = 'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId';
  
  print('Fetching RSS Feed: $url');
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final body = response.body;
      print('Status: 200, Body length: ${body.length}');
      
      final entries = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(body);
      print('Found ${entries.length} entries.');
      
      for (final entry in entries.take(3)) {
        final entryHtml = entry.group(1) ?? '';
        final videoId = RegExp(r'<yt:videoId>(.*?)</yt:videoId>').firstMatch(entryHtml)?.group(1);
        final title = RegExp(r'<title>(.*?)</title>').firstMatch(entryHtml)?.group(1);
        final published = RegExp(r'<published>(.*?)</published>').firstMatch(entryHtml)?.group(1);
        final author = RegExp(r'<name>(.*?)</name>').firstMatch(entryHtml)?.group(1);
        final thumbnail = RegExp(r'<media:thumbnail[^>]*url="(.*?)"').firstMatch(entryHtml)?.group(1);
        
        print('---');
        print('Video ID: $videoId');
        print('Title: $title');
        print('Author: $author');
        print('Published: $published');
        print('Thumbnail: $thumbnail');
      }
    } else {
      print('Status: ${response.statusCode}');
    }
  } catch (e) {
    print('Exception: $e');
  }
}
