


import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/pedido.dart';
import '../models/pedido_item.dart';
import '../services/supabase_service.dart';
import '../widgets/estado_badge.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  List<Pedido> _pedidos = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarPedidos();
  }

  Future<void> _cargarPedidos() async {
    try {
      setState(() => _isLoading = true);
      
      // Simular usuario ID (en una app real vendria de autenticacion)
      final usuarioId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      
      final pedidos = await SupabaseService.getPedidosPorUsuarioConItems(usuarioId);
      
      setState(() {
        _pedidos = pedidos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar pedidos: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _abrirTicketEnvio(String ticketUrl) async {
    try {
      final uri = Uri.parse(ticketUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('No se puede abrir el ticket de envio')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al abrir ticket: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPedidoCard(Pedido pedido) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header del pedido
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
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(pedido.createdAt),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
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

            // Items del pedido
            if (pedido.items != null && pedido.items!.isNotEmpty) ...[
              const Text(
                'Productos:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(height: 8),
              ...pedido.items!.map((item) => _buildItemWidget(item)),
            ],

            const SizedBox(height: 16),

            // Acciones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Boton de ver detalles
                TextButton.icon(
                  onPressed: () {
                    _mostrarDetallesPedido(pedido);
                  },
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Ver detalles'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF0D47A1),
                  ),
                ),
                
                // Boton de ticket de envio
                if (pedido.tieneTicketEnvio)
                  ElevatedButton.icon(
                    onPressed: () => _abrirTicketEnvio(pedido.ticketEnvioUrl!),
                    icon: const Icon(Icons.description, size: 16),
                    label: const Text('Ticket'),
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
                ? Image.network(
                     item.producto!.imagenUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        width: 50,
                        height: 50,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[200],
                      child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                    ),
                  )
                : Container(
                    width: 50,
                    height: 50,
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
                Row(
                  children: [
                    Text(
                      'Cantidad: ${item.cantidad}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      item.precioUnitarioFormateado,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Subtotal
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
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
        ],
      ),
    );
  }

  void _mostrarDetallesPedido(Pedido pedido) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pedido #${pedido.id.substring(0, 8).toUpperCase()}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Informacion general
              _buildDetalleRow('Fecha', _formatDate(pedido.createdAt)),
              _buildDetalleRow('Estado', pedido.estadoNombre),
              _buildDetalleRow('Estado de envio', pedido.estadoEnvioNombre),
              _buildDetalleRow('Total', pedido.totalFormateado),
              _buildDetalleRow('Direccion', pedido.direccionEnvio),
              
              if (pedido.notas.isNotEmpty) ...[
                _buildDetalleRow('Notas', pedido.notas),
              ],
              
              const SizedBox(height: 16),
              
              // Items
              if (pedido.items != null && pedido.items!.isNotEmpty) ...[
                const Text(
                  'Productos:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...pedido.items!.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.cantidad}x ${item.producto?.nombre ?? 'Producto'}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        item.subtotalFormateado,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ],
          ),
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

  Widget _buildDetalleRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Mis Pedidos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pedidos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.history,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Todavia no tenes pedidos.',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '¡Es hora de equiparse para la proxima salida!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.shopping_bag_outlined),
                        label: const Text('Ir a la Tienda'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarPedidos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _pedidos.length,
                    itemBuilder: (context, index) {
                      return _buildPedidoCard(_pedidos[index]);
                    },
                  ),
                ),
    );
  }
}
