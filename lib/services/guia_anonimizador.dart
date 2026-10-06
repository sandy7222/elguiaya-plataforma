/// Limpieza de datos personales ANTES de guardar una pregunta (Fase 2, paso 2.1).
///
/// Borra (y deja el marcador `[borrado]`):
///   · correos electrónicos y direcciones web;
///   · teléfonos, DNI, CBU y cualquier secuencia de 6 o más dígitos (con o sin separadores);
///   · lo que sigue a "me llamo", "mi nombre es" o "soy" (hasta 3 palabras: el nombre).
///
/// Es una red de seguridad, no una garantía: no detecta un nombre dicho sin "me llamo" o "soy"
/// ("pasale el mensaje a Carlos"). Por eso el registro también guarda solo el día y no la hora, y por
/// eso la subida de preguntas (2.2) pide el consentimiento del usuario antes del lanzamiento.
class GuiaAnonimizador {
  static const String marcador = '[borrado]';

  static final RegExp _correo = RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(?:\.[A-Za-z0-9\-]+)+');
  static final RegExp _web = RegExp(r'(?:https?://|www\.)\S+', caseSensitive: false);

  /// Una secuencia que empieza y termina en dígito y tiene 6 o más caracteres de largo; solo se
  /// borra si en total trae 6 o más dígitos ("0,8 mm" o "20 libras" no).
  static final RegExp _numeros = RegExp(r'[+(]?\d[\d ().\-]{4,}\d');

  static final RegExp _nombre = RegExp(
    r'\b(me llamo|mi nombre es|soy)\s+(?:(?:el|la|un|una)\s+)?[\p{L}.\-]+(?:\s+[\p{L}.\-]+){0,2}',
    caseSensitive: false,
    unicode: true,
  );

  static String limpiar(String texto) {
    if (texto.isEmpty) return texto;
    var t = texto;
    t = t.replaceAll(_correo, marcador);
    t = t.replaceAll(_web, marcador);
    t = t.replaceAllMapped(_numeros, (m) {
      final digitos = m[0]!.replaceAll(RegExp(r'\D'), '').length;
      return digitos >= 6 ? marcador : m[0]!;
    });
    t = t.replaceAllMapped(_nombre, (m) => '${m[1]} $marcador');
    return t;
  }
}
