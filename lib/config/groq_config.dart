import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GroqConfig — Claves API y modelo Groq para todos los servicios de la app.
///
/// Hay DOS claves independientes para que la centralita y El Guía
/// no se pisen nunca entre sí:
///   • _keyGuia       → clave de El Guía (asistente del robot flotante)
///   • _keyCentralita → clave de la Centralita (uso administrativo/operativo)
///
/// Si solo tenés una clave en Groq, ponela en ambos campos — o dejá
/// la centralita vacía y El Guía usará su propia.
class GroqConfig {
  // ── Claves de SharedPreferences ───────────────────────────────────────────
  static const String _keyGuia       = 'groq_api_key_guia';
  static const String _keyCentralita = 'groq_api_key_centralita';
  static const String _keyModel      = 'groq_model';

  // ── Clave legada (para migración automática) ──────────────────────────────
  static const String _keyLegado     = 'groq_api_key';
  static const String _fallbackGuia = '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';
  static const String _fallbackCentralita = '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';

  static const String defaultModel = 'llama-3.3-70b-versatile';

  // ── Estado interno ────────────────────────────────────────────────────────
  // Prioridad: variable específica → variable legada → fallback
  static String _apiKeyGuia = const String.fromEnvironment('GROQ_API_KEY_GUIA',
              defaultValue: String.fromEnvironment('GROQ_API_KEY'))
          .isNotEmpty
      ? const String.fromEnvironment('GROQ_API_KEY_GUIA',
          defaultValue: String.fromEnvironment('GROQ_API_KEY'))
      : _fallbackGuia;
  static String _apiKeyCentralita = const String.fromEnvironment(
              'GROQ_API_KEY_CENTRALITA',
              defaultValue: String.fromEnvironment('GROQ_API_KEY'))
          .isNotEmpty
      ? const String.fromEnvironment('GROQ_API_KEY_CENTRALITA',
          defaultValue: String.fromEnvironment('GROQ_API_KEY'))
      : _fallbackCentralita;
  static String _modelo           = defaultModel;


  // ── Getters públicos ──────────────────────────────────────────────────────

  /// Clave que usa El Guía (robot flotante / BaqueanoIAService).
  static String get apiKey        => _apiKeyGuia;
  static String get apiKeyGuia    => _apiKeyGuia;

  /// Clave que usa la Centralita (panel administrativo).
  static String get apiKeyCentralita => _apiKeyCentralita;

  static String get modelo => _modelo;

  static bool get tieneApiKey          => _apiKeyGuia.trim().isNotEmpty;
  static bool get tieneApiKeyCentralita => _apiKeyCentralita.trim().isNotEmpty;

  // ── Carga ─────────────────────────────────────────────────────────────────

  /// Carga ambas claves desde SharedPreferences.
  /// Migra automáticamente la clave legada si existe y las nuevas están vacías.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Migración: si existe la clave vieja y las nuevas están vacías, la usamos
      final keyLegada = prefs.getString(_keyLegado) ?? '';
      final keyEnv    = const String.fromEnvironment('GROQ_API_KEY');

      _apiKeyGuia = prefs.getString(_keyGuia) ?? '';
      if (_apiKeyGuia.isEmpty) {
        _apiKeyGuia = keyLegada.isNotEmpty
            ? keyLegada
            : (keyEnv.isNotEmpty ? keyEnv : _fallbackGuia);
      }

      _apiKeyCentralita = prefs.getString(_keyCentralita) ?? '';
      if (_apiKeyCentralita.isEmpty) {
        _apiKeyCentralita = keyLegada.isNotEmpty
            ? keyLegada
            : (keyEnv.isNotEmpty ? keyEnv : _fallbackCentralita);
      }

      _modelo = prefs.getString(_keyModel) ?? defaultModel;

      debugPrint('[GroqConfig] ✅ Guía key: ${_apiKeyGuia.isNotEmpty ? '${_apiKeyGuia.substring(0, 8)}...' : 'VACÍA'}');
      debugPrint('[GroqConfig] ✅ Centralita key: ${_apiKeyCentralita.isNotEmpty ? '${_apiKeyCentralita.substring(0, 8)}...' : 'VACÍA'}');
    } catch (e) {
      debugPrint('⚠️ [GroqConfig] Error al cargar configuración: $e');
    }
  }

  // ── Setters ───────────────────────────────────────────────────────────────

  /// Guarda la clave de El Guía de forma persistente.
  static Future<void> setApiKey(String key) async {
    await setApiKeyGuia(key);
  }

  /// Guarda la clave de El Guía de forma persistente.
  static Future<void> setApiKeyGuia(String key) async {
    _apiKeyGuia = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyGuia, _apiKeyGuia);
      debugPrint('[GroqConfig] 💾 Clave El Guía guardada: ${_apiKeyGuia.substring(0, 8)}...');
    } catch (e) {
      debugPrint('⚠️ [GroqConfig] Error al guardar clave Guía: $e');
    }
  }

  /// Guarda la clave de la Centralita de forma persistente.
  static Future<void> setApiKeyCentralita(String key) async {
    _apiKeyCentralita = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyCentralita, _apiKeyCentralita);
      debugPrint('[GroqConfig] 💾 Clave Centralita guardada: ${_apiKeyCentralita.substring(0, 8)}...');
    } catch (e) {
      debugPrint('⚠️ [GroqConfig] Error al guardar clave Centralita: $e');
    }
  }

  /// Guarda el modelo de Groq de forma persistente.
  static Future<void> setModelo(String model) async {
    _modelo = model.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyModel, _modelo);
    } catch (e) {
      debugPrint('⚠️ [GroqConfig] Error al guardar modelo: $e');
    }
  }

  // ── Diagnóstico ───────────────────────────────────────────────────────────

  /// Devuelve un string de estado para mostrar en UI de diagnóstico.
  static String get estadoDiagnostico {
    final guia = _apiKeyGuia.isNotEmpty
        ? '${_apiKeyGuia.substring(0, 8)}...'
        : 'SIN CLAVE';
    final centralita = _apiKeyCentralita.isNotEmpty
        ? '${_apiKeyCentralita.substring(0, 8)}...'
        : 'SIN CLAVE';
    return 'Guía: $guia | Centralita: $centralita | Modelo: $_modelo';
  }
}
