

import 'package:flutter/material.dart';

import '../services/billetera_service.dart';

class BilleteraCapitanScreen extends StatefulWidget {
  const BilleteraCapitanScreen({super.key});

  @override
  State<BilleteraCapitanScreen> createState() => _BilleteraCapitanScreenState();
}

class _BilleteraCapitanScreenState extends State<BilleteraCapitanScreen> {
  List<Map<String, dynamic>> _pagos = [];
  bool _isLoading = true;
  String _filtroEstado = 'todos'; // todos, pendiente, procesando, completado, fallido
  String _busqueda = '';
  int _paginaActual = 1;
  final int _limitePorPagina = 10;

  // Colores El Guia YA
  static const Color _fondoOscuro = Color(0xFF1A1A1A);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _rojoFuerte = Color(0xFFFF0000);

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    setState(() => _isLoading = true);
    
    try {
      final pagos = BilleteraService.obtenerPagosDiferidos(
        capitanId: 'capitan-001',
        estado: _filtroEstado == 'todos' ? null : _filtroEstado,
      );
      
      setState(() {
        _pagos = pagos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar pagos: $e'),
          backgroundColor: _rojoFuerte,
        ),
      );
    }
  }

  Future<void> _actualizarEstadoPago(String pagoId, String nuevoEstado) async {
    final resultado = await BilleteraService.actualizarEstadoPago(
      pagoId: pagoId,
      nuevoEstado: nuevoEstado,
      comprobante: nuevoEstado == 'completado' ? 'COMP-${DateTime.now().millisecondsSinceEpoch}' : null,
      metodoPago: nuevoEstado == 'completado' ? 'transferencia' : null,
    );

    if (resultado['success']) {
      _cargarPagos(); // Recargar lista
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pago actualizado correctamente'),
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

  List<Map<String, dynamic>> get _pagosFiltrados {
    var filtrados = _pagos;
    
    // Filtrar por estado
    if (_filtroEstado != 'todos') {
      filtrados = filtrados.where((pago) => pago['status'] == _filtroEstado).toList();
    }
    
    // Filtrar por busqueda
    if (_busqueda.isNotEmpty) {
      filtrados = filtrados.where((pago) {
        final terminoLower = _busqueda.toLowerCase();
        return pago['concepto'].toString().toLowerCase().contains(terminoLower) ||
               pago['cotizacion_id'].toString().toLowerCase().contains(terminoLower) ||
               pago['pescador_id'].toString().toLowerCase().contains(terminoLower);
      }).toList();
    }
    
    return filtrados;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: _blancoPuro, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Billetera del Capitan',
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
            onPressed: _cargarPagos,
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
          // Resumen de pagos
          _buildResumenCard(),
          
          // Filtros y busqueda
          _buildFiltrosCard(),
          
          // Lista de pagos
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _azulVibrante),
                  )
                : _pagosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.account_balance_wallet_outlined,
                              color: _blancoPuro,
                              size: 64,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No hay pagos registrados',
                              style: TextStyle(
                                color: _blancoPuro,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Los pagos de cotizaciones aceptadas apareceran aqui',
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
                        itemCount: _pagosFiltrados.length,
                        itemBuilder: (context, index) {
                          final pago = _pagosFiltrados[index];
                          return _buildPagoCard(pago);
                        },
                      ),
          ),
          
          // Paginacion
          if (!_isLoading && _pagosFiltrados.isNotEmpty)
            _buildPaginacion(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _mostrarFormularioPago,
        backgroundColor: _azulVibrante,
        tooltip: 'Nuevo Pago',
        child: const Icon(Icons.add, color: _blancoPuro),
      ),
    );
  }

  Widget _buildResumenCard() {
    final estadisticas = BilleteraService.obtenerEstadisticasPagos(capitanId: 'capitan-001');
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_azulVibrante.withOpacity(0.1), _azulVibrante.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _azulVibrante.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: _azulVibrante),
              const SizedBox(width: 8),
              const Text(
                '📊 Resumen de Pagos',
                style: TextStyle(
                  color: _blancoPuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildEstadisticaItem('Total', estadisticas['total_pagos'], _azulVibrante),
              _buildEstadisticaItem('Pendientes', estadisticas['pendientes'], _naranjaIntenso),
              _buildEstadisticaItem('Completados', estadisticas['completados'], _verdeBrillante),
              _buildEstadisticaItem('Fallidos', estadisticas['fallidos'], _rojoFuerte),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMontoItem('Pendientes', estadisticas['monto_total_pendientes'], _naranjaIntenso),
              _buildMontoItem('Completados', estadisticas['monto_total_completados'], _verdeBrillante),
            ],
          ),
          if (estadisticas['proximo_vencimiento'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _naranjaIntenso.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _naranjaIntenso.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: _naranjaIntenso),
                  const SizedBox(width: 8),
                  Text(
                    'Proximo vencimiento: ${estadisticas['proximo_vencimiento']}',
                    style: const TextStyle(
                      color: _naranjaIntenso,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (estadisticas['dias_proximo_vencimiento'] != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${estadisticas['dias_proximo_vencimiento']} dias)',
                      style: TextStyle(
                        color: _naranjaIntenso.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEstadisticaItem(String label, dynamic valor, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _blancoPuro.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          valor.toString(),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMontoItem(String label, dynamic valor, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: _blancoPuro.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '\$${(valor as double).toStringAsFixed(2)}',
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFiltrosCard() {
    return Container(
      margin: const EdgeInsets.all(16),
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
              hintText: 'Buscar pagos...',
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
                _buildFiltroBoton('procesando', 'Procesando'),
                _buildFiltroBoton('completado', 'Completados'),
                _buildFiltroBoton('fallido', 'Fallidos'),
              ],
            ),
          ),
        ],
      ),
    );
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

  Widget _buildPagoCard(Map<String, dynamic> pago) {
    final status = pago['status'] as String;
    final monto = pago['monto'] as double;
    final fechaVencimiento = pago['fecha_vencimiento'] as String;
    final fechaPago = pago['fecha_pago'] as String?;
    final cuotas = pago['cuotas'] as int? ?? 1;
    final cuotaActual = pago['cuota_actual'] as int? ?? 1;
    
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (status) {
      case 'pendiente':
        statusColor = _naranjaIntenso;
        statusIcon = Icons.pending;
        statusText = '⏳ Pendiente';
        break;
      case 'procesando':
        statusColor = _azulVibrante;
        statusIcon = Icons.sync;
        statusText = '🔄 Procesando';
        break;
      case 'completado':
        statusColor = _verdeBrillante;
        statusIcon = Icons.check_circle;
        statusText = '✅ Completado';
        break;
      case 'fallido':
        statusColor = _rojoFuerte;
        statusIcon = Icons.error;
        statusText = '❌ Fallido';
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
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Icon(statusIcon, color: _blancoPuro, size: 20),
        ),
        title: Text(
          pago['concepto'],
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
              'Cotizacion: ${pago['cotizacion_id']}',
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Pescador: ${pago['pescador_id']}',
              style: TextStyle(
                color: _azulVibrante,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '\$${monto.toStringAsFixed(2)}',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            if (cuotas > 1) ...[
              Text(
                '$cuotaActual/$cuotas',
                style: TextStyle(
                  color: _blancoPuro.withOpacity(0.8),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
            ],
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
                _buildInfoRow('📅 Fecha Vencimiento', _formatearFecha(fechaVencimiento)),
                _buildInfoRow('💰 Metodo de Pago', pago['metodo_pago'] ?? 'No especificado'),
                if (fechaPago != null) ...[
                  _buildInfoRow('✅ Fecha Pago', _formatearFecha(fechaPago)),
                  _buildInfoRow('🧾 Comprobante', pago['comprobante'] ?? 'No cargado'),
                ],
                
                const SizedBox(height: 12),
                
                // Progreso de pagos
                if (cuotas > 1) ...[
                  Text(
                    '📊 Progreso de Pagos',
                    style: const TextStyle(
                      color: _blancoPuro,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: cuotaActual / cuotas,
                    backgroundColor: _blancoPuro.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(_verdeBrillante),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cuota $cuotaActual de $cuotas',
                    style: TextStyle(
                      color: _blancoPuro.withOpacity(0.8),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                
                // Botones de accion
                Row(
                  children: [
                    if (status == 'pendiente') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstadoPago(pago['id'], 'procesando'),
                          icon: const Icon(Icons.sync, size: 16),
                          label: const Text('Procesar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _azulVibrante,
                            foregroundColor: _blancoPuro,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstadoPago(pago['id'], 'fallido'),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Cancelar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _rojoFuerte,
                            foregroundColor: _blancoPuro,
                          ),
                        ),
                      ),
                    ],
                    
                    if (status == 'procesando') ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _actualizarEstadoPago(pago['id'], 'completado'),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Completar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _verdeBrillante,
                            foregroundColor: _blancoPuro,
                          ),
                        ),
                      ),
                    ],
                    
                    if (status == 'completado' && pago['comprobante'] == null) ...[
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _cargarComprobante(pago['id']),
                          icon: const Icon(Icons.upload, size: 16),
                          label: const Text('Cargar Comprobante'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _azulVibrante,
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
            width: 140,
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

  String _formatearFecha(String fechaIso) {
    final fecha = DateTime.parse(fechaIso);
    return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
  }

  Widget _buildPaginacion() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _paginaActual > 1
                ? () {
                    setState(() => _paginaActual--);
                    _cargarPagos();
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
            onPressed: _pagosFiltrados.length >= _limitePorPagina
                ? () {
                    setState(() => _paginaActual++);
                    _cargarPagos();
                  }
                : null,
            icon: const Icon(Icons.chevron_right, color: _blancoPuro),
          ),
        ],
      ),
    );
  }

  void _mostrarEstadisticas() {
    final estadisticas = BilleteraService.obtenerEstadisticasPagos(capitanId: 'capitan-001');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '📊 Estadisticas de Pagos',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEstadisticaDialogRow('Total Pagos', estadisticas['total_pagos'].toString()),
              _buildEstadisticaDialogRow('Pendientes', estadisticas['pendientes'].toString()),
              _buildEstadisticaDialogRow('Procesando', estadisticas['procesando'].toString()),
              _buildEstadisticaDialogRow('Completados', estadisticas['completados'].toString()),
              _buildEstadisticaDialogRow('Fallidos', estadisticas['fallidos'].toString()),
              const SizedBox(height: 12),
              _buildEstadisticaDialogRow('Monto Total Pendientes', '\$${estadisticas['monto_total_pendientes'].toStringAsFixed(2)}'),
              _buildEstadisticaDialogRow('Monto Total Completados', '\$${estadisticas['monto_total_completados'].toStringAsFixed(2)}'),
              if (estadisticas['proximo_vencimiento'] != null) ...[
                const SizedBox(height: 12),
                _buildEstadisticaDialogRow('Proximo Vencimiento', estadisticas['proximo_vencimiento']),
                _buildEstadisticaDialogRow('Dias para Vencer', '${estadisticas['dias_proximo_vencimiento']} dias'),
                _buildEstadisticaDialogRow('Monto Proximo Vencimiento', '\$${estadisticas['monto_proximo_vencimiento'].toStringAsFixed(2)}'),
              ],
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
  }

  Widget _buildEstadisticaDialogRow(String label, String value) {
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

  void _mostrarFormularioPago() {
    // Navegar al formulario de nuevo pago
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '💰 Nuevo Pago Diferido',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Aqui podrias implementar un formulario para crear nuevos pagos diferidos manualmente.',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 14,
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
  }

  void _cargarComprobante(String pagoId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '🧾 Cargar Comprobante',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Selecciona el archivo del comprobante de pago.',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Comprobante cargado correctamente'),
                  backgroundColor: _verdeBrillante,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _azulVibrante,
              foregroundColor: _blancoPuro,
            ),
            child: const Text('Cargar'),
          ),
        ],
      ),
    );
  }
}
