
import 'dart:ui';
import 'package:flutter/material.dart';
import '../widgets/boton_premium.dart';

class ViajeConfirmadoScreen extends StatelessWidget {
  final Map<String, dynamic> datosViaje;
  final Map<String, dynamic>? datosEnvio;
  final List<Map<String, dynamic>> manifiesto;

  const ViajeConfirmadoScreen({
    super.key,
    required this.datosViaje,
    this.datosEnvio,
    required this.manifiesto,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F), // Azul Profundo
      body: Stack(
        children: [
          // Fondo con Blur
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: NetworkImage('https://images.unsplash.com/photo-1544551763-47a0159c9638?q=80&w=2070&auto=format&fit=crop'),
                fit: BoxFit.cover,
                opacity: 0.2,
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Icono de Éxito con Aura
                  const Icon(Icons.check_circle, color: Color(0xFF00E676), size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    '¡VIAJE CONFIRMADO!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Card Glassmorphism Resumen
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(32),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSeccion('PASAJEROS DECLARADOS', Icons.people),
                                ...manifiesto.map((p) => Text('• ${p['nombre']} (DNI: ${p['dni']})', 
                                  style: const TextStyle(color: Colors.white70, fontSize: 14))),
                                
                                if (datosEnvio != null) ...[
                                  const SizedBox(height: 24),
                                  _buildSeccion('LOGÍSTICA DE ENVÍO', Icons.local_shipping),
                                  Text('${datosEnvio!['calle']} ${datosEnvio!['altura']}', 
                                    style: const TextStyle(color: Colors.white70)),
                                  Text(datosEnvio!['localidad'], 
                                    style: const TextStyle(color: Colors.white70)),
                                ],
                                
                                const SizedBox(height: 24),
                                _buildSeccion('ESTADO DEL RADAR', Icons.radar),
                                const Text('Esperando ignición del Capitán...', 
                                  style: TextStyle(color: Color(0xFF00E676), fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  BotonPremium(
                    label: 'IR A MIS VIAJES',
                    onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                    color: const Color(0xFF0D47A1),
                    icon: Icons.map,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccion(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF00E676), size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
