import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show AssetManifest, rootBundle;
import 'package:path_provider/path_provider.dart';

import 'guia_ficha.dart';

/// Construye el corpus de fichas desde las librerías JSON de El Guía.
///
/// Es el port fiel de `mini_model_lab/retrieval/fichas.py`: mismas reglas
/// A–E, mismas exclusiones, mismo texto. El test `test/guia_retrieval_test.dart`
/// compara la salida contra `fichas_corpus.json` generado por Python, así
/// que cualquier cambio de lógica tiene que hacerse en los dos lados.
///
/// Reglas (se aplican todas, acumulando fichas por archivo):
///  A. intenciones[] con activadores + respuesta_limpia/respuestas
///  B. especies{} (peces.json): una ficha por especie
///  C. claves estructuradas (tipos, nudos, estados, por_especie, ...): una
///     ficha por entrada, o una ficha por clave (tecnica, carnadas, equipos...)
///  D. activadores[] + contenido/respuesta_limpia a nivel raíz
///  E. respuestas_puente[0] largo = la ficha completa del educador
///
/// Nunca entran: librerías CRÍTICAS (seguridad y transaccional de la app,
/// las responde siempre el motor de reglas) ni SOCIALES (saludos, chistes,
/// charla: personalidad, no datos).
class GuiaCorpusBuilder {
  static const Set<String> criticas = {
    'emergencia', 'primeros_auxilios', 'canales_vhf_frecuencias',
    'prefectura_naval_argentina', 'que_sirve_canal_emergencia',
    'activar_guia', 'crear_viaje', 'pagar_viaje', 'confirmar_viaje',
    'reserva', 'ver_cotizaciones', 'elegir_capitan', 'notificaciones',
    'historial_viajes', 'calificar', 'tienda', 'carrito', 'ayuda_general',
    'que_puede_hacer_bot', 'perfil_pescador', 'gps', 'estado_viaje',
  };
  static const List<String> criticasSubstrings = ['frecuencia', 'comunicacion_', 'sinonimos_'];

  static const Set<String> sociales = {
    'saludos', 'despedidas', 'agradecimiento', 'hora', 'mate', 'chistes',
    'humor_contextual', 'charla_cotidiana', 'emociones_pescador',
    'celebraciones', 'reacciones_clima', 'acompanamiento', 'frases_ambiente',
    'preguntas_humanas',
  };

  static const Set<String> _metaKeys = {
    'intent', 'libreria', 'prioridad', 'version', 'modulo', '_comentario',
    'respuestas_puente', 'respuestas', 'seguimiento', 'preguntas_seguimiento',
    'introducciones', 'gif', 'gif_opciones_chiste', 'gif_opciones_carcajada',
    'activadores', 'intenciones', 'palabras_clave', 'etiquetas', 'anclas',
    'ruta_navegacion', 'respuesta_navegacion', 'pregunta_automatica',
    'pregunta_estado', 'respuesta_sin_estado', 'contexto_por_momento',
    'frases_mate_idle', 'reglas', 'fuentes', 'descripcion', 'tipo', 'accion',
    'objetivo', 'especie', 'nombre_cientifico', 'nombres_populares',
    'respuestas_rapidas', 'respuestas_manana', 'respuestas_tarde',
    'respuestas_noche', 'respuesta_presentacion', 'respuesta_final',
    'orden_prioridades', 'modo', 'subintenciones', 'respuesta_sin_especie',
  };

  static const Set<String> _porEntrada = {
    'tipos', 'nudos', 'estados', 'fenomenos', 'metodos', 'canas', 'reeles',
    'por_especie', 'por_condicion', 'por_situacion', 'situaciones',
    'categorias', 'consejos', 'curiosidades',
  };

  static const Set<String> _unaFicha = {
    'tecnica', 'carnadas', 'equipos', 'seguridad', 'habitat', 'temporada',
    'identificacion', 'conservacion', 'condiciones', 'consejo',
    'orientacion_sin_senal', 'advertencia', 'consejo_general', 'senal_rescate',
  };

  static const Set<String> _listaTitulada = {'curiosidades'};

