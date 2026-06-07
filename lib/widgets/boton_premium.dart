
import 'package:flutter/material.dart';

class BotonPremium extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final Color color;
  final bool conBrillo;

  const BotonPremium({
    super.key,
    this.onPressed,
    required this.label,
    this.icon,
    this.color = const Color(0xFFFF6600),
    this.conBrillo = true,
  });

  @override
  State<BotonPremium> createState() => _BotonPremiumState();
}

class _BotonPremiumState extends State<BotonPremium> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: widget.onPressed == null ? Colors.grey : widget.color,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: _isPressed ? 10 : 20,
                offset: const Offset(0, 8),
              ),
              if (widget.conBrillo)
                BoxShadow(
                  color: Colors.white.withOpacity(0.2),
                  blurRadius: 2,
                  spreadRadius: -2,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (widget.conBrillo)
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Positioned(
                      left: -100 + (_controller.value * 300),
                      child: Transform.rotate(
                        angle: 0.5,
                        child: Container(
                          width: 40,
                          height: 200,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withOpacity(0),
                                Colors.white.withOpacity(0.3),
                                Colors.white.withOpacity(0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                  ],
                  Flexible(
                    child: Text(
                      widget.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
