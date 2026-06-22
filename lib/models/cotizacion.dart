

class Cotizacion {
  final String id;
  final String pescadorId;
  final String capitanId;
  final String descripcion;
  final double? presupuestoMonto;
  final String estado;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? presupuestoAt;
  final DateTime? respuestaAt;
  final int? tiempoRealRespuestaMinutos;
  final int? limiteRespuestaMinutos;
  final bool? riesgoNotificado;
  final String? pescadorTelefono;
  final Map<String, dynamic>? puntoPartida;
  final Map<String, dynamic>? puntoDestino;
  final double? distanciaKm;
  final double? distanciaMillas;
  final int? duracionEstimadaMinutos;
  final DateTime? fechaIda;
  final DateTime? fechaVuelta;
  final String? horaEncuentro;
  final int? cantidadPersonas;
  final List<Map<String, dynamic>>? trackLog;

  Cotizacion({
    required this.id,
    required this.pescadorId,
    required this.capitanId,
    required this.descripcion,
    this.presupuestoMonto,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
    this.presupuestoAt,
    this.respuestaAt,
    this.tiempoRealRespuestaMinutos,
    this.limiteRespuestaMinutos,
    this.riesgoNotificado,
    this.pescadorTelefono,
    this.puntoPartida,
    this.puntoDestino,
    this.distanciaKm,
    this.distanciaMillas,
    this.duracionEstimadaMinutos,
    this.fechaIda,
    this.fechaVuelta,
    this.horaEncuentro,
    this.cantidadPersonas,
    this.trackLog,
  });

  // Estados posibles
  static const String ESTADO_PENDIENTE = 'pendiente';
  static const String ESTADO_PRESUPUESTADO = 'presupuestado';
  static const String ESTADO_ACEPTADO = 'aceptado';
  static const String ESTADO_RECHAZADO = 'rechazado';
  static const String ESTADO_EN_RIESGO = 'en_riesgo';
  static const String ESTADO_EN_VIAJE = 'en_viaje';
  static const String ESTADO_FINALIZADO = 'finalizado';

  // Constructor para crear desde Supabase
  factory Cotizacion.fromSupabase(Map<String, dynamic> data) {
    final partidaData = data['coordenadas_partida'] ?? data['punto_partida'];
    final destinoData = data['coordenadas_destino'] ?? data['punto_destino'];
    return Cotizacion(
      id: data['id']?.toString() ?? '',
      pescadorId: data['pescador_id']?.toString() ?? '',
      capitanId: data['capitan_id']?.toString() ?? '',
      descripcion: data['descripcion']?.toString() ?? '',
      presupuestoMonto: (data['presupuesto_monto'] as num?)?.toDouble(),
      estado: data['estado']?.toString() ?? ESTADO_PENDIENTE,
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
      presupuestoAt: data['presupuesto_at'] != null 
          ? DateTime.tryParse(data['presupuesto_at']) 
          : null,
      respuestaAt: data['respuesta_at'] != null 
          ? DateTime.tryParse(data['respuesta_at']) 
          : null,
      tiempoRealRespuestaMinutos: data['tiempo_real_respuesta_minutos'] as int?,
      limiteRespuestaMinutos: data['limite_respuesta_minutos'] as int?,
      riesgoNotificado: data['riesgo_notificado'] as bool?,
      pescadorTelefono: data['pescador_telefono']?.toString(),
      puntoPartida: partidaData != null ? Map<String, dynamic>.from(partidaData) : null,
      puntoDestino: destinoData != null ? Map<String, dynamic>.from(destinoData) : null,
      distanciaKm: (data['distancia_km'] as num?)?.toDouble(),
      distanciaMillas: (data['distancia_millas'] as num?)?.toDouble(),
      duracionEstimadaMinutos: data['duracion_estimada_minutos'] as int?,
      fechaIda: data['fecha_ida'] != null ? DateTime.tryParse(data['fecha_ida']) : null,
      fechaVuelta: data['fecha_vuelta'] != null ? DateTime.tryParse(data['fecha_vuelta']) : null,
      horaEncuentro: data['hora_encuentro']?.toString(),
      cantidadPersonas: data['cantidad_personas'] as int?,
      trackLog: data['track_log'] != null
          ? (data['track_log'] as List).map((x) => Map<String, dynamic>.from(x as Map)).toList()
          : null,
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'pescador_id': pescadorId,
      'capitan_id': capitanId,
      'descripcion': descripcion,
      'presupuesto_monto': presupuestoMonto,
      'estado': estado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'presupuesto_at': presupuestoAt?.toIso8601String(),
      'respuesta_at': respuestaAt?.toIso8601String(),
      'coordenadas_partida': puntoPartida,
      'coordenadas_destino': puntoDestino,
      'punto_partida': puntoPartida,
      'punto_destino': puntoDestino,
      'distancia_km': distanciaKm,
      'distancia_millas': distanciaMillas,
      'duracion_estimada_minutos': duracionEstimadaMinutos,
      'fecha_ida': fechaIda?.toIso8601String(),
      'fecha_vuelta': fechaVuelta?.toIso8601String(),
      'hora_encuentro': horaEncuentro,
      'cantidad_personas': cantidadPersonas,
      'track_log': trackLog,
    };
  }

