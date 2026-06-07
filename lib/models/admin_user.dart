

class AdminUser {
  final String id;
  final String email;
  final String nombre;
  final String rol;
  final bool activo;
  final DateTime createdAt;
  final DateTime updatedAt;

  AdminUser({
    required this.id,
    required this.email,
    required this.nombre,
    required this.rol,
    required this.activo,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear desde Supabase
  factory AdminUser.fromSupabase(Map<String, dynamic> data) {
    return AdminUser(
      id: data['id']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      rol: data['rol']?.toString() ?? '',
      activo: data['activo'] ?? false,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'nombre': nombre,
      'rol': rol,
      'activo': activo,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Roles permitidos
  static const String ROL_ADMIN_MASTER = 'admin_master';
  static const String ROL_ADMIN_NAUTICO = 'admin_nautico';
  static const String ROL_ADMIN_ECOMMERCE = 'admin_ecommerce';
  static const String ROL_ADMIN_OPERACIONES = 'admin_operaciones';

  // Verificar permisos por modulo
  bool tieneAccesoNautico() {
    return rol == ROL_ADMIN_MASTER || rol == ROL_ADMIN_NAUTICO || rol == ROL_ADMIN_OPERACIONES;
  }

  bool tieneAccesoEcommerce() {
    return rol == ROL_ADMIN_MASTER || rol == ROL_ADMIN_ECOMMERCE || rol == ROL_ADMIN_OPERACIONES;
  }

  bool tieneAccesoArchivos() {
    return rol == ROL_ADMIN_MASTER || rol == ROL_ADMIN_OPERACIONES;
  }

  bool puedeAprobarDocumentos() {
    return rol == ROL_ADMIN_MASTER || rol == ROL_ADMIN_NAUTICO;
  }

  bool puedeVerKPIs() {
    return rol == ROL_ADMIN_MASTER || rol == ROL_ADMIN_OPERACIONES;
  }

  // Obtener nombre legible del rol
  String getRolNombre() {
    switch (rol) {
      case ROL_ADMIN_MASTER:
        return 'Admin Master';
      case ROL_ADMIN_NAUTICO:
        return 'Admin Nautico';
      case ROL_ADMIN_ECOMMERCE:
        return 'Admin E-Commerce';
      case ROL_ADMIN_OPERACIONES:
        return 'Admin Operaciones';
      default:
        return 'Sin Rol';
    }
  }
}
