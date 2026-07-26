
import 'package:supabase_flutter/supabase_flutter.dart';

/// Resultado de una operación de facturación AFIP.
class ResultadoFactura {
  final bool exito;
  final String pedidoId;
  final String? facturaId;      // ID interno en facturas_afip
  final String? numeroCae;      // CAE asignado por AFIP (null en sandbox)
  final String? vencimientoCae; // Fecha vencimiento del CAE
  final String estado;          // 'emitida' | 'omitida' | 'error'
  final String mensaje;

  const ResultadoFactura({
    required this.exito,
    required this.pedidoId,
    this.facturaId,
    this.numeroCae,
    this.vencimientoCae,
    required this.estado,
    required this.mensaje,
  });

  @override
  String toString() =>
      'ResultadoFactura(pedidoId: $pedidoId, estado: $estado, mensaje: $mensaje)';
}

/// -----------------------------------------------------------------------------
/// AfipService  Motor de Facturación Electrónica de El Guia YA
///
/// Diseño de Interruptor Maestro:
///    Cuando `afip_facturacion_activa = false` el servicio escribe un log
///     explicativo y NO emite ninguna factura (estado de standby).
///    Cuando `afip_facturacion_activa = true` y `afip_entorno = 'sandbox'`
///     simula la generación (útil durante desarrollo/homologación).
///    Cuando `afip_facturacion_activa = true` y `afip_entorno = 'produccion'`
///     se conecta al endpoint real de AFIP con el token configurado.
///
/// Para activar en producción:
///   1. Ejecutar `sql/add_afip_facturacion.sql` en Supabase.
///   2. Ingresar el token real en `config_sistema.afip_api_token`.
///   3. Cambiar `afip_facturacion_activa` a TRUE y `afip_entorno` a 'produccion'.
/// -----------------------------------------------------------------------------
class AfipService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Endpoint de producción (reemplazar stub con cliente HTTP real)
  static const String _endpointProduccion =
      'https://serviciosjava.afip.gob.ar/wsmtxca/services/MTXCAService';

  // -- Tipo de comprobante por defecto -----------------------------------------
  static const String _tipoComprobanteDefault = 'FC_B';

  /// --------------------------------------------------------------------------
  /// Método principal: genera una factura electrónica para un pedido cerrado.
  ///
  /// Parámetros:
  ///    [pedidoId]     ID del pedido en la tabla `pedidos`.
  ///    [monto]        Monto total a facturar (con IVA si aplica).
  ///    [dniCliente]   DNI/CUIT del cliente para el comprobante.
  ///
  /// Flujo:
  ///   1. Lee la configuración AFIP desde `config_sistema`.
  ///   2. Si `afip_facturacion_activa = false` ? registra omisión y retorna.
  ///   3. Si activa ? genera el comprobante (sandbox o producción).
  ///   4. Persiste el resultado en `facturas_afip` para audit trail.
  /// --------------------------------------------------------------------------
  static Future<ResultadoFactura> generarFacturaAutomatica({
    required String pedidoId,
    required double monto,
    required String dniCliente,
  }) async {
    // -- PASO 1: Leer configuración AFIP desde Supabase ----------------------
    final Map<String, dynamic>? config = await _obtenerConfigAfip();

    final bool facturacionActiva =
        config?['afip_facturacion_activa'] as bool? ?? false;
    final String entorno =
        config?['afip_entorno']?.toString() ?? 'sandbox';
    final String? apiToken = config?['afip_api_token']?.toString();

    // -- PASO 2: Interruptor maestro  sistema en standby -------------------
    if (!facturacionActiva) {
      final mensajeOmision =
          'AFIP: Facturación inactiva. Omitiendo emisión para el pedido $pedidoId';

      // Log en consola (visible en flutter run / debugger)
      print('?? $mensajeOmision');

      // Persistir registro de omisión en audit trail
      final facturaId = await _registrarOmision(
        pedidoId: pedidoId,
        dniCliente: dniCliente,
        monto: monto,
        entorno: entorno,
        motivo: mensajeOmision,
      );

      return ResultadoFactura(
        exito: true, // Es exitoso porque el sistema funcionó como se esperaba
        pedidoId: pedidoId,
        facturaId: facturaId,
        estado: 'omitida',
        mensaje: mensajeOmision,
      );
    }

    // -- PASO 3: Facturación activa  generar comprobante -------------------
    print('?? AFIP: Iniciando emisión de factura para pedido $pedidoId '
        '| Monto: \$$monto | DNI: $dniCliente | Entorno: $entorno');

    try {
      final resultado = entorno == 'produccion'
          ? await _emitirFacturaProduccion(
              pedidoId: pedidoId,
              monto: monto,
              dniCliente: dniCliente,
              apiToken: apiToken,
            )
          : await _emitirFacturaSandbox(
              pedidoId: pedidoId,
              monto: monto,
              dniCliente: dniCliente,
            );

      // -- PASO 4: Persistir resultado en audit trail ------------------------
      final facturaId = await _persistirFactura(
        pedidoId: pedidoId,
        dniCliente: dniCliente,
        monto: monto,
        entorno: entorno,
        estado: 'emitida',
        numeroCae: resultado['cae'],
        vencimientoCae: resultado['vencimiento_cae'],
        payloadRequest: resultado['request'],
        payloadResponse: resultado['response'],
      );

      print('? AFIP: Factura emitida correctamente. CAE: ${resultado['cae']} '
          '| Vence: ${resultado['vencimiento_cae']}');

      return ResultadoFactura(
        exito: true,
        pedidoId: pedidoId,
        facturaId: facturaId,
        numeroCae: resultado['cae'],
        vencimientoCae: resultado['vencimiento_cae'],
        estado: 'emitida',
        mensaje:
            'Factura emitida. CAE: ${resultado['cae']} | Vence: ${resultado['vencimiento_cae']}',
      );
    } catch (e) {
      final errorMsg = 'AFIP: Error al emitir factura para pedido $pedidoId: $e';
      print('? $errorMsg');

      // Persistir el error para revisión posterior
      await _persistirFactura(
        pedidoId: pedidoId,
        dniCliente: dniCliente,
        monto: monto,
        entorno: entorno,
        estado: 'error',
        errorDetalle: e.toString(),
      );

      return ResultadoFactura(
        exito: false,
        pedidoId: pedidoId,
        estado: 'error',
        mensaje: errorMsg,
      );
    }
  }

  /// --------------------------------------------------------------------------
  /// Punto único de disparo de la facturación (Fase 5).
  ///
  /// Idempotente: si ya existe un comprobante emitido/omitido para el pedido no
  /// vuelve a generar. Lee el monto y el documento del cliente desde `pedidos`
  /// (con fallback al `dni` del perfil) y delega en [generarFacturaAutomatica].
  ///
  /// Es "fire-and-forget": nunca lanza; devuelve un [ResultadoFactura] con el
  /// estado resultante para poder loguearlo.
  /// --------------------------------------------------------------------------
  static Future<ResultadoFactura> generarFacturaSiCorresponde({
    required String pedidoId,
  }) async {
    if (pedidoId.isEmpty) {
      return ResultadoFactura(
        exito: false,
        pedidoId: pedidoId,
        estado: 'error',
        mensaje: 'AFIP: pedidoId vacío.',
      );
    }

    try {
      // Idempotencia: no duplicar si ya hay comprobante emitido/omitido.
      final existente = await _supabase
          .from('facturas_afip')
          .select('id, estado')
          .eq('pedido_id', pedidoId)
          .inFilter('estado', ['emitida', 'omitida'])
          .maybeSingle();

      if (existente != null) {
        return ResultadoFactura(
          exito: true,
          pedidoId: pedidoId,
          facturaId: existente['id']?.toString(),
          estado: existente['estado']?.toString() ?? 'emitida',
          mensaje: 'AFIP: comprobante ya existente, se omite duplicado.',
        );
      }

      // Datos del pedido necesarios para el comprobante.
      final pedido = await _supabase
          .from('pedidos')
          .select(
              'monto_total, total, cuit_dni_facturacion, pescador_id, usuario_id')
          .eq('id', pedidoId)
          .maybeSingle();

      if (pedido == null) {
        return ResultadoFactura(
          exito: false,
          pedidoId: pedidoId,
          estado: 'error',
          mensaje: 'AFIP: pedido $pedidoId no encontrado.',
        );
      }

      final monto = (pedido['monto_total'] as num?)?.toDouble() ??
          (pedido['total'] as num?)?.toDouble() ??
          0.0;

      String dniCliente = pedido['cuit_dni_facturacion']?.toString() ?? '';
      if (dniCliente.isEmpty) {
        final clienteId = pedido['pescador_id']?.toString() ??
            pedido['usuario_id']?.toString();
        if (clienteId != null && clienteId.isNotEmpty) {
          try {
            final perfil = await _supabase
                .from('profiles')
                .select('dni')
                .eq('user_id', clienteId)
                .maybeSingle();
            dniCliente = perfil?['dni']?.toString() ?? '';
          } catch (_) {}
        }
      }
      if (dniCliente.isEmpty) dniCliente = '0'; // consumidor final sin dato

      return await generarFacturaAutomatica(
        pedidoId: pedidoId,
        monto: monto,
        dniCliente: dniCliente,
      );
    } catch (e) {
      print('?? AFIP: generarFacturaSiCorresponde falló para $pedidoId: $e');
      return ResultadoFactura(
        exito: false,
        pedidoId: pedidoId,
        estado: 'error',
        mensaje: 'AFIP: error al evaluar facturación: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MÉTODOS PRIVADOS
  // ---------------------------------------------------------------------------

  /// Lee únicamente las columnas AFIP de config_sistema.
  static Future<Map<String, dynamic>?> _obtenerConfigAfip() async {
    try {
      return await _supabase
          .from('config_sistema')
          .select('afip_api_token, afip_facturacion_activa, afip_entorno')
          .limit(1)
          .maybeSingle();
    } catch (e) {
      print('?? AFIP: No se pudo leer config_sistema, asumiendo inactivo: $e');
      return null;
    }
  }

  /// Lee la configuración de AFIP expuesta públicamente para la UI.
  static Future<Map<String, dynamic>?> obtenerConfigAfip() async {
    return _obtenerConfigAfip();
  }

  /// Guarda la configuración de AFIP en config_sistema.
  static Future<void> guardarConfigAfip({
    required bool activa,
    required String entorno,
    required String? token,
  }) async {
    try {
      final response = await _supabase
          .from('config_sistema')
          .select('id')
          .limit(1)
          .maybeSingle();

      final data = {
        'afip_facturacion_activa': activa,
        'afip_entorno': entorno,
        'afip_api_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (response != null && response['id'] != null) {
        await _supabase
            .from('config_sistema')
            .update(data)
            .eq('id', response['id']);
      } else {
        await _supabase
            .from('config_sistema')
            .insert(data);
      }
    } catch (e) {
      print('? AFIP: Error al guardar config en config_sistema: $e');
      throw Exception('Error al guardar la configuración de AFIP: $e');
    }
  }

  /// Simula la emisión en sandbox/homologación.
  /// En producción, reemplazar por la llamada HTTP real al WS de AFIP.
  static Future<Map<String, dynamic>> _emitirFacturaSandbox({
    required String pedidoId,
    required double monto,
    required String dniCliente,
  }) async {
    // Simular latencia de red
    await Future.delayed(const Duration(milliseconds: 300));

    // CAE simulado con formato AFIP (14 dígitos)
    final caeSim = '${DateTime.now().millisecondsSinceEpoch}'.padLeft(14, '0').substring(0, 14);
    final vencimiento = DateTime.now().add(const Duration(days: 10));
    final vencStr =
        '${vencimiento.year}${vencimiento.month.toString().padLeft(2, '0')}${vencimiento.day.toString().padLeft(2, '0')}';

    final requestSim = {
      'tipo_comprobante': _tipoComprobanteDefault,
      'punto_venta': 1,
      'concepto': 2, // Servicios
      'dni_cliente': dniCliente,
      'monto_total': monto,
      'pedido_id': pedidoId,
      'fecha_comprobante':
          '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}',
    };

    final responseSim = {
      'resultado': 'A',              // A = Aprobado
      'cae': caeSim,
      'vencimiento_cae': vencStr,
      'observaciones': 'Sandbox: Comprobante simulado para desarrollo',
    };

    return {
      'cae': caeSim,
      'vencimiento_cae': vencStr,
      'request': requestSim,
      'response': responseSim,
    };
  }

  /// Conecta al endpoint real de AFIP en producción.
  /// Pendiente: reemplazar el stub con la implementación del cliente SOAP/REST.
  static Future<Map<String, dynamic>> _emitirFacturaProduccion({
    required String pedidoId,
    required double monto,
    required String dniCliente,
    String? apiToken,
  }) async {
    if (apiToken == null || apiToken.isEmpty) {
      throw Exception(
        'AFIP en modo PRODUCCIÓN pero afip_api_token no está configurado. '
        'Configure el token en el panel de administración antes de activar la facturación.',
      );
    }

    // TODO: Implementar cliente HTTP/SOAP contra el WS de AFIP.
    // Endpoint real: $_endpointProduccion
    // Autenticación: WSAA + WSFEv1 (Ticket de Acceso)
    // SDK sugerido: integración con wsfev1 o librería dart_afip cuando esté disponible.
    //
    // Stub temporal  lanza excepción para prevenir emisiones accidentales
    // hasta que el cliente real esté implementado.
    throw UnimplementedError(
      'AFIP Producción: El cliente real aún no está implementado. '
      'Integrá el SDK de AFIP y reemplazá este stub. '
      'Endpoint: $_endpointProduccion',
    );
  }

  /// Persiste un registro de omisión (facturación inactiva) en facturas_afip.
  static Future<String?> _registrarOmision({
    required String pedidoId,
    required String dniCliente,
    required double monto,
    required String entorno,
    required String motivo,
  }) async {
    return _persistirFactura(
      pedidoId: pedidoId,
      dniCliente: dniCliente,
      monto: monto,
      entorno: entorno,
      estado: 'omitida',
      motivoOmision: motivo,
    );
  }

  /// Persiste un registro en la tabla facturas_afip y retorna su ID.
  static Future<String?> _persistirFactura({
    required String pedidoId,
    required String dniCliente,
    required double monto,
    required String entorno,
    required String estado,
    String? numeroCae,
    String? vencimientoCae,
    Map<String, dynamic>? payloadRequest,
    Map<String, dynamic>? payloadResponse,
    String? errorDetalle,
    String? motivoOmision,
  }) async {
    try {
      final row = await _supabase.from('facturas_afip').insert({
        'pedido_id': pedidoId,
        'dni_cliente': dniCliente,
        'monto': monto,
        'tipo_comprobante': _tipoComprobanteDefault,
        'numero_cae': numeroCae,
        'vencimiento_cae': vencimientoCae,
        'entorno': entorno,
        'estado': estado,
        'motivo_omision': motivoOmision,
        'payload_request': payloadRequest,
        'payload_response': payloadResponse,
        'error_detalle': errorDetalle,
      }).select('id').single();

      return row['id']?.toString();
    } catch (e) {
      print('?? AFIP: No se pudo persistir el registro en facturas_afip: $e');
      return null;
    }
  }
}
