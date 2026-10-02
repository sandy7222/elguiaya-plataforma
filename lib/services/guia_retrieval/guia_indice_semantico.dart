import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'guia_embedder.dart';
import 'guia_ficha.dart';
import 'guia_modelo_descarga.dart';
import 'guia_retriever.dart';

/// Vectores de una ficha dentro del índice: filas `[desde, desde + n)`.
class _Entrada {
  final String id;
  final String hash;
  final int desde;
  final int n;
  const _Entrada(this.id, this.hash, this.desde, this.n);

  Map<String, dynamic> toJson() => {'id': id, 'hash': hash, 'desde': desde, 'n': n};
  factory _Entrada.fromJson(Map<String, dynamic> j) =>
      _Entrada(j['id'] as String, j['hash'] as String, (j['desde'] as num).toInt(), (j['n'] as num).toInt());
}

/// Índice semántico de fichas: `Float32List` (filas × dimensión) + ids +
/// hashes, persistido en `<documentos>/elguia/indice/`.
///
/// Por ficha se vectorizan las mismas piezas que en el prototipo Python
/// (`BuscadorSemantico`): cada pregunta como `query: …` y el par
/// `passage: título\ntexto`. El puntaje de la ficha es el máximo coseno
/// entre sus filas, reescalado a [0, 1] con `(cos − 0.70) / 0.25`.
///
/// Construcción incremental: solo se vuelven a embeber las fichas cuyo
/// `hash` (título/texto/preguntas) cambió o que son nuevas; las borradas se
/// descartan. El embedding corre en el isolate worker de llama.cpp, así que
/// la UI no se frena; el índice se guarda cada [fichasPorCheckpoint] fichas
/// para no perder el avance si la app se cierra a mitad de camino.
class GuiaIndiceSemantico implements GuiaPuntuadorSemantico {
  static const String nombreMeta = 'indice_e5.json';
  static const String nombreVectores = 'indice_e5.bin';
  static const int fichasPorCheckpoint = 40;
  static const double cosBajo = 0.70;
  static const double cosAlto = 0.95;

  final Directory dir;
  final String modelo;
  final String version;
  int dimension;

  List<_Entrada> _entradas;
  Float32List _vectores;
  final Map<String, int> _porId = {};

  /// Posición de la entrada para cada ficha del corpus actual (o -1).
  List<int> _orden = const [];
  bool _completo = false;
  bool _actualizando = false;

  /// Quien puede darnos un embedder cuando hace falta (el motor lo abre y
  /// cierra según uso para no tener 150 MB residentes todo el tiempo).
  Future<GuiaEmbedder?> Function()? obtenerEmbedder;

  GuiaIndiceSemantico._(this.dir, this.modelo, this.version, this.dimension, this._entradas, this._vectores) {
    _reindexar();
  }

  int get fichasIndexadas => _entradas.length;
  int get filas => dimension == 0 ? 0 : _vectores.length ~/ dimension;
  bool get actualizando => _actualizando;

  @override
  bool get disponible => _completo && !_actualizando && _entradas.isNotEmpty && obtenerEmbedder != null;

  void _reindexar() {
    _porId
      ..clear()
      ..addEntries(_entradas.asMap().entries.map((e) => MapEntry(e.value.id, e.key)));
  }

  /// Carga el índice guardado para este modelo/versión, o devuelve uno vacío
  /// (también si el archivo es de otro modelo: los vectores no son comparables).
  static Future<GuiaIndiceSemantico> cargar(Directory dir, GuiaModeloManifest m) async {
    try {
      if (!await dir.exists()) await dir.create(recursive: true);
      final meta = File('${dir.path}/$nombreMeta');
      final bin = File('${dir.path}/$nombreVectores');
      if (await meta.exists() && await bin.exists()) {
        final j = json.decode(await meta.readAsString()) as Map<String, dynamic>;
        final dim = (j['dimension'] as num).toInt();
        if (j['modelo'] == m.modelo && j['version'] == m.version && dim == m.dimension) {
          final entradas = (j['entradas'] as List).map((e) => _Entrada.fromJson(e as Map<String, dynamic>)).toList();
          final bytes = await bin.readAsBytes();
          final vec = Float32List.view(bytes.buffer, bytes.offsetInBytes, bytes.lengthInBytes ~/ 4);
          final filas = entradas.fold<int>(0, (s, e) => s + e.n);
          if (vec.length == filas * dim) {
            debugPrint('[GuiaIndiceSemantico] Cargado: ${entradas.length} fichas, $filas filas × $dim');
            return GuiaIndiceSemantico._(dir, m.modelo, m.version, dim, entradas, Float32List.fromList(vec));
          }
          debugPrint('[GuiaIndiceSemantico] Índice inconsistente; se reconstruye.');
        } else {
          debugPrint('[GuiaIndiceSemantico] Índice de otro modelo/versión; se reconstruye.');
        }
      }
    } catch (e) {
      debugPrint('[GuiaIndiceSemantico] No se pudo cargar el índice: $e');
    }
    return GuiaIndiceSemantico._(dir, m.modelo, m.version, m.dimension, [], Float32List(0));
  }

