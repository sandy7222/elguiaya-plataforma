import 'package:flutter/services.dart';

/// Formatter que capitaliza la primera letra de cada palabra a medida que se
/// escribe (ej: "juan carlos perez" -> "Juan Carlos Perez").
///
/// Se usa en formularios de datos personales/domicilio para normalizar la
/// entrada del usuario sin depender del teclado del dispositivo.
class PalabrasCapitalizadasFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final texto = newValue.text;
    if (texto.isEmpty) return newValue;

    final capitalizado = texto.split(' ').map((palabra) {
      if (palabra.isEmpty) return palabra;
      final primera = palabra.substring(0, 1).toUpperCase();
      final resto = palabra.length > 1 ? palabra.substring(1) : '';
      return '$primera$resto';
    }).join(' ');

    // Mantener la posición del cursor tal como venía en newValue.
    return newValue.copyWith(
      text: capitalizado,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}
