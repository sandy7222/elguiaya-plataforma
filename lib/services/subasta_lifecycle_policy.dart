/// Reglas unificadas de subasta + ventana de elección (Opción B marketplace).
class SubastaLifecyclePolicy {
  SubastaLifecyclePolicy._();

  static const int horasSubastaRapida = 12;
  static const int horasSubastaNormal = 24;
  static const int horasVentanaEleccion = 24;

  static DateTime? _parse(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  static DateTime createdAtDe(Map<String, dynamic> cotizacion) {
    return _parse(cotizacion['created_at']?.toString()) ?? DateTime.now();
  }

  /// Fin de subasta: capitanes dejan de ofertar.
  static DateTime expiraEnDe(Map<String, dynamic> cotizacion) {
    final fromDb = _parse(cotizacion['expira_en']?.toString());
    if (fromDb != null) return fromDb;

    final tipo = cotizacion['tipo_subasta']?.toString().toLowerCase();
    final horas = tipo == 'rapida' ? horasSubastaRapida : horasSubastaNormal;
    return createdAtDe(cotizacion).add(Duration(hours: horas));
  }

  /// Fin de visibilidad en tablero/panel.
  static DateTime caducaEnDe(
    Map<String, dynamic> cotizacion, {
    required int cantidadPresupuestos,
  }) {
    final fromDb = _parse(cotizacion['caduca_en']?.toString());
    if (fromDb != null) return fromDb;

    final expira = expiraEnDe(cotizacion);
    if (cantidadPresupuestos > 0) {
      return expira.add(const Duration(hours: horasVentanaEleccion));
    }
    return expira;
  }

  static bool subastaCerrada(Map<String, dynamic> cotizacion, [DateTime? now]) {
    final ahora = now ?? DateTime.now();
    return ahora.isAfter(expiraEnDe(cotizacion));
  }

  static bool caducada(
    Map<String, dynamic> cotizacion, {
    required int cantidadPresupuestos,
    DateTime? now,
  }) {
    final ahora = now ?? DateTime.now();
    return ahora.isAfter(
      caducaEnDe(cotizacion, cantidadPresupuestos: cantidadPresupuestos),
    );
  }

  static bool esEstadoTerminal(String? estado) {
    final e = estado?.toLowerCase() ?? '';
    return e == 'cerrada' ||
        e == 'cancelada' ||
        e == 'cancelado' ||
        e == 'finalizado' ||
        e == 'rechazada' ||
        e == 'rechazado';
  }

  /// Pedido que todavía justifica fila en mesa tras caducar (pago hecho / viaje vivo).
  static bool pedidoMantieneMesaTrasCaducar(Map<String, dynamic>? pedido) {
    if (pedido == null) return false;
    if (pedido['contacto_habilitado'] == true) return true;
    final e = (pedido['estado'] ?? pedido['pedido_estado'])
        ?.toString()
        .toLowerCase();
    if (e == null || e.isEmpty) return false;
    return e == 'pagado' ||
        e == 'confirmado' ||
        e == 'cerrado' ||
        e == 'en_curso' ||
        e == 'en_viaje' ||
        e == 'listo_para_confirmar';
  }

  static bool esVisibleEnTablero(
    Map<String, dynamic> cotizacion, {
    required int cantidadPresupuestos,
    Map<String, dynamic>? pedidoActivo,
    DateTime? now,
  }) {
    if (esEstadoTerminal(cotizacion['estado']?.toString())) {
      return pedidoMantieneMesaTrasCaducar(pedidoActivo);
    }

    if (caducada(
      cotizacion,
      cantidadPresupuestos: cantidadPresupuestos,
      now: now,
    )) {
      // Pago pendiente vencido NO se queda en la mesa.
      return pedidoMantieneMesaTrasCaducar(pedidoActivo);
    }

    return true;
  }

  static Duration duracionSubastaDesdeCreacion(String? tipoSubasta) {
    final horas =
        tipoSubasta?.toLowerCase() == 'rapida' ? horasSubastaRapida : horasSubastaNormal;
    return Duration(hours: horas);
  }
}

/// Fases visibles en el tablero de operaciones.
enum SubastaFase {
  enSubasta,
  elegirOferta,
  sinOfertas,
  pagoPendiente,
  confirmado,
  vencida,
}

extension SubastaFaseLabels on SubastaFase {
  String get etiqueta {
    switch (this) {
      case SubastaFase.enSubasta:
        return 'EN SUBASTA';
      case SubastaFase.elegirOferta:
        return 'ELEGÍ CAPITÁN';
      case SubastaFase.sinOfertas:
        return 'SIN OFERTAS';
      case SubastaFase.pagoPendiente:
        return 'PAGO PENDIENTE';
      case SubastaFase.confirmado:
        return 'CONFIRMADO';
      case SubastaFase.vencida:
        return 'VENCIDA';
    }
  }

  int get prioridadUrgencia {
    switch (this) {
      case SubastaFase.pagoPendiente:
        return 0;
      case SubastaFase.elegirOferta:
        return 1;
      case SubastaFase.enSubasta:
        return 2;
      case SubastaFase.sinOfertas:
        return 3;
      case SubastaFase.confirmado:
        return 4;
      case SubastaFase.vencida:
        return 5;
    }
  }
}
