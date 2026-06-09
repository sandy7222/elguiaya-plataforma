

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class AdminDisputasScreen extends StatefulWidget {
  final bool embedMode;
  const AdminDisputasScreen({super.key, this.embedMode = false});

  @override
  State<AdminDisputasScreen> createState() => _AdminDisputasScreenState();
}

class _AdminDisputasScreenState extends State<AdminDisputasScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _viajesEnDisputa = [];
  bool _isLoading = true;
  Timer? _actualizacionTimer;
  
  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);
  static const Color _grisDescanso = Color(0xFF64748B);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarViajesEnDisputa();
    _iniciarActualizacionAutomatica();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actualizacionTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarViajesEnDisputa();
      _iniciarActualizacionAutomatica();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
    }
  }

  void _iniciarActualizacionAutomatica() {
    _actualizacionTimer?.cancel();
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarViajesEnDisputa();
      }
    });
  }

  Future<void> _cargarViajesEnDisputa() async {
    try {
      setState(() => _isLoading = true);
      
      final viajes = await SupabaseService.getViajesEnDisputa();
      
      setState(() {
        _viajesEnDisputa = viajes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar disputas: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoResolucion(Map<String, dynamic> viaje) {
    final montoTotal = (viaje['monto_total'] as num?)?.toDouble() ?? 0.0;
    final motivoDisputa = viaje['motivo_disputa'] as String? ?? '';
    final diasEnDisputa = viaje['dias_en_disputa'] as int? ?? 0;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.gavel, color: _azulNautico),
            SizedBox(width: 8),
            Text('Resolver Disputa'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informacion del viaje
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monto en disputa: \$${montoTotal.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _azulNautico,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Motivo: $motivoDisputa',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Dias en disputa: $diasEnDisputa',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Opciones de resolucion
              const Text(
                '¿A quien favoreces en esta disputa?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Opcion a favor del capitan
              Container(
                width: double.infinity,
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
                        Icon(Icons.sailing, color: _verdeExito),
                        const SizedBox(width: 8),
                        const Text(
                          'Favor Capitan',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _verdeExito,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El capitan recibira el 90% del monto (\$${(montoTotal * 0.9).toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _liberarPago(viaje['pedido_id'], true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verdeExito,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Liberar Pago al Capitan'),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Opcion a favor del cliente
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _rojoProblema.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _rojoProblema.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person, color: _rojoProblema),
                        const SizedBox(width: 8),
                        const Text(
                          'Favor Cliente',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _rojoProblema,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El cliente recibira el reembolso completo (\$${montoTotal.toStringAsFixed(2)})',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _liberarPago(viaje['pedido_id'], false);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _rojoProblema,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Reembolsar al Cliente'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Future<void> _liberarPago(String pedidoId, bool favorCapitan) async {
    final observacionesController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          favorCapitan ? 'Confirmar Liberacion al Capitan' : 'Confirmar Reembolso al Cliente',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              favorCapitan 
                  ? 'Estas por liberar el pago al capitan'
                  : 'Estas por reembolsar al cliente',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: observacionesController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Observaciones (opcional)',
                hintText: 'Describe el motivo de tu decision...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta accion es irreversible y se registrara en el sistema.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _procesarLiberacionPago(pedidoId, favorCapitan, observacionesController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: favorCapitan ? _verdeExito : _rojoProblema,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarLiberacionPago(String pedidoId, bool favorCapitan, String observaciones) async {
    // Mostrar diálogo de carga indicando que se contacta a Mercado Pago
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(color: _azulNautico),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                favorCapitan 
                    ? 'Liberando pago al capitán...' 
                    : 'Procesando reembolso en Mercado Pago...',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final resultado = await SupabaseService.liberarPagoManualAdmin(pedidoId, favorCapitan, observaciones);
      
      if (mounted) {
        Navigator.pop(context); // Cerrar loader
        
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('✅ ${resultado['mensaje']}')),
              backgroundColor: _verdeExito,
            ),
          );
          _cargarViajesEnDisputa(); // Recargar lista
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
        Navigator.pop(context); // Cerrar loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al liberar pago: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: widget.embedMode ? Colors.transparent : const Color(0xFFF5F7FA),
      appBar: widget.embedMode
          ? null
          : AppBar(
              title: const Text(
                'Monitor de Disputas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              backgroundColor: _azulNautico,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  onPressed: _cargarViajesEnDisputa,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Recargar',
                ),
              ],
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viajesEnDisputa.isEmpty
              ? _buildEstadoVacio()
              : Column(
                  children: [
                    // Header de estadisticas
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: _azulNautico,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.gavel, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              const Text(
                                'Viajes en Disputa',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _rojoProblema,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_viajesEnDisputa.length} Activas',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.info_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Resuelve las disputas manualmente para liberar los pagos bloqueados.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de disputas
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _viajesEnDisputa.length,
                        itemBuilder: (context, index) {
                          final disputa = _viajesEnDisputa[index];
                          return _buildDisputaCard(disputa);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _verdeExito.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_outline,
              size: 64,
              color: _verdeExito,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay disputas activas',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _verdeExito,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Todos los viajes estan resueltos.\n¡Buen trabajo!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _cargarViajesEnDisputa,
            icon: const Icon(Icons.refresh),
            label: const Text('Verificar Nuevamente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulNautico,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisputaCard(Map<String, dynamic> disputa) {
    final montoTotal = (disputa['monto_total'] as num?)?.toDouble() ?? 0.0;
    final motivoDisputa = disputa['motivo_disputa'] as String? ?? '';
    final diasEnDisputa = disputa['dias_en_disputa'] as int? ?? 0;
    final urgencia = disputa['urgencia'] as String? ?? 'baja';
    final clienteNombre = disputa['cliente_nombre'] as String? ?? 'Cliente';
    final capitanNombre = disputa['capitan_nombre'] as String? ?? 'Capitan';
    
    Color urgenciaColor;
    IconData urgenciaIcon;
    
    switch (urgencia) {
      case 'alta':
        urgenciaColor = _rojoProblema;
        urgenciaIcon = Icons.priority_high;
        break;
      case 'media':
        urgenciaColor = _naranjaAlerta;
        urgenciaIcon = Icons.warning;
        break;
      default:
        urgenciaColor = _grisDescanso;
        urgenciaIcon = Icons.info_outline;
    }
    
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
            // Header con urgencia
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: urgenciaColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(urgenciaIcon, color: urgenciaColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Disputa Activa',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: urgenciaColor,
                        ),
                      ),
                      Text(
                        '$diasEnDisputa dias en disputa',
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
                    color: urgenciaColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    urgencia.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Monto en disputa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Monto en disputa:',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    '\$${montoTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _azulNautico,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Motivo
            if (motivoDisputa.isNotEmpty) ...[
              Text(
                'Motivo:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                motivoDisputa,
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
            
            // Participantes
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cliente:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        clienteNombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Capitan:',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        capitanNombre,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Boton de accion
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _mostrarDialogoResolucion(disputa),
                icon: const Icon(Icons.gavel),
                label: const Text('Resolver Disputa'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _azulNautico,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Importar Timer para actualizacion automatica
