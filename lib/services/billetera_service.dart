

import 'dart:math';

import 'cotizaciones_service.dart';

class BilleteraService {
  // Estados de pagos diferidos
  static const List<String> estadosPagos = ['pendiente', 'procesando', 'completado', 'fallido'];
  
  // Datos simulados de pagos diferidos (en produccion vendrian de Supabase)
  static final List<Map<String, dynamic>> _pagosDiferidos = [
    {
      'id': 'pago-001',
      'capitan_id': 'capitan-001',
      'cotizacion_id': 'cot-003',
      'pescador_id': 'pescador-003',
      'concepto': 'Cuota 1/3 - Viaje Mar del Plata',
      'monto': 21666.67,
      'moneda': 'ARS',
      'fecha_vencimiento': '2024-06-10T00:00:00Z',
      'status': 'pendiente',
      'fecha_pago': null,
      'metodo_pago': 'transferencia',
      'comprobante': null,
      'created_at': '2024-05-15T10:30:00Z',
      'updated_at': '2024-05-15T10:30:00Z',
    },
    {
      'id': 'pago-002',
      'capitan_id': 'capitan-001',
      'cotizacion_id': 'cot-002',
      'pescador_id': 'pescador-002',
      'concepto': 'Cuota 1/2 - Viaje San Clemente',
      'monto': 60000.00,
      'moneda': 'ARS',
      'fecha_vencimiento': '2024-06-20T00:00:00Z',
      'status': 'procesando',
      'fecha_pago': null,
      'metodo_pago': 'mercado_pago',
      'comprobante': null,
      'created_at': '2024-05-14T14:20:00Z',
      'updated_at': '2024-05-16T09:15:00Z',
    },
    {
      'id': 'pago-003',
      'capitan_id': 'capitan-001',
      'cotizacion_id': 'cot-001',
      'pescador_id': 'pescador-001',
      'concepto': 'Cuota 2/3 - Viaje Puerto Piramides',
      'monto': 28333.33,
      'moneda': 'ARS',
      'fecha_vencimiento': '2024-07-15T00:00:00Z',
      'status': 'completado',
      'fecha_pago': '2024-06-01T14:30:00Z',
      'metodo_pago': 'efectivo',
      'comprobante': 'REC-001',
      'created_at': '2024-05-15T10:30:00Z',
      'updated_at': '2024-06-01T14:30:00Z',
    },
  ];
  
  // Funcion para obtener pagos diferidos del capitan
  static List<Map<String, dynamic>> obtenerPagosDiferidos({
    String? capitanId = 'capitan-001',
    String? estado,
  }) {
    var pagosFiltrados = _pagosDiferidos.where((pago) {
      // Filtrar por capitan si se especifica
      if (capitanId != null && pago['capitan_id'] != capitanId) {
        return false;
      }
      
      // Filtrar por estado si se especifica
      if (estado != null && pago['status'] != estado) {
        return false;
      }
      
      return true;
    }).toList();
    
    // Ordenar por fecha de vencimiento (mas urgentes primero)
    pagosFiltrados.sort((a, b) {
      final fechaA = DateTime.parse(a['fecha_vencimiento']);
      final fechaB = DateTime.parse(b['fecha_vencimiento']);
      return fechaA.compareTo(fechaB);
    });
    
    return pagosFiltrados;
  }
  
