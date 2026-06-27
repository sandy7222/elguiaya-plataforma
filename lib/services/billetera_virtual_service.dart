import 'package:supabase_flutter/supabase_flutter.dart';

// ══════════════════════════════════════════════════════════════════════════════
// BILLETERA VIRTUAL DEL CAPITÁN
//
// Flujo de dinero acordado:
//   1. El pescador paga → dinero retenido por la plataforma (escrow)
//   2. Ambos cierran el viaje y se califican → el ciclo se cierra
//   3. Se crea un movimiento en saldo_pendiente (período de disputa: 48hs)
//   4. A las 48hs sin disputa → pasa automáticamente a saldo_disponible
//   5. El capitán solicita transferencia cuando quiere → procesa en 24/48hs hábiles
//
// Tablas Supabase requeridas:
//   - pedidos (estado, monto_total, capitan_id, cerrado_at)
//   - billetera_capitanes (capitan_id, saldo_disponible, saldo_pendiente, saldo_retenido)
//   - movimientos_billetera (capitan_id, pedido_id, tipo, monto, estado, disponible_desde)
//   - liquidaciones (capitan_id, monto, estado, cbu, created_at, procesado_at)
// ══════════════════════════════════════════════════════════════════════════════

class BilleteraVirtualService {
  static final _db = Supabase.instance.client;

  /// Período de retención en horas para disputas (acordado: 48hs)
  static const int horasDisputas = 48;

  /// Comisión de la plataforma (configurable)
  /// Etapa de lanzamiento: 10% (a futuro puede subir a 15%).
  static const double comisionPorcentaje = 0.10; // 10%

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 1 — Al CERRAR EL VIAJE: acreditar en saldo pendiente
  // Llamado desde ViajeLifecycleService.cerrarViaje()
  // ══════════════════════════════════════════════════════════════════════════

