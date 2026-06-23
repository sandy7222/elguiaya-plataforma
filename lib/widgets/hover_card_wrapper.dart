import 'package:flutter/material.dart';

/// Un wrapper animado que detecta el cursor (hover) y aplica 
/// un efecto premium de elevación (lift) y zoom (scale) suave.
class HoverCardWrapper extends StatefulWidget {
  final Widget child;

  const HoverCardWrapper({
    super.key,
    required this.child,
  });

  @override
  State<HoverCardWrapper> createState() => _HoverCardWrapperState();
}

class _HoverCardWrapperState extends State<HoverCardWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        transform: _isHovered
            ? (Matrix4.identity()
                ..translate(0.0, -8.0, 0.0) // Eleva 8px hacia arriba
                ..scale(1.03))              // Escala un 3% para zoom
            : Matrix4.identity(),
        child: widget.child,
      ),
    );
  }
}
