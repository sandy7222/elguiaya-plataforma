class ArticuloBlog {
  final String id;
  final String titulo;
  final String resumen;
  final String contenido;
  final String autor;
  final int minutosLectura;
  final String imagenPortada;
  final String categoria;
  final List<String> productosSugeridos;
  final String? fuenteUrl;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  ArticuloBlog({
    required this.id,
    required this.titulo,
    required this.resumen,
    required this.contenido,
    required this.autor,
    required this.minutosLectura,
    required this.imagenPortada,
    required this.categoria,
    this.productosSugeridos = const [],
    this.fuenteUrl,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ArticuloBlog.fromSupabase(Map<String, dynamic> data) {
    List<String> prodSugeridos = [];
    if (data['productos_sugeridos'] != null) {
      if (data['productos_sugeridos'] is List) {
        prodSugeridos = List<String>.from(
          (data['productos_sugeridos'] as List).map((x) => x.toString()),
        );
      }
    }

    return ArticuloBlog(
      id: data['id']?.toString() ?? '',
      titulo: data['titulo']?.toString() ?? '',
      resumen: data['resumen']?.toString() ?? '',
      contenido: data['contenido']?.toString() ?? '',
      autor: data['autor']?.toString() ?? '',
      minutosLectura: (data['minutos_lectura'] as num?)?.toInt() ?? 5,
      imagenPortada: data['imagen_portada']?.toString() ?? '',
      categoria: data['categoria']?.toString() ?? 'Guías',
      productosSugeridos: prodSugeridos,
      fuenteUrl: data['fuente_url']?.toString(),
      activo: data['activo'] ?? true,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'titulo': titulo,
      'resumen': resumen,
      'contenido': contenido,
      'autor': autor,
      'minutos_lectura': minutosLectura,
      'imagen_portada': imagenPortada,
      'categoria': categoria,
      'productos_sugeridos': productosSugeridos,
      'fuente_url': fuenteUrl,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toInsertMap() {
    return {
      'titulo': titulo,
      'resumen': resumen,
      'contenido': contenido,
      'autor': autor,
      'minutos_lectura': minutosLectura,
      'imagen_portada': imagenPortada,
      'categoria': categoria,
      'productos_sugeridos': productosSugeridos,
      'fuente_url': fuenteUrl,
      'activo': activo,
    };
  }

  ArticuloBlog.empty()
      : id = '',
        titulo = '',
        resumen = '',
        contenido = '',
        autor = '',
        minutosLectura = 5,
        imagenPortada = '',
        categoria = 'Guías',
        productosSugeridos = const [],
        fuenteUrl = null,
        activo = true,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();
}
