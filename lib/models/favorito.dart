

class Favorito {
  final String id;
  final String usuarioId;
  final String productoId;
  final DateTime createdAt;

  Favorito({
    required this.id,
    required this.usuarioId,
    required this.productoId,
    required this.createdAt,
  });

  // Constructor para crear desde Supabase
  factory Favorito.fromSupabase(Map<String, dynamic> data) {
    return Favorito(
      id: data['id']?.toString() ?? '',
      usuarioId: data['usuario_id']?.toString() ?? '',
      productoId: data['producto_id']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'producto_id': productoId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Map para insertar (sin id y created_at)
  Map<String, dynamic> toInsertMap() {
    return {
      'usuario_id': usuarioId,
      'producto_id': productoId,
    };
  }
}
