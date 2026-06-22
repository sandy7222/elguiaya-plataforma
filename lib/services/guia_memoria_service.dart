import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'el_guia_engine.dart';

/// Servicio de Rehidratación de Contexto y Memoria Local para El Guía.
/// Almacena datos del pescador en SharedPreferences y mantiene un backup
/// en la columna bio_pescador de la tabla profiles de Supabase.
class GuiaMemoriaService {
  static SharedPreferences? _prefs;

  /// Inicializa las SharedPreferences si no lo están.
  static Future<void> inicializar() async {
    if (_prefs != null) return;
    try {
      _prefs = await SharedPreferences.getInstance();
    } catch (e) {
      debugPrint('Error inicializando SharedPreferences en GuiaMemoriaService: $e');
    }
  }

  /// Obtiene el prefijo de almacenamiento basado en el ID del usuario actual de Supabase
  /// para dar soporte a múltiples usuarios en el mismo dispositivo de forma aislada.
  static String _getUserPrefix() {
    String? userId;
    try {
      userId = SupabaseService.currentUserId;
    } catch (_) {}
    return 'guia_memoria_${userId ?? 'anonimo'}_';
  }

  /// Compila el mini-contexto de rehidratación (máximo 5 líneas) y lo retorna.
  /// Si la caché local está vacía, busca restaurarla desde Supabase.
  /// También actualiza la fecha de la última sesión.
  static Future<String?> cargarContextoRehidratado() async {
    await inicializar();
    if (_prefs == null) return null;

    final prefix = _getUserPrefix();
    
    // Verificar si SharedPreferences está vacío para este usuario
    final String? cachedNombre = _prefs!.getString('${prefix}nombre');
    final List<String>? cachedEspecies = _prefs!.getStringList('${prefix}especies');
    final List<String>? cachedZonas = _prefs!.getStringList('${prefix}zonas');
    
    // Si la caché local está vacía y hay sesión activa de Supabase, intentamos restaurar
    final userId = SupabaseService.currentUserId;
    if (cachedNombre == null && (cachedEspecies == null || cachedEspecies.isEmpty) && (cachedZonas == null || cachedZonas.isEmpty) && userId != null) {
      debugPrint('[GuiaMemoriaService] Caché local vacía. Intentando restaurar desde Supabase...');
      await _restaurarDesdeSupabase(userId, prefix);
    }

    final String? nombre = _prefs!.getString('${prefix}nombre');
    final List<String> especies = _prefs!.getStringList('${prefix}especies') ?? [];
    final List<String> zonas = _prefs!.getStringList('${prefix}zonas') ?? [];
    final String? nivel = _prefs!.getString('${prefix}nivel');
    final String? ultimoTema = _prefs!.getString('${prefix}ultimo_tema');
    final String? conQuienVive = _prefs!.getString('${prefix}con_quien_vive');
    final String? comoVive = _prefs!.getString('${prefix}como_vive');
    final String? ultimaVivenciaPesca = _prefs!.getString('${prefix}ultima_vivencia_pesca');
    
    // Actualizar la fecha de última sesión
    final ahora = DateTime.now().toIso8601String();
    await _prefs!.setString('${prefix}fecha_sesion', ahora);
    
    // Ejecutar el backup en segundo plano para actualizar la fecha en Supabase
    _backupToSupabase();

    if (nombre == null &&
        especies.isEmpty &&
        zonas.isEmpty &&
        nivel == null &&
        ultimoTema == null &&
        conQuienVive == null &&
        comoVive == null &&
        ultimaVivenciaPesca == null) {
      return null;
    }

    final lines = <String>[];
    if (nombre != null && nombre.isNotEmpty) {
      lines.add('Estás hablando con $nombre.');
    }
    if (especies.isNotEmpty) {
      final espToShow = especies.take(3).join(', ');
      lines.add('Le gusta pescar $espToShow.');
    }
    if (zonas.isNotEmpty) {
      final zonToShow = zonas.take(2).join(', ');
      lines.add('Zona frecuente: $zonToShow.');
    }
    if (nivel != null && nivel.isNotEmpty) {
      lines.add('Nivel: $nivel.');
    }
    if (ultimoTema != null && ultimoTema.isNotEmpty) {
      lines.add('Último tema: $ultimoTema.');
    }
    if (conQuienVive != null && conQuienVive.isNotEmpty) {
      lines.add('Con quién vive: $conQuienVive');
    }
    if (comoVive != null && comoVive.isNotEmpty) {
      lines.add('Cómo vive: $comoVive');
    }
    if (ultimaVivenciaPesca != null && ultimaVivenciaPesca.isNotEmpty) {
      lines.add('Última vivencia/pesca: $ultimaVivenciaPesca');
    }

    if (lines.isEmpty) return null;

    // Directrices de personalidad (no cuentan dentro de las 5 líneas de datos)
    lines.add('No menciones esto de forma robótica.');
    lines.add('Usalo naturalmente si encaja.');

    return lines.join('\n');
  }

