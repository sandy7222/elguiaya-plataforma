import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/services/news_compiler_service.dart';

void main() {
  test('Diagnostics for Blog Piques', () async {
    print("--- [DIAGNOSTICS] Starting ---");
    
    print("1. Initializing Supabase...");
    try {
      await SupabaseService.initialize();
      print("   Supabase client initialized: ${SupabaseService.supabase != null}");
    } catch (e) {
      print("   ❌ Error initializing Supabase: $e");
    }
    
    print("2. Querying 'blog_articulos' table...");
    try {
      final list = await SupabaseService.obtenerArticulosBlog(soloActivos: false);
      print("   ✅ Success: Found ${list.length} articles in database.");
      for (var i = 0; i < list.length && i < 3; i++) {
        print("      - Article [$i]: ${list[i].titulo} (Active: ${list[i].activo}, Category: ${list[i].categoria})");
      }
    } catch (e) {
      print("   ❌ Error querying 'blog_articulos': $e");
    }

    print("3. Fetching YouTube feeds...");
    try {
      final videos = await NewsCompilerService.obtenerVideosRecientesYoutube('');
      print("   ✅ Success: Found ${videos.length} videos from curated channels.");
      for (var i = 0; i < videos.length && i < 3; i++) {
        print("      - Video [$i]: ${videos[i]['titulo']} (Source: ${videos[i]['fuente']})");
      }
    } catch (e) {
      print("   ❌ Error fetching YouTube videos: $e");
    }

    print("4. Fetching Web news...");
    try {
      final news = await NewsCompilerService.obtenerNoticiasRecientesWeb('Pique de la semana');
      print("   ✅ Success: Found ${news.length} news articles (real or simulated).");
      for (var i = 0; i < news.length && i < 3; i++) {
        print("      - News [$i]: ${news[i]['titulo']} (Source: ${news[i]['fuente']})");
      }
    } catch (e) {
      print("   ❌ Error fetching Web news: $e");
    }

    print("5. Attempting Auto-Compilation...");
    try {
      final count = await NewsCompilerService.autoCompilarContenidoSemanal();
      print("   ✅ Success: Auto-compiled $count new articles.");
    } catch (e) {
      print("   ❌ Error during auto-compilation: $e");
    }
    
    print("--- [DIAGNOSTICS] Finished ---");
  });
}
