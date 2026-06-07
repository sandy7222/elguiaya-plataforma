
import 'package:flutter/material.dart';

class Notificacion {
  final String id;
  final String usuarioId;
  final String titulo;
  final String mensaje;
  final DateTime fecha;
  final bool leida;
  final String tipo; // 'oferta', 'viaje', 'mensaje', 'promo', 'clima'
  final Map<String, dynamic>? metadata;

  Notificacion({
    required this.id,
    required this.usuarioId,
    required this.titulo,
    required this.mensaje,
    required this.fecha,
    required this.leida,
    required this.tipo,
    this.metadata,
  });

  factory Notificacion.fromSupabase(Map<String, dynamic> data) {
    return Notificacion(
      id: data['id']?.toString() ?? '',
      usuarioId: data['usuario_id']?.toString() ?? '',
      titulo: data['titulo'] ?? '',
      mensaje: data['mensaje'] ?? '',
      fecha: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      leida: data['leida'] ?? false,
      tipo: data['tipo'] ?? 'mensaje',
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'usuario_id': usuarioId,
      'titulo': titulo,
      'mensaje': mensaje,
      'tipo': tipo,
      'leida': leida,
      'metadata': metadata,
    };
  }

  IconData get icon {
    switch (tipo) {
      case 'oferta':
        return Icons.local_offer_outlined;
      case 'viaje':
        return Icons.directions_boat_outlined;
      case 'mensaje':
        return Icons.chat_bubble_outline;
      case 'promo':
        return Icons.star_outline;
      case 'clima':
        return Icons.wb_sunny_outlined;
      default:
        return Icons.notifications_none_outlined;
    }
  }

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(fecha);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${fecha.day}/${fecha.month}';
    }
  }
}
