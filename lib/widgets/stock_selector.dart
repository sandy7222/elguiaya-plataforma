
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class StockSelector extends StatelessWidget {
  final int stock;
  final VoidCallback onContactar;

  const StockSelector({
    super.key,
    required this.stock,
    required this.onContactar,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasStock = stock > 0;
    final bool lowStock = stock > 0 && stock <= 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lowStock)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '¡ÚLTIMAS $stock UNIDADES DISPONIBLES!',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 65,
          decoration: BoxDecoration(
            boxShadow: hasStock 
              ? [BoxShadow(color: const Color(0xFF00E676).withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))]
              : null,
          ),
          child: ElevatedButton(
            onPressed: hasStock ? onContactar : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasStock ? const Color(0xFF25D366) : Colors.grey[400],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  hasStock ? FontAwesomeIcons.whatsapp : FontAwesomeIcons.circleExclamation,
                  size: 24,
                ),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasStock ? "CONTACTAR AHORA" : "AGOTADO",
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1),
                    ),
                    Text(
                      hasStock 
                        ? "Consultar con el Capitán" 
                        : "Producto sin stock por el momento",
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
