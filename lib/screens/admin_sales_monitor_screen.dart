



import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/safe_button.dart';

import '../models/pedido.dart';
import '../models/pedido_item.dart';
import '../models/usuario_comprador.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../widgets/estado_badge.dart';
import '../widgets/ticket_printer.dart';

class AdminSalesMonitorScreen extends StatefulWidget {
  const AdminSalesMonitorScreen({super.key});

  @override
  State<AdminSalesMonitorScreen> createState() => _AdminSalesMonitorScreenState();
}

class _AdminSalesMonitorScreenState extends State<AdminSalesMonitorScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _pedidos = [];
  Map<String, dynamic> _estadisticas = {};
  bool _isLoading = true;
  String _filtroEstado = 'todos';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      final resultados = await Future.wait([
        SupabaseService.getPedidosMaestro(),
        SupabaseService.getEstadisticasVentas(),
      ]);
      
      setState(() {
        _pedidos = resultados[0] as List<Map<String, dynamic>>;
        _estadisticas = resultados[1] as Map<String, dynamic>;
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

  List<Map<String, dynamic>> get _pedidosFiltrados {
    if (_filtroEstado == 'todos') {
      return _pedidos;
    }
    
    return _pedidos.where((pedido) => 
      pedido['estado_envio'] == _filtroEstado
    ).toList();
  }

  Future<void> _actualizarEstadoEnvio(String pedidoId, String nuevoEstado) async {
    try {
      await SupabaseService.actualizarEstadoEnvio(pedidoId, nuevoEstado);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Estado actualizado correctamente')),
          backgroundColor: Colors.green,
        ),
      );
      
      _cargarDatos(); // Recargar datos para sincronizar
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Error al actualizar estado: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _subirComprobanteEnvio(String pedidoId, XFile imagen) async {
    try {
      // Subir imagen al bucket administracion_archivos
      final imageUrl = await StorageService.uploadAdminDocument(
        file: imagen,
        folder: 'admin_ventas',
        prefix: 'comprobante_envio',
      );
      
      // Actualizar estado y URL del ticket
      await SupabaseService.actualizarEstadoEnvioConTicket(
        pedidoId, 
        Pedido.ESTADO_ENVIO_DESPACHADO,
        imageUrl,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Comprobante subido y pedido despachado')),
          backgroundColor: Colors.green,
        ),
      );
      
      _cargarDatos(); // Recargar datos para sincronizar
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Error al subir comprobante: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarOpcionesDespacho(Map<String, dynamic> pedidoData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Opciones de Despacho'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pedidoData['estado_envio'] != Pedido.ESTADO_ENVIO_DESPACHADO) ...[
              const Text('Cambiar estado a:'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: SafeElevatedIconButton(
  onPressed: () {
                    Navigator.pop(context);
                    _actualizarEstadoEnvio(pedidoData['id'], Pedido.ESTADO_ENVIO_DESPACHADO);
                  },
  icon: Icons.local_shipping,
  label: 'Despachado',
  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SafeElevatedIconButton(
  onPressed: () {
                    Navigator.pop(context);
                    _actualizarEstadoEnvio(pedidoData['id'], Pedido.ESTADO_ENVIO_ENTREGADO);
                  },
  icon: Icons.check_circle,
  label: 'Entregado',
  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _mostrarSubidaComprobante(Map<String, dynamic> pedidoData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subir Comprobante de Envio'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seleccione una imagen del comprobante de envio:'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: SafeElevatedIconButton(
  onPressed: () async {
                  final XFile? imagen = await StorageService.pickImageFromGallery();
                  if (imagen != null) {
                    Navigator.pop(context);
                    await _subirComprobanteEnvio(pedidoData['id'], imagen);
                  }
                },
  icon: Icons.photo_library,
  label: 'Seleccionar de Galeria',
  style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: SafeElevatedIconButton(
  onPressed: () async {
                  final XFile? imagen = await StorageService.captureImageFromCamera();
                  if (imagen != null) {
                    Navigator.pop(context);
                    await _subirComprobanteEnvio(pedidoData['id'], imagen);
                  }
                },
  icon: Icons.camera_alt,
  label: 'Tomar Foto',
  style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticasCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estadisticas de Ventas',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildEstadisticaItem(
                    'Total Ventas',
                    '\$${(_estadisticas['total_ventas'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildEstadisticaItem(
                    'Total Pedidos',
                    '${_estadisticas['total_pedidos'] ?? 0}',
                    Icons.shopping_cart,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildEstadisticaItem(
                    'Pendientes',
                    '${_estadisticas['pedidos_pendientes'] ?? 0}',
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildEstadisticaItem(
                    'Despachados',
                    '${_estadisticas['pedidos_despachados'] ?? 0}',
                    Icons.local_shipping,
                    Colors.indigo,
                  ),
                ),
                Expanded(
                  child: _buildEstadisticaItem(
                    'Entregados',
                    '${_estadisticas['pedidos_entregados'] ?? 0}',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticaItem(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            valor,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPedidoCard(Map<String, dynamic> pedidoData) {
    final pedido = Pedido.fromSupabase(pedidoData);
    final usuario = UsuarioComprador.fromSupabase(pedidoData['usuarios']);
    final items = (pedidoData['pedido_items'] as List?)
        ?.map((item) => PedidoItem.fromSupabase(item))
        .toList() ?? <PedidoItem>[];

    final esPendiente = pedido.estadoEnvio == Pedido.ESTADO_ENVIO_PREPARANDO;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: esPendiente ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: esPendiente 
          ? BorderSide(color: Colors.orange[300]!, width: 2)
          : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header prioritario para pedidos pendientes
            if (esPendiente)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.priority_high, color: Colors.orange[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'PEDIDO PENDIENTE - ATENCION INMEDIATA',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            
            if (esPendiente) const SizedBox(height: 12),
            
            // Informacion principal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${pedido.id.substring(0, 8).toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    Text(
                      'Cliente: ${usuario.nombreMostrar}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      'Email: ${usuario.email}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      pedido.totalFormateado,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    EstadoEnvioBadge(estadoEnvio: pedido.estadoEnvio),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Items del pedido
            if (items.isNotEmpty) ...[
              const Text(
                'Productos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 8),
              ...items.take(3).map((item) => _buildItemWidget(item)),
              if (items.length > 3)
                Text(
                  '... y ${items.length - 3} productos mas',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              const SizedBox(height: 12),
            ],

            // Direccion de envio
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pedido.direccionEnvio,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Boton de imprimir ticket
                SafeElevatedIconButton(
  onPressed: () {
                    TicketPrinter.imprimirTicket(
                      context: context,
                      pedido: pedido,
                      usuario: usuario,
                      items: items,
                    );
                  },
  icon: Icons.print,
  iconSize: 16,
  label: 'Imprimir Ticket',
  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
),
                
                // Botones de despacho
                if (pedido.estadoEnvio != Pedido.ESTADO_ENVIO_DESPACHADO)
                  Row(
                    children: [
                      SafeOutlinedIconButton(
  onPressed: () => _mostrarOpcionesDespacho(pedidoData),
  icon: Icons.local_shipping,
  iconSize: 16,
  label: 'Despachar',
  style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                        ),
),
                      const SizedBox(width: 8),
                      SafeElevatedIconButton(
  onPressed: () => _mostrarSubidaComprobante(pedidoData),
  icon: Icons.upload,
  iconSize: 16,
  label: 'Subir Comprobante',
  style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
),
                    ],
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green[700], size: 16),
                        const SizedBox(width: 4),
                        Text(
                          'Despachado',
                          style: TextStyle(
                            color: Colors.green[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemWidget(PedidoItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Imagen del producto
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: item.producto?.imagenUrl != null && item.producto!.imagenUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: item.producto!.imagenUrl,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 40,
                      height: 40,
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                    ),
                    memCacheWidth: 80,
                    memCacheHeight: 80,
                  )
                : Container(
                    width: 40,
                    height: 40,
                    color: Colors.grey[200],
                    child: Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                  ),
          ),
          
          const SizedBox(width: 12),
          
          // Informacion del item
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.producto?.nombre ?? 'Producto no disponible',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.cantidad}x ${item.precioUnitarioFormateado}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          
          // Subtotal
          Text(
            item.subtotalFormateado,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1),
            ),
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
        title: const Text(
          'Monitor de Ventas',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          // Estadisticas
          _buildEstadisticasCard(),
          
          // Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _filtroEstado == 'todos',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filtroEstado = 'todos');
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: const Color(0xFF0D47A1),
                    labelStyle: TextStyle(
                      color: _filtroEstado == 'todos' ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Preparando'),
                    selected: _filtroEstado == Pedido.ESTADO_ENVIO_PREPARANDO,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filtroEstado = Pedido.ESTADO_ENVIO_PREPARANDO);
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.orange,
                    labelStyle: TextStyle(
                      color: _filtroEstado == Pedido.ESTADO_ENVIO_PREPARANDO ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Despachado'),
                    selected: _filtroEstado == Pedido.ESTADO_ENVIO_DESPACHADO,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filtroEstado = Pedido.ESTADO_ENVIO_DESPACHADO);
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.blue,
                    labelStyle: TextStyle(
                      color: _filtroEstado == Pedido.ESTADO_ENVIO_DESPACHADO ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Entregado'),
                    selected: _filtroEstado == Pedido.ESTADO_ENVIO_ENTREGADO,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() => _filtroEstado = Pedido.ESTADO_ENVIO_ENTREGADO);
                      }
                    },
                    backgroundColor: Colors.white,
                    selectedColor: Colors.green,
                    labelStyle: TextStyle(
                      color: _filtroEstado == Pedido.ESTADO_ENVIO_ENTREGADO ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Lista de pedidos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _pedidosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No hay pedidos${_filtroEstado != 'todos' ? ' en este estado' : ''}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarDatos,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _pedidosFiltrados.length,
                          itemBuilder: (context, index) {
                            return _buildPedidoCard(_pedidosFiltrados[index]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
