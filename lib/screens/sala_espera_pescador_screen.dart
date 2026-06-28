import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/core_business_logic.dart';
import '../widgets/boton_premium.dart';
import 'pescador_dashboard_screen.dart';

class SalaEsperaPescadorScreen extends StatefulWidget {
  final String cotizacionId;

  const SalaEsperaPescadorScreen({super.key, required this.cotizacionId});

  @override
  State<SalaEsperaPescadorScreen> createState() => _SalaEsperaPescadorScreenState();
}

class _SalaEsperaPescadorScreenState extends State<SalaEsperaPescadorScreen> with SingleTickerProviderStateMixin {
  String? _selectedOfertaId;
  final bool _yaAdjudicado = false;
  late AnimationController _radarController;
  Map<String, dynamic>? _cotizacionData;
  bool _expirado = false;

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _cargarDatosCotizacion();
  }

  Future<void> _cargarDatosCotizacion() async {
    final data = await Supabase.instance.client
        .from('cotizaciones')
        .select()
        .eq('id', widget.cotizacionId)
        .single();
    setState(() => _cotizacionData = data);
  }

  @override
  void dispose() {
    _radarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              'BUSCANDO CAPITANES',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 10),
            if (_cotizacionData != null) _buildCountdownTimer(),
            const SizedBox(height: 10),
            Text(
              _expirado ? '¡TIEMPO AGOTADO! Elige tu mejor opción' : 'Tu solicitud está navegando por el radar...',
              style: TextStyle(color: _expirado ? Colors.orange : Colors.white54, fontSize: 13, fontWeight: _expirado ? FontWeight.bold : FontWeight.normal),
            ),
            const Expanded(
              child: Center(
                child: RadarAnimation(), // Un widget de radar animado
              ),
            ),
            
            // LISTA DE OFERTAS EN TIEMPO REAL
            Container(
              height: 350,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('OFERTAS RECIBIDAS', 
                    style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 20),
                  Expanded(
                    child: StreamBuilder<List<Map<String, dynamic>>>(
                      stream: MasterConnectionSkill.escucharOfertas(widget.cotizacionId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        final ofertas = snapshot.data ?? [];
                        
                        if (ofertas.isEmpty) {
                          return const Center(
                            child: Text('Esperando la primera oferta...', 
                              style: TextStyle(color: Colors.white24, fontStyle: FontStyle.italic)),
                          );
                        }

                        return ListView.builder(
                          itemCount: ofertas.length,
                          itemBuilder: (context, index) {
                            final oferta = ofertas[index];
                            return _buildOfertaCard(oferta);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfertaCard(Map<String, dynamic> oferta) {
    final bool isSelected = _selectedOfertaId == oferta['id'];
    
    return GestureDetector(
      onTap: () => setState(() => _selectedOfertaId = oferta['id']),
      child: AnimatedScale(
        scale: isSelected ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected 
                      ? [const Color(0xFF0D47A1).withOpacity(0.3), const Color(0xFF00E676).withOpacity(0.1)]
                      : [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.03)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00E676).withOpacity(0.8) : Colors.white.withOpacity(0.1),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: const Color(0xFF00E676).withOpacity(0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar con Aura Dinámica
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF00E676), Color(0xFF2196F3)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00E676).withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFF001F3F),
                            child: const Icon(Icons.anchor_rounded, color: Colors.white, size: 30),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'EL GUIA YA',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildVerifiedBadge(),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: Colors.amber, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '4.9 (24 viajes)',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white60,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OFERTA TOTAL',
                              style: GoogleFonts.outfit(
                                color: Colors.white38,
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '\$${oferta['monto']}',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF00E676),
                                fontWeight: FontWeight.w900,
                                fontSize: 32,
                                shadows: [
                                  Shadow(
                                    color: const Color(0xFF00E676).withOpacity(0.5),
                                    blurRadius: 15,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        BotonPremium(
                          label: 'ACEPTAR',
                          onPressed: () => _aceptarOferta(oferta),
                          color: const Color(0xFF0D47A1),
                          icon: Icons.check_circle_outline,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifiedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFFFD700).withOpacity(0.3), const Color(0xFFFFD700).withOpacity(0.1)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 12),
          const SizedBox(width: 4),
          Text(
            'PRO',
            style: GoogleFonts.outfit(
              color: const Color(0xFFFFD700),
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _aceptarOferta(Map<String, dynamic> oferta) async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final pedidoId = await MasterConnectionSkill.cerrarTratoYA(
        oferta: oferta,
        pescadorId: userId,
      );

      Navigator.pop(context); // Cerrar loading
      
      // Navegar al Dashboard para ver el viaje en curso
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PescadorDashboardScreen()),
        (route) => false,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('? ¡Trato cerrado! El GPS ya está activo.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('? Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
  Widget _buildCountdownTimer() {
    if (_cotizacionData == null || _cotizacionData!['expira_en'] == null) return const SizedBox();
    
    final expiraEn = DateTime.parse(_cotizacionData!['expira_en']);
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, snapshot) {
        final ahora = DateTime.now();
        final diferencia = expiraEn.difference(ahora);
        
        if (diferencia.isNegative) {
          if (!_expirado) Future.microtask(() => setState(() => _expirado = true));
          return const Text('00:00:00', style: TextStyle(color: Colors.red, fontSize: 32, fontWeight: FontWeight.bold));
        }

        final h = diferencia.inHours.toString().padLeft(2, '0');
        final m = (diferencia.inMinutes % 60).toString().padLeft(2, '0');
        final s = (diferencia.inSeconds % 60).toString().padLeft(2, '0');

        return Text('$h:$m:$s', 
          style: const TextStyle(color: Color(0xFF00E676), fontSize: 40, fontWeight: FontWeight.bold, fontFamily: 'monospace'));
      },
    );
  }
}

class RadarAnimation extends StatefulWidget {
  const RadarAnimation({super.key});

  @override
  State<RadarAnimation> createState() => _RadarAnimationState();
}

class _RadarAnimationState extends State<RadarAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Círculos de onda expansiva
            ...List.generate(3, (index) {
              final progress = (_controller.value + index / 3) % 1.0;
              return Container(
                width: 300 * progress,
                height: 300 * progress,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF00E676).withOpacity(1 - progress),
                    width: 2,
                  ),
                ),
              );
            }),
            // Línea de barrido rotativa
            Transform.rotate(
              angle: _controller.value * 2 * 3.14159,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    center: Alignment.center,
                    colors: [
                      const Color(0xFF00E676).withOpacity(0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.1, 0.4],
                  ),
                ),
              ),
            ),
            // Centro
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF001F3F),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00E676).withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(Icons.sailing, color: Colors.white, size: 40),
            ),
          ],
        );
      },
    );
  }
}