  // Map para insertar (sin id y timestamps)
  Map<String, dynamic> toInsertMap() {
    return {
      'pescador_id': pescadorId,
      'capitan_id': capitanId,
      'descripcion': descripcion,
      'presupuesto_monto': presupuestoMonto,
      'estado': estado,
    };
  }

  // Validar datos de la cotizacion
  bool get isValid {
    return pescadorId.isNotEmpty && 
           capitanId.isNotEmpty && 
           descripcion.isNotEmpty;
  }

  // Verificar si esta pendiente
  bool get isPendiente => estado == ESTADO_PENDIENTE;

  // Verificar si esta presupuestada
  bool get isPresupuestada => estado == ESTADO_PRESUPUESTADO;

  // Verificar si esta aceptada
  bool get isAceptada => estado == ESTADO_ACEPTADO;

  // Verificar si esta rechazada
  bool get isRechazada => estado == ESTADO_RECHAZADO;

  // Verificar si esta en riesgo
  bool get isEnRiesgo => estado == ESTADO_EN_RIESGO;

  // Verificar si tiene presupuesto
  bool get hasPresupuesto => presupuestoMonto != null && presupuestoMonto! > 0;

  // Obtener estado formateado
  String get estadoFormateado {
    switch (estado) {
      case ESTADO_PENDIENTE:
        return 'Pendiente';
      case ESTADO_PRESUPUESTADO:
        return 'Presupuestado';
      case ESTADO_ACEPTADO:
        return 'Aceptado';
      case ESTADO_RECHAZADO:
        return 'Rechazado';
      case ESTADO_EN_RIESGO:
        return 'EN RIESGO';
      case ESTADO_EN_VIAJE:
        return 'En Viaje';
      case ESTADO_FINALIZADO:
        return 'Finalizado';
      default:
        return 'Desconocido';
    }
  }

  // Obtener color del estado
  String get estadoColor {
    switch (estado) {
      case ESTADO_PENDIENTE:
        return 'orange';
      case ESTADO_PRESUPUESTADO:
        return 'blue';
      case ESTADO_ACEPTADO:
        return 'green';
      case ESTADO_RECHAZADO:
        return 'red';
      case ESTADO_EN_RIESGO:
        return 'purple';
      case ESTADO_EN_VIAJE:
        return 'indigo';
      case ESTADO_FINALIZADO:
        return 'teal';
      default:
        return 'grey';
    }
  }

