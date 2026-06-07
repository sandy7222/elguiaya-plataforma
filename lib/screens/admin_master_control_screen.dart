import 'package:flutter/material.dart';
import '../widgets/failsafe_background.dart';

class AdminMasterControlScreen extends StatelessWidget {
  const AdminMasterControlScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FailsafeBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _buildMainMetrics(),
                      const SizedBox(height: 24),
                      _buildAlertsSection(),
                      const SizedBox(height: 24),
                      _buildRecentActivity(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CONTROL MAESTRO',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hola, Seba',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMainMetrics() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            title: 'Viajes del Día',
            value: '12',
            icon: Icons.sailing,
            color: Colors.blueAccent,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildMetricCard(
            title: 'Recaudación',
            value: '\$456.800',
            icon: Icons.account_balance_wallet,
            color: Colors.greenAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.15),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
              const SizedBox(width: 12),
              const Text(
                'ALERTAS DE SEGURIDAD',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAlertItem('Capitán Gómez: Matrícula vencida'),
          _buildAlertItem('Capitán López: Seguro no cargado'),
          _buildAlertItem('Capitán Pérez: Documento ilegible'),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          const Icon(Icons.chevron_right, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVIDAD RECIENTE',
            style: TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 20),
          _buildActivityItem(
            icon: Icons.check_circle,
            color: Colors.greenAccent,
            title: 'Pago Completado',
            subtitle: 'Juan Pérez - \$150.000',
            time: 'Hace 10 min',
          ),
          _buildActivityItem(
            icon: Icons.sailing,
            color: Colors.blueAccent,
            title: 'Viaje Aceptado',
            subtitle: 'Capitán Sandy - Excursión Dorado',
            time: 'Hace 25 min',
          ),
          _buildActivityItem(
            icon: Icons.request_quote,
            color: Colors.orangeAccent,
            title: 'Nueva Cotización',
            subtitle: 'María López - Alquiler Lancha',
            time: 'Hace 1 hora',
          ),
        ],
      ),
    );
  }

  Widget _buildActivityItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxBoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: const TextStyle(color: Colors.white30, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

extension BoxBoxShape on BoxShape {
  static const BoxShape circle = BoxShape.circle;
}
