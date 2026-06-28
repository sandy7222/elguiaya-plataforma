

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class AdminMonitorScreen extends StatefulWidget {
  const AdminMonitorScreen({super.key});

  @override
  State<AdminMonitorScreen> createState() => _AdminMonitorScreenState();
}

class _AdminMonitorScreenState extends State<AdminMonitorScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  Map<String, dynamic> _estadisticas = {};
  List<Map<String, dynamic>> _alertas = [];
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
    _cargarDatos();
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
      _cargarDatos();
      _iniciarActualizacionAutomatica();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
    }
  }

  void _iniciarActualizacionAutomatica() {
    _actualizacionTimer?.cancel();
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarDatos();
      }
    });
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      // Obtener estadisticas del monitor
      final estadisticas = await SupabaseService.getMonitorAdminDetalles();
      final alertas = await SupabaseService.getAlertasAdmin();
      
      setState(() {
        _estadisticas = estadisticas;
        _alertas = alertas;
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

  Future<void> _ejecutarVigilante() async {
    try {
      final resultado = await SupabaseService.ejecutarVigilanteCotizaciones();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text(
              '? Vigilante ejecutado: ${resultado['cotizaciones_procesadas']} procesadas, '
              '${resultado['alertas_creadas']} alertas creadas'
            )),
            backgroundColor: _verdeExito,
          ),
        );
        _cargarDatos(); // Recargar datos
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al ejecutar vigilante: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _marcarAlertaComoLeida(String alertaId) async {
    try {
      await SupabaseService.marcarAlertaAdminLeida(alertaId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('Alerta marcada como leida')),
            backgroundColor: _verdeExito,
          ),
        );
        _cargarDatos(); // Recargar datos
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al marcar alerta: $e')),
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
          'Monitor de Administrador',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _ejecutarVigilante,
            icon: const Icon(Icons.search),
            tooltip: 'Ejecutar Vigilante',
          ),
          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Tarjeta principal de estadisticas
                  _buildTarjetaPrincipal(),
                  
                  const SizedBox(height: 20),
                  
                  // Estadisticas de cotizaciones
                  _buildSeccionCotizaciones(),
                  
                  const SizedBox(height: 20),
                  
                  // Estadisticas de capitanes
                  _buildSeccionCapitanes(),
                  
                  const SizedBox(height: 20),
                  
                  // Alertas pendientes
                  _buildSeccionAlertas(),
                ],
              ),
            ),
    );
  }

  Widget _buildTarjetaPrincipal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _azulNautico,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
              const Icon(Icons.dashboard, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Panel de Control',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Ultima actualizacion: ${_formatHora(DateTime.now())}',
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
          
          // Metricas principales
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Cotizaciones Hoy',
                  '${_estadisticas['cotizaciones_hoy'] ?? 0}',
                  Icons.receipt_long,
                  Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Tasa Conversion',
                  '${(_estadisticas['tasa_conversion_porcentaje'] ?? 0).toStringAsFixed(1)}%',
                  Icons.trending_up,
                  _verdeExito,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Alertas Activas',
                  '${_estadisticas['alertas_pendientes'] ?? 0}',
                  Icons.notifications,
                  _naranjaAlerta,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionCotizaciones() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: _azulNautico),
                const SizedBox(width: 8),
                const Text(
                  'Estadisticas de Cotizaciones',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
                const Spacer(),
                Text(
                  'Hoy: ${DateTime.now().day}/${DateTime.now().month}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Grid de estadisticas
            Column(
              children: [
                _buildStatRow(
                  'Total de cotizaciones',
                  '${_estadisticas['cotizaciones_hoy'] ?? 0}',
                  Icons.list_alt,
                ),
                _buildStatRow(
                  'Pendientes de presupuesto',
                  '${_estadisticas['cotizaciones_pendientes_hoy'] ?? 0}',
                  Icons.pending,
                  color: _naranjaAlerta,
                ),
                _buildStatRow(
                  'Presupuestadas',
                  '${_estadisticas['cotizaciones_presupuestadas_hoy'] ?? 0}',
                  Icons.description,
                  color: Colors.blue,
                ),
                _buildStatRow(
                  'Aceptadas',
                  '${_estadisticas['cotizaciones_aceptadas_hoy'] ?? 0}',
                  Icons.check_circle,
                  color: _verdeExito,
                ),
                _buildStatRow(
                  'Tiempo promedio de respuesta',
                  '${_estadisticas['tiempo_promedio_respuesta_minutos'] ?? 0} min',
                  Icons.access_time,
                  color: Colors.purple,
                ),
                _buildStatRow(
                  'Monto promedio por viaje',
                  '\$${(_estadisticas['monto_promedio_viajes'] ?? 0).toStringAsFixed(2)}',
                  Icons.attach_money,
                  color: Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionCapitanes() {
    final totalCapitanes = _estadisticas['total_capitanes'] ?? 0;
    final capitanesActivos = _estadisticas['capitanes_activos'] ?? 0;
    final capitanesEnDescanso = _estadisticas['capitanes_en_descanso'] ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.people, color: _azulNautico),
                const SizedBox(width: 8),
                const Text(
                  'Estado de Capitanes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
                const Spacer(),
                Text(
                  'Total: $totalCapitanes',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Barra de progreso
            Container(
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: FractionallySizedBox(
                widthFactor: totalCapitanes > 0 ? capitanesActivos / totalCapitanes : 0,
                alignment: Alignment.centerLeft,
                child: Container(
                  decoration: BoxDecoration(
                    color: _verdeExito,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Estadisticas detalladas
            Row(
              children: [
                Expanded(
                  child: _buildCapitanStat(
                    'Activos',
                    '$capitanesActivos',
                    Icons.power,
                    _verdeExito,
                  ),
                ),
                Expanded(
                  child: _buildCapitanStat(
                    'En Descanso',
                    '$capitanesEnDescanso',
                    Icons.power_off,
                    _grisDescanso,
                  ),
                ),
                Expanded(
                  child: _buildCapitanStat(
                    'Disponibilidad',
                    '${totalCapitanes > 0 ? ((capitanesActivos / totalCapitanes) * 100).toStringAsFixed(0) : 0}%',
                    Icons.percent,
                    _azulNautico,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitanStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
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
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildSeccionAlertas() {
    final alertasCriticas = _estadisticas['alertas_criticas'] ?? 0;
    final cotizacionesPendientesLargas = _estadisticas['cotizaciones_pendientes_largas'] ?? 0;
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.notifications, color: _azulNautico),
                const SizedBox(width: 8),
                const Text(
                  'Alertas Pendientes',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _azulNautico,
                  ),
                ),
                const Spacer(),
                if (alertasCriticas > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _rojoProblema,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$alertasCriticas CRITICAS',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Lista de alertas
            if (_alertas.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: _verdeExito),
                    const SizedBox(width: 8),
                    const Text('No hay alertas pendientes'),
                  ],
                ),
              )
            else
              Column(
                children: _alertas.take(5).map((alerta) => _buildAlertaCard(alerta)).toList(),
              ),
            
            if (_alertas.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Y ${_alertas.length - 5} alertas mas...',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertaCard(Map<String, dynamic> alerta) {
    final tipo = alerta['tipo'] as String? ?? 'desconocido';
    final descripcion = alerta['descripcion'] as String? ?? 'Sin descripcion';
    final prioridad = alerta['prioridad'] as String? ?? 'media';
    final createdAt = alerta['created_at'] as String? ?? '';
    
    Color prioridadColor;
    IconData prioridadIcon;
    
    switch (prioridad) {
      case 'critica':
        prioridadColor = _rojoProblema;
        prioridadIcon = Icons.priority_high;
        break;
      case 'alta':
        prioridadColor = _naranjaAlerta;
        prioridadIcon = Icons.warning;
        break;
      case 'media':
        prioridadColor = Colors.blue;
        prioridadIcon = Icons.info;
        break;
      default:
        prioridadColor = Colors.grey;
        prioridadIcon = Icons.info_outline;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: prioridadColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: prioridadColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(prioridadIcon, color: prioridadColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Hace ${_formatTiempoTranscurrido(createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _marcarAlertaComoLeida(alerta['id']),
            icon: const Icon(Icons.check),
            iconSize: 20,
            color: _verdeExito,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? _azulNautico, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? _azulNautico,
            ),
          ),
        ],
      ),
    );
  }

  String _formatHora(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTiempoTranscurrido(String fechaString) {
    try {
      final fecha = DateTime.parse(fechaString);
      final ahora = DateTime.now();
      final diferencia = ahora.difference(fecha);
      
      if (diferencia.inMinutes < 60) {
        return '${diferencia.inMinutes} min';
      } else if (diferencia.inHours < 24) {
        return '${diferencia.inHours} h';
      } else {
        return '${diferencia.inDays} d';
      }
    } catch (e) {
      return 'Desconocido';
    }
  }
}

// Importar Timer para actualizacion automatica
