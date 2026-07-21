import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import 'safe_product_image.dart';

class CartSheet extends StatelessWidget {
  const CartSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle del modal
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TU CARRITO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1),
              ),
              Text(
                '${cart.totalItems} ÍTEMS',
                style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          if (cart.items.isEmpty)
            _buildEmptyState()
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: cart.items.length,
                itemBuilder: (context, index) {
                  final item = cart.items[index];
                  return _buildCartItem(context, item, cart);
                },
              ),
            ),
          
          const Divider(height: 40),
          
          // Resumen de Totales
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL ESTIMADO', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(
                cart.totalFormateado,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: Color(0xFF0D47A1)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Botón de Checkout
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              onPressed: cart.items.isEmpty 
                ? null 
                : () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/carrito');
                  },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D47A1),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                shadowColor: const Color(0xFF0D47A1).withOpacity(0.4),
              ),
              child: const Text(
                'IR AL PAGO SEGURO',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.shopping_basket_outlined, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text('Tu red está vacía', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, CartItem item, CartProvider cart) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SafeProductImage(
              imagenUrl: item.imagenMostrada,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombreProducto,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.producto.rubro.toUpperCase(),
                  style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  item.precioFormateado,
                  style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.w900, fontSize: 14),
                ),
              ],
            ),
          ),
          // Controles de cantidad
          Row(
            children: [
              _buildQtyBtn(Icons.remove, () => cart.decrementarCantidad(item.producto.id, varianteId: item.varianteId)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('${item.cantidad}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              _buildQtyBtn(Icons.add, () => cart.incrementarCantidad(item.producto.id, varianteId: item.varianteId)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: Colors.black87),
      ),
    );
  }
}