  // Obtener icono del estado
  String get estadoIcono {
    switch (estado) {
      case ESTADO_PENDIENTE:
        return '⏳';
      case ESTADO_PRESUPUESTADO:
        return '💰';
      case ESTADO_ACEPTADO:
        return '✅';
      case ESTADO_RECHAZADO:
        return '❌';
      case ESTADO_EN_RIESGO:
        return '⚠️';
      case ESTADO_EN_VIAJE:
        return '🛥️';
      case ESTADO_FINALIZADO:
        return '🏁';
      default:
        return '❓';
    }
  }

  // Calcular tiempo de respuesta
  Duration? get tiempoRespuesta {
    if (respuestaAt != null) {
      return respuestaAt!.difference(createdAt);
    }
    return null;
  }

  // Formatear tiempo de respuesta
  String get tiempoRespuestaFormateado {
    if (tiempoRealRespuestaMinutos != null) {
      return '$tiempoRealRespuestaMinutos min';
    }
    
    final tiempo = tiempoRespuesta;
    if (tiempo == null) return 'N/A';
    
    if (tiempo.inMinutes < 60) {
      return '${tiempo.inMinutes} min';
    } else if (tiempo.inHours < 24) {
      return '${tiempo.inHours}h ${tiempo.inMinutes % 60}min';
    } else {
      return '${tiempo.inDays}d ${tiempo.inHours % 24}h';
    }
  }

  // Calcular tiempo transcurrido desde creacion
  int get minutosTranscurridos {
    final ahora = DateTime.now();
    final transcurrido = ahora.difference(createdAt);
    return transcurrido.inMinutes;
  }

  // Calcular tiempo restante para respuesta
  int? get minutosRestantes {
    final limite = limiteRespuestaMinutos ?? 15;
    final transcurrido = minutosTranscurridos;
    final restante = limite - transcurrido;
    return restante > 0 ? restante : 0;
  }

  // Calcular porcentaje de tiempo usado
  double get porcentajeTiempoUsado {
    final limite = limiteRespuestaMinutos ?? 15;
    final transcurrido = minutosTranscurridos;
    final porcentaje = (transcurrido / limite) * 100;
    return porcentaje > 100 ? 100.0 : porcentaje;
  }

  // Verificar si esta a punto de vencerse (80% del tiempo)
  bool get estaPorVencerse => porcentajeTiempoUsado >= 80;

  // Verificar si ya vencio
  bool get estaVencida => minutosRestantes == 0;

  // Obtener color segun urgencia
  String get urgenciaColor {
    if (isEnRiesgo) return 'purple';
    if (estaVencida) return 'red';
    if (estaPorVencerse) return 'orange';
    return 'green';
  }

  // Obtener texto de tiempo restante formateado
  String get tiempoRestanteFormateado {
    final restante = minutosRestantes;
    if (restante == null) return 'N/A';
    
    if (restante <= 0) return 'Vencida';
    
    if (restante < 60) {
      return '$restante min';
    } else {
      final horas = restante ~/ 60;
      final minutos = restante % 60;
      return '${horas}h ${minutos}min';
    }
  }

  // Verificar si cumplio tiempo de respuesta
  bool get cumplioTiempoRespuesta {
    if (tiempoRealRespuestaMinutos == null) return false;
    final limite = limiteRespuestaMinutos ?? 15;
    return tiempoRealRespuestaMinutos! <= limite;
  }

  // Metodos geograficos
  bool get tieneDatosGeograficos => puntoPartida != null && puntoDestino != null;
  
  String get nombrePartida => puntoPartida?['nombre'] ?? 'Origen desconocido';
  
  String get nombreDestino => puntoDestino?['nombre'] ?? 'Destino desconocido';
  
  double? get latitudPartida => puntoPartida?['lat'] != null ? (puntoPartida!['lat'] as num).toDouble() : null;
  
  double? get longitudPartida => puntoPartida?['lon'] != null ? (puntoPartida!['lon'] as num).toDouble() : null;
  
  double? get latitudDestino => puntoDestino?['lat'] != null ? (puntoDestino!['lat'] as num).toDouble() : null;
  
