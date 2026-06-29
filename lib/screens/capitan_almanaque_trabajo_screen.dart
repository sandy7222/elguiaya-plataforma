import 'package:flutter/material.dart';

import '../utils/view_insets.dart';
import '../widgets/bloqueo_almanaque_widget.dart';
import '../widgets/calendario_viajes_widget.dart';

class CapitanAlmanaqueTrabajoScreen extends StatelessWidget {
  final String capitanId;

  const CapitanAlmanaqueTrabajoScreen({
    super.key,
    required this.capitanId,
  });

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.orangeAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.orangeAccent,
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text(
          'ALMANAQUE DE TRABAJO',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: const Color(0xFF001F3F),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          ViewInsets.systemBottomPadding(context, extra: 24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionHeader('BLOQUEO DE ALMANAQUE', Icons.edit_calendar_rounded),
            Text(
              'Configurá tus días libres de navegación',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            BloqueoAlmanaqueWidget(capitanId: capitanId),
            const SizedBox(height: 28),
            _sectionHeader('ALMANAQUE DE RESERVAS', Icons.calendar_month_rounded),
            Text(
              'Viajes pagados y confirmados por fecha',
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 12),
            CalendarioViajesWidget(
              capitanId: capitanId,
              initialCollapsed: false,
            ),
          ],
        ),
      ),
    );
  }
}
