

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/supabase_service.dart';

class AdminAlertasSeguridadScreen extends StatefulWidget {
  const AdminAlertasSeguridadScreen({super.key});

  @override
  State<AdminAlertasSeguridadScreen> createState() => _AdminAlertasSeguridadScreenState();
}

class _AdminAlertasSeguridadScreenState extends State<AdminAlertasSeguridadScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
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
    _cargarAlertas();
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
      _cargarAlertas();
      _iniciarActualizacionAutomatica();
    } else if (state == AppLifecycleState.paused) {
      _actualizacionTimer?.cancel();
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

  Future<void> _cargarAlertas() async {
    try {
      setState(() => _isLoading = true);
      
      final alertas = await SupabaseService.getAlertasSeguridad();
      
      setState(() {
        _alertas = alertas;
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

  Future<void> _enviarAdvertencia(Map<String, dynamic> alerta) async {
    final TextEditingController mensajeController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: _naranjaAlerta),
            const SizedBox(width: 8),
            const Text('Enviar Advertencia'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capitan: ${alerta['capitan_nombre']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tipo: ${alerta['tipo_alerta']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Texto detectado: "${alerta['texto_detectado']}"',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 16),
            const Text('Mensaje personalizado (opcional):'),
            const SizedBox(height: 8),
            TextField(
              controller: mensajeController,
              maxLines: 4,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Deja vacio para usar mensaje por defecto...',
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
              await _procesarAdvertencia(alerta, mensajeController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _naranjaAlerta,
              foregroundColor: Colors.white,
            ),
            child: const Text('Enviar Advertencia'),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarAdvertencia(Map<String, dynamic> alerta, String mensaje) async {
    try {
      final resultado = await SupabaseService.enviarAdvertenciaCapitan(
        alerta['id'],
        '11111111-1111-1111-1111-111111111111', // ID de prueba admin
        mensaje.isEmpty ? null : mensaje,
      );
      
      if (mounted) {
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('✅ Advertencia enviada exitosamente')),
              backgroundColor: _verdeExito,
            ),
          );
          _cargarAlertas(); // Recargar alertas
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
            content: Center(child: Text('Error al enviar advertencia: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _suspenderCapitan(Map<String, dynamic> alerta) async {
    final TextEditingController motivoController = TextEditingController();
    int dias = 7;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.block, color: _rojoProblema),
              const SizedBox(width: 8),
              const Text('Suspender Capitan'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Capitan: ${alerta['capitan_nombre']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Alertas previas: ${alerta['total_alertas']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Suspensiones activas: ${alerta['suspensiones_activas']}',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              const Text('Duracion de la suspension:'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: dias.toDouble(),
                      min: 1,
                      max: 30,
                      divisions: 29,
                      label: '$dias dias',
                      onChanged: (value) {
                        setState(() => dias = value.round());
                      },
                    ),
                  ),
                  Container(
                    width: 60,
                    alignment: Alignment.center,
                    child: Text(
                      '$dias dias',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Motivo de la suspension:'),
              const SizedBox(height: 8),
              TextField(
                controller: motivoController,
                maxLines: 3,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Motivo de la suspension...',
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
                await _procesarSuspension(alerta, dias, motivoController.text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _rojoProblema,
                foregroundColor: Colors.white,
              ),
              child: const Text('Suspender'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _procesarSuspension(Map<String, dynamic> alerta, int dias, String motivo) async {
    try {
      final resultado = await SupabaseService.suspenderCapitan(
        alerta['id'],
        '11111111-1111-1111-1111-111111111111', // ID de prueba admin
        'temporal',
        dias,
        motivo.isEmpty ? null : motivo,
      );
      
      if (mounted) {
        if (resultado['exito'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('🚫 Capitan suspendido por $dias dias')),
              backgroundColor: _rojoProblema,
            ),
          );
          _cargarAlertas(); // Recargar alertas
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
            content: Center(child: Text('Error al suspender capitan: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _verMensajeCompleto(Map<String, dynamic> alerta) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.message, color: _azulNautico),
            const SizedBox(width: 8),
            const Text('Mensaje Completo'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Capitan: ${alerta['capitan_nombre']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Tipo de alerta: ${alerta['tipo_alerta']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Severidad: ${alerta['severidad_formateada']}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            const Text(
              'Mensaje original:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                alerta['texto_original'] ?? 'Sin mensaje',
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Texto detectado:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _rojoProblema.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _rojoProblema.withOpacity(0.3)),
              ),
              child: Text(
                alerta['texto_detectado'] ?? 'Sin texto detectado',
                style: TextStyle(
                  color: _rojoProblema,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.security, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Alertas de Seguridad'),
          ],
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarAlertas,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _alertas.isEmpty
              ? _buildEstadoVacio()
              : Column(
                  children: [
                    // Header de estadisticas
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _azulNautico,
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Alertas Activas',
                              '${_alertas.length}',
                              Icons.warning,
                              Colors.white,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              'Criticas',
                              '${_alertas.where((a) => a['severidad'] == 'critica').length}',
                              Icons.priority_high,
                              _rojoProblema,
                            ),
                          ),
                          Expanded(
                            child: _buildStatCard(
                              'Altas',
                              '${_alertas.where((a) => a['severidad'] == 'alta').length}',
                              Icons.trending_up,
                              _naranjaAlerta,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Lista de alertas
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _alertas.length,
                        itemBuilder: (context, index) {
                          final alerta = _alertas[index];
                          return _buildAlertaCard(alerta);
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
              Icons.security,
              size: 64,
              color: _verdeExito,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '¡Sin Alertas de Seguridad!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _verdeExito,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No hay alertas de seguridad pendientes\nen este momento.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
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
              fontSize: 10,
              color: color.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertaCard(Map<String, dynamic> alerta) {
    final colorStr = alerta['color_severidad'] as String? ?? '0xFF6B7280';
    final severidadColor = Color(int.tryParse(colorStr) ?? 0xFF6B7280);
    final severidadIcon = alerta['severidad'] == 'critica' 
        ? Icons.priority_high 
        : alerta['severidad'] == 'alta' 
            ? Icons.warning 
            : Icons.info;
    
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
            // Header con informacion del capitan y severidad
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _azulNautico.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: _azulNautico, width: 2),
                  ),
                  child: alerta['capitan_foto'] != null
                      ? ClipOval(
                          child: Image.network(
                            alerta['capitan_foto'],
                            width: 36,
                            height: 36,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.person, color: _azulNautico);
                            },
                          ),
                        )
                      : const Icon(Icons.person, color: _azulNautico),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alerta['capitan_nombre'] ?? 'Capitan desconocido',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      Text(
                        'Alertas: ${alerta['total_alertas']} | Suspensiones: ${alerta['suspensiones_activas']}',
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
                    color: severidadColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: severidadColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(severidadIcon, color: severidadColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        alerta['severidad_formateada'] ?? 'Media',
                        style: TextStyle(
                          color: severidadColor,
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
            
            // Informacion de la alerta
            Container(
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
                      Icon(Icons.category, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Tipo: ${alerta['tipo_alerta']}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        _formatTimestamp(alerta['creado_at']),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.search, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Detectado: "${alerta['texto_detectado']}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Botones de accion
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => _verMensajeCompleto(alerta),
                  icon: const Icon(Icons.visibility),
                  label: const Text('Ver Mensaje'),
                  style: TextButton.styleFrom(
                    foregroundColor: _azulNautico,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _enviarAdvertencia(alerta),
                  icon: const Icon(Icons.warning),
                  label: const Text('Advertencia'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _naranjaAlerta,
                    foregroundColor: Colors.white,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _suspenderCapitan(alerta),
                  icon: const Icon(Icons.block),
                  label: const Text('Suspension'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rojoProblema,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);
      
      if (difference.inMinutes < 60) {
        return 'Hace ${difference.inMinutes} min';
      } else if (difference.inHours < 24) {
        return 'Hace ${difference.inHours} h';
      } else {
        return '${dateTime.day}/${dateTime.month}';
      }
    } catch (e) {
      return 'Desconocido';
    }
  }
}

// Importar Timer para actualizacion automatica
