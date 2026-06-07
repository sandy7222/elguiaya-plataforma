

class DireccionEnvio {
  final String id;
  final String usuarioId;
  final String nombre;
  final String apellido;
  final String telefono;
  final String email;
  final String direccion;
  final String ciudad;
  final String provincia;
  final String codigoPostal;
  final String pais;
  final String? referencias;
  final bool esPrincipal;
  final DateTime createdAt;
  final DateTime updatedAt;

  DireccionEnvio({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.email,
    required this.direccion,
    required this.ciudad,
    required this.provincia,
    required this.codigoPostal,
    required this.pais,
    this.referencias,
    this.esPrincipal = false,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear desde Supabase
  factory DireccionEnvio.fromSupabase(Map<String, dynamic> data) {
    return DireccionEnvio(
      id: data['id']?.toString() ?? '',
      usuarioId: data['usuario_id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      apellido: data['apellido']?.toString() ?? '',
      telefono: data['telefono']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      direccion: data['direccion']?.toString() ?? '',
      ciudad: data['ciudad']?.toString() ?? '',
      provincia: data['provincia']?.toString() ?? '',
      codigoPostal: data['codigo_postal']?.toString() ?? '',
      pais: data['pais']?.toString() ?? '',
      referencias: data['referencias']?.toString(),
      esPrincipal: data['es_principal'] ?? false,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'ciudad': ciudad,
      'provincia': provincia,
      'codigo_postal': codigoPostal,
      'pais': pais,
      'referencias': referencias,
      'es_principal': esPrincipal,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Map para insertar (sin id y timestamps)
  Map<String, dynamic> toInsertMap() {
    return {
      'usuario_id': usuarioId,
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'email': email,
      'direccion': direccion,
      'ciudad': ciudad,
      'provincia': provincia,
      'codigo_postal': codigoPostal,
      'pais': pais,
      'referencias': referencias,
      'es_principal': esPrincipal,
    };
  }

  // Validar datos de direccion
  bool get isValid {
    return nombre.isNotEmpty &&
           apellido.isNotEmpty &&
           telefono.isNotEmpty &&
           email.isNotEmpty &&
           direccion.isNotEmpty &&
           ciudad.isNotEmpty &&
           provincia.isNotEmpty &&
           codigoPostal.isNotEmpty &&
           pais.isNotEmpty;
  }

  // Obtener direccion completa formateada
  String get direccionCompleta {
    final partes = [direccion, ciudad, provincia, codigoPostal, pais];
    return partes.where((parte) => parte.isNotEmpty).join(', ');
  }

  // Obtener nombre completo
  String get nombreCompleto {
    return '$nombre $apellido';
  }

  // Constructor para direccion vacia
  DireccionEnvio.empty()
      : id = '',
        usuarioId = '',
        nombre = '',
        apellido = '',
        telefono = '',
        email = '',
        direccion = '',
        ciudad = '',
        provincia = '',
        codigoPostal = '',
        pais = '',
        referencias = '',
        esPrincipal = false,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  // Constructor para direccion temporal (checkout)
  DireccionEnvio.temporal({
    required this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.email,
    required this.direccion,
    required this.ciudad,
    required this.provincia,
    required this.codigoPostal,
    this.pais = 'Argentina',
    this.referencias,
  }) : id = 'temp_${DateTime.now().millisecondsSinceEpoch}',
     esPrincipal = false,
     createdAt = DateTime.now(),
     updatedAt = DateTime.now();
}
