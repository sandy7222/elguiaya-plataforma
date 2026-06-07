

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class AdminCierresScreen extends StatefulWidget {
  const AdminCierresScreen({super.key});

  @override
  State<AdminCierresScreen> createState() => _AdminCierresScreenState();
}

class _AdminCierresScreenState extends State<AdminCierresScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _viajes = [];
  bool _isLoading = true;
  Timer? _actualizacionTimer;
  
  // Colores CapitanYA
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
      
      // Obtener monitor de cierres
      final viajes = await SupabaseService.getMonitorCierres();
      
      setState(() {
        _viajes = viajes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar cierres: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _ejecutarVigilancia() async {
    try {
      final resultado = await SupabaseService.ejecutarVigilanciaCierres();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text(
              '✅ Vigilancia ejecutada: ${resultado['pedidos_procesados']} procesados, '
              '${resultado['notificaciones_enviadas']} notificaciones, '
              '${resultado['alertas_demora_creadas']} alertas'
            )),
            backgroundColor: _verdeExito,
          ),
        );
        _cargarViajes(); // Recargar datos
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al ejecutar vigilancia: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _mostrarDialogoCierreManual(Map<String, dynamic> viaje) {
    final montoTotal = (viaje['monto_total'] as num?)?.toDouble() ?? 0.0;
    final descripcion = viaje['descripcion'] as String? ?? 'Viaje sin descripcion';
    final clienteNombre = viaje['cliente_nombre'] as String? ?? 'Cliente';
    final capitanNombre = viaje['capitan_nombre'] as String? ?? 'Capitan';
    final horasDesdeRetorno = (viaje['horas_desde_retorno'] as num?)?.toDouble() ?? 0.0;
    
    final observacionesController = TextEditingController();
    bool liberarPago = true;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gavel, color: _azulNautico),
              SizedBox(width: 8),
              Text('Cierre Manual'),
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
                        'Viaje: $descripcion',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text('Cliente: $clienteNombre'),
                          const SizedBox(width: 16),
                          Text('Capitan: $capitanNombre'),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tiempo desde retorno: ${horasDesdeRetorno.toStringAsFixed(1)} horas',
                        style: TextStyle(
                          fontSize: 12,
                          color: _naranjaAlerta,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monto afectado: \$${montoTotal.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Opcion de liberar pago
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _verdeExito.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _verdeExito.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: liberarPago,
                        onChanged: (value) {
                          setState(() {
                            liberarPago = value!;
                          });
                        },
                        activeColor: _verdeExito,
                      ),
                      Expanded(
                        child: Text(
                          'Liberar pago al capitan (90%: \$${(montoTotal * 0.9).toStringAsFixed(2)})',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Observaciones
                TextField(
                  controller: observacionesController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Observaciones (opcional)',
                    hintText: 'Describe el motivo del cierre manual...',
                  ),
                  maxLines: 3,
                ),
                
                const SizedBox(height: 12),
                
                // Advertencia
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _naranjaAlerta.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _naranjaAlerta.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: _naranjaAlerta, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esta accion es irreversible y se registrara en el sistema.',
                          style: TextStyle(
                            fontSize: 12,
                            color: _naranjaAlerta,
                          ),
                        ),
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
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _procesarCierreManual(viaje['pedido_id'], liberarPago, observacionesController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _azulNautico,
                foregroundColor: Colors.white,
              ),
              child: const Text('Procesar Cierre'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarCierreManual(String pedidoId, bool liberarPago, String observaciones) async {
    try {
      final resultado = await SupabaseService.cierreManualAdmin(pedidoId, liberarPago, observaciones);
      
      if (mounted) {
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('✅ ${resultado['mensaje']}')),
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
            content: Center(child: Text('Error al procesar cierre: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    final enVuelo = _viajes.where((v) => v['estado_actual'] == 'en_vuelo').length;
    final recienteLlegada = _viajes.where((v) => v['estado_actual'] == 'reciente_llegada').length;
    final listoConfirmar = _viajes.where((v) => v['estado_actual'] == 'listo_confirmar').length;
    final demorado = _viajes.where((v) => v['estado_actual'] == 'demorado').length;
    final alertaAlta = _viajes.where((v) => v['nivel_alerta'] == 'alta').length;
    final alertaCritica = _viajes.where((v) => v['nivel_alerta'] == 'critica').length;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Monitor de Cierres',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _ejecutarVigilancia,
            icon: const Icon(Icons.sync),
            tooltip: 'Ejecutar Vigilancia',
          ),
          IconButton(
            onPressed: _cargarViajes,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          const Icon(Icons.monitor_heart, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          const Text(
                            'Monitor de Operaciones',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Total: ${_viajes.length}',
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
                      
                      // Estadisticas principales
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard('En Vuelo', '$enVuelo', Icons.flight, Colors.blue),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard('Llegaron', '$recienteLlegada', Icons.home, Colors.green),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard('Listos', '$listoConfirmar', Icons.check_circle, Colors.orange),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildStatCard('Demorados', '$demorado', Icons.warning, Colors.red),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Alertas
                      if (alertaAlta > 0 || alertaCritica > 0)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _rojoProblema.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _rojoProblema.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.priority_high, color: _rojoProblema, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Alertas: $alertaAlta altas, $alertaCritica criticas',
                                style: const TextStyle(
                                  color: _rojoProblema,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
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
                    itemCount: _viajes.length,
                    itemBuilder: (context, index) {
                      final viaje = _viajes[index];
                      return _buildViajeCard(viaje);
                    },
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> viaje) {
    final descripcion = viaje['descripcion'] as String? ?? 'Viaje sin descripcion';
    final clienteNombre = viaje['cliente_nombre'] as String? ?? 'Cliente';
    final capitanNombre = viaje['capitan_nombre'] as String? ?? 'Capitan';
    final horasDesdeRetorno = (viaje['horas_desde_retorno'] as num?)?.toDouble() ?? 0.0;
    final estadoActual = viaje['estado_actual'] as String? ?? 'desconocido';
    final nivelAlerta = viaje['nivel_alerta'] as String? ?? 'normal';
    final montoTotal = (viaje['monto_total'] as num?)?.toDouble() ?? 0.0;
    
    Color estadoColor;
    IconData estadoIcon;
    
    switch (estadoActual) {
      case 'en_vuelo':
        estadoColor = Colors.blue;
        estadoIcon = Icons.flight;
        break;
      case 'reciente_llegada':
        estadoColor = Colors.green;
        estadoIcon = Icons.home;
        break;
      case 'listo_confirmar':
        estadoColor = Colors.orange;
        estadoIcon = Icons.check_circle;
        break;
      case 'demorado':
        estadoColor = Colors.red;
        estadoIcon = Icons.warning;
        break;
      case 'cerrado_manual':
        estadoColor = Colors.purple;
        estadoIcon = Icons.gavel;
        break;
      default:
        estadoColor = Colors.grey;
        estadoIcon = Icons.help_outline;
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
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(estadoIcon, color: estadoColor, size: 20),
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
                        '$clienteNombre ← $capitanNombre',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (nivelAlerta != 'normal')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: nivelAlerta == 'critica' ? _rojoProblema : _naranjaAlerta,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      nivelAlerta.toUpperCase(),
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
            
            // Informacion de tiempo y monto
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tiempo desde retorno:',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        Text(
                          '${horasDesdeRetorno.toStringAsFixed(1)} horas',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: estadoColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto:',
                          style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        ),
                        Text(
                          '\$${montoTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _azulNautico,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Boton de accion
            if (estadoActual != 'cerrado_manual' && estadoActual != 'confirmado')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoCierreManual(viaje),
                  icon: const Icon(Icons.gavel),
                  label: const Text('Cierre Manual'),
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
