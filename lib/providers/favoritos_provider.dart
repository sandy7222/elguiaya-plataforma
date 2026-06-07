

import 'package:flutter/foundation.dart';

import '../models/favorito.dart';
import '../models/producto.dart';
import '../services/supabase_service.dart';

class FavoritosProvider extends ChangeNotifier {
  List<Favorito> _favoritos = [];
  final Map<String, Producto> _productosCache = {};
  bool _isLoading = false;
  String? _currentUserId;

  List<Favorito> get favoritos => List.unmodifiable(_favoritos);
  List<Producto> get productosFavoritos {
    return _favoritos
        .map((fav) => _productosCache[fav.productoId])
        .where((producto) => producto != null)
        .cast<Producto>()
        .toList();
  }
  bool get isLoading => _isLoading;
  int get totalFavoritos => _favoritos.length;

  // Verificar si un producto es favorito
  bool esFavorito(String productoId) {
    return _favoritos.any((fav) => fav.productoId == productoId);
  }

  // Inicializar con usuario actual
  Future<void> inicializar(String userId) async {
    if (_currentUserId == userId && _favoritos.isNotEmpty) {
      return; // Ya esta inicializado
    }

    _currentUserId = userId;
    await cargarFavoritos();
  }

  // Cargar favoritos del usuario
  Future<void> cargarFavoritos() async {
    if (_currentUserId == null) return;

    try {
      setState(() => _isLoading = true);

      // Cargar favoritos desde Supabase
      final favoritos = await SupabaseService.getFavoritosPorUsuario(_currentUserId!);
      
      // Cargar productos asociados
      final productoIds = favoritos.map((f) => f.productoId).toSet();
      final productos = await SupabaseService.getProductosPorIds(productoIds.toList());
      
      // Actualizar cache de productos
      _productosCache.clear();
      for (final producto in productos) {
        _productosCache[producto.id] = producto;
      }

      setState(() {
        _favoritos = favoritos;
      });
    } catch (e) {
      debugPrint('Error al cargar favoritos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Agregar producto a favoritos
  Future<bool> agregarFavorito(Producto producto) async {
    if (_currentUserId == null) return false;
    if (esFavorito(producto.id)) return true; // Ya es favorito

    try {
      setState(() => _isLoading = true);

      // Crear favorito
      final favorito = Favorito(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        usuarioId: _currentUserId!,
        productoId: producto.id,
        createdAt: DateTime.now(),
      );

      // Guardar en Supabase
      await SupabaseService.guardarFavorito(favorito);

      // Agregar a lista local
      setState(() {
        _favoritos.add(favorito);
        _productosCache[producto.id] = producto;
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al agregar favorito: $e');
      return false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Eliminar producto de favoritos
  Future<bool> eliminarFavorito(String productoId) async {
    if (_currentUserId == null) return false;

    try {
      setState(() => _isLoading = true);

      // Encontrar favorito a eliminar
      final favoritoAEliminar = _favoritos
          .where((fav) => fav.productoId == productoId)
          .firstOrNull;

      if (favoritoAEliminar == null) return false;

      // Eliminar de Supabase
      await SupabaseService.eliminarFavorito(favoritoAEliminar.id);

      // Eliminar de lista local
      setState(() {
        _favoritos.removeWhere((fav) => fav.productoId == productoId);
        _productosCache.remove(productoId);
      });

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error al eliminar favorito: $e');
      return false;
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Toggle favorito (agregar/eliminar)
  Future<bool> toggleFavorito(Producto producto) async {
    if (esFavorito(producto.id)) {
      return await eliminarFavorito(producto.id);
    } else {
      return await agregarFavorito(producto);
    }
  }

  // Vaciar todos los favoritos
  Future<void> vaciarFavoritos() async {
    if (_currentUserId == null) return;

    try {
      setState(() => _isLoading = true);

      // Eliminar todos los favoritos del usuario
      for (final favorito in _favoritos) {
        await SupabaseService.eliminarFavorito(favorito.id);
      }

      // Limpiar lista local
      setState(() {
        _favoritos.clear();
        _productosCache.clear();
      });

      notifyListeners();
    } catch (e) {
      debugPrint('Error al vaciar favoritos: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Actualizar producto en cache
  void actualizarProductoCache(Producto producto) {
    _productosCache[producto.id] = producto;
    notifyListeners();
  }

  // Obtener favoritos con stock disponible
  List<Producto> get favoritosDisponibles {
    return productosFavoritos.where((producto) => producto.activo && producto.stock > 0).toList();
  }

  // Obtener favoritos sin stock
  List<Producto> get favoritosSinStock {
    return productosFavoritos.where((producto) => !producto.activo || producto.stock == 0).toList();
  }

  // Limpiar al cerrar sesion
  void limpiar() {
    _favoritos.clear();
    _productosCache.clear();
    _currentUserId = null;
    notifyListeners();
  }

  // Metodo auxiliar para actualizar estado
  void setState(VoidCallback fn) {
    fn();
    notifyListeners();
  }
}
