import 'package:flutter/material.dart';

/// Pantalla de administración de Reclamos de Tienda.
///
/// NOTA: Reconstrucción mínima. El archivo original nunca fue commiteado al
/// repositorio (existía solo en la máquina del desarrollador), por lo que esta
/// versión provee la superficie necesaria para compilar y navegar. Reemplazar
/// por la implementación real (listado/gestión de reclamos de la tienda) cuando
/// esté disponible.
class AdminReclamosTiendaScreen extends StatelessWidget {
  final bool embedMode;
  const AdminReclamosTiendaScreen({super.key, this.embedMode = false});

  static const Color _azulNautico = Color(0xFF001F3F);

  @override
  Widget build(BuildContext context) {
    final contenido = Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.report_gmailerrorred_outlined,
                size: 72, color: _azulNautico),
            const SizedBox(height: 16),
            const Text(
              'Reclamos de Tienda',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Módulo en preparación. Acá se gestionarán los reclamos de los '
              'pedidos de la tienda.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );

    return Scaffold(
      backgroundColor: embedMode ? Colors.transparent : const Color(0xFFF5F7FA),
      appBar: embedMode
          ? null
          : AppBar(
              title: const Text(
                'Reclamos de Tienda',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: _azulNautico,
              foregroundColor: Colors.white,
            ),
      body: contenido,
    );
  }
}
