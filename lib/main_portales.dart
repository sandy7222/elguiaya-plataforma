

import 'package:flutter/material.dart';

import 'screens/portal_capitan_fixed.dart';
import 'screens/portal_pescador_fixed.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const CapitanYA());
}

class CapitanYA extends StatelessWidget {
  const CapitanYA({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Capitan YA - Portales Integrados',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        primaryColor: const Color(0xFF002366),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF002366),
          foregroundColor: Colors.white,
        ),
      ),
      home: const PortalSelectorScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PortalSelectorScreen extends StatelessWidget {
  const PortalSelectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0066FF), Color(0xFFFF6600)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.sailing,
              color: Color(0xFFFFFFFF),
              size: 80,
            ),
            const SizedBox(height: 20),
            const Text(
              'Capitan YA',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Sistema de Cotizaciones Integrado',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 60),
            
            // Botones de portal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                children: [
                  _buildPortalButton(
                    context,
                    'Portal del Capitan',
                    'Gestionar solicitudes y cotizaciones',
                    Icons.sailing,
                    const PortalCapitanScreen(),
                  ),
                  const SizedBox(height: 20),
                  _buildPortalButton(
                    context,
                    'Portal del Pescador',
                    'Solicitar cotizaciones de viajes',
                    Icons.sailing,
                    const PortalPescadorScreen(),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            const Text(
              'Selecciona tu portal para continuar',
              style: TextStyle(
                color: Color(0xFFFFFFFF),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortalButton(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Widget destination,
  ) {
    return Container(
      width: double.infinity,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => destination,
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0066FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFFFFFFF),
                    size: 30,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A).withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Color(0xFF0066FF),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
