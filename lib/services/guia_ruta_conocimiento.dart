import 'package:shared_preferences/shared_preferences.dart';
import 'guia_retrieval/guia_texto_es.dart';

/// Paso 4: el conocimiento de pesca (técnica, carnada, especie, equipo) lo contesta el motor local, no la nube.
///
/// El router mandaba a la nube todo lo que no fuera seguridad, transaccional o condiciones; en el Moto G15 "pesca de mojarra" salió de
/// ahí y la nube inventó. El motor local (BM25 + fichas + "no tengo ese dato" honesto) es la fuente de este conocimiento, con o sin
/// señal. La nube queda para la charla. Flag `guia_pesca_local` (encendido por defecto; apagado vuelve al camino anterior).
///
/// Compara PALABRAS ENTERAS (callejón sin salida de AGENTS.md: `contains` hacía que "pescar" matcheara "Caja de Pesca").
class GuiaRutaConocimiento {
  static const String prefPescaLocal = 'guia_pesca_local';
  static bool habilitado = true;

  static void aplicarFlags(SharedPreferences prefs) {
    habilitado = prefs.getBool(prefPescaLocal) ?? habilitado;
  }

  static const Set<String> _palabras = {
    // pesca y equipo
    'pesca', 'pescar', 'pesco', 'pescas', 'pescan', 'pescamos', 'pescando', 'pique', 'piques', 'carnada', 'carnadas', 'senuelo',
    'senuelos', 'anzuelo', 'anzuelos', 'cana', 'canas', 'reel', 'reeles', 'aparejo', 'aparejos', 'plomada', 'plomadas', 'boya',
    'boyas', 'spinning', 'trolling', 'nudo', 'nudos', 'mosca', 'carrete', 'carretel', 'fly',
    // especies
    'dorado', 'dorados', 'surubi', 'surubis', 'pejerrey', 'pejerreyes', 'mojarra', 'mojarras', 'boga', 'bogas', 'sabalo', 'sabalos',
    'tararira', 'tarariras', 'bagre', 'bagres', 'pati', 'patis', 'armado', 'armados', 'carpa', 'carpas', 'corvina', 'corvinas',
    'pacu', 'mimoso', 'moncholo', 'lenguado', 'pescadilla', 'brotola', 'trucha', 'truchas', 'salmon', 'perca', 'percas',
    'dientudo', 'vieja', 'anchoa', 'tiburon', 'palometa', 'manduva',
  };

  /// ¿La frase pregunta por conocimiento de pesca (alguna palabra entera del vocabulario de pesca)?
  static bool esConocimientoDePesca(String pregunta) {
    final palabras = GuiaTextoEs.normalizar(pregunta).split(' ');
    return palabras.any(_palabras.contains);
  }

  /// ¿Esta pregunta tiene que contestarla el motor local aunque haya señal?
  static bool debeResponderLocal(String pregunta) => habilitado && esConocimientoDePesca(pregunta);
}
