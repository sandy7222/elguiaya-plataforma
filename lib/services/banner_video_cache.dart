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

  Future<VideoPlayerController> acquire(String url) async {
    final key = url.trim();
    final list = _pool.putIfAbsent(key, () => []);

    final free = list
        .where((e) => e.refs <= 0 && e.controller.value.isInitialized)
        .toList();
    if (free.isNotEmpty) {
      final entry = free.first;
      entry.refs = 1;
      try {
        if (!entry.controller.value.isPlaying) {
          await entry.controller.play();
        }
      } catch (_) {}
      return entry.controller;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(key));
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0.0);
      await controller.play();
      list.add(_CacheEntry(controller, refs: 1));
      return controller;
    } catch (e) {
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
        // Se deja warm (inicializado) para que al volver no haya spinner.
        break;
      }
    }

    _trim(key);
  }

  void _trim(String key) {
    final list = _pool[key];
    if (list == null || list.length <= 2) return;

    final extras = list.where((e) => e.refs <= 0).skip(1).toList();
    for (final entry in extras) {
      list.remove(entry);
      entry.controller.dispose();
    }
  }

  /// Precalienta videos de banners activos (en paralelo, sin bloquear UI).
  Future<void> preloadAll(Iterable<String> urls) async {
    final unique = urls
        .map((u) => u.trim())
        .where((u) => u.isNotEmpty && isVideoUrl(u))
        .toSet();
    await Future.wait(unique.map((url) async {
      try {
        final c = await acquire(url);
        release(url, c);
      } catch (e) {
        debugPrint('BannerVideoCache preload failed ($url): $e');
      }
    }));
  }
}
