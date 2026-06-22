

class UserProfile {
  final String id;
  final String userId;
  final String? dni;
  final String? telefono;
  final String? direccionCalle;
  final String? direccionNumero;
  final String? localidad;
  final String? fotoDniUrl;
  final String? nombre;
  final String? avatarUrl;
  final bool esCapitan;
  final double radioTrabajo;
  final double? puertoBaseLat;
  final double? puertoBaseLon;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    this.dni,
    this.telefono,
    this.direccionCalle,
    this.direccionNumero,
    this.localidad,
    this.fotoDniUrl,
    this.nombre,
    this.avatarUrl,
    this.esCapitan = false,
    this.radioTrabajo = 50.0,
    this.puertoBaseLat,
    this.puertoBaseLon,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear desde Supabase
  factory UserProfile.fromSupabase(Map<String, dynamic> data) {
    return UserProfile(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      dni: data['dni']?.toString(),
      telefono: data['telefono']?.toString(),
      direccionCalle: data['direccion_calle']?.toString(),
      direccionNumero: data['direccion_numero']?.toString(),
      localidad: data['localidad']?.toString(),
      fotoDniUrl: data['foto_dni_url']?.toString(),
      nombre: data['nombre']?.toString() ?? data['full_name']?.toString(),
      avatarUrl: data['avatar_url']?.toString(),
      esCapitan: data['es_capitan'] as bool? ?? false,
      radioTrabajo: (data['zona_radio_km'] as num?)?.toDouble() ?? (data['radio_trabajo'] as num?)?.toDouble() ?? 50.0,
      puertoBaseLat: (data['zona_lat'] as num?)?.toDouble() ?? (data['puerto_base_lat'] as num?)?.toDouble(),
      puertoBaseLon: (data['zona_lng'] as num?)?.toDouble() ?? (data['puerto_base_lon'] as num?)?.toDouble(),
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'dni': dni,
      'telefono': telefono,
      'direccion_calle': direccionCalle,
      'direccion_numero': direccionNumero,
      'localidad': localidad,
      'foto_dni_url': fotoDniUrl,
      'nombre': nombre,
      'avatar_url': avatarUrl,
      'es_capitan': esCapitan,
      'radio_trabajo': radioTrabajo,
      'puerto_base_lat': puertoBaseLat,
      'puerto_base_lon': puertoBaseLon,
      'zona_radio_km': radioTrabajo,
      'zona_lat': puertoBaseLat,
      'zona_lng': puertoBaseLon,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Map para insertar (sin id y timestamps)
  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'dni': dni,
      'telefono': telefono,
      'direccion_calle': direccionCalle,
      'direccion_numero': direccionNumero,
      'localidad': localidad,
      'foto_dni_url': fotoDniUrl,
      'nombre': nombre,
      'avatar_url': avatarUrl,
      'es_capitan': esCapitan,
      'radio_trabajo': radioTrabajo,
      'puerto_base_lat': puertoBaseLat,
      'puerto_base_lon': puertoBaseLon,
      'zona_radio_km': radioTrabajo,
      'zona_lat': puertoBaseLat,
      'zona_lng': puertoBaseLon,
    };
  }

  // Validar datos del perfil (sin restricciones estrictas)
  bool get isValid {
    return userId.isNotEmpty;
  }

  // Verificar si tiene datos completos
  bool get hasCompleteData {
    return dni != null && dni!.isNotEmpty &&
           telefono != null && telefono!.isNotEmpty &&
           direccionCalle != null && direccionCalle!.isNotEmpty &&
           direccionNumero != null && direccionNumero!.isNotEmpty &&
           localidad != null && localidad!.isNotEmpty;
  }

  // Verificar si tiene foto DNI
  bool get hasFotoDni {
    return fotoDniUrl != null && fotoDniUrl!.isNotEmpty;
  }

  // Obtener direccion completa formateada
  String get direccionCompleta {
    if (direccionCalle == null || direccionNumero == null) {
      return 'Sin direccion';
    }
    
    final partes = [direccionCalle, direccionNumero];
    if (localidad != null && localidad!.isNotEmpty) {
      partes.add(localidad!);
    }
    
    return partes.join(' ');
  }

  // Obtener nombre completo (placeholder para futuro)
  String get nombreCompleto {
    return 'Usuario ${userId.substring(0, 8)}';
  }

  // Constructor para perfil vacio
  UserProfile.empty()
      : id = '',
        userId = '',
        dni = '',
        telefono = '',
        direccionCalle = '',
        direccionNumero = '',
        localidad = '',
        fotoDniUrl = '',
        nombre = null,
        avatarUrl = null,
        esCapitan = false,
        radioTrabajo = 50.0,
        puertoBaseLat = null,
        puertoBaseLon = null,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  // Constructor para perfil temporal (antes de guardar)
  UserProfile.temporal({
    required this.userId,
    this.dni,
    this.telefono,
    this.direccionCalle,
    this.direccionNumero,
    this.localidad,
    this.fotoDniUrl,
    this.nombre,
    this.avatarUrl,
    this.esCapitan = false,
    this.radioTrabajo = 50.0,
    this.puertoBaseLat,
    this.puertoBaseLon,
  }) : id = 'temp_${DateTime.now().millisecondsSinceEpoch}',
        createdAt = DateTime.now(),
        updatedAt = DateTime.now();

  // Copiar perfil con cambios
  UserProfile copyWith({
    String? id,
    String? userId,
    String? dni,
    String? telefono,
    String? direccionCalle,
    String? direccionNumero,
    String? localidad,
    String? fotoDniUrl,
    String? nombre,
    String? avatarUrl,
    bool? esCapitan,
    double? radioTrabajo,
    double? puertoBaseLat,
    double? puertoBaseLon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      dni: dni ?? this.dni,
      telefono: telefono ?? this.telefono,
      direccionCalle: direccionCalle ?? this.direccionCalle,
      direccionNumero: direccionNumero ?? this.direccionNumero,
      localidad: localidad ?? this.localidad,
      fotoDniUrl: fotoDniUrl ?? this.fotoDniUrl,
      nombre: nombre ?? this.nombre,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      esCapitan: esCapitan ?? this.esCapitan,
      radioTrabajo: radioTrabajo ?? this.radioTrabajo,
      puertoBaseLat: puertoBaseLat ?? this.puertoBaseLat,
      puertoBaseLon: puertoBaseLon ?? this.puertoBaseLon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
