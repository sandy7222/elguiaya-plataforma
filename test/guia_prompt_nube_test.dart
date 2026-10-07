// Paso 3: el texto de instrucciones que se le manda a la nube (Groq) para el chat del Guía.
//
// Medido en el Moto G15 (docs/ESTADO.md): ante "pesca de mojarra" el Guía dijo que no tenía el dato, siguió inventando, hizo un
// recorrido por la tienda y dio dirección y correo, y habló minutos. Causas en el texto actual (capacitacion_service.dart):
//   · "ROL PRINCIPAL — ASESOR DE VENTAS… impulsar la venta", "usálos sin dudar ni avisar que no podés", "NUNCA digas que no tenés
//     el URL", "respondé siempre con estos datos" de contacto;
//   · conocimiento de pesca por zona escrito en el prompt (fuente de invención);
//   · sin tope de largo para una respuesta que se lee en voz alta;
//   · el protocolo |||APRENDO||| (el aprendizaje automático está apagado desde el paso 2).
// El prompt nuevo es corto, sin rol de ventas, con respuesta de 3 oraciones como máximo y "no tengo ese dato" y se termina ahí.

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/guia_prompt_nube.dart';

void main() {
  final p = GuiaPromptNube.sistema(zona: 'general');

  group('lo que el texto anterior le mandaba hacer y ya no', () {
    test('no es un vendedor', () {
      final t = p.toLowerCase();
      expect(t, isNot(contains('asesor de ventas')));
      expect(t, isNot(contains('impulsar la venta')));
      expect(t, isNot(contains('impulsar')));
    });
    test('no le ordena usar la tienda "sin avisar que no puede"', () {
      expect(p.toLowerCase(), isNot(contains('sin dudar ni avisar')));
      expect(p.toLowerCase(), isNot(contains('nunca digas que no tenés')));
    });
    test('no lleva datos de contacto escritos (solo se agregan si el usuario los pide)', () {
      expect(p, isNot(contains('info@elguiaya.com')));
      expect(p, isNot(contains('4899')));
    });
    test('no trae conocimiento de pesca por zona escrito a mano', () {
      for (final f in ['Chascomús', 'Pejerrey', 'pejerrey', 'Juramento', 'Bermejo', 'Ushuaia', 'trolling', 'brótola']) {
        expect(p, isNot(contains(f)), reason: f);
      }
    });
    test('no pide el bloque |||APRENDO||| con el aprendizaje apagado', () {
      expect(p, isNot(contains('APRENDO')));
    });
    test('no promete que un reclamo "queda guardado" (el chat no lo guarda)', () {
      expect(p.toLowerCase(), isNot(contains('queda guardado')));
    });
  });

  group('lo que sí tiene que decir', () {
    test('respuesta corta: 3 oraciones como máximo, para leerse en voz alta', () {
      expect(p, contains('3 oraciones'));
      expect(p.toLowerCase(), contains('voz alta'));
    });
    test('sin dato: lo dice en una oración y termina ahí', () {
      expect(p, contains('No tengo ese dato'));
      expect(p.toLowerCase(), contains('terminá ahí'));
    });
    test('prohíbe inventar datos concretos', () {
      final t = p.toLowerCase();
      for (final w in ['medidas', 'vedas', 'carnadas', 'técnicas', 'precios', 'teléfonos']) {
        expect(t, contains(w), reason: w);
      }
    });
    test('solo afirma lo que figura en el contexto del mensaje', () {
      expect(p.toLowerCase(), contains('contexto'));
    });
    test('deja las emergencias, el GPS y los pagos a la app', () {
      final t = p.toLowerCase();
      expect(t, contains('emergencias'));
      expect(t, contains('gps'));
      expect(t, contains('pagos'));
    });
    test('es español rioplatense', () {
      expect(p, contains('rioplatense'));
    });
  });

  group('enlaces', () {
    test('los enlaces oficiales solo se dan si el usuario los pide', () {
      expect(p, contains('https://elguiaya.com/#/tienda'));
      expect(p.toLowerCase(), contains('solo si te los piden'));
    });
  });

  group('zona', () {
    test('si hay zona, se la menciona sin cargar conocimiento', () {
      final z = GuiaPromptNube.sistema(zona: 'patagonia');
      expect(z, contains('PATAGONIA'));
      expect(z.toLowerCase(), isNot(contains('trucha')));
    });
    test('zona general no agrega nada', () {
      expect(p, isNot(contains('GENERAL')));
    });
  });

  group('aprendizaje (solo si se reactiva el flag)', () {
    test('con el aprendizaje encendido se agrega el protocolo', () {
      final t = GuiaPromptNube.sistema(zona: 'general', conAprendizaje: true);
      expect(t, contains('|||APRENDO|||'));
    });
  });

  test('es corto: menos de 2000 caracteres (el anterior pasaba los 5000)', () {
    expect(p.length, lessThan(2000));
  });

  test('groq_service y capacitacion_service usan el prompt nuevo, no el viejo', () {
    final groq = File('lib/services/groq_service.dart').readAsStringSync();
    expect(groq, contains('GuiaPromptNube.sistema('));
    expect(groq, isNot(contains('REGLA 2 — PROTOCOLO DE APRENDIZAJE AUTOMÁTICO')));
    final cap = File('lib/services/capacitacion_service.dart').readAsStringSync();
    expect(cap, isNot(contains('ROL PRINCIPAL — ASESOR DE VENTAS')));
    expect(cap, contains('GuiaPromptNube.sistema('));
  });
}
