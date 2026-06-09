import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'el_guia_context.dart';
import 'guia_clima_service.dart';
import 'guia_rol_service.dart';

/// CapacitacionService — Gestiona el JSON de capacitación de Gemini.
///
/// Estrategia de carga (fallback en cascada):
///   1. Supabase (tabla guia_capacitacion) — actualizable sin recompilar
///   2. Assets local (base_conocimiento.json) — siempre disponible
///
/// El JSON resultante se convierte en systemInstruction para cada llamada a Gemini.
class CapacitacionService {
  static const String _assetPath     = 'assets/elguia/capacitacion/base_conocimiento.json';
  static const String _supabaseTable = 'guia_capacitacion';
  static const String _supabaseKey   = 'contenido';

  static Map<String, dynamic>? _cachedJsonDatos;
  static DateTime? _ultimaCarga;
  static const Duration _ttlCache = Duration(hours: 6);

  // ── Caché del conocimiento distribuido aprobado ───────────────────────────
  // Alimentado por guia_conocimiento_distribuido donde aprobado = true.
  // TTL corto (30 min) para reflejar nuevas aprobaciones del admin pronto.
  static List<Map<String, dynamic>> _cacheConocimientoAprobado = [];
  static DateTime? _ultimaCargaDistribuido;
  static const Duration _ttlDistribuido = Duration(minutes: 30);

  // Prompts del Sistema por Rol
  static String obtenerPromptRedactor() {
    return '''Sos el redactor oficial de EL GUIA YA.
Tu única función es redactar notas periodísticas de pesca con lo que el pescador te contó.

REGLAS ABSOLUTAS:
- Solo usás información del relato del pescador
- PROHIBIDO agregar especies no mencionadas
- PROHIBIDO agregar ríos o lugares no mencionados  
- PROHIBIDO inventar capturas, clima o condiciones
- Si no tenés un dato → no lo escribas
- Preferís una nota corta y verdadera a una larga inventada

Estructura de la nota:
1. Título con emoji
2. Dónde y cuándo (solo lo que dijo el pescador)
3. Las condiciones (solo si las mencionó)
4. La pesca (solo especies y técnicas que nombró)
5. El campamento/comida (solo si lo mencionó)
6. Cierre con recomendaciones (solo basadas en lo dicho)''';
  }

  static String obtenerPromptSoporteApp() {
    return '''Sos el asistente de EL GUIA YA.
Tu función es ayudar con la navegación y funciones de la app.
Respondé de forma clara y directa.
Máximo 3 líneas por respuesta.''';
  }

  static String obtenerPromptGuiaNacional(String zona) {
    final buffer = StringBuffer();
    buffer.writeln('''Sos El Guía, experto en toda la pesca deportiva argentina.
Tu conocimiento abarca todo el territorio nacional:

LITORAL (Paraná, Uruguay, Paraguay):
→ Dorado, surubí, boga, sábalo, patí, armado
→ Pesca de fondo, spinning, trolling

LAGUNAS PAMPEANAS (Buenos Aires, La Pampa):
→ Pejerrey, tararira, carpa, bagre, mojarra
→ Pesca de flote, spinning liviano
→ Zonas: Chascomús, General Belgrano, Monte, Lobos, Las Flores, Mar Chiquita

MAR ARGENTINO (Costa Atlántica):
→ Corvina, lenguado, pescadilla, tiburón, brótola, anchoa de banco
→ Pesca de costa y embarcado
→ Zonas: Mar del Plata, Necochea, San Clemente, Bahía Blanca, San Blas

PATAGONIA (Ríos y lagos andinos):
→ Trucha arcoíris, trucha marrón, salmón del Atlántico, pejerrey patagónico, perca
→ Fly fishing, spinning
→ Zonas: Bariloche, Junín de los Andes, Esquel, Río Grande, Ushuaia

NOROESTE (Tucumán, Salta, Jujuy):
→ Dorado, sábalo, bagre, mojarra
→ Ríos: Juramento, Salí, Bermejo

ADAPTACIÓN POR ZONA:
Cuando el pescador mencione una zona → activá el conocimiento específico de esa región.
No asumas que siempre están en el Paraná.''');

    if (zona != 'general') {
      buffer.writeln('\n[CONTEXTO GEOGRÁFICO DETECTADO]: El pescador está consultando sobre la zona: ${zona.toUpperCase()}. Responde enfocándote en las especies y técnicas típicas de esta región.');
    }
    return buffer.toString();
  }

