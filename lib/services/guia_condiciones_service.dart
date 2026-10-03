import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/el_guia_respuesta.dart';
import 'connectivity_bridge.dart';
import 'location_preference_service.dart';
import 'solunar_service.dart';
import 'weather_service.dart';

/// Qué dato actual pide la pregunta.
enum TipoCondicion { hora, fecha, sol, luna, solunar, clima }

/// Lector de condiciones determinista (paso 1.0b): hora, fecha, sol, luna, períodos
/// solunares y clima.
///
/// No redacta nada con una IA: LEE los datos (reloj del celular, `SolunarService`,
/// último pronóstico guardado) y los dice con plantillas fijas. Corre en el router
/// antes de la nube y nunca en una emergencia (el portón de seguridad va primero).
///
/// Reglas de seguridad de redacción:
///   · nunca "ideal" ni "seguro": solo se informan datos y, si hace falta, alertas;
///   · si la pregunta es sobre salir o navegar, o el viento es fuerte, se manda al
///     parte oficial del SMN o de Prefectura;
///   · olas solo si el proveedor las informó;
///   · sin dato vigente dice que no lo tiene; no inventa.
class GuiaCondicionesService {
  static const String prefCondiciones = 'guia_condiciones';
  static bool habilitado = true;

  static void aplicarFlags(SharedPreferences prefs) {
    habilitado = prefs.getBool(prefCondiciones) ?? habilitado;
  }

  /// Reloj de los tests del router.
  @visibleForTesting
  static DateTime Function()? ahoraParaTest;

  /// Pronóstico guardado más viejo que esto ya no sirve ("no tengo datos vigentes").
  static const Duration _vencimiento = Duration(hours: 48);

  /// Más viejo que esto se avisa ("Ojo, ese pronóstico tiene N horas").
  static const Duration _aviso = Duration(hours: 6);

  /// Más nuevo que esto no se vuelve a bajar.
  static const Duration _fresco = Duration(minutes: 30);

  static const double _kmMaximosDelLugar = 30;

  // ── Detección ──────────────────────────────────────────────────────────────

  static String _n(String texto) => texto
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static bool _r(String n, String patron) => RegExp(patron).hasMatch(n);

  // Preguntas que NO piden un dato actual sino que explican o aconsejan.
  static const String _didactico =
      r'\b(afecta|influye|influencia|sirve|que carnada|que hago|por que|que es|como se|como hago|como influye|con viento|con luna)\b';

  static TipoCondicion? detectar(String pregunta) {
    final n = _n(pregunta);
    if (n.isEmpty) return null;

    if (_r(n, r'\bque hora (es|son|tenes|tienes|marca)\b') ||
        _r(n, r'\b(decime|dime|me decis|me dices|me podes decir|dame|sabes)\b.*\bla hora\b')) {
      return TipoCondicion.hora;
    }
    if (_r(n, r'\bque (dia|fecha) es\b|\ba cuanto estamos\b|\bque dia estamos\b')) return TipoCondicion.fecha;

    if (_r(n, r'\ba que hora (sale|se pone|se oculta|nace) el sol\b') ||
        _r(n, r'\ba que hora (amanece|atardece|anochece|oscurece)\b') ||
        _r(n, r'\bhora del? (amanecer|atardecer)\b')) {
      return TipoCondicion.sol;
    }

    final cueLuna = _r(n, r'\b(hoy|esta noche|ahora|hay|tenemos|en este momento|como esta la luna)\b');
    if (_r(n, r'\ba que hora (sale|se pone) la luna\b') ||
        (_r(n, r'\bluna\b|\blunar\b') && cueLuna && !_r(n, _didactico) && !_r(n, r'\b(influ|pican?|pesca)\b'))) {
      return TipoCondicion.luna;
    }

    if (_r(n, r'\bperiodos? solunar') ||
        _r(n, r'\btabla solunar\b') ||
        (_r(n, r'\b(mejor|mejores) horas? (para )?(pescar|la pesca)\b|\ba que hora conviene pescar\b') &&
            _r(n, r'\b(hoy|ahora|esta noche)\b'))) {
      return TipoCondicion.solunar;
    }

    return _esClima(n) ? TipoCondicion.clima : null;
  }

