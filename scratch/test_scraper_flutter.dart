import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/news_compiler_service.dart';

void main() {
  test('Test NewsCompilerService scraping', () async {
    print('=== STARTING NEWS COMPILER SERVICE TEST ===');
    try {
      final noticias = await NewsCompilerService.scrapearRevistas(maxPorRevista: 3);
      print('Finished scraping. Found ${noticias.length} articles:');
      for (var i = 0; i < noticias.length; i++) {
        final n = noticias[i];
        print('[$i] [${n['fuente']}] ${n['titulo']}');
        print('    Url: ${n['url']}');
        print('    Image: ${n['imagen']}');
      }
      expect(noticias.isNotEmpty, true);
    } catch (e, stack) {
      print('Error during test: $e');
      print(stack);
      fail('Scraper test failed');
    }
  });
}
