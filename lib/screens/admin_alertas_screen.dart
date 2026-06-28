

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/safe_button.dart';
import '../services/supabase_service.dart';

class AdminAlertasScreen extends StatefulWidget {
  const AdminAlertasScreen({super.key});

  @override
  State<AdminAlertasScreen> createState() => _AdminAlertasScreenState();
}

class _AdminAlertasScreenState extends State<AdminAlertasScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _alertas = [];
  List<Map<String, dynamic>> _alertasNoNotificadas = [];
  bool _isLoading = true;
  Timer? _actualizacionTimer;
  RealtimeChannel? _alertasChannel;
  int _totalAlertasHoy = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarAlertas();
    _iniciarActualizacionAutomatica();
    _configurarAlertasRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _actualizacionTimer?.cancel();
    _alertasChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarAlertas();
      _iniciarActualizacionAutomatica();
      _configurarAlertasRealtime();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
    }
  }

  Future<void> _cargarAlertas() async {
    try {
      setState(() => _isLoading = true);
      
      // Cargar alertas no notificadas
      final alertasNoNotificadas = await SupabaseService.getAlertasNoNotificadas();
      
      // Calcular total de alertas hoy
      final hoy = DateTime.now();
      _totalAlertasHoy = alertasNoNotificadas.where((alerta) {
        final createdAt = DateTime.tryParse(alerta['created_at'] ?? '');
        if (createdAt == null) return false;
        return createdAt.year == hoy.year && 
               createdAt.month == hoy.month && 
               createdAt.day == hoy.day;
      }).length;
      
      setState(() {
        _alertasNoNotificadas = alertasNoNotificadas;
        _alertas = alertasNoNotificadas;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar alertas: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _iniciarActualizacionAutomatica() {
    _actualizacionTimer?.cancel();
    _actualizacionTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _cargarAlertas();
      }
    });
  }

  void _configurarAlertasRealtime() {
    _alertasChannel?.unsubscribe();
    
    _alertasChannel = SupabaseService.alertasChannel(
      onAlertaCreada: (alertaData) {
        _mostrarNotificacionNuevaAlerta(alertaData);
        _cargarAlertas();
      },
    );
    
    _alertasChannel?.subscribe();
  }

  void _mostrarNotificacionNuevaAlerta(Map<String, dynamic> alertaData) {
    if (!mounted) return;
    
    // Mostrar SnackBar inmediato
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¡Nueva Alerta de Negocio!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'Capitan sin respuesta - Telefono: ${alertaData['pescador_telefono']}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red[600],
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () {
            // Scroll a la alerta especifica
          },
        ),
      ),
    );
  }

  Future<void> _marcarComoNotificada(String alertaId) async {
    try {
      await SupabaseService.marcarAlertaNotificada(alertaId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('Alerta marcada como notificada')),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      await _cargarAlertas();
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

  Future<void> _marcarCotizacionesEnRiesgo() async {
    try {
      final resultado = await SupabaseService.marcarCotizacionesEnRiesgo();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('${resultado.length} cotizaciones marcadas en riesgo')),
            backgroundColor: Colors.orange,
          ),
        );
      }
      
      await _cargarAlertas();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al marcar cotizaciones: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuracion(int minutos) {
    if (minutos < 60) {
      return '$minutos min';
    } else {
      final horas = minutos ~/ 60;
      final minutosRestantes = minutos % 60;
      return '${horas}h ${minutosRestantes}min';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Panel de Alertas de Negocio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          if (_alertasNoNotificadas.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_alertasNoNotificadas.length} Activas',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          IconButton(
            onPressed: _cargarAlertas,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header de estadisticas
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Alertas Activas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Hoy',
                        '$_totalAlertasHoy',
                        Icons.today,
                        Colors.orange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Sin Notificar',
                        '${_alertasNoNotificadas.length}',
                        Icons.notification_important,
                        Colors.red,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        'Actualizacion',
                        '30s',
                        Icons.update,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Botones de accion
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            child: SafeElevatedIconButton(
              onPressed: _marcarCotizacionesEnRiesgo,
              icon: Icons.search,
              label: 'Buscar cotizaciones en riesgo',
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          
          // Lista de alertas
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _alertas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Colors.green[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sin Alertas Activas',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.green[600],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'No hay cotizaciones en riesgo actualmente',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alertas.length,
                        itemBuilder: (context, index) {
                          return _buildAlertaCard(_alertas[index]);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaCard(Map<String, dynamic> alertaData) {
    final createdAt = DateTime.tryParse(alertaData['created_at'] ?? '') ?? DateTime.now();
    final tiempoTranscurrido = alertaData['tiempo_transcurrido'] as int? ?? 0;
    final limiteRespuesta = alertaData['limite_respuesta'] as int? ?? 15;
    final pescadorTelefono = alertaData['pescador_telefono'] as String? ?? 'No disponible';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con informacion critica
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.warning, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COTIZACION EN RIESGO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        Text(
                          'ID: ${alertaData['cotizacion_id']?.toString().substring(0, 8) ?? 'N/A'}...',
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
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'CRITICO',
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
              
              // Informacion de tiempo
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Tiempo sin respuesta: ${_formatDuracion(tiempoTranscurrido)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.access_time, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Limite establecido: $limiteRespuesta min',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: Colors.grey, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Alerta generada: ${_formatDateTime(createdAt)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Informacion de contacto
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'INFORMACION DE CONTACTO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            pescadorTelefono,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            // Accion para llamar
                          },
                          icon: const Icon(Icons.call, color: Colors.green),
                          tooltip: 'Llamar',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Botones de accion
              Row(
                children: [
                  Expanded(
                    child: SafeElevatedIconButton(
                      onPressed: () {
                        // Navegar a detalles de cotizacion
                      },
                      icon: Icons.visibility,
                      label: 'Ver cotización',
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SafeElevatedIconButton(
                      onPressed: () => _marcarComoNotificada(alertaData['id']),
                      icon: Icons.check,
                      label: 'Marcar notificada',
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
