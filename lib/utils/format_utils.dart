/// Utilidades de formato compartidas en la app.
class FormatUtils {
  FormatUtils._();

  /// Enmascara CBU/CVU mostrando solo los primeros y últimos 4 dígitos.
  static String enmascararCbu(String? cbu) {
    final limpio = cbu?.replaceAll(RegExp(r'[\s\-]'), '') ?? '';
    if (limpio.length < 8) return 'Sin CBU cargado';
    return '${limpio.substring(0, 4)}...${limpio.substring(limpio.length - 4)}';
  }
}
