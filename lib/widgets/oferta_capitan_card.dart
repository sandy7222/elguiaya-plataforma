import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class OfertaCapitanCard extends StatefulWidget {
  final Map<String, dynamic> oferta;
  final VoidCallback onAccept;
  final bool isProcessing;

  const OfertaCapitanCard({
    super.key,
    required this.oferta,
    required this.onAccept,
    this.isProcessing = false,
  });

  @override
  State<OfertaCapitanCard> createState() => _OfertaCapitanCardState();
}

class _OfertaCapitanCardState extends State<OfertaCapitanCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
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
    final capitanData = widget.oferta['profiles'] as Map<String, dynamic>?;
    final capitanNombre = capitanData?['nombre'] ?? 'Capitán';
    final capitanFoto = capitanData?['avatar_url'];
    final barcoNombre = widget.oferta['barco_nombre'] ?? 'Embarcación Principal';
    final barcoFoto = widget.oferta['barco_foto_url'] ?? widget.oferta['embarcacion_url'];
    final monto = (widget.oferta['monto'] as num?)?.toDouble() ?? 0.0;
    final detalles = widget.oferta['detalles'] ?? 'Servicio de pesca profesional con equipamiento completo.';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabecera: Foto, Nombre y Badge
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white24,
                      backgroundImage: capitanFoto != null ? NetworkImage(capitanFoto) : null,
                      child: capitanFoto == null ? const Icon(Icons.person, color: Colors.white) : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            capitanNombre,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'VERIFICADO',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Precio en la esquina superior
                    Text(
                      '\$${monto.toStringAsFixed(0)}',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFF00E676),
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(color: Colors.white10, height: 1),
                ),

                // Foto de la embarcación (Si existe) o Placeholder náutico
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.black26,
                    image: barcoFoto != null 
                      ? DecorationImage(image: NetworkImage(barcoFoto), fit: BoxFit.cover)
                      : null,
                  ),
                  child: barcoFoto == null 
                    ? const Center(child: Icon(Icons.directions_boat, color: Colors.white24, size: 40))
                    : null,
                ),

                const SizedBox(height: 12),

                // Info: Barco y Detalles
                Row(
                  children: [
                    const Icon(Icons.anchor, color: Colors.white70, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      barcoNombre,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  detalles,
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 20),

                // Botón 'Zarpamos' -> Ahora lleva al resumen
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0066FF), Color(0xFF00E676)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0066FF).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: widget.isProcessing ? null : widget.onAccept,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.visibility, color: Colors.white, size: 20),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              'VER DETALLES Y RESERVAR',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

