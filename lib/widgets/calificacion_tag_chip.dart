import 'package:flutter/material.dart';

/// Cápsula de etiqueta para diálogos de calificación.
/// Colores explícitos para evitar que el tema Material pise el contraste.
class CalificacionTagChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final Color accentColor;

  const CalificacionTagChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.accentColor = const Color(0xFF00E676),
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? const Color(0xFF041018) : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onSelected(!selected),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? accentColor : const Color(0xFF1A2F45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? accentColor
                  : Colors.white.withOpacity(0.4),
              width: selected ? 2 : 1,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: accentColor.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
