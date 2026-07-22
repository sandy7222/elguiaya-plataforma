class OpcionVariante {
  final String id;
  final String nombre;
  final int orden;
  final bool activo;

  OpcionVariante({
    required this.id,
    required this.nombre,
    this.orden = 0,
    this.activo = true,
  });

  factory OpcionVariante.fromSupabase(Map<String, dynamic> data) {
    return OpcionVariante(
      id: data['id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      activo: data['activo'] ?? true,
    );
  }
}

class OpcionVarianteValor {
  final String id;
  final String opcionId;
  final String valor;
  final String? codigoHex;
  final int orden;
  final bool activo;

  OpcionVarianteValor({
    required this.id,
    required this.opcionId,
    required this.valor,
    this.codigoHex,
    this.orden = 0,
    this.activo = true,
  });

  factory OpcionVarianteValor.fromSupabase(Map<String, dynamic> data) {
    return OpcionVarianteValor(
      id: data['id']?.toString() ?? '',
      opcionId: data['opcion_id']?.toString() ?? '',
      valor: data['valor']?.toString() ?? '',
      codigoHex: data['codigo_hex']?.toString(),
      orden: (data['orden'] as num?)?.toInt() ?? 0,
      activo: data['activo'] ?? true,
    );
  }
}

class ProductoVariante {
  final String id;
  final String productoId;
  final String? sku;
  final String color;
  final String? opcionValorId;
  final int stock;
  final double? precio;
  final String? imagenUrl;
  final List<String> galeriaUrls;
  final bool esDefault;
  final bool activo;
  final int orden;

  ProductoVariante({
    required this.id,
    required this.productoId,
    this.sku,
    required this.color,
    this.opcionValorId,
    required this.stock,
    this.precio,
    this.imagenUrl,
    this.galeriaUrls = const [],
    this.esDefault = false,
    this.activo = true,
    this.orden = 0,
  });

  factory ProductoVariante.fromSupabase(Map<String, dynamic> data) {
    List<String> galeria = [];
    if (data['galeria_urls'] is List) {
      galeria = List<String>.from(data['galeria_urls']);
    }
    return ProductoVariante(
      id: data['id']?.toString() ?? '',
      productoId: data['producto_id']?.toString() ?? '',
      sku: data['sku']?.toString(),
      color: data['color']?.toString() ?? '',
      opcionValorId: data['opcion_valor_id']?.toString(),
      stock: (data['stock'] as num?)?.toInt() ?? 0,
      precio: (data['precio'] as num?)?.toDouble(),
      imagenUrl: data['imagen_url']?.toString(),
      galeriaUrls: galeria,
      esDefault: data['es_default'] ?? false,
      activo: data['activo'] ?? true,
      orden: (data['orden'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toInsertMap({required String productoId}) {
    return {
      'producto_id': productoId,
      'sku': (sku == null || sku!.isEmpty) ? null : sku,
      'color': color.trim(),
      'opcion_valor_id':
          (opcionValorId == null || opcionValorId!.isEmpty) ? null : opcionValorId,
      'stock': stock,
      'precio': precio,
      'imagen_url': (imagenUrl == null || imagenUrl!.isEmpty) ? null : imagenUrl,
      'galeria_urls': galeriaUrls,
      'es_default': esDefault,
      'activo': activo,
      'orden': orden,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'producto_id': productoId,
      'sku': sku,
      'color': color,
      'opcion_valor_id': opcionValorId,
      'stock': stock,
      'precio': precio,
      'imagen_url': imagenUrl,
      'galeria_urls': galeriaUrls,
      'es_default': esDefault,
      'activo': activo,
      'orden': orden,
    };
  }

  ProductoVariante copyWith({
    String? id,
    String? productoId,
    String? sku,
    String? color,
    String? opcionValorId,
    int? stock,
    double? precio,
    String? imagenUrl,
    List<String>? galeriaUrls,
    bool? esDefault,
    bool? activo,
    int? orden,
  }) {
    return ProductoVariante(
      id: id ?? this.id,
      productoId: productoId ?? this.productoId,
      sku: sku ?? this.sku,
      color: color ?? this.color,
      opcionValorId: opcionValorId ?? this.opcionValorId,
      stock: stock ?? this.stock,
      precio: precio ?? this.precio,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      galeriaUrls: galeriaUrls ?? this.galeriaUrls,
      esDefault: esDefault ?? this.esDefault,
      activo: activo ?? this.activo,
      orden: orden ?? this.orden,
    );
  }

  bool get tieneStock => stock > 0;

  double precioEfectivo(double precioProducto) => precio ?? precioProducto;
}
