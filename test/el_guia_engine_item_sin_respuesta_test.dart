// Prueba del dueño (paso 4): "¿cuándo es la veda del surubí?" caía en el motor local y este reventaba con
// "type 'Null' is not a subtype of type 'String'" (el usuario veía "me trabé un segundo"). Causa: `_generarRespuestaPorIntencion` arma
// `List<String>.from(item['respuestas'] ?? [item['respuesta_limpia']])` y un ítem de las intenciones dinámicas sin ninguna de las dos
// da [null]. Un ítem sin texto se saltea; nunca rompe. Y de las vedas no se inventa nada (regla 2): si no hay ficha, "no tengo ese dato".

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capitanya_master/services/baqueano_ia_service.dart';
import 'package:capitanya_master/services/el_guia_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await BaqueanoIAService.inicializarParaTest();
    // El buscador de fichas se arma en segundo plano: si todavía no está listo (o está apagado) contesta el motor de reglas, y por
    // ahí rompía. Se fuerza ese camino para que el test sea determinista.
    ElGuiaEngine.bm25Habilitado = false;
  });
  tearDownAll(() => ElGuiaEngine.bm25Habilitado = true);

  for (final p in [
    'cuándo es la veda del surubí',
    'cuándo es la veda del dorado',
    'hasta cuándo está vedado el pejerrey',
    'cuál es la medida mínima del dorado',
  ]) {
    test('"$p" no rompe el motor local', () async {
      final r = await ElGuiaEngine().responder(p);
      expect(r.texto.trim(), isNotEmpty);
      expect(r.texto, isNot(contains('me trabé')));
    });
  }

  test('las vedas no se inventan: no hay fechas ni números inventados en la respuesta', () async {
    final r = await ElGuiaEngine().responder('cuándo es la veda del surubí');
    expect(RegExp(r'\d').hasMatch(r.texto), isFalse, reason: r.texto);
  });
}
