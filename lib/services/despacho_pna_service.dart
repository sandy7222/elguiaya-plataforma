import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/fecha_nacimiento_utils.dart';
import 'notificacion_helper.dart';

/// Persona listada en el despacho PNA.
class PersonaDespachoPna {
  final String nombreApellido;
  final String nacionalidad;
  final String fechaNacimiento;
  final String lugarNacimiento;
  final String documento;

  const PersonaDespachoPna({
    required this.nombreApellido,
    this.nacionalidad = 'Argentina',
    required this.fechaNacimiento,
    this.lugarNacimiento = '—',
    required this.documento,
  });
}

/// Datos completos para generar el PDF de despacho PNA.
class DespachoPnaData {
  final String pedidoId;
  final String estadoPedido;
  final String nombreEmbarcacion;
  final String nacionalidadEmbarcacion;
  final String habilitacionCapitan;
  final String nombreCapitan;
  final String emailCapitan;
  final String telefonoCapitan;
  final String fechaHoraZarpada;
  final String lugarZarpada;
  final String fechaHoraRegreso;
  final String lugarRegreso;
  final String matriculaEmbarcacion;
  final String referenciaReserva;
  final String contactoTierraNombre;
  final String contactoTierraTelefono;
  final String contactoTierraEmail;
  final List<PersonaDespachoPna> tripulantes;
  final List<PersonaDespachoPna> acompanantes;

  const DespachoPnaData({
    required this.pedidoId,
    required this.estadoPedido,
    required this.nombreEmbarcacion,
    required this.nacionalidadEmbarcacion,
    required this.habilitacionCapitan,
    required this.nombreCapitan,
    required this.emailCapitan,
    required this.telefonoCapitan,
    required this.fechaHoraZarpada,
    required this.lugarZarpada,
    required this.fechaHoraRegreso,
    required this.lugarRegreso,
    required this.matriculaEmbarcacion,
    required this.referenciaReserva,
    required this.contactoTierraNombre,
    required this.contactoTierraTelefono,
    required this.contactoTierraEmail,
    required this.tripulantes,
    required this.acompanantes,
  });
}

enum DespachoPnaElegibilidad {
  listo,
  pedidoNoEncontrado,
  viajeNoConfirmado,
  sinManifiesto,
  faltanFechasNacimiento,
}

/// Estado de la documentación PNA para avisos al capitán.
enum DespachoPnaEstadoDocumentacion {
  esperandoManifiesto,
  faltanFechasNacimiento,
  faltaDatosEmbarcacion,
  listo,
}

class DespachoPnaResumenDocumentacion {
  final DespachoPnaEstadoDocumentacion estado;
  final bool faltaDatosEmbarcacion;
  final String? nombreEmbarcacion;
  final String? matriculaEmbarcacion;
  final String capitanId;

  const DespachoPnaResumenDocumentacion({
    required this.estado,
    required this.faltaDatosEmbarcacion,
    required this.capitanId,
    this.nombreEmbarcacion,
    this.matriculaEmbarcacion,
  });
}

class DespachoPnaResultado {
  final DespachoPnaElegibilidad elegibilidad;
  final DespachoPnaData? data;
  final String mensaje;

  const DespachoPnaResultado({
    required this.elegibilidad,
    this.data,
    required this.mensaje,
  });

  bool get puedeGenerar => elegibilidad == DespachoPnaElegibilidad.listo && data != null;
}

class DespachoPnaService {
  DespachoPnaService._();

  static final _supabase = Supabase.instance.client;

  static const _estadosValidos = {
    'confirmado',
    'pagado',
    'en_curso',
    'listo_para_confirmar',
    'completado_pendiente_firma',
    'completado',
    'cerrado',
  };

  /// Consulta rápida si el despacho ya está precargado (sin armar todo el PDF).
  static Future<DespachoPnaResultado> consultarEstado(String pedidoId) =>
      cargarParaPedido(pedidoId);

  static String _formatearFechaHora(String? fechaRaw, String hora) {
    if (fechaRaw == null || fechaRaw.isEmpty) return '—';
    try {
      final d = DateTime.parse(fechaRaw).toLocal();
      return '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/'
          '${d.year} $hora';
    } catch (_) {
      return '$fechaRaw $hora';
    }
  }

  static String? _nonEmpty(String? value) {
    final t = value?.trim();
    if (t == null || t.isEmpty || t.toLowerCase() == 'null') return null;
    return t;
  }

