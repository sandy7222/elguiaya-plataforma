import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import '../screens/product_catalog_screen.dart';
import '../app_navigator.dart';

class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  void inicializar() {
    // Escuchar links entrantes cuando la app está abierta o en segundo plano (hot start)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _procesarDeepLink(uri);
    }, onError: (err) {
      debugPrint('?? Error en deep link stream: $err');
    });

    // Procesar el link con el que se abrió la app (cold start)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _procesarDeepLink(uri);
      }
    }).catchError((err) {
      debugPrint('?? Error al obtener link inicial: $err');
    });
  }

  void _procesarDeepLink(Uri uri) {
    debugPrint('? Deep link recibido: $uri');
    
    // El Guia YA://tienda o similar
    if (uri.scheme == 'El Guia YA' && uri.host == 'tienda') {
      _navegarATienda();
    }
  }

  void _navegarATienda() {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // Si el contexto del navegador aún no está listo, reintentamos un poco más tarde
      Future.delayed(const Duration(milliseconds: 500), _navegarATienda);
      return;
    }

    debugPrint('?? Navegando a ProductCatalogScreen via Deep Link');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ProductCatalogScreen(),
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
