

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class ConfirmarRetornoScreen extends StatefulWidget {
  const ConfirmarRetornoScreen({super.key});

  @override
  State<ConfirmarRetornoScreen> createState() => _ConfirmarRetornoScreenState();
}

class _ConfirmarRetornoScreenState extends State<ConfirmarRetornoScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _viajesListos = [];
  bool _isLoading = true;
  Timer? _actualizacionTimer;
  
  // ID de prueba para el pescador
  final String _pescadorId = '11111111-1111-1111-1111-111111111111';
  
  // Colores El Guia YA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarViajes();
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
      _cargarViajes();
      _iniciarActualizacionAutomatica();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
    }
  }

  void _iniciarActualizacionAutomatica() {
    _actualizacionTimer?.cancel();
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarViajes();
      }
    });
  }

  Future<void> _cargarViajes() async {
    try {
      setState(() => _isLoading = true);
      
      // Obtener viajes listos para confirmar retorno
      final viajes = await SupabaseService.getViajesListosConfirmarRetorno(_pescadorId);
      
      setState(() {
        _viajesListos = viajes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar viajes: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmarRetornoYLibrerarPago(String pedidoId) async {
    try {
      final resultado = await SupabaseService.confirmarRetornoYLiberarPago(pedidoId, _pescadorId);
      
      if (mounted) {
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('✅ ¡Retorno confirmado! Pago liberado al capitan')),
              backgroundColor: _verdeExito,
            ),
          );
          _cargarViajes(); // Recargar lista
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
            content: Center(child: Text('Error al confirmar retorno: $e')),
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
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Confirmar Regreso',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarViajes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _viajesListos.isEmpty
              ? _buildEstadoVacio()
              : Column(
                  children: [
                    // Header de informacion
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
                              const Icon(Icons.home_work, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Viajes Listos para Confirmar',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Estos viajes han completado su fecha de retorno y estan listos para tu confirmacion.',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
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
                                Icon(Icons.info_outline, color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Tu confirmacion liberara automaticamente el pago al capitan.',
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
                    
                    // Lista de viajes
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _viajesListos.length,
                        itemBuilder: (context, index) {
                          final viaje = _viajesListos[index];
                          return _buildViajeCard(viaje);
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
              color: _azulNautico.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.home_work_outlined,
              size: 64,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay viajes listos para confirmar',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cuando tus viajes completen su fecha de retorno,\napareceran aqui para confirmar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _cargarViajes,
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

  Widget _buildViajeCard(Map<String, dynamic> viaje) {
    final horasDesdeRetorno = (viaje['horas_desde_retorno'] as num?)?.toDouble() ?? 0.0;
    final monto = (viaje['monto_total'] as num?)?.toDouble() ?? 0.0;
    final descripcion = viaje['descripcion'] as String? ?? 'Viaje sin descripcion';
    final fechaRetorno = viaje['fecha_regorno'] as String? ?? '';
    final capitanNombre = viaje['capitan_nombre'] as String? ?? 'Capitan';
    final urgencia = viaje['urgencia'] as String? ?? 'baja';
    
    Color urgenciaColor;
    IconData urgenciaIcon;
    String urgenciaText;
    
    switch (urgencia) {
      case 'critica':
        urgenciaColor = _rojoProblema;
        urgenciaIcon = Icons.priority_high;
        urgenciaText = 'Critica';
        break;
      case 'alta':
        urgenciaColor = _naranjaAlerta;
        urgenciaIcon = Icons.warning;
        urgenciaText = 'Alta';
        break;
      case 'media':
        urgenciaColor = Colors.orange;
        urgenciaIcon = Icons.info;
        urgenciaText = 'Media';
        break;
      default:
        urgenciaColor = _verdeExito;
        urgenciaIcon = Icons.check_circle;
        urgenciaText = 'Normal';
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
            // Header del viaje
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _azulNautico.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sailing, color: _azulNautico, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        descripcion,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Capitan: $capitanNombre',
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(urgenciaIcon, color: Colors.white, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        urgenciaText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Informacion de tiempo
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
                  Row(
                    children: [
                      const Icon(Icons.schedule, size: 16, color: _azulNautico),
                      const SizedBox(width: 8),
                      Text(
                        'Fecha de retorno: ${_formatFecha(fechaRetorno)}',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: urgenciaColor),
                      const SizedBox(width: 8),
                      Text(
                        'Tiempo transcurrido: ${horasDesdeRetorno.toStringAsFixed(1)} horas',
                        style: TextStyle(
                          fontSize: 12,
                          color: urgenciaColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Monto
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _verdeExito.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _verdeExito.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pago a liberar:',
                    style: TextStyle(fontSize: 14),
                  ),
                  Text(
                    '\$${monto.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _verdeExito,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Boton de confirmacion
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(
                  colors: [_verdeExito, _azulNautico],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: ElevatedButton.icon(
                onPressed: () => _confirmarRetornoYLibrerarPago(viaje['pedido_id']),
                icon: const Icon(Icons.check_circle, color: Colors.white),
                label: const Text(
                  'Confirmar Regreso y Liberar Pago',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFecha(String fechaString) {
    try {
      final fecha = DateTime.parse(fechaString);
      return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return fechaString;
    }
  }
}

// Importar Timer para actualizacion automatica