  /// Orden importa: se prueba el primero que matchea.
  static const List<MapEntry<String, String>> _prefijosPregunta = [
    MapEntry('como_hago_', '¿Cómo hago '),
    MapEntry('como_se_hace_', '¿Cómo se hace '),
    MapEntry('como_se_prepara_', '¿Cómo se prepara '),
    MapEntry('como_sirve_', '¿Cómo sirve '),
    MapEntry('como_pescar_', '¿Cómo se pesca '),
    MapEntry('que_sirve_', '¿Para qué sirve '),
    MapEntry('que_se_hace_', '¿Qué se hace con '),
    MapEntry('cuando_hago_', '¿Cuándo hago '),
    MapEntry('cuando_sirve_', '¿Cuándo sirve '),
    MapEntry('cuando_se_usa_', '¿Cuándo se usa '),
    MapEntry('donde_se_hace_', '¿Dónde se hace '),
    MapEntry('donde_sirve_', '¿Dónde sirve '),
  ];

  static const List<MapEntry<List<String>, String>> _categoriaPorPista = [
    MapEntry(['empanada', 'fritanga', 'chupin', 'masa', 'conserva', 'viuda', 'receta'], 'cocina'),
    MapEntry(['fuego', 'refugio', 'agua', 'alimento', 'supervivencia', 'orientacion'], 'campamento'),
    MapEntry(['peces', 'especie', 'bagre_de_mar', 'dorado', 'surubi', 'pejerrey', 'trucha', 'corvina', 'tararira', 'boga'], 'especies'),
    MapEntry(['clima', 'rio', 'luna', 'marea', 'presion', 'solunar', 'temporada'], 'condiciones'),
  ];

  static const int _textoLargoMin = 120;
  static final RegExp _citaRe = RegExp(r'\s*\[\d+(?:,\s*\d+)*\]');
  static final RegExp _prefijoNoPalabra = RegExp(r'^[^\p{L}\p{N}_¿¡]+', unicode: true);
  static final RegExp _tieneLetra = RegExp(r'\p{L}', unicode: true);

  // ───────────────────────────── carga ─────────────────────────────

  /// Devuelve el motivo de exclusión ("critica" | "social") o null.
  static String? motivoExclusion(String stem) {
    if (criticas.contains(stem) || criticasSubstrings.any(stem.contains)) return 'critica';
    if (sociales.contains(stem)) return 'social';
    return null;
  }

