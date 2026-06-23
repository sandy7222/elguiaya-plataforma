import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/supabase_service.dart';
import '../services/pago_service.dart';
import '../services/storage_service.dart';
import '../services/notificacion_service.dart';

class AdminPedidosScreen extends StatelessWidget {
  const AdminPedidosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestion de Pedidos'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Gestion de Pedidos',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 20),
            
            // Tabla con datos reales de Supabase
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: SupabaseService.getPedidosMaestro(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Color(0xFF4CAF50)),
                              SizedBox(height: 16),
                              Text('Cargando pedidos...', style: TextStyle(color: Colors.grey)),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                'Error al cargar pedidos',
                                style: const TextStyle(fontSize: 16, color: Colors.red),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                snapshot.error.toString(),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final pedidos = snapshot.data ?? [];

                    if (pedidos.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No hay pedidos registrados',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return Column(
                      children: [
                        // Encabezado de tabla
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: Color(0xFF4CAF50),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Expanded(child: Text('Pedido #', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Cliente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Expanded(child: Text('Estado', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                              Expanded(child: Text('Total', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        
                        // Filas con datos reales
                        Expanded(
                          child: ListView.builder(
                            itemCount: pedidos.length,
                            itemBuilder: (context, index) {
                              final pedido = pedidos[index];
                              return _buildTableRow(context, pedido);
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getEstadoColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'procesando':
        return Colors.purple;
      case 'enviado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildTableRow(BuildContext context, Map<String, dynamic> pedido) {
    final pedidoIdRaw = pedido['id']?.toString() ?? '';
    final pedidoIdDisplay = '#${pedidoIdRaw.length > 6 ? pedidoIdRaw.substring(0, 6) : pedidoIdRaw}';
    final cliente = pedido['usuarios']?['nombre'] ?? pedido['usuario_id']?.toString() ?? 'Desconocido';
    final estado = pedido['estado']?.toString() ?? 'pendiente';
    final total = (pedido['total'] as num?)?.toDouble() ?? 0.0;

    final Color estadoColor = _getEstadoColor(estado);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _mostrarDetallesPedido(context, pedido),
              child: Text(pedidoIdDisplay, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            ),
          ),
          Expanded(flex: 2, child: Text(cliente, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(
            child: PopupMenuButton<String>(
              onSelected: (String nuevoEstado) async {
                if (nuevoEstado == 'enviado') {
                  _mostrarDialogoEnvio(context, pedidoIdRaw, pedidoIdDisplay, pedido['usuario_id']?.toString() ?? '');
                } else {
                  try {
                    await SupabaseService.actualizarEstadoPedido(pedidoIdRaw, nuevoEstado);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Pedido $pedidoIdDisplay actualizado a $nuevoEstado'), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(value: 'pendiente', child: Text('⏳ Pendiente')),
                const PopupMenuItem<String>(value: 'procesando', child: Text('⚙️ Procesando')),
                const PopupMenuItem<String>(value: 'enviado', child: Text('🚚 Enviado')),
                const PopupMenuItem<String>(value: 'entregado', child: Text('✅ Entregado')),
                const PopupMenuItem<String>(value: 'cancelado', child: Text('❌ Cancelar')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: estadoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: estadoColor.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      estado,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: estadoColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: estadoColor),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: Text('\$${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  void _mostrarDetallesPedido(BuildContext context, Map<String, dynamic> pedido) {
    final String pedidoIdRaw = pedido['id']?.toString() ?? '';
    final String displayId = '#${pedidoIdRaw.length > 6 ? pedidoIdRaw.substring(0, 6) : pedidoIdRaw}';
    final String estado = pedido['estado']?.toString() ?? 'pendiente';
    final List<dynamic> items = pedido['pedido_items'] as List<dynamic>? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalles del Pedido $displayId'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (items.isNotEmpty)
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final cant = item['cantidad'] ?? 1;
                      final nombre = item['producto']?['nombre'] ?? 'Producto Desconocido';
                      final cat = item['producto']?['categoria']?['nombre'] ?? 'Sin categoria';
                      return ListTile(
                        title: Text('$cant x $nombre'),
                        subtitle: Text('Categoria: $cat'),
                        leading: const Icon(Icons.inventory_2, color: Color(0xFF1565C0)),
                      );
                    },
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Sin detalles de items.'),
                ),
              if (estado.toLowerCase() == 'cancelado') ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Cerrar dialog actual
                    _verificarYProcesarReembolso(context, pedidoIdRaw);
                  },
                  icon: const Icon(Icons.settings_backup_restore_rounded),
                  label: const Text('Procesar Reembolso MP 💸'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))
        ],
      ),
    );
  }

  void _verificarYProcesarReembolso(BuildContext context, String pedidoId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))),
    );

    try {
      final pagosResponse = await SupabaseService.supabase
          .from('pagos')
          .select()
          .eq('reserva_id', pedidoId)
          .eq('estado', 'confirmado');

      if (!context.mounted) return;
      Navigator.pop(context); // Cerrar spinner

      final List<dynamic> pagosList = pagosResponse as List<dynamic>? ?? [];

      if (pagosList.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sin Pagos Pendientes'),
            content: const Text('No se encontraron pagos confirmados para este pedido o ya han sido reembolsados.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Aceptar')),
            ],
          ),
        );
        return;
      }

      final pago = pagosList.first;
      final double monto = (pago['monto'] as num?)?.toDouble() ?? 0.0;
      final String metodo = pago['metodo_pago'] ?? '';

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirmar Reembolso'),
          content: Text(
            'Se detectó un pago de \$${monto.toStringAsFixed(2)} vía ${metodo == 'mercado_pago' ? 'Mercado Pago' : metodo}.\n\n'
            '¿Desea iniciar el reembolso real de dinero al cliente?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Cerrar este dialogo
                
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))),
                );

                try {
                  final result = await PagoService.solicitarReembolso(
                    pagoId: pago['id'].toString(),
                    motivo: 'Cancelación desde panel de pedidos',
                  );

                  if (!context.mounted) return;
                  Navigator.pop(context); // Cerrar spinner

                  if (result['success'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Reembolso completado con éxito'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: ${result['error']}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (err) {
                  if (!context.mounted) return;
                  Navigator.pop(context); // Cerrar spinner
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Excepción: $err'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              child: const Text('Reembolsar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cerrar spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al buscar pago: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _mostrarDialogoEnvio(BuildContext context, String pedidoId, String displayId, String usuarioId) {
    final TextEditingController notasController = TextEditingController();
    XFile? ticketFile;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B), // Fondo oscuro slate premium
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: const Color(0xFF38BDF8).withOpacity(0.5), width: 1.5),
              ),
              title: Row(
                children: const [
                  Icon(Icons.local_shipping_rounded, color: Color(0xFF38BDF8), size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Despachar Pedido',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Código de pedido: $displayId',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Datos de Envío / Seguimiento *',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: notasController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'ej. Correo Argentino - Cód: AR123456789AR',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 13),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Comprobante de Envío (Opcional)',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ticketFile == null
                        ? Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploading ? null : () async {
                                    final picked = await StorageService.pickImageFromGallery();
                                    if (picked != null) {
                                      setState(() {
                                        ticketFile = picked;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                                  label: const Text('Galería', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF334155),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: isUploading ? null : () async {
                                    final captured = await StorageService.captureImageFromCamera();
                                    if (captured != null) {
                                      setState(() {
                                        ticketFile = captured;
                                      });
                                    }
                                  },
                                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                                  label: const Text('Cámara', style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF334155),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.image, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ticketFile!.name,
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.redAccent, size: 18),
                                  onPressed: isUploading ? null : () {
                                    setState(() {
                                      ticketFile = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                    if (isUploading) ...[
                      const SizedBox(height: 20),
                      const Center(
                        child: CircularProgressIndicator(color: Color(0xFF38BDF8)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isUploading ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isUploading ? null : () async {
                    if (notasController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚠️ Por favor, ingrese los datos de seguimiento.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      isUploading = true;
                    });

                    try {
                      String? ticketUrl;
                      if (ticketFile != null) {
                        ticketUrl = await StorageService.uploadXFile(
                          xFile: ticketFile!,
                          bucket: 'branding',
                          folderPath: 'tickets_envio',
                          fileNamePrefix: 'ticket_$pedidoId',
                        );
                      }

                      await SupabaseService.actualizarDespachoPedido(
                        pedidoId: pedidoId,
                        nuevoEstado: 'enviado',
                        notas: notasController.text.trim(),
                        ticketEnvioUrl: ticketUrl,
                      );

                      // Enviar notificación al pescador/cliente
                      if (usuarioId.isNotEmpty) {
                        await NotificacionService().enviarNotificacion({
                          'receptor_id': usuarioId,
                          'titulo': '🚚 ¡Tu pedido ha sido enviado!',
                          'contenido': 'Tu pedido $displayId fue despachado. Seguimiento: ${notasController.text.trim()}',
                          'categoria': 'logistica',
                          'leido': false,
                          'payload': {
                            'pedido_id': pedidoId,
                          },
                        });
                      }

                      if (context.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Pedido $displayId despachado con éxito.'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      setState(() {
                        isUploading = false;
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ Error al despachar: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Confirmar Envío', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
