import 'package:flutter/material.dart';

/// Colores del panel administrador alineados al logotipo El Guía YA.
class AdminTheme {
  AdminTheme._();

  /// Fondo del PNG del cartel (muestreado del asset con gotero: #000513).
  static const Color logoBannerBackground = Color(0xFF000513);

  /// Azul principal del panel admin (igual al cartel).
  static const Color deepNavy = logoBannerBackground;

  /// Variante más oscura para gradientes y barra inferior.
  static const Color deepNavyDark = Color(0xFF00040F);

  /// Superficie oscura (drawer, sheets, app bar).
  static const Color deepNavySurface = Color(0xFF000614);

  static const LinearGradient screenGradient = LinearGradient(
    colors: [deepNavy, deepNavyDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient drawerHeaderGradient = LinearGradient(
    colors: [deepNavy, deepNavySurface],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
