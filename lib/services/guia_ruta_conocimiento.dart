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
    // peces en general, hábitat, vedas y cupos (datos que nunca se inventan: si no hay ficha, se dice), cebos
    'pez', 'peces', 'especie', 'especies', 'habitat', 'habitats', 'veda', 'vedas', 'cupo', 'cupos', 'cebo', 'cebos', 'lombriz',
    'lombrices', 'cardumen', 'cardumenes',
  };

  /// Intenciones del motor que son conocimiento de pesca (las bibliotecas peces, carnadas, cañas y reeles, nudos, plomadas, boyas
  /// y las fichas "como_/cuando_/donde_/que_sirve_/que_se_/conocer_..."). Las sociales, transaccionales y de seguridad NO entran.
  static const Set<String> _intencionesDeConocimiento = {
    'peces', 'conocer_peces_argentinos', 'habitat', 'carnadas', 'canas_y_reeles', 'nudos', 'plomadas', 'boyas', 'rio',
  };
  static const List<String> _prefijos = ['como_', 'cuando_', 'donde_', 'que_sirve_', 'que_se_', 'conocer_'];

  static bool esIntencionDeConocimiento(String intencion) =>
      _intencionesDeConocimiento.contains(intencion) || _prefijos.any(intencion.startsWith);

  /// ¿La frase pregunta por conocimiento de pesca (alguna palabra entera del vocabulario de pesca)?
  static bool esConocimientoDePesca(String pregunta) {
    final palabras = GuiaTextoEs.normalizar(pregunta).split(' ');
    return palabras.any(_palabras.contains);
  }

  /// ¿Esta pregunta tiene que contestarla el motor local aunque haya señal?
  static bool debeResponderLocal(String pregunta, {String intencion = ''}) =>
      habilitado && (esConocimientoDePesca(pregunta) || esIntencionDeConocimiento(intencion));
}
