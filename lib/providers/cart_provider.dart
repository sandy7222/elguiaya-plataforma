

import 'package:flutter/material.dart';

import '../models/cart_item.dart';
import '../models/direccion_envio.dart';
import '../models/manifiesto_viaje.dart';
import '../models/producto.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  DireccionEnvio? _direccionEnvio;
  final List<ManifiestoViaje> _manifiestosViaje = [];
  String? _pedidoViajeId;

  /// ID del pedido real en Supabase vinculado al viaje del carrito.
  String? get pedidoViajeId => _pedidoViajeId;

  List<CartItem> get items => List.unmodifiable(_items);

  // Deteccion de tipos de items
  List<CartItem> get itemsTienda {
    return _items.where((item) => item.producto.rubro.toLowerCase() != 'viaje').toList();
  }

  List<CartItem> get itemsViaje {
    return _items.where((item) => item.producto.rubro.toLowerCase() == 'viaje').toList();
  }

  // Verificar si hay items de cada tipo
  bool get tieneItemsTienda => itemsTienda.isNotEmpty;
  bool get tieneItemsViaje => itemsViaje.isNotEmpty;

  // Datos de envio y manifiestos
  DireccionEnvio? get direccionEnvio => _direccionEnvio;
  List<ManifiestoViaje> get manifiestosViaje => List.unmodifiable(_manifiestosViaje);

  int get totalItems {
    return _items.fold(0, (sum, item) => sum + item.cantidad);
  }

  double get totalCarrito {
    return _items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  String get totalFormateado {
    return '\$${totalCarrito.toStringAsFixed(2)}';
  }

  // Verificar si un producto esta en el carrito
  bool estaEnCarrito(String productoId) {
    return _items.any((item) => item.producto.id == productoId);
  }

  // Obtener cantidad de un producto en el carrito
  int getCantidadProducto(String productoId) {
    final item = _items.where((item) => item.producto.id == productoId).firstOrNull;
    return item?.cantidad ?? 0;
  }

  // Agregar producto al carrito
  bool agregarAlCarrito(Producto producto, {int cantidad = 1}) {
    // Verificar stock disponible
    if (producto.stock < cantidad) {
      return false; // No hay stock suficiente
    }

    // Verificar si el producto ya esta en el carrito
    final existingItemIndex = _items.indexWhere(
      (item) => item.producto.id == producto.id,
    );

    if (existingItemIndex != -1) {
      // El producto ya esta en el carrito, actualizar cantidad
      final existingItem = _items[existingItemIndex];
      final nuevaCantidad = existingItem.cantidad + cantidad;
      
      // Verificar stock total
      if (producto.stock < nuevaCantidad) {
        return false; // No hay stock suficiente para la cantidad total
      }
      
      _items[existingItemIndex] = CartItem(
        id: existingItem.id,
        producto: existingItem.producto,
        cantidad: nuevaCantidad,
        addedAt: existingItem.addedAt,
      );
    } else {
      // Agregar nuevo item al carrito
      _items.add(CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        producto: producto,
        cantidad: cantidad,
        addedAt: DateTime.now(),
      ));
    }

    notifyListeners();
    return true;
  }

  // Agregar oferta de viaje al carrito
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
    // Determinar imagenUrl: embarcacionUrl -> capitanAvatarUrl -> fallback
    String resolvedImagenUrl = 'assets/images/logo_elguiaya_white.png';
    if (embarcacionUrl != null && embarcacionUrl.trim().isNotEmpty) {
      resolvedImagenUrl = embarcacionUrl.trim();
    } else if (capitanAvatarUrl != null && capitanAvatarUrl.trim().isNotEmpty) {
      resolvedImagenUrl = capitanAvatarUrl.trim();
    }

    // Creamos un producto virtual para el viaje
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

    // Evitar duplicados del mismo viaje
    _items.removeWhere((item) => item.producto.id == productoViaje.id);

    _items.add(CartItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      producto: productoViaje,
      cantidad: 1,
      addedAt: DateTime.now(),
    ));

    notifyListeners();
  }

  // Actualizar cantidad de un producto
  bool actualizarCantidad(String productoId, int nuevaCantidad) {
    if (nuevaCantidad < 0) return false;

    final itemIndex = _items.indexWhere(
      (item) => item.producto.id == productoId,
    );

    if (itemIndex == -1) return false;

    final item = _items[itemIndex];
    
    // Verificar stock disponible
    if (item.producto.stock < nuevaCantidad) {
      return false;
    }

    if (nuevaCantidad == 0) {
      // Eliminar item si la cantidad es 0
      _items.removeAt(itemIndex);
    } else {
      // Actualizar cantidad
      _items[itemIndex] = CartItem(
        id: item.id,
        producto: item.producto,
        cantidad: nuevaCantidad,
        addedAt: item.addedAt,
      );
    }

    notifyListeners();
    return true;
  }

  // Eliminar producto del carrito
  void eliminarDelCarrito(String productoId) {
    final item = _items.where((i) => i.producto.id == productoId).firstOrNull;
    if (item != null && item.producto.rubro.toLowerCase() == 'viaje') {
      _pedidoViajeId = null;
    }
    _items.removeWhere((item) => item.producto.id == productoId);
    notifyListeners();
  }

  // Incrementar cantidad de un producto
  bool incrementarCantidad(String productoId) {
    final itemIndex = _items.indexWhere(
      (item) => item.producto.id == productoId,
    );

    if (itemIndex == -1) return false;

    final item = _items[itemIndex];
    final nuevaCantidad = item.cantidad + 1;

    // Verificar stock disponible
    if (item.producto.stock < nuevaCantidad) {
      return false;
    }

    _items[itemIndex] = CartItem(
      id: item.id,
      producto: item.producto,
      cantidad: nuevaCantidad,
      addedAt: item.addedAt,
    );

    notifyListeners();
    return true;
  }

  // Decrementar cantidad de un producto
  bool decrementarCantidad(String productoId) {
    final itemIndex = _items.indexWhere(
      (item) => item.producto.id == productoId,
    );

    if (itemIndex == -1) return false;

    final item = _items[itemIndex];
    
    if (item.cantidad <= 1) {
      // Eliminar item si la cantidad es 1 o menos
      _items.removeAt(itemIndex);
    } else {
      // Decrementar cantidad
      _items[itemIndex] = CartItem(
        id: item.id,
        producto: item.producto,
        cantidad: item.cantidad - 1,
        addedAt: item.addedAt,
      );
    }

    notifyListeners();
    return true;
  }

  // Metodos para datos de envio y manifiestos
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

  // Validacion para checkout
  bool get datosEnvioValidos {
    if (!tieneItemsTienda) return true; // No requiere validacion si no hay items de tienda
    return _direccionEnvio?.isValid == true;
  }

  bool get manifiestosValidos {
    if (!tieneItemsViaje) return true; // No requiere validacion si no hay items de viaje
    if (_manifiestosViaje.isEmpty) return false;
    return _manifiestosViaje.every((m) => m.isValidConFoto); // Requiere foto DNI
  }

  bool get puedeProcederAlPago {
    return _items.isNotEmpty && datosEnvioValidos && manifiestosValidos;
  }

  // Vaciar carrito
  void vaciarCarrito() {
    _items.clear();
    _direccionEnvio = null;
    _manifiestosViaje.clear();
    _pedidoViajeId = null;
    notifyListeners();
  }

  // Verificar si hay items sin stock
  List<CartItem> get itemsSinStock {
    return _items.where((item) => !item.hasStock).toList();
  }

  // Actualizar items con stock cambiado
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

        // Ajustar cantidad si excede el nuevo stock
        final cantidadAjustada = nuevoStock < item.cantidad ? nuevoStock : item.cantidad;

        _items[i] = CartItem(
          id: item.id,
          producto: productoActualizado,
          cantidad: cantidadAjustada,
          addedAt: item.addedAt,
        );
        
        notifyListeners();
        if (nuevoStock == 0) {
          _items.removeAt(i);
          i--; // Ajustar indice despues de remover
        }
        break;
      }
    }
  }

  // Obtener resumen para checkout
  Map<String, dynamic> get resumenCheckout {
    return {
      'items': _items.map((item) => {
        'producto_id': item.producto.id,
        'nombre': item.producto.nombre,
        'cantidad': item.cantidad,
        'precio_unitario': item.producto.precio,
        'subtotal': item.subtotal,
      }).toList(),
      'total_items': totalItems,
      'total_carrito': totalCarrito,
      'items_sin_stock': itemsSinStock.length,
    };
  }
}