  Future<void> guardar() async {
    try {
      final meta = {
        'modelo': modelo,
        'version': version,
        'dimension': dimension,
        'filas': filas,
        'guardado': DateTime.now().toIso8601String(),
        'entradas': _entradas.map((e) => e.toJson()).toList(),
      };
      final tmpBin = File('${dir.path}/$nombreVectores.tmp');
      await tmpBin.writeAsBytes(_vectores.buffer.asUint8List(_vectores.offsetInBytes, _vectores.lengthInBytes));
      await tmpBin.rename('${dir.path}/$nombreVectores');
      final tmpMeta = File('${dir.path}/$nombreMeta.tmp');
      await tmpMeta.writeAsString(json.encode(meta));
      await tmpMeta.rename('${dir.path}/$nombreMeta');
    } catch (e) {
      debugPrint('[GuiaIndiceSemantico] No se pudo guardar: $e');
    }
  }

  /// Textos a vectorizar de una ficha, ya con prefijos e5.
  static List<String> textosDeFicha(GuiaFicha f, GuiaEmbedder e) => [
        for (final p in f.preguntas)
          if (p.trim().isNotEmpty) e.prefijarConsulta(p.trim()),
        e.prefijarPasaje('${f.titulo}\n${f.texto}'),
      ];

  /// Alinea el índice con [fichas] (orden del corpus actual) y embebe lo que
  /// falte o haya cambiado. Devuelve cuántas fichas se (re)vectorizaron.
  Future<int> actualizar(
    List<GuiaFicha> fichas,
    GuiaEmbedder embedder, {
    void Function(int hechas, int total)? onProgreso,
  }) async {
    if (_actualizando) return 0;
    _actualizando = true;
    var nuevas = 0;
    try {
      if (embedder.dimension != dimension) {
        // Modelo distinto al del índice guardado: empezar de cero.
        dimension = embedder.dimension;
        _entradas = [];
        _vectores = Float32List(0);
        _reindexar();
      }

      final vigentes = <String>{for (final f in fichas) f.id};
      // 1. Sacar fichas borradas o modificadas.
      final conservar = <_Entrada>[];
      final pendientes = <GuiaFicha>[];
      final hashPorId = {for (final f in fichas) f.id: f.hash};
      for (final e in _entradas) {
        if (vigentes.contains(e.id) && hashPorId[e.id] == e.hash) conservar.add(e);
      }
      final conservadas = {for (final e in conservar) e.id};
      for (final f in fichas) {
        if (!conservadas.contains(f.id)) pendientes.add(f);
      }
      if (conservar.length != _entradas.length) _compactar(conservar);

      // 2. Embeber lo pendiente por lotes de fichas, con checkpoints.
      final total = pendientes.length;
      var hechas = 0;
      var desdeUltimoGuardado = 0;
      final t0 = DateTime.now();
      for (var i = 0; i < pendientes.length; i += fichasPorCheckpoint) {
        final grupo = pendientes.sublist(
            i, i + fichasPorCheckpoint < pendientes.length ? i + fichasPorCheckpoint : pendientes.length);
        final textos = <String>[];
        final cuentas = <int>[];
        for (final f in grupo) {
          final ts = textosDeFicha(f, embedder);
          textos.addAll(ts);
          cuentas.add(ts.length);
        }
        final vecs = await embedder.lote(textos);
        if (vecs.length != textos.length) {
          throw StateError('embedder devolvió ${vecs.length} vectores para ${textos.length} textos');
        }
        var k = 0;
        for (var g = 0; g < grupo.length; g++) {
          _agregar(grupo[g], vecs.sublist(k, k + cuentas[g]));
          k += cuentas[g];
        }
        nuevas += grupo.length;
        hechas += grupo.length;
        desdeUltimoGuardado += grupo.length;
        onProgreso?.call(hechas, total);
        if (desdeUltimoGuardado >= fichasPorCheckpoint) {
          await guardar();
          desdeUltimoGuardado = 0;
        }
      }
      if (nuevas > 0 || conservar.length != fichas.length) await guardar();
      if (nuevas > 0) {
        final ms = DateTime.now().difference(t0).inMilliseconds;
        debugPrint('[GuiaIndiceSemantico] $nuevas fichas vectorizadas en $ms ms '
            '(${(ms / nuevas).toStringAsFixed(0)} ms/ficha); total $fichasIndexadas fichas, $filas filas');
      }

      // 3. Orden del corpus → entrada.
      _orden = [for (final f in fichas) _porId[f.id] ?? -1];
      _completo = fichas.isNotEmpty && !_orden.contains(-1);
    } catch (e) {
      debugPrint('[GuiaIndiceSemantico] Actualización interrumpida: $e');
      _orden = [for (final f in fichas) _porId[f.id] ?? -1];
      _completo = false;
      await guardar();
    } finally {
      _actualizando = false;
    }
    return nuevas;
  }

