


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/producto.dart';
import '../providers/favoritos_provider.dart';

import 'hover_card_wrapper.dart';

class ProductCard extends StatelessWidget {
  final Producto producto;
  final VoidCallback onTap;
  final VoidCallback onAddToCart;

  const ProductCard({
    super.key,
    required this.producto,
    required this.onTap,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return HoverCardWrapper(
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
            // Sección superior: Imagen + Stack de Favorito
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1.3,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: producto.imagenUrl.isNotEmpty
                        ? Image.network(
                            producto.imagenUrl,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: const Color(0xFFF4F7FA),
                                child: const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFF4F7FA),
                              child: const Icon(Icons.image_not_supported, color: Colors.grey, size: 36),
                            ),
                          )
                        : Container(
                            color: const Color(0xFFF4F7FA),
                            child: const Icon(Icons.shopping_bag_outlined, color: Colors.grey, size: 36),
                          ),
                  ),
                ),
                // Botón de Favorito flotando sobre la imagen (esquina superior derecha)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Consumer<FavoritosProvider>(
                    builder: (context, favoritosProvider, child) {
                      final esFav = favoritosProvider.esFavorito(producto.id);
                      return GestureDetector(
                        onTap: () async {
                          await favoritosProvider.toggleFavorito(producto);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            esFav ? Icons.favorite : Icons.favorite_border,
                            color: esFav ? const Color(0xFFFF2D55) : Colors.grey[700],
                            size: 18,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            
            // Sección inferior: Información y Botón Agregar
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nombre del producto
                  Text(
                    producto.nombre,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  
                  // Fila de Precio y Stock (compacta para ahorrar espacio)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          producto.precioFormateado,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF00E676),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStockColor(producto.stock).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _getStockColor(producto.stock).withOpacity(0.3), width: 0.5),
                        ),
                        child: Text(
                          producto.estadoStock,
                          style: TextStyle(
                            fontSize: 9,
                            color: _getStockColor(producto.stock),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Botón de agregar al carrito (Estilo Premium)
                  SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton.icon(
                      onPressed: producto.stock > 0 ? onAddToCart : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey[200],
                        disabledForegroundColor: Colors.grey[400],
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.add_shopping_cart, size: 14),
                      label: const Text(
                        'Agregar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
   );
  }

  Color _getStockColor(int stock) {
    if (stock == 0) return Colors.red;
    if (stock < 5) return Colors.orange;
    return Colors.green;
  }
}
