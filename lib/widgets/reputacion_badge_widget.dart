import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Capitanes se califican con anclas ?; pescadores con anzuelos ??.
enum ReputacionTipo { capitan, pescador }

/// Widget reutilizable que muestra el promedio de reputación de un usuario.
///
/// Uso:
///   ReputacionBadgeWidget(userId: 'uuid', tipo: ReputacionTipo.pescador)
class ReputacionBadgeWidget extends StatefulWidget {
  final String userId;
  final ReputacionTipo tipo;

  /// Si [compact] = true muestra solo el promedio numérico y 1 icono.
  /// Si false, muestra la fila completa con iconos y contador.
  final bool compact;

  /// Color principal del badge (por defecto verde El Guia YA).
  final Color? color;

  const ReputacionBadgeWidget({
    super.key,
    required this.userId,
    this.tipo = ReputacionTipo.capitan,
    this.compact = false,
    this.color,
  });

  @override
  State<ReputacionBadgeWidget> createState() => _ReputacionBadgeWidgetState();
}

class _ReputacionBadgeWidgetState extends State<ReputacionBadgeWidget> {
  double _promedio = 0;
  int _total = 0;
  String _nivel = 'novato';
  bool _loading = true;

  IconData get _iconoFilled =>
      widget.tipo == ReputacionTipo.pescador
          ? Icons.phishing_rounded
          : Icons.anchor_rounded;

  IconData get _iconoOutline =>
      widget.tipo == ReputacionTipo.pescador
          ? Icons.phishing_outlined
          : Icons.anchor_outlined;

  String get _etiquetaTipo =>
      widget.tipo == ReputacionTipo.pescador ? 'anzuelos' : 'anclas';

  String get _rolCalificador =>
      widget.tipo == ReputacionTipo.pescador ? 'capitan' : 'pescador';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(ReputacionBadgeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId || oldWidget.tipo != widget.tipo) {
      _cargar();
    }
  }

  Future<void> _cargar() async {
    if (widget.userId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      // 1) Intentar tabla de reputación cacheada
      final tabla = widget.tipo == ReputacionTipo.pescador
          ? 'reputacion_pescadores'
          : 'reputacion_capitanes';
      final idCol = widget.tipo == ReputacionTipo.pescador
          ? 'pescador_id'
          : 'capitan_id';

      try {
        final rep = await Supabase.instance.client
            .from(tabla)
            .select('calificacion_promedio, total_calificaciones, nivel_reputacion')
            .eq(idCol, widget.userId)
            .maybeSingle();

        if (rep != null && (rep['total_calificaciones'] as num? ?? 0) > 0) {
          if (!mounted) return;
          setState(() {
            _promedio =
                (rep['calificacion_promedio'] as num?)?.toDouble() ?? 0;
            _total = (rep['total_calificaciones'] as num?)?.toInt() ?? 0;
            _nivel = rep['nivel_reputacion']?.toString() ?? 'novato';
            _loading = false;
          });
          return;
        }
      } catch (_) {}

      // 2) Fallback: calcular desde calificaciones_viaje filtradas por rol
      final res = await Supabase.instance.client
          .from('calificaciones_viaje')
          .select('calificacion')
          .eq('calificado_id', widget.userId)
          .eq('calificador_rol', _rolCalificador);

      if (!mounted) return;
      if ((res as List).isEmpty) {
        setState(() {
          _promedio = 0;
          _total = 0;
          _nivel = 'novato';
          _loading = false;
        });
        return;
      }
      final suma = res.fold<double>(
          0, (acc, row) => acc + (row['calificacion'] as num).toDouble());
      setState(() {
        _total = res.length;
        _promedio = suma / _total;
        _nivel = _calcularNivel(_promedio, _total);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _calcularNivel(double promedio, int totalCalifs) {
    if (promedio >= 4.8 && totalCalifs >= 50) return 'elite';
    if (promedio >= 4.5 && totalCalifs >= 20) return 'experto';
    if (promedio >= 4.0 && totalCalifs >= 10) return 'intermedio';
    return 'novato';
  }

  Color get _badgeColor {
    if (widget.color != null) return widget.color!;
    if (_promedio >= 4) return const Color(0xFF00E676);
    if (_promedio >= 3) return Colors.amber;
    return Colors.redAccent;
  }

  String get _nivelLabel {
    switch (_nivel) {
      case 'elite':
        return 'Élite';
      case 'experto':
        return 'Experto';
      case 'intermedio':
        return 'Intermedio';
      default:
        return 'Novato';
    }
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
        child: Text(
          'Sin $_etiquetaTipo aún',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
        ),
      );
    }

    if (widget.compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconoFilled, size: 14, color: _badgeColor),
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
            '($_total)',
            style: TextStyle(
              color: Colors.white.withOpacity(0.4),
              fontSize: 10,
            ),
          ),
        ],
      );
    }

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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  final filled = (i + 1) <= _promedio.round();
                  return Icon(
                    filled ? _iconoFilled : _iconoOutline,
                    size: 16,
                    color:
                        filled ? _badgeColor : Colors.white.withOpacity(0.15),
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
                    '$_total · $_nivelLabel',
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