  double? get longitudDestino => puntoDestino?['lon'] != null ? (puntoDestino!['lon'] as num).toDouble() : null;
  
  String? get staticMapUrl {
    if (latitudPartida == null || longitudPartida == null || latitudDestino == null || longitudDestino == null) {
      return null;
    }
    final partidaStr = '$longitudPartida,$latitudPartida,pm2gnm'; // Verde
    final destinoStr = '$longitudDestino,$latitudDestino,pm2rdm'; // Rojo
    
    String url = 'https://static-maps.yandex.ru/1.x/?l=sat&size=450,150&pt=$partidaStr~$destinoStr';
    
    if (trackLog != null && trackLog!.isNotEmpty) {
      final points = <String>[];
      final step = (trackLog!.length / 15).clamp(1, double.infinity).ceil();
      for (int i = 0; i < trackLog!.length; i += step) {
        final pt = trackLog![i];
        final lat = pt['lat'];
        final lon = pt['lon'];
        if (lat != null && lon != null) {
          points.add('$lon,$lat');
        }
      }
      final lastPt = trackLog!.last;
      if (lastPt['lat'] != null && lastPt['lon'] != null) {
        points.add('${lastPt['lon']},${lastPt['lat']}');
      }
      
      if (points.isNotEmpty) {
        url += '&pl=color:0000ff80,width:4,${points.join(',')}';
      }
    }
    return url;
  }
  
  String get distanciaFormateada {
    if (distanciaKm == null) return 'Distancia no calculada';
    return '${distanciaKm!.toStringAsFixed(2)} km';
  }
  
  String get distanciaFormateadaMillas {
    if (distanciaMillas == null) return 'Distancia no calculada';
    return '${distanciaMillas!.toStringAsFixed(2)} millas';
  }
  
  String get duracionFormateada {
    if (duracionEstimadaMinutos == null) return 'Duracion no estimada';
    final minutos = duracionEstimadaMinutos!;
    if (minutos < 60) {
      return '$minutos minutos';
    } else {
      final horas = minutos ~/ 60;
      final minsRestantes = minutos % 60;
      return '${horas}h ${minsRestantes}min';
    }
  }
  
  String get categoriaViaje {
    if (distanciaKm == null) return 'No definido';
    final km = distanciaKm!;
    if (km <= 10) return 'Corto';
    if (km <= 30) return 'Medio';
    if (km <= 60) return 'Largo';
    return 'Muy Largo';
  }
  
  String get colorCategoria {
    if (distanciaKm == null) return 'grey';
    final km = distanciaKm!;
    if (km <= 10) return '#4CAF50';
    if (km <= 30) return '#FF9800';
    if (km <= 60) return '#FF5722';
    return '#F44336';
  }
  
  // Calcular presupuesto base basado en distancia
  double get presupuestoBase {
    if (distanciaKm == null) return 0.0;
    final baseFijo = 50.0; // Cargo base fijo
    final costoPorKm = 8.0; // $8 por kilometro
    return baseFijo + (distanciaKm! * costoPorKm);
  }
  
  String get presupuestoBaseFormateado {
    return '\$${presupuestoBase.toStringAsFixed(2)}';
  }

  // Formatear monto del presupuesto
  String get presupuestoFormateado {
    if (!hasPresupuesto) return 'Sin presupuesto';
    return '\$${presupuestoMonto!.toStringAsFixed(2)}';
  }

  // Obtener descripcion corta
  String get descripcionCorta {
    if (descripcion.length <= 50) return descripcion;
    return '${descripcion.substring(0, 47)}...';
  }

  /// Código corto legible del viaje: #VJ-XXXX
  String get codigoCorto {
    if (id.isEmpty) return '#VJ-????';
    final parte = id.replaceAll('-', '').toUpperCase();
    return '#VJ-${parte.substring(0, 4)}';
  }

  /// Código largo de referencia (8 chars del UUID en mayúscula)
  String get codigoLargo {
    if (id.isEmpty) return 'SIN-CÓDIGO';
    return id.toUpperCase().substring(0, 8);
  }

