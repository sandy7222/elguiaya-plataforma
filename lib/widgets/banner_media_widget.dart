import '../services/banner_video_politica.dart';
import '../services/diag_memoria.dart';
import 'package:flutter/foundation.dart' show kIsWeb, ValueListenable;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';

import '../services/banner_video_cache.dart';
import 'banner_html_video_stub.dart'
    if (dart.library.html) 'banner_html_video_web.dart';

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

class _VideoLoopPlayerState extends State<VideoLoopPlayer> with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _hasError = false;
  bool _attaching = false;
  String? _attachedUrl;
  bool _playRetryScheduled = false;
  Size _lastKnownSize = Size.zero;

  // R.3b: solo se reproduce lo que se ve. Sin AutomaticKeepAlive: al salir de pantalla se libera el decodificador.
  bool _appActiva = true;
  int? _ramMb;
  bool _ramMedida = false;
  ValueListenable<bool>? _tickerNotifier;

  bool get _visible => _tickerNotifier?.value ?? true;
  bool get _debeReproducir =>
      !DiagMemoria.sinVideo &&
      _ramMedida &&
      BannerVideoPolitica.debeReproducir(visible: _visible, appActiva: _appActiva, ramMb: _ramMb);
  bool get _modoImagenFija => _ramMedida && BannerVideoPolitica.esEquipoLiviano(_ramMb);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    BannerVideoCache.instance.activos.addListener(_sincronizarDiferido);
    final estado = WidgetsBinding.instance.lifecycleState;
    _appActiva = estado == null || estado == AppLifecycleState.resumed;
    BannerVideoPolitica.ramTotalMb().then((mb) {
      if (!mounted) return;
      _ramMb = mb;
      _ramMedida = true;
      _sincronizar();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nuevo = TickerMode.getNotifier(context);
    if (!identical(nuevo, _tickerNotifier)) {
      _tickerNotifier?.removeListener(_sincronizarDiferido);
      _tickerNotifier = nuevo..addListener(_sincronizarDiferido);
    }
    _sincronizarDiferido();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appActiva = state == AppLifecycleState.resumed;
    _sincronizarDiferido();
  }

  /// Los cambios de TickerMode llegan durante el armado del árbol: setState recién después del cuadro.
  void _sincronizarDiferido() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _sincronizar());
  }

  /// Conecta el video si hay que reproducirlo y no está conectado; lo suelta (libera el decodificador) si no.
  void _sincronizar() {
    if (!mounted) return;
    if (_debeReproducir) {
      if (_attachedUrl == null && _controller == null && !_attaching) _attach(widget.url);
    } else if (_attachedUrl != null || _controller != null) {
      _detach();
      setState(() {});
    } else if (_modoImagenFija) {
      setState(() {});
    }
  }

  @override
  void didUpdateWidget(covariant VideoLoopPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _detach();
      _sincronizar();
    }
  }

  void _onControllerTick() {
    final c = _controller;
    if (!mounted || c == null) return;

    final v = c.value;
    final ready = v.isInitialized;
    final sizeChanged = v.size != _lastKnownSize &&
        (v.size.width > 0 || v.size.height > 0);

    if (ready != _initialized || sizeChanged) {
      _lastKnownSize = v.size;
      setState(() {
        _initialized = ready;
        _hasError = false;
      });
    }

    // Reintento suave de autoplay muteado (políticas de Chrome).
    if (ready && !v.isPlaying && !_playRetryScheduled) {
      _playRetryScheduled = true;
      Future<void>.delayed(const Duration(milliseconds: 120), () async {
        if (!mounted || _controller == null) return;
        await BannerVideoCache.ensureMutedAutoplay(_controller!);
        _playRetryScheduled = false;
      });
    }
  }

  Future<void> _attach(String url) async {
    final trimmed = url.trim();
    _playRetryScheduled = false;
    _attaching = true;
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
        _initialized = false;
      });
    }

    try {
      final controller = await BannerVideoCache.instance.acquire(trimmed);
      _attaching = false;
      if (controller == null) return; // hay otro reproductor vivo: se reintenta cuando se libere
      if (!mounted || widget.url.trim() != trimmed || !_debeReproducir) {
        BannerVideoCache.instance.release(trimmed, controller);
        return;
      }
      _attachedUrl = trimmed;
      _controller?.removeListener(_onControllerTick);
      _controller = controller;
      controller.addListener(_onControllerTick);
      setState(() {
        _initialized = controller.value.isInitialized;
        _hasError = false;
      });
      // Asegurar mute+play otra vez al montar el widget (web).
      await BannerVideoCache.ensureMutedAutoplay(controller);
    } catch (e) {
      _attaching = false;
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
    _playRetryScheduled = false;
    _lastKnownSize = Size.zero;
    if (controller != null) {
      controller.removeListener(_onControllerTick);
    }
    if (url != null && controller != null) {
      BannerVideoCache.instance.release(url, controller);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tickerNotifier?.removeListener(_sincronizarDiferido);
    BannerVideoCache.instance.activos.removeListener(_sincronizarDiferido);
    _detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF0D47A1),
        child: const Center(
          child: Icon(Icons.movie_creation_outlined, color: Colors.white38, size: 40),
        ),
      );
    }

    // Equipos de 4 GB o menos: imagen fija, sin decodificador de video.
    if (_modoImagenFija) {
      return const ColoredBox(
        color: Color(0xFF001F3F),
        child: Center(child: Icon(Icons.play_circle_outline, color: Colors.white24, size: 48)),
      );
    }

    // Sin spinner: fondo oscuro mientras arranca (o instantáneo si viene del cache).
    if (!_initialized || _controller == null) {
      return const ColoredBox(color: Color(0xFF001F3F));
    }

    // En Chrome/web, value.size puede ser 0x0 aunque isInitialized sea true.
    // Un FittedBox con hijo 0x0 colapsa y deja ver el navy del contenedor padre.
    final raw = _controller!.value.size;
    final width = raw.width > 0 ? raw.width : 16.0;
    final height = raw.height > 0 ? raw.height : 9.0;

    return IgnorePointer(
      child: ColoredBox(
        color: const Color(0xFF001F3F),
        child: SizedBox.expand(
          child: FittedBox(
            fit: widget.fit,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: width,
              height: height,
              child: VideoPlayer(_controller!),
            ),
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
      // Web: <video> HTML nativo (autoplay muteado). Más fiable en el carrusel.
      if (kIsWeb) {
        return BannerHtmlVideo(
          key: ValueKey('banner-html-video-$url'),
          url: url,
          fit: widget.fit,
        );
      }
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
        // En web a veces un .mp4 llega sin extensión clara en el path parseado;
        // si la imagen falla, reintentamos como video.
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
