

class ManifiestoViaje {
  final String id;
  final String usuarioId;
  final String nombre;
  final String apellido;
  final String telefono;
  final String email;
  final String? documento;
  final String? numeroDocumento;
  final DateTime fechaNacimiento;
  final String? nacionalidad;
  final String? emergenciaContacto;
  final String? emergenciaTelefono;
  final String? condicionesMedicas;
  final String? alergias;
  final String? preferenciasComida;
   final String? fotoDniUrl;
  final String? numeroTramite; // Nuevo campo para permisos oficiales
  final DateTime createdAt;
  final DateTime updatedAt;

  ManifiestoViaje({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.email,
    this.documento,
    this.numeroDocumento,
    this.numeroTramite,
    required this.fechaNacimiento,
    this.nacionalidad,
    this.emergenciaContacto,
    this.emergenciaTelefono,
    this.condicionesMedicas,
    this.alergias,
    this.preferenciasComida,
    this.fotoDniUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear desde Supabase
  factory ManifiestoViaje.fromSupabase(Map<String, dynamic> data) {
    return ManifiestoViaje(
      id: data['id']?.toString() ?? '',
      usuarioId: data['usuario_id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? '',
      apellido: data['apellido']?.toString() ?? '',
      telefono: data['telefono']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      documento: data['documento']?.toString(),
      numeroDocumento: data['numero_documento']?.toString(),
      numeroTramite: data['numero_tramite']?.toString(),
      fechaNacimiento: DateTime.tryParse(data['fecha_nacimiento'] ?? '') ?? DateTime.now(),
      nacionalidad: data['nacionalidad']?.toString(),
      emergenciaContacto: data['emergencia_contacto']?.toString(),
      emergenciaTelefono: data['emergencia_telefono']?.toString(),
      condicionesMedicas: data['condiciones_medicas']?.toString(),
      alergias: data['alergias']?.toString(),
      preferenciasComida: data['preferencias_comida']?.toString(),
      fotoDniUrl: data['foto_dni_url']?.toString(),
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
      'documento': documento,
      'numero_documento': numeroDocumento,
      'numero_tramite': numeroTramite,
      'fecha_nacimiento': fechaNacimiento.toIso8601String(),
      'nacionalidad': nacionalidad,
      'emergencia_contacto': emergenciaContacto,
      'emergencia_telefono': emergenciaTelefono,
      'condiciones_medicas': condicionesMedicas,
      'alergias': alergias,
      'preferencias_comida': preferenciasComida,
      'foto_dni_url': fotoDniUrl,
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
      'documento': documento,
      'numero_documento': numeroDocumento,
      'numero_tramite': numeroTramite,
      'fecha_nacimiento': fechaNacimiento.toIso8601String(),
      'nacionalidad': nacionalidad,
      'emergencia_contacto': emergenciaContacto,
      'emergencia_telefono': emergenciaTelefono,
      'condiciones_medicas': condicionesMedicas,
      'alergias': alergias,
      'preferencias_comida': preferenciasComida,
      'foto_dni_url': fotoDniUrl,
    };
  }

  // Validar datos del manifiesto
  bool get isValid {
    return nombre.isNotEmpty &&
           apellido.isNotEmpty &&
           telefono.isNotEmpty &&
           email.isNotEmpty &&
           fechaNacimiento.isBefore(DateTime.now());
  }

  // Validar datos del manifiesto con foto DNI
  bool get isValidConFoto {
    return isValid && fotoDniUrl != null && fotoDniUrl!.isNotEmpty;
  }

  // Verificar si tiene foto DNI
  bool get tieneFotoDni {
    return fotoDniUrl != null && fotoDniUrl!.isNotEmpty;
  }

  // Obtener nombre completo
  String get nombreCompleto {
    return '$nombre $apellido';
  }

  // Obtener edad
  int get edad {
    final hoy = DateTime.now();
    int edad = hoy.year - fechaNacimiento.year;
    if (hoy.month < fechaNacimiento.month || 
        (hoy.month == fechaNacimiento.month && hoy.day < fechaNacimiento.day)) {
      edad--;
    }
    return edad;
  }

  // Obtener documento completo
  String get documentoCompleto {
    if (documento == null || numeroDocumento == null) return 'No especificado';
    return '$documento $numeroDocumento';
  }

  // Constructor para manifiesto vacio
  ManifiestoViaje.empty()
      : id = '',
        usuarioId = '',
        nombre = '',
        apellido = '',
        telefono = '',
        email = '',
        documento = '',
        numeroDocumento = '',
        fechaNacimiento = DateTime.now(),
        nacionalidad = '',
        emergenciaContacto = '',
        emergenciaTelefono = '',
        condicionesMedicas = '',
        alergias = '',
        preferenciasComida = '',
        fotoDniUrl = '',
        numeroTramite = '',
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  // Constructor para manifiesto temporal (checkout)
  ManifiestoViaje.temporal({
    required this.usuarioId,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.email,
    required this.fechaNacimiento,
    this.documento,
    this.numeroDocumento,
    this.nacionalidad = 'Argentina',
    this.emergenciaContacto,
    this.emergenciaTelefono,
    this.condicionesMedicas,
    this.alergias,
    this.preferenciasComida,
    this.fotoDniUrl,
    this.numeroTramite,
  }) : id = 'temp_${DateTime.now().millisecondsSinceEpoch}',
     createdAt = DateTime.now(),
     updatedAt = DateTime.now();

  // Tipos de documentos
  static const String DOC_DNI = 'DNI';
  static const String DOC_PASAPORTE = 'Pasaporte';
  static const String DOC_CEDULA = 'Cedula';
  static const String DOC_OTRO = 'Otro';

  // Lista de tipos de documentos
  static List<String> get tiposDocumentos => [
    DOC_DNI,
    DOC_PASAPORTE,
    DOC_CEDULA,
    DOC_OTRO,
  ];
}
