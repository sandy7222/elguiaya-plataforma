class ElGuiaRespuesta {
  /// Texto de la respuesta para mostrar en burbuja y TTS.
  final String texto;

  /// Estado del GIF del robot sugerido para esta respuesta.
  /// Ejemplos: 'chiste', 'hablaConMate', 'rieGana', 'exito', 'piensaLeve'
  final String gifSugerido;

  /// Si es true, el humor fue inyectado contextualmente (no solicitado)
  final bool esHumorContextual;

  /// Si es true, la respuesta provino de Gemini (modo online).
  final bool origenGemini;

  /// Si no es nulo, gatilla la navegación a esta ruta en la app.
  final String? rutaNavegacion;

  // Propiedades para estandarizar la comunicación y manejo de errores
  final bool exito;
  final String? mensaje;
  final String? error;
  final String tipoError; // 'network'|'timeout'|'parse'|'none'

  const ElGuiaRespuesta({
    required this.texto,
    this.gifSugerido = 'hablaConMate',
    this.esHumorContextual = false,
    this.origenGemini = false,
    this.rutaNavegacion,
    this.exito = true,
    this.mensaje,
    this.error,
    this.tipoError = 'none',
  });

  /// Constructor exitoso compatible con los servicios y la UI
  const ElGuiaRespuesta.ok(String? msg)
      : texto = msg ?? '',
        gifSugerido = 'hablaConMate',
        esHumorContextual = false,
        origenGemini = false,
        rutaNavegacion = null,
        exito = true,
        mensaje = msg,
        error = null,
        tipoError = 'none';

  /// Constructor de fallo compatible con los servicios y la UI
  const ElGuiaRespuesta.fallo(String? err, String tipoErr)
      : texto = 'Chamigo, no me pude conectar con el motor de IA en este momento.',
        gifSugerido = 'piensaLeve',
        esHumorContextual = false,
        origenGemini = false,
        rutaNavegacion = null,
        exito = false,
        mensaje = null,
        error = err,
        tipoError = tipoErr;

  /// Respuesta de texto simple con GIF por defecto
  factory ElGuiaRespuesta.simple(String texto) =>
      ElGuiaRespuesta(texto: texto);

  /// Respuesta de chiste con GIF de risa
  factory ElGuiaRespuesta.chiste(String texto, String gif) =>
      ElGuiaRespuesta(texto: texto, gifSugerido: gif);

  /// Respuesta con humor contextual inyectado
  factory ElGuiaRespuesta.humorContextual(String texto, String gif) =>
      ElGuiaRespuesta(
        texto: texto,
        gifSugerido: gif,
        esHumorContextual: true,
      );

  @override
  String toString() => 'ElGuiaRespuesta(gif: $gifSugerido, texto: $texto, exito: $exito)';
}
