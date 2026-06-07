

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/supabase_service.dart';

class SeguimientoEnviosScreen extends StatefulWidget {
  const SeguimientoEnviosScreen({super.key});

  @override
  State<SeguimientoEnviosScreen> createState() => _SeguimientoEnviosScreenState();
}

class _SeguimientoEnviosScreenState extends State<SeguimientoEnviosScreen> {
  List<Map<String, dynamic>> _envios = [];
  bool _isLoading = true;
  
  // Colores CapitanYA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);
  static const Color _grisDescanso = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _cargarEnvios();
  }

  Future<void> _cargarEnvios() async {
    try {
      setState(() => _isLoading = true);
      
      final envios = await SupabaseService.getSeguimientoPescador(
        '11111111-1111-1111-1111-111111111111', // ID de prueba pescador
      );
      
      setState(() {
        _envios = envios;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar envios: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _abrirSeguimiento(String trackingUrl) async {
    if (trackingUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('⏳ Codigo de tracking aun no disponible')),
          backgroundColor: _naranjaAlerta,
        ),
      );
      return;
    }

    try {
      final uri = Uri.parse(trackingUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir el enlace';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al abrir seguimiento: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copiarTracking(String trackingCodigo) {
    // Aqui implementariamos el copiado al portapapeles
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Center(child: Text('📋 Codigo copiado al portapapeles')),
        backgroundColor: _verdeExito,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_shipping, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Seguimiento de Envios'),
          ],
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarEnvios,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _envios.isEmpty
              ? _buildEstadoVacio()
              : RefreshIndicator(
                  onRefresh: _cargarEnvios,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _envios.length,
                    itemBuilder: (context, index) {
                      final envio = _envios[index];
                      return _buildEnvioCard(envio);
                    },
                  ),
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
              Icons.local_shipping_outlined,
              size: 64,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin Envios Activos',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No tienes envios en seguimiento\nen este momento.',
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

  Widget _buildEnvioCard(Map<String, dynamic> envio) {
    final estadoColor = Color(int.tryParse(envio['color_estado'] as String? ?? '') ?? 0xFF6B7280);
    final estadoIcon = _getEstadoIcon(envio['estado_envio'] as String? ?? '');
    final tieneTracking = envio['tracking_codigo'] != null && envio['tracking_codigo'].toString().isNotEmpty;
    
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
            // Header con estado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: estadoColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(estadoIcon, color: estadoColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${envio['pedido_id']?.toString().substring(0, 8) ?? 'Unknown'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: _azulNautico,
                        ),
                      ),
                      Text(
                        envio['estado_formateado'] ?? 'Desconocido',
                        style: TextStyle(
                          fontSize: 12,
                          color: estadoColor,
                          fontWeight: FontWeight.w500,
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
                    envio['transportista'] ?? 'Correo Argentino',
                    style: TextStyle(
                      color: estadoColor,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Informacion de envio
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
                      Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          envio['direccion_entrega'] ?? 'Direccion no especificada',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (envio['fecha_despacho'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Despachado: ${_formatDate(envio['fecha_despacho'])}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (envio['fecha_estimada_entrega'] != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.event, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Entrega estimada: ${_formatDate(envio['fecha_estimada_entrega'])}',
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
            
            // Codigo de tracking
            if (tieneTracking) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _azulNautico.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _azulNautico.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.local_shipping, color: _azulNautico, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Codigo de Seguimiento',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _azulNautico,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            envio['tracking_codigo'] ?? '',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: _azulNautico,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _copiarTracking(envio['tracking_codigo']),
                          icon: const Icon(Icons.copy),
                          iconSize: 20,
                          color: _azulNautico,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Botones de accion
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _abrirSeguimiento(envio['enlace_seguimiento'] ?? ''),
                    icon: const Icon(Icons.open_in_browser),
                    label: Text(
                      tieneTracking ? 'Seguir en Correo Argentino' : 'Ver Detalles',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _azulNautico,
                    ),
                  ),
                ),
                if (tieneTracking) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _copiarTracking(envio['tracking_codigo']),
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copiar codigo',
                    style: IconButton.styleFrom(
                      backgroundColor: _azulNautico,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getEstadoIcon(String estado) {
    switch (estado.toLowerCase()) {
      case 'entregado':
        return Icons.check_circle;
      case 'en_transito':
        return Icons.local_shipping;
      case 'despachado':
        return Icons.inventory_2;
      case 'preparando':
        return Icons.inventory;
      default:
        return Icons.help_outline;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }
}
