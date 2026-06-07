import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// GroqConfig — Configuración y almacenamiento persistente para el motor Groq.
class GroqConfig {
  static const String _keyApiKey = 'groq_api_key';
  static const String _keyModel  = 'groq_model';

  static const String defaultModel = 'llama-3.3-70b-versatile';

  static String _apiKey = const String.fromEnvironment('GROQ_API_KEY');
  static String _modelo = defaultModel;

  static String get apiKey => _apiKey;
  static String get modelo => _modelo;

  static bool get tieneApiKey => _apiKey.trim().isNotEmpty;

  /// Carga la clave API y el modelo desde SharedPreferences,
  /// con fallback a la variable de entorno de compilación.
  static Future<void> cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _apiKey = prefs.getString(_keyApiKey) ?? const String.fromEnvironment('GROQ_API_KEY');
      _modelo = prefs.getString(_keyModel) ?? defaultModel;
    } catch (e) {
      debugPrint('⚠️ [GroqConfig] Error al cargar configuración: $e');
    }
  }

  /// Guarda la clave API de Groq de forma persistente.
  static Future<void> setApiKey(String key) async {
    _apiKey = key.trim();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyApiKey, _apiKey);
    } catch (e) {
      debugPrint('⚠️ [GroqConfig] Error al guardar API Key: $e');
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
}
