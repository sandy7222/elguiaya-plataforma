void main() {
  final String pregunta1 = 'mi nombre es Seba Borrego';
  final String pregunta2 = 'me llamo Seba';
  final String pregunta3 = 'soy Seba Borrego';
  
  final RegExp nameRegExp = RegExp(
    r'\b(?:me llamo|mi nombre es|soy)\s+([a-zA-ZáéíóúÁÉÍÓÚñÑ]{3,15})\b',
    caseSensitive: false,
  );
  
  void test(String pregunta) {
    final match = nameRegExp.firstMatch(pregunta);
    if (match != null) {
      final posibleNombre = match.group(1)!;
      final palabrasExcluidas = ['principiante', 'intermedio', 'avanzado', 'experto', 'novato', 'pescador', 'guia', 'capitan', 'el', 'un', 'una', 'triste', 'feliz', 'hola', 'amigo', 'chamigo'];
      if (!palabrasExcluidas.contains(posibleNombre.toLowerCase())) {
        final nombreFormateado = posibleNombre[0].toUpperCase() + posibleNombre.substring(1).toLowerCase();
        print('Pregunta: "$pregunta" => Detectado: "$nombreFormateado"');
      } else {
        print('Pregunta: "$pregunta" => Detectado "$posibleNombre" pero está en la lista de excluidos');
      }
    } else {
      print('Pregunta: "$pregunta" => No se detectó ninguna coincidencia.');
    }
  }

  test(pregunta1);
  test(pregunta2);
  test(pregunta3);
}