  /// Carga todas las librerías: primero las de assets (listadas por el
  /// AssetManifest, así aparecen las nuevas sin tocar código) y encima las
  /// sincronizadas en `<documentos>/elguia/librerias/` (overrides OTA).
  static Future<Map<String, Map<String, dynamic>>> cargarLibreriasDeApp() async {
    final librerias = <String, Map<String, dynamic>>{};
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in manifest.listAssets()) {
        if (!asset.startsWith('assets/elguia/librerias/') || !asset.endsWith('.json')) continue;
        final stem = asset.substring('assets/elguia/librerias/'.length, asset.length - 5);
        if (stem.contains('/')) continue;
        try {
          final decoded = json.decode(await rootBundle.loadString(asset));
          if (decoded is Map<String, dynamic>) librerias[stem] = decoded;
        } catch (_) {
          // JSON roto en assets: se saltea, el resto sigue.
        }
      }
    } catch (_) {
      // Sin manifest (tests o plataforma rara): se sigue solo con overrides.
    }
    try {
      final dir = await getApplicationDocumentsDirectory().timeout(const Duration(seconds: 3));
      final overrides = Directory('${dir.path}/elguia/librerias');
      if (await overrides.exists()) {
        await for (final ent in overrides.list()) {
          if (ent is! File || !ent.path.endsWith('.json')) continue;
          final stem = ent.uri.pathSegments.last;
          try {
            final decoded = json.decode(await ent.readAsString());
            if (decoded is Map<String, dynamic>) {
              librerias[stem.substring(0, stem.length - 5)] = decoded;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    return librerias;
  }

  // ─────────────────────────── construcción ───────────────────────────

  /// Construye el corpus a partir de `{stem: json}`. Función pura.
  static GuiaCorpusResultado construir(Map<String, Map<String, dynamic>> librerias) {
    final fichas = <GuiaFicha>[];
    final reporte = GuiaCorpusReporte();
    final stems = librerias.keys.toList()..sort();
    for (final stem in stems) {
      reporte.libreriasTotal++;
      final motivo = motivoExclusion(stem);
      if (motivo == 'critica') {
        reporte.excluidasCriticas.add(stem);
        continue;
      }
      if (motivo == 'social') {
        reporte.excluidasSociales.add(stem);
        continue;
      }
      final r = fichasDeLibreria(stem, librerias[stem]!);
      if (r.sinConvertir.isNotEmpty) reporte.sinConvertir[stem] = r.sinConvertir;
      if (r.fichas.isEmpty) {
        reporte.sinFichas.add(stem);
        continue;
      }
      reporte.fichasPorLibreria[stem] = r.fichas.length;
      fichas.addAll(r.fichas);
    }
    return GuiaCorpusResultado(fichas, reporte);
  }

  /// Fichas de UNA librería. Espejo de `fichas_de_libreria` en Python.
  static ({List<GuiaFicha> fichas, List<String> sinConvertir}) fichasDeLibreria(
      String stem, Map<String, dynamic> data) {
    final fichas = <GuiaFicha>[];
    final sinConvertir = <String>[];
    final tema = _legible(stem);
    final categoria = _categoriaPara(stem);
    final keywordsArchivo = <String>[
      for (final k in (data['palabras_clave'] as List? ?? const []))
        if (k is String) k,
    ];
    final respuestasRapidas = data['respuestas_rapidas'] is Map
        ? Map<String, dynamic>.from(data['respuestas_rapidas'] as Map)
        : const <String, dynamic>{};

    // A. intenciones[]
    if (data['intenciones'] is List) {
      for (final item in data['intenciones'] as List) {
        if (item is! Map) continue;
        final nombre = (item['intencion']?.toString() ?? '').trim();
        final activadores = <String>[
          for (final a in (item['activadores'] as List? ?? const []))
            if (a is String && a.trim().isNotEmpty) a.trim(),
        ];
        var respuesta = _extraerRespuesta(item['respuesta_limpia']) ?? _extraerRespuesta(item['respuestas']);
        if (respuesta == null && nombre.isNotEmpty && respuestasRapidas.isNotEmpty) {
          final r = respuestasRapidas[nombre] ?? respuestasRapidas[_rstripS(nombre)];
          respuesta = r is String ? r.trim() : null;
        }
        if (respuesta == null || respuesta.isEmpty || activadores.isEmpty) continue;
        fichas.add(_ficha(
          id: '$stem/${nombre.isNotEmpty ? nombre : activadores[0]}',
          libreria: stem,
          titulo: _tituloDesdeTexto(respuesta, _legible(nombre).isNotEmpty ? _legible(nombre) : activadores[0]),
          texto: respuesta,
          preguntas: activadores,
          keywords: keywordsArchivo,
          categoria: categoria,
        ));
      }
    }

    // B. especies{}
    if (data['especies'] is Map) {
      (data['especies'] as Map).forEach((nombre, info) {
        if (info is! Map) return;
        final texto = _valorATexto(info);
        if (texto.isEmpty) return;
        final n = _legible(nombre.toString());
        fichas.add(_ficha(
          id: '$stem/$nombre',
          libreria: stem,
          titulo: _capitalize(n),
          texto: texto,
          preguntas: [n, 'contame del $n', 'cómo se pesca el $n'],
          keywords: [(info['nombre_cientifico'] ?? '').toString(), ...keywordsArchivo],
          categoria: 'especies',
        ));
      });
    }

    // C. claves estructuradas
    data.forEach((clave, valor) {
      if (_metaKeys.contains(clave) || clave == 'especies') return;
      if (_listaTitulada.contains(clave) && valor is List) {
        for (var i = 0; i < valor.length; i++) {
          final item = valor[i];
          if (item is! Map || item['texto'] is! String) continue;
          final titulo = (item['titulo']?.toString().trim().isNotEmpty ?? false)
              ? item['titulo'].toString().trim()
              : '${_legible(clave)} ${i + 1}';
          fichas.add(_ficha(
            id: '$stem/$clave/${i + 1}',
            libreria: stem,
            titulo: '$titulo ($tema)',
            texto: (item['texto'] as String).trim(),
            preguntas: [titulo, '$titulo $tema'],
            keywords: keywordsArchivo,
            categoria: categoria,
          ));
        }
      } else if (_porEntrada.contains(clave) && valor is Map) {
        valor.forEach((entrada, contenido) {
          final texto = _valorATexto(contenido);
          if (texto.isEmpty) return;
          final nombre = _legible(entrada.toString());
          List<String> preguntas;
          if (clave == 'por_especie') {
            final singular = tema.endsWith('s') ? tema.substring(0, tema.length - 1) : tema;
            preguntas = ['$tema para $nombre', 'que $singular uso para $nombre', 'con que se pesca el $nombre'];
          } else if (clave == 'por_condicion') {
            preguntas = ['$tema con $nombre', nombre, 'que $tema conviene con $nombre'];
          } else {
            preguntas = [nombre, '$tema $nombre', '$nombre $tema'];
          }
          fichas.add(_ficha(
            id: '$stem/$clave/$entrada',
            libreria: stem,
            titulo: '${_capitalize(nombre)} ($tema)',
            texto: texto,
            preguntas: preguntas,
            keywords: keywordsArchivo,
            categoria: categoria,
          ));
        });
      } else if (_unaFicha.contains(clave) && (valor is Map || valor is String || valor is List)) {
        final texto = _valorATexto(valor);
        if (texto.isEmpty) return;
        final nombre = _legible(clave);
        fichas.add(_ficha(
          // "campo/" evita chocar con una intención del mismo nombre (bagre_de_mar)
          id: '$stem/campo/$clave',
          libreria: stem,
          titulo: '${_capitalize(nombre)} ($tema)',
          texto: texto,
          preguntas: ['$nombre $tema', '$tema $nombre', _preguntaDesdeNombre(stem)],
          keywords: keywordsArchivo,
          categoria: categoria,
        ));
      } else if (clave == 'tipos' && valor is List) {
        // lista de ejemplos: se suma como keywords en E
      } else {
        sinConvertir.add(clave);
      }
    });

    // D. activadores[] + contenido a nivel raíz
    if (fichas.isEmpty && data['activadores'] is List) {
      final activadores = <String>[
        for (final a in data['activadores'] as List)
          if (a is String && a.trim().isNotEmpty) a.trim(),
      ];
      final respuesta = _extraerRespuesta(data['contenido']) ?? _extraerRespuesta(data['respuesta_limpia']);
      if (respuesta != null && activadores.isNotEmpty) {
        fichas.add(_ficha(
          id: stem,
          libreria: stem,
          titulo: _tituloDesdeTexto(respuesta, tema),
          texto: respuesta,
          preguntas: activadores,
          keywords: keywordsArchivo,
          categoria: categoria,
        ));
      }
    }

    // E. respuestas_puente como contenido
    if (fichas.isEmpty && data['respuestas_puente'] is List) {
      final respuesta = _extraerRespuesta(data['respuestas_puente']);
      if (respuesta != null && (respuesta.runes.length >= _textoLargoMin || respuesta.contains('\n'))) {
        final ejemplos = data['tipos'] is List
            ? <String>[for (final t in data['tipos'] as List) if (t is String) t]
            : const <String>[];
        final pregunta = _preguntaDesdeNombre(stem);
        fichas.add(_ficha(
          id: stem,
          libreria: stem,
          titulo: _tituloDesdeTexto(respuesta, pregunta),
          texto: respuesta,
          preguntas: [pregunta, tema],
          keywords: [...ejemplos, ...keywordsArchivo],
          categoria: categoria,
        ));
      }
    }

    return (fichas: fichas, sinConvertir: sinConvertir);
  }

  // ───────────────────────────── helpers ─────────────────────────────

  /// Aplica la limpieza final común: saca citas [15, 16], deduplica.
  static GuiaFicha _ficha({
    required String id,
    required String libreria,
    required String titulo,
    required String texto,
    required List<String> preguntas,
    required List<String> keywords,
    required String categoria,
  }) =>
      GuiaFicha(
        id: id,
        libreria: libreria,
        titulo: titulo,
        texto: texto.replaceAll(_citaRe, '').trim(),
        preguntas: _unicos(preguntas),
        keywords: _unicos(keywords),
        categoria: categoria,
      );

  static List<String> _unicos(List<String> xs) {
    final vistos = <String>{};
    final out = <String>[];
    for (final x in xs) {
      final t = x.trim();
      if (t.isEmpty || !vistos.add(t)) continue;
      out.add(t);
    }
    return out;
  }

  static String _legible(String clave) => clave.replaceAll('_', ' ').trim();

  static String _capitalize(String s) =>
      s.isEmpty ? s : s.substring(0, 1).toUpperCase() + s.substring(1).toLowerCase();

  static String _rstripS(String s) {
    var t = s;
    while (t.endsWith('s')) {
      t = t.substring(0, t.length - 1);
    }
    return t;
  }

  static String _preguntaDesdeNombre(String stem) {
    for (final e in _prefijosPregunta) {
      if (stem.startsWith(e.key)) return '${e.value}${_legible(stem.substring(e.key.length))}?';
    }
    return _legible(stem);
  }

  static String _categoriaPara(String stem) {
    for (final e in _categoriaPorPista) {
      if (e.key.any(stem.contains)) return e.value;
    }
    return 'tecnico';
  }

  /// Si el texto arranca con un título tipo "🎣 CÓMO ARMAR LA LÍNEA", lo usa.
  static String _tituloDesdeTexto(String texto, String alternativo) {
    final primera = texto.trim().split('\n').first.trim();
    final limpia = primera.replaceFirst(_prefijoNoPalabra, '').trim();
    final largo = limpia.runes.length;
    if (largo >= 3 && largo <= 80 && limpia.toUpperCase() == limpia && _tieneLetra.hasMatch(limpia)) {
      return _capitalize(limpia);
    }
    return alternativo;
  }

  static String? _extraerRespuesta(dynamic valor) {
    if (valor is String && valor.trim().isNotEmpty) return valor.trim();
    if (valor is List && valor.isNotEmpty) {
      final primero = valor.first;
      if (primero is String && primero.trim().isNotEmpty) return primero.trim();
      if (primero is Map) {
        for (final campo in const ['texto', 'respuesta_limpia', 'contenido']) {
          final v = primero[campo];
          if (v is String && v.trim().isNotEmpty) return v.trim();
        }
      }
    }
    return null;
  }

  /// Convierte dict/list/str a texto legible, determinístico.
  static String _valorATexto(dynamic valor, [String sangria = '']) {
    if (valor is String) return valor.trim();
    if (valor is bool) return valor ? 'True' : 'False';
    if (valor is num) return valor.toString();
    if (valor is List) {
      final items = <String>[];
      for (final v in valor) {
        if (v == null) continue;
        final t = _valorATexto(v);
        if (t.isNotEmpty) items.add(t);
      }
      if (items.isEmpty) return '';
      if (items.every((i) => !i.contains('\n') && i.runes.length < 60)) return items.join(', ');
      return items.map((i) => '$sangria- $i').join('\n');
    }
    if (valor is Map) {
      final lineas = <String>[];
      valor.forEach((k, v) {
        final t = _valorATexto(v, '$sangria  ');
        if (t.isEmpty) return;
        final etiqueta = _capitalize(_legible(k.toString()));
        lineas.add(t.contains('\n') ? '$sangria$etiqueta:\n$t' : '$sangria$etiqueta: $t');
      });
      return lineas.join('\n');
    }
    return '';
  }
}

class GuiaCorpusResultado {
  final List<GuiaFicha> fichas;
  final GuiaCorpusReporte reporte;
  const GuiaCorpusResultado(this.fichas, this.reporte);
}

/// Qué se convirtió y qué no, para revisar desde el panel del educador.
class GuiaCorpusReporte {
  int libreriasTotal = 0;
  final List<String> excluidasCriticas = [];
  final List<String> excluidasSociales = [];
  final List<String> sinFichas = [];
  final Map<String, List<String>> sinConvertir = {};
  final Map<String, int> fichasPorLibreria = {};

  int get fichasTotal => fichasPorLibreria.values.fold(0, (a, b) => a + b);

  Map<String, dynamic> toJson() => {
        'librerias_total': libreriasTotal,
        'excluidas_criticas': excluidasCriticas,
        'excluidas_sociales': excluidasSociales,
        'sin_fichas': sinFichas,
        'sin_convertir': sinConvertir,
        'fichas_por_libreria': fichasPorLibreria,
        'fichas_total': fichasTotal,
      };

  @override
  String toString() =>
      'GuiaCorpusReporte(librerias: $libreriasTotal, criticas: ${excluidasCriticas.length}, '
      'sociales: ${excluidasSociales.length}, con fichas: ${fichasPorLibreria.length}, '
      'fichas: $fichasTotal, sin fichas: ${sinFichas.length}, sin convertir: ${sinConvertir.length})';
}