  void _compactar(List<_Entrada> conservar) {
    final nuevo = Float32List(conservar.fold<int>(0, (s, e) => s + e.n) * dimension);
    final nuevas = <_Entrada>[];
    var fila = 0;
    for (final e in conservar) {
      nuevo.setRange(fila * dimension, (fila + e.n) * dimension, _vectores, e.desde * dimension);
      nuevas.add(_Entrada(e.id, e.hash, fila, e.n));
      fila += e.n;
    }
    _entradas = nuevas;
    _vectores = nuevo;
    _reindexar();
  }

  void _agregar(GuiaFicha f, List<Float32List> vecs) {
    final desde = filas;
    final ampliado = Float32List(_vectores.length + vecs.length * dimension);
    ampliado.setRange(0, _vectores.length, _vectores);
    var off = _vectores.length;
    for (final v in vecs) {
      ampliado.setRange(off, off + dimension, v);
      off += dimension;
    }
    _vectores = ampliado;
    _entradas.add(_Entrada(f.id, f.hash, desde, vecs.length));
    _porId[f.id] = _entradas.length - 1;
  }

  /// Puntaje [0, 1] por ficha del corpus (orden de la última [actualizar]),
  /// o null si el índice no está completo o no hay embedder.
  @override
  Future<List<double>?> puntuar(String consulta) async {
    if (!disponible) return null;
    final embedder = await obtenerEmbedder!();
    if (embedder == null) return null;
    final q = await embedder.consulta(consulta);
    if (q == null || q.length != dimension) return null;
    return puntuarConVector(q);
  }

  /// Igual que [puntuar] pero con la consulta ya vectorizada (tests / medición).
  List<double> puntuarConVector(Float32List q) {
    final salida = List<double>.filled(_orden.length, 0.0);
    for (var i = 0; i < _orden.length; i++) {
      final pos = _orden[i];
      if (pos < 0) continue;
      final e = _entradas[pos];
      var mejor = -1.0;
      for (var r = e.desde; r < e.desde + e.n; r++) {
        var dot = 0.0;
        final base = r * dimension;
        for (var d = 0; d < dimension; d++) {
          dot += _vectores[base + d] * q[d];
        }
        if (dot > mejor) mejor = dot;
      }
      salida[i] = reescalar(mejor);
    }
    return salida;
  }

  /// `reescalar_cos` del prototipo: [0.70, 0.95] → [0, 1].
  static double reescalar(double cos) => ((cos - cosBajo) / (cosAlto - cosBajo)).clamp(0.0, 1.0);

  /// Borra el índice del disco (cambio de modelo, liberar espacio).
  static Future<void> borrar(Directory dir) async {
    for (final n in [nombreMeta, nombreVectores, '$nombreMeta.tmp', '$nombreVectores.tmp']) {
      try {
        final f = File('${dir.path}/$n');
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
