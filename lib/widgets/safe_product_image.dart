import 'package:flutter/material.dart';

class SafeProductImage extends StatelessWidget {
  final String imagenUrl;
  final double width;
  final double height;
  final BoxFit fit;

  const SafeProductImage({
    super.key,
    required this.imagenUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final cleanUrl = imagenUrl.trim();
    
    if (cleanUrl.startsWith('http://') || cleanUrl.startsWith('https://')) {
      return Image.network(
        cleanUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: width,
            height: height,
            color: Colors.grey.shade100,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                ),
              ),
            ),
          );
        },
      );
    } else if (cleanUrl.isNotEmpty) {
      // Es un asset local
      return Image.asset(
        cleanUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, __, ___) => _buildFallback(),
      );
    } else {
      return _buildFallback();
    }
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported_outlined, color: Colors.grey),
    );
  }
}