  static bool _esClima(String n) {
    if (_r(n, _didactico)) return false;
    const fuerte = r'\bque (clima|tiempo|temperatura|viento|oleaje) (hace|hay|tenemos|esta haciendo)\b|'
        r'\bcuantos grados\b|\b(va a|ira a) llover\b|\besta lloviendo\b|\bllueve (hoy|ahora)\b|'
        r'\bcomo (esta|viene|anda|va) (el|la) (clima|tiempo|viento|oleaje|temperatura|pronostico)\b|'
        r'\b(cual|como) es el pronostico\b|\bhace (frio|calor)\b|\bhay (mucho |poco )?(viento|oleaje|olas)\b|'
        r'\b(puedo|podemos|se puede|salgo|salimos|conviene) (salir|navegar|zarpar)\b';
    if (_r(n, fuerte)) return true;
    const cond = r'\b(clima|temperatura|viento|oleaje|olas|humedad|llover|llueve|lluvia|lloviendo|pronostico|grados)\b';
    const cue = r'\b(hoy|ahora|ahorita|en este momento|esta (tarde|noche|manana)|manana|actual)\b';
    return _r(n, cond) && _r(n, cue);
  }

  // ── Respuesta ──────────────────────────────────────────────────────────────

  /// Responde una pregunta de condiciones, o devuelve null si no es una (o el
  /// flag está apagado). Los parámetros son costuras para los tests; en la app
  /// se llama solo con la pregunta.
  static Future<ElGuiaRespuesta?> responder(
    String pregunta, {
    DateTime? ahora,
    LocationDetails? lugar,
    Future<ClimaGuardado?> Function()? leerCache,
    Future<MarineWeather?> Function(LocationDetails lugar)? descargar,
    Future<SolunarInfo> Function(DateTime fecha, double lat, double lon)? solunar,
  }) async {
    if (!habilitado) return null;
    final tipo = detectar(pregunta);
    if (tipo == null) return null;
    final n = _n(pregunta);
    final reloj = ahora ?? ahoraParaTest?.call() ?? DateTime.now();

    switch (tipo) {
      case TipoCondicion.hora:
        return _ok(_textoHora(reloj), 'exito');
      case TipoCondicion.fecha:
        return _ok('Hoy es ${_textoFecha(reloj)}.', 'exito');
      case TipoCondicion.sol:
      case TipoCondicion.luna:
      case TipoCondicion.solunar:
        final donde = lugar ?? await _lugarRapido();
        final info = await (solunar ?? SolunarService.calculateSolunar)(reloj, donde.latitude, donde.longitude);
        return _ok(
          tipo == TipoCondicion.sol
              ? _textoSol(info)
              : tipo == TipoCondicion.luna
                  ? _textoLuna(info, n)
                  : _textoSolunar(info),
          'explica',
        );
      case TipoCondicion.clima:
        final donde = lugar ?? await _lugarRapido();
        final guardado = await _obtenerClima(reloj, donde, leerCache, descargar);
        return _ok(_textoClima(n, reloj, donde, guardado), 'piensaProfundo');
    }
  }

  static ElGuiaRespuesta _ok(String texto, String gif) => ElGuiaRespuesta(texto: texto, gifSugerido: gif);

  // ── Datos: lugar, caché, descarga ──────────────────────────────────────────

  static Future<LocationDetails> _lugarRapido() async {
    try {
      final guardado = await LocationPreferenceService.predefinidaSiExiste();
      if (guardado != null) return guardado;
    } catch (_) {}
    return LocationDetails(
      latitude: LocationPreferenceService.defaultLat,
      longitude: LocationPreferenceService.defaultLon,
      name: LocationPreferenceService.defaultName,
    );
  }

  static bool _cerca(ClimaGuardado g, LocationDetails l) {
    final dLat = (g.lat - l.latitude) * 111.0;
    final dLon = (g.lon - l.longitude) * 111.0 * math.cos(l.latitude * math.pi / 180);
    return math.sqrt(dLat * dLat + dLon * dLon) <= _kmMaximosDelLugar;
  }

