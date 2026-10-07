/// Casilla "Seleccionar todos" de Importación / Exportación (admin). Tres estados: todos, ninguno o algunos.
class SeleccionCatalogo {
  /// `true` si están todos tildados, `false` si no hay ninguno (o el catálogo está vacío), `null` si hay algunos (la casilla muestra un guion).
  static bool? estado(Set<String> seleccionados, List<String> ids) {
    if (ids.isEmpty) return false;
    final tildados = ids.where(seleccionados.contains).length;
    if (tildados == 0) return false;
    if (tildados == ids.length) return true;
    return null;
  }

  /// Si no están todos, los tilda todos; si ya están todos, los destilda. No toca lo seleccionado que no está en [ids]. No modifica [seleccionados].
  static Set<String> alternarTodos(Set<String> seleccionados, List<String> ids) {
    final resultado = {...seleccionados};
    if (estado(seleccionados, ids) == true) {
      resultado.removeAll(ids);
    } else {
      resultado.addAll(ids);
    }
    return resultado;
  }

  /// Sin selección se exporta todo el catálogo (como hasta hoy); con selección, solo lo tildado.
  static int cantidadAExportar(Set<String> seleccionados, List<String> ids) {
    final tildados = ids.where(seleccionados.contains).length;
    return tildados == 0 ? ids.length : tildados;
  }
}
