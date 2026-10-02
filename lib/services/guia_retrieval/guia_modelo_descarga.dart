import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Manifest publicado en Supabase Storage (`guia_modelos/manifest.json`).
/// Plantilla y valores reales: `mini_model_lab/retrieval/manifest_modelo.json`.
class GuiaModeloManifest {
  final String modelo;
  final String version;
  final String archivo;
  final String url;

  /// Si el archivo se sube partido (tope de 50 MB del plan Free), acá van
  /// las URLs de cada parte en orden; la app las concatena.
  final List<String> partes;
  final String sha256;
  final int bytes;
  final int dimension;
  final String prefijoConsulta;
  final String prefijoPasaje;
  final int maxTokens;
  final int minRamMb;

  const GuiaModeloManifest({
    required this.modelo,
    required this.version,
    required this.archivo,
    required this.url,
    required this.partes,
    required this.sha256,
    required this.bytes,
    required this.dimension,
    required this.prefijoConsulta,
    required this.prefijoPasaje,
    required this.maxTokens,
    required this.minRamMb,
  });

  factory GuiaModeloManifest.fromJson(Map<String, dynamic> j) {
    final prefijos = (j['prefijos'] as Map?) ?? const {};
    return GuiaModeloManifest(
      modelo: j['modelo']?.toString() ?? '',
      version: j['version']?.toString() ?? '',
      archivo: j['archivo']?.toString() ?? '',
      url: j['url']?.toString() ?? '',
      partes: List<String>.from((j['partes'] as List?) ?? const []),
      sha256: (j['sha256']?.toString() ?? '').toLowerCase(),
      bytes: (j['bytes'] as num?)?.toInt() ?? 0,
      dimension: (j['dimension'] as num?)?.toInt() ?? 384,
      prefijoConsulta: prefijos['consulta']?.toString() ?? 'query: ',
      prefijoPasaje: prefijos['pasaje']?.toString() ?? 'passage: ',
      maxTokens: (j['max_tokens'] as num?)?.toInt() ?? 512,
      minRamMb: (j['min_ram_mb'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'modelo': modelo,
        'version': version,
        'archivo': archivo,
        'url': url,
        'partes': partes,
        'sha256': sha256,
        'bytes': bytes,
        'dimension': dimension,
        'prefijos': {'consulta': prefijoConsulta, 'pasaje': prefijoPasaje},
        'max_tokens': maxTokens,
        'min_ram_mb': minRamMb,
      };

  bool get valido =>
      archivo.isNotEmpty && sha256.length == 64 && bytes > 0 && (url.isNotEmpty || partes.isNotEmpty);
}

enum GuiaModeloEstado { sinWifi, sinManifest, alDia, descargado, error, deshabilitado }

/// Descarga WiFi-gated del modelo de embeddings a `<documentos>/elguia/modelos/`.
///
/// Mismo patrón que `GuiaOtaSync`: se fija que haya WiFi, consulta Supabase,
/// escribe en documentos. Se dispara desde
/// `GuiaKnowledgeSyncService.verificarYEjecutarSincronizaciones()` a lo sumo
/// una vez por día; el archivo se baja por streaming a un `.part` con
/// reanudación (header Range) y se valida por sha256 antes de renombrarlo.
///
/// El modelo en sí NO vive en Supabase por defecto (50 MB por archivo y
/// 5 GB/mes de egreso en el plan Free): el manifest apunta a Hugging Face.
/// Ver `sql/guia_modelos_bucket.sql`.
class GuiaModeloDescarga {
  static const String bucket = 'guia_modelos';
  static const String nombreManifest = 'manifest.json';
  static const String _prefUltimoChequeo = 'guia_modelo_ultimo_chequeo';
  static const String _prefHabilitado = 'guia_modelo_descarga_habilitada';
  static const String _manifestInstalado = 'manifest_instalado.json';
  static const Duration _intervaloChequeo = Duration(hours: 24);

  /// Se llama cuando hay un modelo nuevo verificado en disco (Paso 5 lo usa
  /// para construir el índice semántico).
  static void Function(File modelo, GuiaModeloManifest manifest)? onModeloListo;

  /// Progreso 0..1 de la descarga en curso (para mostrar en el panel admin).
  static final ValueNotifier<double?> progreso = ValueNotifier<double?>(null);

  static Future<Directory> _dirModelos() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}/elguia/modelos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Manifest del modelo que YA está instalado y verificado, o null.
  static Future<GuiaModeloManifest?> manifestInstalado() async {
    try {
      final dir = await _dirModelos();
      final f = File('${dir.path}/$_manifestInstalado');
      if (!await f.exists()) return null;
      final m = GuiaModeloManifest.fromJson(json.decode(await f.readAsString()) as Map<String, dynamic>);
      final modelo = File('${dir.path}/${m.archivo}');
      if (!await modelo.exists() || await modelo.length() != m.bytes) return null;
      return m;
    } catch (_) {
      return null;
    }
  }

  /// Archivo del modelo instalado (verificado por tamaño), o null.
  static Future<File?> modeloInstalado() async {
    final m = await manifestInstalado();
    if (m == null) return null;
    final dir = await _dirModelos();
    return File('${dir.path}/${m.archivo}');
  }

  /// Punto de entrada desde la sincronización. Respeta el intervalo de
  /// chequeo salvo [forzar]. Nunca lanza: devuelve el estado.
  static Future<GuiaModeloEstado> verificarYDescargar({bool forzar = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_prefHabilitado) ?? true)) return GuiaModeloEstado.deshabilitado;

      if (!forzar) {
        final ultimo = prefs.getString(_prefUltimoChequeo);
        if (ultimo != null) {
          final t = DateTime.tryParse(ultimo);
          if (t != null && DateTime.now().difference(t) < _intervaloChequeo) {
            return await manifestInstalado() != null ? GuiaModeloEstado.alDia : GuiaModeloEstado.sinManifest;
          }
        }
      }

      // 1. Solo por WiFi (o ethernet), igual que GuiaOtaSync.
      final conexiones = await Connectivity().checkConnectivity();
      final hayWifi = conexiones.any((c) => c == ConnectivityResult.wifi || c == ConnectivityResult.ethernet);
      if (!hayWifi && !forzar) {
        debugPrint('[GuiaModeloDescarga] Sin WiFi: se posterga la descarga del modelo.');
        return GuiaModeloEstado.sinWifi;
      }

      // 2. Manifest remoto.
      final remoto = await _bajarManifest();
      await prefs.setString(_prefUltimoChequeo, DateTime.now().toIso8601String());
      if (remoto == null || !remoto.valido) {
        debugPrint('[GuiaModeloDescarga] Manifest ausente o inválido en $bucket/$nombreManifest.');
        return GuiaModeloEstado.sinManifest;
      }

      // 3. ¿Ya está?
      final local = await manifestInstalado();
      if (local != null && local.sha256 == remoto.sha256 && local.version == remoto.version) {
        return GuiaModeloEstado.alDia;
      }

      // 4. Descargar + verificar.
      final dir = await _dirModelos();
      final destino = File('${dir.path}/${remoto.archivo}');
      final ok = await _descargarVerificado(remoto, destino);
      if (!ok) return GuiaModeloEstado.error;

      await File('${dir.path}/$_manifestInstalado').writeAsString(json.encode(remoto.toJson()));
      await _limpiarViejos(dir, conservar: {remoto.archivo, _manifestInstalado});
      debugPrint('[GuiaModeloDescarga] Modelo ${remoto.modelo} ${remoto.version} instalado '
          '(${(remoto.bytes / 1048576).toStringAsFixed(1)} MB).');
      onModeloListo?.call(destino, remoto);
      return GuiaModeloEstado.descargado;
    } catch (e) {
      debugPrint('[GuiaModeloDescarga] Error: $e');
      return GuiaModeloEstado.error;
    } finally {
      progreso.value = null;
    }
  }

  static Future<GuiaModeloManifest?> _bajarManifest() async {
    try {
      final url = Supabase.instance.client.storage.from(bucket).getPublicUrl(nombreManifest);
      final r = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      return GuiaModeloManifest.fromJson(json.decode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[GuiaModeloDescarga] No se pudo leer el manifest: $e');
      return null;
    }
  }

  /// Baja `url` (o concatena `partes`) a `destino.part`, reanudando si hay un
  /// `.part` previo, y lo renombra solo si el sha256 coincide.
  static Future<bool> _descargarVerificado(GuiaModeloManifest m, File destino) async {
    final parcial = File('${destino.path}.part');
    final fuentes = m.partes.isNotEmpty ? m.partes : [m.url];
    final cliente = http.Client();
    try {
      var yaBajado = await parcial.exists() ? await parcial.length() : 0;
      if (yaBajado > m.bytes) {
        await parcial.delete();
        yaBajado = 0;
      }
      // Con varias partes no se reanuda (habría que mapear offsets): se empieza de cero.
      if (fuentes.length > 1 && yaBajado > 0) {
        await parcial.delete();
        yaBajado = 0;
      }

      final salida = parcial.openWrite(mode: yaBajado > 0 ? FileMode.append : FileMode.write);
      var total = yaBajado;
      try {
        for (final fuente in fuentes) {
          final req = http.Request('GET', Uri.parse(fuente));
          if (fuentes.length == 1 && yaBajado > 0) req.headers['Range'] = 'bytes=$yaBajado-';
          final resp = await cliente.send(req).timeout(const Duration(seconds: 30));
          if (resp.statusCode == 200 && yaBajado > 0 && fuentes.length == 1) {
            // El servidor ignoró el Range: empezar de cero.
            await salida.close();
            await parcial.writeAsBytes(const []);
            return await _descargarVerificado(m, destino);
          }
          if (resp.statusCode != 200 && resp.statusCode != 206) {
            debugPrint('[GuiaModeloDescarga] HTTP ${resp.statusCode} bajando $fuente');
            return false;
          }
          await for (final chunk in resp.stream.timeout(const Duration(seconds: 60))) {
            salida.add(chunk);
            total += chunk.length;
            progreso.value = (total / m.bytes).clamp(0.0, 1.0);
          }
        }
      } finally {
        await salida.close();
      }

      if (await parcial.length() != m.bytes) {
        debugPrint('[GuiaModeloDescarga] Tamaño distinto al del manifest (${await parcial.length()} vs ${m.bytes}).');
        return false;
      }
      final hash = await _sha256DeArchivo(parcial);
      if (hash != m.sha256) {
        debugPrint('[GuiaModeloDescarga] sha256 no coincide: $hash vs ${m.sha256}. Se descarta.');
        await parcial.delete();
        return false;
      }
      if (await destino.exists()) await destino.delete();
      await parcial.rename(destino.path);
      return true;
    } catch (e) {
      debugPrint('[GuiaModeloDescarga] Descarga interrumpida (se reanuda la próxima vez): $e');
      return false;
    } finally {
      cliente.close();
    }
  }

  static Future<String> _sha256DeArchivo(File f) async {
    final digest = await sha256.bind(f.openRead()).first;
    return digest.toString();
  }

  static Future<void> _limpiarViejos(Directory dir, {required Set<String> conservar}) async {
    try {
      await for (final e in dir.list()) {
        if (e is! File) continue;
        final nombre = e.uri.pathSegments.last;
        if (conservar.contains(nombre) || nombre.endsWith('.part')) continue;
        if (nombre.endsWith('.gguf') || nombre.endsWith('.json')) await e.delete();
      }
    } catch (_) {}
  }

  /// Borra el modelo instalado (para liberar espacio desde ajustes).
  static Future<void> desinstalar() async {
    try {
      final dir = await _dirModelos();
      await for (final e in dir.list()) {
        if (e is File) await e.delete();
      }
    } catch (_) {}
  }

  /// Permite apagar la descarga automática desde ajustes.
  static Future<void> habilitarDescargaAutomatica(bool habilitada) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefHabilitado, habilitada);
  }
}
