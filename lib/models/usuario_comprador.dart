

class UsuarioComprador {
  final String id;
  final String email;
  final String nombre;
  final String? telefono;
  final DateTime createdAt;

  UsuarioComprador({
    required this.id,
    required this.email,
    required this.nombre,
    this.telefono,
    required this.createdAt,
  });

  // Constructor para crear desde Supabase
  factory UsuarioComprador.fromSupabase(Map<String, dynamic> data) {
    return UsuarioComprador(
      id: data['id']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? data['user_metadata']?['name']?.toString() ?? '',
      telefono: data['telefono']?.toString(),
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'telefono': telefono,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Obtener nombre para mostrar
  String get nombreMostrar {
    if (nombre.isNotEmpty) return nombre;
    return email.split('@').first;
  }

  // Obtener iniciales para avatar
  String get iniciales {
    final parts = nombreMostrar.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return nombreMostrar.isNotEmpty ? nombreMostrar[0].toUpperCase() : 'U';
  }
}
