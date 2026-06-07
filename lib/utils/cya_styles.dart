import 'package:flutter/material.dart';

/// Sistema Centralizado de Diseño y Estética Premium de Capitán-YA.
/// Contiene tokens de color, decoraciones y constructores de UI estandarizados
/// para lograr consistencia visual total en las plataformas Pescador, Capitán y Administrador.
class CYAStyles {
  // ─── PALETA DE COLORES PREMIUM ─────────────────────────────────────────────
  static const Color primaryDark = Color(0xFF001326);   // Fondo marino ultra profundo
  static const Color primaryNavy = Color(0xFF001F3F);   // Azul náutico clásico
  static const Color primaryLight = Color(0xFF002D59);  // Azul náutico intermedio
  
  static const Color accentGreen = Color(0xFF00E676);   // Verde vibrante (Éxito, Compras, Pagos)
  static const Color accentOrange = Color(0xFFFF6600);  // Naranja intenso (Capitán, Alertas)
  static const Color accentBlue = Color(0xFF0066FF);    // Azul brillante (Pescador, Información)
  
  static const Color textWhite = Colors.white;
  static const Color textMuted = Colors.white70;
  static const Color textSubMuted = Colors.white54;

  // ─── BORDES REDONDEADOS ──────────────────────────────────────────────────
  static final BorderRadius radiusSmall = BorderRadius.circular(8);
  static final BorderRadius radiusMedium = BorderRadius.circular(14);
  static final BorderRadius radiusLarge = BorderRadius.circular(20);
  static final BorderRadius radiusExtraLarge = BorderRadius.circular(28);

  // ─── DECORACIÓN DE TARJETAS GLASSMORPHIC ──────────────────────────────────
  /// Crea una tarjeta translúcida y premium que flota en el fondo oscuro.
  static BoxDecoration glassCard({
    Color? borderOverride,
    double opacity = 0.06,
    double borderOpacity = 0.12,
  }) {
    return BoxDecoration(
      color: Colors.white.withOpacity(opacity),
      borderRadius: radiusLarge,
      border: Border.all(
        color: borderOverride ?? Colors.white.withOpacity(borderOpacity),
        width: 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.15),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ─── BOTONES ESTANDARIZADOS ──────────────────────────────────────────────
  
  /// Botón principal premium con gradiente.
  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    IconData? icon,
    List<Color> gradientColors = const [accentBlue, Color(0xFF00B0FF)],
    double height = 54,
    double fontSize = 15,
    bool isLoading = false,
  }) {
    final bool isDisabled = onPressed == null || isLoading;
    
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        gradient: isDisabled 
            ? null 
            : LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: isDisabled ? Colors.white.withOpacity(0.12) : null,
        borderRadius: radiusMedium,
        boxShadow: [
          if (!isDisabled)
            BoxShadow(
              color: gradientColors.first.withOpacity(0.35),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: ElevatedButton(
        onPressed: isDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDisabled ? Colors.white38 : Colors.white,
                        fontSize: fontSize,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Botón secundario de aspecto vítreo (Glassmorphic).
  static Widget secondaryButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    double height = 50,
    double fontSize = 13,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: radiusMedium,
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.2,
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Botón Outline (Contorno fino) con color de acento.
  static Widget outlineButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color color = accentGreen,
    double height = 50,
    double fontSize = 13,
  }) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: radiusMedium,
        border: Border.all(
          color: color.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: radiusMedium),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: fontSize,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── DECORACIÓN DE ENTRADAS DE TEXTO ───────────────────────────────────────
  
  /// Estilo de decoración para TextFields premium y oscuros.
  static InputDecoration inputDecoration({
    required String label,
    required IconData icon,
    Color accentColor = accentBlue,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13, color: textSubMuted),
      prefixIcon: Icon(icon, color: textMuted, size: 18),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.12),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radiusMedium,
        borderSide: BorderSide(
          color: accentColor,
          width: 2,
        ),
      ),
    );
  }
}
