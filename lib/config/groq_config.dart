import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Configuración pública de Groq. Las claves viven exclusivamente como secretos
/// de la Edge Function y no se aceptan ni se persisten en Flutter.
class GroqConfig {
  // ── Claves de SharedPreferences ───────────────────────────────────────────
  static const String _keyGuia       = 'groq_api_key_guia';
  static const String _keyCentralita = 'groq_api_key_centralita';
  static const String _keyModel      = 'groq_model';

  // ── Clave legada (para migración automática) ──────────────────────────────
  static const String _keyLegado     = 'groq_api_key';

  static const String defaultModel = 'openai/gpt-oss-120b';

  // ── Estado interno ────────────────────────────────────────────────────────
  // Fase 0: el cliente no conserva ni recibe claves de proveedor.
  static String _apiKeyGuia = '';
  static String _apiKeyCentralita = '';
  static String _modelo           = defaultModel;


  // ── Getters públicos ──────────────────────────────────────────────────────

  static String get modelo => _modelo;
  static bool get iaOnlineHabilitada => true;

  @Deprecated('Las claves no se exponen al cliente.')
  static String get apiKey => '';
  @Deprecated('Las claves no se exponen al cliente.')
  static String get apiKeyGuia => '';
  @Deprecated('Las claves no se exponen al cliente.')
  static String get apiKeyCentralita => '';
  static bool get tieneApiKey => iaOnlineHabilitada;
  static bool get tieneApiKeyCentralita => iaOnlineHabilitada;

  // ── Carga ─────────────────────────────────────────────────────────────────

  /// Elimina credenciales de instalaciones anteriores sin leerlas ni mostrarlas.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_keyLegado);
      await prefs.remove(_keyGuia);
      await prefs.remove(_keyCentralita);
      _apiKeyGuia = '';
      _apiKeyCentralita = '';

      _modelo = prefs.getString(_keyModel) ?? defaultModel;

      debugPrint('[GroqConfig] IA online deshabilitada en cliente (Fase 0).');
    } catch (e) {
      debugPrint('⚠️ [GroqConfig] Error al cargar configuración: $e');
    }
  }

  // ── Setters ───────────────────────────────────────────────────────────────

  /// Ya no se admite almacenar claves de proveedor en el dispositivo.
  static Future<void> setApiKey(String key) async {
    await _rechazarClaveLocal(key);
  }

  static Future<void> setApiKeyGuia(String key) async {
    await _rechazarClaveLocal(key);
  }

  static Future<void> setApiKeyCentralita(String key) async {
    await _rechazarClaveLocal(key);
  }

  static Future<void> _rechazarClaveLocal(String key) async {
    if (key.trim().isNotEmpty) {
      throw UnsupportedError('Las claves de Groq se configuran como secretos de la Edge Function.');
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
    return 'Proveedor: Edge Function | Modelo: $_modelo';
  }
}
