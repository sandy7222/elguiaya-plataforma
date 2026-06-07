

import 'package:flutter/material.dart';


class CartFloatingButton extends StatelessWidget {
  final int itemCount;
  final String total;
  final VoidCallback? onTap;

  const CartFloatingButton({
    super.key,
    required this.itemCount,
    required this.total,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0) {
      return const SizedBox.shrink(); // No mostrar si el carrito esta vacio
    }

    return FloatingActionButton.extended(
      onPressed: onTap ?? () => Navigator.pushNamed(context, '/carrito'),
      backgroundColor: const Color(0xFF00C853), // Esmeralda Náutico
      foregroundColor: Colors.white,
      elevation: 8,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.shopping_cart_outlined),
          if (itemCount > 0)
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 20,
                  minHeight: 20,
                ),
                child: Text(
                  '$itemCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
      label: Text('FINALIZAR COMPRA • $total', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
    );
  }
}
