class PescadorViajeSnapshot {
  final DateTime? capturadoEn;
  final Map<String, dynamic> codigos;
  final Map<String, dynamic> titular;
  final List<Map<String, dynamic>> acompanantes;
  final Map<String, dynamic> contingencia;

  const PescadorViajeSnapshot({
    this.capturadoEn,
    this.codigos = const {},
    this.titular = const {},
    this.acompanantes = const [],
    this.contingencia = const {},
  });

  factory PescadorViajeSnapshot.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return const PescadorViajeSnapshot();
    }
    DateTime? capturado;
    final raw = json['capturado_en']?.toString();
    if (raw != null) capturado = DateTime.tryParse(raw);

    final acompRaw = json['acompanantes'];
    final acompanantes = <Map<String, dynamic>>[];
    if (acompRaw is List) {
      for (final item in acompRaw) {
        if (item is Map) {
          acompanantes.add(Map<String, dynamic>.from(item));
        }
      }
    }

    return PescadorViajeSnapshot(
      capturadoEn: capturado,
      codigos: Map<String, dynamic>.from(json['codigos'] ?? {}),
      titular: Map<String, dynamic>.from(json['titular'] ?? {}),
      acompanantes: acompanantes,
      contingencia: Map<String, dynamic>.from(json['contingencia'] ?? {}),
    );
  }

  String txtTitular(String key, [String fallback = 'No informado']) {
    final value = titular[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return fallback;
    }
    return value;
  }

  String txtContingencia(String key, [String fallback = 'No informado']) {
    final value = contingencia[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return fallback;
    }
    return value;
  }

  String txtCodigo(String key, [String fallback = '—']) {
    final value = codigos[key]?.toString().trim();
    if (value == null || value.isEmpty || value.toLowerCase() == 'null') {
      return fallback;
    }
    return value;
  }
}

class FichaPescadorData {
  final String pedidoId;
  final String estado;
  final double? montoTotal;
  final String? fechaServicio;
  final bool contactoHabilitado;
  final String? capitanId;
  final String? pescadorId;
  final PescadorViajeSnapshot snapshot;

  const FichaPescadorData({
    required this.pedidoId,
    required this.estado,
    this.montoTotal,
    this.fechaServicio,
    this.contactoHabilitado = false,
    this.capitanId,
    this.pescadorId,
    required this.snapshot,
  });

  factory FichaPescadorData.fromRpc(Map<String, dynamic> json) {
    final snapRaw = json['pescador_snapshot'];
    Map<String, dynamic>? snapMap;
    if (snapRaw is Map) {
      snapMap = Map<String, dynamic>.from(snapRaw);
    }

    return FichaPescadorData(
      pedidoId: json['pedido_id']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      montoTotal: (json['monto_total'] as num?)?.toDouble(),
      fechaServicio: json['fecha_servicio']?.toString(),
      contactoHabilitado: json['contacto_habilitado'] == true,
      capitanId: json['capitan_id']?.toString(),
      pescadorId: json['pescador_id']?.toString(),
      snapshot: PescadorViajeSnapshot.fromJson(snapMap),
    );
  }
}
