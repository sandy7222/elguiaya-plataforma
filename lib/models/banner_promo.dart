

class BannerPromo {
  final String id;
  final String titulo;
  final String subtitulo;
  final String imagenUrl;
  final bool activo;
  final int orden;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? productId;   // Enlace opcional a un producto
  final String? categoriaId; // Enlace opcional a una categoria
  final double tituloSize;
  final double subtituloSize;
  final String textColor; // Color del texto (HEX)
  final String tipo;       // 'hero', 'product_collection', 'marquee'
  final String? tituloSeccion; // Para carruseles de productos
  final double velocidad;  // Para marquesinas
  final String? backgroundColor; // Color de fondo (HEX) para marquesinas

  BannerPromo({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.imagenUrl,
    required this.activo,
    this.orden = 0,
    required this.createdAt,
    required this.updatedAt,
    this.tituloSize = 20.0,
    this.subtituloSize = 14.0,
    this.textColor = '#FFFFFF',
    this.tipo = 'hero',
    this.tituloSeccion,
    this.productId,
    this.categoriaId,
    this.velocidad = 5.0,
    this.backgroundColor = '#0D47A1',
  });

  // Constructor para crear desde Supabase
  factory BannerPromo.fromSupabase(Map<String, dynamic> data) {
    return BannerPromo(
      id: data['id']?.toString() ?? '',
      titulo: data['titulo']?.toString() ?? '',
      subtitulo: data['subtitulo']?.toString() ?? '',
      imagenUrl: data['imagen_url']?.toString() ?? '',
      activo: data['activo'] ?? true,
      orden: data['orden'] ?? 0,
      createdAt: DateTime.parse(data['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(data['updated_at'] ?? DateTime.now().toIso8601String()),
      tituloSize: (data['titulo_size'] as num?)?.toDouble() ?? 20.0,
      subtituloSize: (data['subtitulo_size'] as num?)?.toDouble() ?? 14.0,
      textColor: data['text_color']?.toString() ?? '#FFFFFF',
      tipo: data['tipo']?.toString() ?? 'hero',
      tituloSeccion: data['titulo_seccion']?.toString(),
      productId: data['product_id']?.toString(),
      categoriaId: data['categoria_id']?.toString(),
      velocidad: (data['velocidad'] as num?)?.toDouble() ?? 5.0,
      backgroundColor: data['background_color']?.toString() ?? '#0D47A1',
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'subtitulo': subtitulo,
      'imagen_url': imagenUrl,
      'activo': activo,
      'orden': orden,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'titulo_size': tituloSize,
      'subtitulo_size': subtituloSize,
      'text_color': textColor,
      'tipo': tipo,
      'titulo_seccion': tituloSeccion,
      'product_id': productId,
      'categoria_id': categoriaId,
      'velocidad': velocidad,
      'background_color': backgroundColor,
    };
  }

  // Map para insertar ultra-simplificado para evitar errores de esquema
  Map<String, dynamic> toInsertMap() {
    return {
      'titulo': titulo,
      'subtitulo': subtitulo,
      'imagen_url': imagenUrl,
      'tipo': tipo,
      'activo': activo,
      'orden': orden,
      'titulo_size': tituloSize,
      'subtitulo_size': subtituloSize,
      'text_color': textColor,
      'titulo_seccion': tituloSeccion,
      'product_id': productId,
      'categoria_id': categoriaId,
      'velocidad': velocidad,
      'background_color': backgroundColor,
    };
  }

  // Validar datos del banner
  bool get isValid {
    return titulo.isNotEmpty && 
           subtitulo.isNotEmpty && 
           imagenUrl.isNotEmpty;
  }

  // Obtener estado formateado
  String get estadoFormateado {
    return activo ? 'Activo' : 'Inactivo';
  }

  // Obtener color del estado
  String get estadoColor {
    return activo ? 'green' : 'red';
  }

  // Constructor para banner vacio
  BannerPromo.empty()
      : id = '',
        titulo = '',
        subtitulo = '',
        imagenUrl = '',
        activo = false,
        orden = 0,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        tituloSize = 20.0,
        subtituloSize = 14.0,
        textColor = '#FFFFFF',
        tipo = 'hero',
        tituloSeccion = null,
        productId = null,
        categoriaId = null,
        velocidad = 5.0,
        backgroundColor = '#0D47A1';

  // Constructor para banner temporal (antes de guardar)
  BannerPromo.temporal({
    required this.titulo,
    required this.subtitulo,
    required this.imagenUrl,
    this.activo = true,
    this.orden = 0,
    this.tituloSize = 20.0,
    this.subtituloSize = 14.0,
    this.textColor = '#FFFFFF',
    this.tipo = 'hero',
    this.tituloSeccion,
    this.productId,
    this.categoriaId,
    this.velocidad = 5.0,
    this.backgroundColor = '#0D47A1',
  }) : id = 'temp_${DateTime.now().millisecondsSinceEpoch}',
     createdAt = DateTime.now(),
     updatedAt = DateTime.now();

  // Copiar banner con cambios
  BannerPromo copyWith({
    String? id,
    String? titulo,
    String? subtitulo,
    String? imagenUrl,
    bool? activo,
    int? orden,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? tituloSize,
    double? subtituloSize,
    String? textColor,
    String? tipo,
    String? tituloSeccion,
    String? productId,
    String? categoriaId,
    double? velocidad,
    String? backgroundColor,
  }) {
    return BannerPromo(
      id: id ?? this.id,
      titulo: titulo ?? this.titulo,
      subtitulo: subtitulo ?? this.subtitulo,
      imagenUrl: imagenUrl ?? this.imagenUrl,
      activo: activo ?? this.activo,
      orden: orden ?? this.orden,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      tituloSize: tituloSize ?? this.tituloSize,
      subtituloSize: subtituloSize ?? this.subtituloSize,
      textColor: textColor ?? this.textColor,
      tipo: tipo ?? this.tipo,
      tituloSeccion: tituloSeccion ?? this.tituloSeccion,
      productId: productId ?? this.productId,
      categoriaId: categoriaId ?? this.categoriaId,
      velocidad: velocidad ?? this.velocidad,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }
}