  /// El pronóstico a usar: el guardado si es fresco; si no, intenta bajar uno nuevo
  /// (solo con señal, con tope de 5 s) y, si no se puede, vuelve al guardado.
  static Future<ClimaGuardado?> _obtenerClima(
    DateTime ahora,
    LocationDetails lugar,
    Future<ClimaGuardado?> Function()? leerCache,
    Future<MarineWeather?> Function(LocationDetails lugar)? descargar,
  ) async {
    ClimaGuardado? guardado;
    try {
      guardado = await (leerCache ?? ClimaCache.leer)();
    } catch (_) {}
    if (guardado != null && !_cerca(guardado, lugar)) guardado = null;
    if (guardado != null && ahora.difference(guardado.descargadoEn) <= _fresco) return guardado;

    try {
      final nuevo = await (descargar ?? _descargarEnLaApp)(lugar).timeout(const Duration(seconds: 5));
      if (nuevo != null && nuevo.datosDisponibles) {
        return ClimaGuardado(clima: nuevo, descargadoEn: ahora, lat: lugar.latitude, lon: lugar.longitude);
      }
    } catch (_) {}
    return guardado;
  }

  static Future<MarineWeather?> _descargarEnLaApp(LocationDetails lugar) async {
    if (!ConnectivityBridge.estaConectado) return null;
    final w = await WeatherService.fetchMarineWeather(lugar.latitude, lugar.longitude);
    return w.datosDisponibles ? w : null;
  }

  // ── Textos ─────────────────────────────────────────────────────────────────

  static String _hm(DateTime d) => '${d.hour}:${d.minute.toString().padLeft(2, '0')}';

  /// "a las 6:29", pero "a la 1:50".
  static String _alas(DateTime d) => d.hour == 1 ? 'a la ${_hm(d)}' : 'a las ${_hm(d)}';

  static String _textoHora(DateTime d) => d.hour == 1 ? 'Es la ${_hm(d)}.' : 'Son las ${_hm(d)}.';

