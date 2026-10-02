// Tests de seguridad del router del ayudante (Fase 0 de docs/PLAN_AYUDANTE_IA.md).
//
// Regla innegociable: emergencia, primeros auxilios, VHF/Prefectura, "estoy
// perdido", GPS y lo transaccional de la app NUNCA los responde la nube, ni un
// filtro de humor, ni un retraso artificial. Los responde el motor de reglas.
//
// La nube se simula con un Groq falso que cuenta las llamadas y devuelve una
// marca reconocible. Cada caso comprueba tres cosas:
//   1. no se llamó a Groq,
//   2. el texto devuelto no es el de Groq,
//   3. (seguridad) respondió el motor de reglas, no un filtro de humor.
//
// Este archivo nace en ROJO a propósito (paso 0.1): prueba la falla del código
// de hoy. Los pasos 0.2 a 0.5 lo ponen en verde.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/models/el_guia_respuesta.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/ia_router_state.dart';

const String _marcaNube = 'RESPUESTA-DE-LA-NUBE-NO-DEBE-USARSE';

/// Temas de seguridad: siempre el motor de reglas.
const Map<String, List<String>> _seguridad = {
  'emergencia directa': [
    'me hundo',
    'se hunde la lancha',
    'hombre al agua',
    'necesito ayuda urgente',
    'mayday mayday',
    'auxilio me estoy ahogando',
    'se incendió el motor',
    'estoy en peligro',
    'tengo una emergencia',
    'pedido de socorro',
  ],
  'emergencia indirecta': [
    'se dio vuelta el bote',
    'no veo la costa',
    'entra agua al bote y no para',
    'se me cayó un pibe al río',
    'se me apagó el motor y hay tormenta',
    'estoy a la deriva',
    'se rompió el timón en medio del río',
    'quedamos varados sin combustible',
  ],
  'emergencia con urgencia': [
    'dale rápido que se hunde la lancha',
    'apurate que me ahogo',
    'rápido ayuda que se incendia el motor',
    'urgente se hunde el bote dale',
    'estoy en pura angustia se hunde la lancha',
    'apúrate que se da vuelta el bote',
  ],
  'errores de voz': [
    'prefetura',
    'se me ase agua',
    'me allogo',
    'emerjencia en el rio',
    'nesesito ayuda se undio el bote',
    'ayuda se me undio la lancha',
    'llamar a perfectura naval',
    'ase agua la lancha',
  ],
  'perdido y GPS': [
    'estoy perdido',
    'me perdí en las islas',
    'no sé dónde estoy',
    'dónde estoy',
    'cuál es mi ubicación',
    'mandame mi posición gps',
  ],
  'primeros auxilios': [
    'me corté con un anzuelo y sangra mucho',
    'se desmayó mi amigo',
    'me clavé un anzuelo en el dedo',
    'picadura de raya qué hago',
    'me quemé con el motor',
    'tengo hipotermia',
    'golpe de calor',
    'se atragantó',
    'me mordió una víbora',
    'convulsiona',
  ],
  'VHF y Prefectura': [
    'canal 16',
    'qué canal uso para pedir auxilio por radio',
    'cómo llamo por vhf a prefectura',
    'teléfono de prefectura naval',
    'frecuencia de emergencia marítima',
    'número de emergencias 106',
    'cómo uso la radio vhf',
    'prefectura naval argentina',
  ],
};

/// Transaccional: puede seguir a acción directa o tienda, pero nunca a Groq.
const List<String> _transaccional = [
  'cómo pago el viaje',
  'quiero pagar',
  'dónde veo mis cotizaciones',
  'cómo creo un viaje',
  'confirmar pago con mercado pago',
  'cómo cancelo mi reserva',
  'estado de mi viaje',
  'agregar al carrito',
  'pagar con tarjeta',
  'cómo califico al capitán',
];

int _llamadasANube = 0;