  /// Devuelve la systemInstruction lista para pasarle a Gemini/Ollama.
  /// Cachea los datos base por 6 horas para no recargar en cada consulta,
  /// pero construye el prompt final dinámicamente con el contexto actual.
  static Future<String> obtenerSystemInstruction({ElGuiaContext? contexto}) async {
    Map<String, dynamic> json;
    
    // Usar cache si es reciente
    if (_cachedJsonDatos != null && _ultimaCarga != null &&
        DateTime.now().difference(_ultimaCarga!) < _ttlCache) {
      json = _cachedJsonDatos!;
    } else {
      json = await _cargarJson();
      _cachedJsonDatos = json;
      _ultimaCarga = DateTime.now();
    }

    return _construirInstruction(json, contexto: contexto);
  }

  /// Fuerza recarga (llamar desde admin cuando se actualiza el JSON en Supabase).
  static void invalidarCache() {
    _cachedJsonDatos = null;
    _ultimaCarga = null;
  }

  /// Fuerza recarga del conocimiento distribuido aprobado.
  /// Llamar cuando el admin aprueba una intención desde el panel.
  static void invalidarCacheDistribuido() {
    _cacheConocimientoAprobado = [];
    _ultimaCargaDistribuido = null;
    debugPrint('[CapacitacionService] 🔄 Caché de conocimiento distribuido invalidada — próxima consulta recargará desde Supabase.');
  }

  /// Carga con caché los conocimientos aprobados de guia_conocimiento_distribuido.
  /// Ordenados por veces_preguntado DESC para priorizar el conocimiento más demandado.
  /// En error de red devuelve la caché anterior (stale) para no romper el flujo.
  static Future<List<Map<String, dynamic>>> _cargarConocimientoAprobado() async {
    if (_cacheConocimientoAprobado.isNotEmpty &&
        _ultimaCargaDistribuido != null &&
        DateTime.now().difference(_ultimaCargaDistribuido!) < _ttlDistribuido) {
      return _cacheConocimientoAprobado;
    }
    try {
      final response = await Supabase.instance.client
          .from('guia_conocimiento_distribuido')
          .select('intencion, activadores, respuesta_limpia')
          .eq('aprobado', true)
          .order('veces_preguntado', ascending: false)
          .limit(150);
      _cacheConocimientoAprobado = List<Map<String, dynamic>>.from(response as List? ?? []);
      _ultimaCargaDistribuido = DateTime.now();
      debugPrint('[CapacitacionService] 📚 ${_cacheConocimientoAprobado.length} conocimientos distribuidos cargados en caché');
      return _cacheConocimientoAprobado;
    } catch (e) {
      debugPrint('[CapacitacionService] ⚠️ Error cargando conocimiento distribuido: $e');
      return _cacheConocimientoAprobado; // caché anterior en caso de error de red
    }
  }

