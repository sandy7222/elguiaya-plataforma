
class ReviewExpedicion {
  final String id;
  final String usuarioId;
  final String usuarioNombre;
  final String? usuarioAvatar;
  final String guiaId;
  final String? tripId;
  final double rating;
  final String comentario;
  final List<String> fotosCapturas; // Fotos de los pescados/momentos
  final String? especieCapturada;    // Ejemplo: "Dorado", "Surubí"
  final double? pesoCaptura;        // En KG
  final DateTime fecha;

  ReviewExpedicion({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    this.usuarioAvatar,
    required this.guiaId,
    this.tripId,
    required this.rating,
    required this.comentario,
    this.fotosCapturas = const [],
    this.especieCapturada,
    this.pesoCaptura,
    required this.fecha,
  });

  factory ReviewExpedicion.fromSupabase(Map<String, dynamic> data) {
    return ReviewExpedicion(
      id: data['id']?.toString() ?? '',
      usuarioId: data['usuario_id']?.toString() ?? '',
      usuarioNombre: data['usuario_nombre']?.toString() ?? 'Pescador Anónimo',
      usuarioAvatar: data['usuario_avatar']?.toString(),
      guiaId: data['guia_id']?.toString() ?? '',
      tripId: data['trip_id']?.toString(),
      rating: (data['rating'] as num?)?.toDouble() ?? 5.0,
      comentario: data['comentario']?.toString() ?? '',
      fotosCapturas: List<String>.from(data['fotos_capturas'] ?? []),
      especieCapturada: data['especie_capturada']?.toString(),
      pesoCaptura: (data['peso_captura'] as num?)?.toDouble(),
      fecha: DateTime.tryParse(data['fecha'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario_id': usuarioId,
      'usuario_nombre': usuarioNombre,
      'guia_id': guiaId,
      'trip_id': tripId,
      'rating': rating,
      'comentario': comentario,
      'fotos_capturas': fotosCapturas,
      'especie_capturada': especieCapturada,
      'peso_captura': pesoCaptura,
      'fecha': fecha.toIso8601String(),
    };
  }
}
