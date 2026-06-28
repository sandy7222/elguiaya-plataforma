

import 'package:flutter/material.dart';
import '../widgets/safe_button.dart';

class TicketGeneradoScreen extends StatelessWidget {
  const TicketGeneradoScreen({super.key, this.invoice, this.paymentData});
  
  final Map<String, dynamic>? invoice;
  final Map<String, dynamic>? paymentData;

  // Colores El Guia YA - Alto contraste para exteriores
  final Color _fondoOscuro = const Color(0xFF1A1A1A);      // Fondo oscuro
  final Color _blancoPuro = const Color(0xFFFFFFFF);        // Blanco puro
  final Color _azulVibrante = const Color(0xFF0066FF);      // Azul vibrante
  final Color _verdeBrillante = const Color(0xFF00FF00);     // Verde brillante
  final Color _naranjaIntenso = const Color(0xFFFF6600);     // Naranja intenso
  final Color _rojoFuerte = const Color(0xFFFF0000);          // Rojo fuerte
  final Color _amarilloVivo = const Color(0xFFFFFF00);       // Amarillo vivo

  @override
  Widget build(BuildContext context) {

    // Datos del ticket fiscal generado
    const netoGravado = 55020.08;
    const iva = 11554.22;
    const ingresosBrutos = 2397.70;
    const total = 68500.00;

    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.receipt_long, color: _blancoPuro, size: 24),
            const SizedBox(width: 8),
            Text(
              'Ticket Fiscal Generado',
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
            // Header principal con exito
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_verdeBrillante, _azulVibrante],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: _blancoPuro, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    '? TICKET FISCAL GENERADO',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Se ha registrado exitosamente en el sistema fiscal',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Resumen financiero fiscal
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: _verdeBrillante),
                      const SizedBox(width: 8),
                      Text(
                        'Resumen Fiscal',
                        style: TextStyle(
                          color: _fondoOscuro,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // Montos principales
                  _buildMontoFiscal('Total de la Operacion', total, _verdeBrillante, 24),
                  const SizedBox(height: 12),
                  
                  // Desglose impositivo
                  _buildMontoFiscal('Neto Gravado', netoGravado, _azulVibrante, 18),
                  _buildMontoFiscal('IVA (21%)', iva, _naranjaIntenso, 18),
                  _buildMontoFiscal('Ingresos Brutos', ingresosBrutos, _naranjaIntenso, 18),
                  
                  const SizedBox(height: 20),
                  
                  // Informacion legal
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _azulVibrante.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informacion Legal',
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '• Este ticket es un comprobante fiscal valido',
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '• Se ha registrado en el sistema tributario',
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          '• Para consultas fiscales, conservar este documento',
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Botones de accion
            Container(
              margin: const EdgeInsets.all(16),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: SafeElevatedIconButton(
  onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Column(
                              children: [
                                Icon(Icons.download, color: _blancoPuro),
                                const SizedBox(width: 8),
                                Text('Descargando ticket fiscal...'),
                              ],
                            ),
                            backgroundColor: _verdeBrillante,
                          ),
                        );
                      },
  icon: Icons.download,
  iconColor: _blancoPuro,
  label: 'DESCARGAR TICKET',
  textStyle: TextStyle(color: _blancoPuro, fontWeight: FontWeight.bold),
  style: ElevatedButton.styleFrom(
                        backgroundColor: _azulVibrante,
                        foregroundColor: _blancoPuro,
                        elevation: 6,
                        shadowColor: _verdeBrillante.withOpacity(0.3),
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
                    child: SafeOutlinedIconButton(
  onPressed: () {
                        Navigator.of(context).pop();
                      },
  icon: Icons.arrow_back,
  iconColor: _verdeBrillante,
  label: 'VOLVER AL INICIO',
  textStyle: TextStyle(
                          color: _verdeBrillante,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
  style: OutlinedButton.styleFrom(
                        side: BorderSide(color: _verdeBrillante),
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

  Widget _buildMontoFiscal(String concepto, double monto, Color color, double fontSize) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            '\$${monto.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
