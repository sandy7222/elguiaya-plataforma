import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Widget reutilizable que muestra el promedio de reputación de un usuario
/// (capitán o pescador) basándose en sus calificaciones recibidas.
///
/// Uso:
///   ReputacionBadgeWidget(userId: 'uuid', compact: false)
class ReputacionBadgeWidget extends StatefulWidget {
  final String userId;

  /// Si [compact] = true muestra solo el promedio numérico y 1 ancla/estrella.
  /// Si false, muestra la fila completa con anclas y contador.
  final bool compact;

  /// Color principal del badge (por defecto verde CapitanYA).
  final Color? color;

  const ReputacionBadgeWidget({
    super.key,
    required this.userId,
    this.compact = false,
    this.color,
  });

  @override
  State<ReputacionBadgeWidget> createState() => _ReputacionBadgeWidgetState();
}

class _ReputacionBadgeWidgetState extends State<ReputacionBadgeWidget> {
  double _promedio = 0;
  int _total = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(ReputacionBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _cargar();
  }

  Future<void> _cargar() async {
    if (widget.userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('calificaciones_viaje')
          .select('calificacion')
          .eq('calificado_id', widget.userId);

      if (!mounted) return;
      if ((res as List).isEmpty) {
        setState(() {
          _promedio = 0;
          _total = 0;
          _loading = false;
        });
        return;
      }
      final suma = res.fold<double>(
          0, (acc, row) => acc + (row['calificacion'] as num).toDouble());
      setState(() {
        _total = res.length;
        _promedio = suma / _total;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color get _badgeColor {
    if (widget.color != null) return widget.color!;
    if (_promedio >= 4) return const Color(0xFF00E676);
    if (_promedio >= 3) return Colors.amber;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 1.5, color: _badgeColor),
      );
    }

    if (_total == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white10),
        ),
        child: const Text(
          'Sin calificaciones',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
      );
    }

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.anchor_rounded, size: 14, color: _badgeColor),
          const SizedBox(width: 4),
          Text(
            _promedio.toStringAsFixed(1),
            style: TextStyle(
              color: _badgeColor,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            '(${ _total})',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      );
    }

    // Modo completo
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _badgeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _badgeColor.withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Fila de anclas
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = (i + 1) <= _promedio.round();
                  return Icon(
                    Icons.anchor_rounded,
                    size: 16,
                    color: filled ? _badgeColor : Colors.white.withOpacity(0.15),
                  );
                }),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _promedio.toStringAsFixed(1),
                    style: TextStyle(
                      color: _badgeColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$_total calificación${_total == 1 ? '' : 'es'}',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 10,
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
