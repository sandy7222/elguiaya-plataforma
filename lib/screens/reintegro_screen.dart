import 'package:flutter/material.dart';

class ReintegroScreen extends StatelessWidget {
  const ReintegroScreen({super.key});

  // Colores CapitanYA - Alto contraste para exteriores
  static const Color _fondoOscuro = Color(0xFF1A1A1A);      // Fondo oscuro
  static const Color _blancoPuro = Color(0xFFFFFFFF);        // Blanco puro
  static const Color _azulVibrante = Color(0xFF0066FF);      // Azul vibrante
  static const Color _verdeBrillante = Color(0xFF00FF00);     // Verde brillante
  static const Color _naranjaIntenso = Color(0xFFFF6600);     // Naranja intenso
  static const Color _rojoFuerte = Color(0xFFFF0000);          // Rojo fuerte
  static const Color _amarilloVivo = Color(0xFFFFFF00);       // Amarillo vivo

  @override
  Widget build(BuildContext context) {
    // Datos simulados del reintegro
    const totalOriginal = 68500.00;
    const productosConsumidos = 15000.00;  // Productos ya consumidos
    const montoDevolver = totalOriginal - productosConsumidos;  // $53.500

    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.refresh, color: _blancoPuro, size: 24),
            SizedBox(width: 8),
            Text(
              'Solicitud de Reintegro',
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
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header con informacion de disconformidad
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_rojoFuerte, _naranjaIntenso],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: const Column(
                children: [
                  Icon(Icons.warning, color: _blancoPuro, size: 48),
                  SizedBox(height: 12),
                  Text(
                    '¿Tienes una disconformidad?',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Entendemos tu situacion. Te ayudamos a procesar el reintegro.',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontSize: 16,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Informacion del pedido
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _blancoPuro,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long, color: _azulVibrante),
                      SizedBox(width: 8),
                      Text(
                        'Informacion del Pedido',
                        style: TextStyle(
                          color: _fondoOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildInfoItem('ID del Pedido', 'PED-2024-00123'),
                  _buildInfoItem('Fecha del Viaje', '15/03/2024'),
                  _buildInfoItem('Capitan', 'Juan Perez'),
                  _buildInfoItem('Estado Actual', 'Pendiente con Reembolso Habilitado'),
                ],
              ),
            ),
            
            // Calculo del reintegro
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_azulVibrante.withOpacity(0.1), _azulVibrante.withOpacity(0.2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _azulVibrante.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calculate, color: _azulVibrante),
                      SizedBox(width: 8),
                      Text(
                        '💰 Calculo del Reintegro',
                        style: TextStyle(
                          color: _fondoOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCostoItem('Total Original', totalOriginal, _fondoOscuro),
                  _buildCostoItem('Productos Consumidos', productosConsumidos, _rojoFuerte),
                  const Divider(color: Color(0xFF666666)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MONTO A DEVOLVER',
                        style: TextStyle(
                          color: _fondoOscuro,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${montoDevolver.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: _azulVibrante,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _naranjaIntenso.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '⚠️ Importante:',
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Los productos de la tienda (\$15.000) ya fueron consumidos y no se pueden devolver.',
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          'El reintegro se procesara a tu CBU en 3-5 dias habiles.',
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Formulario de motivo
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _blancoPuro,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.edit, color: _azulVibrante),
                      SizedBox(width: 8),
                      Text(
                        'Motivo del Reintegro',
                        style: TextStyle(
                          color: _fondoOscuro,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Describe brevemente el motivo de tu disconformidad...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _azulVibrante),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: _azulVibrante, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Este motivo sera evaluado por nuestro equipo de soporte.',
                    style: TextStyle(
                      color: _fondoOscuro.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            
            // Botones de accion
            Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Row(
                              children: [
                                Icon(Icons.refresh, color: _azulVibrante),
                                SizedBox(width: 8),
                                Text(
                                  'Confirmar Solicitud',
                                  style: TextStyle(
                                    color: _fondoOscuro,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '¿Estas seguro que deseas solicitar el reintegro?',
                                  style: TextStyle(
                                    color: _fondoOscuro,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Monto a devolver: \$${montoDevolver.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: _azulVibrante,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'El proceso tomara 3-5 dias habiles.',
                                  style: TextStyle(
                                    color: _fondoOscuro.withOpacity(0.8),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancelar'),
                              ),
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(Icons.check_circle, color: _blancoPuro),
                                          SizedBox(width: 8),
                                          Text('Solicitud de reintegro enviada'),
                                        ],
                                      ),
                                      backgroundColor: _azulVibrante,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                  Navigator.of(context).pop();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _azulVibrante,
                                  foregroundColor: _blancoPuro,
                                ),
                                child: const Text('Confirmar'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh, color: _blancoPuro),
                      label: const Text(
                        'SOLICITAR REINTEGRO',
                        style: TextStyle(color: _blancoPuro, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _azulVibrante,
                        foregroundColor: _blancoPuro,
                        elevation: 6,
                        shadowColor: _azulVibrante.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.arrow_back, color: _azulVibrante),
                      label: const Text(
                        'VOLVER',
                        style: TextStyle(
                          color: _azulVibrante,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _azulVibrante),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: _fondoOscuro.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: _fondoOscuro,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostoItem(String concepto, double monto, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            concepto,
            style: TextStyle(
              color: _fondoOscuro.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Text(
            '\$${monto.toStringAsFixed(0)}',
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
