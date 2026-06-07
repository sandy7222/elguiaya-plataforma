
import 'package:flutter/material.dart';
import '../models/producto_atributo.dart';

class FichaTecnicaWidget extends StatelessWidget {
  final List<ProductoAtributo> atributos;

  const FichaTecnicaWidget({super.key, required this.atributos});

  @override
  Widget build(BuildContext context) {
    if (atributos.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.terminal, size: 18, color: Color(0xFF0D47A1)),
              SizedBox(width: 10),
              Text(
                'ESPECIFICACIONES TÉCNICAS',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                  color: Color(0xFF0D47A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2.8,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: atributos.length,
            itemBuilder: (context, index) {
              final attr = atributos[index];
              return _buildSpecItem(
                attr.detalle?.nombre ?? 'Especificación',
                _decorateValue(attr.valor, attr.detalle?.nombre ?? ''),
                _getIconForAttribute(attr.detalle?.nombre ?? ''),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5)],
          ),
          child: Icon(icon, size: 16, color: const Color(0xFF0D47A1)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              Text(
                value,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _decorateValue(String value, String attributeName) {
    final v = value.toLowerCase();
    final attr = attributeName.toLowerCase();
    if (attr.contains('accion')) {
      if (v.contains('fast')) return '$value (Punta)';
      if (v.contains('medium')) return '$value (Media)';
    }
    return value;
  }

  IconData _getIconForAttribute(String name) {
    final n = name.toLowerCase();
    if (n.contains('rulemanes')) return Icons.settings;
    if (n.contains('material')) return Icons.architecture;
    if (n.contains('peso')) return Icons.scale;
    if (n.contains('largo')) return Icons.straighten;
    return Icons.info_outline;
  }
}