  static const _dias = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
  static const _meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre',
    'diciembre',
  ];

  static String _textoFecha(DateTime d) => '${_dias[d.weekday - 1]} ${d.day} de ${_meses[d.month - 1]}';

  static String _textoSol(SolunarInfo i) => 'Hoy el sol sale ${_alas(i.sunrise)} y se pone ${_alas(i.sunset)}.';

  static String _textoLuna(SolunarInfo i, String n) {
    if (_r(n, r'\ba que hora (sale|se pone) la luna\b')) {
      final partes = <String>[
        if (i.moonrise != null) 'sale ${_alas(i.moonrise!)}',
        if (i.moonset != null) 'se pone ${_alas(i.moonset!)}',
      ];
      if (partes.isEmpty) return 'Hoy no tengo el horario de la luna.';
      return 'Hoy la luna ${partes.join(' y ')}.';
    }
    final pct = (i.moonIllumination * 100).round();
    final base = 'Hoy la luna está en ${i.moonPhaseName.toLowerCase()}, con $pct por ciento iluminada.';
    final horarios = <String>[
      if (i.moonrise != null) 'Sale ${_alas(i.moonrise!)}',
      if (i.moonset != null) 'se pone ${_alas(i.moonset!)}',
    ];
    return horarios.isEmpty ? base : '$base ${horarios.join(' y ')}.';
  }

  static String _textoSolunar(SolunarInfo i) {
    String rango(SolunarPeriod p) => 'de ${_hm(p.start)} a ${_hm(p.end)}';
    List<SolunarPeriod> de(PeriodType t) => (i.periods.where((p) => p.type == t).toList()
      ..sort((a, b) => a.start.compareTo(b.start)));
    final mayores = de(PeriodType.major).map(rango).join(' y ');
    final menores = de(PeriodType.minor).map(rango).join(' y ');
    final partes = <String>[
      if (mayores.isNotEmpty) 'los períodos mayores son $mayores',
      if (menores.isNotEmpty) 'los menores, $menores',
    ];
    if (partes.isEmpty) return 'Hoy no tengo los períodos de la tabla solunar.';
    return 'Según la tabla solunar de la app, hoy ${partes.join('; ')}. '
        'Es un cálculo de la luna y el sol, no es una garantía de pique.';
  }

  static const _rumbos = ['norte', 'noreste', 'este', 'sudeste', 'sur', 'suroeste', 'oeste', 'noroeste'];

  static String _rumbo(double grados) => _rumbos[(((grados % 360) + 22.5) / 45).floor() % 8];

  static String _numero(double v, [int decimales = 0]) =>
      v.toStringAsFixed(decimales).replaceAll('.', ',');

  static const String _parteOficial = 'Consultá el parte oficial del SMN o de Prefectura antes de salir.';

  static String _cuandoBajo(ClimaGuardado g, DateTime ahora) {
    final hm = 'a las ${_hm(g.descargadoEn)}';
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final dia = DateTime(g.descargadoEn.year, g.descargadoEn.month, g.descargadoEn.day);
    final dif = hoy.difference(dia).inDays;
    if (dif == 0) return hm;
    if (dif == 1) return 'ayer $hm';
    return 'el ${_dias[g.descargadoEn.weekday - 1]} $hm';
  }

  static HourlyForecast? _horaDelPronostico(ClimaGuardado g, DateTime objetivo) {
    for (final h in g.clima.pronosticoHorario) {
      if (h.hora.year == objetivo.year &&
          h.hora.month == objetivo.month &&
          h.hora.day == objetivo.day &&
          h.hora.hour == objetivo.hour) {
        return h;
      }
    }
    return null;
  }

  static String _textoClima(String n, DateTime ahora, LocationDetails lugar, ClimaGuardado? g) {
    const sinDatos = 'Con señal te lo busco; mientras tanto fijate el parte del SMN o de Prefectura.';
    if (g == null) {
      return 'No tengo datos del clima: no hay un pronóstico guardado y ahora no hay señal para bajarlo. $sinDatos';
    }
    final edad = ahora.difference(g.descargadoEn);
    if (edad > _vencimiento) {
      final dias = edad.inDays;
      return 'No tengo datos vigentes: el último pronóstico que bajé es de hace $dias días. $sinDatos';
    }

    final manana = _r(n, r'\bmanana\b') && !_r(n, r'\b(hoy|ahora)\b');
    final objetivo = manana ? ahora.add(const Duration(days: 1)) : ahora;
    final cuando = _cuandoBajo(g, ahora);
    final hora = _horaDelPronostico(g, objetivo);

    double temp, viento, rafaga, dir, ola;
    int humedad;
    if (hora != null) {
      temp = hora.temperatura;
      viento = hora.vientoKmH;
      rafaga = hora.rafagasKmH;
      dir = hora.direccionViento;
      ola = hora.alturaOlas;
      humedad = hora.humedad;
    } else if (!manana && edad <= const Duration(hours: 1)) {
      // Sin horario pero recién bajado: los valores "actuales" todavía valen.
      temp = g.clima.temperatura;
      viento = g.clima.velocidadViento;
      rafaga = viento;
      dir = g.clima.direccionViento;
      ola = g.clima.alturaOlas;
      humedad = g.clima.humedad;
    } else {
      return 'No tengo datos para ${manana ? 'mañana a esta hora' : 'esta hora'} en el pronóstico que bajé $cuando. $sinDatos';
    }

    final salir = _r(n, r'\b(salir|salgo|salimos|navegar|navego|zarpar)\b');
    final tema = _r(n, r'\b(llover|llueve|lluvia|lloviendo)\b')
        ? 'lluvia'
        : _r(n, r'\b(oleaje|olas)\b')
            ? 'olas'
            : _r(n, r'\bviento\b')
                ? 'viento'
                : _r(n, r'\b(temperatura|grados|frio|calor)\b')
                    ? 'temperatura'
                    : _r(n, r'\bhumedad\b')
                        ? 'humedad'
                        : 'general';

    final aEstaHora = manana ? 'mañana a esta hora' : 'a esta hora';
    final intro = 'Según el pronóstico que bajé $cuando, $aEstaHora';
    final vientoTxt = 'viento de ${_numero(viento)} kilómetros por hora del ${_rumbo(dir)}'
        '${rafaga > viento ? ', con ráfagas de ${_numero(rafaga)}' : ''}';
    final olasDisponibles = g.clima.olajeDisponible;

    final partes = <String>[];
    switch (tema) {
      case 'lluvia':
        partes.add('De lluvia no tengo dato: el pronóstico que bajé no la trae. Mirá el radar o el parte del SMN.');
        break;
      case 'olas':
        partes.add(olasDisponibles
            ? '$intro se esperan olas de ${_numero(ola, 1)} metros.'
            : 'No tengo dato de olas para este lugar.');
        break;
      case 'viento':
        partes.add('$intro hay $vientoTxt.');
        break;
      case 'temperatura':
        partes.add('$intro se esperan ${_numero(temp)} grados.');
        break;
      case 'humedad':
        partes.add('$intro se espera una humedad del ${_numero(humedad.toDouble())} por ciento.');
        break;
      default:
        partes.add('$intro se esperan ${_numero(temp)} grados, $vientoTxt y humedad del ${humedad.toString()} por ciento'
            '${olasDisponibles ? ', con olas de ${_numero(ola, 1)} metros' : ''}.');
    }

    if (edad > _aviso) partes.add('Ojo, ese pronóstico tiene ${edad.inHours} horas.');

    final fuerte = viento >= 28;
    final moderado = viento >= 18 && !fuerte;
    if (tema != 'lluvia' && tema != 'temperatura' && tema != 'humedad') {
      if (fuerte) partes.add('Es un viento fuerte: mucha precaución.');
      if (moderado) partes.add('Es un viento moderado a fuerte: precaución.');
    }
    if (salir || fuerte || moderado) partes.add(_parteOficial);
    return partes.join(' ');
  }

  // ── Contexto para la nube ──────────────────────────────────────────────────

  /// Las mismas condiciones, en una línea, para dárselas a Groq como contexto
  /// (reemplaza la inyección que bajaba el clima por su cuenta). La nube conversa
  /// sobre estos números; no los recalcula.
  static Future<String> resumenParaContexto({DateTime? ahora}) async {
    const sinClima =
        '[CONDICIONES REALES] Clima no disponible en este momento. No inventes ni estimes clima, viento, olas ni mareas: indicá que no hay datos y recomendá consultar el parte oficial del SMN/Prefectura.';
    try {
      final reloj = ahora ?? ahoraParaTest?.call() ?? DateTime.now();
      final lugar = await _lugarRapido();
      final g = await _obtenerClima(reloj, lugar, null, null);
      final hora = 'Hora local: ${_hm(reloj)}.';
      if (g == null || reloj.difference(g.descargadoEn) > _vencimiento) return '$sinClima $hora';
      final h = _horaDelPronostico(g, reloj);
      if (h == null) return '$sinClima $hora';
      final edad = reloj.difference(g.descargadoEn);
      final olas = g.clima.olajeDisponible ? '${_numero(h.alturaOlas, 1)} m' : 'sin dato';
      var solunarTxt = '';
      try {
        final s = await SolunarService.calculateSolunar(reloj, lugar.latitude, lugar.longitude);
        solunarTxt =
            ' Fase lunar: ${s.moonPhaseName} (${(s.moonIllumination * 100).round()}% iluminada).';
      } catch (_) {}
      final vieja = edad > _aviso ? ' (pronóstico bajado hace ${edad.inHours} h: aclaralo)' : '';
      return '[CONDICIONES REALES EN ${lugar.name}] $hora Temp: ${_numero(h.temperatura)}°C, Humedad: ${h.humedad}%, '
          'Viento: ${_numero(h.vientoKmH)} km/h del ${_rumbo(h.direccionViento)}, Olas: $olas.$solunarTxt$vieja '
          'No digas que es ideal ni seguro salir: recomendá el parte oficial.';
    } catch (_) {
      return '[CONDICIONES REALES] Clima y mareas no disponibles en este momento.';
    }
  }
}
