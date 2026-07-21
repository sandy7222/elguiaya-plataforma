
import 'producto_variante.dart';

class Producto {
  final String id;
  final String nombre;
  final String descripcion;
  final double precio;
  final int stock;
  final String rubro;
  final String categoriaId;
  final String imagenUrl;
  final List<String> galeriaUrls; // Galeria de imagenes adicionales
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool destacado;
  final String? rubroId;
  final String? vendedorId; 

  final String? videoUrl; // Link de video opcional
  final List<ProductoVariante> variantes;

  Producto({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.precio,
    required this.stock,
    required this.rubro,
    required this.categoriaId,
    required this.imagenUrl,
    this.galeriaUrls = const [],
    this.videoUrl,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
    this.destacado = false,
    this.rubroId,
    this.vendedorId,
    this.variantes = const [],
  });

  factory Producto.fromSupabase(Map<String, dynamic> data) {
    // Parsear galeria_urls si existe (asumiendo que es un array JSON o lista)
    List<String> galeria = [];
    if (data['galeria_urls'] != null) {
      if (data['galeria_urls'] is List) {
        galeria = List<String>.from(data['galeria_urls']);
      }
    }

    List<ProductoVariante> vars = [];
    if (data['producto_variantes'] is List) {
      vars = (data['producto_variantes'] as List)
          .whereType<Map>()
          .map((v) => ProductoVariante.fromSupabase(Map<String, dynamic>.from(v)))
          .toList()
        ..sort((a, b) => a.orden.compareTo(b.orden));
    } else if (data['variantes'] is List) {
      vars = (data['variantes'] as List)
          .whereType<Map>()
          .map((v) => ProductoVariante.fromSupabase(Map<String, dynamic>.from(v)))
          .toList();
    }

    return Producto(
      id: data['id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      precio: (data['precio'] as num?)?.toDouble() ?? 0.0,
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      rubro: data['rubro']?.toString() ?? '',
      categoriaId: data['categoria_id']?.toString() ?? '',
      imagenUrl: data['imagen_url']?.toString() ?? '',
      galeriaUrls: galeria,
      videoUrl: data['video_url']?.toString(),
      activo: data['activo'] ?? true,
      vendedorId: data['vendedor_id']?.toString(),
      destacado: data['destacado'] ?? false,
      rubroId: data['rubro_id']?.toString(),
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
      variantes: vars,
    );
  }

  bool get tieneVariantes => variantes.where((v) => v.activo).isNotEmpty;

  List<ProductoVariante> get variantesActivas =>
      variantes.where((v) => v.activo).toList();

  ProductoVariante? get varianteDefault {
    final activas = variantesActivas;
    if (activas.isEmpty) return null;
    for (final v in activas) {
      if (v.esDefault) return v;
    }
    return activas.first;
  }

  int get stockDisponible {
    if (!tieneVariantes) return stock;
    return variantesActivas.fold(0, (sum, v) => sum + v.stock);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'stock': stock,
      'rubro': rubro,
      'categoria_id': categoriaId,
      'imagen_url': imagenUrl,
      'galeria_urls': galeriaUrls,
      'producto_variantes': variantes.map((v) => v.toMap()).toList(),
      'video_url': videoUrl,
      'activo': activo,
      'rubro_id': rubroId,
      'vendedor_id': vendedorId,
      'destacado': destacado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'precio': precio,
      'stock': stock,
      'rubro': rubro, 
      'categoria_id': categoriaId.isEmpty ? null : categoriaId,
      'imagen_url': imagenUrl,
      'galeria_urls': galeriaUrls,
      'video_url': videoUrl,
      'activo': activo,
      'rubro_id': (rubroId?.isEmpty ?? true) ? null : rubroId,
      'vendedor_id': (vendedorId?.isEmpty ?? true) ? null : vendedorId,
      'destacado': destacado,
    };
  }

  bool get isValid => nombre.isNotEmpty && precio > 0 && stock >= 0;

  String get precioFormateado => '\$${precio.toStringAsFixed(2)}';

  String get estadoStock {
    if (stock == 0) return 'Sin stock';
    if (stock < 5) return 'Stock bajo';
    return 'Disponible';
  }

  String get estadoStockColor {
    if (stock == 0) return 'red';
    if (stock < 5) return 'orange';
    return 'green';
  }

  Producto.empty()
      : id = '',
        nombre = '',
        descripcion = '',
        precio = 0.0,
        stock = 0,
        rubro = '',
        categoriaId = '',
        imagenUrl = '',
        galeriaUrls = const [],
        activo = true,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        destacado = false,
        rubroId = null,
        vendedorId = null,
        videoUrl = null,
        variantes = const [];

  Producto copyWith({
    String? id,
    String? nombre,
    String? descripcion,
    double? precio,
    int? stock,
    String? rubro,
    String? categoriaId,
    String? imagenUrl,
    List<String>? galeriaUrls,
    String? videoUrl,
    bool? activo,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? destacado,
    String? rubroId,
    String? vendedorId,
    List<ProductoVariante>? variantes,
  }) {
    return Producto(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      descripcion: descripcion ?? this.descripcion,
      precio: precio ?? this.precio,
      stock: stock ?? this.stock,
      rubro: rubro ?? this.rubro,
      categoriaId: categoriaId ?? this.categoriaId,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      galeriaUrls: galeriaUrls ?? this.galeriaUrls,
      videoUrl: videoUrl ?? this.videoUrl,
      activo: activo ?? this.activo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      destacado: destacado ?? this.destacado,
      rubroId: rubroId ?? this.rubroId,
      vendedorId: vendedorId ?? this.vendedorId,
      variantes: variantes ?? this.variantes,
    );
  }
}