  /// Analiza el mensaje del usuario para extraer y guardar datos de perfil en SharedPreferences
  /// y luego realiza la sincronización de backup en Supabase.
  static Future<void> actualizarMemoria(String pregunta) async {
    await inicializar();
    if (_prefs == null) return;

    final prefix = _getUserPrefix();
    final pq = pregunta.toLowerCase().trim();
    bool huboCambio = false;

    // 1. EXTRAER NOMBRE
    final RegExp nameRegExp = RegExp(
      r'\b(?:me llamo|mi nombre es|soy)\s+([a-zA-ZáéíóúÁÉÍÓÚñÑ]{3,15})\b',
      caseSensitive: false,
    );
    final match = nameRegExp.firstMatch(pregunta);
    if (match != null) {
      final posibleNombre = match.group(1)!;
      final palabrasExcluidas = ['principiante', 'intermedio', 'avanzado', 'experto', 'novato', 'pescador', 'guia', 'capitan', 'el', 'un', 'una', 'triste', 'feliz', 'hola', 'amigo', 'chamigo'];
      if (!palabrasExcluidas.contains(posibleNombre.toLowerCase())) {
        final nombreFormateado = posibleNombre[0].toUpperCase() + posibleNombre.substring(1).toLowerCase();
        await _prefs!.setString('${prefix}nombre', nombreFormateado);
        huboCambio = true;
      }
    }

    // 2. EXTRAER ESPECIES FAVORITAS
    const listaEspecies = [
      'dorado', 'surubí', 'surubi', 'boga', 'bagre', 'patí', 'pati', 
      'tararira', 'carpa', 'pejerrey', 'sábalo', 'sabalo', 'pacú', 'pacu', 
      'armado', 'bagre de mar', 'mimoso', 'moncholo', 'manguruyú', 'manduví', 
      'tarucha', 'corvina', 'lisa'
    ];
    final List<String> especiesGuardadas = _prefs!.getStringList('${prefix}especies') ?? [];
    bool cambioEspecies = false;

    for (final especie in listaEspecies) {
      if (pq.contains(especie)) {
        final especieNormalizada = especie == 'surubi' ? 'surubí' :
                                   especie == 'pati' ? 'patí' :
                                   especie == 'sabalo' ? 'sábalo' :
                                   especie == 'pacu' ? 'pacú' : especie;
                                   
        if (!especiesGuardadas.contains(especieNormalizada)) {
          especiesGuardadas.add(especieNormalizada);
          cambioEspecies = true;
        }
      }
    }
    if (cambioEspecies) {
      await _prefs!.setStringList('${prefix}especies', especiesGuardadas);
      huboCambio = true;
    }

    // 3. EXTRAER ZONAS FRECUENTES
    const listaZonas = [
      'punta lara', 'chascomús', 'chascomus', 'paraná', 'parana', 
      'río de la plata', 'rio de la plata', 'tigre', 'san pedro', 
      'ibicuy', 'esquina', 'goya', 'zárate', 'zarate', 'reconquista', 
      'ituzaingó', 'ituzaingo', 'río salado', 'rio salado', 'concordia', 
      'berisso', 'paso de la patria', 'santa fe', 'rosario', 'baradero', 
      'san nicolás', 'san nicolas', 'cayastá', 'cayasta', 'helvecia', 
      'empedrado', 'bella vista', 'itbaté', 'itbate', 'florencia', 
      'victoria', 'diamante', 'ramallo', 'guayquiraró', 'uruguay'
    ];
    final List<String> zonasGuardadas = _prefs!.getStringList('${prefix}zonas') ?? [];
    bool cambioZonas = false;

    for (final zona in listaZonas) {
      if (pq.contains(zona)) {
        final palabras = zona.split(' ');
        final zonaFormateada = palabras.map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1)).join(' ');
        
        if (!zonasGuardadas.contains(zonaFormateada)) {
          zonasGuardadas.add(zonaFormateada);
          cambioZonas = true;
        }
      }
    }
    if (!cambioZonas) {
      final RegExp prepRegExp = RegExp(
        r'\b(?:pesco en|frecuento|zona de|voy a|fui a)\s+([a-zA-ZáéíóúÁÉÍÓÚñÑ\s]{3,20})\b',
        caseSensitive: false,
      );
      final matchPrep = prepRegExp.firstMatch(pq);
      if (matchPrep != null) {
        final posibleZonaRaw = matchPrep.group(1)!.trim();
        if (posibleZonaRaw.isNotEmpty && 
            !posibleZonaRaw.contains(RegExp(r'\b(?:y|o|pero|que|con|del|al|el|la|los|las|de|en|a)\b')) &&
            posibleZonaRaw.split(' ').length <= 3) {
          final palabras = posibleZonaRaw.split(' ');
          final zonaFormateada = palabras.map((p) => p.isEmpty ? '' : p[0].toUpperCase() + p.substring(1).toLowerCase()).join(' ');
          if (!zonasGuardadas.contains(zonaFormateada)) {
            zonasGuardadas.add(zonaFormateada);
            cambioZonas = true;
          }
        }
      }
    }
    if (cambioZonas) {
      await _prefs!.setStringList('${prefix}zonas', zonasGuardadas);
      huboCambio = true;
    }

    // 4. EXTRAER NIVEL DE EXPERIENCIA
    String? nivelDetectado;
    if (pq.contains('principiante') || pq.contains('novato') || pq.contains('empezando') || pq.contains('arrancando') || pq.contains('primera vez')) {
      nivelDetectado = 'principiante';
    } else if (pq.contains('intermedio') || pq.contains('se defender') || pq.contains('sé defender')) {
      nivelDetectado = 'intermedio';
    } else if (pq.contains('avanzado') || pq.contains('experto') || pq.contains('hace años pesco') || pq.contains('hace mucho pesco')) {
      nivelDetectado = 'avanzado';
    }
    if (nivelDetectado != null) {
      final currentNivel = _prefs!.getString('${prefix}nivel');
      if (currentNivel != nivelDetectado) {
        await _prefs!.setString('${prefix}nivel', nivelDetectado);
        huboCambio = true;
      }
    }

    // 5. ACTUALIZAR ÚLTIMO TEMA DE CONVERSACIÓN
    String? nuevoTema;
    try {
      final intencion = ElGuiaEngine().obtenerIntencionPrincipal(pq);
      nuevoTema = _intentToTema(intencion, pq);
    } catch (_) {}

    if (nuevoTema != null) {
      final currentTema = _prefs!.getString('${prefix}ultimo_tema');
      if (currentTema != nuevoTema) {
        await _prefs!.setString('${prefix}ultimo_tema', nuevoTema);
        huboCambio = true;
      }
    }

    // 6. EXTRAER CON QUIEN VIVE
    // Se pisa si cambia o si hay alguna corrección / novedad
    String? conQuienVive;
    
    // Términos de compañía / familia / mascotas
    final RegExp companiaRegExp = RegExp(
      r'\b(?:la señora|la vieja|los pibes|los gurises|la familia|mi viejo|el nene|la nena|mi señora|mi vieja|mi esposo|mi esposa|mi marido|mi mujer|mi novio|mi novia|mi pareja|mi hijo|mi hija|mis hijos|mi hermano|mi hermana|mis hermanos|el pichicho|la perra|los cachorros|los canes|canes|can|pichicho|pichichos|el pichico|pichico|pichicos|mascota|mascotas|gato|gata|gatos|gatas|perro|perros)\b',
      caseSensitive: false,
    );

    final RegExp correccionRegExp = RegExp(
      r'\b(?:se murió|se murio|murió|murio|se me murió|se me murio|falleció|fallecio|ya no tengo|se me fue|se fue|perdí|perdi|regalé|regale)\b',
      caseSensitive: false,
    );

    final RegExp vivoConRegExp = RegExp(
      r'\b(?:vivo con|comparto casa con|vivo solo con|vivo sola con)\s+([^.,!?\n]+)',
      caseSensitive: false,
    );
    
    final matchVivo = vivoConRegExp.firstMatch(pq);
    if (matchVivo != null) {
      final detalle = matchVivo.group(1)!.trim();
      if (detalle.isNotEmpty) {
        conQuienVive = 'Vivo con $detalle.';
      }
    }

    final oraciones = pregunta.split(RegExp(r'[.,!?\n]'));
    for (final oracion in oraciones) {
      final oracionLower = oracion.toLowerCase();
      final tieneCompania = companiaRegExp.hasMatch(oracionLower);
      final tieneCorreccion = correccionRegExp.hasMatch(oracionLower);
      
      if (tieneCompania || tieneCorreccion) {
        final detalleTexto = oracion.trim();
        if (detalleTexto.isNotEmpty && detalleTexto.length > 5) {
          if (tieneCorreccion) {
            conQuienVive = 'Corrección/Novedad: $detalleTexto.';
          } else {
            conQuienVive = 'Compañía: $detalleTexto.';
          }
        }
      }
    }

    if (conQuienVive != null) {
      final currentConQuien = _prefs!.getString('${prefix}con_quien_vive');
      if (currentConQuien != conQuienVive) {
        await _prefs!.setString('${prefix}con_quien_vive', conQuienVive);
        huboCambio = true;
      }
    }

    // 7. EXTRAER COMO VIVE (Lugar, situación)
    // Se pisa si cambia o se corrige
    String? comoVive;
    final RegExp comoViveRegExp = RegExp(
      r'\b(?:vivo en|resido en|mi casa es|mi rancho es|tengo casa en|mi hogar es)\s+([^.,!?\n]+)',
      caseSensitive: false,
    );
    final matchComo = comoViveRegExp.firstMatch(pq);
    if (matchComo != null) {
      final detalle = matchComo.group(1)!.trim();
      if (detalle.isNotEmpty) {
        comoVive = 'Vive en $detalle.';
      }
    }

    if (comoVive != null) {
      final currentComo = _prefs!.getString('${prefix}como_vive');
      if (currentComo != comoVive) {
        await _prefs!.setString('${prefix}como_vive', comoVive);
        huboCambio = true;
      }
    }

    // 8. EXTRAER ÚLTIMA VIVENCIA / PESCA
    // Se pisa siempre con la más reciente
    final RegExp vivenciaRegExp = RegExp(
      r'\b(?:última pesca|ultima pesca|última salida|ultima salida|la última vez|la ultima vez|el finde pasado|el fin de semana pasado|el otro día|el otro dia|ayer fui|fui a pescar)\b',
      caseSensitive: false,
    );
    if (vivenciaRegExp.hasMatch(pq)) {
      for (final oracion in oraciones) {
        final oracionLower = oracion.toLowerCase();
        if (vivenciaRegExp.hasMatch(oracionLower)) {
          final vivenciaTexto = oracion.trim();
          if (vivenciaTexto.length > 5) {
            final formatted = vivenciaTexto[0].toUpperCase() + vivenciaTexto.substring(1);
            await _prefs!.setString('${prefix}ultima_vivencia_pesca', formatted);
            huboCambio = true;
            break;
          }
        }
      }
    }

    // Si detectamos cambios en SharedPreferences, sincronizamos con Supabase de forma asíncrona
    if (huboCambio) {
      _backupToSupabase();
    }
  }

  /// Realiza la restauración de preferencias locales consultando la base de datos de Supabase.
  static Future<void> _restaurarDesdeSupabase(String userId, String prefix) async {
    try {
      final response = await SupabaseService.supabase
          .from('profiles')
          .select('bio_pescador')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        final bioRaw = response['bio_pescador'] ?? '';
        if (bioRaw.toString().startsWith('{')) {
          final jsonBio = jsonDecode(bioRaw);
          final memory = jsonBio['guia_memoria'];
          if (memory is Map<String, dynamic>) {
            debugPrint('[GuiaMemoriaService] Restaurando memoria local desde Supabase para el usuario: $userId');
            if (memory['nombre'] != null) await _prefs!.setString('${prefix}nombre', memory['nombre']);
            if (memory['especies'] != null) {
              await _prefs!.setStringList('${prefix}especies', List<String>.from(memory['especies']));
            }
            if (memory['zonas'] != null) {
              await _prefs!.setStringList('${prefix}zonas', List<String>.from(memory['zonas']));
            }
            if (memory['nivel'] != null) await _prefs!.setString('${prefix}nivel', memory['nivel']);
            if (memory['ultimo_tema'] != null) await _prefs!.setString('${prefix}ultimo_tema', memory['ultimo_tema']);
            if (memory['fecha_sesion'] != null) await _prefs!.setString('${prefix}fecha_sesion', memory['fecha_sesion']);
            if (memory['con_quien_vive'] != null) await _prefs!.setString('${prefix}con_quien_vive', memory['con_quien_vive']);
            if (memory['como_vive'] != null) await _prefs!.setString('${prefix}como_vive', memory['como_vive']);
            if (memory['ultima_vivencia_pesca'] != null) await _prefs!.setString('${prefix}ultima_vivencia_pesca', memory['ultima_vivencia_pesca']);
          }
        }
      }
    } catch (e) {
      debugPrint('[GuiaMemoriaService] Fallo al restaurar desde Supabase: $e');
    }
  }

  /// Realiza el backup asíncrono en Supabase de la memoria almacenada en SharedPreferences.
  static Future<void> _backupToSupabase() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final prefix = _getUserPrefix();
      final String? nombre = _prefs!.getString('${prefix}nombre');
      final List<String>? especies = _prefs!.getStringList('${prefix}especies');
      final List<String>? zonas = _prefs!.getStringList('${prefix}zonas');
      final String? nivel = _prefs!.getString('${prefix}nivel');
      final String? ultimoTema = _prefs!.getString('${prefix}ultimo_tema');
      final String? fechaSesion = _prefs!.getString('${prefix}fecha_sesion');
      final String? conQuienVive = _prefs!.getString('${prefix}con_quien_vive');
      final String? comoVive = _prefs!.getString('${prefix}como_vive');
      final String? ultimaVivenciaPesca = _prefs!.getString('${prefix}ultima_vivencia_pesca');

      final memoryMap = {
        if (nombre != null) 'nombre': nombre,
        if (especies != null) 'especies': especies,
        if (zonas != null) 'zonas': zonas,
        if (nivel != null) 'nivel': nivel,
        if (ultimoTema != null) 'ultimo_tema': ultimoTema,
        if (fechaSesion != null) 'fecha_sesion': fechaSesion,
        if (conQuienVive != null) 'con_quien_vive': conQuienVive,
        if (comoVive != null) 'como_vive': comoVive,
        if (ultimaVivenciaPesca != null) 'ultima_vivencia_pesca': ultimaVivenciaPesca,
      };

      if (memoryMap.isEmpty) return;

      // Consultar bio_pescador actual para preservar otros campos
      final response = await SupabaseService.supabase
          .from('profiles')
          .select('bio_pescador')
          .eq('user_id', userId)
          .maybeSingle();

      dynamic newBioValue;
      if (response != null) {
        final bioRaw = response['bio_pescador'] ?? '';
        if (bioRaw.toString().startsWith('{')) {
          final Map<String, dynamic> jsonBio = Map<String, dynamic>.from(jsonDecode(bioRaw));
          jsonBio['guia_memoria'] = memoryMap;
          newBioValue = jsonEncode(jsonBio);
        } else {
          // Si es una biografía plana, la estructuramos en formato JSON
          newBioValue = jsonEncode({
            'bio': bioRaw.toString(),
            'guia_memoria': memoryMap,
          });
        }
      } else {
        newBioValue = jsonEncode({
          'bio': '',
          'guia_memoria': memoryMap,
        });
      }

      await SupabaseService.supabase
          .from('profiles')
          .update({'bio_pescador': newBioValue})
          .eq('user_id', userId);

      debugPrint('[GuiaMemoriaService] Backup completado exitosamente en Supabase para el usuario: $userId');
    } catch (e) {
      debugPrint('[GuiaMemoriaService] Error realizando backup en Supabase: $e');
    }
  }

  /// Auxiliar para convertir la intención a una frase descriptiva de tema
  static String? _intentToTema(String intencion, String pq) {
    String? especieMencionada;
    const especies = ['dorado', 'surubí', 'surubi', 'boga', 'bagre', 'patí', 'pati', 'tararira', 'pejerrey', 'bagre de mar'];
    for (final esp in especies) {
      if (pq.contains(esp)) {
        especieMencionada = esp == 'surubi' ? 'surubí' : esp == 'pati' ? 'patí' : esp;
        break;
      }
    }

    switch (intencion) {
      case 'carnadas':
        return especieMencionada != null ? 'carnadas para $especieMencionada' : 'carnadas';
      case 'nudos':
        return 'nudos de pesca';
      case 'boyas':
        return 'boyas y flotadores';
      case 'plomadas':
        return 'plomadas';
      case 'canas_y_reeles':
        return 'cañas y reeles';
      case 'peces':
        return especieMencionada != null ? 'pesca de $especieMencionada' : 'especies de peces';
      case 'rio':
        return 'condiciones del río';
      case 'clima':
        return 'clima y navegación';
      case 'refugio':
      case 'fuego':
      case 'agua':
        return 'supervivencia en la isla';
      default:
        if (especieMencionada != null) {
          return 'pesca de $especieMencionada';
        }
        return null;
    }
  }
}