  // Constructor para cotizacion vacia
  Cotizacion.empty()
      : id = '',
        pescadorId = '',
        capitanId = '',
        descripcion = '',
        presupuestoMonto = null,
        estado = ESTADO_PENDIENTE,
        createdAt = DateTime.now(),
        updatedAt = DateTime.now(),
        presupuestoAt = null,
        respuestaAt = null,
        tiempoRealRespuestaMinutos = null,
        limiteRespuestaMinutos = null,
        riesgoNotificado = null,
        pescadorTelefono = null,
        puntoPartida = null,
        puntoDestino = null,
        distanciaKm = null,
        distanciaMillas = null,
        duracionEstimadaMinutos = null,
        fechaIda = null,
        fechaVuelta = null,
        horaEncuentro = null,
        cantidadPersonas = null,
        trackLog = null;

  // Constructor para cotizacion temporal (antes de guardar)
  Cotizacion.temporal({
    required this.pescadorId,
    required this.capitanId,
    required this.descripcion,
    this.presupuestoMonto,
    this.estado = ESTADO_PENDIENTE,
  }) : id = 'temp_${DateTime.now().millisecondsSinceEpoch}',
     createdAt = DateTime.now(),
     updatedAt = DateTime.now(),
     presupuestoAt = null,
     respuestaAt = null,
     tiempoRealRespuestaMinutos = null,
     limiteRespuestaMinutos = null,
     riesgoNotificado = null,
     pescadorTelefono = null,
     puntoPartida = null,
     puntoDestino = null,
     distanciaKm = null,
     distanciaMillas = null,
     duracionEstimadaMinutos = null,
     fechaIda = null,
     fechaVuelta = null,
     horaEncuentro = null,
     cantidadPersonas = null,
     trackLog = null;

  // Copiar cotizacion con cambios
  Cotizacion copyWith({
    String? id,
    String? pescadorId,
    String? capitanId,
    String? descripcion,
    double? presupuestoMonto,
    String? estado,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? presupuestoAt,
    DateTime? respuestaAt,
    DateTime? fechaIda,
    DateTime? fechaVuelta,
    String? horaEncuentro,
    int? cantidadPersonas,
    List<Map<String, dynamic>>? trackLog,
  }) {
    return Cotizacion(
      id: id ?? this.id,
      pescadorId: pescadorId ?? this.pescadorId,
      capitanId: capitanId ?? this.capitanId,
      descripcion: descripcion ?? this.descripcion,
      presupuestoMonto: presupuestoMonto ?? this.presupuestoMonto,
      estado: estado ?? this.estado,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      presupuestoAt: presupuestoAt ?? this.presupuestoAt,
      respuestaAt: respuestaAt ?? this.respuestaAt,
      distanciaKm: distanciaKm,
      distanciaMillas: distanciaMillas,
      duracionEstimadaMinutos: duracionEstimadaMinutos,
      puntoPartida: puntoPartida,
      puntoDestino: puntoDestino,
      fechaIda: fechaIda ?? this.fechaIda,
      fechaVuelta: fechaVuelta ?? this.fechaVuelta,
      horaEncuentro: horaEncuentro ?? this.horaEncuentro,
      cantidadPersonas: cantidadPersonas ?? this.cantidadPersonas,
      trackLog: trackLog ?? this.trackLog,
    );
  }

  // Convertir a JSON para logs
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pescadorId': pescadorId,
      'capitanId': capitanId,
      'descripcion': descripcion,
      'presupuestoMonto': presupuestoMonto,
      'estado': estado,
      'estadoFormateado': estadoFormateado,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'presupuestoAt': presupuestoAt?.toIso8601String(),
      'respuestaAt': respuestaAt?.toIso8601String(),
      'tiempoRespuesta': tiempoRespuesta?.inMinutes,
      'hasPresupuesto': hasPresupuesto,
    };
  }
}
