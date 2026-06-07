

import 'package:flutter/material.dart';
import 'billetera_capitan_screen.dart';
import 'cotizaciones_capitan_screen.dart';
import 'inbox_capitan_screen.dart';

class PortalCapitanScreen extends StatefulWidget {
  const PortalCapitanScreen({super.key});

  @override
  State<PortalCapitanScreen> createState() => _PortalCapitanScreenState();
}

class _PortalCapitanScreenState extends State<PortalCapitanScreen> {
  int _selectedIndex = 0;

  // Colores CapitanYA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _naranjaIntenso = Color(0xFFFF6600);

  final List<Widget> _screens = [
    const InboxCapitanScreen(),
    const CotizacionesCapitanScreen(),
    const BilleteraCapitanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.sailing, color: _blancoPuro, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Portal del Capitan',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _fondoOscuro,
          border: Border(
            top: BorderSide(color: _blancoPuro.withOpacity(0.2)),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) {
            setState(() => _selectedIndex = index);
          },
          backgroundColor: _fondoOscuro,
          selectedItemColor: _azulVibrante,
          unselectedItemColor: _blancoPuro.withOpacity(0.6),
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.inbox),
              label: 'Solicitudes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long),
              label: 'Cotizaciones',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet),
              label: 'Billetera',
            ),
          ],
        ),
      ),
    );
  }
}
