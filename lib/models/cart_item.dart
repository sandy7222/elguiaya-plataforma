import '../models/producto.dart';

class CartItem {
  final String id;
  final Producto producto;
  int cantidad;
  DateTime addedAt;
  final String? varianteId;
  final String? varianteColor;
  final String? varianteImagenUrl;
  final double? precioUnitarioOverride;

  CartItem({
    required this.id,
    required this.producto,
    required this.cantidad,
    required this.addedAt,
    this.varianteId,
    this.varianteColor,
    this.varianteImagenUrl,
    this.precioUnitarioOverride,
  });

  factory CartItem.fromMap(Map<String, dynamic> data) {
    return CartItem(
      id: data['id'] ?? '',
      producto: data['producto'] ?? Producto.empty(),
      cantidad: data['cantidad'] ?? 1,
      addedAt: DateTime.tryParse(data['addedAt'] ?? '') ?? DateTime.now(),
      varianteId: data['varianteId']?.toString(),
      varianteColor: data['varianteColor']?.toString(),
      varianteImagenUrl: data['varianteImagenUrl']?.toString(),
      precioUnitarioOverride: (data['precioUnitarioOverride'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto': producto,
      'cantidad': cantidad,
      'addedAt': addedAt.toIso8601String(),
      'varianteId': varianteId,
      'varianteColor': varianteColor,
      'varianteImagenUrl': varianteImagenUrl,
      'precioUnitarioOverride': precioUnitarioOverride,
    };
  }

  double get precioUnitario =>
      precioUnitarioOverride ?? producto.precio;

  double get subtotal => precioUnitario * cantidad;

  int get stockDisponible {
    if (varianteId != null) {
      for (final v in producto.variantes) {
        if (v.id == varianteId) return v.stock;
      }
      return 0;
    }
    return producto.stockDisponible;
  }

  bool get hasStock => cantidad <= stockDisponible;

  String get nombreProducto {
    if (varianteColor != null && varianteColor!.isNotEmpty) {
      return '${producto.nombre} ($varianteColor)';
    }
    return producto.nombre;
  }

  String get imagenMostrada {
    if (varianteImagenUrl != null && varianteImagenUrl!.isNotEmpty) {
      return varianteImagenUrl!;
    }
    return producto.imagenUrl;
  }

  String get precioFormateado => '\$${precioUnitario.toStringAsFixed(2)}';

  String get subtotalFormateado => '\$${subtotal.toStringAsFixed(2)}';

  String get lineKey =>
      '${producto.id}::${varianteId ?? 'base'}';
}
