import 'package:flutter/material.dart';
import '../services/review_service.dart';

/// Pantalla/Formulario para calificar multidimensionalmente al Capitán.
class ReviewForm extends StatefulWidget {
  final String pedidoId;
  final String capitanNombre;
  final VoidCallback? onReviewSubmitted;

  const ReviewForm({
    super.key,
    required this.pedidoId,
    this.capitanNombre = 'Capitán',
    this.onReviewSubmitted,
  });

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  // Dimensiones de calificación (0 indica no seleccionado)
  double _puntualidad = 0;
  double _embarcacion = 0;
  double _guiaPesca = 0;
  double _trato = 0;
  double _equipamiento = 0;

  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // Verifica que todas las 5 dimensiones tengan calificación (mínimo 1 estrella)
  bool get _isValid =>
      _puntualidad > 0 &&
      _embarcacion > 0 &&
      _guiaPesca > 0 &&
      _trato > 0 &&
      _equipamiento > 0;

  Future<void> _submitReview() async {
    if (!_isValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Por favor califica todas las dimensiones del servicio.'),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ReviewService.submitReview(
        pedidoId: widget.pedidoId,
        puntualidad: _puntualidad,
        embarcacion: _embarcacion,
        guiaPesca: _guiaPesca,
        trato: _trato,
        equipamiento: _equipamiento,
        comentario: _commentController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⭐ ¡Calificación enviada exitosamente! Gracias por tu feedback.'),
            backgroundColor: Color(0xFF00E676),
            behavior: SnackBarBehavior.floating,
          ),
        );
        widget.onReviewSubmitted?.call();
        // Navegar automáticamente fuera de la pantalla (regresar al panel)
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al enviar calificación: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildDimensionRating({
    required String title,
    required String subtitle,
    required double currentRating,
    required IconData icon,
    required ValueChanged<double> onRatingChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF00E676), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final val = index + 1.0;
              final isSelected = val <= currentRating;
              return GestureDetector(
                onTap: () => onRatingChanged(val),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      isSelected ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 38,
                      color: isSelected
                          ? Colors.amber[400]
                          : Colors.white.withOpacity(0.18),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double ratingPromedio = _isValid
        ? (_puntualidad + _embarcacion + _guiaPesca + _trato + _equipamiento) / 5.0
        : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0A192F),
      appBar: AppBar(
        title: const Text(
          'Calificar Capitán',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        backgroundColor: const Color(0xFF0F223D),
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Fondo degradado sutil
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A192F), Color(0xFF0F223D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera de información del capitán
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.04),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00E676).withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: const Color(0xFF00E676).withOpacity(0.1),
                          child: const Icon(Icons.directions_boat_rounded,
                              color: Color(0xFF00E676), size: 32),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.capitanNombre,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Valoración multidimensional del servicio',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_isValid) ...[
                          const SizedBox(height: 14),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                '${ratingPromedio.toStringAsFixed(1)} / 5.0',
                                style: const TextStyle(
                                  color: Colors.amber,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sección de dimensiones
                  _buildDimensionRating(
                    title: 'Puntualidad',
                    subtitle: 'Cumplimiento de horarios de encuentro y retorno.',
                    currentRating: _puntualidad,
                    icon: Icons.access_time_rounded,
                    onRatingChanged: (val) => setState(() => _puntualidad = val),
                  ),
                  _buildDimensionRating(
                    title: 'Estado de Embarcación',
                    subtitle: 'Limpieza, orden y seguridad a bordo.',
                    currentRating: _embarcacion,
                    icon: Icons.directions_boat_rounded,
                    onRatingChanged: (val) => setState(() => _embarcacion = val),
                  ),
                  _buildDimensionRating(
                    title: 'Conocimiento de la Zona',
                    subtitle: 'Lectura del río, pique y guía de pesca.',
                    currentRating: _guiaPesca,
                    icon: Icons.explore_rounded,
                    onRatingChanged: (val) => setState(() => _guiaPesca = val),
                  ),
                  _buildDimensionRating(
                    title: 'Técnica de Pesca y Equipos',
                    subtitle: 'Calidad de cañas, reeles, líneas y carnadas.',
                    currentRating: _equipamiento,
                    icon: Icons.phishing_rounded,
                    onRatingChanged: (val) => setState(() => _equipamiento = val),
                  ),
                  _buildDimensionRating(
                    title: 'Atención al Cliente',
                    subtitle: 'Cordialidad, comunicación y buen trato del capitán.',
                    currentRating: _trato,
                    icon: Icons.people_outline_rounded,
                    onRatingChanged: (val) => setState(() => _trato = val),
                  ),

                  // Caja de comentarios
                  const Text(
                    'Comentarios',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cuéntanos tu experiencia de forma constructiva (opcional)...',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3), fontSize: 13),
                      fillColor: Colors.white.withOpacity(0.03),
                      filled: true,
                      contentPadding: const EdgeInsets.all(16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: Color(0xFF00E676), width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            BorderSide(color: Colors.white.withOpacity(0.08)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // Botón de guardado
                  ElevatedButton(
                    onPressed: (_isSubmitting || !_isValid) ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: Colors.white.withOpacity(0.08),
                      disabledForegroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: _isValid ? 6 : 0,
                      shadowColor: const Color(0xFF00E676).withOpacity(0.3),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'ENVIAR CALIFICACIÓN',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              letterSpacing: 0.5,
                              color: _isValid ? Colors.black : Colors.white24,
                            ),
                          ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
