/// Clasifica el tipo de checkout según el contenido del carrito.
///
/// Se persiste en la columna `tipo_checkout` de la tabla `pedidos` mediante
/// el getter [valor]. Los strings deben mantenerse estables porque quedan
/// guardados en la base de datos.
enum TipoCheckout {
  /// Carrito vacío (sin items).
  vacio('vacio'),

  /// Solo productos de la tienda.
  tienda('tienda'),

  /// Solo un viaje (salida de pesca).
  viaje('viaje'),

  /// Combinación de productos de tienda y viaje en el mismo pedido.
  hibrido('hibrido');

  const TipoCheckout(this.valor);

  /// Valor string persistido en Supabase (`pedidos.tipo_checkout`).
  final String valor;

  /// Prefijo corto para el número de pedido legible (ej: `TI-2026-0001`).
  String get prefijoPedido {
    switch (this) {
      case TipoCheckout.tienda:
        return 'TI';
      case TipoCheckout.viaje:
        return 'VJ';
      case TipoCheckout.hibrido:
        return 'MX';
      case TipoCheckout.vacio:
        return 'PD';
    }
  }

  /// Reconstruye el enum desde el string almacenado. Cae a [vacio] si no matchea.
  static TipoCheckout fromValor(String? valor) {
    switch (valor) {
      case 'tienda':
        return TipoCheckout.tienda;
      case 'viaje':
        return TipoCheckout.viaje;
      case 'hibrido':
        return TipoCheckout.hibrido;
      default:
        return TipoCheckout.vacio;
    }
  }
}

/// Determina el [TipoCheckout] a partir de la presencia de items de tienda
/// y/o de viaje en el carrito.
TipoCheckout combinarTipoCheckout({
  required bool tieneTienda,
  required bool tieneViaje,
}) {
  if (tieneTienda && tieneViaje) return TipoCheckout.hibrido;
  if (tieneTienda) return TipoCheckout.tienda;
  if (tieneViaje) return TipoCheckout.viaje;
  return TipoCheckout.vacio;
}
