import 'package:flutter/widgets.dart';

/// Stub no-web: el VideoLoopPlayer de video_player cubre mobile/desktop.
class BannerHtmlVideo extends StatelessWidget {
  final String url;
  final BoxFit fit;

  const BannerHtmlVideo({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
