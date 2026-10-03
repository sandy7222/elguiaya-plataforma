// Paso 1.0 de docs/PLAN_AYUDANTE_IA.md: navegación solo con pedido explícito.
//
// Hoy `IntentService.detectarNavegacion` navega con casi cualquier frase:
//   (1) basta UNA coincidencia de producto y compara pedazos de palabra
//       ("pescar" contiene "pesca" → "Caja de Pesca");
//   (2) cuenta como orden "podés" y cualquier texto que contenga "ver"
//       ("verano", "river", "llover");
//   (3) "anzuelo" y "carnada" abren la tienda directo.
//
// Regla nueva: una PREGUNTA nunca navega; un pedido explícito (verbo de
// navegación como palabra entera + destino) sí. Si el tema roza la tienda, el
// Guía responde y OFRECE (`ofertaDeNavegacion`), nunca navega solo.
//
// Estos tests corren con productos y categorías cargados, como en la app real.
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/categoria.dart';
import 'package:capitanya_master/models/producto.dart';
import 'package:capitanya_master/services/intent_service.dart';
import 'package:capitanya_master/services/supabase_service.dart';

Producto _producto(String id, String nombre) => Producto(
      id: id,
      nombre: nombre,
      descripcion: '',
      precio: 1000,
      stock: 5,
      rubro: 'Pesca',
      categoriaId: 'c1',
      imagenUrl: '',
      activo: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Categoria _categoria(String id, String nombre) => Categoria(
      id: id,
      nombre: nombre,
      descripcion: '',
      activa: true,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SupabaseService.cachedProductos
      ..clear()
      ..addAll([
        _producto('p1', 'Caja de Pesca'),
        _producto('p2', 'Caña Spinning 2,10 m'),
        _producto('p3', 'Anzuelo triple N4'),
        _producto('p4', 'Carnada artificial rana'),
        _producto('p5', 'Chaleco salvavidas adulto'),
        _producto('p6', 'Reel frontal 4000'),
        _producto('p7', 'Línea multifilamento 0,20'),
        _producto('p8', 'Señuelo dorado'),
      ]);
    SupabaseService.cachedCategorias
      ..clear()
      ..addAll([
        _categoria('k1', 'Cañas de pescar'),
        _categoria('k2', 'Anzuelos'),
        _categoria('k3', 'Carnadas'),
        _categoria('k4', 'Cajas y organizadores'),
        _categoria('k5', 'Seguridad náutica'),
      ]);
  });

  tearDownAll(() {
    SupabaseService.cachedProductos.clear();
    SupabaseService.cachedCategorias.clear();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    IntentService.navEstricta = true;
  });

  // ── Preguntas de pesca que hoy navegan ────────────────────────────────────
  const preguntas = [
    'qué carnada uso',
    'qué carnada uso para el dorado',
    'cómo pescar en verano',
    'podés decirme cómo se pesca el dorado',
    'podés explicarme cómo atar un anzuelo',
    'cuál es la mejor carnada para el surubí',
    'cómo se usa una caja de pesca',
    'qué anzuelo me conviene para pejerrey',
    'dónde pescar dorado',
    'dónde pescar pejerrey en el río',
    'cuándo conviene pescar con luna llena',
    'qué pasa si llueve mucho en el río',
    'va a llover mañana en el río',
    'cómo está el viento para pescar',
    'cómo se arma una línea con anzuelo',
    'por qué no pican con viento sur',
    'cómo es la pesca en verano',
    'qué caña uso para pescar surubí',
    'qué reel necesito para el dorado',
    'qué es un anzuelo circular',
    'cuál es la diferencia entre carnada viva y artificial',
    'cómo conservo la carnada',
    'cómo se pesca con señuelo',
    'dónde consigo carnada viva',
    '¿conviene pescar con carnada artificial?',
    'conviene ir a pescar con el pronóstico de hoy?',
    'qué tal está la tarde para la pesca',
    'me gustaría saber cómo se pesca la boga',
    'cuántos anzuelos lleva una línea de fondo',
    'cuánta carnada llevo para una tarde',
    'quién gana el partido de river hoy',
    'vi un dorado enorme en el río',
    'ayer pesqué un surubí con carnada viva',
    'el verano es la mejor época para el dorado',
    'qué señuelo uso de noche',
    'cómo elijo una caja de pesca',
    'cómo se pesca en el río en verano',
    'qué línea uso con un reel frontal',
    'por qué se rompe el anzuelo',
    'se puede pescar con lluvia',
    'no sé qué carnada comprar',
    'qué chaleco necesito para salir en lancha',
    'a qué hora sale el sol hoy',
    'cómo se llama el nudo para atar el anzuelo',
  ];

  group('una pregunta o comentario de pesca NO navega', () {
    for (final p in preguntas) {
      test('"$p"', () {
        final nav = IntentService.detectarNavegacion(p);
        expect(nav, isNull, reason: 'navegó a ${nav?.ruta}: "${nav?.respuesta}"');
      });
    }
    test('hay al menos 40 preguntas', () => expect(preguntas.length, greaterThanOrEqualTo(40)));
  });

  // ── Pedidos explícitos: navegan bien ──────────────────────────────────────
  const pedidos = {
    'llevame a la tienda': '/tienda',
    'abrí la tienda': '/tienda',
    'quiero ir a la tienda': '/tienda',
    'ir a la tienda': '/tienda',
    'quiero comprar': '/tienda',
    'mostrame las cañas de pescar': '/categoria/k1',
    'mostrame los anzuelos': '/categoria/k2',
    'abrí la categoría carnadas': '/categoria/k3',
    'quiero ver la caja de pesca': '/producto/p1',
    'mostrame la caja de pesca': '/producto/p1',
    'llevame al chaleco salvavidas adulto': '/producto/p5',
    'quiero comprar la caña spinning': '/producto/p2',
    'abrí el mapa': '/mapa',
    'mostrame el mapa': '/mapa',
    'abrí el pronóstico': '/clima',
    'mostrame el pronóstico': '/clima',
    'llevame al clima': '/clima',
    'abrí la tabla solunar': '/solunar',
    'abrí mi perfil': '/perfil',
    'abrí el carrito': '/carrito',
    'ir al carrito': '/carrito',
    'mostrame mis favoritos': '/favoritos',
    'abrí las notificaciones': '/notificaciones',
    'llevame al menú principal': '/panel',
  };

  group('un pedido explícito navega bien', () {
    for (final p in pedidos.entries) {
      test('"${p.key}" → ${p.value}', () {
        final nav = IntentService.detectarNavegacion(p.key);
        expect(nav?.ruta, p.value, reason: 'no navegó donde se pidió');
      });
    }
    test('hay al menos 20 pedidos', () => expect(pedidos.length, greaterThanOrEqualTo(20)));
  });

  // ── Palabra entera: los pedazos de palabra no cuentan ─────────────────────
  group('productos y categorías por palabra entera', () {
    test('"pescar" no es "Caja de Pesca" ni "Cañas de pescar" cuando no hay pedido', () {
      expect(IntentService.detectarNavegacion('quiero pescar'), isNull);
    });
    test('un pedido con UNA sola palabra suelta de un producto de varias palabras no navega a ese producto', () {
      final nav = IntentService.detectarNavegacion('mostrame la caja');
      expect(nav?.ruta, isNot('/producto/p1'), reason: 'una sola palabra ("caja") no alcanza');
    });
    test('"mostrame verano" no navega a ningún producto', () {
      expect(IntentService.detectarNavegacion('mostrame el verano'), isNull);
    });
  });

  // ── Flag ──────────────────────────────────────────────────────────────────
  group('flag guia_nav_estricta', () {
    test('viene prendido por defecto', () {
      expect(IntentService.navEstricta, isTrue);
    });
    test('apagado vuelve al comportamiento de siempre (navega con la pregunta)', () {
      IntentService.navEstricta = false;
      expect(IntentService.detectarNavegacion('qué carnada uso'), isNotNull);
    });
    test('aplicarFlags lee la preferencia', () async {
      SharedPreferences.setMockInitialValues({IntentService.prefNavEstricta: false});
      IntentService.aplicarFlags(await SharedPreferences.getInstance());
      expect(IntentService.navEstricta, isFalse);
      SharedPreferences.setMockInitialValues({IntentService.prefNavEstricta: true});
      IntentService.aplicarFlags(await SharedPreferences.getInstance());
      expect(IntentService.navEstricta, isTrue);
    });
  });

  // ── Oferta: primero responde, después ofrece ──────────────────────────────
  group('oferta de navegación (nunca navega sola)', () {
    test('un tema de la tienda ofrece, con ruta', () {
      final o = IntentService.ofertaDeNavegacion('qué carnada uso para el dorado');
      expect(o, isNotNull);
      expect(o!.ruta, startsWith('/'));
      expect(o.respuesta.toLowerCase(), contains('si querés'));
    });
    test('un tema que no roza la tienda no ofrece nada', () {
      expect(IntentService.ofertaDeNavegacion('cómo se hace el nudo palomar'), isNull);
      expect(IntentService.ofertaDeNavegacion('hola, cómo andás'), isNull);
    });
    test('un pedido explícito no necesita oferta: ya navega', () {
      expect(IntentService.ofertaDeNavegacion('llevame a la tienda'), isNull);
    });
    test('el "sí" por voz acepta una oferta pendiente', () {
      for (final s in ['sí', 'si', 'dale', 'bueno', 'mostrámelo', 'sí, mostrámelas']) {
        expect(IntentService.esAceptacionDeOferta(s), isTrue, reason: s);
      }
      for (final s in ['no', 'no gracias', 'después', 'qué carnada uso', 'sí pero explicame el nudo']) {
        expect(IntentService.esAceptacionDeOferta(s), isFalse, reason: s);
      }
    });
  });

  // ── Rutas que traen las respuestas del motor (tienda, gps, notificaciones...) ──
  // El motor de reglas y el router devuelven `rutaNavegacion` para varias
  // intenciones, y el overlay navegaba solo 1 s después. Ahora decide
  // `IntentService.resolverRuta`: navega solo si la persona lo PIDIÓ.
  group('resolverRuta: la ruta de una respuesta nunca navega sola', () {
    test('una pregunta con ruta en la respuesta ofrece, no navega', () {
      final r = IntentService.resolverRuta('qué carnada uso para el dorado', '/tienda');
      expect(r.navegarA, isNull);
      expect(r.ofertaRuta, '/tienda');
      expect(r.ofertaTexto, contains('Si querés'));
    });
    test('un pedido explícito navega a la ruta pedida', () {
      final r = IntentService.resolverRuta('llevame al mapa', '/mapa');
      expect(r.navegarA, '/mapa');
      expect(r.ofertaRuta, isNull);
    });
    test('sin ruta en la respuesta, un tema de tienda igual ofrece', () {
      final r = IntentService.resolverRuta('qué anzuelo me conviene para pejerrey', null);
      expect(r.navegarA, isNull);
      expect(r.ofertaRuta, isNotNull);
    });
    test('sin ruta y sin tema de tienda, no pasa nada', () {
      final r = IntentService.resolverRuta('cómo se hace el nudo palomar', null);
      expect(r.navegarA, isNull);
      expect(r.ofertaRuta, isNull);
    });
    test('una emergencia no navega ni agrega ofertas', () {
      final r = IntentService.resolverRuta('estoy perdido en el río', '/mapa', esSeguridad: true);
      expect(r.navegarA, isNull);
      expect(r.ofertaRuta, isNull);
      expect(r.ofertaTexto, isNull);
    });
    test('con el flag apagado se conserva el comportamiento anterior (navega)', () {
      IntentService.navEstricta = false;
      final r = IntentService.resolverRuta('qué carnada uso para el dorado', '/tienda');
      expect(r.navegarA, '/tienda');
    });
  });
}
