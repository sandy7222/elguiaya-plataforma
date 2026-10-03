import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'supabase_service.dart';
import '../models/producto.dart';
import '../models/categoria.dart';

/// Resultado de un comando de navegación detectado.
class NavIntencion {
  final String ruta;
  final String respuesta;
  const NavIntencion(this.ruta, this.respuesta);
}

/// Decisión sobre una ruta: navegar ya, o solo ofrecerla.
class RutaResuelta {
  final String? navegarA;
  final String? ofertaRuta;
  final String? ofertaTexto;
  const RutaResuelta({this.navegarA, this.ofertaRuta, this.ofertaTexto});
}

/// Detecta comandos de navegación por voz ANTES de llamar al motor de IA.
/// Si el usuario dice "mostrá la tienda" → navega instantáneamente sin esperar Gemini.
class IntentService {
  /// Paso 1.0: navegación solo con pedido explícito (flag `guia_nav_estricta`).
  /// Apagado vuelve al comportamiento de antes (navega con casi cualquier frase).
  static const String prefNavEstricta = 'guia_nav_estricta';
  static bool navEstricta = true;
  static void aplicarFlags(SharedPreferences prefs) {
    navEstricta = prefs.getBool(prefNavEstricta) ?? navEstricta;
  }

  // Verbos de navegación: señales de que el usuario QUIERE ir a una pantalla.
  static bool _esComandoNavegar(String f) =>
      f.contains('mostrame') ||
      f.contains('mostrá') ||
      f.contains('mostrar') ||
      f.contains('abrir') ||
      f.contains('abrí') ||
      f.contains('abri') ||
      f.contains('ir a') ||
      f.contains('llevame') ||
      f.contains('llevar') ||
      f.contains('quiero ver') ||
      f.contains('ver el') ||
      f.contains('ver la') ||
      f.contains('podés') ||
      f.contains('podes') ||
      f.contains('abre') ||
      f.contains('andá a') ||
      f.contains('anda a') ||
      f.contains('llevame a') ||
      f.contains('quiero ir');

