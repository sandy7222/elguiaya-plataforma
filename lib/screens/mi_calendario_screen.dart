import 'package:flutter/material.dart';

import '../widgets/bloqueo_almanaque_widget.dart';

/// Pantalla legacy de bloqueo — delega en [BloqueoAlmanaqueWidget].
class MiCalendarioScreen extends StatelessWidget {
  const MiCalendarioScreen({super.key});

  static const Color _fondoOscuro = Color(0xFF001F3F);
  static const Color _blancoPuro = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.calendar_today, color: _blancoPuro),
            const SizedBox(width: 8),
            Text(
              'Bloqueo de Almanaque',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: BloqueoAlmanaqueWidget(),
      ),
    );
  }
}
