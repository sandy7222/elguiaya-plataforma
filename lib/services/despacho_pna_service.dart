import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/fecha_nacimiento_utils.dart';

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
    'cerrado',
  };

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
            'embarcacion_url, localidad, provincia',
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

    final nombreEmbarcacion = _nonEmpty(presupuesto?['barco_nombre']?.toString()) ??
        _nonEmpty(embarcacionSnap?['barco_nombre']?.toString()) ??
        (_nonEmpty(capitan['nombre']?.toString()) != null
            ? 'Embarcación de ${capitan['nombre']}'
            : 'Embarcación deportiva');

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
    final hora = _nonEmpty(cotizacion?['hora_encuentro']?.toString()) ??
        _nonEmpty(pedido['hora_encuentro']?.toString()) ??
        '—';
    final lugar = _nonEmpty(cotizacion?['lugar_encuentro']?.toString()) ??
        _nonEmpty(cotizacion?['localidad_partida']?.toString()) ??
        _nonEmpty(pedido['lugar_encuentro']?.toString()) ??
        '—';

    String fechaHoraZarpada = '—';
    if (fechaIda != null) {
      try {
        final d = DateTime.parse(fechaIda).toLocal();
        fechaHoraZarpada =
            '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} $hora';
      } catch (_) {
        fechaHoraZarpada = '$fechaIda $hora';
      }
    }

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
      nombreEmbarcacion: nombreEmbarcacion,
      nacionalidadEmbarcacion: 'Argentina',
      habilitacionCapitan: habilitacion,
      nombreCapitan: nombreCapitan,
      emailCapitan: _nonEmpty(capitan['email']?.toString()) ?? '—',
      telefonoCapitan: _nonEmpty(capitan['telefono']?.toString()) ?? '—',
      fechaHoraZarpada: fechaHoraZarpada,
      lugarZarpada: lugar,
      contactoTierraNombre: titularNombre.isNotEmpty ? titularNombre : '—',
      contactoTierraTelefono: contactoTel.isNotEmpty ? contactoTel : '—',
      contactoTierraEmail: contactoEmail.isNotEmpty ? contactoEmail : '—',
      tripulantes: [tripulanteCapitan],
      acompanantes: acompanantes,
    );

    return DespachoPnaResultado(
      elegibilidad: DespachoPnaElegibilidad.listo,
      data: data,
      mensaje: 'Despacho PNA listo para generar.',
    );
  }
}
