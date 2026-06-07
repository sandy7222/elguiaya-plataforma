

class PerfilCapitan {
  final String id;
  final String userId;
  final String? nombre;
  final bool esCapitan;
  final int limiteRespuestaMinutos;
  final String? telefonoContacto;
  final String? dni;
  final String? telefono;
  final double? radioOperacionKm;
  final Map<String, dynamic>? centroOperacionLatLong;
  final bool disponible;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? avatarUrl;
  final String? seguroUrl;
  final String? embarcacionUrl;

  PerfilCapitan({
    required this.id,
    required this.userId,
    this.nombre,
    required this.esCapitan,
    required this.limiteRespuestaMinutos,
    this.telefonoContacto,
    this.dni,
    this.telefono,
    this.radioOperacionKm,
    this.centroOperacionLatLong,
    this.disponible = true,
    required this.createdAt,
    required this.updatedAt,
    this.avatarUrl,
    this.seguroUrl,
    this.embarcacionUrl,
  });

  // Constructor para crear desde Supabase
  factory PerfilCapitan.fromSupabase(Map<String, dynamic> data) {
    return PerfilCapitan(
      id: data['id']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      nombre: data['nombre']?.toString() ?? data['profiles']?['nombre']?.toString(),
      esCapitan: data['es_capitan'] as bool? ?? false,
      limiteRespuestaMinutos: data['limite_respuesta_minutos'] as int? ?? 15,
      telefonoContacto: data['telefono_contacto']?.toString(),
      dni: data['dni']?.toString(),
      telefono: data['telefono']?.toString(),
      radioOperacionKm: (data['zona_radio_km'] as num?)?.toDouble() ?? (data['radio_operacion_km'] as num?)?.toDouble(),
      centroOperacionLatLong: data['centro_operacion_lat_long'] as Map<String, dynamic>? ?? (
        (data['zona_lat'] != null && data['zona_lng'] != null) 
          ? {'lat': data['zona_lat'], 'lon': data['zona_lng'], 'nombre': 'Puerto Base'}
          : null
      ),
      disponible: data['disponible'] as bool? ?? true,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
      avatarUrl: data['avatar_url']?.toString(),
      seguroUrl: data['seguro_url']?.toString(),
      embarcacionUrl: data['embarcacion_url']?.toString(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'nombre': nombre,
      'es_capitan': esCapitan,
      'limite_respuesta_minutos': limiteRespuestaMinutos,
      'telefono_contacto': telefonoContacto,
      'dni': dni,
      'telefono': telefono,
      'zona_radio_km': radioOperacionKm,
      'zona_lat': latitudCentro,
      'zona_lng': longitudCentro,
      'disponible': disponible,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'avatar_url': avatarUrl,
      'seguro_url': seguroUrl,
      'embarcacion_url': embarcacionUrl,
    };
  }

  // Map para insertar (sin id y timestamps)
  Map<String, dynamic> toInsertMap() {
    return {
      'user_id': userId,
      'es_capitan': esCapitan,
      'limite_respuesta_minutos': limiteRespuestaMinutos,
      'telefono_contacto': telefonoContacto,
      'dni': dni,
      'telefono': telefono,
      'zona_radio_km': radioOperacionKm,
      'zona_lat': latitudCentro,
      'zona_lng': longitudCentro,
      'disponible': disponible,
      'avatar_url': avatarUrl,
      'seguro_url': seguroUrl,
      'embarcacion_url': embarcacionUrl,
    };
  }

  // Validar datos del perfil
  bool get isValid {
    return userId.isNotEmpty && esCapitan;
  }

  // Formatear limite de respuesta
  String get limiteRespuestaFormateado {
    if (limiteRespuestaMinutos < 60) {
      return '$limiteRespuestaMinutos minutos';
    } else {
      final horas = limiteRespuestaMinutos ~/ 60;
      final minutos = limiteRespuestaMinutos % 60;
      return '${horas}h ${minutos}min';
    }
  }

  // Obtener telefono principal
  String get telefonoPrincipal {
    return telefonoContacto ?? telefono ?? 'No configurado';
  }

  // Metodos de geofencing
  bool get tieneGeofencingConfigurado => centroOperacionLatLong != null && radioOperacionKm != null;
  
  String get nombreCentroOperacion => centroOperacionLatLong?['nombre'] ?? 'Centro no definido';
  
  double? get latitudCentro => centroOperacionLatLong?['lat'] as double?;
  
  double? get longitudCentro => centroOperacionLatLong?['lon'] as double?;
  
  String get radioOperacionFormateado {
    if (radioOperacionKm == null) return 'No configurado';
    final km = radioOperacionKm!;
    if (km < 1) {
      return '${(km * 1000).toStringAsFixed(0)} m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }
  
  String get estadoOperativo {
    if (!tieneGeofencingConfigurado) return 'Sin configurar';
    if (!disponible) return 'No disponible';
    return 'Disponible';
  }
  
  String get colorEstado {
    if (!tieneGeofencingConfigurado) return 'grey';
    if (!disponible) return 'red';
    return 'green';
  }
  
  String get estadoDisponibilidad {
    return disponible ? 'Disponible' : 'No disponible';
  }
  
  String get colorDisponibilidad {
    return disponible ? 'green' : 'red';
  }

  // Constructor para perfil vacio
  PerfilCapitan.empty()
      : id = '',
        userId = '',
        nombre = null,
        esCapitan = false,
        limiteRespuestaMinutos = 15,
        telefonoContacto = null,
        dni = null,
        telefono = null,
        radioOperacionKm = null,
        centroOperacionLatLong = null,
        disponible = true,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        avatarUrl = null,
        seguroUrl = null,
        embarcacionUrl = null;

  // Constructor para perfil temporal
  PerfilCapitan.temporal({
    required this.userId,
    this.nombre,
    this.esCapitan = true,
    this.limiteRespuestaMinutos = 15,
    this.telefonoContacto,
    this.dni,
    this.telefono,
    this.radioOperacionKm = 25.0,
    this.centroOperacionLatLong,
    this.disponible = true,
  }) : id = 'temp_${DateTime.now().millisecondsSinceEpoch}',
     createdAt = DateTime.now(),
     updatedAt = DateTime.now(),
     avatarUrl = null,
     seguroUrl = null,
     embarcacionUrl = null;

  // Copiar perfil con cambios
  PerfilCapitan copyWith({
    String? id,
    String? userId,
    bool? esCapitan,
    int? limiteRespuestaMinutos,
    String? telefonoContacto,
    String? dni,
    String? telefono,
    double? radioOperacionKm,
    Map<String, dynamic>? centroOperacionLatLong,
    bool? disponible,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? avatarUrl,
    String? seguroUrl,
    String? embarcacionUrl,
  }) {
    return PerfilCapitan(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      esCapitan: esCapitan ?? this.esCapitan,
      limiteRespuestaMinutos: limiteRespuestaMinutos ?? this.limiteRespuestaMinutos,
      telefonoContacto: telefonoContacto ?? this.telefonoContacto,
      dni: dni ?? this.dni,
      telefono: telefono ?? this.telefono,
      radioOperacionKm: radioOperacionKm ?? this.radioOperacionKm,
      centroOperacionLatLong: centroOperacionLatLong ?? this.centroOperacionLatLong,
      disponible: disponible ?? this.disponible,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      seguroUrl: seguroUrl ?? this.seguroUrl,
      embarcacionUrl: embarcacionUrl ?? this.embarcacionUrl,
    );
  }

  // Convertir a JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'esCapitan': esCapitan,
      'limiteRespuestaMinutos': limiteRespuestaMinutos,
      'limiteRespuestaFormateado': limiteRespuestaFormateado,
      'telefonoContacto': telefonoContacto,
      'telefonoPrincipal': telefonoPrincipal,
      'dni': dni,
      'telefono': telefono,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'avatarUrl': avatarUrl,
      'seguroUrl': seguroUrl,
      'embarcacionUrl': embarcacionUrl,
    };
  }
}
