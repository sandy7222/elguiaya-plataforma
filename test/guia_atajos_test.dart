// Paso 0.6 de docs/PLAN_AYUDANTE_IA.md: el portón de seguridad también en el
// overlay.
//
// El overlay del ayudante resuelve cuatro atajos ANTES de llamar al router:
// silenciar, volver a hablar, despedirse y navegar. Se detectan por palabras
// sueltas, así que una emergencia podía caer en uno: "no puedo apagar el
// incendio" → el ayudante se despedía y se apagaba; "necesito un chaleco
// salvavidas, se hunde el bote" → navegaba a la tienda; "se me clavó un
// anzuelo" → abría la tienda. Sin pasar nunca por seguridad.
//
// Estos tests corren con productos y categorías cargados en el caché, como en
// la app real: sin eso la navegación por producto no se dispararía y el
// problema quedaría escondido.
//
// Este archivo nace en ROJO a propósito: prueba la falla del código de hoy.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/categoria.dart';
import 'package:capitanya_master/models/producto.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/guia_atajos.dart';
import 'package:capitanya_master/services/ia_router_state.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'frases_seguridad.dart';

Producto _producto(String id, String nombre) => Producto(
      id: id,
      nombre: nombre,
      descripcion: '',
      precio: 1000,
      stock: 5,
      rubro: 'Náutica',
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

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
    // Productos y categorías cuyos nombres chocan con palabras de emergencia.
    SupabaseService.cachedProductos
      ..clear()
      ..addAll([
        _producto('p1', 'Chaleco salvavidas adulto'),
        _producto('p2', 'Ancla plegable 5 kg'),
        _producto('p3', 'Radio VHF portátil'),
        _producto('p4', 'Bote inflable'),
        _producto('p5', 'Botiquín de primeros auxilios'),
        _producto('p6', 'Bengalas de señales'),
        _producto('p7', 'Anzuelo triple N4'),
        _producto('p8', 'Plomada pasante'),
        _producto('p9', 'Linterna impermeable'),
      ]);
    SupabaseService.cachedCategorias
      ..clear()
      ..addAll([
        _categoria('k1', 'Seguridad náutica'),
        _categoria('k2', 'Primeros auxilios'),
        _categoria('k3', 'Radios y comunicación'),
        _categoria('k4', 'Embarcaciones'),
        _categoria('k5', 'Anclas y fondeo'),
        _categoria('k6', 'Anzuelos'),
      ]);
  });

  tearDownAll(() {
    SupabaseService.cachedProductos.clear();
    SupabaseService.cachedCategorias.clear();
  });

  setUp(() {
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = false;
  });

  // ── Seguridad: ningún atajo ───────────────────────────────────────────────
  group('una frase de seguridad nunca dispara un atajo', () {
    for (final grupo in frasesSeguridad.entries) {
      for (final frase in grupo.value) {
        test('[${grupo.key}] "$frase"', () {
          final atajo = GuiaAtajos.detectar(frase);
          expect(
            atajo,
            isNull,
            reason: 'disparó "${atajo?.tipo.name}"'
                '${atajo?.navegacion != null ? ' → ${atajo!.navegacion!.ruta}' : ''}: '
                'una emergencia tiene que llegar al motor de reglas, no a un atajo',
          );
        });
      }
    }
  });

  // ── Frases donde una palabra suelta chocaba con un atajo ───────────────────
  group('palabras sueltas que chocaban con un atajo', () {
    const choques = {
      // despedida: "apagar", "chau", "desconectar"
      'no puedo apagar el incendio del motor': 'despedida',
      'chau chau me hundo': 'despedida',
      'tengo que apagar el motor, se hunde el bote': 'despedida',
      'hay que desconectar la batería, se incendia el bote': 'despedida',
      // silenciar: "mudo", "no hables"
      'quedé mudo, se hunde el bote': 'silenciar',
      'no hables, se hunde la lancha': 'silenciar',
      // volver a hablar: "habla" (también dentro de "hablame")
      'hablá con prefectura que se hunde la lancha': 'activarVoz',
      'habla por radio con prefectura, nos hundimos': 'activarVoz',
      // navegación: productos y categorías del caché, "tienda", "mapa", "podés"
      'necesito un chaleco salvavidas urgente, se hunde el bote': 'navegacion',
      'mostrame dónde está el botiquín, me corté con un anzuelo y sangra mucho': 'navegacion',
      'podés ayudarme, perdí el ancla y me arrastra la corriente': 'navegacion',
      'se me clavó un anzuelo qué hago?': 'navegacion',
      'abrí el mapa que estoy perdido en el río': 'navegacion',
      'llevame a la radio vhf, se hunde la lancha': 'navegacion',
    };
    for (final c in choques.entries) {
      test('"${c.key}" (hoy dispararía: ${c.value})', () {
        expect(GuiaAtajos.detectar(c.key), isNull);
      });
    }
  });

  // ── Lo que NO es seguridad sigue funcionando ──────────────────────────────
  group('los atajos normales siguen funcionando', () {
    test('silenciar', () => expect(GuiaAtajos.detectar('silenciar')?.tipo, TipoAtajo.silenciar));
    test('callate', () => expect(GuiaAtajos.detectar('callate')?.tipo, TipoAtajo.silenciar));
    test('hablá', () => expect(GuiaAtajos.detectar('hablá')?.tipo, TipoAtajo.activarVoz));
    test('chau', () => expect(GuiaAtajos.detectar('chau')?.tipo, TipoAtajo.despedida));
    test('hasta luego', () => expect(GuiaAtajos.detectar('hasta luego')?.tipo, TipoAtajo.despedida));
    test('nos vemos', () => expect(GuiaAtajos.detectar('nos vemos')?.tipo, TipoAtajo.despedida));

    test('llevame a la tienda', () {
      final a = GuiaAtajos.detectar('llevame a la tienda');
      expect(a?.tipo, TipoAtajo.navegacion);
      expect(a?.navegacion?.ruta, '/tienda');
    });

    test('mostrame el mapa', () {
      final a = GuiaAtajos.detectar('mostrame el mapa');
      expect(a?.tipo, TipoAtajo.navegacion);
      expect(a?.navegacion?.ruta, '/mapa');
    });

    test('comprar un producto del caché navega al producto', () {
      final a = GuiaAtajos.detectar('quiero ver el chaleco salvavidas');
      expect(a?.tipo, TipoAtajo.navegacion);
      expect(a?.navegacion?.ruta, '/producto/p1');
    });

    // La intención "gps" también tiene activadores de NAVEGACIÓN ("mapa", "ver
    // mapa", "llevame al", "cómo llegar"): pedir el mapa no es una emergencia.
    // Es seguridad solo cuando pide su ubicación ("dónde estoy").
    for (final frase in [
      'mostrame el mapa',
      'abrí el mapa',
      'ver el mapa del río',
      'quiero ver los puntos de pesca',
      'cómo llegar a zárate',
      'llevame al mapa',
      'abrir gps',
    ]) {
      test('"$frase" es navegación de la app, no seguridad', () {
        expect(BaqueanoIAService.esConsultaDeSeguridad(frase), isFalse);
      });
    }

    test('"mostrame el mapa que estoy perdido" SÍ es seguridad (pide el mapa perdido)', () {
      expect(BaqueanoIAService.esConsultaDeSeguridad('mostrame el mapa que estoy perdido'), isTrue);
    });

    test('lo transaccional conserva sus atajos (el portón es solo de seguridad)', () {
      expect(BaqueanoIAService.esConsultaDeSeguridad('agregar al carrito'), isFalse);
      expect(BaqueanoIAService.esConsultaDeSeguridad('cómo pago el viaje'), isFalse);
    });
  });

  // ── La misma función que el router ────────────────────────────────────────
  group('esConsultaDeSeguridad es la misma regla del router', () {
    for (final grupo in frasesSeguridad.entries) {
      for (final frase in grupo.value) {
        test('[${grupo.key}] "$frase"', () {
          expect(BaqueanoIAService.esConsultaDeSeguridad(frase), isTrue);
        });
      }
    }
  });

  // ── Modo emergencia pegajoso ──────────────────────────────────────────────
  group('modo emergencia pegajoso en el overlay', () {
    test('después de una emergencia, "chau" no apaga el ayudante durante 3 turnos', () async {
      await BaqueanoIAService.responder('se hunde la lancha');
      expect(GuiaAtajos.detectar('chau'), isNull, reason: 'turno 1 de 3');
      await BaqueanoIAService.responder('y ahora qué hago?');
      expect(GuiaAtajos.detectar('chau'), isNull, reason: 'turno 2 de 3');
      await BaqueanoIAService.responder('no sé qué hacer');
      expect(GuiaAtajos.detectar('chau'), isNull, reason: 'turno 3 de 3');
      await BaqueanoIAService.responder('qué más');
      expect(GuiaAtajos.detectar('chau')?.tipo, TipoAtajo.despedida,
          reason: 'pasados los 3 turnos el atajo vuelve a funcionar');
    });

    test('después de una emergencia, un comando de navegación tampoco navega', () async {
      await BaqueanoIAService.responder('se me clavó un anzuelo qué hago?');
      expect(GuiaAtajos.detectar('llevame a la tienda'), isNull);
    });
  });
}
