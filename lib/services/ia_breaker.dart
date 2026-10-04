import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
import 'groq_service.dart' show GroqEstadoException;

/// Circuit breaker de la nube (paso 1.6, flag `guia_breaker`).
///
/// Si Groq falla o tarda, la nube queda "abierta" 60 s: mientras tanto el router va
/// directo al motor offline, sin esperar. Pasados los 60 s se deja pasar UN pedido de
/// prueba; si sale bien se cierra, si falla de nuevo se abre 5 min. Un 402 o un 429
/// (sin cuota, demasiados pedidos) abre de inmediato por 5 min.
///
/// Es estado de la sesión, en memoria: al reabrir la app arranca cerrado.
class IABreaker {
  static const String prefBreaker = 'guia_breaker';
  static bool habilitado = true;

  static void aplicarFlags(SharedPreferences prefs) {
    habilitado = prefs.getBool(prefBreaker) ?? habilitado;
  }

  static const Duration _aperturaCorta = Duration(seconds: 60);
  static const Duration _aperturaLarga = Duration(minutes: 5);

  /// Cuánto se espera a la nube antes de contestar con el motor local. Con el flag
  /// apagado vuelve a los 12 s de antes.
  static Duration get timeoutNube =>
      timeoutParaTest ?? (habilitado ? const Duration(seconds: 6) : const Duration(seconds: 12));

  @visibleForTesting
  static Duration? timeoutParaTest;

  @visibleForTesting
  static DateTime Function()? relojParaTest;

  static DateTime? _abiertoHasta;
  static bool _probando = false;
  static int _fallosSeguidos = 0;

  static DateTime _ahora(DateTime? ahora) => ahora ?? relojParaTest?.call() ?? DateTime.now();

  /// Deja el breaker cerrado y sin historia.
  static void reiniciar() {
    _abiertoHasta = null;
    _probando = false;
    _fallosSeguidos = 0;
  }

  /// ¿Se puede llamar a la nube ahora? Cerrado: sí. Abierto: no, hasta que pasa el
  /// tiempo; entonces sí, pero solo para UN pedido de prueba.
  static bool permite([DateTime? ahora]) {
    if (!habilitado) return true;
    final hasta = _abiertoHasta;
    if (hasta == null) return true;
    if (_ahora(ahora).isBefore(hasta)) return false;
    if (_probando) return false;
    _probando = true;
    return true;
  }

  static void registrarExito() {
    if (!habilitado) return;
    reiniciar();
  }

  /// La nube falló o tardó. [status] es el código HTTP si lo hubo (402/429 abren 5 min).
  static void registrarFallo(DateTime? ahora, {int? status}) {
    if (!habilitado) return;
    _probando = false;
    _fallosSeguidos++;
    final inmediato = status == 402 || status == 429;
    final duracion = (inmediato || _fallosSeguidos >= 2) ? _aperturaLarga : _aperturaCorta;
    _abiertoHasta = _ahora(ahora).add(duracion);
  }

  /// El código HTTP que trae un error de la nube, o null (timeout, sin red...).
  static int? estadoDe(Object error) {
    if (error is GroqEstadoException) return error.status;
    if (error is FunctionException) return error.status;
    return null;
  }
}
