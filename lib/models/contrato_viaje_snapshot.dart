class ContratoViajeSnapshot {
  final DateTime? capturadoEn;
  final Map<String, dynamic> capitan;
  final Map<String, dynamic> embarcacion;
  final Map<String, dynamic> servicios;
  final Map<String, dynamic> viaje;
  final Map<String, dynamic> oferta;

  const ContratoViajeSnapshot({
    this.capturadoEn,
    this.capitan = const {},
    this.embarcacion = const {},
    this.servicios = const {},
    this.viaje = const {},
    this.oferta = const {},
  });

  factory ContratoViajeSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const ContratoViajeSnapshot();
    }
    DateTime? capturado;
    final raw = json['capturado_en']?.toString();
    if (raw != null) capturado = DateTime.tryParse(raw);

    return ContratoViajeSnapshot(
      capturadoEn: capturado,
      capitan: Map<String, dynamic>.from(json['capitan'] ?? {}),
      embarcacion: Map<String, dynamic>.from(json['embarcacion'] ?? {}),
      servicios: Map<String, dynamic>.from(json['servicios'] ?? {}),
      viaje: Map<String, dynamic>.from(json['viaje'] ?? {}),
      oferta: Map<String, dynamic>.from(json['oferta'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'capturado_en': (capturadoEn ?? DateTime.now()).toIso8601String(),
      'capitan': capitan,
      'embarcacion': embarcacion,
      'servicios': servicios,
      'viaje': viaje,
      'oferta': oferta,
    };
  }

  String txt(String section, String key, [String fallback = 'No informado']) {
    final map = switch (section) {
      'capitan' => capitan,
      'embarcacion' => embarcacion,
      'servicios' => servicios,
      'viaje' => viaje,
      'oferta' => oferta,
      _ => const {},
    };
    final value = map[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return fallback;
    }
    return value;
  }
}

class FichaContractualData {
  final String pedidoId;
  final String estado;
  final double? montoTotal;
  final String? fechaServicio;
  final bool contactoHabilitado;
  final String? capitanId;
  final String? pescadorId;
  final ContratoViajeSnapshot snapshot;

  const FichaContractualData({
    required this.pedidoId,
    required this.estado,
    this.montoTotal,
    this.fechaServicio,
    this.contactoHabilitado = false,
    this.capitanId,
    this.pescadorId,
    required this.snapshot,
  });

  factory FichaContractualData.fromRpc(Map<String, dynamic> json) {
    final snapRaw = json['contrato_snapshot'];
    Map<String, dynamic>? snapMap;
    if (snapRaw is Map) {
      snapMap = Map<String, dynamic>.from(snapRaw);
    }

    return FichaContractualData(
      pedidoId: json['pedido_id']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      montoTotal: (json['monto_total'] as num?)?.toDouble(),
      fechaServicio: json['fecha_servicio']?.toString(),
      contactoHabilitado: json['contacto_habilitado'] == true,
      capitanId: json['capitan_id']?.toString(),
      pescadorId: json['pescador_id']?.toString(),
      snapshot: ContratoViajeSnapshot.fromJson(snapMap),
    );
  }

  bool get puedeVerContacto =>
      contactoHabilitado ||
      const {'pagado', 'confirmado', 'en_curso', 'listo_para_confirmar', 'cerrado'}
          .contains(estado);
}
