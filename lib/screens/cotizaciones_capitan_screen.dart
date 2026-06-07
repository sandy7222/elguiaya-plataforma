
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/cotizaciones_service.dart';
import 'cotizaciones_formulario_fixed.dart';

class CotizacionesCapitanScreen extends StatefulWidget {
  const CotizacionesCapitanScreen({super.key});

  @override
  State<CotizacionesCapitanScreen> createState() => _CotizacionesCapitanScreenState();
}

class _CotizacionesCapitanScreenState extends State<CotizacionesCapitanScreen> {
  List<Map<String, dynamic>> _cotizaciones = [];
  bool _isLoading = true;
  String _filtroEstado = 'todos';
  String _busqueda = '';
  int _paginaActual = 1;
  final int _limitePorPagina = 10;

  // ── Bloqueo blando: documentación vencida ──────────────────────────
  bool _docsVencidos = false;
  String _motivoVencimiento = '';
  String _capitanUuid = '';

  // Colores CapitanYA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _rojoFuerte = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _verificarDocumentos();
    _cargarCotizaciones();
  }

  Future<void> _verificarDocumentos() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;
      _capitanUuid = user.id;

      final perfil = await Supabase.instance.client
          .from('profiles')
          .select('vencimiento_seguro, vencimiento_carnet')
          .eq('user_id', user.id)
          .maybeSingle();

      if (perfil == null) return;
      final hoy = DateTime.now();
      final motivosVencidos = <String>[];

      if (perfil['vencimiento_seguro'] != null) {
        final fecha = DateTime.tryParse(perfil['vencimiento_seguro'] as String);
        if (fecha != null && fecha.isBefore(hoy)) {
          motivosVencidos.add('Seguro de Embarcación');
        }
      }
      if (perfil['vencimiento_carnet'] != null) {
        final fecha = DateTime.tryParse(perfil['vencimiento_carnet'] as String);
        if (fecha != null && fecha.isBefore(hoy)) {
          motivosVencidos.add('Carnet de Timonel');
        }
      }

      if (motivosVencidos.isNotEmpty && mounted) {
        setState(() {
          _docsVencidos = true;
          _motivoVencimiento = motivosVencidos.join(' y ');
        });
      }
    } catch (e) {
      // No bloquear la app si falla la verificación
    }
  }

  Future<void> _cargarCotizaciones() async {
    setState(() => _isLoading = true);
    
    try {
      final cotizaciones = await CotizacionesService.obtenerCotizacionesCapitan(
        limite: _limitePorPagina,
        offset: (_paginaActual - 1) * _limitePorPagina,
      );
      
      setState(() {
        _cotizaciones = cotizaciones;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar cotizaciones: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  Future<void> _actualizarEstado(String cotizacionId, String nuevoEstado) async {
    final resultado = await CotizacionesService.actualizarEstadoCotizacion(
      cotizacionId: cotizacionId,
      nuevoEstado: nuevoEstado,
      motivo: 'Actualizado desde Portal del Capitan',
      usuarioId: 'capitan-001',
    );

    if (resultado['success']) {
      _cargarCotizaciones(); // Recargar lista
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cotizacion actualizada correctamente'),
          backgroundColor: _verdeBrillante,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al actualizar: ${resultado['error']}'),
          backgroundColor: _rojoFuerte,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _cotizacionesFiltradas {
    var filtradas = _cotizaciones;
    
    // Filtrar por estado
    if (_filtroEstado != 'todos') {
      filtradas = filtradas.where((cot) => cot['status'] == _filtroEstado).toList();
    }
    
    // Filtrar por busqueda
    if (_busqueda.isNotEmpty) {
      final query = _busqueda.toLowerCase();
      filtradas = filtradas.where((cot) => 
        (cot['titulo']?.toString().toLowerCase().contains(query) ?? false) ||
        (cot['descripcion']?.toString().toLowerCase().contains(query) ?? false) ||
        (cot['pescador_nombre']?.toString().toLowerCase().contains(query) ?? false)
      ).toList();
    }
    
    return filtradas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: _blancoPuro, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Portal del Capitan - Cotizaciones',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _cargarCotizaciones,
            icon: const Icon(Icons.refresh, color: _blancoPuro),
            tooltip: 'Actualizar',
          ),
          IconButton(
            onPressed: () => _mostrarEstadisticas(),
            icon: const Icon(Icons.analytics, color: _blancoPuro),
            tooltip: 'Estadisticas',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Banner bloqueo blando (doc vencida) ────────────────────────
          if (_docsVencidos) _buildBannerDocsVencidos(),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _blancoPuro.withOpacity(0.1),
              border: Border(
                bottom: BorderSide(color: _blancoPuro.withOpacity(0.2)),
              ),
            ),
            child: Column(
              children: [
                // Busqueda
                TextField(
                  onChanged: (value) => setState(() => _busqueda = value),
                  decoration: InputDecoration(
                    hintText: 'Buscar cotizaciones...',
                    hintStyle: TextStyle(color: _blancoPuro.withOpacity(0.5)),
                    prefixIcon: const Icon(Icons.search, color: _blancoPuro),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _azulVibrante.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: _azulVibrante, width: 2),
                    ),
                  ),
                  style: const TextStyle(color: _blancoPuro),
                ),
                const SizedBox(height: 12),
                
                // Filtros de estado
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFiltroBoton('todos', 'Todos'),
                      _buildFiltroBoton('pendiente', 'Pendientes'),
                      _buildFiltroBoton('enviado', 'Enviados'),
                      _buildFiltroBoton('aceptado', 'Aceptados'),
                      _buildFiltroBoton('rechazado', 'Rechazados'),
                      _buildFiltroBoton('vencido', 'Vencidos'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Lista de cotizaciones
          Expanded(
            child: _docsVencidos
                ? _buildContenidoBloqueado()
                : _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _azulVibrante),
                  )
                : _cotizacionesFiltradas.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.receipt_long_outlined,
                              color: _blancoPuro,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay cotizaciones',
                              style: TextStyle(
                                color: _blancoPuro,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _filtroEstado != 'todos' || _busqueda.isNotEmpty
                                  ? 'Intenta con otros filtros o terminos de busqueda'
                                  : 'No tienes cotizaciones activas',
                              style: TextStyle(
                                color: _blancoPuro.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _cotizacionesFiltradas.length,
                        itemBuilder: (context, index) {
                          final cotizacion = _cotizacionesFiltradas[index];
                          return _buildCotizacionCard(cotizacion);
                        },
                      ),
          ),
          
          // Paginacion
          if (!_isLoading && _cotizacionesFiltradas.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _paginaActual > 1
                        ? () {
                            setState(() => _paginaActual--);
                            _cargarCotizaciones();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left, color: _blancoPuro),
                  ),
                  const SizedBox(width: 20),
                  Text(
                    'Pagina $_paginaActual',
                    style: const TextStyle(color: _blancoPuro, fontSize: 14),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: _cotizacionesFiltradas.length >= _limitePorPagina
                        ? () {
                            setState(() => _paginaActual++);
                            _cargarCotizaciones();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right, color: _blancoPuro),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioCotizacion,
        backgroundColor: _azulVibrante,
        tooltip: 'Nueva Cotizacion',
        child: const Icon(Icons.add, color: _blancoPuro),
      ),
    );
  }

  // ── BLOQUEO BLANDO: Banner y pantalla de documentación vencida ──────────

  /// Banner sutil que aparece en la parte superior de la pantalla.
  /// No bloquea la navegación, solo informa la situación.
  Widget _buildBannerDocsVencidos() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6600).withOpacity(0.15),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF6600).withOpacity(0.4),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF6600), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'ⓘ  $_motivoVencimiento vencido. Para regularizar tu documentación, contactá a soporte.',
              style: const TextStyle(
                color: Color(0xFFFF6600),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: _contactarSoporteWhatsApp,
            child: const Text(
              'IR A SOPORTE',
              style: TextStyle(
                color: Color(0xFF25D366),
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Reemplaza la lista de cotizaciones cuando los docs están vencidos.
  Widget _buildContenidoBloqueado() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF6600).withOpacity(0.1),
                border: Border.all(
                  color: const Color(0xFFFF6600).withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.lock_clock_outlined,
                color: Color(0xFFFF6600),
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Cotizaciones temporalmente inactivas',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blancoPuro,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Tu $_motivoVencimiento está vencido.\n'
              'Para volver a recibir solicitudes de pescadores,\n'
              'regularizá tu documentación con el equipo de Capitán-YA.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.7),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _contactarSoporteWhatsApp,
              icon: const Icon(Icons.chat, size: 18),
              label: const Text(
                'Contactar Soporte por WhatsApp',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Volver al panel',
                style: TextStyle(color: _blancoPuro.withOpacity(0.5), fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre WhatsApp incluyendo el UUID del capitán en el mensaje
  /// para que soporte lo identifique sin pedirle datos al usuario.
  Future<void> _contactarSoporteWhatsApp() async {
    final uuid = _capitanUuid.isNotEmpty ? _capitanUuid : 'no-identificado';
    final mensaje = Uri.encodeComponent(
      'Hola, soy el capitán con UUID: $uuid\n'
      'Necesito regularizar mi documentación ($_motivoVencimiento).\n'
      'Quedo a disposición. Gracias.',
    );
    final url = Uri.parse('https://wa.me/5493624000000?text=$mensaje');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Widget _buildFiltroBoton(String valor, String etiqueta) {
    final isSelected = _filtroEstado == valor;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(etiqueta),
        selected: isSelected,
        onSelected: (selected) {
          setState(() => _filtroEstado = valor);
        },
        backgroundColor: isSelected ? _azulVibrante : _blancoPuro.withOpacity(0.1),
        labelStyle: TextStyle(
          color: isSelected ? _blancoPuro : _blancoPuro.withOpacity(0.7),
        ),
        side: BorderSide(
          color: isSelected ? _azulVibrante : _blancoPuro.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildCotizacionCard(Map<String, dynamic> cotizacion) {
    final status = cotizacion['status'] as String;
    final monto = cotizacion['monto_total'] as double;
    final fechaSolicitud = cotizacion['fecha_solicitud'] as String;
    final vencido = cotizacion['vencido'] as bool? ?? false;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status) {
      case 'pendiente':
        statusColor = _naranjaIntenso;
        statusIcon = Icons.pending;
        statusText = '⏳ Pendiente';
        break;
      case 'enviado':
        statusColor = _azulVibrante;
        statusIcon = Icons.send;
        statusText = '📤 Enviado';
        break;
      case 'aceptado':
        statusColor = _verdeBrillante;
        statusIcon = Icons.check_circle;
        statusText = '✅ Aceptado';
        break;
      case 'rechazado':
        statusColor = _rojoFuerte;
        statusIcon = Icons.cancel;
        statusText = '❌ Rechazado';
        break;
      case 'vencido':
        statusColor = _rojoFuerte;
        statusIcon = Icons.timer_off;
        statusText = '⏰ Vencido';
        break;
      default:
        statusColor = _blancoPuro;
        statusIcon = Icons.help;
        statusText = status;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: vencido ? _rojoFuerte.withOpacity(0.5) : _blancoPuro.withOpacity(0.1),
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(statusIcon, color: _blancoPuro, size: 20),
        ),
        title: Text(
          cotizacion['titulo'],
          style: const TextStyle(
            color: _blancoPuro,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              cotizacion['pescador_nombre'],
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    cotizacion['viaje_nombre'],
                    style: TextStyle(
                      color: _azulVibrante,
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  '📏 ${(cotizacion['distancia_km'] ?? 0.0).toStringAsFixed(1)} km',
                  style: const TextStyle(
                    color: _blancoPuro,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${monto.toStringAsFixed(0)}',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              statusText,
              style: TextStyle(
                color: statusColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('📅 Fecha Solicitud', _formatearFecha(fechaSolicitud)),
                Row(
                  children: [
                    Expanded(child: _buildInfoRow('📏 Recorrido Trazado', '${(cotizacion['distancia_km'] ?? 0.0).toStringAsFixed(1)} km')),
                    if (cotizacion['coordenadas_partida'] != null && cotizacion['coordenadas_destino'] != null)
                      TextButton.icon(
                        onPressed: () => _mostrarMapaRecorrido(cotizacion),
                        icon: const Icon(Icons.map, color: _azulVibrante),
                        label: const Text('VER RECORRIDO', style: TextStyle(color: _azulVibrante, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                  ],
                ),
                _buildInfoRow('📧 Pescador', cotizacion['pescador_email']),
                _buildInfoRow('📞 Telefono', cotizacion['pescador_telefono']),
                _buildInfoRow('📅 Viaje', '${cotizacion['viaje_fecha_salida']} - ${cotizacion['viaje_fecha_llegada']}'),
                _buildInfoRow('⏰ Vigencia', CotizacionesService.calcularVigencia(cotizacion['fecha_vigencia'])),
                
                const SizedBox(height: 12),
                
                // Descripcion
                if (cotizacion['descripcion'] != null) ...[
                  const Text(
                    '📝 Descripcion:',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cotizacion['descripcion'],
                    style: TextStyle(
                      color: _blancoPuro.withOpacity(0.8),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Detalles de items
                if (cotizacion['detalles'] != null) ...[
                  const Text(
                    '💰 Detalles del Presupuesto:',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDetallesItems(cotizacion['detalles']),
                  const SizedBox(height: 12),
                ],
                
                // Archivos adjuntos
                if (cotizacion['archivos_adjuntos'] != null && 
                    (cotizacion['archivos_adjuntos'] as List).isNotEmpty) ...[
                  const Text(
                    '📎 Archivos Adjuntos:',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildArchivosAdjuntos(cotizacion['archivos_adjuntos']),
                  const SizedBox(height: 12),
                ],
                
                // Botones de accion
                Row(
                  children: [
                    if (status == 'pendiente') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstado(cotizacion['id'], 'enviado'),
                          icon: const Icon(Icons.send, size: 16),
                          label: const Text('Enviar al Pescador'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _azulVibrante,
                            foregroundColor: _blancoPuro,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstado(cotizacion['id'], 'rechazado'),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Rechazar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _rojoFuerte,
                            foregroundColor: _blancoPuro,
                          ),
                        ),
                      ),
                    ],
                    
                    if (status == 'enviado') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstado(cotizacion['id'], 'aceptado'),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Aceptar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _verdeBrillante,
                            foregroundColor: _blancoPuro,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstado(cotizacion['id'], 'rechazado'),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Rechazar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _rojoFuerte,
                            foregroundColor: _blancoPuro,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _blancoPuro,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesItems(Map<String, dynamic> detalles) {
    final items = detalles['items'] as List<dynamic>? ?? [];
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _blancoPuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      item['descripcion'],
                      style: const TextStyle(
                        color: _blancoPuro,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'x${item['cantidad']}',
                      style: TextStyle(
                        color: _blancoPuro.withOpacity(0.8),
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '\$${item['precio_unitario'].toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: _blancoPuro,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildArchivosAdjuntos(List<dynamic> archivos) {
    return archivos.map<Widget>((archivo) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Icon(Icons.attach_file, color: _azulVibrante, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                archivo.toString(),
                style: const TextStyle(
                  color: _azulVibrante,
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Descargando: ${archivo.toString()}'),
                    backgroundColor: _azulVibrante,
                  ),
                );
              },
              icon: const Icon(Icons.download, color: _azulVibrante, size: 16),
              tooltip: 'Descargar archivo',
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatearFecha(String fechaIso) {
    final fecha = DateTime.parse(fechaIso);
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _mostrarEstadisticas() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: _azulVibrante)),
    );

    try {
      final estadisticas = await CotizacionesService.obtenerEstadisticasCapitan('capitan-001');
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            '📊 Estadisticas del Capitan',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildEstadisticaRow('Total Cotizaciones', estadisticas['total_cotizaciones'].toString()),
                _buildEstadisticaRow('Pendientes', estadisticas['pendientes'].toString()),
                _buildEstadisticaRow('Enviados', estadisticas['enviados'].toString()),
                _buildEstadisticaRow('Aceptados', estadisticas['aceptados'].toString()),
                _buildEstadisticaRow('Rechazados', estadisticas['rechazados'].toString()),
                _buildEstadisticaRow('Vencidos', estadisticas['vencidos'].toString()),
                const SizedBox(height: 12),
                _buildEstadisticaRow('Monto Total Aceptados', '\$${estadisticas['monto_total_aceptados'].toStringAsFixed(0)}'),
                _buildEstadisticaRow('Tasa Conversion', '${estadisticas['tasa_conversion'].toStringAsFixed(1)}%'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loader si está abierto
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar estadisticas: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  Widget _buildEstadisticaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarMapaRecorrido(Map<String, dynamic> cotizacion) {
    try {
      final partidaRaw = cotizacion['coordenadas_partida'];
      final destinoRaw = cotizacion['coordenadas_destino'];

      if (partidaRaw == null || destinoRaw == null) return;

      LatLng pPartida;
      LatLng pDestino;

      if (partidaRaw is Map) {
        pPartida = LatLng(
          (partidaRaw['latitude'] ?? partidaRaw['lat'] ?? 0).toDouble(),
          (partidaRaw['longitude'] ?? partidaRaw['lng'] ?? 0).toDouble(),
        );
      } else {
        pPartida = LatLng(partidaRaw.latitude, partidaRaw.longitude);
      }

      if (destinoRaw is Map) {
        pDestino = LatLng(
          (destinoRaw['latitude'] ?? destinoRaw['lat'] ?? 0).toDouble(),
          (destinoRaw['longitude'] ?? destinoRaw['lng'] ?? 0).toDouble(),
        );
      } else {
        pDestino = LatLng(destinoRaw.latitude, destinoRaw.longitude);
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF001F3F),
          title: const Text(
            'RECORRIDO DEL PESCADOR',
            style: TextStyle(
              color: _blancoPuro,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: pPartida,
                  initialZoom: 12,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.capitanya.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: [pPartida, pDestino],
                        color: _azulVibrante,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: pPartida,
                        child: const Icon(Icons.location_on, color: Colors.green, size: 30),
                      ),
                      Marker(
                        point: pDestino,
                        child: const Icon(Icons.flag, color: Colors.red, size: 30),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CERRAR', style: TextStyle(color: _blancoPuro)),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar el mapa: $e'),
          backgroundColor: _rojoFuerte,
        ),
      );
    }
  }

  void _mostrarFormularioCotizacion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CotizacionesFormularioScreen(),
      ),
    ).then((_) => _cargarCotizaciones());
  }
}
