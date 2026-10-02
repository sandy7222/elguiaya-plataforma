import 'baqueano_ia_service.dart';
import 'intent_service.dart';

/// Qué atajo detectó [GuiaAtajos.detectar].
enum TipoAtajo { silenciar, activarVoz, despedida, navegacion }

/// Un atajo de voz o de texto que el overlay ejecuta SIN pasar por el motor.
class AtajoDeVoz {
  final TipoAtajo tipo;

  /// Solo para [TipoAtajo.navegacion]: a dónde ir y qué decir.
  final NavIntencion? navegacion;

  const AtajoDeVoz(this.tipo, {this.navegacion});
}

/// Atajos que el overlay del ayudante resuelve ANTES de llamar al router de IA:
/// silenciar, volver a hablar, despedirse y navegar a una pantalla.
///
/// Se detectan por palabras sueltas ("apagar", "mudo", "habla", "anzuelo"), así
/// que una frase de emergencia puede caer en uno ("no puedo apagar el incendio"
/// → despedida). Por eso el chequeo de seguridad va primero, con la misma
/// función que usa el router.
class GuiaAtajos {
  static const List<String> _silenciar = [
    'silenciar',
    'callate',
    'cállate',
    'no hables',
    'mudo',
  ];

  static const List<String> _activarVoz = ['habla', 'hablá', 'desmutear', 'activar voz'];

  static const List<String> _despedida = [
    'chau',
    'adios',
    'adiós',
    'apagar',
    'apagate',
    'apágate',
    'hasta luego',
    'hablamos mas tarde',
    'hablamos más tarde',
    'desconecte',
    'desconéctate',
    'desconectate',
    'desconectar',
    'nos vemos',
  ];

  /// El atajo que corresponde a [texto], o null si hay que mandarlo al router.
  /// El orden es el de siempre: silenciar, activar voz, despedida, navegación.
  ///
  /// PORTÓN DE SEGURIDAD: va primero, con la MISMA función que usa el router
  /// (no una copia). Una emergencia, o un turno del modo emergencia pegajoso
  /// ("¿y ahora qué hago?", "chau"), no es un atajo: pasa al router, que la
  /// atiende el motor de reglas. Ante la duda, gana seguridad.
  static AtajoDeVoz? detectar(String texto) {
    if (BaqueanoIAService.esConsultaDeSeguridad(texto)) return null;
    final t = texto.trim().toLowerCase();
    if (_silenciar.any(t.contains)) return const AtajoDeVoz(TipoAtajo.silenciar);
    if (_activarVoz.any(t.contains)) return const AtajoDeVoz(TipoAtajo.activarVoz);
    if (_despedida.any(t.contains)) return const AtajoDeVoz(TipoAtajo.despedida);
    final nav = IntentService.detectarNavegacion(texto.trim());
    if (nav != null) return AtajoDeVoz(TipoAtajo.navegacion, navegacion: nav);
    return null;
  }
}
