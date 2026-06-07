import 'package:flutter/material.dart';

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

  /// Detecta si la frase es un comando de navegación.
  /// Retorna [NavIntencion] con ruta + frase de confirmación, o null si no es navegación.
  static NavIntencion? detectarNavegacion(String fraseUsuario) {
    final f = fraseUsuario.toLowerCase().trim();
    final nav = _esComandoNavegar(f);

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

    // ── INICIO / HOME ──────────────────────────────────────────────────────
    if ((f.contains('inicio') || f.contains('pantalla principal')) && nav) {
      return const NavIntencion(
        '/inicio',
        'Dale, volvemos al inicio.',
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
