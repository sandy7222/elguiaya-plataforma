import 'package:flutter/material.dart';

/// Banner tappable de El Guía YA para volver al Panel del Pescador.
class ElGuiaYaHomeButton extends StatelessWidget {
  final VoidCallback onTap;
  final double height;

  const ElGuiaYaHomeButton({
    super.key,
    required this.onTap,
    this.height = 34,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Ir al Panel del Pescador',
      child: Tooltip(
        message: 'Ir al Panel',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
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
