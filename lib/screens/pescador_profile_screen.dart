

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/safe_button.dart';

import '../models/cotizacion.dart';
import '../services/supabase_service.dart';
import 'route_selection_screen.dart';

class PescadorProfileScreen extends StatefulWidget {
  const PescadorProfileScreen({super.key});

  @override
  State<PescadorProfileScreen> createState() => _PescadorProfileScreenState();
}

class _PescadorProfileScreenState extends State<PescadorProfileScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  List<Cotizacion> _cotizaciones = [];
  bool _isLoading = true;
  RealtimeChannel? _cotizacionesChannel;
  
  String get _pescadorId => SupabaseService.currentUserId ?? '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cargarCotizaciones();
    _configurarRealtime();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cotizacionesChannel?.unsubscribe();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _configurarRealtime();
    }
  }

  Future<void> _cargarCotizaciones() async {
    try {
      setState(() => _isLoading = true);
      
      final cotizaciones = await SupabaseService.getCotizacionesPescador(_pescadorId);
      
      setState(() {
        _cotizaciones = cotizaciones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar cotizaciones: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _configurarRealtime() {
    // Cancelar suscripcion anterior si existe
    _cotizacionesChannel?.unsubscribe();
    
    _cotizacionesChannel = SupabaseService.cotizacionesChannel(
      pescadorId: _pescadorId,
      onCotizacionCreada: (cotizacionData) {
        _cargarCotizaciones(); // Recargar datos
        
        // Registrar en logs
        SupabaseService.registrarLogSistema(
          tipo: 'cotizacion_creada',
          descripcion: 'Pescador creo nueva cotizacion',
          userId: _pescadorId,
          cotizacionId: cotizacionData['id'],
          datosAdicionales: {
            'timestamp': DateTime.now().toIso8601String(),
            'estado': cotizacionData['estado'],
          },
        );
      },
      onCotizacionActualizada: (cotizacionData) {
        _cargarCotizaciones(); // Recargar datos
        
        final cotizacion = Cotizacion.fromSupabase(cotizacionData);
        
        // Mostrar notificacion si fue presupuestada
        if (cotizacion.isPresupuestada) {
          _mostrarNotificacionPresupuestoRecibido(cotizacion);
        }
        
        // Registrar en logs
        SupabaseService.registrarLogSistema(
          tipo: 'cotizacion_actualizada',
          descripcion: 'Cotizacion actualizada: ${cotizacion.estado}',
          userId: _pescadorId,
          cotizacionId: cotizacion.id,
          datosAdicionales: {
            'timestamp': DateTime.now().toIso8601String(),
            'estado': cotizacion.estado,
            'presupuesto_monto': cotizacion.presupuestoMonto,
          },
        );
      },
    );
    
    _cotizacionesChannel?.subscribe();
  }

  void _mostrarNotificacionPresupuestoRecibido(Cotizacion cotizacion) {
    if (!mounted) return;
    
    // Mostrar SnackBar inmediato
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.monetization_on, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¡Presupuesto Recibido!',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    cotizacion.presupuestoFormateado,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Ver',
          textColor: Colors.white,
          onPressed: () {
            _mostrarPantallaPresupuestoRecibido(cotizacion);
          },
        ),
      ),
    );
    
    // Tambien mostrar dialogo emergente
    _mostrarDialogoEmergente(cotizacion);
  }

  void _mostrarDialogoEmergente(Cotizacion cotizacion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.monetization_on, color: Colors.green),
            const SizedBox(width: 8),
            const Text('¡Presupuesto Recibido!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El capitan ha respondido a tu solicitud:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cotizacion.descripcion,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.attach_money, color: Colors.green[600], size: 20),
                      const SizedBox(width: 4),
                      Text(
                        cotizacion.presupuestoFormateado,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[600],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Mas Tarde'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _mostrarPantallaPresupuestoRecibido(cotizacion);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver Presupuesto'),
          ),
        ],
      ),
    );
  }

  void _mostrarPantallaPresupuestoRecibido(Cotizacion cotizacion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PresupuestoRecibidoScreen(cotizacion: cotizacion),
      ),
    );
  }

  void _crearNuevaCotizacion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteSelectionScreen(
          onRouteSelected: (partida, destino, descripcion) async {
            await _crearCotizacionConRuta(descripcion, partida, destino);
          },
        ),
      ),
    );
  }

  Future<void> _crearCotizacionConRuta(
    String descripcion, 
    Map<String, dynamic> partida, 
    Map<String, dynamic> destino
  ) async {
    try {
      // Crear cotizacion con matchmaking con pulso de tiempo real
      final resultado = await SupabaseService.matchmakingConPulso(
        _pescadorId,
        descripcion,
        partida,
        destino,
      );
      
      if (mounted) {
        if (resultado['asignacion_exitosa'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('Solicitud enviada correctamente')),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Volver de la pantalla de seleccion de ruta
        } else {
          // No hay capitanes disponibles en la zona
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Sin Capitanes Disponibles'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'No hay capitanes disponibles en esta zona en este momento.',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Mensaje del sistema: ${resultado['mensaje']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[200]!),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Intenta nuevamente mas tarde o ajusta tu ubicacion.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
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
                  child: const Text('Entendido'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context); // Volver al perfil
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D47A1),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Volver al Perfil'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al crear cotizacion: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarCotizaciones,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarCotizaciones,
              child: Column(
                children: [
                  // Header del perfil
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0D47A1),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.person,
                            size: 40,
                            color: Colors.blue[800],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Pescador Demo',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${_pescadorId.substring(0, 8)}...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Boton para nueva cotizacion
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    child: SafeElevatedIconButton(
  onPressed: _crearNuevaCotizacion,
  icon: Icons.add,
  label: 'Nueva Solicitud de Cotizacion',
  style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
),
                  ),
                  
                  // Lista de cotizaciones
                  Expanded(
                    child: _cotizaciones.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay cotizaciones',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Crea tu primera solicitud de cotizacion',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _cotizaciones.length,
                            itemBuilder: (context, index) {
                              return _buildCotizacionCard(_cotizaciones[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildCotizacionCard(Cotizacion cotizacion) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  cotizacion.estadoIcono,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cotizacion.descripcion,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getEstadoColor(cotizacion.estado),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cotizacion.estadoFormateado,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            if (cotizacion.hasPresupuesto)
              Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.green[600], size: 20),
                  const SizedBox(width: 4),
                  Text(
                    cotizacion.presupuestoFormateado,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 8),
            
            Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey[600], size: 16),
                const SizedBox(width: 4),
                Text(
                  'Creada: ${_formatDateTime(cotizacion.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (cotizacion.tiempoRespuesta != null) ...[
                  const SizedBox(width: 16),
                  Icon(Icons.timer, color: Colors.blue[600], size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Respuesta: ${cotizacion.tiempoRespuestaFormateado}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[600],
                    ),
                  ),
                ],
              ],
            ),
            
            if (cotizacion.isPresupuestada)
              const SizedBox(height: 12),
            
            if (cotizacion.isPresupuestada)
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _mostrarPantallaPresupuestoRecibido(cotizacion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Ver Presupuesto'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _mostrarDialogoRespuesta(cotizacion),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Responder'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _mostrarDialogoRespuesta(Cotizacion cotizacion) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Responder Presupuesto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              cotizacion.descripcion,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.attach_money, color: Colors.green[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    cotizacion.presupuestoFormateado,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Aceptas o rechazas este presupuesto?',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _responderCotizacion(cotizacion.id, Cotizacion.ESTADO_RECHAZADO);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Rechazar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _responderCotizacion(cotizacion.id, Cotizacion.ESTADO_ACEPTADO);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Future<void> _responderCotizacion(String cotizacionId, String respuesta) async {
    try {
      await SupabaseService.responderCotizacion(cotizacionId, respuesta);
      
      // Registrar en logs
      SupabaseService.registrarLogSistema(
        tipo: respuesta == Cotizacion.ESTADO_ACEPTADO ? 'cotizacion_aceptada' : 'cotizacion_rechazada',
        descripcion: 'Pescador ${respuesta == Cotizacion.ESTADO_ACEPTADO ? 'acepto' : 'rechazo'} el presupuesto',
        userId: _pescadorId,
        cotizacionId: cotizacionId,
        datosAdicionales: {
          'timestamp': DateTime.now().toIso8601String(),
          'respuesta': respuesta,
        },
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(respuesta == Cotizacion.ESTADO_ACEPTADO 
                  ? 'Presupuesto aceptado' 
                  : 'Presupuesto rechazado'),
            ),
            backgroundColor: respuesta == Cotizacion.ESTADO_ACEPTADO 
                ? Colors.green 
                : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al responder: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case Cotizacion.ESTADO_PENDIENTE:
        return Colors.orange;
      case Cotizacion.ESTADO_PRESUPUESTADO:
        return Colors.blue;
      case Cotizacion.ESTADO_ACEPTADO:
        return Colors.green;
      case Cotizacion.ESTADO_RECHAZADO:
        return Colors.red;
      case Cotizacion.ESTADO_EN_VIAJE:
        return Colors.indigo;
      case Cotizacion.ESTADO_FINALIZADO:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

// Pantalla de Presupuesto Recibido
class PresupuestoRecibidoScreen extends StatelessWidget {
  final Cotizacion cotizacion;

  const PresupuestoRecibidoScreen({
    super.key,
    required this.cotizacion,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Presupuesto Recibido'),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card principal del presupuesto
            Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.green[50]!,
                      Colors.green[100]!,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.monetization_on,
                      size: 64,
                      color: Colors.green[600],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '¡Presupuesto Recibido!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El capitan ha respondido a tu solicitud',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Monto del presupuesto
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Presupuesto',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cotizacion.presupuestoFormateado,
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Detalles de la solicitud
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Detalles de la Solicitud',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailRow('Descripcion', cotizacion.descripcion),
                    _buildDetailRow('Estado', cotizacion.estadoFormateado),
                    _buildDetailRow('Fecha de Creacion', _formatDateTime(cotizacion.createdAt)),
                    if (cotizacion.presupuestoAt != null)
                      _buildDetailRow('Fecha de Presupuesto', _formatDateTime(cotizacion.presupuestoAt!)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Botones de accion
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await SupabaseService.responderCotizacion(
                          cotizacion.id, 
                          Cotizacion.ESTADO_RECHAZADO
                        );
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Center(child: Text('Presupuesto rechazado')),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Center(child: Text('Error: $e')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Rechazar Presupuesto'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await SupabaseService.responderCotizacion(
                          cotizacion.id, 
                          Cotizacion.ESTADO_ACEPTADO
                        );
                        
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Center(child: Text('¡Presupuesto aceptado!')),
                              backgroundColor: Colors.green,
                            ),
                          );
                          Navigator.pop(context);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Center(child: Text('Error: $e')),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Aceptar Presupuesto'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
