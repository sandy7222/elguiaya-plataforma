

import 'package:flutter/material.dart';

class EstadoBadge extends StatelessWidget {
  final String estado;
  final String texto;
  final Color? color;
  final IconData? icono;

  const EstadoBadge({
    super.key,
    required this.estado,
    required this.texto,
    this.color,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? _getColorForEstado(estado);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: badgeColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(
              icono,
              size: 14,
              color: badgeColor,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: TextStyle(
              color: badgeColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColorForEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'preparando':
        return Colors.orange;
      case 'despachado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'en_preparacion':
        return Colors.purple;
      case 'enviado':
        return Colors.indigo;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

class EstadoEnvioBadge extends StatelessWidget {
  final String estadoEnvio;

  const EstadoEnvioBadge({
    super.key,
    required this.estadoEnvio,
  });

  @override
  Widget build(BuildContext context) {
    IconData? icono;
    String texto;
    
    switch (estadoEnvio.toLowerCase()) {
      case 'preparando':
        icono = Icons.inventory_2;
        texto = 'Preparando';
        break;
      case 'despachado':
        icono = Icons.local_shipping;
        texto = 'Despachado';
        break;
      case 'entregado':
        icono = Icons.check_circle;
        texto = 'Entregado';
        break;
      default:
        icono = Icons.inventory_2;
        texto = 'Preparando';
    }
    
    return EstadoBadge(
      estado: estadoEnvio,
      texto: texto,
      icono: icono,
    );
  }
}
