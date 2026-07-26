/// Política centralizada del ciclo de vida de las "subastas" (cotizaciones de
/// viaje que el pescador publica para que los capitanes presupuesten).
///
/// Reúne las reglas de duración y visibilidad para que sean consistentes entre
/// la creación de la cotización, los tableros del pescador y los filtros de red.
class SubastaLifecyclePolicy {
  SubastaLifecyclePolicy._();

  /// Duración de una subasta "rápida" (pescador quiere respuestas urgentes).
  static const Duration duracionRapida = Duration(hours: 12);

  /// Duración por defecto de una subasta normal.
  static const Duration duracionNormal = Duration(hours: 24);

  /// Devuelve cuánto vive una subasta desde su creación según su tipo.
  ///
  /// `tipo_subasta == 'rapida'` => 12 hs; cualquier otro valor => 24 hs.
  static Duration duracionSubastaDesdeCreacion(String? tipoSubasta) {
    return tipoSubasta == 'rapida' ? duracionRapida : duracionNormal;
  }

  /// Momento de expiración efectivo de una cotización.
  ///
  /// Usa `expira_en` si está presente; si no, lo deriva de `created_at` más la
  /// duración correspondiente al `tipo_subasta`. Devuelve null si no se puede
  /// determinar.
  static DateTime? expiracion(Map<String, dynamic> cotizacion) {
    final expiraRaw = cotizacion['expira_en']?.toString();
    if (expiraRaw != null && expiraRaw.isNotEmpty) {
      final parsed = DateTime.tryParse(expiraRaw);
      if (parsed != null) return parsed;
    }

    final creadoRaw = cotizacion['created_at']?.toString();
    if (creadoRaw != null && creadoRaw.isNotEmpty) {
      final creado = DateTime.tryParse(creadoRaw);
      if (creado != null) {
        return creado.add(
          duracionSubastaDesdeCreacion(cotizacion['tipo_subasta']?.toString()),
        );
      }
    }
    return null;
  }

  /// Indica si la subasta ya venció respecto de [ahora].
  static bool estaExpirada(Map<String, dynamic> cotizacion, {DateTime? ahora}) {
    final exp = expiracion(cotizacion);
    if (exp == null) return false; // sin datos suficientes => no la ocultamos
    return exp.isBefore(ahora ?? DateTime.now());
  }

  /// Regla de visibilidad para el tablero del pescador (sus propias
  /// cotizaciones activas).
  ///
  /// Se muestra mientras: (a) tenga presupuestos recibidos —para que el
  /// pescador pueda revisarlos aunque haya vencido—, o (b) siga vigente
  /// (no expirada). Se ocultan las que vencieron sin ninguna oferta.
  static bool esVisibleEnTablero(
    Map<String, dynamic> cotizacion, {
    required int cantidadPresupuestos,
    DateTime? ahora,
  }) {
    if (cantidadPresupuestos > 0) return true;
    return !estaExpirada(cotizacion, ahora: ahora);
  }
}
