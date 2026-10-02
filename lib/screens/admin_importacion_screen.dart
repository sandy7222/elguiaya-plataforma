import 'package:flutter/material.dart';

/// Pantalla de administración de Importación de catálogo/datos.
///
/// NOTA: Reconstrucción mínima. El archivo original nunca fue commiteado al
/// repositorio (existía solo en la máquina del desarrollador), por lo que esta
/// versión provee la superficie necesaria para compilar y navegar. Reemplazar
/// por la implementación real (importación masiva de productos/datos) cuando
/// esté disponible.
class AdminImportacionScreen extends StatelessWidget {
  const AdminImportacionScreen({super.key});

  static const Color _azulNautico = Color(0xFF001F3F);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Importación',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_upload_outlined,
                  size: 72, color: _azulNautico),
              const SizedBox(height: 16),
              const Text(
                'Importación de Catálogo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Módulo en preparación. Acá se realizará la importación masiva '
                'de productos y datos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
