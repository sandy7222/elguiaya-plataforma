

import 'package:flutter/material.dart';

class DisclaimerTiemposEntregaWidget extends StatefulWidget {
  final bool obligatorio;
  final Function(bool) onAceptado;
  final String? userId;
  final String? pedidoId;

  const DisclaimerTiemposEntregaWidget({
    super.key,
    this.obligatorio = true,
    required this.onAceptado,
    this.userId,
    this.pedidoId,
  });

  @override
  State<DisclaimerTiemposEntregaWidget> createState() => _DisclaimerTiemposEntregaWidgetState();
}

class _DisclaimerTiemposEntregaWidgetState extends State<DisclaimerTiemposEntregaWidget> {
  bool _aceptado = false;
  bool _procesando = false;
  
  // Colores CapitanYA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _naranjaAlerta.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _naranjaAlerta.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del disclaimer
            Row(
              children: [
                Icon(Icons.warning_amber, color: _naranjaAlerta, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Aviso Importante sobre Tiempos de Entrega',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _naranjaAlerta,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Contenido del disclaimer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠️ Politica de Tiempos de Entrega',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: _naranjaAlerta,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'CapitanYA no gestiona los tiempos de entrega finales. Una vez despachado, el servicio queda sujeto a los plazos y condiciones de Correo Argentino.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Los plazos estimados son proporcionados por el transportista\n'
                    '• CapitanYA no se responsabiliza por demoras en la entrega\n'
                    '• Las consultas sobre el estado del envio deben realizarse directamente con Correo Argentino\n'
                    '• Una vez despachado, el seguimiento estara disponible en tu panel',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Checkbox de aceptacion
            Row(
              children: [
                Checkbox(
                  value: _aceptado,
                  onChanged: (value) {
                    if (value == true) {
                      _mostrarDialogoConfirmacion();
                    } else {
                      setState(() {
                        _aceptado = false;
                        widget.onAceptado(false);
                      });
                    }
                  },
                  activeColor: _azulNautico,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (!_aceptado) {
                        _mostrarDialogoConfirmacion();
                      }
                    },
                    child: Text(
                      widget.obligatorio 
                          ? 'He leido y acepto los terminos sobre tiempos de entrega (obligatorio)'
                          : 'He leido y acepto los terminos sobre tiempos de entrega',
                      style: TextStyle(
                        fontSize: 12,
                        color: _aceptado ? _azulNautico : Colors.black87,
                        fontWeight: _aceptado ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            // Indicador de procesamiento
            if (_procesando) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Registrando aceptacion...',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoConfirmacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info, color: _azulNautico),
            const SizedBox(width: 8),
            const Text('Confirmacion de Aceptacion'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Al aceptar estos terminos, reconoces que:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(
              '• CapitanYA no controla los tiempos de entrega finales\n'
              '• Los plazos dependen exclusivamente de Correo Argentino\n'
              '• Las demoras no afectaran la liquidacion del capitan\n'
              '• Deberas gestionar directamente las consultas de seguimiento',
              style: TextStyle(fontSize: 12),
            ),
            SizedBox(height: 16),
            Text(
              '¿Deseas continuar y aceptar estos terminos?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _registrarAceptacion();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulNautico,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _registrarAceptacion() async {
    setState(() => _procesando = true);
    
    try {
      // Aqui implementariamos la llamada al servicio para registrar la aceptacion
      // Por ahora, simulamos el proceso
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _aceptado = true;
        _procesando = false;
      });
      
      widget.onAceptado(true);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('✅ Aceptacion registrada exitosamente')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _procesando = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al registrar aceptacion: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Widget para bloqueo de punto de encuentro
class BloqueoPuntoEmbarqueWidget extends StatelessWidget {
  const BloqueoPuntoEmbarqueWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.block, color: Colors.red, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Restriccion de Entrega',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🚫 Politica de Entrega',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Los productos se envian unicamente a domicilios particulares o comerciales urbanos. No se realizan entregas en puntos de embarque.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '⚠️ No se permiten entregas en:\n'
                    '• Muelles o puertos\n'
                    '• Terminales de embarque\n'
                    '• Aeropuertos\n'
                    '• Estaciones de transporte',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget para informacion de separacion de flujos
class SeparacionFlujosWidget extends StatelessWidget {
  const SeparacionFlujosWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info, color: Colors.blue, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Informacion Importante',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🔄 Flujos Independientes',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'El estado de "Producto Entregado" es independiente del estado de "Viaje Realizado":',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '✅ Viaje Realizado → Liquidacion del capitan habilitada\n'
                    '📦 Producto Entregado → Seguimiento completado\n'
                    '⚡ Una demora en el correo NO bloquea la liquidacion del capitan',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