  /// Acredita el monto neto del viaje en el saldo_pendiente del capitán.
  /// El dinero queda retenido 48hs antes de ser disponible para retirar.
  static Future<void> acreditarPorViajeCerrado({
    required String pedidoId,
    required String capitanId,
  }) async {
    try {
      // Obtener datos del pedido
      final pedido = await _db
          .from('pedidos')
          .select('monto_total, cerrado_at, estado')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido == null) {
        print('⚠️ Billetera: pedido $pedidoId no encontrado');
        return;
      }

      if (pedido['estado'] != 'cerrado') {
        print('⚠️ Billetera: pedido $pedidoId no está cerrado (estado: ${pedido['estado']})');
        return;
      }

      final montoTotal  = (pedido['monto_total'] as num?)?.toDouble() ?? 0.0;
      final comision    = montoTotal * comisionPorcentaje;
      final montoNeto   = montoTotal - comision;
      final cerradoAt   = pedido['cerrado_at'] != null
          ? DateTime.parse(pedido['cerrado_at'].toString())
          : DateTime.now();
      final disponibleDesde = cerradoAt.add(const Duration(hours: horasDisputas));

      // Verificar si ya se procesó este pedido
      final yaExiste = await _db
          .from('movimientos_billetera')
          .select('id')
          .eq('pedido_id', pedidoId)
          .maybeSingle();

      if (yaExiste != null) {
        print('⚠️ Billetera: movimiento para pedido $pedidoId ya existe, ignorando duplicado');
        return;
      }

      // Insertar movimiento en pendiente
      await _db.from('movimientos_billetera').insert({
        'capitan_id':       capitanId,
        'pedido_id':        pedidoId,
        'tipo':             'ingreso_viaje',
        'monto_bruto':      montoTotal,
        'comision':         comision,
        'monto_neto':       montoNeto,
        'estado':           'pendiente',           // → disponible en 48hs
        'disponible_desde': disponibleDesde.toIso8601String(),
        'descripcion':      'Viaje cerrado — período de disputa ${horasDisputas}hs',
        'created_at':       DateTime.now().toIso8601String(),
      });

      // Actualizar saldo_pendiente en la billetera del capitán
      await _upsertBilletera(capitanId, deltaPendiente: montoNeto);

      print('✅ Billetera: \$${montoNeto.toStringAsFixed(0)} en pendiente para capitán $capitanId');
      print('   Disponible desde: ${disponibleDesde.toLocal()}');
    } catch (e) {
      print('❌ Billetera: error al acreditar por viaje $pedidoId: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 2 — LIBERAR PENDIENTES (cron / scheduler cada hora)
  // Mueve saldo de pendiente a disponible cuando pasaron 48hs sin disputa
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> liberarPendientesVencidos() async {
    try {
      final ahora = DateTime.now().toIso8601String();

      // Obtener movimientos pendientes cuyo período de disputa ya venció
      final pendientes = await _db
          .from('movimientos_billetera')
          .select()
          .eq('estado', 'pendiente')
          .lte('disponible_desde', ahora);

      if (pendientes is! List || pendientes.isEmpty) return;

      for (final mov in pendientes) {
        final capitanId  = mov['capitan_id']?.toString() ?? '';
        final montoNeto  = (mov['monto_neto'] as num?)?.toDouble() ?? 0.0;
        final movId      = mov['id']?.toString() ?? '';

        // Marcar movimiento como disponible
        await _db
            .from('movimientos_billetera')
            .update({
              'estado':        'disponible',
              'liberado_at':   ahora,
            })
            .eq('id', movId);

        // Transferir de pendiente → disponible en la billetera
        await _upsertBilletera(
          capitanId,
          deltaPendiente:   -montoNeto,
          deltaDisponible:   montoNeto,
        );

        print('✅ Billetera: \$${montoNeto.toStringAsFixed(0)} liberado para capitán $capitanId (movimiento $movId)');
      }

      print('📊 Billetera: ${pendientes.length} movimientos liberados');
    } catch (e) {
      print('❌ Billetera: error al liberar pendientes: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PASO 3 — EL CAPITÁN SOLICITA TRANSFERENCIA
  // ══════════════════════════════════════════════════════════════════════════

  static Future<SolicitudTransferenciaResult> solicitarTransferencia({
    required String capitanId,
    required double monto,
    required String cbu,       // CBU o CVU de 22 dígitos
    String? alias,
    String? banco,
  }) async {
    try {
      // Validar CBU/CVU
      final cbuLimpio = cbu.replaceAll(' ', '').replaceAll('-', '');
      if (cbuLimpio.length != 22 && cbuLimpio.length != 20) {
        return SolicitudTransferenciaResult.error(
            'El CBU/CVU debe tener 22 dígitos. Verificá los datos ingresados.');
      }

      // Verificar saldo disponible
      final billetera = await getBilletera(capitanId);
      final saldoDisponible = billetera['saldo_disponible'] ?? 0.0;

      if (monto > saldoDisponible) {
        return SolicitudTransferenciaResult.error(
            'Saldo insuficiente. Disponible: \$${saldoDisponible.toStringAsFixed(0)}');
      }

      if (monto < 100) {
        return SolicitudTransferenciaResult.error(
            'El monto mínimo de transferencia es \$100');
      }

      // Crear solicitud de liquidación
      final liquidacion = await _db.from('liquidaciones').insert({
        'capitan_id':  capitanId,
        'monto':       monto,
        'cbu':         cbuLimpio,
        'alias':       alias,
        'banco':       banco,
        'estado':      'solicitado',   // → procesando → completado
        'created_at':  DateTime.now().toIso8601String(),
        'descripcion': 'Transferencia solicitada por el capitán',
      }).select().single();

      // Reservar el monto (se descuenta de disponible, pasa a retenido hasta procesar)
      await _upsertBilletera(
        capitanId,
        deltaDisponible: -monto,
        deltaRetenido:    monto,
      );

      // Registrar movimiento de salida
      await _db.from('movimientos_billetera').insert({
        'capitan_id':   capitanId,
        'tipo':         'retiro_solicitado',
        'monto_bruto':  monto,
        'comision':     0.0,
        'monto_neto':   monto,
        'estado':       'procesando',
        'liquidacion_id': liquidacion['id']?.toString(),
        'descripcion':  'Transferencia a CBU ${cbuLimpio.substring(0, 4)}...${cbuLimpio.substring(cbuLimpio.length - 4)}',
        'created_at':   DateTime.now().toIso8601String(),
      });

      return SolicitudTransferenciaResult.ok(
        liquidacionId: liquidacion['id']?.toString() ?? '',
        monto:         monto,
        cbu:           cbuLimpio,
        estimacion:    '24-48 horas hábiles',
      );
    } catch (e) {
      return SolicitudTransferenciaResult.error('Error al procesar: $e');
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONSULTAS
  // ══════════════════════════════════════════════════════════════════════════

  /// Obtiene el resumen de la billetera del capitán
  static Future<Map<String, dynamic>> getBilletera(String capitanId) async {
    try {
      final result = await _db
          .from('billetera_capitanes')
          .select()
          .eq('capitan_id', capitanId)
          .maybeSingle();

      if (result == null) {
        // Billetera nueva — crear registro vacío
        await _upsertBilletera(capitanId);
        return {
          'capitan_id':       capitanId,
          'saldo_disponible': 0.0,
          'saldo_pendiente':  0.0,
          'saldo_retenido':   0.0,
          'total_cobrado':    0.0,
        };
      }

      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('⚠️ getBilletera error: $e');
      return {
        'saldo_disponible': 0.0,
        'saldo_pendiente':  0.0,
        'saldo_retenido':   0.0,
      };
    }
  }

  /// Obtiene el historial de movimientos del capitán
  static Future<List<Map<String, dynamic>>> getMovimientos({
    required String capitanId,
    int limit = 20,
    String? soloEstado,
  }) async {
    try {
      // Construir query base
      var baseQuery = _db
          .from('movimientos_billetera')
          .select('*, pedidos(cotizaciones(descripcion, fecha_ida))')
          .eq('capitan_id', capitanId);

      // Filtrar por estado si se especificó (antes del order/limit)
      final result = soloEstado != null
          ? await baseQuery
              .eq('estado', soloEstado)
              .order('created_at', ascending: false)
              .limit(limit)
          : await baseQuery
              .order('created_at', ascending: false)
              .limit(limit);

      return List<Map<String, dynamic>>.from(result as List);
    } catch (e) {
      print('⚠️ getMovimientos error: $e');
      return [];
    }
  }

  /// Cuánto tiempo falta para que el próximo pendiente sea disponible
  static Future<Duration?> tiempoHastaProximoLibre(String capitanId) async {
    try {
      final result = await _db
          .from('movimientos_billetera')
          .select('disponible_desde')
          .eq('capitan_id', capitanId)
          .eq('estado', 'pendiente')
          .order('disponible_desde', ascending: true)
          .limit(1)
          .maybeSingle();

      if (result == null) return null;
      final disponible = DateTime.tryParse(result['disponible_desde'].toString());
      if (disponible == null) return null;
      final ahora = DateTime.now();
      return disponible.isAfter(ahora) ? disponible.difference(ahora) : Duration.zero;
    } catch (_) {
      return null;
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HELPERS INTERNOS
  // ══════════════════════════════════════════════════════════════════════════

  static Future<void> _upsertBilletera(
    String capitanId, {
    double deltaPendiente  = 0,
    double deltaDisponible = 0,
    double deltaRetenido   = 0,
  }) async {
    try {
      // Obtener saldos actuales
      final actual = await _db
          .from('billetera_capitanes')
          .select('saldo_disponible, saldo_pendiente, saldo_retenido, total_cobrado')
          .eq('capitan_id', capitanId)
          .maybeSingle();

      final sdActual  = (actual?['saldo_disponible'] as num?)?.toDouble() ?? 0.0;
      final spActual  = (actual?['saldo_pendiente']  as num?)?.toDouble() ?? 0.0;
      final srActual  = (actual?['saldo_retenido']   as num?)?.toDouble() ?? 0.0;
      final tcActual  = (actual?['total_cobrado']    as num?)?.toDouble() ?? 0.0;

      final nuevoDisponible = (sdActual + deltaDisponible).clamp(0.0, double.infinity);
      final nuevoPendiente  = (spActual + deltaPendiente ).clamp(0.0, double.infinity);
      final nuevoRetenido   = (srActual + deltaRetenido  ).clamp(0.0, double.infinity);
      // total_cobrado solo crece, cuando entra dinero al disponible
      final nuevoTotal = deltaDisponible > 0 ? tcActual + deltaDisponible : tcActual;

      await _db.from('billetera_capitanes').upsert({
        'capitan_id':       capitanId,
        'saldo_disponible': nuevoDisponible,
        'saldo_pendiente':  nuevoPendiente,
        'saldo_retenido':   nuevoRetenido,
        'total_cobrado':    nuevoTotal,
        'updated_at':       DateTime.now().toIso8601String(),
      }, onConflict: 'capitan_id');
    } catch (e) {
      print('⚠️ _upsertBilletera error: $e');
    }
  }
}

// ─── Modelos resultado ─────────────────────────────────────────────────────────

class SolicitudTransferenciaResult {
  final bool exito;
  final String? errorMsg;
  final String? liquidacionId;
  final double? monto;
  final String? cbu;
  final String? estimacion;

  const SolicitudTransferenciaResult._({
    required this.exito,
    this.errorMsg,
    this.liquidacionId,
    this.monto,
    this.cbu,
    this.estimacion,
  });

  factory SolicitudTransferenciaResult.ok({
    required String liquidacionId,
    required double monto,
    required String cbu,
    required String estimacion,
  }) => SolicitudTransferenciaResult._(
    exito: true,
    liquidacionId: liquidacionId,
    monto: monto,
    cbu: cbu,
    estimacion: estimacion,
  );

  factory SolicitudTransferenciaResult.error(String msg) =>
      SolicitudTransferenciaResult._(exito: false, errorMsg: msg);
}
