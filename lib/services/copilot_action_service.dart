import 'guia_copilot_brain.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  CopilotActionService — Detección de acciones contextuales por pantalla
//
//  Diferencia con IntentService: IntentService navega a rutas.
//  CopilotActionService ejecuta ACCIONES DENTRO de la pantalla activa.
//
//  Tier 0 del router — responde en < 5ms, sin llamar a IA.
// ─────────────────────────────────────────────────────────────────────────────

/// Acción que el copiloto puede ejecutar directamente en la UI activa.
class CopilotAction {
  /// Tipo de acción: 'confirmar' | 'accion_mapa' | 'accion_tienda' | 'mostrar_info'
  final String tipo;

  /// Lo que el Guía dice al ejecutar la acción.
  final String respuesta;

  /// GIF del personaje para esta respuesta.
  final String gifSugerido;

  /// Para acciones de formulario o pantalla — se delega vía CopilotChannel.
  final Map<String, dynamic>? payload;

  /// Para acciones que además navegan a otra pantalla.
  final String? ruta;

  const CopilotAction({
    required this.tipo,
    required this.respuesta,
    this.gifSugerido = 'exito',
    this.payload,
    this.ruta,
  });
}

class CopilotActionService {
  /// Detecta si la frase, combinada con el contexto actual de pantalla,
  /// genera una acción concreta — más allá de solo texto.
  ///
  /// Retorna null si no hay acción contextual → cae al flujo IA normal.
  static CopilotAction? detectarAccion(
    String frase,
    ScreenContext pantallaActiva,
    AppAction? accionActiva,
  ) {
    final f = frase.toLowerCase().trim();

    switch (pantallaActiva) {

      // ── COTIZACIÓN ─────────────────────────────────────────────────────────
      case ScreenContext.cotizacion:
        if (_contiene(f, ['acepto', 'lo tomo', 'confirmá', 'confirmar',
            'lo confirmo', 'dale confirmo', 'sí lo tomo'])) {
          return const CopilotAction(
            tipo: 'confirmar',
            respuesta:
                'Dale chamigo, confirmando la cotización. Revisalo antes de pagar.',
            payload: {'accion': 'confirmar_cotizacion'},
          );
        }
        if (_contiene(f, ['cuánto', 'cuanto', 'precio', 'cuesta', 'monto',
            'total', 'cuanto sale', 'cuánto sale'])) {
          return const CopilotAction(
            tipo: 'mostrar_info',
            respuesta:
                'El total lo ves en la tarjeta de cotización, chamigo. ¿Lo confirmamos?',
            gifSugerido: 'hablaConMate',
          );
        }
        if (_contiene(f, ['no lo acepto', 'rechazar', 'no me sirve',
            'muy caro', 'demasiado caro'])) {
          return const CopilotAction(
            tipo: 'rechazar',
            respuesta:
                'Entiendo chamigo. Podés pedir otra cotización o elegir otro capitán.',
            gifSugerido: 'piensaLeve',
            payload: {'accion': 'rechazar_cotizacion'},
          );
        }

      // ── MAPA ───────────────────────────────────────────────────────────────
      case ScreenContext.mapa:
        if (_contiene(f, ['dónde estoy', 'donde estoy', 'mi posición',
            'mi ubicacion', 'mi ubicación', 'donde me encuentro',
            'dónde me encuentro', 'centrar', 'centrame'])) {
          return const CopilotAction(
            tipo: 'accion_mapa',
            respuesta: 'Centrando el mapa en tu posición, chamigo.',
            payload: {'accion': 'centrar_en_usuario'},
          );
        }
        if (_contiene(f, ['capitán', 'capitan', 'capitanes cerca',
            'quién está cerca', 'quien esta cerca', 'mostrar capitanes',
            'ver capitanes'])) {
          return const CopilotAction(
            tipo: 'accion_mapa',
            respuesta: 'Buscando capitanes disponibles cerca tuyo.',
            payload: {'accion': 'mostrar_capitanes'},
          );
        }
        if (_contiene(f, ['alejá', 'aleja', 'zoom out', 'ver más',
            'ver todo el río', 'ver todo el rio'])) {
          return const CopilotAction(
            tipo: 'accion_mapa',
            respuesta: 'Abriendo la vista del mapa, chamigo.',
            payload: {'accion': 'zoom_out'},
          );
        }

      // ── PAGO ───────────────────────────────────────────────────────────────
      case ScreenContext.pago:
        if (_contiene(f, ['pagar', 'lo pago', 'confirmar pago',
            'proceder al pago', 'confirmo el pago', 'seguir con el pago'])) {
          return const CopilotAction(
            tipo: 'confirmar',
            respuesta:
                '¿Seguro chamigo? Revisá el monto antes de confirmar el pago.',
            gifSugerido: 'piensaLeve',
            payload: {'accion': 'solicitar_confirmacion_pago'},
          );
        }

      // ── TIENDA ─────────────────────────────────────────────────────────────
      case ScreenContext.tienda:
        if (_contiene(f, ['agregar', 'lo quiero', 'al carrito',
            'lo compro', 'quiero ese', 'quiero esa', 'añadir'])) {
          return const CopilotAction(
            tipo: 'accion_tienda',
            respuesta: 'Lo agrego al carrito, chamigo.',
            payload: {'accion': 'agregar_al_carrito'},
          );
        }

      // ── CARRITO ────────────────────────────────────────────────────────────
      case ScreenContext.carrito:
        if (_contiene(f, ['vaciar', 'borrar todo', 'limpiar carrito',
            'sacar todo', 'eliminar todo'])) {
          return const CopilotAction(
            tipo: 'accion_carrito',
            respuesta:
                'Uff chamigo, vas a vaciar el carrito. ¿Estás seguro?',
            gifSugerido: 'duda',
            payload: {'accion': 'confirmar_vaciar_carrito'},
          );
        }
        if (_contiene(f, ['finalizar compra', 'pagar el carrito',
            'proceder', 'ir al pago'])) {
          return const CopilotAction(
            tipo: 'accion_carrito',
            respuesta: 'Dale, vamos al pago, chamigo.',
            payload: {'accion': 'ir_al_pago'},
            ruta: '/pago',
          );
        }

      // ── CALIFICACIÓN ───────────────────────────────────────────────────────
      case ScreenContext.calificacion:
        if (_contiene(f, ['cinco estrellas', '5 estrellas', 'excelente',
            'muy bueno', 'lo mejor'])) {
          return const CopilotAction(
            tipo: 'accion_calificacion',
            respuesta:
                '¡Buenísimo! Calificando con cinco estrellas al capitán.',
            gifSugerido: 'exito',
            payload: {'accion': 'calificar', 'estrellas': 5},
          );
        }

      // ── INICIO ─────────────────────────────────────────────────────────────
      case ScreenContext.inicio:
        if (_contiene(f, ['crear viaje', 'quiero salir', 'armar viaje',
            'reservar viaje', 'hacer una reserva'])) {
          return const CopilotAction(
            tipo: 'navegar',
            respuesta:
                'Dale chamigo, vamos a armar el viaje. Te abro el mapa.',
            gifSugerido: 'exito',
            ruta: '/mapa',
          );
        }

      default:
        break;
    }

    return null; // Sin acción contextual — cae al flujo IA normal
  }

  // Utilidad interna — comprueba si la frase contiene alguno de los tokens
  static bool _contiene(String frase, List<String> tokens) =>
      tokens.any((t) => frase.contains(t));
}
