// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadBytesWeb(List<int> bytes, String filename, String mimeType) {
  try {
    final blob = html.Blob([bytes], mimeType);
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  } catch (e) {
    // ignore
  }
}
