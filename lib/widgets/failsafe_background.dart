import 'package:flutter/material.dart';

class FailsafeBackground extends StatelessWidget {
  final String? imageUrl;
  final Widget? child;
  final double opacity;
  final double brightness;
  final Color? overlayColor;

  const FailsafeBackground({
    super.key,
    this.imageUrl,
    this.child,
    this.opacity = 0.5,
    this.brightness = 1.0,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    // Colores de la marca para el degradado de seguridad
    const Color azulProfundo = Color(0xFF00153D);
    const Color azulCapitan = Color(0xFF001F3F);
    const Color azulOscuro = Color(0xFF000D26);

    return Stack(
      children: [
        // Capa 1: Imagen (Red con fallback a Asset)
        Positioned.fill(
          child: (imageUrl != null && imageUrl!.isNotEmpty)
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                color: Colors.black.withOpacity((1.0 - brightness).clamp(0.0, 1.0)),
                colorBlendMode: BlendMode.darken,
                errorBuilder: (context, error, stackTrace) => _buildAssetFallback(brightness),
              )
            : _buildAssetFallback(brightness),
        ),

        // Capa 3: Overlay de Opacidad (Mezcla con el color de marca)
        Positioned.fill(
          child: Container(
            color: (overlayColor ?? Colors.black).withOpacity(opacity.clamp(0.0, 1.0)),
          ),
        ),

        // Contenido
        if (child != null) child!,
      ],
    );
  }

  Widget _buildAssetFallback(double brightness) {
    return Image.asset(
      'assets/images/unnamed.jpg',
      fit: BoxFit.cover,
      color: Colors.black.withOpacity((1.0 - brightness).clamp(0.0, 1.0)),
      colorBlendMode: BlendMode.darken,
      errorBuilder: (context, error, stackTrace) => Container(color: const Color(0xFF000D26)),
    );
  }
}
