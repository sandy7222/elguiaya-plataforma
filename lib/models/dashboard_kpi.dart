

import 'package:flutter/material.dart';

class DashboardKPI {
  final String titulo;
  final String valor;
  final String descripcion;
  final IconData icono;
  final Color color;
  final String tendencia; // 'up', 'down', 'stable'
  final double porcentajeCambio;

  DashboardKPI({
    required this.titulo,
    required this.valor,
    required this.descripcion,
    required this.icono,
    required this.color,
    this.tendencia = 'stable',
    this.porcentajeCambio = 0.0,
  });

  DashboardKPI copyWith({
    String? titulo,
    String? valor,
    String? descripcion,
    IconData? icono,
    Color? color,
    String? tendencia,
    double? porcentajeCambio,
  }) {
    return DashboardKPI(
      titulo: titulo ?? this.titulo,
      valor: valor ?? this.valor,
      descripcion: descripcion ?? this.descripcion,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      tendencia: tendencia ?? this.tendencia,
      porcentajeCambio: porcentajeCambio ?? this.porcentajeCambio,
    );
  }
}

class KPIData {
  final String titulo;
  final double valor;
  final String unidad;
  final IconData icono;
  final Color color;
  final String descripcion;
  final double porcentajeCambio;

  KPIData({
    required this.titulo,
    required this.valor,
    required this.unidad,
    required this.icono,
    required this.color,
    this.descripcion = '',
    this.porcentajeCambio = 0.0,
  });

  KPIData copyWith({
    String? titulo,
    double? valor,
    String? unidad,
    IconData? icono,
    Color? color,
    String? descripcion,
    double? porcentajeCambio,
  }) {
    return KPIData(
      titulo: titulo ?? this.titulo,
      valor: valor ?? this.valor,
      unidad: unidad ?? this.unidad,
      icono: icono ?? this.icono,
      color: color ?? this.color,
      descripcion: descripcion ?? this.descripcion,
      porcentajeCambio: porcentajeCambio ?? this.porcentajeCambio,
    );
  }

  // Modulo Nautico
  static KPIData viajesHoy = KPIData(
    titulo: 'Viajes Hoy',
    valor: 0,
    unidad: '',
    icono: Icons.sailing,
    color: Colors.blue,
  );

  static KPIData documentosPendientes = KPIData(
    titulo: 'Documentos Pendientes',
    valor: 0,
    unidad: '',
    icono: Icons.pending_actions,
    color: Colors.orange,
  );

  static KPIData capitanesActivos = KPIData(
    titulo: 'Capitanes Activos',
    valor: 0,
    unidad: '',
    icono: Icons.anchor,
    color: Colors.green,
  );

  static KPIData invitadosHoy = KPIData(
    titulo: 'Invitados Hoy',
    valor: 0,
    unidad: '',
    icono: Icons.group,
    color: Colors.purple,
  );

  // Modulo E-Commerce
  static KPIData ventasSemana = KPIData(
    titulo: 'Ventas Semana',
    valor: 0,
    unidad: '\$',
    icono: Icons.shopping_cart,
    color: Colors.green,
  );

  static KPIData pedidosPendientes = KPIData(
    titulo: 'Pedidos Pendientes',
    valor: 0,
    unidad: '',
    icono: Icons.inventory,
    color: Colors.orange,
  );

  static KPIData ticketsEnvio = KPIData(
    titulo: 'Tickets Envio',
    valor: 0,
    unidad: '',
    icono: Icons.local_shipping,
    color: Colors.blue,
  );

  static KPIData productosStock = KPIData(
    titulo: 'Stock Bajo',
    valor: 0,
    unidad: '',
    icono: Icons.warning,
    color: Colors.red,
  );

  // Generales
  static KPIData usuariosTotales = KPIData(
    titulo: 'Usuarios Totales',
    valor: 0,
    unidad: '',
    icono: Icons.people,
    color: Colors.indigo,
  );

  static KPIData ingresosMes = KPIData(
    titulo: 'Ingresos Mes',
    valor: 0,
    unidad: '\$',
    icono: Icons.attach_money,
    color: Colors.green,
  );
}

class KPIUpdateResult {
  final bool exito;
  final String? error;
  final Map<String, dynamic>? datos;

  KPIUpdateResult({required this.exito, this.error, this.datos});
}
