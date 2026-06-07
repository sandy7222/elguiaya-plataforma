import 'package:hive/hive.dart';

part 'pique_pulse.g.dart';

@HiveType(typeId: 3)
class PiquePulse extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final DateTime timestamp;

  @HiveField(2)
  final double latitud;

  @HiveField(3)
  final double longitud;

  @HiveField(4)
  final String tipoActivacion;

  @HiveField(5)
  final String? especieDetectada;

  PiquePulse({
    required this.id,
    required this.timestamp,
    required this.latitud,
    required this.longitud,
    required this.tipoActivacion,
    this.especieDetectada,
  });

  /// Convierte el modelo a un Map (para el servidor Supabase en Capitán-YA)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitud': latitud,
      'longitud': longitud,
      'tipo_activacion': tipoActivacion,
      'especie_detectada': especieDetectada,
    };
  }

  /// Crea una instancia del modelo desde un Map
  factory PiquePulse.fromMap(Map<String, dynamic> map) {
    return PiquePulse(
      id: map['id'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      latitud: (map['latitud'] as num).toDouble(),
      longitud: (map['longitud'] as num).toDouble(),
      tipoActivacion: map['tipo_activacion'] as String,
      especieDetectada: map['especie_detectada'] as String?,
    );
  }
}
