/// Utilidades para fecha de nacimiento en declaraciones PNA.
class FechaNacimientoUtils {
  FechaNacimientoUtils._();

  static String formatearLegible(dynamic value) {
    if (value == null) return '—';
    try {
      final d = value is DateTime
          ? value
          : DateTime.parse(value.toString().split('T').first);
      final day = d.day.toString().padLeft(2, '0');
      final month = d.month.toString().padLeft(2, '0');
      return '$day/$month/${d.year}';
    } catch (_) {
      return value.toString();
    }
  }

  static String? toIsoDate(DateTime? value) {
    if (value == null) return null;
    return value.toIso8601String().split('T').first;
  }

  static bool todosConFecha(List<Map<String, dynamic>> pasajeros) {
    if (pasajeros.isEmpty) return false;
    for (final p in pasajeros) {
      final raw = p['fecha_nacimiento'];
      if (raw == null || raw.toString().trim().isEmpty) return false;
    }
    return true;
  }
}