  // ── Carga con fallback ────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _cargarJson() async {
    // Intento 1: Supabase
    try {
      final response = await Supabase.instance.client
          .from(_supabaseTable)
          .select(_supabaseKey)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response[_supabaseKey] != null) {
        final contenido = response[_supabaseKey];
        if (contenido is String) {
          return json.decode(contenido) as Map<String, dynamic>;
        } else if (contenido is Map<String, dynamic>) {
          return contenido;
        }
      }
    } catch (_) {
      // Falla silenciosa → usar assets
    }

    // Intento 2: Assets local (siempre disponible)
    return await _cargarDesdeAssets();
  }

  static Future<Map<String, dynamic>> _cargarDesdeAssets() async {
    try {
      final str = await rootBundle.loadString(_assetPath);
      return json.decode(str) as Map<String, dynamic>;
    } catch (_) {
      return _jsonMinimoPorDefecto();
    }
  }

  // ── Constructor de systemInstruction ──────────────────────────────────────

  static String _construirInstruction(Map<String, dynamic> datos, {ElGuiaContext? contexto}) {
    final rol = GuiaRolService.detectarRol(
      contexto?.ultimaConsulta ?? '', 
      esBlog: contexto?.esBlog ?? false
    );

    final zona = GuiaRolService.detectarZona(
      contexto?.ultimaConsulta ?? ''
    );

    // Seleccionar el prompt correcto según el rol
    switch (rol) {
      case GuiaRol.redactor:
        return obtenerPromptRedactor();
      case GuiaRol.soporteApp:
        return obtenerPromptSoporteApp();
      case GuiaRol.guiaNacional:
        return """
${obtenerPromptGuiaNacional(zona)}

=== PROTOCOLO DE APRENDIZAJE AUTOMÁTICO ===
Al final de cada respuesta agregá |||APRENDO||| seguido del JSON de aprendizaje.
Este bloque es COMPLETAMENTE INVISIBLE para el usuario. Nunca lo menciones ni lo expliques.
Si no podés completar el JSON, escribí |||APRENDO|||{} y seguí adelante.
Estructura:
{
  "intencion": "nombre_en_snake_case",
  "activadores": ["frase 1", "frase 2", "frase 3", "frase 4"],
  "respuesta_limpia": "versión compacta de tu respuesta (máximo 120 caracteres)",
  "gif": "hablaConMate|exito|piensaLeve|piensaProfundo|saludo|duda",
  "puntaje": 9,
  "fuente": "conocimiento_propio"
}
""";
    }
  }

  // ── Clasificador de Categorías de Consulta ──────────────────────────────
  // Clasifica la pregunta en una categoría de alto nivel para decidir si
  // vale la pena buscar contexto o si pasar directo a Groq.
  static const _kCharla = {
    'hola', 'buenas', 'chau', 'adios', 'gracias', 'joya', 'dale',
    'como estas', 'como va', 'que tal', 'buena', 'todo bien', 'copado',
    'genial', 'perfecto', 'ok', 'okey', 'si', 'no', 'claro', 'mate',
    'tomas mate', 'chiste', 'cuentame', 'quien sos', 'que sos', 'que haces',
    'para que servis', 'me aburro', 'que dia', 'no pica', 'mucho calor',
    'mucho frio', 'tengo hambre', 'estoy cansado', 'me voy', 'hasta luego',
    'nos vemos', 'buen dia', 'buenas tardes', 'buenas noches',
    'hora', 'que hora', 'decime la hora',
  };

  static const _kTecnica = {
    'pescar', 'pesca', 'pique', 'clavar', 'cavar', 'morder', 'picar',
    'carnada', 'cebo', 'anzuelo', 'linea', 'madre', 'lider', 'brazolada',
    'aparejo', 'armo la linea', 'cana', 'caña', 'reel', 'carrete',
    'plomada', 'plomo', 'satelite', 'torpedo', 'boya', 'flotador',
    'nudo', 'atar', 'unir', 'palomar', 'albright', 'clinch',
    'corriente', 'fondo', 'profundidad',
  };

  static const _kEspecie = {
    'dorado', 'surubi', 'surubí', 'boga', 'bagre', 'pati', 'patí',
    'tararira', 'pejerrey', 'sabalo', 'sábalo', 'pacu', 'pacú',
    'armado', 'mimoso', 'moncholo', 'monchuelo', 'bagre de mar',
    'corvina', 'trucha', 'pejerrey de rio', 'especie', 'pez', 'peces',
  };

  static const _kSeguridad = {
    'espina', 'chuza', 'veneno', 'ponzona', 'ponzoña', 'pinchar',
    'me pico', 'me picó', 'me lastimo', 'me lastimé', 'me corte',
    'herida', 'sangre', 'emergencia', 'socorro', 'auxilio', 'accidente',
    'prefectura', 'pna', 'canal 16', 'vhf', 'radio', 'gomón', 'gomon',
    'supervivencia', 'perdido', 'perdí', 'refugio', 'agua potable',
    'fuego', 'fogata', 'primeros auxilios', 'serpiente', 'vibora', 'víbora',
  };

  static const _kCondiciones = {
    'marea', 'mareas', 'corriente', 'parada de agua', 'turbia', 'clara',
    'crecida', 'bajante', 'tormenta', 'temporal', 'lluvia', 'viento',
    'clima', 'temperatura', 'barometro', 'luna', 'solunar', 'luna nueva',
    'luna llena', 'en que mes', 'temporada', 'cuando sale', 'cuando pica',
  };

  /// Clasificación de la consulta: devuelve la categoría o `null` si es charla.
  /// `null` indica: pasar directo a Groq sin buscar contexto.
  static String? _clasificarConsulta(String query) {
    // Charla cotidiana → contexto innecesario
    for (final kw in _kCharla) {
      if (query.contains(kw)) {
        debugPrint('[CapacitacionService] 💬 Charla detectada — skip contexto');
        return null;
      }
    }
    // Categorías técnicas
    for (final kw in _kSeguridad) {
      if (query.contains(kw)) return 'seguridad';
    }
    for (final kw in _kEspecie) {
      if (query.contains(kw)) return 'especie';
    }
    for (final kw in _kTecnica) {
      if (query.contains(kw)) return 'tecnica';
    }
    for (final kw in _kCondiciones) {
      if (query.contains(kw)) return 'condiciones';
    }
    // Sin match → sin contexto (Groq puede resolverlo con su base general)
    return null;
  }

  // ── Mapa de librería → palabras clave disparadoras ──────────────────────
  static const _kLibrerias = {
    'peces':         ['dorado', 'surubi', 'boga', 'bagre', 'pati', 'tararira', 'pejerrey', 'sabalo', 'pacu', 'armado', 'mimoso', 'moncholo', 'bagre de mar', 'especie', 'pez', 'peces', 'corvina'],
    'carnadas':      ['carnada', 'cebo', 'anchoa', 'calamar', 'sardina', 'lombriz', 'masa', 'encarne', 'que le pongo', 'que pongo'],
    'nudos':         ['nudo', 'atar', 'anzuelo', 'linea', 'unir', 'albright', 'palomar', 'clinch', 'como uno', 'como ato'],
    'boyas':         ['boya', 'flotador', 'chupetona', 'yoyo', 'luminosa', 'corcho'],
    'plomadas':      ['plomada', 'plomo', 'satelite', 'torpedo', 'pera', 'cuanto plomo'],
    'canas_y_reeles':['cana', 'caña', 'reel', 'frontal', 'rotativo', 'equipo de pesca', 'que caña', 'que reel'],
    'rio':           ['rio', 'crecida', 'bajante', 'corriente', 'turbia', 'clara', 'barroso', 'nivel del rio'],
    'emergencia':    ['emergencia', 'socorro', 'accidente', 'lastime', 'herida', 'sangre', 'pna', 'prefectura', 'canal 16'],
    'primeros_auxilios': ['primeros auxilios', 'corte', 'quemadura', 'dolor', 'golpe', 'torcedura'],
    'supervivencia': ['supervivencia', 'perdido', 'perdí', 'aislado', 'solo en la isla', 'refugio', 'agua potable'],
  };

  /// Busca contexto relevante en Supabase y librerías JSON locales
  /// según la categoría clasificada. Si la pregunta es charla cotidiana,
  /// devuelve cadena vacía inmediatamente (sin tocar Supabase ni assets).
  static Future<String> getContextoContextual(String pregunta) async {
    final query = pregunta
        .toLowerCase()
        .replaceAll(RegExp('[áàä]'), 'a')
        .replaceAll(RegExp('[éèë]'), 'e')
        .replaceAll(RegExp('[íìï]'), 'i')
        .replaceAll(RegExp('[óòö]'), 'o')
        .replaceAll(RegExp('[úùü]'), 'u')
        .replaceAll('ñ', 'n')
        .trim();

    final String queryLower = query.toLowerCase();
    final bool esClimaPescaCondicion = queryLower.contains('clima') ||
        queryLower.contains('tiempo') ||
        queryLower.contains('pronostico') ||
        queryLower.contains('viento') ||
        queryLower.contains('ola') ||
        queryLower.contains('solunar') ||
        queryLower.contains('luna') ||
        queryLower.contains('pesca') ||
        queryLower.contains('pique') ||
        queryLower.contains('condicion') ||
        queryLower.contains('marea');

    // ── FASE 1: Clasificación — ¿merece buscar contexto? ─────────────────
    final categoria = _clasificarConsulta(query);
    if (categoria == null && !esClimaPescaCondicion) {
      // Charla o pregunta sin match técnico → directo a Groq
      return '';
    }
    debugPrint('[CapacitacionService] 🔍 Categoría detectada: $categoria (clima/pesca=$esClimaPescaCondicion) — buscando contexto...');

    final buffer = StringBuffer();

    if (esClimaPescaCondicion) {
      final climaCtx = await GuiaClimaService.getResumenParaPesca();
      buffer.writeln(climaCtx);
    }

    // ── FASE 2: Buscar en JSON de capacitación (Supabase o assets) ────────
    try {
      final Map<String, dynamic> datos = _cachedJsonDatos ?? await _cargarJson();
      final palabras = query.split(RegExp(r'\s+')).where((w) => w.length > 3).toList();

      final pesca = datos['conocimiento_pesca'] as Map<String, dynamic>?;
      if (pesca != null) {
        pesca.forEach((key, value) {
          final keyLower = key.toLowerCase();
          final valStr = value.toString().toLowerCase();

          bool coincide = query.contains(keyLower);
          if (!coincide) {
            for (final p in palabras) {
              if (keyLower.contains(p) || valStr.contains(p)) {
                coincide = true;
                break;
              }
            }
          }
          if (coincide) {
            buffer.writeln('- $key: $value');
          }
        });
      }
    } catch (e) {
      debugPrint('[CapacitacionService] Error buscando en JSON de capacitación: $e');
    }

    // ── FASE 3: Buscar en librerías locales solo si la categoría aplica ───
    // Las charlas ya fueron filtradas en Fase 1.
    final libreriasABuscar = <String>[];
    for (final entry in _kLibrerias.entries) {
      for (final kw in entry.value) {
        if (query.contains(kw)) {
          libreriasABuscar.add(entry.key);
          break;
        }
      }
    }

    for (final libreria in libreriasABuscar) {
      try {
        final contentStr = await rootBundle.loadString('assets/elguia/librerias/$libreria.json');
        final decoded = json.decode(contentStr) as Map<String, dynamic>;

        if (decoded.containsKey('respuestas_puente')) {
          final lista = decoded['respuestas_puente'] as List<dynamic>?;
          if (lista != null && lista.isNotEmpty) {
            buffer.writeln('- [${libreria.toUpperCase()}]: ${lista.first}');
          }
        } else if (decoded.containsKey('especies') && libreria == 'peces') {
          final especies = decoded['especies'] as Map<String, dynamic>;
          especies.forEach((espName, espVal) {
            if (query.contains(espName)) {
              final val = espVal as Map<String, dynamic>;
              buffer.writeln('- Especie "$espName": ${val['descripcion']} '
                  'Carnada: ${(val['carnada'] as List?)?.join(', ')}. '
                  'Equipo: ${val['equipo']}. Temporada: ${val['temporada']}.');
            }
          });
        }
      } catch (e) {
        debugPrint('[CapacitacionService] Error cargando $libreria.json: $e');
      }
    }

    // ── FASE 4: guia_conocimiento_distribuido (conocimiento aprendido en charlas anteriores) ──
    // Cada vez que Groq aprende algo nuevo (|||APRENDO|||) y el admin lo aprueba,
    // ese conocimiento queda disponible aquí para enriquecer futuras respuestas.
    // Se inyectan hasta 3 coincidencias para no sobrecargar el contexto.
    try {
      final conocimientoAprobado = await _cargarConocimientoAprobado();
      if (conocimientoAprobado.isNotEmpty) {
        final palabrasClave = query
            .split(RegExp(r'\s+'))
            .where((w) => w.length > 3)
            .toList();

        int matchCount = 0;
        for (final item in conocimientoAprobado) {
          if (matchCount >= 3) break;
          final activadores = List<String>.from(item['activadores'] as List? ?? []);
          final respuesta = item['respuesta_limpia']?.toString() ?? '';
          final intencion = item['intencion']?.toString() ?? '';
          if (respuesta.isEmpty || intencion.startsWith('carencia_')) continue;

          bool coincide = false;
          for (final activador in activadores) {
            final act = activador.toLowerCase();
            // Match directo: el activador está dentro del query completo
            if (query.contains(act)) {
              coincide = true;
              break;
            }
            // Match por palabras clave individuales (>3 chars)
            for (final palabra in palabrasClave) {
              if (act.contains(palabra)) {
                coincide = true;
                break;
              }
            }
            if (coincide) break;
          }

          if (coincide) {
            buffer.writeln('- [CONOCIMIENTO APRENDIDO] $intencion: $respuesta');
            matchCount++;
          }
        }
        if (matchCount > 0) {
          debugPrint('[CapacitacionService] 🎓 $matchCount conocimientos distribuidos inyectados en contexto de Groq');
        }
      }
    } catch (e) {
      debugPrint('[CapacitacionService] ⚠️ Error en Fase 4 (conocimiento distribuido): $e');
    }

    final resultado = buffer.toString().trim();
    debugPrint('[CapacitacionService] Contexto generado: ${resultado.isEmpty ? "(vacío)" : "${resultado.length} chars"}');
    return resultado;
  }


  /// Persiste un nuevo conocimiento aprendido dinámicamente en Supabase (guia_capacitacion).
  ///
  /// Validaciones de seguridad previas al guardado:
  ///   1. El JSON serializado no puede exceder los 2000 caracteres.
  ///   2. Debe contener obligatoriamente las llaves 'tema' y 'contenido'.
  /// Si alguna validación falla, se loguea el motivo y se aborta sin tocar Supabase.
  static Future<void> persistirNuevoConocimiento(Map<String, dynamic> jsonAprendido) async {
    // ── VALIDACIÓN DE SEGURIDAD ─────────────────────────────────────────────
    // Verificar llaves obligatorias
    final tieneTema     = jsonAprendido.containsKey('tema');
    final tieneContenido = jsonAprendido.containsKey('contenido');
    if (!tieneTema || !tieneContenido) {
      debugPrint(
        '[CapacitacionService] 🚫 Aprendizaje rechazado: faltan llaves obligatorias. '
        'tema=${tieneTema ? "✓" : "✗"}  contenido=${tieneContenido ? "✓" : "✗"}',
      );
      return;
    }

    // Verificar longitud máxima del payload
    final jsonStr = jsonEncode(jsonAprendido);
    if (jsonStr.length > 2000) {
      debugPrint(
        '[CapacitacionService] 🚫 Aprendizaje rechazado: payload demasiado largo '
        '(${jsonStr.length} chars > 2000). No se guarda en Supabase.',
      );
      return;
    }
    // ── FIN VALIDACIÓN ──────────────────────────────────────────────────────

    try {
      // 1. Cargar el JSON de capacitación actual (Supabase o assets)
      final Map<String, dynamic> datosActuales = await _cargarJson();

      // 2. Extraer activadores y respuestas limpias
      final activadoresRaw = jsonAprendido['activadores'] as List<dynamic>? ?? [];
      final respuestaLimpia = jsonAprendido['respuesta_limpia']?.toString() ?? '';
      if (respuestaLimpia.isEmpty) return;

      // 3. Obtener la lista actual de qa_especificas
      final List<dynamic> qaEspecificas = List.from(datosActuales['qa_especificas'] as List<dynamic>? ?? []);

      // 4. Agregar las nuevas preguntas/respuestas basadas en los activadores
      for (final act in activadoresRaw) {
        final activadorStr = act.toString().trim();
        if (activadorStr.isNotEmpty) {
          // Evitar duplicados exactos de la pregunta (sin importar mayúsculas/minúsculas ni espacios)
          qaEspecificas.removeWhere((item) =>
            item is Map && item['pregunta']?.toString().toLowerCase().trim() == activadorStr.toLowerCase()
          );
          qaEspecificas.add({
            'pregunta': activadorStr,
            'respuesta': respuestaLimpia,
          });
        }
      }

      // Actualizar en el mapa
      datosActuales['qa_especificas'] = qaEspecificas;

      // 5. Guardar en Supabase (insertando un nuevo registro con el JSON actualizado)
      await Supabase.instance.client
          .from(_supabaseTable)
          .insert({
            _supabaseKey: datosActuales,
          });

      // 6. Invalidar la caché para que la próxima consulta obtenga los datos frescos
      invalidarCache();
      debugPrint('[CapacitacionService] ✅ Nuevo conocimiento persistido en Supabase exitosamente.');
    } catch (e) {
      debugPrint('[CapacitacionService] ⚠️ Error al persistir nuevo conocimiento en Supabase: $e');
    }
  }

  static Map<String, dynamic> _jsonMinimoPorDefecto() => {
    'persona': {
      'descripcion': 'Sos El Guía, el asistente de EL GUIA YA.',
      'tono': 'Hablás como un ribereño argentino. Usás "amigo", "dale", "tocá".',
      'restricciones': ['Máximo 3 líneas.', 'Sin markdown.', 'Texto plano.'],
    },
    'app_contexto': {
      'nombre': 'EL GUIA YA',
      'descripcion': 'App de pesca deportiva que conecta pescadores con capitanes en el Paraná.',
    },
    'qa_especificas': [],
  };
}
