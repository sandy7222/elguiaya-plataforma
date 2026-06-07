import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Pantalla que reproduce un video de YouTube dentro de la app,
/// sin salir a la aplicación de YouTube ni al navegador.
class YoutubePlayerScreen extends StatefulWidget {
  final String videoUrl;   // URL completa de YouTube
  final String titulo;
  final String descripcion;
  final String fuente;
  final String fechaLegible;

  const YoutubePlayerScreen({
    super.key,
    required this.videoUrl,
    this.titulo = '',
    this.descripcion = '',
    this.fuente = '',
    this.fechaLegible = '',
  });

  @override
  State<YoutubePlayerScreen> createState() => _YoutubePlayerScreenState();
}

class _YoutubePlayerScreenState extends State<YoutubePlayerScreen> {
  YoutubePlayerController? _controller;
  bool _isFullScreen = false;
  bool _videoError = false;

  @override
  void initState() {
    super.initState();
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    if (videoId != null && videoId.isNotEmpty) {
      _controller = YoutubePlayerController(
        initialVideoId: videoId,
        flags: const YoutubePlayerFlags(
          autoPlay: true,
          mute: false,
          enableCaption: true,
          captionLanguage: 'es',
          forceHD: false,
          loop: false,
        ),
      )..addListener(_onPlayerStateChange);
    } else {
      _videoError = true;
    }
  }

  void _onPlayerStateChange() {
    if (!mounted) return;
    final isFS = _controller?.value.isFullScreen ?? false;
    if (isFS != _isFullScreen) {
      setState(() => _isFullScreen = isFS);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerStateChange);
    _controller?.dispose();
    // Restaurar orientación al salir
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_videoError || _controller == null) {
      return _buildErrorScreen();
    }

    return YoutubePlayerBuilder(
      onExitFullScreen: () {
        SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      },
      player: YoutubePlayer(
        controller: _controller!,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF00E676),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF00E676),
          handleColor: Color(0xFF00E676),
          bufferedColor: Colors.white30,
          backgroundColor: Colors.white12,
        ),
        onReady: () {},
        onEnded: (_) {},
      ),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: const Color(0xFF001F3F),
          body: Column(
            children: [
              // ── Reproductor ─────────────────────────────────────
              player,

              // ── Info del video ──────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Fuente y fecha
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.red.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_circle_fill, color: Colors.red, size: 14),
                                const SizedBox(width: 5),
                                Text(
                                  widget.fuente.isNotEmpty ? widget.fuente : 'YouTube',
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.fechaLegible.isNotEmpty) ...[
                            const SizedBox(width: 10),
                            Text(
                              widget.fechaLegible,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.4),
                                fontSize: 11,
                              ),
                            ),
                          ],
                          const Spacer(),
                          // Botón cerrar
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Título
                      if (widget.titulo.isNotEmpty)
                        Text(
                          widget.titulo,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            height: 1.4,
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Divider
                      Divider(color: Colors.white.withOpacity(0.08)),

                      const SizedBox(height: 14),

                      // Descripción / comentario del influencer
                      if (widget.descripcion.isNotEmpty) ...[
                        Row(
                          children: [
                            Icon(Icons.format_quote_rounded,
                                color: const Color(0xFF00E676).withOpacity(0.6), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'Sobre este video',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.06)),
                          ),
                          child: Text(
                            widget.descripcion,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 14,
                              height: 1.7,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Crédito
                      Center(
                        child: Text(
                          '🎣 CapitanYA — Blog de Pesca',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.2),
                            fontSize: 11,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_rounded, color: Colors.white30, size: 60),
            const SizedBox(height: 16),
            const Text(
              'No se pudo cargar el video',
              style: TextStyle(color: Colors.white60, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              widget.videoUrl,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white30, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