  static Future<void> _abrirUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .trim();
  }

  static String _quitarPlural(String palabra) {
    if (palabra.length <= 3) return palabra;
    if (palabra.endsWith('es')) return palabra.substring(0, palabra.length - 2);
    if (palabra.endsWith('s')) return palabra.substring(0, palabra.length - 1);
    return palabra;
  }

  static Categoria? _buscarCategoriaPorFrase(String fraseNorm) {
    final categorias = SupabaseService.cachedCategorias;
    if (categorias.isEmpty) return null;
    
    final palabrasFrase = fraseNorm.split(RegExp(r'\s+')).map((w) => _quitarPlural(w)).toList();

    for (final cat in categorias) {
      final nombreNorm = _normalizar(cat.nombre);
      final palabrasCat = nombreNorm.split(RegExp(r'\s+')).map((w) => _quitarPlural(w)).toList();
      
      // Si alguna palabra de la categoría coincide con alguna palabra de la frase
      for (final pCat in palabrasCat) {
        if (pCat.length <= 2) continue;
        for (final pFrase in palabrasFrase) {
          if (pFrase.length <= 2) continue;
          if (pCat == pFrase || pCat.contains(pFrase) || pFrase.contains(pCat)) {
            return cat;
          }
        }
      }
    }
    return null;
  }

  static Producto? _buscarProductoPorFrase(String fraseNorm) {
    final productos = SupabaseService.cachedProductos;
    if (productos.isEmpty) return null;

    final palabrasFrase = fraseNorm.split(RegExp(r'\s+')).map((w) => _quitarPlural(w)).toList();
    
    Producto? mejorMatch;
    int maxCoincidencias = 0;

    for (final prod in productos) {
      final nombreNorm = _normalizar(prod.nombre);
      final palabrasProd = nombreNorm.split(RegExp(r'\s+')).map((w) => _quitarPlural(w)).toList();
      
      int coincidencias = 0;
      for (final pProd in palabrasProd) {
        if (pProd.length <= 2) continue;
        for (final pFrase in palabrasFrase) {
          if (pFrase.length <= 2) continue;
          if (pProd == pFrase || pProd.contains(pFrase) || pFrase.contains(pProd)) {
            coincidencias++;
          }
        }
      }
      
      if (coincidencias > maxCoincidencias) {
        maxCoincidencias = coincidencias;
        mejorMatch = prod;
      }
    }

    if (maxCoincidencias >= 2) {
      return mejorMatch;
    } else if (maxCoincidencias == 1 && mejorMatch != null) {
      return mejorMatch;
    }

    return null;
  }

  /// Detecta si la frase es un comando de navegación.
  /// Retorna [NavIntencion] con ruta + frase de confirmación, o null si no es navegación.
  static NavIntencion? detectarNavegacion(String fraseUsuario) =>
      navEstricta ? _detectarEstricta(fraseUsuario) : _detectarLegado(fraseUsuario);

  /// Comportamiento anterior a 1.0, que queda detrás del flag.
  static NavIntencion? _detectarLegado(String fraseUsuario) {
    final f = fraseUsuario.toLowerCase().trim();
    final fNorm = _normalizar(f);
    final nav = _esComandoNavegar(fNorm);

    // 1. Intentar buscar coincidencia con un producto específico primero (si hay intención de ver/ir/comprar)
    if (nav || fNorm.contains('producto') || fNorm.contains('buscar') || fNorm.contains('ver') || fNorm.contains('comprar') || fNorm.contains('tienda')) {
      final producto = _buscarProductoPorFrase(fNorm);
      if (producto != null) {
        return NavIntencion(
          '/producto/${producto.id}',
          'Dale compañero, te llevo a ver ${producto.nombre}.',
        );
      }
    }

    // 2. Intentar buscar coincidencia con una categoría o subcategoría específica
    if (nav || fNorm.contains('categoria') || fNorm.contains('subcategoria') || fNorm.contains('seccion') || fNorm.contains('ver') || fNorm.contains('comprar') || fNorm.contains('tienda')) {
      final categoria = _buscarCategoriaPorFrase(fNorm);
      if (categoria != null) {
        return NavIntencion(
          '/categoria/${categoria.id}',
          'Dale chamigo, te muestro la categoría ${categoria.nombre}.',
        );
      }
    }

    // ── TIENDA / COMPRAS ──────────────────────────────────────────────────
    if (f.contains('tienda') ||
        (f.contains('comprar') && nav) ||
        f.contains('quiero comprar') ||
        f.contains('anzuelo') ||
        f.contains('carnada') ||
        f.contains('mis pedidos') ||
        f.contains('ver productos')) {
      return const NavIntencion(
        '/tienda',
        'Dale chamigo, te abro la tienda.',
      );
    }

    // ── MAPA / RÍO ────────────────────────────────────────────────────────
    if (f.contains('mapa') ||
        f.contains('ver el río') ||
        f.contains('ver el rio') ||
        f.contains('dónde pescar') ||
        f.contains('donde pescar') ||
        f.contains('ruta') && nav) {
      return const NavIntencion(
        '/mapa',
        'Dale, te abro el mapa.',
      );
    }

    // ── PRONÓSTICO / CLIMA ─────────────────────────────────────────────────
    if (f.contains('pronóstico') ||
        f.contains('pronostico') ||
        f.contains('tiempo') && nav ||
        f.contains('clima') && nav ||
        f.contains('temperatura') && nav ||
        f.contains('lluvia') && nav ||
        f.contains('viento') && nav ||
        f.contains('meteorolog')) {
      return const NavIntencion(
        '/clima',
        'Dale, te abro el pronóstico del tiempo.',
      );
    }

    // ── TABLA SOLUNAR ──────────────────────────────────────────────────────
    if (f.contains('solunar') ||
        f.contains('tabla lunar') ||
        f.contains('tabla solunar') ||
        f.contains('calendario lunar') ||
        f.contains('luna llena') && nav ||
        f.contains('luna nueva') && nav) {
      return const NavIntencion(
        '/solunar',
        'Dale, te abro la tabla solunar.',
      );
    }

    // ── PERFIL / CONFIGURACIÓN ─────────────────────────────────────────────
    if (f.contains('perfil') ||
        f.contains('mis papeles') ||
        f.contains('carnet') ||
        f.contains('mi licencia') ||
        f.contains('configuración') ||
        f.contains('configuracion') ||
        f.contains('mis datos') ||
        f.contains('mi cuenta') && nav ||
        f.contains('configuración personal') ||
        f.contains('ajustes')) {
      return const NavIntencion(
        '/perfil',
        'Dale, te abro tu perfil.',
      );
    }

    // ── CARRITO / PAGOS ────────────────────────────────────────────────────
    if (f.contains('carrito') ||
        f.contains('mis compras') ||
        f.contains('pago') && nav ||
        f.contains('pagar') && nav ||
        f.contains('cesta')) {
      return const NavIntencion(
        '/carrito',
        'Dale, te abro el carrito.',
      );
    }

    // ── NOTIFICACIONES ─────────────────────────────────────────────────────
    if (f.contains('notificacion') ||
        f.contains('notificación') ||
        f.contains('avisos') ||
        f.contains('alertas') && nav ||
        f.contains('mensajes') && nav) {
      return const NavIntencion(
        '/notificaciones',
        'Dale, te abro las notificaciones.',
      );
    }

    // ── BLOG / PIQUES ──────────────────────────────────────────────────────
    if (f.contains('blog') ||
        f.contains('que pica') ||
        f.contains('qué pica') ||
        f.contains('novedades') && nav ||
        f.contains('noticias') && nav) {
      return const NavIntencion(
        '/blog',
        'Dale chamigo, vamos a ver los últimos piques.',
      );
    }

    // ── FAVORITOS ──────────────────────────────────────────────────────────
    if (f.contains('favorito') ||
        f.contains('guardados') && nav) {
      return const NavIntencion(
        '/favoritos',
        'Dale, te muestro tus favoritos.',
      );
    }

    // ── HISTORIAL DE VIAJES ────────────────────────────────────────────────
    if (f.contains('historial') ||
        f.contains('mis viajes') ||
        f.contains('viajes anteriores') ||
        f.contains('viajes pasados')) {
      return const NavIntencion(
        '/historial',
        'Dale, te muestro tu historial de viajes.',
      );
    }

    // ── PANEL PRINCIPAL / MENÚ PESCADOR ───────────────────────────────────
    if (f.contains('menú principal') ||
        f.contains('menu principal') ||
        f.contains('panel de control') ||
        f.contains('panel principal') ||
        f.contains('panel del pescador') ||
        f.contains('mi panel') ||
        f.contains('pantalla principal') ||
        f.contains('volver al inicio') ||
        f.contains('ir al inicio') ||
        f.contains('ir al home') ||
        f.contains('ir al menú') ||
        f.contains('ir al menu') ||
        f.contains('menú') && nav ||
        f.contains('menu') && nav ||
        f.contains('home') && nav ||
        f.contains('inicio') && nav) {
      return const NavIntencion(
        '/panel',
        '¡Dale chamigo! Te llevo al menú principal.',
      );
    }

    // ── YOUTUBE ──────────────────────────────────────────────────────
    if (f.contains('youtube') || 
        f.contains('video') && nav) {
      _abrirUrl('https://www.youtube.com');
      return const NavIntencion(
        'externo',
        'Dale chamigo, te abro YouTube.',
      );
    }

    // ── WHATSAPP ─────────────────────────────────────────────────────
    if (f.contains('whatsapp') ||
        f.contains('manda un mensaje') ||
        f.contains('mandá un mensaje')) {
      _abrirUrl('https://wa.me/');
      return const NavIntencion(
        'externo',
        'Dale, te abro WhatsApp.',
      );
    }

    // ── SPOTIFY ──────────────────────────────────────────────────────
    if (f.contains('spotify') ||
        f.contains('música') && nav ||
        f.contains('musica') && nav ||
        f.contains('poner música') ||
        f.contains('poner musica')) {
      _abrirUrl('https://open.spotify.com');
      return const NavIntencion(
        'externo',
        'Dale chamigo, te abro Spotify.',
      );
    }

    // ── MAPS / GOOGLE MAPS ───────────────────────────────────────────
    if (f.contains('google maps') ||
        f.contains('cómo llego') ||
        f.contains('como llego') ||
        f.contains('navegación gps') ||
        f.contains('navegacion gps')) {
      _abrirUrl('https://maps.google.com');
      return const NavIntencion(
        'externo',
        'Dale, te abro Google Maps.',
      );
    }

    return null;
  }


  // ── Navegación estricta (paso 1.0) ─────────────────────────────────────────

  static final RegExp _soloLetras = RegExp(r'[^a-zñ0-9\s]');

  /// Minúsculas, sin tildes ni signos, espacios simples. Conserva la ñ.
  static String _limpiar(String texto) => _normalizar(texto.replaceAll('ñ', '\u0001').replaceAll('Ñ', '\u0001'))
      .replaceAll('\u0001', 'ñ')
      .replaceAll(_soloLetras, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static const _relleno = r'(?:(?:che|guia|hola|ok|dale|bueno|ahora|entonces|y|por favor|porfa)\s+)*';
  static const _cortesia = r'(?:(?:podes|podrias|puedes|quiero que|necesito que)\s+)?(?:me\s+)?';
  // Verbos explícitos de navegación, como palabra entera y AL PRINCIPIO de la frase.
  static final RegExp _pedido = RegExp(
    '^$_relleno$_cortesia'
    r'(?:quiero ir a|quiero ir al|quiero ver|quiero comprar|quiero abrir|ir a|ir al|anda a|anda al|voy a ver|'
    r'mostrame|mostra|mostrar|muestrame|abri|abrime|abrir|abre|abris|llevame|lleva|llevar|ver|comprar)\b',
  );

  static const _interrogativos = {
    'como', 'que', 'cual', 'cuales', 'cuando', 'donde', 'por', 'porque', 'quien', 'quienes', 'cuanto', 'cuanta',
    'cuantos', 'cuantas', 'para',
  };

  /// ¿La frase es un pedido explícito de ir a una pantalla (verbo al principio)
  /// y no una pregunta? Devuelve lo que se pide, ya sin el verbo, o null.
  static String? _objetoDelPedido(String fraseUsuario) {
    final f = _limpiar(fraseUsuario);
    final primera = f.split(' ').first;
    if (_interrogativos.contains(primera)) return null;
    final m = _pedido.firstMatch(f);
    if (m == null) return null;
    return f.substring(m.end).trim();
  }

  static Set<String> _palabras(String texto) =>
      _limpiar(texto).split(' ').where((w) => w.length > 2).map(_quitarPlural).toSet();

  /// Producto por PALABRA ENTERA: al menos 2 palabras del nombre en la frase, o el
  /// nombre exacto si es de una sola palabra. "pescar" ya no es "Caja de Pesca".
  static Producto? _productoExacto(Set<String> frase) {
    Producto? mejor;
    var mejorN = 0;
    for (final p in SupabaseService.cachedProductos) {
      final nombre = _palabras(p.nombre);
      if (nombre.isEmpty) continue;
      final n = nombre.where(frase.contains).length;
      final alcanza = n >= 2 || (nombre.length == 1 && n == 1);
      if (alcanza && n > mejorN) {
        mejor = p;
        mejorN = n;
      }
    }
    return mejor;
  }

  /// Categoría por PALABRA ENTERA: todas las palabras de su nombre, o al menos 2.
  static Categoria? _categoriaExacta(Set<String> frase) {
    Categoria? mejor;
    var mejorN = 0;
    for (final c in SupabaseService.cachedCategorias) {
      final nombre = _palabras(c.nombre);
      if (nombre.isEmpty) continue;
      final n = nombre.where(frase.contains).length;
      final alcanza = n >= 2 || n == nombre.length;
      if (alcanza && n > mejorN) {
        mejor = c;
        mejorN = n;
      }
    }
    return mejor;
  }

  static bool _tiene(String f, List<String> claves) => claves.any((c) => RegExp('\\b$c\\b').hasMatch(f));

  static NavIntencion? _detectarEstricta(String fraseUsuario) {
    final objeto = _objetoDelPedido(fraseUsuario);
    if (objeto == null) return null;
    final f = _limpiar(fraseUsuario);
    final palabras = _palabras(objeto);

    final producto = _productoExacto(palabras);
    if (producto != null) {
      return NavIntencion('/producto/${producto.id}', 'Dale compañero, te llevo a ver ${producto.nombre}.');
    }
    final categoria = _categoriaExacta(palabras);
    if (categoria != null) {
      return NavIntencion('/categoria/${categoria.id}', 'Dale chamigo, te muestro la categoría ${categoria.nombre}.');
    }

    // Aplicaciones externas.
    if (_tiene(f, ['google maps'])) {
      _abrirUrl('https://maps.google.com');
      return const NavIntencion('externo', 'Dale, te abro Google Maps.');
    }
    if (_tiene(f, ['youtube'])) {
      _abrirUrl('https://www.youtube.com');
      return const NavIntencion('externo', 'Dale chamigo, te abro YouTube.');
    }
    if (_tiene(f, ['whatsapp'])) {
      _abrirUrl('https://wa.me/');
      return const NavIntencion('externo', 'Dale, te abro WhatsApp.');
    }
    if (_tiene(f, ['spotify', 'musica'])) {
      _abrirUrl('https://open.spotify.com');
      return const NavIntencion('externo', 'Dale chamigo, te abro Spotify.');
    }

    // Pantallas de la app. El verbo ya está; acá solo se elige el destino.
    if ((objeto.isEmpty && f.contains('comprar')) || _tiene(objeto, ['tienda', 'pedidos', 'productos'])) {
      return const NavIntencion('/tienda', 'Dale chamigo, te abro la tienda.');
    }
    if (_tiene(objeto, ['mapa', 'rio'])) return const NavIntencion('/mapa', 'Dale, te abro el mapa.');
    if (_tiene(objeto, ['pronostico', 'clima', 'tiempo', 'meteorologico', 'temperatura', 'viento'])) {
      return const NavIntencion('/clima', 'Dale, te abro el pronóstico del tiempo.');
    }
    if (_tiene(objeto, ['solunar', 'tabla lunar', 'calendario lunar'])) {
      return const NavIntencion('/solunar', 'Dale, te abro la tabla solunar.');
    }
    if (_tiene(objeto, ['perfil', 'configuracion', 'ajustes', 'mis datos', 'mi cuenta', 'mis papeles', 'carnet'])) {
      return const NavIntencion('/perfil', 'Dale, te abro tu perfil.');
    }
    if (_tiene(objeto, ['carrito', 'mis compras', 'cesta'])) {
      return const NavIntencion('/carrito', 'Dale, te abro el carrito.');
    }
    if (_tiene(objeto, ['notificaciones', 'avisos', 'alertas'])) {
      return const NavIntencion('/notificaciones', 'Dale, te abro las notificaciones.');
    }
    if (_tiene(objeto, ['blog', 'novedades', 'noticias', 'piques'])) {
      return const NavIntencion('/blog', 'Dale chamigo, vamos a ver los últimos piques.');
    }
    if (_tiene(objeto, ['favoritos', 'guardados'])) {
      return const NavIntencion('/favoritos', 'Dale, te muestro tus favoritos.');
    }
    if (_tiene(objeto, ['historial', 'mis viajes', 'viajes anteriores', 'viajes pasados'])) {
      return const NavIntencion('/historial', 'Dale, te muestro tu historial de viajes.');
    }
    if (_tiene(objeto, ['menu principal', 'menu', 'panel', 'inicio', 'home', 'pantalla principal'])) {
      return const NavIntencion('/panel', '¡Dale chamigo! Te llevo al menú principal.');
    }
    return null;
  }

  // ── Oferta: primero responde, después ofrece ───────────────────────────────

  static const _temasTienda = [
    'anzuelo', 'anzuelos', 'carnada', 'carnadas', 'cana', 'canas', 'reel', 'reels', 'senuelo', 'senuelos',
    'linea', 'lineas', 'caja de pesca', 'cajas de pesca', 'chaleco', 'chalecos', 'plomada', 'plomadas',
    'tienda', 'comprar',
  ];

  /// Si el tema de [frase] roza la tienda, una oferta que el Guía agrega DESPUÉS de
  /// responder ("Si querés, te muestro …"); el usuario la acepta con un botón o
  /// con un "sí" por voz ([esAceptacionDeOferta]). Nunca navega sola. Si la frase
  /// ya es un pedido explícito, devuelve null (ya navegó).
  static NavIntencion? ofertaDeNavegacion(String frase) {
    if (!navEstricta) return null;
    if (_objetoDelPedido(frase) != null) return null;
    final f = _limpiar(frase);
    if (!_tiene(f, _temasTienda)) return null;
    final categoria = _categoriaExacta(_palabras(f));
    if (categoria != null) {
      return NavIntencion('/categoria/${categoria.id}', 'Si querés, te muestro la categoría ${categoria.nombre}.');
    }
    return const NavIntencion('/tienda', 'Si querés, te muestro la tienda.');
  }

  static const _nombresDeRuta = {
    '/tienda': 'la tienda',
    '/mapa': 'el mapa',
    '/clima': 'el pronóstico',
    '/solunar': 'la tabla solunar',
    '/notificaciones': 'las notificaciones',
    '/perfil': 'tu perfil',
    '/carrito': 'el carrito',
    '/blog': 'el blog',
    '/favoritos': 'tus favoritos',
    '/historial': 'tu historial de viajes',
    '/inicio': 'el inicio',
    '/panel': 'el menú principal',
  };

  /// Qué hace el overlay con la ruta que trae una respuesta del motor: navega
  /// SOLO si la persona lo pidió (verbo explícito); si no, la convierte en una
  /// oferta que se dice después de responder ("Si querés, te abro el mapa").
  /// En una emergencia no navega ni agrega nada: la respuesta ya dice qué hacer.
  static RutaResuelta resolverRuta(String pregunta, String? rutaDeLaRespuesta, {bool esSeguridad = false}) {
    if (!navEstricta) return RutaResuelta(navegarA: rutaDeLaRespuesta);
    if (esSeguridad) return const RutaResuelta();
    final pedido = _detectarEstricta(pregunta);
    if (pedido != null && pedido.ruta != 'externo') return RutaResuelta(navegarA: pedido.ruta);
    if (rutaDeLaRespuesta != null) {
      final nombre = _nombresDeRuta[rutaDeLaRespuesta] ??
          (rutaDeLaRespuesta.startsWith('/categoria/') ? 'esa categoría' : 'esa pantalla');
      return RutaResuelta(ofertaRuta: rutaDeLaRespuesta, ofertaTexto: 'Si querés, te abro $nombre.');
    }
    final oferta = ofertaDeNavegacion(pregunta);
    if (oferta != null) return RutaResuelta(ofertaRuta: oferta.ruta, ofertaTexto: oferta.respuesta);
    return const RutaResuelta();
  }

  static const _senalesDeAceptacion = {
    'si', 'dale', 'bueno', 'ok', 'okey', 'claro', 'listo', 'vamos', 'obvio', 'mostrame', 'mostramelo',
    'mostramela', 'mostramelos', 'mostramelas', 'abrilo', 'abrila', 'llevame',
  };
  static const _relleno2 = {'por', 'favor', 'de', 'una', 'gracias'};

  /// ¿El usuario acepta una oferta pendiente? Solo si TODA la frase es una
  /// aceptación ("sí", "dale", "mostrámelo"): "sí pero explicame el nudo" no.
  static bool esAceptacionDeOferta(String frase) {
    final palabras = _limpiar(frase).split(' ').where((w) => w.isNotEmpty).toList();
    if (palabras.isEmpty || palabras.length > 4) return false;
    if (!palabras.any(_senalesDeAceptacion.contains)) return false;
    return palabras.every((w) => _senalesDeAceptacion.contains(w) || _relleno2.contains(w));
  }

  // Método original — mantenido por compatibilidad con el engine
  static String? analizarIntencionNavegacion(String fraseUsuario) =>
      detectarNavegacion(fraseUsuario)?.ruta;

  static void ejecutarNavegacion(BuildContext context, String ruta) {
    if (ModalRoute.of(context)?.settings.name != ruta) {
      Navigator.pushNamed(context, ruta);
    }
  }
}