/// Prepara el entorno de un caso: nube falsa que cuenta, router "con señal" y
/// una marca de estado que un filtro de humor dejaría intacta.
void _prepararCaso({required bool conSenal}) {
  _llamadasANube = 0;
  BaqueanoIAService.reiniciarEstadoParaTest();
  BaqueanoIAService.groqParaTest = (pregunta, historial) async {
    _llamadasANube++;
    return const ElGuiaRespuesta(texto: _marcaNube, gifSugerido: 'hablaConMate');
  };
  IARouterState.modoOnline.value = conSenal;
  IARouterState.reportarEstado(IAEstado.contingencia);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
  });

  tearDown(() {
    BaqueanoIAService.reiniciarEstadoParaTest();
    IARouterState.modoOnline.value = true;
  });

  // ── Seguridad con señal: la nube nunca responde ───────────────────────────
  for (final grupo in _seguridad.entries) {
    group('CON señal · ${grupo.key}', () {
      for (final frase in grupo.value) {
        test('"$frase"', () async {
          _prepararCaso(conSenal: true);
          final resp = await BaqueanoIAService.responder(frase);
          expect(_llamadasANube, 0, reason: 'se llamó a la nube con un tema de seguridad');
          expect(resp.texto, isNot(contains(_marcaNube)));
          expect(
            IARouterState.estado.value,
            IAEstado.offline,
            reason: 'tenía que responder el motor de reglas, no un filtro de humor ni la nube',
          );
        });
      }
    });
  }

  // ── Seguridad sin señal: responde el motor de reglas, no un filtro de humor ─
  for (final grupo in _seguridad.entries) {
    group('SIN señal · ${grupo.key}', () {
      for (final frase in grupo.value) {
        test('"$frase"', () async {
          _prepararCaso(conSenal: false);
          final resp = await BaqueanoIAService.responder(frase);
          expect(_llamadasANube, 0);
          expect(resp.texto, isNot(contains(_marcaNube)));
          expect(
            IARouterState.estado.value,
            IAEstado.offline,
            reason: 'tenía que responder el motor de reglas, no un filtro de humor',
          );
        });
      }
    });
  }

  // ── Transaccional: puede seguir sus caminos, pero nunca a la nube ─────────
  group('CON señal · transaccional', () {
    for (final frase in _transaccional) {
      test('"$frase"', () async {
        _prepararCaso(conSenal: true);
        final resp = await BaqueanoIAService.responder(frase);
        expect(_llamadasANube, 0, reason: 'se llamó a la nube con un tema transaccional');
        expect(resp.texto, isNot(contains(_marcaNube)));
      });
    }
  });

  // ── Modo emergencia pegajoso: los 3 turnos siguientes también van a reglas ─
  group('modo emergencia pegajoso', () {
    const seguimientos = [
      'y ahora qué hago?',
      'no sé qué hacer',
      'qué más',
    ];

    test('después de una emergencia, los 3 turnos siguientes no usan la nube', () async {
      _prepararCaso(conSenal: true);
      await BaqueanoIAService.responder('se hunde la lancha');
      for (final frase in seguimientos) {
        final resp = await BaqueanoIAService.responder(frase);
        expect(_llamadasANube, 0, reason: 'seguimiento "$frase" llegó a la nube');
        expect(resp.texto, isNot(contains(_marcaNube)));
        expect(IARouterState.estado.value, IAEstado.offline);
      }
    });

    test('el modo emergencia vence: el cuarto turno ya puede usar la nube', () async {
      _prepararCaso(conSenal: true);
      await BaqueanoIAService.responder('se hunde la lancha');
      for (final frase in seguimientos) {
        await BaqueanoIAService.responder(frase);
      }
      await BaqueanoIAService.responder('qué carnada uso para el dorado en el río');
      expect(_llamadasANube, 1, reason: 'pasados los 3 turnos, la nube vuelve a poder responder');
    });
  });
}
