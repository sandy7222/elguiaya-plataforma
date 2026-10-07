/// Resultado de verificar una respuesta de la nube.
class VerificacionDatos {
  final String texto;

  /// Lo que se sacó o reemplazó (para el registro; nunca se le muestra al usuario).
  final List<String> reemplazos;

  const VerificacionDatos(this.texto, this.reemplazos);

  bool get corrigio => reemplazos.isNotEmpty;
}

/// La nube no puede inventar datos ni citar fuentes que la app no le dio (paso 1.8).
///
/// Caso real (2026-10-07, prueba del dueño): ante "cómo está la pesca el día de hoy" contestó "Según el parte
/// oficial… el nivel del río está medio, con aguas algo turbias". Ni el parte oficial ni el nivel del río existen en
/// ningún dato que la app le dé: rompe la regla 2 de AGENTS.md ("nunca inventar datos").
///
/// Dos capas, que acá viven juntas:
///   1. [reglasDeDatos]: se agrega al prompt. Lista los datos que la app SÍ da y prohíbe citar lo demás.
///   2. [verificar]: revisa lo que contestó la nube, oración por oración, contra el contexto que se le mandó. Lo que
///      no tiene respaldo se reemplaza por [reemplazo]. Es la red de seguridad: el prompt solo no alcanza.
/// (La tercera capa, el ruteo de "cómo está la pesca hoy" al lector de condiciones, está en `GuiaCondicionesService`.)
class GuiaVerificadorDatos {
  static const String reemplazo = 'Ese dato no lo tengo; consultalo en el parte oficial.';

  static const String reglasDeDatos = '''
REGLAS DE DATOS (no negociables):
- Los ÚNICOS datos medidos que tenés son los que figuran en los bloques entre corchetes de este mensaje: la hora local, la temperatura, el viento, la humedad, las olas (solo si figuran) y la fase de la luna.
- PROHIBIDO citar el parte oficial, Prefectura, el SMN, el INA o cualquier otra fuente como si la hubieras consultado.
- PROHIBIDO dar o describir el nivel del río (ni su altura), el caudal, crecidas o bajantes, la turbidez, la temperatura del agua, las mareas (pleamar y bajamar), vedas, ni horarios del sol, de la luna o del pique, si no figuran en esos bloques.
- PROHIBIDO dar números con unidad (grados, km/h, %, metros, hPa) que no estén en esos bloques o que no haya dicho el usuario.
- Si te piden uno de esos datos y no figura, contestá exactamente: "$reemplazo"
- Conversá sobre los datos que SÍ tenés, las especies y las técnicas de pesca. No completes con suposiciones.''';

  // ── Normalización ──────────────────────────────────────────────────────────
  static String _n(String t) => t
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('³', '3');

  // ── Fuentes oficiales citadas como si se hubieran consultado ───────────────
  static const String _fuente =
      r'(?:parte oficial|parte meteorologico|parte de prefectura|reporte oficial|informe oficial|boletin(?: oficial)?|'
      r'prefectura(?: naval)?(?: argentina)?|pna|smn|servicio meteorologico(?: nacional)?|ina|instituto nacional del agua|'
      r'alerta oficial)';

  /// "Según el SMN, hoy…": una cláusula con coma que se puede sacar sin romper la oración.
  static final RegExp _clausulaConComa = RegExp(
    r'\b(?:segun|de acuerdo (?:con|a|al)|conforme (?:a|al))\s+(?:el |la |los |las )?' + _fuente + r'[^,.;]{0,30},\s*',
  );

  /// "Según el SMN el río…" (sin coma): la oración entera es la afirmación → se reemplaza.
  static final RegExp _segunFuente = RegExp(
    r'\b(?:segun|de acuerdo (?:con|a|al)|conforme (?:a|al))\s+(?:el |la |los |las )?' + _fuente + r'\b',
  );

  /// "El SMN indica…", "El parte oficial informa…".
  static final RegExp _fuenteAfirma = RegExp(
    r'\b(?:el|la)\s+' + _fuente +
        r'\s+(?:indica|informa|dice|marca|reporta|senala|anuncia|confirma|publico|advierte|pronostica|aconseja|recomienda)\b',
  );

  // ── Mediciones que la app no da ────────────────────────────────────────────
  static final List<RegExp> _temasInventados = [
    RegExp(r'\b(?:nivel|altura|cota)\s+del\s+(?:rio|agua|parana)\b[^.]{0,30}\b(?:es|esta|se encuentra|ronda|marca|subio|bajo|sube|baja|medio|alto|bajo|normal|\d)'),
    RegExp(r'\bcaudal\b[^.]{0,25}\b(?:es|esta|ronda|de|\d)'),
    RegExp(r'\b(?:hay|hubo|habra|se espera|con)\s+(?:una\s+)?(?:crecida|bajante)\b'),
    RegExp(r'\b(?:turbidez|turbiedad)\b'),
    RegExp(r'\btemperatura del agua\b[^.]{0,25}\b(?:es|esta|ronda|anda|de|\d)'),
    RegExp(r'\b(?:pleamar|bajamar)\b[^.]{0,40}(?:\d{1,2}:\d{2}|\bhoy\b|\bmanana\b|\bes a\b|\bsera\b)'),
    RegExp(r'\bveda\b[^.]{0,60}\b(?:desde|hasta|empieza|comienza|termina|vigente|rige|inicia|del \d|entre el|el \d+ de)'),
  ];

