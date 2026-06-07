

import '../models/producto.dart';

class CartItem {
  final String id;
  final Producto producto;
  int cantidad;
  DateTime addedAt;

  CartItem({
    required this.id,
    required this.producto,
    required this.cantidad,
    required this.addedAt,
  });

  // Constructor para crear desde mapa
  factory CartItem.fromMap(Map<String, dynamic> data) {
    return CartItem(
      id: data['id'] ?? '',
      producto: data['producto'] ?? Producto.empty(),
      cantidad: data['cantidad'] ?? 1,
      addedAt: DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto': producto,
      'cantidad': cantidad,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  // Calcular subtotal
  double get subtotal {
    return producto.precio * cantidad;
  }

  // Verificar si hay stock suficiente
  bool get hasStock {
    return cantidad <= producto.stock;
  }

  // Obtener nombre del producto
  String get nombreProducto {
    return producto.nombre;
  }

  // Obtener precio formateado
  String get precioFormateado {
    return producto.precioFormateado;
  }

  // Obtener subtotal formateado
  String get subtotalFormateado {
    return '\$${subtotal.toStringAsFixed(2)}';
  }
}
