

class ViajesInvitados {
  final String id;
  final String pescadorId;
  final String nombre;
  final String dni;
  final DateTime createdAt;
  final DateTime updatedAt;

  ViajesInvitados({
    required this.id,
    required this.pescadorId,
    required this.nombre,
    required this.dni,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear desde Supabase
  factory ViajesInvitados.fromSupabase(Map<String, dynamic> data) {
    return ViajesInvitados(
      id: data['id']?.toString() ?? '',
      pescadorId: data['pescador_id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      dni: data['dni']?.toString() ?? '',
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pescador_id': pescadorId,
      'nombre': nombre,
      'dni': int.tryParse(dni) ?? 0, // Convertir DNI a numero
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
