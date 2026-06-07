


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/cart_provider.dart';
import '../providers/favoritos_provider.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarFavoritos();
  }

  Future<void> _cargarFavoritos() async {
    final favoritosProvider = context.read<FavoritosProvider>();
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      await favoritosProvider.inicializar(user.id);
    } else {
      await favoritosProvider.inicializar('anonimo');
    }
  }

  Future<void> _refreshFavoritos() async {
    setState(() => _isLoading = true);
    await _cargarFavoritos();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Mis Favoritos',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          Consumer<FavoritosProvider>(
            builder: (context, favoritosProvider, child) {
              if (favoritosProvider.totalFavoritos > 0) {
                return IconButton(
                  onPressed: () async {
                    final confirmar = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Vaciar Favoritos'),
                        content: const Text('¿Estas seguro que quieres eliminar todos tus favoritos?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancelar'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Vaciar'),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirmar == true) {
                      await favoritosProvider.vaciarFavoritos();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Center(child: Text('Favoritos vaciados')),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline),
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<FavoritosProvider>(
        builder: (context, favoritosProvider, child) {
          if (favoritosProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final productos = favoritosProvider.productosFavoritos;
          final productosDisponibles = favoritosProvider.favoritosDisponibles;
          final productosSinStock = favoritosProvider.favoritosSinStock;

          if (productos.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.favorite_border,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No tienes favoritos aun',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Agrega productos a tus favoritos para verlos aqui',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.shopping_bag_outlined),
                    label: const Text('Explorar Tienda'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }

          final double screenWidth = MediaQuery.of(context).size.width;
          final bool isMobile = screenWidth < 900;
          final double contentMargin = isMobile ? 0 : (screenWidth - 1200) / 2;
          final double hPadding = contentMargin > 0 ? contentMargin : 0;
          final int crossAxisCount = isMobile ? 2 : 4;
          
          final double containerWidth = isMobile ? screenWidth : (screenWidth > 1200 ? 1200 : screenWidth);
          final double gridWidth = containerWidth - 32 - (12 * (crossAxisCount - 1));
          final double cardWidth = gridWidth / crossAxisCount;
          final double cardHeight = (cardWidth / 1.3) + 125; 
          final double childAspectRatio = cardWidth / cardHeight;

          return RefreshIndicator(
            onRefresh: _refreshFavoritos,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16 + hPadding, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Contador de favoritos
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Colors.red[400],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${favoritosProvider.totalFavoritos} favorito${favoritosProvider.totalFavoritos == 1 ? '' : 's'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (productosSinStock.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${productosSinStock.length} sin stock',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Productos disponibles
                  if (productosDisponibles.isNotEmpty) ...[
                    const Text(
                      'Disponibles',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: childAspectRatio,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: productosDisponibles.length,
                      itemBuilder: (context, index) {
                        final producto = productosDisponibles[index];
                        return ProductCard(
                          producto: producto,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ProductDetailScreen(producto: producto),
                              ),
                            );
                          },
                          onAddToCart: () {
                            final cartProvider = context.read<CartProvider>();
                            final exito = cartProvider.agregarAlCarrito(producto);
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Center(
                                  child: Text(
                                    exito 
                                      ? '${producto.nombre} agregado al carrito'
                                      : 'No hay stock suficiente',
                                  ),
                                ),
                                backgroundColor: exito ? Colors.green : Colors.red,
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],

                  // Productos sin stock
                  if (productosSinStock.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Sin Stock',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: productosSinStock.length,
                      itemBuilder: (context, index) {
                        final producto = productosSinStock[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: producto.imagenUrl.isNotEmpty
                                  ? Image.network(
                                       producto.imagenUrl,
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.grey[200],
                                        child: Icon(Icons.image_not_supported, color: Colors.grey[400]),
                                      ),
                                    )
                                  : Container(
                                      width: 50,
                                      height: 50,
                                      color: Colors.grey[200],
                                      child: Icon(Icons.shopping_bag_outlined, color: Colors.grey[400]),
                                    ),
                            ),
                            title: Text(producto.nombre),
                            subtitle: Text(producto.precioFormateado),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.red[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red[200]!),
                              ),
                              child: Text(
                                'Sin stock',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