  /// Número con unidad de CONDICIONES (no de pesca: mm de línea, kg, libras...).
  static final RegExp _numeroConUnidad = RegExp(
    r'(\d+(?:[.,]\d+)?)\s?(?:°\s?c|ºc|°|grados(?: centigrados)?|km/h|kilometros por hora|nudos|kt|%|por ciento|hpa|milibares|mb|m3/s|mm de lluvia|milimetros de lluvia)',
  );

  /// Metros solo cuentan como condición si la oración habla del agua, las olas o el río.
  static final RegExp _metrosDeAgua = RegExp(
    r'(\d+(?:[.,]\d+)?)\s?(?:m|metros?)\b',
  );
  static final RegExp _hablaDelAgua = RegExp(r'\b(?:olas?|rio|agua|crecida|altura|profundidad del rio)\b');

  static final RegExp _horario = RegExp(r'\b(\d{1,2}):(\d{2})\b');
  static final RegExp _hablaDeHorarioAstronomico =
      RegExp(r'\b(?:sale|se pone|amanece|atardece|pleamar|bajamar|salida|puesta|pique|periodo|marea|luna|sol)\b');

  static double? _valor(String s) => double.tryParse(s.replaceAll(',', '.'));

  static List<String> _partir(String t) =>
      t.split(RegExp(r'(?<=[.!?])\s+(?=[A-ZÁÉÍÓÚÑ¿¡0-9])')).where((p) => p.trim().isNotEmpty).toList();

  static String _mayuscula(String t) => t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  /// Verifica [respuesta] contra [contexto] (lo que se le mandó a la nube: los bloques de condiciones, la pregunta
  /// y la charla reciente). Cada oración se queda solo si lo que afirma tiene respaldo en ese contexto.
  static VerificacionDatos verificar(String respuesta, {required String contexto}) {
    if (respuesta.trim().isEmpty) return VerificacionDatos(respuesta, const []);
    final ctx = _n(contexto);
    final numeros = RegExp(r'\d+(?:[.,]\d+)?').allMatches(ctx).map((m) => _valor(m[0]!)).whereType<double>().toList();
    final horarios = _horario.allMatches(ctx).map((m) => '${int.parse(m[1]!)}:${m[2]}').toSet();

    bool respaldado(double v) => numeros.any((n) => (n - v).abs() < 1.0);

    final salida = <String>[];
    final reemplazos = <String>[];

    void inventada(String original) {
      reemplazos.add(original.trim());
      if (salida.isEmpty || salida.last != reemplazo) salida.add(reemplazo);
    }

    for (final original in _partir(respuesta)) {
      var t = original;
      final n = _n(t);

      // 1. Fuentes oficiales citadas como si se hubieran consultado.
      if (_fuenteAfirma.hasMatch(n) || (_segunFuente.hasMatch(n) && !_clausulaConComa.hasMatch(n))) {
        inventada(original);
        continue;
      }
      var sacoClausula = false;
      final clausula = _clausulaConComa.firstMatch(n);
      if (clausula != null) {
        // La cláusula es del mismo largo en el texto original (la normalización no cambia la cantidad de letras).
        t = _mayuscula(t.substring(0, clausula.start) + t.substring(clausula.end));
        reemplazos.add(original.substring(clausula.start, clausula.end).trim());
        sacoClausula = true;
      }
      final nt = _n(t);

      // 2. Mediciones que la app no da (nivel del río, caudal, turbidez...).
      if (_temasInventados.any((r) => r.hasMatch(nt) && !ctx.contains(r.firstMatch(nt)![0]!.split(RegExp(r'\s+')).take(3).join(' ')))) {
        inventada(original);
        continue;
      }

      // 3. Números de condiciones que no están en el contexto.
      var sinRespaldo = false;
      var conRespaldo = false;
      for (final m in _numeroConUnidad.allMatches(nt)) {
        final v = _valor(m[1]!);
        if (v == null) continue;
        if (respaldado(v)) {
          conRespaldo = true;
        } else {
          sinRespaldo = true;
        }
      }
      if (_hablaDelAgua.hasMatch(nt)) {
        for (final m in _metrosDeAgua.allMatches(nt)) {
          final v = _valor(m[1]!);
          if (v != null && !respaldado(v)) sinRespaldo = true;
        }
      }
      // 4. Horarios del sol, la luna, las mareas o el pique que la app no dio.
      if (_hablaDeHorarioAstronomico.hasMatch(nt)) {
        for (final m in _horario.allMatches(nt)) {
          if (!horarios.contains('${int.parse(m[1]!)}:${m[2]}')) sinRespaldo = true;
        }
      }
      if (sinRespaldo) {
        inventada(original);
        continue;
      }

      // Si se sacó una fuente inventada, lo que queda tiene que estar respaldado por números del contexto;
      // si no, era el contenido de esa fuente ("según Prefectura, hay alerta…") y se reemplaza entero.
      if (sacoClausula && !conRespaldo) {
        inventada(original);
        continue;
      }
      salida.add(t.trim());
    }

    return VerificacionDatos(salida.join(' ').trim(), reemplazos);
  }
}
