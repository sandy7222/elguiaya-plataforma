enum GuiaRol { redactor, guiaNacional, soporteApp }

class GuiaRolService {
  
  // Detecta automáticamente el rol según el contexto
  static GuiaRol detectarRol(String texto, {bool esBlog = false}) {
    if (esBlog) return GuiaRol.redactor;
    
    final pq = texto.toLowerCase();
    
    // Soporte app
    if (_esConsultaApp(pq)) return GuiaRol.soporteApp;
    
    // Por defecto → Guía Nacional
    return GuiaRol.guiaNacional;
  }

  // Detecta la zona geográfica mencionada
  static String detectarZona(String texto) {
    final pq = texto.toLowerCase();
    
    if (_esPatagonia(pq)) return 'patagonia';
    if (_esMar(pq)) return 'mar_argentino';
    if (_esLitoral(pq)) return 'litoral_parana';
    if (_esLagunas(pq)) return 'lagunas_pampeanas';
    if (_esNoroeste(pq)) return 'noroeste';
    
    return 'general'; // Sin zona específica
  }

  // Palabras clave por región
  static bool _esPatagonia(String pq) => [
    'bariloche', 'neuquén', 'neuquen', 'río negro', 'rio negro',
    'chubut', 'santa cruz', 'tierra del fuego', 'ushuaia',
    'junín de los andes', 'esquel', 'trucha', 'salmón', 'salmon',
    'perca', 'fly fishing', 'mosca patagonia'
  ].any((k) => pq.contains(k));

  static bool _esMar(String pq) => [
    'mar del plata', 'necochea', 'miramar', 'san clemente',
    'bahía blanca', 'bahia blanca', 'san blas', 'viedma',
    'corvina', 'lenguado', 'pescadilla', 'mar argentino',
    'costa atlántica', 'costa atlantica', 'playa', 'olas'
  ].any((k) => pq.contains(k));

  static bool _esLagunas(String pq) => [
    'chascomús', 'chascomus', 'general belgrano', 'monte',
    'lobos', 'las flores', 'mar chiquita', 'laguna',
    'pejerrey', 'tararira', 'carpa', 'laguna pampeana'
  ].any((k) => pq.contains(k));

  static bool _esLitoral(String pq) => [
    'paraná', 'parana', 'uruguay', 'corrientes', 'misiones',
    'entre ríos', 'entre rios', 'chaco', 'formosa',
    'dorado', 'surubí', 'surubi', 'patí', 'pati', 'boga',
    'paso de la patria', 'esquina', 'goya', 'reconquista'
  ].any((k) => pq.contains(k));

  static bool _esNoroeste(String pq) => [
    'tucumán', 'tucuman', 'salta', 'jujuy', 'santiago del estero',
    'bermejo', 'juramento', 'salí', 'sali'
  ].any((k) => pq.contains(k));

  // Detecta consultas orientadas al soporte de la app y sus funciones
  static bool _esConsultaApp(String pq) {
    const keywords = [
      'como funciona', 'cómo funciona', 'no encuentro', 'donde esta', 'dónde está',
      'como hago', 'cómo hago', 'ayuda con la app', 'para que sirve', 'para qué sirve',
      'no se usar', 'no sé usar', 'como uso', 'cómo uso', 'no entiendo la app',
      'me explicas la app', 'no puedo entrar', 'como entro a', 'cómo entro a',
      'abrir mapa', 'no veo mi ubicacion', 'como reservo', 'cómo reservo',
      'como comprar', 'cómo comprar', 'mi cuenta', 'cambiar contraseña',
      'cambiar foto', 'como usar el gps', 'cómo usar el gps', 'boton sos',
      'crear viaje', 'ver cotizaciones', 'pagar viaje', 'confirmar viaje',
      'calificar capitan', 'notificaciones', 'perfil', 'asistente flotante',
      'historial de viajes', 'tienda', 'carrito'
    ];
    return keywords.any((k) => pq.contains(k));
  }
}
