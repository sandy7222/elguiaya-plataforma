import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/supabase_service.dart';

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
  Map<String, dynamic>? _datosCapitan;
  bool _loadingDetails = false;

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

    _datosCapitan = _datosDesdeOferta();
    _resolverDatosCapitan();
  }

  @override
  void didUpdateWidget(covariant OfertaCapitanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.oferta['id'] != widget.oferta['id'] ||
        oldWidget.oferta['capitan_id'] != widget.oferta['capitan_id']) {
      _datosCapitan = _datosDesdeOferta();
      _resolverDatosCapitan();
    }
  }

  bool _isValidUrl(String? value) {
    final url = value?.trim();
    return url != null && url.isNotEmpty && url.toLowerCase() != 'null';
  }

  Map<String, dynamic>? _profileFromOferta() {
    final rawProfiles = widget.oferta['profiles'];
    if (rawProfiles is List) {
      return rawProfiles.isNotEmpty
          ? Map<String, dynamic>.from(rawProfiles.first as Map)
          : null;
    }
    if (rawProfiles is Map) {
      return Map<String, dynamic>.from(rawProfiles);
    }
    return null;
  }

  Map<String, dynamic>? _datosDesdeOferta() {
    final profile = _profileFromOferta();
    final nombre = _firstValidText([
      widget.oferta['capitan_nombre']?.toString(),
      profile?['nombre']?.toString(),
      widget.oferta['nombre']?.toString(),
    ]);
    final avatar = _firstValidUrl([
      widget.oferta['capitan_avatar_url']?.toString(),
      widget.oferta['avatar_url']?.toString(),
      profile?['avatar_url']?.toString(),
    ]);
    final embarcacion = _firstValidUrl([
      widget.oferta['embarcacion_url']?.toString(),
      widget.oferta['barco_foto_url']?.toString(),
      profile?['embarcacion_url']?.toString(),
    ]);
    final barcoNombre = _firstValidText([
      widget.oferta['barco_nombre']?.toString(),
      widget.oferta['embarcacion_nombre']?.toString(),
    ]);

    if (!_isValidUrl(avatar) && !_isValidUrl(embarcacion) && nombre == null) {
      return null;
    }

    return {
      if (nombre != null) 'nombre': nombre,
      if (avatar != null) 'avatar_url': avatar,
      if (embarcacion != null) 'embarcacion_url': embarcacion,
      if (barcoNombre != null) 'barco_nombre': barcoNombre,
      'calificacion_promedio': widget.oferta['calificacion_promedio'],
      'viajes_realizados': widget.oferta['viajes_realizados'],
      'bio_pescador': widget.oferta['bio_pescador'],
    };
  }

  Future<void> _resolverDatosCapitan() async {
    final local = _datosDesdeOferta();
    if (_isValidUrl(local?['avatar_url']?.toString()) &&
        _isValidUrl(local?['embarcacion_url']?.toString()) &&
        _firstValidText([local?['nombre']?.toString()]) != null) {
      if (mounted) setState(() => _datosCapitan = local);
      return;
    }

    final capitanId = widget.oferta['capitan_id']?.toString();
    if (capitanId == null || capitanId.isEmpty) return;

    if (mounted) setState(() => _loadingDetails = true);

    try {
      final enriquecido = await SupabaseService.enrichPresupuestoParaTarjeta(
        widget.oferta,
      );
      final rpcNombre = enriquecido['capitan_nombre']?.toString();
      final rpcAvatar = enriquecido['capitan_avatar_url']?.toString() ??
          enriquecido['avatar_url']?.toString();
      final rpcEmbarcacion = enriquecido['embarcacion_url']?.toString();

      if (mounted) {
        setState(() {
          _datosCapitan = {
            'nombre': _firstValidText([rpcNombre, local?['nombre']?.toString()]) ??
                'Capitán',
            'avatar_url': _firstValidUrl([
              rpcAvatar,
              local?['avatar_url']?.toString(),
            ]),
            'embarcacion_url': _firstValidUrl([
              rpcEmbarcacion,
              local?['embarcacion_url']?.toString(),
            ]),
            'barco_nombre': _firstValidText([
                  enriquecido['barco_nombre']?.toString(),
                  local?['barco_nombre']?.toString(),
                ]) ??
                'Embarcación Principal',
            'calificacion_promedio': enriquecido['calificacion_promedio'] ??
                local?['calificacion_promedio'],
            'viajes_realizados': enriquecido['viajes_realizados'] ??
                local?['viajes_realizados'],
            'bio_pescador':
                enriquecido['bio_pescador'] ?? local?['bio_pescador'],
          };
          _loadingDetails = false;
        });
      }
    } catch (e) {
      debugPrint('Error resolving captain card data: $e');
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final datos = _datosCapitan ?? _datosDesdeOferta() ?? const {};

    final capitanNombre =
        datos['nombre']?.toString() ?? 'Capitán';
    final capitanFoto = datos['avatar_url']?.toString();
    final barcoFoto = datos['embarcacion_url']?.toString();
    final barcoNombre =
        datos['barco_nombre']?.toString() ?? 'Embarcación Principal';

    final monto = (widget.oferta['monto'] as num?)?.toDouble() ??
        (widget.oferta['monto_total'] as num?)?.toDouble() ??
        (widget.oferta['total'] as num?)?.toDouble() ??
        0.0;
    final detalles = widget.oferta['detalles']?.toString() ??
        datos['bio_pescador']?.toString() ??
        widget.oferta['bio_pescador']?.toString() ??
        'Servicio de guía profesional (Contacto privado hasta el pago)';

    final calificacion =
        (datos['calificacion_promedio'] as num?)?.toDouble() ??
            (widget.oferta['calificacion_promedio'] as num?)?.toDouble() ??
            (widget.oferta['calificacion'] as num?)?.toDouble();
    final viajesRealizados =
        (datos['viajes_realizados'] as num?)?.toInt() ??
            (widget.oferta['viajes_realizados'] as num?)?.toInt();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2540),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              SizedBox(
                height: 140,
                width: double.infinity,
                child: _isValidUrl(barcoFoto)
                    ? Image.network(
                        barcoFoto!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: 140,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return _buildBoatPlaceholder(loading: true);
                        },
                        errorBuilder: (_, __, ___) => _buildBoatPlaceholder(),
                      )
                    : _buildBoatPlaceholder(loading: _loadingDetails),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.55),
                      ],
                      stops: const [0.45, 1.0],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: 14,
                child: Row(
                  children: [
                    const Icon(Icons.directions_boat_rounded,
                        color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      barcoNombre,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E676).withOpacity(0.6),
                    ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E676),
                      width: 2.5,
                    ),
                  ),
                  child: ClipOval(
                    child: SizedBox(
                      width: 52,
                      height: 52,
                      child: _buildAvatarWidget(capitanFoto, capitanNombre),
                    ),
                  ),
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
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.verified,
                                    color: Colors.white, size: 11),
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
                          if (calificacion != null && calificacion > 0) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.star_rounded,
                                color: Color(0xFFFFD700), size: 14),
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
                          if (viajesRealizados != null &&
                              viajesRealizados > 0) ...[
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
                        : FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.visibility_rounded,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 6),
                                Text(
                                  'VER DETALLES Y RESERVAR',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String? _firstValidUrl(List<String?> candidates) {
    for (final candidate in candidates) {
      if (_isValidUrl(candidate)) return candidate;
    }
    return null;
  }

  String? _firstValidText(List<String?> candidates) {
    for (final candidate in candidates) {
      final text = candidate?.trim();
      if (text != null &&
          text.isNotEmpty &&
          text.toLowerCase() != 'null' &&
          text != 'Capitán') {
        return text;
      }
    }
    return null;
  }

  Widget _buildAvatarWidget(String? capitanFoto, String capitanNombre) {
    if (_loadingDetails && !_isValidUrl(capitanFoto)) {
      return Container(
        color: const Color(0xFF16324F),
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white54,
            ),
          ),
        ),
      );
    }

    if (_isValidUrl(capitanFoto)) {
      return Image.network(
        capitanFoto!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildAvatarFallback(capitanNombre),
      );
    }

    return _buildAvatarFallback(capitanNombre);
  }

  Widget _buildAvatarFallback(String capitanNombre) {
    final inicial = capitanNombre.trim().isNotEmpty
        ? capitanNombre.trim()[0].toUpperCase()
        : '?';

    return Container(
      color: const Color(0xFF16324F),
      alignment: Alignment.center,
      child: Text(
        inicial,
        style: GoogleFonts.outfit(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildBoatPlaceholder({bool loading = false}) {
    return Container(
      color: const Color(0xFF001830),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF00E676),
                ),
              )
            else
              Icon(
                Icons.directions_boat_rounded,
                color: Colors.white.withOpacity(0.15),
                size: 48,
              ),
            const SizedBox(height: 6),
            Text(
              loading ? 'Cargando embarcación...' : 'Sin foto de embarcación',
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