  // Funcion para crear nuevo pago diferido
  static Future<Map<String, dynamic>> crearPagoDiferido({
    required String capitanId,
    required String cotizacionId,
    required String pescadorId,
    required String concepto,
    required double monto,
    required String fechaVencimiento,
    int cuotas = 1,
    int cuotaActual = 1,
  }) async {
    // Simular llamada a Supabase
    await Future.delayed(const Duration(milliseconds: 500));
    
    final nuevoPago = {
      'id': 'pago-${Random().nextInt(1000).toString().padLeft(3, '0')}',
      'capitan_id': capitanId,
      'cotizacion_id': cotizacionId,
      'pescador_id': pescadorId,
      'concepto': concepto,
      'monto': monto,
      'moneda': 'ARS',
      'fecha_vencimiento': fechaVencimiento,
      'status': 'pendiente',
      'fecha_pago': null,
      'metodo_pago': 'transferencia',
      'comprobante': null,
      'cuotas': cuotas,
      'cuota_actual': cuotaActual,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    _pagosDiferidos.add(nuevoPago);
    
    print('✅ Nuevo pago diferido creado: ${nuevoPago['id']}');
    
    return {
      'success': true,
      'pago': nuevoPago,
    };
  }
  
  // Funcion para procesar pago de cotizacion aceptada
  static Future<Map<String, dynamic>> procesarPagoCotizacion({
    required String cotizacionId,
    required String metodoPago,
    String? comprobante,
  }) async {
    // Buscar cotizacion
    final cotizacion = await CotizacionesService.obtenerCotizacionPorId(cotizacionId);
    
    if (cotizacion == null) {
      return {
        'success': false,
        'error': 'Cotización no encontrada',
      };
    }
    
    // Simular llamada a Supabase
    await Future.delayed(const Duration(milliseconds: 800));
    
    // Crear pagos diferidos segun el monto total (presupuesto_monto en Supabase)
    final double montoTotal = (cotizacion['presupuesto_monto'] ?? cotizacion['monto_total'] ?? 0.0).toDouble();
    final String capitanId = cotizacion['capitan_id'] ?? 'capitan-001';
    final String pescadorId = cotizacion['pescador_id'] ?? 'pescador-001';
    final String titulo = cotizacion['observaciones'] ?? cotizacion['descripcion'] ?? 'Solicitud de Viaje';
    
    final pagosCreados = <Map<String, dynamic>>[];
    
    // Logica de cuotas segun el monto
    if (montoTotal <= 30000) {
      // Pago en una sola cuota
      final pago = await crearPagoDiferido(
        capitanId: capitanId,
        cotizacionId: cotizacionId,
        pescadorId: pescadorId,
        concepto: 'Pago completo - $titulo',
        monto: montoTotal,
        fechaVencimiento: DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      );
      pagosCreados.add(pago['pago']);
    } else if (montoTotal <= 60000) {
      // Pago en 2 cuotas
      final montoCuota = montoTotal / 2;
      for (int i = 1; i <= 2; i++) {
        final fechaVencimiento = DateTime.now().add(Duration(days: 30 * i)).toIso8601String();
        final pago = await crearPagoDiferido(
          capitanId: capitanId,
          cotizacionId: cotizacionId,
          pescadorId: pescadorId,
          concepto: 'Cuota $i/2 - $titulo',
          monto: montoCuota,
          fechaVencimiento: fechaVencimiento,
          cuotas: 2,
          cuotaActual: i,
        );
        pagosCreados.add(pago['pago']);
      }
    } else {
      // Pago en 3 cuotas
      final montoCuota = montoTotal / 3;
      for (int i = 1; i <= 3; i++) {
        final fechaVencimiento = DateTime.now().add(Duration(days: 30 * i)).toIso8601String();
        final pago = await crearPagoDiferido(
          capitanId: capitanId,
          cotizacionId: cotizacionId,
          pescadorId: pescadorId,
          concepto: 'Cuota $i/3 - $titulo',
          monto: montoCuota,
          fechaVencimiento: fechaVencimiento,
          cuotas: 3,
          cuotaActual: i,
        );
        pagosCreados.add(pago['pago']);
      }
    }
    
    print('✅ Pagos diferidos creados para cotizacion $cotizacionId: ${pagosCreados.length} cuotas');
    
    return {
      'success': true,
      'cotizacion_id': cotizacionId,
      'monto_total': montoTotal,
      'pagos_creados': pagosCreados,
      'metodo_pago': metodoPago,
      'comprobante': comprobante,
    };
  }
  
  // Funcion para actualizar estado de pago
  static Future<Map<String, dynamic>> actualizarEstadoPago({
    required String pagoId,
    required String nuevoEstado,
    String? comprobante,
    String? metodoPago,
  }) async {
    // Validar estado
    if (!estadosPagos.contains(nuevoEstado)) {
      return {
        'success': false,
        'error': 'Estado no valido',
        'estados_permitidos': estadosPagos,
      };
    }
    
    // Buscar pago
    final pagoIndex = _pagosDiferidos.indexWhere((pago) => pago['id'] == pagoId);
    if (pagoIndex == -1) {
      return {
        'success': false,
        'error': 'Pago no encontrado',
      };
    }
    
    // Actualizar pago
    final pago = _pagosDiferidos[pagoIndex];
    final estadoAnterior = pago['status'];
    
    _pagosDiferidos[pagoIndex] = {
      ...pago,
      'status': nuevoEstado,
      'updated_at': DateTime.now().toIso8601String(),
    };
    
    // Si es completado, actualizar fecha de pago y comprobante
    if (nuevoEstado == 'completado') {
      _pagosDiferidos[pagoIndex]['fecha_pago'] = DateTime.now().toIso8601String();
      if (comprobante != null) {
        _pagosDiferidos[pagoIndex]['comprobante'] = comprobante;
      }
    }
    
    // Si se especifica metodo de pago
    if (metodoPago != null) {
      _pagosDiferidos[pagoIndex]['metodo_pago'] = metodoPago;
    }
    
    print('✅ Pago $pagoId actualizado: $estadoAnterior → $nuevoEstado');
    
    return {
      'success': true,
      'pago_id': pagoId,
      'estado_anterior': estadoAnterior,
      'estado_nuevo': nuevoEstado,
      'fecha_actualizacion': DateTime.now().toIso8601String(),
    };
  }
  
  // Funcion para obtener estadisticas de pagos
  static Map<String, dynamic> obtenerEstadisticasPagos({
    String? capitanId = 'capitan-001',
  }) {
    final pagosCapitan = obtenerPagosDiferidos(capitanId: capitanId);
    
    final pendientes = pagosCapitan.where((pago) => pago['status'] == 'pendiente').length;
    final procesando = pagosCapitan.where((pago) => pago['status'] == 'procesando').length;
    final completados = pagosCapitan.where((pago) => pago['status'] == 'completado').length;
    final fallidos = pagosCapitan.where((pago) => pago['status'] == 'fallido').length;
    
    final montoTotalPendientes = pagosCapitan
        .where((pago) => pago['status'] == 'pendiente')
        .fold<double>(0, (sum, pago) => sum + (pago['monto'] as double));
    
    final montoTotalCompletados = pagosCapitan
        .where((pago) => pago['status'] == 'completado')
        .fold<double>(0, (sum, pago) => sum + (pago['monto'] as double));
    
    // Calcular proximo vencimiento
    DateTime? proximoVencimiento;
    double? montoProximoVencimiento;
    
    final pagosPendientesList = pagosCapitan.where((pago) => pago['status'] == 'pendiente').toList();
    if (pagosPendientesList.isNotEmpty) {
      pagosPendientesList.sort((a, b) {
        final fechaA = DateTime.parse(a['fecha_vencimiento']);
        final fechaB = DateTime.parse(b['fecha_vencimiento']);
        return fechaA.compareTo(fechaB);
      });
      
      proximoVencimiento = DateTime.parse(pagosPendientesList.first['fecha_vencimiento']);
      montoProximoVencimiento = pagosPendientesList.first['monto'] as double;
    }
    
    return {
      'total_pagos': pagosCapitan.length,
      'pendientes': pendientes,
      'procesando': procesando,
      'completados': completados,
      'fallidos': fallidos,
      'monto_total_pendientes': montoTotalPendientes,
      'monto_total_completados': montoTotalCompletados,
      'proximo_vencimiento': proximoVencimiento?.toIso8601String(),
      'monto_proximo_vencimiento': montoProximoVencimiento,
      'dias_proximo_vencimiento': proximoVencimiento != null 
          ? DateTime.now().difference(proximoVencimiento).inDays 
          : null,
    };
  }
  
  // Funcion para verificar vencimientos
  static Future<Map<String, dynamic>> verificarVencimientos() async {
    final ahora = DateTime.now();
    List<Map<String, dynamic>> pagosVencidos = [];
    List<Map<String, dynamic>> pagosPorVencer = [];
    
    for (final pago in _pagosDiferidos) {
      if (pago['status'] == 'pendiente') {
        final fechaVencimiento = DateTime.parse(pago['fecha_vencimiento']);
        final diasParaVencimiento = fechaVencimiento.difference(ahora).inDays;
        
        if (diasParaVencimiento < 0) {
          pagosVencidos.add(pago);
        } else if (diasParaVencimiento <= 3) {
          pagosPorVencer.add(pago);
        }
      }
    }
    
    return {
      'vencidos': pagosVencidos,
      'por_vencer': pagosPorVencer,
      'total_vencidos': pagosVencidos.length,
      'total_por_vencer': pagosPorVencer.length,
      'monto_total_vencidos': pagosVencidos.fold<double>(0, (sum, pago) => sum + (pago['monto'] as double)),
      'monto_total_por_vencer': pagosPorVencer.fold<double>(0, (sum, pago) => sum + (pago['monto'] as double)),
    };
  }
  
  // Funcion para obtener resumen de pagos de una cotizacion
  static Map<String, dynamic>? obtenerResumenPagosCotizacion(String cotizacionId) {
    final pagosCotizacion = _pagosDiferidos.where((pago) => pago['cotizacion_id'] == cotizacionId).toList();
    
    if (pagosCotizacion.isEmpty) {
      return null;
    }
    
    final montoTotal = pagosCotizacion.fold<double>(0, (sum, pago) => sum + (pago['monto'] as double));
    final pagadosCompletados = pagosCotizacion.where((pago) => pago['status'] == 'completado').length;
    final pagosPendientes = pagosCotizacion.where((pago) => pago['status'] == 'pendiente').length;
    
    return {
      'cotizacion_id': cotizacionId,
      'total_cuotas': pagosCotizacion.length,
      'cuotas_completadas': pagadosCompletados,
      'cuotas_pendientes': pagosPendientes,
      'monto_total': montoTotal,
      'monto_pagado': pagosCotizacion
          .where((pago) => pago['status'] == 'completado')
          .fold<double>(0, (sum, pago) => sum + (pago['monto'] as double)),
      'monto_pendiente': pagosCotizacion
          .where((pago) => pago['status'] == 'pendiente')
          .fold<double>(0, (sum, pago) => sum + (pago['monto'] as double)),
      'progreso_pago': pagadosCompletados / pagosCotizacion.length,
      'completado': pagadosCompletados == pagosCotizacion.length,
    };
  }
  
  // Funcion para calcular proximas fechas de pago
  static List<Map<String, dynamic>> obtenerProximosPagos({
    String? capitanId = 'capitan-001',
    int limite = 5,
  }) {
    final pagosPendientes = _pagosDiferidos.where((pago) {
      if (capitanId != null && pago['capitan_id'] != capitanId) {
        return false;
      }
      return pago['status'] == 'pendiente';
    }).toList();
    
    // Ordenar por fecha de vencimiento
    pagosPendientes.sort((a, b) {
      final fechaA = DateTime.parse(a['fecha_vencimiento']);
      final fechaB = DateTime.parse(b['fecha_vencimiento']);
      return fechaA.compareTo(fechaB);
    });
    
    return pagosPendientes.take(limite).toList();
  }
  
  // Funcion para validar monto de pago
  static Map<String, dynamic> validarMontoPago(double monto) {
    if (monto <= 0) {
      return {
        'valido': false,
        'error': 'El monto debe ser mayor a cero',
      };
    }
    
    if (monto > 500000) {
      return {
        'valido': false,
        'error': 'El monto excede el limite maximo permitido',
      };
    }
    
    return {
      'valido': true,
      'monto_formateado': '\$${monto.toStringAsFixed(2)}',
    };
  }
  
  // Funcion para generar reporte de pagos
  static Map<String, dynamic> generarReportePagos({
    String? capitanId = 'capitan-001',
    required String fechaInicio,
    required String fechaFin,
  }) {
    final fechaInicioDt = DateTime.parse(fechaInicio);
    final fechaFinDt = DateTime.parse(fechaFin);
    
    final pagosFiltrados = _pagosDiferidos.where((pago) {
      if (capitanId != null && pago['capitan_id'] != capitanId) {
        return false;
      }
      
      final fechaPago = pago['fecha_pago'] != null 
          ? DateTime.parse(pago['fecha_pago'])
          : DateTime.parse(pago['fecha_vencimiento']);
      
      return fechaPago.isAfter(fechaInicioDt) && fechaPago.isBefore(fechaFinDt);
    }).toList();
    
    final totalPagos = pagosFiltrados.length;
    final montoTotal = pagosFiltrados.fold<double>(0, (sum, pago) => sum + (pago['monto'] as double));
    final pagosCompletados = pagosFiltrados.where((pago) => pago['status'] == 'completado').length;
    final montoCompletado = pagosFiltrados
        .where((pago) => pago['status'] == 'completado')
        .fold<double>(0, (sum, pago) => sum + (pago['monto'] as double));
    
    return {
      'periodo': '$fechaInicio - $fechaFin',
      'total_pagos': totalPagos,
      'pagos_completados': pagosCompletados,
      'monto_total': montoTotal,
      'monto_completado': montoCompletado,
      'tasa_completado': totalPagos > 0 ? (pagosCompletados / totalPagos * 100) : 0,
      'promedio_pago': totalPagos > 0 ? montoTotal / totalPagos : 0,
      'pagos': pagosFiltrados,
    };
  }
}
