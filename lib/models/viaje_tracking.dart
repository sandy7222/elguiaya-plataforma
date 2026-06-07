

class ViajeTracking {
  final String? id;
  final String? tripId;
  final String captainId;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final double? heading;
  final double? accuracy;
  final DateTime timestamp;

  ViajeTracking({
    this.id,
    this.tripId,
    required this.captainId,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    this.accuracy,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'trip_id': tripId,
      'captain_id': captainId,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ViajeTracking.fromMap(Map<String, dynamic> map) {
    return ViajeTracking(
      id: map['id'],
      tripId: map['trip_id'],
      captainId: map['captain_id'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      altitude: map['altitude'],
      speed: map['speed'],
      heading: map['heading'],
      accuracy: map['accuracy'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
