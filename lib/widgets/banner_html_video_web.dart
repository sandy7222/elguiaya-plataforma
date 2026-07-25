import 'dart:js_interop';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

/// Video de banner en Flutter Web vía <video> HTML nativo.
/// Evita bugs de video_player (size 0x0 / platform views) en PageView/ClipRRect.
class BannerHtmlVideo extends StatefulWidget {
  final String url;
  final BoxFit fit;

  const BannerHtmlVideo({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  @override
  State<BannerHtmlVideo> createState() => _BannerHtmlVideoState();
}

class _BannerHtmlVideoState extends State<BannerHtmlVideo> {
  late final String _viewType;
  web.HTMLVideoElement? _video;

  @override
  void initState() {
    super.initState();
    _viewType =
        'elguia-banner-video-${widget.url.hashCode}-${identityHashCode(this)}';
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = web.HTMLVideoElement()
        ..src = widget.url
        ..autoplay = true
        ..loop = true
        ..muted = true
        ..controls = false
        ..preload = 'auto';
      video.setAttribute('playsinline', 'true');
      video.setAttribute('webkit-playsinline', 'true');
      video.setAttribute('muted', 'true');
      video.style
        ..setProperty('width', '100%')
        ..setProperty('height', '100%')
        ..setProperty('object-fit', _cssObjectFit(widget.fit))
        ..setProperty('border', 'none')
        ..setProperty('display', 'block')
        ..setProperty('background', '#001F3F');

      // Autoplay muteado (política Chrome). Ignora rechazo del Promise.
      video.play().toDart.then((_) {}, onError: (_) {});

      _video = video;
      return video;
    });
  }

  String _cssObjectFit(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitWidth:
      case BoxFit.fitHeight:
      case BoxFit.scaleDown:
        return 'contain';
      case BoxFit.none:
        return 'none';
      case BoxFit.cover:
        return 'cover';
    }
  }

  @override
  void didUpdateWidget(covariant BannerHtmlVideo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url && _video != null) {
      _video!
        ..src = widget.url
        ..load();
      _video!.play().toDart.then((_) {}, onError: (_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return HtmlElementView(viewType: _viewType);
  }
}
