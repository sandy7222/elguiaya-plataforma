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
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.03).animate(
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
    // Datos del capitán — vienen de profiles join
    final rawProfiles = widget.oferta['profiles'];
    final capitanData = rawProfiles is List
        ? (rawProfiles.isNotEmpty ? rawProfiles.first as Map<String, dynamic>? : null)
        : rawProfiles as Map<String, dynamic>?;

    final capitanNombre = capitanData?['nombre']?.toString() ?? 'Capitán';
    final capitanFoto = capitanData?['avatar_url']?.toString();
    
    // Foto de la embarcación — viene del join con guias
    final barcoFoto = widget.oferta['embarcacion_url']?.toString()
        ?? widget.oferta['barco_foto_url']?.toString();
    final barcoNombre = widget.oferta['barco_nombre']?.toString()
        ?? widget.oferta['embarcacion_nombre']?.toString()
        ?? 'Embarcación Principal';

    final monto = (widget.oferta['monto'] as num?)?.toDouble() ?? 0.0;
    final detalles = widget.oferta['detalles']?.toString()
        ?? widget.oferta['bio_pescador']?.toString()
        ?? 'Servicio de guía profesional (Contacto privado hasta el pago)';
    
    final calificacion = (widget.oferta['calificacion_promedio'] as num?)?.toDouble()
        ?? (widget.oferta['calificacion'] as num?)?.toDouble();
    final viajesRealizados = (widget.oferta['viajes_realizados'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── FOTO DE LA LANCHA (banner superior) ──────────────────
                Stack(
                  children: [
                    // Imagen de la lancha como banner
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(23),
                        topRight: Radius.circular(23),
                      ),
                      child: Container(
                        height: 140,
                        width: double.infinity,
                        color: const Color(0xFF001830),
                        child: barcoFoto != null
                            ? Image.network(
                                barcoFoto,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildBoatPlaceholder(),
                              )
                            : _buildBoatPlaceholder(),
                      ),
                    ),

                    // Degradado sobre la imagen para legibilidad
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(23),
                          topRight: Radius.circular(23),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.6),
                              ],
                              stops: const [0.4, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Nombre de la embarcación encima del degradado
                    Positioned(
                      bottom: 10,
                      left: 14,
                      child: Row(
                        children: [
                          const Icon(Icons.directions_boat_rounded, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            barcoNombre,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              shadows: [
                                Shadow(color: Colors.black.withOpacity(0.5), blurRadius: 4),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Precio flotando arriba a la derecha
                    Positioned(
                      top: 10,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFF00E676).withOpacity(0.6)),
                        ),
                        child: Text(
                          '\$${monto.toStringAsFixed(0)}',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF00E676),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // ── CABECERA: AVATAR + NOMBRE + BADGE ────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar del capitán con borde brillante
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF00E676),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E676).withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white12,
                          backgroundImage: capitanFoto != null
                              ? NetworkImage(capitanFoto)
                              : null,
                          child: capitanFoto == null
                              ? const Icon(Icons.person, color: Colors.white60, size: 26)
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nombre + badge verificado
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              capitanNombre,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Badge verificado
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.verified, color: Colors.white, size: 11),
                                      const SizedBox(width: 3),
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
                                // Calificación si existe
                                if (calificacion != null && calificacion > 0) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 14),
                                  const SizedBox(width: 2),
                                  Text(
                                    calificacion.toStringAsFixed(1),
                                    style: GoogleFonts.outfit(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                // Cantidad de viajes si existe
                                if (viajesRealizados != null && viajesRealizados > 0) ...[
                                  const SizedBox(width: 6),
                                  Text(
                                    '· $viajesRealizados viajes',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── DESCRIPCIÓN ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    detalles,
                    style: GoogleFonts.outfit(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                const SizedBox(height: 16),

                // ── BOTÓN VER DETALLES ────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0066FF), Color(0xFF00C6FF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0066FF).withOpacity(0.35),
                              blurRadius: 10,
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
                          child: widget.isProcessing
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.visibility_rounded, color: Colors.white, size: 18),
                                    const SizedBox(width: 10),
                                    Text(
                                      'VER DETALLES Y RESERVAR',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
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

  Widget _buildBoatPlaceholder() {
    return Container(
      color: const Color(0xFF001830),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.directions_boat_rounded,
              color: Colors.white.withOpacity(0.15),
              size: 48,
            ),
            const SizedBox(height: 6),
            Text(
              'Sin foto de embarcación',
              style: GoogleFonts.outfit(
                color: Colors.white24,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
