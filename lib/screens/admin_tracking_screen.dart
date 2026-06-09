

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';

class AdminTrackingScreen extends StatefulWidget {
  final bool embedMode;
  const AdminTrackingScreen({super.key, this.embedMode = false});

  @override
  State<AdminTrackingScreen> createState() => _AdminTrackingScreenState();
}

class _AdminTrackingScreenState extends State<AdminTrackingScreen> {
  List<Map<String, dynamic>> _pedidos = [];
  final List<Map<String, dynamic>> _reservas = [];
  bool _isLoading = true;
  final _trackingController = TextEditingController();
  String? _pedidoSeleccionadoId;
  
  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);
  static const Color _grisDescanso = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      final gestionLogistica = await SupabaseService.getGestionLogisticaAdmin();
      
      setState(() {
        _pedidos = gestionLogistica;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar datos: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cargarTracking() async {
    if (_pedidoSeleccionadoId == null || _trackingController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Por favor, selecciona un pedido y ingresa el codigo de tracking')),
          backgroundColor: _rojoProblema,
        ),
      );
      return;
    }

    try {
      final resultado = await SupabaseService.cargarTrackingYNotificar(
        _pedidoSeleccionadoId!,
        _trackingController.text,
        '11111111-1111-1111-1111-111111111111', // ID de prueba admin
      );

      if (mounted) {
        if (resultado['exito'] == true) {
          _trackingController.clear();
          _pedidoSeleccionadoId = null;
          _cargarDatos(); // Recargar datos para mostrar el tracking actualizado
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text(
                '✅ ${resultado['mensaje']}\n'
                '📧 Correo enviado al pescador'
              )),
              backgroundColor: _verdeExito,
              duration: const Duration(seconds: 4),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('Error: ${resultado['mensaje']}')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar tracking: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDetallesPedido(Map<String, dynamic> pedido) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.shopping_cart, color: _azulNautico),
            const SizedBox(width: 8),
            const Text('Detalles del Pedido'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pedido #${pedido['pedido_tienda_id']?.toString().substring(0, 8) ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Pescador: ${pedido['pescador_nombre'] ?? 'N/A'}'),
              Text('Email: ${pedido['pescador_email'] ?? 'N/A'}'),
              Text('Total: \$${pedido['total_pedido']?.toStringAsFixed(2) ?? '0.00'}'),
              Text('Estado: ${pedido['estado_pedido'] ?? 'Desconocido'}'),
              
              if (pedido['tracking_codigo'] != null) ...[
                const SizedBox(height: 12),
                const Text('Tracking:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Codigo: ${pedido['tracking_codigo']}'),
                if (pedido['tracking_url'] != null)
                  GestureDetector(
                    onTap: () => _abrirTrackingUrl(pedido['tracking_url']),
                    child: Text(
                      'Seguimiento: ${pedido['tracking_url']}',
                      style: const TextStyle(
                        color: _azulNautico,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
              
              if (pedido['reserva_viaje_id'] != null) ...[
                const SizedBox(height: 12),
                const Text('Viaje Vinculado:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Reserva ID: ${pedido['reserva_viaje_id']?.toString().substring(0, 8) ?? 'Unknown'}'),
                Text('Estado Viaje: ${pedido['estado_reserva'] ?? 'Desconocido'}'),
                Text('Monto Viaje: \$${pedido['monto_reserva']?.toStringAsFixed(2) ?? '0.00'}'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _abrirTrackingUrl(String trackingUrl) async {
    try {
      final uri = Uri.parse(trackingUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al abrir enlace: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.embedMode ? Colors.transparent : const Color(0xFFF5F7FA),
      appBar: widget.embedMode
          ? null
          : AppBar(
              title: Row(
                children: const [
                  Icon(Icons.local_shipping, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Gestion de Tracking'),
                ],
              ),
              backgroundColor: _azulNautico,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  onPressed: _cargarDatos,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recargar',
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Panel de carga de tracking
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cargar Tracking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresa el codigo de tracking de Correo Argentino para enviar notificaciones automaticas a los pescadores.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Selector de pedido
                      DropdownButtonFormField<String>(
                        initialValue: _pedidoSeleccionadoId,
                        decoration: const InputDecoration(
                          labelText: 'Seleccionar Pedido',
                          border: OutlineInputBorder(),
                        ),
                        items: _pedidos
                            .where((p) => p['tracking_codigo'] == null)
                            .map((pedido) => DropdownMenuItem<String>(
                              value: pedido['pedido_tienda_id'],
                              child: Text(
                                'Pedido #${pedido['pedido_tienda_id']?.toString().substring(0, 8)} - ${pedido['pescador_nombre'] ?? 'N/A'}',
                              ),
                            ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _pedidoSeleccionadoId = value;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Campo de tracking
                      TextFormField(
                        controller: _trackingController,
                        decoration: const InputDecoration(
                          labelText: 'Codigo de Tracking',
                          border: OutlineInputBorder(),
                          hintText: 'Ej: 123456789012',
                        ),
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.characters,
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Boton de carga
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _cargarTracking,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Cargar Tracking y Enviar Notificacion'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _verdeExito,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Lista de pedidos
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _pedidos.length,
                    itemBuilder: (context, index) {
                      final pedido = _pedidos[index];
                      return _buildPedidoCard(pedido);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedido) {
    final estadoColor = Color(int.tryParse(pedido['color_general'] as String? ?? '') ?? 0xFF6B7280);
    final tieneTracking = pedido['tracking_codigo'] != null;
    final tieneViaje = pedido['reserva_viaje_id'] != null;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con informacion principal
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _azulNautico.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    tieneViaje ? Icons.directions_boat : Icons.shopping_cart,
                    color: _azulNautico,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${pedido['pedido_tienda_id']?.toString().substring(0, 8) ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      Text(
                        pedido['pescador_nombre'] ?? 'Pescador no identificado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: estadoColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    pedido['estado_general'] ?? 'Desconocido',
                    style: TextStyle(
                      color: estadoColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Informacion detallada
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\$${pedido['total_pedido']?.toStringAsFixed(2) ?? '0.00'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      Text(
                        'Total Pedido',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                if (tieneViaje) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${pedido['monto_reserva']?.toStringAsFixed(2) ?? '0.00'}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _verdeExito,
                          ),
                        ),
                        Text(
                          'Viaje Vinculado',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            
            // Estados individuales
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEstadoChip(
                    'Pedido',
                    pedido['estado_pedido'] ?? 'desconocido',
                    pedido['pedido_despachado'] == true,
                  ),
                ),
                if (tieneViaje) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildEstadoChip(
                      'Viaje',
                      pedido['estado_reserva'] ?? 'desconocido',
                      pedido['viaje_realizado'] == true,
                    ),
                  ),
                ],
              ],
            ),
            
            // Informacion de tracking
            if (tieneTracking) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _verdeExito.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _verdeExito.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping, color: _verdeExito, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Tracking Disponible',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _verdeExito,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Codigo: ${pedido['tracking_codigo']}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _abrirTrackingUrl(pedido['tracking_url']),
                          icon: const Icon(Icons.open_in_browser),
                          iconSize: 16,
                          color: _verdeExito,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Botones de accion
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mostrarDetallesPedido(pedido),
                    icon: const Icon(Icons.visibility),
                    label: const Text('Ver Detalles'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulNautico,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!tieneTracking)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _pedidoSeleccionadoId = pedido['pedido_tienda_id'];
                        });
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Agregar Tracking'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _azulNautico,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoChip(String titulo, String estado, bool completado) {
    Color color;
    IconData icon;
    
    switch (estado.toLowerCase()) {
      case 'entregado':
      case 'realizado':
      case 'liquidado':
        color = _verdeExito;
        icon = Icons.check_circle;
        break;
      case 'despachado':
      case 'pagado':
        color = _azulNautico;
        icon = Icons.local_shipping;
        break;
      case 'pagado':
        color = _naranjaAlerta;
        icon = Icons.payment;
        break;
      default:
        color = _grisDescanso;
        icon = Icons.schedule;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            '$titulo: $estado',
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
