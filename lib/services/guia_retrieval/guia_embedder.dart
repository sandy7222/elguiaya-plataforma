import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:llama_cpp_dart/llama_cpp_dart.dart';

import 'guia_modelo_descarga.dart';

/// Envoltorio sobre `LlamaEngine` (llama.cpp) para sacar embeddings de
/// `multilingual-e5-small` en el celular.
///
/// - Corre en el isolate worker del engine: no bloquea la UI.
/// - Agrega los prefijos `query: ` / `passage: ` que e5 necesita (vienen del
///   manifest, por si algún día se cambia de modelo).
/// - Devuelve vectores L2-normalizados, así el coseno es un producto punto.
///
/// Igual que `EmbedderE5` en `mini_model_lab/retrieval/evaluar_retrieval.py`
/// (mean pooling + L2). Ahí se usó ONNX int8 por falta de wheel de
/// llama-cpp-python en Python 3.14; acá va el GGUF Q8_0. El índice se
/// construye en el dispositivo con el mismo modelo que puntúa las
/// consultas, así que nunca se mezclan variantes.
class GuiaEmbedder {
  final LlamaEngine _engine;
  final GuiaModeloManifest manifest;
  final int dimension;
  bool _cerrado = false;

  /// Cuántos pasajes se meten por pasada de `embedBatch` (= nSeqMax).
  static const int tamanoLote = 8;

  /// Contexto por secuencia: e5-small admite 512 tokens; las fichas más
  /// largas (~1200 caracteres) entran holgadas.
  static const int nCtxPorSecuencia = 512;

  GuiaEmbedder._(this._engine, this.manifest, this.dimension);

  bool get disponible => !_cerrado;

  /// ¿Esta plataforma puede cargar libllama? En tests de escritorio (Windows/
  /// Linux) no viaja el binario, así que se salta el semántico sin error.
  static bool get plataformaSoportada => Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  /// Abre el modelo. Devuelve null (y loguea) si no se puede: sin binario
  /// nativo, GGUF corrupto, RAM insuficiente... El retriever sigue léxico.
  static Future<GuiaEmbedder?> abrir(File modelo, GuiaModeloManifest manifest) async {
    if (!plataformaSoportada) {
      debugPrint('[GuiaEmbedder] Plataforma sin libllama (${Platform.operatingSystem}); solo BM25.');
      return null;
    }
    if (!await modelo.exists()) return null;
    final t0 = DateTime.now();
    try {
      final modelParams = ModelParams(path: modelo.path, useMmap: true);
      final contextParams = ContextParams(
        nCtx: nCtxPorSecuencia * tamanoLote,
        nBatch: nCtxPorSecuencia * tamanoLote,
        nUbatch: nCtxPorSecuencia,
        nSeqMax: tamanoLote,
        embeddings: true,
        poolingType: PoolingType.mean,
        flashAttn: FlashAttention.auto,
      );
      final engine = Platform.isAndroid
          ? await LlamaEngine.spawn(
              libraryPath: 'libllama.so', // basename: Android resuelve desde el AAR
              modelParams: modelParams,
              contextParams: contextParams,
            )
          : await LlamaEngine.spawnFromProcess(
              modelParams: modelParams,
              contextParams: contextParams,
            );
      // Sondeo: dimensión real y calentamiento.
      final prueba = await engine.embed('${manifest.prefijoConsulta}hola');
      final dim = prueba.nEmbd;
      if (dim != manifest.dimension) {
        debugPrint('[GuiaEmbedder] Dimensión $dim ≠ manifest ${manifest.dimension}; se usa la real.');
      }
      debugPrint('[GuiaEmbedder] ${manifest.modelo} listo (dim $dim) en '
          '${DateTime.now().difference(t0).inMilliseconds} ms');
      return GuiaEmbedder._(engine, manifest, dim);
    } catch (e) {
      debugPrint('[GuiaEmbedder] No se pudo cargar el modelo: $e');
      return null;
    }
  }

  /// Vector de una consulta del usuario (con prefijo `query: `).
  Future<Float32List?> consulta(String texto) async {
    if (_cerrado) return null;
    try {
      final r = await _engine.embed(manifest.prefijoConsulta + _recortar(texto), normalize: true);
      return _normalizado(r.vector);
    } catch (e) {
      debugPrint('[GuiaEmbedder] embed consulta falló: $e');
      return null;
    }
  }

  /// Vectores de varios textos ya prefijados (ver [prefijarConsulta] /
  /// [prefijarPasaje]). Trabaja de a [tamanoLote]; si un lote falla, cae a
  /// uno por uno para no perder todo.
  Future<List<Float32List>> lote(List<String> textos) async {
    final salida = <Float32List>[];
    for (var i = 0; i < textos.length; i += tamanoLote) {
      final trozo = textos.sublist(i, math.min(i + tamanoLote, textos.length)).map(_recortar).toList();
      try {
        final rs = await _engine.embedBatch(trozo, normalize: true);
        for (final r in rs) {
          salida.add(_normalizado(r.vector));
        }
      } catch (e) {
        debugPrint('[GuiaEmbedder] embedBatch falló (${trozo.length} textos), uno por uno: $e');
        for (final t in trozo) {
          final r = await _engine.embed(t, normalize: true);
          salida.add(_normalizado(r.vector));
        }
      }
    }
    return salida;
  }

  String prefijarConsulta(String t) => manifest.prefijoConsulta + t;
  String prefijarPasaje(String t) => manifest.prefijoPasaje + t;

  /// Corte defensivo por caracteres: ~4 chars/token en español → 512 tokens.
  static String _recortar(String t) => t.length > 1800 ? t.substring(0, 1800) : t;

  /// Garantiza norma 1 aunque el engine no haya normalizado (o el vector
  /// venga como vista sobre un buffer más grande).
  static Float32List _normalizado(Float32List v) {
    var s = 0.0;
    for (final x in v) {
      s += x * x;
    }
    final n = math.sqrt(s);
    final out = Float32List(v.length);
    if (n == 0) return out;
    for (var i = 0; i < v.length; i++) {
      out[i] = v[i] / n;
    }
    return out;
  }

  Future<void> cerrar() async {
    if (_cerrado) return;
    _cerrado = true;
    try {
      await _engine.dispose();
    } catch (_) {}
  }
}
