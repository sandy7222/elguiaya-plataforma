import 'package:flutter/material.dart';

import '../utils/view_insets.dart';

/// Banner tappable de El Guía YA para volver al panel principal del portal.
class ElGuiaYaHomeButton extends StatelessWidget {
  final VoidCallback onTap;
  final double height;
  final String tooltip;
  final String semanticsLabel;

  const ElGuiaYaHomeButton({
    super.key,
    required this.onTap,
    this.height = 34,
    this.tooltip = 'Ir al Panel',
    this.semanticsLabel = 'Ir al Panel del Pescador',
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                ViewInsets.portalHeaderHorizontal,
                2,
                0,
                2,
              ),
              child: Image.asset(
                'assets/images/logo_elguiaya_header.png',
                height: height,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  'EL GUIA YA',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    fontSize: height * 0.45,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
