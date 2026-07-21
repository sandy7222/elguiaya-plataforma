

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cart_item.dart';
import '../models/direccion_envio.dart';
import '../models/manifiesto_viaje.dart';
import '../models/producto.dart';
import '../models/producto_variante.dart';
import '../models/tipo_checkout.dart';
import '../services/cart_persistence_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  DireccionEnvio? _direccionEnvio;
  final List<ManifiestoViaje> _manifiestosViaje = [];
  String? _pedidoViajeId;
  bool _inicializado = false;

  CartProvider() {
    inicializarSesion();
  }

  /// ID del pedido real en Supabase vinculado al viaje del carrito.
  String? get pedidoViajeId => _pedidoViajeId;
  bool get inicializado => _inicializado;

  List<CartItem> get items => List.unmodifiable(_items);

  List<CartItem> get itemsTienda {
    return _items
        .where((item) => item.producto.rubro.toLowerCase() != 'viaje')
        .toList();
  }

  List<CartItem> get itemsViaje {
    return _items
        .where((item) => item.producto.rubro.toLowerCase() == 'viaje')
        .toList();
  }

  bool get tieneItemsTienda => itemsTienda.isNotEmpty;
  bool get tieneItemsViaje => itemsViaje.isNotEmpty;

  TipoCheckout get tipoCheckoutActual => combinarTipoCheckout(
        tieneTienda: tieneItemsTienda,
        tieneViaje: tieneItemsViaje,
      );

  DireccionEnvio? get direccionEnvio => _direccionEnvio;
  List<ManifiestoViaje> get manifiestosViaje => List.unmodifiable(_manifiestosViaje);

  int get totalItems => _items.fold(0, (sum, item) => sum + item.cantidad);

  double get totalCarrito =>
      _items.fold(0.0, (sum, item) => sum + item.subtotal);

  String get totalFormateado => '\$${totalCarrito.toStringAsFixed(2)}';

  String? get _userId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> inicializarSesion() async {
    if (_inicializado) return;
    final userId = _userId;
    if (userId == null) {
      _inicializado = true;
      return;
    }

    final local = await CartPersistenceService.cargar(userId);
    if (local != null && local.items.isNotEmpty) {
      _aplicarSnapshot(local, merge: false);
    } else {
      final remoto = await CartPersistenceService.hidratarPedidoPendiente(userId);
      if (remoto != null && remoto.items.isNotEmpty) {
        _aplicarSnapshot(remoto, merge: false);
      }
    }

    _inicializado = true;
    notifyListeners();
  }

  /// Restaura el carrito desde un pedido concreto (deep link / MIS VIAJES → caja).
  Future<void> hidratarDesdePedido(String pedidoId) async {
    final snapshot = await CartPersistenceService.hidratarDesdePedido(pedidoId);
    if (snapshot == null || snapshot.items.isEmpty) return;
    _aplicarSnapshot(snapshot, merge: true);
    await _persistir();
    notifyListeners();
  }

  void _aplicarSnapshot(CartSnapshot snapshot, {required bool merge}) {
    if (!merge) {
      _items.clear();
      _pedidoViajeId = null;
    }
    if (snapshot.pedidoViajeId != null && snapshot.pedidoViajeId!.isNotEmpty) {
      _pedidoViajeId = snapshot.pedidoViajeId;
    }
    for (final item in snapshot.items) {
      if (item.producto.rubro.toLowerCase() == 'viaje') {
        _items.removeWhere(
          (i) => i.producto.rubro.toLowerCase() == 'viaje',
        );
        _items.add(item);
      } else {
        final idx = _items.indexWhere((i) => i.lineKey == item.lineKey);
        if (idx >= 0) {
          _items[idx] = item;
        } else {
          _items.add(item);
        }
      }
    }
  }

  Future<void> _persistir() async {
    await CartPersistenceService.guardar(
      userId: _userId,
      pedidoViajeId: _pedidoViajeId,
      items: List.from(_items),
    );
  }

  void _notifyPersist() {
    notifyListeners();
    _persistir();
  }

  bool estaEnCarrito(String productoId) {
    return _items.any((item) => item.producto.id == productoId);
  }

  int getCantidadProducto(String productoId) {
    final item =
        _items.where((item) => item.producto.id == productoId).firstOrNull;
    return item?.cantidad ?? 0;
  }

  bool agregarAlCarrito(
    Producto producto, {
    int cantidad = 1,
    ProductoVariante? variante,
  }) {
    if (producto.rubro.toLowerCase() == 'viaje') return false;

    if (producto.tieneVariantes && variante == null) return false;

    final stockOk = variante != null
        ? variante.stock >= cantidad
        : producto.stockDisponible >= cantidad;
    if (!stockOk) return false;

    final lineKey =
        '${producto.id}::${variante?.id ?? 'base'}';
    final existingItemIndex =
        _items.indexWhere((item) => item.lineKey == lineKey);

    if (existingItemIndex != -1) {
      final existingItem = _items[existingItemIndex];
      final nuevaCantidad = existingItem.cantidad + cantidad;
      final maxStock = variante?.stock ?? producto.stockDisponible;
      if (maxStock < nuevaCantidad) return false;
      _items[existingItemIndex] = CartItem(
        id: existingItem.id,
        producto: existingItem.producto,
        cantidad: nuevaCantidad,
        addedAt: existingItem.addedAt,
        varianteId: existingItem.varianteId,
        varianteColor: existingItem.varianteColor,
        varianteImagenUrl: existingItem.varianteImagenUrl,
        precioUnitarioOverride: existingItem.precioUnitarioOverride,
      );
    } else {
      _items.add(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        producto: producto,
        cantidad: cantidad,
        addedAt: DateTime.now(),
        varianteId: variante?.id,
        varianteColor: variante?.color,
        varianteImagenUrl: variante?.imagenUrl,
        precioUnitarioOverride: variante?.precioEfectivo(producto.precio),
      ));
    }

    _notifyPersist();
    return true;
  }

  void agregarViajeAlCarrito({
    required String idCotizacion,
    required String nombreCapitan,
    required double monto,
    required String descripcion,
    required String fecha,
    String? capitanAvatarUrl,
    String? embarcacionUrl,
    String? pedidoId,
  }) {
    if (pedidoId != null && pedidoId.isNotEmpty) {
      _pedidoViajeId = pedidoId;
    }

    String resolvedImagenUrl = 'assets/images/logo_elguiaya_white.png';
    if (embarcacionUrl != null && embarcacionUrl.trim().isNotEmpty) {
      resolvedImagenUrl = embarcacionUrl.trim();
    } else if (capitanAvatarUrl != null && capitanAvatarUrl.trim().isNotEmpty) {
      resolvedImagenUrl = capitanAvatarUrl.trim();
    }

    final productoViaje = Producto(
      id: 'viaje_$idCotizacion',
      nombre: 'VIAJE: $descripcion',
      descripcion: 'Capitán: $nombreCapitan - Fecha: $fecha',
      precio: monto,
      stock: 1,
      rubro: 'viaje',
      categoriaId: 'viajes',
      imagenUrl: resolvedImagenUrl,
      activo: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    _items.removeWhere((item) => item.producto.id == productoViaje.id);
    _items.add(CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      producto: productoViaje,
      cantidad: 1,
      addedAt: DateTime.now(),
    ));

    _notifyPersist();
  }

  bool actualizarCantidad(String productoId, int nuevaCantidad, {String? varianteId}) {
    if (nuevaCantidad < 0) return false;

    final lineKey = '$productoId::${varianteId ?? 'base'}';
    final itemIndex = _items.indexWhere((item) =>
        item.lineKey == lineKey ||
        (varianteId == null && item.producto.id == productoId));
    if (itemIndex == -1) return false;

    final item = _items[itemIndex];
    if (item.stockDisponible < nuevaCantidad) return false;

    if (nuevaCantidad == 0) {
      _items.removeAt(itemIndex);
    } else {
      _items[itemIndex] = CartItem(
        id: item.id,
        producto: item.producto,
        cantidad: nuevaCantidad,
        addedAt: item.addedAt,
        varianteId: item.varianteId,
        varianteColor: item.varianteColor,
        varianteImagenUrl: item.varianteImagenUrl,
        precioUnitarioOverride: item.precioUnitarioOverride,
      );
    }

    _notifyPersist();
    return true;
  }

  void eliminarDelCarrito(String productoId, {String? varianteId}) {
    final lineKey = '$productoId::${varianteId ?? 'base'}';
    CartItem? item;
    for (final i in _items) {
      if (i.lineKey == lineKey ||
          (varianteId == null && i.producto.id == productoId)) {
        item = i;
        break;
      }
    }
    if (item != null && item.producto.rubro.toLowerCase() == 'viaje') {
      _pedidoViajeId = null;
    }
    _items.removeWhere((i) =>
        i.lineKey == lineKey ||
        (varianteId == null && i.producto.id == productoId && i.varianteId == null));
    _notifyPersist();
  }

  bool incrementarCantidad(String productoId, {String? varianteId}) {
    final lineKey = '$productoId::${varianteId ?? 'base'}';
    final itemIndex = _items.indexWhere((item) =>
        item.lineKey == lineKey ||
        (varianteId == null && item.producto.id == productoId));
    if (itemIndex == -1) return false;

    final item = _items[itemIndex];
    final nuevaCantidad = item.cantidad + 1;
    if (item.stockDisponible < nuevaCantidad) return false;

    _items[itemIndex] = CartItem(
      id: item.id,
      producto: item.producto,
      cantidad: nuevaCantidad,
      addedAt: item.addedAt,
      varianteId: item.varianteId,
      varianteColor: item.varianteColor,
      varianteImagenUrl: item.varianteImagenUrl,
      precioUnitarioOverride: item.precioUnitarioOverride,
    );

    _notifyPersist();
    return true;
  }

  bool decrementarCantidad(String productoId, {String? varianteId}) {
    final lineKey = '$productoId::${varianteId ?? 'base'}';
    final itemIndex = _items.indexWhere((item) =>
        item.lineKey == lineKey ||
        (varianteId == null && item.producto.id == productoId));
    if (itemIndex == -1) return false;

    final item = _items[itemIndex];
    if (item.cantidad <= 1) {
      if (item.producto.rubro.toLowerCase() == 'viaje') {
        _pedidoViajeId = null;
      }
      _items.removeAt(itemIndex);
    } else {
      _items[itemIndex] = CartItem(
        id: item.id,
        producto: item.producto,
        cantidad: item.cantidad - 1,
        addedAt: item.addedAt,
        varianteId: item.varianteId,
        varianteColor: item.varianteColor,
        varianteImagenUrl: item.varianteImagenUrl,
        precioUnitarioOverride: item.precioUnitarioOverride,
      );
    }

    _notifyPersist();
    return true;
  }

  void setDireccionEnvio(DireccionEnvio direccion) {
    _direccionEnvio = direccion;
    notifyListeners();
  }

  void addManifiestoViaje(ManifiestoViaje manifiesto) {
    _manifiestosViaje.add(manifiesto);
    notifyListeners();
  }

  void updateManifiestoViaje(int index, ManifiestoViaje manifiesto) {
    if (index >= 0 && index < _manifiestosViaje.length) {
      _manifiestosViaje[index] = manifiesto;
      notifyListeners();
    }
  }

  void removeManifiestoViaje(int index) {
    if (index >= 0 && index < _manifiestosViaje.length) {
      _manifiestosViaje.removeAt(index);
      notifyListeners();
    }
  }

  void clearManifiestosViaje() {
    _manifiestosViaje.clear();
    notifyListeners();
  }

  bool get datosEnvioValidos {
    if (!tieneItemsTienda) return true;
    return _direccionEnvio?.isValid == true;
  }

  bool get manifiestosValidos {
    if (!tieneItemsViaje) return true;
    if (_manifiestosViaje.isEmpty) return false;
    return _manifiestosViaje.every((m) => m.isValidConFoto);
  }

  bool get puedeProcederAlPago {
    return _items.isNotEmpty && datosEnvioValidos && manifiestosValidos;
  }

  void vaciarCarrito() {
    _items.clear();
    _direccionEnvio = null;
    _manifiestosViaje.clear();
    _pedidoViajeId = null;
    CartPersistenceService.limpiar();
    notifyListeners();
  }

  List<CartItem> get itemsSinStock {
    return _items.where((item) => !item.hasStock).toList();
  }

  void actualizarStockProducto(String productoId, int nuevoStock) {
    for (int i = 0; i < _items.length; i++) {
      if (_items[i].producto.id == productoId) {
        final item = _items[i];
        final productoActualizado = Producto(
          id: item.producto.id,
          nombre: item.producto.nombre,
          descripcion: item.producto.descripcion,
          precio: item.producto.precio,
          stock: nuevoStock,
          rubro: item.producto.rubro,
          categoriaId: item.producto.categoriaId,
          imagenUrl: item.producto.imagenUrl,
          activo: item.producto.activo,
          createdAt: item.producto.createdAt,
          updatedAt: DateTime.now(),
          rubroId: item.producto.rubroId,
        );

        final cantidadAjustada =
            nuevoStock < item.cantidad ? nuevoStock : item.cantidad;

        _items[i] = CartItem(
          id: item.id,
          producto: productoActualizado,
          cantidad: cantidadAjustada,
          addedAt: item.addedAt,
        );

        if (nuevoStock == 0) {
          _items.removeAt(i);
        }
        _notifyPersist();
        break;
      }
    }
  }

  Map<String, dynamic> get resumenCheckout {
    return {
      'items': _items
          .map((item) => {
                'producto_id': item.producto.id,
                'nombre': item.nombreProducto,
                'cantidad': item.cantidad,
                'precio_unitario': item.precioUnitario,
                'subtotal': item.subtotal,
                'variante_id': item.varianteId,
                'variante_label': item.varianteColor,
              })
          .toList(),
      'total_items': totalItems,
      'total_carrito': totalCarrito,
      'items_sin_stock': itemsSinStock.length,
    };
  }
}
