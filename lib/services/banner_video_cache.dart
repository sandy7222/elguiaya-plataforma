import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';

class _CacheEntry {
  final VideoPlayerController controller;
  int refs;

  _CacheEntry(this.controller, {this.refs = 0});
}

/// Cache de videos de banners: evita reinicializar (y el spinner) al scrollear.
class BannerVideoCache {
  BannerVideoCache._();
  static final BannerVideoCache instance = BannerVideoCache._();

  final Map<String, List<_CacheEntry>> _pool = {};

  /// R.3b: máximo de reproductores vivos a la vez (el del banner visible). Fuera de la Tienda tiene que ser 0.
  static const int maxReproductores = 1;

  /// Reproductores vivos o en arranque. Cambia al reservar o devolver un cupo.
  final ValueNotifier<int> activos = ValueNotifier<int>(0);

  bool reservarCupo() {
    if (activos.value >= maxReproductores) return false;
    activos.value++;
    return true;
  }

  void devolverCupo() {
    if (activos.value > 0) activos.value--;
  }

  static bool isVideoUrl(String? url) {
    if (url == null || url.trim().isEmpty) return false;
    final lower = url.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.webm') ||
        lower.contains('.m4v') ||
        lower.contains('.3gp') ||
        lower.contains('video');
  }

  /// En web, Chrome bloquea autoplay con audio: hay que mutear ANTES de play().
  static Future<void> ensureMutedAutoplay(VideoPlayerController controller) async {
    try {
      await controller.setVolume(0.0);
    } catch (_) {}
    try {
      await controller.setLooping(true);
    } catch (_) {}
    try {
      await controller.play();
    } catch (playErr) {
      debugPrint(
        '⚠️ [BannerVideoCache] Autoplay suprimido por navegador: $playErr',
      );
    }
  }

  /// Devuelve null si ya hay otro reproductor vivo (solo se permite el del banner visible).
  Future<VideoPlayerController?> acquire(String url) async {
    if (!reservarCupo()) return null;
    try {
      return await _crear(url);
    } catch (_) {
      devolverCupo();
      rethrow;
    }
  }

  Future<VideoPlayerController> _crear(String url) async {
    final key = url.trim();
    final list = _pool.putIfAbsent(key, () => []);

    final free = list
        .where((e) => e.refs <= 0 && e.controller.value.isInitialized)
        .toList();
    if (free.isNotEmpty) {
      final entry = free.first;
      entry.refs = 1;
      await ensureMutedAutoplay(entry.controller);
      return entry.controller;
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(key),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: true,
        allowBackgroundPlayback: false,
      ),
    );
    try {
      await controller.initialize();
      // Mute obligatorio en web antes de play (política de autoplay de Chrome).
      await ensureMutedAutoplay(controller);
      list.add(_CacheEntry(controller, refs: 1));
      return controller;
    } catch (e) {
      debugPrint('⚠️ [BannerVideoCache] Error al inicializar video ($key): $e');
      await controller.dispose();
      rethrow;
    }
  }

  void release(String url, VideoPlayerController controller) {
    final key = url.trim();
    final list = _pool[key];
    if (list == null) return;

    for (final entry in list) {
      if (identical(entry.controller, controller)) {
        entry.refs = (entry.refs - 1).clamp(0, 999);
        // R.3b: al soltarlo se libera el decodificador (antes quedaba "warm" y los videos crecían sin parar).
        if (entry.refs <= 0) {
          list.remove(entry);
          entry.controller.dispose();
          devolverCupo();
        }
        break;
      }
    }

    if (list.isEmpty) _pool.remove(key);
  }

  /// R.3b: ya no se precalienta nada (retener controladores inicializados costaba cientos de MB).
  Future<void> preloadAll(Iterable<String> urls) async {}
}
