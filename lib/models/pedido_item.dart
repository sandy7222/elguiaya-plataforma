

import '../models/producto.dart';

class PedidoItem {
  final String id;
  final String pedidoId;
  final String productoId;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final DateTime createdAt;

  PedidoItem({
    required this.id,
    required this.pedidoId,
    required this.productoId,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.createdAt,
  });

  // Constructor para crear desde Supabase
  factory PedidoItem.fromSupabase(Map<String, dynamic> data) {
    return PedidoItem(
      id: data['id']?.toString() ?? '',
      pedidoId: data['pedido_id']?.toString() ?? '',
      productoId: data['producto_id']?.toString() ?? '',
      cantidad: (data['cantidad'] as num?)?.toInt() ?? 0,
      precioUnitario: (data['precio_unitario'] as num?)?.toDouble() ?? 0.0,
      subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pedido_id': pedidoId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Map para insertar (sin id y created_at)
  Map<String, dynamic> toInsertMap() {
    return {
      'pedido_id': pedidoId,
      'producto_id': productoId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
      'subtotal': subtotal,
    };
  }

  // Constructor para crear desde producto y cantidad
  factory PedidoItem.fromProducto({
    required String id,
    required String pedidoId,
    required Producto producto,
    required int cantidad,
  }) {
    final subtotal = producto.precio * cantidad;
    
    return PedidoItem(
      id: id,
      pedidoId: pedidoId,
      productoId: producto.id,
      cantidad: cantidad,
      precioUnitario: producto.precio,
      subtotal: subtotal,
      createdAt: DateTime.now(),
    );
  }

  // Obtener subtotal formateado
  String get subtotalFormateado {
    return '\$${subtotal.toStringAsFixed(2)}';
  }

  // Obtener precio unitario formateado
  String get precioUnitarioFormateado {
    return '\$${precioUnitario.toStringAsFixed(2)}';
  }

  // Getter para obtener el producto (necesario para ticket_printer.dart)
  Producto? get producto {
    // Aqui deberias implementar la logica para obtener el producto
    // desde un servicio o base de datos usando productoId
    return null; // Placeholder - implementar segun necesites
  }

  // Verificar si los datos son validos
  bool get isValid {
    return pedidoId.isNotEmpty && 
           productoId.isNotEmpty && 
           cantidad > 0 && 
           precioUnitario >= 0;
  }
}
