import 'package:flutter/material.dart';
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

/// Detecta comandos de navegación por voz ANTES de llamar al motor de IA.
/// Si el usuario dice "mostrá la tienda" → navega instantáneamente sin esperar Gemini.
class IntentService {
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
  static NavIntencion? detectarNavegacion(String fraseUsuario) {
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

  // Método original — mantenido por compatibilidad con el engine
  static String? analizarIntencionNavegacion(String fraseUsuario) =>
      detectarNavegacion(fraseUsuario)?.ruta;

  static void ejecutarNavegacion(BuildContext context, String ruta) {
    if (ModalRoute.of(context)?.settings.name != ruta) {
      Navigator.pushNamed(context, ruta);
    }
  }
}
