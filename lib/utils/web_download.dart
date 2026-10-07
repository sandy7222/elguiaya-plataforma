import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';

void downloadFileOnWeb(List<int> bytes, String filename, String mimeType) {
  downloadBytesWeb(bytes, filename, mimeType);
}
