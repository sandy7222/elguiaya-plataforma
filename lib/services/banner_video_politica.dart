import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Fase R, R.3b: cuándo se reproduce el video de un banner.
///
/// Los videos son la mayor fuente de crecimiento de memoria medida en el Moto G15 (ver
/// `docs/INFORME_MEMORIA_R1.md`). Regla: solo se reproduce lo que se ve (pestaña visible y app en primer plano),
/// y en equipos de 4 GB o menos no se reproduce video: se muestra una imagen fija.
class BannerVideoPolitica {
  /// Hasta esta RAM total (MB) el equipo se considera liviano. El Moto G15 informa ~3,8 GB.
  static const int ramMaxEquipoLivianoMb = 4096;

  static const MethodChannel _canal = MethodChannel('capitanya/dispositivo');
  static int? _ramMb;
  static bool _medida = false;

  static bool esEquipoLiviano(int? ramMb) => ramMb != null && ramMb <= ramMaxEquipoLivianoMb;

  static bool debeReproducir({required bool visible, required bool appActiva, required int? ramMb}) =>
      visible && appActiva && !esEquipoLiviano(ramMb);

  /// RAM total del equipo en MB, o null si no se pudo medir (web, iOS, error). Se mide una sola vez.
  static Future<int?> ramTotalMb() async {
    if (_medida) return _ramMb;
    try {
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        _ramMb = await _canal.invokeMethod<int>('ramTotalMb');
      }
    } catch (e) {
      debugPrint('No se pudo medir la RAM: $e');
    }
    _medida = true;
    return _ramMb;
  }
}
