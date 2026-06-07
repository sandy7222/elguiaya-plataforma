import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/viaje_lifecycle_service.dart';

/// Diálogo para que el Capitán califique al Pescador al finalizar un viaje.
class CalificacionPescadorDialog extends StatefulWidget {
  final String pedidoId;
  final String capitanId;
  final String pescadorId;
  final String pescadorNombre;
  final String codigoViaje;
  final VoidCallback? onCalificacionGuardada;

  const CalificacionPescadorDialog({
    super.key,
    required this.pedidoId,
    required this.capitanId,
    required this.pescadorId,
    required this.pescadorNombre,
    required this.codigoViaje,
    this.onCalificacionGuardada,
  });

  /// Método estático de conveniencia para mostrar el diálogo.
  static Future<void> mostrar({
    required BuildContext context,
    required String pedidoId,
    required String capitanId,
    required String pescadorId,
    required String pescadorNombre,
    required String codigoViaje,
    VoidCallback? onCalificacionGuardada,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => CalificacionPescadorDialog(
        pedidoId: pedidoId,
        capitanId: capitanId,
        pescadorId: pescadorId,
        pescadorNombre: pescadorNombre,
        codigoViaje: codigoViaje,
        onCalificacionGuardada: onCalificacionGuardada,
      ),
    );
  }

  @override
  State<CalificacionPescadorDialog> createState() =>
      _CalificacionPescadorDialogState();
}

class _CalificacionPescadorDialogState
    extends State<CalificacionPescadorDialog> {
  int _rating = 5;
  final Set<String> _selectedTags = {};
  final TextEditingController _commentController = TextEditingController();
  bool _isSaving = false;
  bool _reportarIncidente = false;

  static const List<String> _etiquetas = [
    'Puntual al embarque',
    'Respetuoso',
    'Buen pagador',
    'Sin incidentes',
    'Lo recomendaría',
    'Cuidó la embarcación',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() => _isSaving = true);
    try {
      await ViajeLifecycleService.calificarPescador(
        pedidoId: widget.pedidoId,
        capitanId: widget.capitanId,
        pescadorId: widget.pescadorId,
        calificacion: _rating,
        comentario: _commentController.text.trim(),
        etiquetas: [
          ..._selectedTags,
          if (_reportarIncidente) 'INCIDENTE_REPORTADO',
        ],
      );
      if (mounted) {
        Navigator.pop(context);
        widget.onCalificacionGuardada?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⭐ Calificación guardada. ¡Gracias!'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A192F).withOpacity(0.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.star_rounded, color: Color(0xFF00E676), size: 26),
                      SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          'Calificar al Pescador',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Código del viaje
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF00E676).withOpacity(0.3)),
                    ),
                    child: Text(
                      widget.codigoViaje,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.pescadorNombre,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),

                  // Anclas de calificación
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final val = index + 1;
                      final isSelected = val <= _rating;
                      return GestureDetector(
                        onTap: () => setState(() => _rating = val),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF00E676)
                                            .withOpacity(0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : [],
                            ),
                            child: Icon(
                              Icons.anchor_rounded,
                              size: 36,
                              color: isSelected
                                  ? const Color(0xFF00E676)
                                  : Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 20),

                  // Etiquetas rápidas
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: _etiquetas.map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return ChoiceChip(
                        label: Text(tag),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _selectedTags.add(tag);
                            } else {
                              _selectedTags.remove(tag);
                            }
                          });
                        },
                        selectedColor:
                            const Color(0xFF00E676).withOpacity(0.2),
                        backgroundColor: Colors.white.withOpacity(0.04),
                        labelStyle: TextStyle(
                          color: isSelected
                              ? const Color(0xFF00E676)
                              : Colors.white.withOpacity(0.7),
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF00E676).withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Comentario
                  TextField(
                    controller: _commentController,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Comentario adicional (opcional)...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3), fontSize: 13),
                      fillColor: Colors.white.withOpacity(0.04),
                      filled: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: Color(0xFF00E676)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Switch de incidente
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _reportarIncidente
                          ? Colors.redAccent.withOpacity(0.1)
                          : Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _reportarIncidente
                            ? Colors.redAccent.withOpacity(0.4)
                            : Colors.white.withOpacity(0.08),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: _reportarIncidente
                              ? Colors.redAccent
                              : Colors.white38,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Reportar incidente con este pescador',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ),
                        Switch(
                          value: _reportarIncidente,
                          onChanged: (v) =>
                              setState(() => _reportarIncidente = v),
                          activeColor: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Botones
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed:
                            _isSaving ? null : () => Navigator.pop(context),
                        child: Text(
                          'Omitir por ahora',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.black),
                              )
                            : const Text(
                                'GUARDAR CALIFICACIÓN',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
