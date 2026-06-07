import 'package:capitanya_master/services/news_compiler_service.dart';

void main() async {
  print('Starting scraper test...');
  try {
    final revistas = await NewsCompilerService.scrapearRevistas(maxPorRevista: 3);
    print('Scraping finished. Found ${revistas.length} articles:');
    for (var i = 0; i < revistas.length; i++) {
      final art = revistas[i];
      print('[$i] ${art['fuente']} - ${art['titulo']} - Has real image: ${art['tiene_imagen_real']} - Url: ${art['url']}');
    }
  } catch (e, stack) {
    print('Error: $e');
    print(stack);
  }
}
