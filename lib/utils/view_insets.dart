import 'package:flutter/material.dart';

/// Insets para evitar que el contenido quede tapado por la barra del sistema
/// y el bottom navigation de los portales.
class ViewInsets {
  ViewInsets._();

  /// Padding extra del contenedor del bottom nav en portales.
  static const double portalNavContainerPadding = 12;

  /// Colchón visual adicional bajo listas scrollables.
  static const double scrollExtra = 12;

  /// Solo solapamiento del bottom nav de portal (sin barra del sistema).
  static double portalNavOverlap(BuildContext context, {double extra = scrollExtra}) {
    return kBottomNavigationBarHeight + portalNavContainerPadding + extra;
  }

  /// Altura reservada cuando hay bottom nav de portal (`extendBody: true`).
  static double portalBottomPadding(
    BuildContext context, {
    double extra = scrollExtra,
  }) {
    return MediaQuery.of(context).padding.bottom + portalNavOverlap(context, extra: extra);
  }

  /// Solo barra del sistema (pantallas push sin bottom nav de portal).
  static double systemBottomPadding(
    BuildContext context, {
    double extra = 16,
  }) {
    return MediaQuery.of(context).padding.bottom + extra;
  }

  static EdgeInsets scrollPadding(
    BuildContext context, {
    bool hasPortalBottomNav = true,
    double horizontal = 16,
    double top = 12,
    double extra = scrollExtra,
  }) {
    final bottom = hasPortalBottomNav
        ? portalBottomPadding(context, extra: extra)
        : systemBottomPadding(context, extra: extra);
    return EdgeInsets.fromLTRB(horizontal, top, horizontal, bottom);
  }

  /// Margen inferior más compacto para la Tienda (evita franja blanca excesiva).
  static double storeBottomPadding(BuildContext context) {
    return portalBottomPadding(context, extra: 0);
  }
}
