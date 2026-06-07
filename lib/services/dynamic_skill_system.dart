import 'package:flutter/material.dart';

/// Clase base abstracta para habilidades del sistema integrables dinámicamente en la UI.
abstract class DynamicSystemSkill {
  /// Identificador único del módulo.
  String get id;

  /// Nombre del módulo para mostrar en los títulos de la interfaz.
  String get name;

  /// Icono descriptivo de la funcionalidad.
  IconData get icon;

  /// Genera el widget de interfaz de usuario (Card o Panel) de configuración.
  Widget buildConfigCard(BuildContext context);
}

/// Registro global de habilidades de sistema inyectadas dinámicamente.
class SystemSkillRegistry {
  static final List<DynamicSystemSkill> _skills = [];

  /// Expone los módulos registrados de forma inmutable.
  static List<DynamicSystemSkill> get skills => List.unmodifiable(_skills);

  /// Registra una nueva habilidad en el sistema si aún no está registrada.
  static void register(DynamicSystemSkill skill) {
    if (!_skills.any((s) => s.id == skill.id)) {
      _skills.add(skill);
      print('🚀 [SKILL REGISTRY] Módulo registrado exitosamente: ${skill.name} (${skill.id})');
    }
  }

  /// Limpia los registros (principalmente para pruebas).
  @visibleForTesting
  static void clear() {
    _skills.clear();
  }
}
