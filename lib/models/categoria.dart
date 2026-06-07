

class Categoria {
  final String id;
  final String nombre;
  final String descripcion;
  final bool activa;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? rubroId;
  final String? parentId;
  final String? iconoUrl;

  Categoria({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activa,
    required this.createdAt,
    required this.updatedAt,
    this.rubroId,
    this.parentId,
    this.iconoUrl,
  });

  // Constructor para crear desde Supabase
  factory Categoria.fromSupabase(Map<String, dynamic> data) {
    return Categoria(
      id: data['id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      activa: data['activa'] ?? true,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
      rubroId: data['rubro_id']?.toString(),
      parentId: data['parent_id']?.toString(),
      iconoUrl: data['icono_url']?.toString(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'activa': activa,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (rubroId != null) 'rubro_id': rubroId,
      if (parentId != null) 'parent_id': parentId,
      if (iconoUrl != null) 'icono_url': iconoUrl,
    };
  }

  // Validar datos de la categoria
  bool get isValid {
    return nombre.isNotEmpty;
  }

  Categoria.empty()
      : id = '',
        nombre = 'Sin Categoria',
        descripcion = '',
        activa = false,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        rubroId = null,
        parentId = null,
        iconoUrl = null;
}
