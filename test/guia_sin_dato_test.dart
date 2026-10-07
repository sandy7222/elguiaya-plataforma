// Paso 3 (parte 2): cuando la nube dice que no tiene el dato, la respuesta termina ahí.
//
// Prueba del dueño en el Moto G15: "primero te avisa que ese dato de la pregunta no lo tiene, luego empieza a inventar".
// El prompt nuevo le pide cortar, pero el prompt solo no alcanza: el verificador (paso 1.8) se queda con la primera oración
// cuando esa oración es un "no tengo ese dato" y descarta lo que sigue. Solo corta en el límite de una oración, y solo si el
// "no tengo" es la PRIMERA oración (un "no tengo" en el medio de una respuesta útil no se toca).

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/services/guia_verificador_datos.dart';

String _v(String t, {String contexto = ''}) => GuiaVerificadorDatos.cortarTrasSinDato(t).texto;

void main() {
  group('si arranca con "no tengo ese dato", se corta ahí', () {
    const casos = {
      'No tengo ese dato. La mojarra pica mejor con lombriz y a media agua. Visitá la tienda para ver cañas.': 'No tengo ese dato.',
      'Ese dato no lo tengo. Igual te cuento que la mojarra se pesca de día. Escribinos a info@elguiaya.com.': 'Ese dato no lo tengo.',
      'Chamigo, no tengo ese dato. La mojarra anda por los juncales.': 'Chamigo, no tengo ese dato.',
      'No tengo esa información. Pero seguramente la mojarra pique de tarde.': 'No tengo esa información.',
      'No cuento con ese dato. Te recomiendo una caña de 2 metros.': 'No cuento con ese dato.',
      'No tengo datos sobre eso. La mojarra es un pez chico.': 'No tengo datos sobre eso.',
    };
    casos.forEach((entrada, esperado) {
      test(entrada.split('.').first, () => expect(_v(entrada), esperado));
    });
  });

  test('la frase exacta que el prompt de datos le manda decir también corta lo que sigue', () {
    const t = '${GuiaVerificadorDatos.reemplazo} Pero el río suele estar medio. Visitá la tienda.';
    expect(_v(t), GuiaVerificadorDatos.reemplazo);
  });

  test('verificar() no recorta: lo que pone el verificador seguido de contenido legítimo se conserva', () {
    const t = '${GuiaVerificadorDatos.reemplazo} El dorado pica.';
    expect(GuiaVerificadorDatos.verificar(t, contexto: '').texto, t);
  });

  group('lo legítimo no se toca', () {
    const intactas = [
      'La mojarra se pesca con lombriz en aguas quietas.',
      'Hoy hay 16 °C y viento del este. No tengo ese dato del nivel del río.',
      'Llevá agua y abrigo. No tengo más datos por ahora.',
      'No tengo problema en ayudarte. Contame qué buscás.',
      'No es ese el lugar, probá más al sur.',
    ];
    for (final t in intactas) {
      test('"$t"', () => expect(_v(t, contexto: 'Temp: 16°C Viento: este'), t));
    }
  });

  test('solo corta en el límite de una oración (un "no tengo ese dato, pero…" en la misma oración se deja)', () {
    // No se parte una oración al medio: lo que sigue a la coma es parte de la misma oración.
    const t = 'No tengo ese dato, pero si querés te cuento de la mojarra.';
    expect(_v(t), t);
  });

  test('es idempotente', () {
    const t = 'No tengo ese dato. La mojarra pica con lombriz.';
    expect(_v(_v(t)), _v(t));
  });

  test('informa qué cortó (para el registro)', () {
    final r = GuiaVerificadorDatos.cortarTrasSinDato('No tengo ese dato. La mojarra pica con lombriz.');
    expect(r.corrigio, isTrue);
    expect(r.reemplazos.join(' '), contains('lombriz'));
  });

  test('groq_service corta tras "no tengo ese dato" ANTES de verificar', () {
    final c = File('lib/services/groq_service.dart').readAsStringSync();
    final corte = c.indexOf('GuiaVerificadorDatos.cortarTrasSinDato(');
    final verif = c.indexOf('GuiaVerificadorDatos.verificar(');
    expect(corte, greaterThan(0));
    expect(corte, lessThan(verif));
  });
}