  static String _nombreCompletoPasajero(Map<String, dynamic> p) {
    final nombre = p['nombre']?.toString() ?? p['nombre_pasajero']?.toString() ?? '';
    final apellidoRaw = p['apellido']?.toString() ?? p['apellido_pasajero']?.toString() ?? '';
    final apellido = apellidoRaw.split('(').first.trim();
    return '$nombre $apellido'.trim();
  }

  static PersonaDespachoPna _personaDesdePasajero(Map<String, dynamic> p) {
    return PersonaDespachoPna(
      nombreApellido: _nombreCompletoPasajero(p),
      documento: p['dni']?.toString() ?? p['dni_pasajero']?.toString() ?? '—',
      fechaNacimiento: FechaNacimientoUtils.formatearLegible(p['fecha_nacimiento']),
    );
  }

  static Future<DespachoPnaResultado> cargarParaPedido(String pedidoId) async {
    if (pedidoId.isEmpty) {
      return const DespachoPnaResultado(
        elegibilidad: DespachoPnaElegibilidad.pedidoNoEncontrado,
        mensaje: 'Pedido inválido.',
      );
    }

    final pedido = await _supabase
        .from('pedidos')
        .select('*')
        .eq('id', pedidoId)
        .maybeSingle();

    if (pedido == null) {
      return const DespachoPnaResultado(
        elegibilidad: DespachoPnaElegibilidad.pedidoNoEncontrado,
        mensaje: 'No se encontró el pedido.',
      );
    }

    final estado = pedido['estado']?.toString() ?? '';
    if (!_estadosValidos.contains(estado)) {
      return const DespachoPnaResultado(
        elegibilidad: DespachoPnaElegibilidad.viajeNoConfirmado,
        mensaje: 'El despacho PNA está disponible cuando el viaje está confirmado y pagado.',
      );
    }

    List<Map<String, dynamic>> pasajeros = [];
    try {
      final rows = await _supabase
          .from('viajes_invitados')
          .select('*')
          .eq('pedido_id', pedidoId)
          .order('es_titular', ascending: false);
      pasajeros = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    if (pasajeros.isEmpty) {
      return const DespachoPnaResultado(
        elegibilidad: DespachoPnaElegibilidad.sinManifiesto,
        mensaje: 'Completá la declaración de pasajeros antes de generar el despacho.',
      );
    }

    if (!FechaNacimientoUtils.todosConFecha(pasajeros)) {
      return const DespachoPnaResultado(
        elegibilidad: DespachoPnaElegibilidad.faltanFechasNacimiento,
        mensaje:
            'Completá la fecha de nacimiento de todos los pasajeros en la declaración.',
      );
    }

    final cotizacionId = pedido['cotizacion_id']?.toString() ?? '';
    Map<String, dynamic>? cotizacion;
    if (cotizacionId.isNotEmpty) {
      cotizacion = await _supabase
          .from('cotizaciones')
          .select('*')
          .eq('id', cotizacionId)
          .maybeSingle();
    }

    final capitanId = pedido['capitan_id']?.toString() ?? '';
    Map<String, dynamic> capitan = {};
    if (capitanId.isNotEmpty) {
      final profile = await _supabase
          .from('profiles')
          .select(
            'nombre, telefono, email, dni, numero_carnet, expediente, '
            'embarcacion_url, localidad, provincia, '
            'nombre_embarcacion, matricula_embarcacion, nacionalidad_embarcacion, '
            'tipo_embarcacion, puerto_base',
          )
          .eq('user_id', capitanId)
          .maybeSingle();
      if (profile != null) capitan = Map<String, dynamic>.from(profile);

      final guia = await _supabase
          .from('guias')
          .select('*')
          .eq('id', capitanId)
          .maybeSingle();
      if (guia != null) {
        guia.forEach((k, v) {
          if (v != null && (capitan[k] == null || capitan[k] == '')) {
            capitan[k] = v;
          }
        });
      }
    }

    Map<String, dynamic>? presupuesto;
    if (cotizacionId.isNotEmpty) {
      final pres = await _supabase
          .from('presupuestos')
          .select('barco_nombre, capitan_nombre, contrato_snapshot')
          .eq('cotizacion_id', cotizacionId)
          .inFilter('estado', ['aceptado', 'pagado', 'pendiente'])
          .order('created_at', ascending: false)
          .limit(1);
      if (pres.isNotEmpty) {
        presupuesto = Map<String, dynamic>.from(pres.first);
      }
    }

    final snapshot = presupuesto?['contrato_snapshot'];
    Map<String, dynamic>? embarcacionSnap;
    Map<String, dynamic>? capitanSnap;
    if (snapshot is Map) {
      final snap = Map<String, dynamic>.from(snapshot);
      if (snap['embarcacion'] is Map) {
        embarcacionSnap = Map<String, dynamic>.from(snap['embarcacion']);
      }
      if (snap['capitan'] is Map) {
        capitanSnap = Map<String, dynamic>.from(snap['capitan']);
      }
    }

    final nombreEmbarcacion = _nonEmpty(capitan['nombre_embarcacion']?.toString()) ??
        _nonEmpty(presupuesto?['barco_nombre']?.toString()) ??
        _nonEmpty(embarcacionSnap?['barco_nombre']?.toString()) ??
        _nonEmpty(embarcacionSnap?['nombre_embarcacion']?.toString()) ??
        _nonEmpty(embarcacionSnap?['nombre']?.toString()) ??
        (_nonEmpty(capitan['nombre']?.toString()) != null
            ? 'Embarcación de ${capitan['nombre']}'
            : 'Embarcación deportiva');

    final matriculaEmbarcacion = _nonEmpty(capitan['matricula_embarcacion']?.toString()) ??
        _nonEmpty(embarcacionSnap?['matricula_embarcacion']?.toString()) ??
        _nonEmpty(embarcacionSnap?['matricula']?.toString()) ??
        _nonEmpty(embarcacionSnap?['numero_matricula']?.toString()) ??
        '—';

    final nacionalidadEmbarcacion =
        _nonEmpty(capitan['nacionalidad_embarcacion']?.toString()) ??
            _nonEmpty(embarcacionSnap?['nacionalidad_embarcacion']?.toString()) ??
            'Argentina';

    final tipoEmbarcacion = _nonEmpty(capitan['tipo_embarcacion']?.toString()) ??
        _nonEmpty(embarcacionSnap?['tipo_embarcacion']?.toString());

    final nombreEmbarcacionCompleto = tipoEmbarcacion != null
        ? '$nombreEmbarcacion — $tipoEmbarcacion'
        : nombreEmbarcacion;

    final nombreCapitan = _nonEmpty(presupuesto?['capitan_nombre']?.toString()) ??
        _nonEmpty(capitanSnap?['nombre']?.toString()) ??
        _nonEmpty(capitan['nombre']?.toString()) ??
        'Capitán';

    final habilitacion = _nonEmpty(capitanSnap?['numero_carnet']?.toString()) ??
        _nonEmpty(capitan['numero_carnet']?.toString()) ??
        _nonEmpty(capitanSnap?['expediente']?.toString()) ??
        _nonEmpty(capitan['expediente']?.toString()) ??
        '—';

    final fechaIda = cotizacion?['fecha_ida']?.toString() ?? pedido['fecha_ida']?.toString();
    final fechaVuelta = cotizacion?['fecha_vuelta']?.toString() ??
        pedido['fecha_vuelta']?.toString() ??
        fechaIda;
    final hora = _nonEmpty(cotizacion?['hora_encuentro']?.toString()) ??
        _nonEmpty(pedido['hora_encuentro']?.toString()) ??
        '—';
    final lugar = _nonEmpty(cotizacion?['lugar_encuentro']?.toString()) ??
        _nonEmpty(cotizacion?['localidad_partida']?.toString()) ??
        _nonEmpty(pedido['lugar_encuentro']?.toString()) ??
        _nonEmpty(capitan['puerto_base']?.toString()) ??
        _nonEmpty(capitan['localidad']?.toString()) ??
        '—';
    final lugarRegreso = _nonEmpty(cotizacion?['lugar_encuentro']?.toString()) ??
        _nonEmpty(cotizacion?['localidad_destino']?.toString()) ??
        _nonEmpty(cotizacion?['localidad_partida']?.toString()) ??
        lugar;

    final fechaHoraZarpada = _formatearFechaHora(fechaIda, hora);
    final fechaHoraRegreso = _formatearFechaHora(fechaVuelta, hora);
    final referenciaReserva = pedidoId.length > 8
        ? pedidoId.substring(0, 8).toUpperCase()
        : pedidoId.toUpperCase();

    final titular = pasajeros.firstWhere(
      (p) => p['es_titular'] == true,
      orElse: () => pasajeros.first,
    );
    final titularNombre = _nombreCompletoPasajero(titular);
    final apellidoRaw = titular['apellido']?.toString() ?? '';
    String contactoTel = titular['telefono']?.toString() ?? '';
    String contactoEmail = '';
    final emergenciaMatch =
        RegExp(r'Emergencia:\s*([^,]+).*Email:\s*([^,]+).*Tel:\s*([^)]+)');
    final m = emergenciaMatch.firstMatch(apellidoRaw);
    if (m != null) {
      contactoTel = m.group(3)?.trim() ?? contactoTel;
      contactoEmail = m.group(2)?.trim() ?? contactoEmail;
    }

    final pescadorId = pedido['pescador_id']?.toString() ?? '';
    if (contactoEmail.isEmpty && pescadorId.isNotEmpty) {
      final perfilPescador = await _supabase
          .from('profiles')
          .select('email, telefono')
          .eq('user_id', pescadorId)
          .maybeSingle();
      contactoEmail = _nonEmpty(perfilPescador?['email']?.toString()) ?? contactoEmail;
      contactoTel = _nonEmpty(perfilPescador?['telefono']?.toString()) ?? contactoTel;
    }

    final tripulanteCapitan = PersonaDespachoPna(
      nombreApellido: nombreCapitan,
      documento: _nonEmpty(capitan['dni']?.toString()) ??
          _nonEmpty(capitanSnap?['numero_carnet']?.toString()) ??
          habilitacion,
      fechaNacimiento: '—',
    );

    final acompanantes = pasajeros.map(_personaDesdePasajero).toList();

    final data = DespachoPnaData(
      pedidoId: pedidoId,
      estadoPedido: estado,
      nombreEmbarcacion: nombreEmbarcacionCompleto,
      nacionalidadEmbarcacion: nacionalidadEmbarcacion,
      habilitacionCapitan: habilitacion,
      nombreCapitan: nombreCapitan,
      emailCapitan: _nonEmpty(capitan['email']?.toString()) ?? '—',
      telefonoCapitan: _nonEmpty(capitan['telefono']?.toString()) ?? '—',
      fechaHoraZarpada: fechaHoraZarpada,
      lugarZarpada: lugar,
      fechaHoraRegreso: fechaHoraRegreso,
      lugarRegreso: lugarRegreso,
      matriculaEmbarcacion: matriculaEmbarcacion,
      referenciaReserva: referenciaReserva,
      contactoTierraNombre: titularNombre.isNotEmpty ? titularNombre : '—',
      contactoTierraTelefono: contactoTel.isNotEmpty ? contactoTel : '—',
      contactoTierraEmail: contactoEmail.isNotEmpty ? contactoEmail : '—',
      tripulantes: [tripulanteCapitan],
      acompanantes: acompanantes,
    );

    return DespachoPnaResultado(
      elegibilidad: DespachoPnaElegibilidad.listo,
      data: data,
      mensaje:
          'Despacho PNA precargado. Solo imprimí, firmá y presentá en Prefectura.',
    );
  }

  /// Evalúa qué falta para el despacho PNA (avisos al capitán).
  static Future<DespachoPnaResumenDocumentacion?> evaluarDocumentacion(
    String pedidoId,
  ) async {
    if (pedidoId.isEmpty) return null;

    final pedido = await _supabase
        .from('pedidos')
        .select('capitan_id, estado, cotizacion_id')
        .eq('id', pedidoId)
        .maybeSingle();
    if (pedido == null) return null;

    final estadoPedido = pedido['estado']?.toString() ?? '';
    if (!_estadosValidos.contains(estadoPedido)) return null;

    final capitanId = pedido['capitan_id']?.toString() ?? '';
    if (capitanId.isEmpty) return null;

    final datosEmbarcacion =
        await _resolverDatosEmbarcacionCapitan(capitanId, pedido);
    final faltaEmbarcacion = datosEmbarcacion.nombre == null ||
        datosEmbarcacion.matricula == null;

    List<Map<String, dynamic>> pasajeros = [];
    try {
      final rows = await _supabase
          .from('viajes_invitados')
          .select('*')
          .eq('pedido_id', pedidoId)
          .order('es_titular', ascending: false);
      pasajeros = List<Map<String, dynamic>>.from(rows);
    } catch (_) {}

    if (pasajeros.isEmpty) {
      return DespachoPnaResumenDocumentacion(
        estado: DespachoPnaEstadoDocumentacion.esperandoManifiesto,
        faltaDatosEmbarcacion: faltaEmbarcacion,
        capitanId: capitanId,
        nombreEmbarcacion: datosEmbarcacion.nombre,
        matriculaEmbarcacion: datosEmbarcacion.matricula,
      );
    }

    if (!FechaNacimientoUtils.todosConFecha(pasajeros)) {
      return DespachoPnaResumenDocumentacion(
        estado: DespachoPnaEstadoDocumentacion.faltanFechasNacimiento,
        faltaDatosEmbarcacion: faltaEmbarcacion,
        capitanId: capitanId,
        nombreEmbarcacion: datosEmbarcacion.nombre,
        matriculaEmbarcacion: datosEmbarcacion.matricula,
      );
    }

    if (faltaEmbarcacion) {
      return DespachoPnaResumenDocumentacion(
        estado: DespachoPnaEstadoDocumentacion.faltaDatosEmbarcacion,
        faltaDatosEmbarcacion: true,
        capitanId: capitanId,
        nombreEmbarcacion: datosEmbarcacion.nombre,
        matriculaEmbarcacion: datosEmbarcacion.matricula,
      );
    }

    return DespachoPnaResumenDocumentacion(
      estado: DespachoPnaEstadoDocumentacion.listo,
      faltaDatosEmbarcacion: false,
      capitanId: capitanId,
      nombreEmbarcacion: datosEmbarcacion.nombre,
      matriculaEmbarcacion: datosEmbarcacion.matricula,
    );
  }

  /// Aviso al capitán tras pago confirmado o manifiesto actualizado.
  static Future<void> notificarCapitanDocumentacion({
    required String pedidoId,
    required String escenario,
  }) async {
    try {
      final resumen = await evaluarDocumentacion(pedidoId);
      if (resumen == null) return;

      final codigo = _codigoViaje(pedidoId);
      final clave = _claveNotificacion(escenario, resumen);
      final yaEnviada = await _notificacionDocumentacionYaEnviada(
        capitanId: resumen.capitanId,
        pedidoId: pedidoId,
        clave: clave,
      );
      if (yaEnviada) return;

      final copy = _copyNotificacionDocumentacion(
        escenario: escenario,
        codigo: codigo,
        resumen: resumen,
      );

      await NotificacionHelper.enviar(
        usuarioId: resumen.capitanId,
        titulo: copy.titulo,
        mensaje: copy.mensaje,
        tipo: 'viaje_despacho_pna',
        metadata: {
          'pedido_id': pedidoId,
          'escenario': escenario,
          'clave': clave,
          'estado_documentacion': resumen.estado.name,
        },
      );
    } catch (e) {
      print('⚠️ [DespachoPna] Error notificando capitán ($escenario): $e');
    }
  }

  static String _codigoViaje(String pedidoId) {
    if (pedidoId.isEmpty) return '#VJ-????';
    final limpio = pedidoId.replaceAll('-', '').toUpperCase();
    return '#VJ-${limpio.substring(0, limpio.length >= 4 ? 4 : limpio.length)}';
  }

  static String _claveNotificacion(
    String escenario,
    DespachoPnaResumenDocumentacion resumen,
  ) {
    if (escenario == 'pago_confirmado' &&
        resumen.estado == DespachoPnaEstadoDocumentacion.esperandoManifiesto &&
        resumen.faltaDatosEmbarcacion) {
      return '$escenario:pendiente_manifiesto_y_embarcacion';
    }
    return '$escenario:${resumen.estado.name}';
  }

  static Future<bool> _notificacionDocumentacionYaEnviada({
    required String capitanId,
    required String pedidoId,
    required String clave,
  }) async {
    try {
      final rows = await _supabase
          .from('notificaciones')
          .select('id')
          .eq('usuario_id', capitanId)
          .eq('tipo', 'viaje_despacho_pna')
          .eq('metadata->>pedido_id', pedidoId)
          .eq('metadata->>clave', clave)
          .limit(1);
      return rows.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static ({String titulo, String mensaje}) _copyNotificacionDocumentacion({
    required String escenario,
    required String codigo,
    required DespachoPnaResumenDocumentacion resumen,
  }) {
    final barco = resumen.nombreEmbarcacion;
    final matricula = resumen.matriculaEmbarcacion;
    final detalleBarco = barco != null && matricula != null
        ? '$barco (mat. $matricula)'
        : barco != null
            ? barco
            : null;

    switch (resumen.estado) {
      case DespachoPnaEstadoDocumentacion.esperandoManifiesto:
        if (resumen.faltaDatosEmbarcacion) {
          return (
            titulo: '📋 Reserva pagada — documentación pendiente',
            mensaje:
                'El viaje $codigo está pagado. Completá nombre y matrícula en '
                'Declaración de Servicio. El pescador aún debe cargar los pasajeros '
                'para el despacho PNA.',
          );
        }
        return (
          titulo: '📋 Reserva pagada — aguardando pasajeros',
          mensaje:
              'El viaje $codigo está pagado. Cuando el pescador cargue el manifiesto '
              'podrás generar el despacho PNA desde Viajes programados.',
        );

      case DespachoPnaEstadoDocumentacion.faltanFechasNacimiento:
        return (
          titulo: '📋 Manifiesto incompleto',
          mensaje:
              'El pescador cargó pasajeros en $codigo, pero faltan fechas de '
              'nacimiento para cerrar el despacho PNA.${resumen.faltaDatosEmbarcacion ? ' También completá nombre y matrícula de tu embarcación en Declaración de Servicio.' : ''}',
        );

      case DespachoPnaEstadoDocumentacion.faltaDatosEmbarcacion:
        return (
          titulo: '⚓ Completá datos de embarcación',
          mensaje:
              escenario == 'pago_confirmado'
                  ? 'El viaje $codigo está pagado. Completá nombre y matrícula en '
                      'Declaración de Servicio para precargar el despacho PNA.'
                  : 'Pasajeros cargados en $codigo. Completá nombre y matrícula en '
                      'Declaración de Servicio para precargar el despacho PNA.',
        );

      case DespachoPnaEstadoDocumentacion.listo:
        final detalle = detalleBarco != null ? ' ($detalleBarco)' : '';
        return (
          titulo: '✅ Despacho PNA precargado',
          mensaje:
              escenario == 'pago_confirmado'
                  ? 'El viaje $codigo está pagado y la documentación está lista$detalle. '
                      'Entrá a Viajes programados o al manifiesto para imprimir el despacho.'
                  : 'El manifiesto de $codigo está completo$detalle. '
                      'Tu despacho PNA está listo para imprimir desde Viajes programados.',
        );
    }
  }

  static Future<({String? nombre, String? matricula})> _resolverDatosEmbarcacionCapitan(
    String capitanId,
    Map<String, dynamic> pedido,
  ) async {
    Map<String, dynamic> capitan = {};
    final profile = await _supabase
        .from('profiles')
        .select('nombre_embarcacion, matricula_embarcacion, nombre')
        .eq('user_id', capitanId)
        .maybeSingle();
    if (profile != null) capitan = Map<String, dynamic>.from(profile);

    final guia = await _supabase
        .from('guias')
        .select('nombre_embarcacion, matricula_embarcacion, nombre')
        .eq('id', capitanId)
        .maybeSingle();
    if (guia != null) {
      guia.forEach((k, v) {
        if (v != null && (capitan[k] == null || capitan[k] == '')) {
          capitan[k] = v;
        }
      });
    }

    Map<String, dynamic>? embarcacionSnap;
    final cotizacionId = pedido['cotizacion_id']?.toString() ?? '';
    if (cotizacionId.isNotEmpty) {
      final pres = await _supabase
          .from('presupuestos')
          .select('barco_nombre, contrato_snapshot')
          .eq('cotizacion_id', cotizacionId)
          .inFilter('estado', ['aceptado', 'pagado', 'pendiente'])
          .order('created_at', ascending: false)
          .limit(1);
      if (pres.isNotEmpty) {
        final presupuesto = Map<String, dynamic>.from(pres.first);
        final snapshot = presupuesto['contrato_snapshot'];
        if (snapshot is Map) {
          final snap = Map<String, dynamic>.from(snapshot);
          if (snap['embarcacion'] is Map) {
            embarcacionSnap = Map<String, dynamic>.from(snap['embarcacion']);
          }
        }
        capitan['barco_nombre'] ??= presupuesto['barco_nombre'];
      }
    }

    final nombre = _nonEmpty(capitan['nombre_embarcacion']?.toString()) ??
        _nonEmpty(capitan['barco_nombre']?.toString()) ??
        _nonEmpty(embarcacionSnap?['barco_nombre']?.toString()) ??
        _nonEmpty(embarcacionSnap?['nombre_embarcacion']?.toString());
    final matricula = _nonEmpty(capitan['matricula_embarcacion']?.toString()) ??
        _nonEmpty(embarcacionSnap?['matricula_embarcacion']?.toString()) ??
        _nonEmpty(embarcacionSnap?['matricula']?.toString());

    return (nombre: nombre, matricula: matricula);
  }
}
