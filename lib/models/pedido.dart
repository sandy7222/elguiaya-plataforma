

import '../models/pedido_item.dart';

class Pedido {
  final String id;
  final String usuarioId;
  final double total;
  final String estado;
  final String estadoEnvio;
  final String direccionEnvio;
  final String notas;
  final String? ticketEnvioUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<PedidoItem>? items;

  Pedido({
    required this.id,
    required this.usuarioId,
    required this.total,
    required this.estado,
    required this.estadoEnvio,
    required this.direccionEnvio,
    required this.notas,
    this.ticketEnvioUrl,
    required this.createdAt,
    required this.updatedAt,
    this.items,
  });

  // Constructor para crear desde Supabase
  factory Pedido.fromSupabase(Map<String, dynamic> data) {
    return Pedido(
      id: data['id']?.toString() ?? '',
      usuarioId: data['usuario_id']?.toString() ?? '',
      total: (data['total'] as num?)?.toDouble() ?? 0.0,
      estado: data['estado']?.toString() ?? 'pendiente',
      estadoEnvio: data['estado_envio']?.toString() ?? 'preparando',
      direccionEnvio: data['direccion_envio']?.toString() ?? '',
      notas: data['notas']?.toString() ?? '',
      ticketEnvioUrl: data['ticket_envio_url']?.toString(),
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
      items: data['pedido_items'] != null 
          ? (data['pedido_items'] as List).map((item) => PedidoItem.fromSupabase(item)).toList()
          : null,
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'total': total,
      'estado': estado,
      'estado_envio': estadoEnvio,
      'direccion_envio': direccionEnvio,
      'notas': notas,
      'ticket_envio_url': ticketEnvioUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Map para insertar (sin id y timestamps)
  Map<String, dynamic> toInsertMap() {
    return {
      'usuario_id': usuarioId,
      'total': total,
      'estado': estado,
      'estado_envio': estadoEnvio,
      'direccion_envio': direccionEnvio,
      'notas': notas,
      'ticket_envio_url': ticketEnvioUrl,
    };
  }

  // Estados permitidos
  static const String ESTADO_PENDIENTE = 'pendiente';
  static const String ESTADO_CONFIRMADO = 'confirmado';
  static const String ESTADO_EN_PREPARACION = 'en_preparacion';
  static const String ESTADO_ENVIADO = 'enviado';
  static const String ESTADO_ENTREGADO = 'entregado';
  static const String ESTADO_CANCELADO = 'cancelado';

  // Estados de envio
  static const String ESTADO_ENVIO_PREPARANDO = 'preparando';
  static const String ESTADO_ENVIO_DESPACHADO = 'despachado';
  static const String ESTADO_ENVIO_ENTREGADO = 'entregado';

  // Obtener nombre legible del estado
  String get estadoNombre {
    switch (estado) {
      case ESTADO_PENDIENTE:
        return 'Pendiente';
      case ESTADO_CONFIRMADO:
        return 'Confirmado';
      case ESTADO_EN_PREPARACION:
        return 'En Preparacion';
      case ESTADO_ENVIADO:
        return 'Enviado';
      case ESTADO_ENTREGADO:
        return 'Entregado';
      case ESTADO_CANCELADO:
        return 'Cancelado';
      default:
        return 'Desconocido';
    }
  }

  // Obtener nombre legible del estado de envio
  String get estadoEnvioNombre {
    switch (estadoEnvio) {
      case ESTADO_ENVIO_PREPARANDO:
        return 'Preparando';
      case ESTADO_ENVIO_DESPACHADO:
        return 'Despachado';
      case ESTADO_ENVIO_ENTREGADO:
        return 'Entregado';
      default:
        return 'Preparando';
    }
  }

  // Obtener color del estado
  String get estadoColor {
    switch (estado) {
      case ESTADO_PENDIENTE:
        return 'orange';
      case ESTADO_CONFIRMADO:
        return 'blue';
      case ESTADO_EN_PREPARACION:
        return 'purple';
      case ESTADO_ENVIADO:
        return 'indigo';
      case ESTADO_ENTREGADO:
        return 'green';
      case ESTADO_CANCELADO:
        return 'red';
      default:
        return 'grey';
    }
  }

  // Obtener color del estado de envio
  String get estadoEnvioColor {
    switch (estadoEnvio) {
      case ESTADO_ENVIO_PREPARANDO:
        return 'orange';
      case ESTADO_ENVIO_DESPACHADO:
        return 'blue';
      case ESTADO_ENVIO_ENTREGADO:
        return 'green';
      default:
        return 'orange';
    }
  }

  // Obtener total formateado
  String get totalFormateado {
    return '\$${total.toStringAsFixed(2)}';
  }

  // Verificar si el pedido puede ser cancelado
  bool get puedeCancelarse {
    return estado == ESTADO_PENDIENTE || estado == ESTADO_CONFIRMADO;
  }

  // Verificar si el pedido esta en proceso
  bool get estaEnProceso {
    return estado == ESTADO_CONFIRMADO || 
           estado == ESTADO_EN_PREPARACION || 
           estado == ESTADO_ENVIADO;
  }

  // Verificar si el pedido esta completado
  bool get estaCompletado {
    return estado == ESTADO_ENTREGADO;
  }

  // Verificar si tiene ticket de envio
  bool get tieneTicketEnvio {
    return ticketEnvioUrl != null && ticketEnvioUrl!.isNotEmpty;
  }
}
