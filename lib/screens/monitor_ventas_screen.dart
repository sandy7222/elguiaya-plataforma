

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/perfil_capitan.dart';
import '../services/supabase_service.dart';

class MonitorVentasScreen extends StatefulWidget {
  const MonitorVentasScreen({super.key});

  @override
  State<MonitorVentasScreen> createState() => _MonitorVentasScreenState();
}

class _MonitorVentasScreenState extends State<MonitorVentasScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Map<String, dynamic>> _cotizacionesPendientes = [];
  PerfilCapitan? _perfilCapitan;
  bool _isLoading = true;
  Timer? _contadorTimer;
  RealtimeChannel? _alertasChannel;
  
  // ID de prueba para el capitan (sin Auth)
  final String _capitanId = '22222222-2222-2222-2222-222222222222';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarDatos();
    _iniciarContadorRegresivo();
    _configurarAlertasRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _contadorTimer?.cancel();
    _alertasChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cargarDatos();
      _iniciarContadorRegresivo();
      _configurarAlertasRealtime();
    } else if (state == AppLifecycleState.paused) {
      _contadorTimer?.cancel();
    }
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      // Cargar perfil del capitan
      final perfil = await SupabaseService.getPerfilCapitan(_capitanId);
      
      // Cargar cotizaciones pendientes con tiempo
      final cotizaciones = await SupabaseService.getCotizacionesPendientesConTiempo(_capitanId);
      
      setState(() {
        _perfilCapitan = perfil;
        _cotizacionesPendientes = cotizaciones;
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

  void _iniciarContadorRegresivo() {
    _contadorTimer?.cancel();
    _contadorTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          // Actualizar tiempos restantes
        });
      }
    });
  }

  void _configurarAlertasRealtime() {
    _alertasChannel?.unsubscribe();
    
    _alertasChannel = SupabaseService.alertasChannel(
      onAlertaCreada: (alertaData) {
        _mostrarAlertaCritica(alertaData);
      },
    );
    
    _alertasChannel?.subscribe();
  }

  void _mostrarAlertaCritica(Map<String, dynamic> alertaData) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('¡ALERTA DE NEGOCIO!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cotizacion en RIESGO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tiempo sin respuesta: ${alertaData['tiempo_transcurrido']} min',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    'Limite: ${alertaData['limite_respuesta']} min',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Contactar inmediatamente:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  const Icon(Icons.phone, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    alertaData['pescador_telefono'] ?? 'No disponible',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _marcarAlertaNotificada(alertaData['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Future<void> _marcarAlertaNotificada(String alertaId) async {
    try {
      await SupabaseService.marcarAlertaNotificada(alertaId);
    } catch (e) {
      print('Error al marcar alerta: $e');
    }
  }

  void _mostrarDialogoConfiguracion() {
    final limiteController = TextEditingController(
      text: _perfilCapitan?.limiteRespuestaMinutos.toString() ?? '15',
    );
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar Tiempo de Respuesta'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Establece tu limite de respuesta para cotizaciones:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: limiteController,
              decoration: InputDecoration(
                labelText: 'Limite (minutos)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                suffixText: 'min',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Text(
              'Este limite se usara para alertas y metricas de cumplimiento.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
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
              final limite = int.tryParse(limiteController.text);
              if (limite != null && limite > 0) {
                Navigator.pop(context);
                await _actualizarLimiteRespuesta(limite);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D47A1),
              foregroundColor: Colors.white,
            ),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _actualizarLimiteRespuesta(int limiteMinutos) async {
    try {
      await SupabaseService.actualizarLimiteRespuesta(_capitanId, limiteMinutos);
      await _cargarDatos();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('Limite de respuesta actualizado')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al actualizar limite: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatTiempoRestante(int minutosRestantes) {
    if (minutosRestantes <= 0) return 'Vencida';
    
    if (minutosRestantes < 60) {
      return '$minutosRestantes min';
    } else {
      final horas = minutosRestantes ~/ 60;
      final minutos = minutosRestantes % 60;
      return '${horas}h ${minutos}min';
    }
  }

  Color _getColorPorUrgencia(double porcentajeUsado) {
    if (porcentajeUsado >= 100) return Colors.red;
    if (porcentajeUsado >= 80) return Colors.orange;
    if (porcentajeUsado >= 50) return Colors.yellow[700]!;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Monitor de Ventas Potenciales',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
          IconButton(
            onPressed: _mostrarDialogoConfiguracion,
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Header con configuracion
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0D47A1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.timer, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            'Limite de Respuesta: ${_perfilCapitan?.limiteRespuestaFormateado ?? '15 minutos'}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${_cotizacionesPendientes.length} Pendientes',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tiempo actualizado cada segundo',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Lista de cotizaciones con contador regresivo
                Expanded(
                  child: _cotizacionesPendientes.isEmpty
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
                                '¡Todo en orden!',
                                style: TextStyle(
                                  fontSize: 20,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No hay cotizaciones pendientes',
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
                          itemCount: _cotizacionesPendientes.length,
                          itemBuilder: (context, index) {
                            return _buildCotizacionConContador(_cotizacionesPendientes[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCotizacionConContador(Map<String, dynamic> cotizacionData) {
    final descripcion = cotizacionData['descripcion'] as String? ?? '';
    final tiempoTranscurrido = cotizacionData['tiempo_transcurrido'] as int? ?? 0;
    final limiteRespuesta = cotizacionData['limite_respuesta'] as int? ?? 15;
    final tiempoRestante = cotizacionData['tiempo_restante'] as int? ?? 0;
    final porcentajeUsado = cotizacionData['porcentaje_tiempo_usado'] as double? ?? 0.0;
    final estado = cotizacionData['estado_actual'] as String? ?? 'pendiente';
    
    final colorUrgencia = _getColorPorUrgencia(porcentajeUsado);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorUrgencia.withOpacity(0.3), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con estado y tiempo
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorUrgencia.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      estado == 'en_riesgo' ? Icons.warning : Icons.timer,
                      color: colorUrgencia,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          descripcion.length > 50 
                              ? '${descripcion.substring(0, 47)}...'
                              : descripcion,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Transcurrido: $tiempoTranscurrido min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colorUrgencia,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _formatTiempoRestante(tiempoRestante),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Barra de progreso de tiempo
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tiempo de respuesta',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '${porcentajeUsado.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorUrgencia,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: porcentajeUsado / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(colorUrgencia),
                    minHeight: 8,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Botones de accion
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navegar para presupuestar
                      },
                      icon: const Icon(Icons.attach_money),
                      label: const Text('Presupuestar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  if (estado == 'en_riesgo') ...[
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Llamar al pescador
                      },
                      icon: const Icon(Icons.phone),
                      label: const Text('Llamar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
