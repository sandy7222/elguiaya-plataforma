import 'package:flutter/material.dart';
import '../services/ia_router_state.dart';

/// Badge de estado IA para insertar en la AppBar.
///
/// Muestra visualmente el tier activo del router:
/// - 🟢 Cloud (Groq)  — verde
/// - 🟡 Offline        — amarillo
class IAStatusBadge extends StatefulWidget {
  const IAStatusBadge({super.key});

  @override
  State<IAStatusBadge> createState() => _IAStatusBadgeState();
}

class _IAStatusBadgeState extends State<IAStatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<IAEstado>(
      valueListenable: IARouterState.estado,
      builder: (context, estado, _) {
        final config = _configForEstado(estado);

        return AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulse.value,
              child: child,
            );
          },
          child: Tooltip(
            message: config.tooltip,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: config.color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: config.color.withOpacity(0.6),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: config.color.withOpacity(0.25),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: config.color,
                      boxShadow: [
                        BoxShadow(
                          color: config.color.withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    config.label,
                    style: TextStyle(
                      color: config.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  _BadgeConfig _configForEstado(IAEstado estado) {
    switch (estado) {
      case IAEstado.accionDirecta:
        return const _BadgeConfig(
          color: Color(0xFF00B0FF),
          label: 'Copiloto',
          tooltip: 'Acción directa contextual ejecutada por el copiloto',
        );
      case IAEstado.navegacion:
        return const _BadgeConfig(
          color: Color(0xFF00E5FF),
          label: 'Navegación',
          tooltip: 'Navegación de ruta asistida',
        );
      case IAEstado.cloud:
        return const _BadgeConfig(
          color: Color(0xFF00E676),
          label: 'IA Cloud',
          tooltip: 'Conectado a Groq Llama 3.3 (Cloud)',
        );
      case IAEstado.offline:
        return const _BadgeConfig(
          color: Color(0xFFFFC107),
          label: 'Offline',
          tooltip: 'Modo offline — El Guía Engine',
        );
      case IAEstado.contingencia:
        return const _BadgeConfig(
          color: Color(0xFFE57373),
          label: 'Contingencia',
          tooltip: 'Modo contingencia — Respuestas básicas locales',
        );
    }
  }
}

class _BadgeConfig {
  final Color color;
  final String label;
  final String tooltip;

  const _BadgeConfig({
    required this.color,
    required this.label,
    required this.tooltip,
  });
}
