import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

import '../services/banner_video_cache.dart';

class VideoLoopPlayer extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const VideoLoopPlayer({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoLoopPlayer> createState() => _VideoLoopPlayerState();
}

class _VideoLoopPlayerState extends State<VideoLoopPlayer>
    with AutomaticKeepAliveClientMixin {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  String? _attachedUrl;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _attach(widget.url);
  }

  @override
  void didUpdateWidget(covariant VideoLoopPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _detach();
      _attach(widget.url);
    }
  }

  Future<void> _attach(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _initialized = false;
          _controller = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _hasError = false;
        // Si ya hay frame en cache, no forzamos estado "loading" con spinner.
        _initialized = false;
      });
    }

    try {
      final controller = await BannerVideoCache.instance.acquire(trimmed);
      if (!mounted || widget.url.trim() != trimmed) {
        BannerVideoCache.instance.release(trimmed, controller);
        return;
      }
      _attachedUrl = trimmed;
      _controller = controller;
      setState(() {
        _initialized = controller.value.isInitialized;
        _hasError = false;
      });
    } catch (e) {
      debugPrint('Error initializing video ($e) for URL: $trimmed');
      if (mounted && widget.url.trim() == trimmed) {
        setState(() {
          _hasError = true;
          _initialized = false;
          _controller = null;
        });
      }
    }
  }

  void _detach() {
    final url = _attachedUrl;
    final controller = _controller;
    _attachedUrl = null;
    _controller = null;
    _initialized = false;
    if (url != null && controller != null) {
      BannerVideoCache.instance.release(url, controller);
    }
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_hasError) {
      return Container(
        color: const Color(0xFF0D47A1),
        child: const Center(
          child: Icon(Icons.movie_creation_outlined, color: Colors.white38, size: 40),
        ),
      );
    }

    // Sin spinner: fondo oscuro mientras arranca (o instantáneo si viene del cache).
    if (!_initialized || _controller == null) {
      return const ColoredBox(color: Color(0xFF001F3F));
    }

    return IgnorePointer(
      child: SizedBox.expand(
        child: FittedBox(
          fit: widget.fit,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: _controller!.value.size.width,
            height: _controller!.value.size.height,
            child: VideoPlayer(_controller!),
          ),
        ),
      ),
    );
  }
}

class BannerMediaWidget extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const BannerMediaWidget({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  @override
  State<BannerMediaWidget> createState() => _BannerMediaWidgetState();
}

class _BannerMediaWidgetState extends State<BannerMediaWidget> {
  bool _forceVideoMode = false;

  @override
  void didUpdateWidget(covariant BannerMediaWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      setState(() {
        _forceVideoMode = false;
      });
    }
  }

  bool _isLottie(String path) {
    final lower = path.toLowerCase();
    return lower.contains('.json');
  }

  bool _isVideo(String path) {
    return _forceVideoMode || BannerVideoCache.isVideoUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.url.trim();

    if (url.isEmpty) {
      return const ColoredBox(color: Color(0xFF001F3F));
    }

    if (_isLottie(url)) {
      return Lottie.network(
        url,
        fit: widget.fit,
        errorBuilder: (context, error, stackTrace) => const ColoredBox(
          color: Color(0xFF001F3F),
          child: Center(
            child: Icon(Icons.animation, color: Colors.white24),
          ),
        ),
      );
    }

    if (_isVideo(url)) {
      return VideoLoopPlayer(
        key: ValueKey('banner-video-$url'),
        url: url,
        fit: widget.fit,
      );
    }

    return Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_forceVideoMode) {
            setState(() {
              _forceVideoMode = true;
            });
          }
        });
        return const ColoredBox(color: Color(0xFF001F3F));
      },
    );
  }
}
