

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
  });

  factory Producto.fromSupabase(Map<String, dynamic> data) {
    // Parsear galeria_urls si existe (asumiendo que es un array JSON o lista)
    List<String> galeria = [];
    if (data['galeria_urls'] != null) {
      if (data['galeria_urls'] is List) {
        galeria = List<String>.from(data['galeria_urls']);
      }
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
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
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
        videoUrl = null;
}
