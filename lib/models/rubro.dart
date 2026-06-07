

class Rubro {
  final String id;
  final String nombre;
  final String descripcion;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Rubro({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear desde Supabase
  factory Rubro.fromSupabase(Map<String, dynamic> data) {
    return Rubro(
      id: data['id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      activo: data['activo'] ?? true,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Map para insertar (sin id y timestamps)
  Map<String, dynamic> toInsertMap() {
    return {
      'nombre': nombre,
      'descripcion': descripcion,
      'activo': activo,
    };
  }

  // Validar datos del rubro
  bool get isValid {
    return nombre.isNotEmpty;
  }

  // Rubros predefinidos
  static const String PESCA = 'pesca';
  static const String CAMPING = 'camping';

  // Obtener nombre legible
  String get nombreLegible {
    switch (nombre.toLowerCase()) {
      case PESCA:
        return 'Pesca';
      case CAMPING:
        return 'Camping';
      default:
        return nombre;
    }
  }

  // Obtener icono segun rubro
  String get icono {
    switch (nombre.toLowerCase()) {
      case PESCA:
        return '🎣';
      case CAMPING:
        return '⛺';
      default:
        return '📦';
    }
  }

  // Constructor vacio
  Rubro.empty()
      : id = '',
        nombre = 'Sin Rubro',
        descripcion = '',
        activo = false,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();
}
