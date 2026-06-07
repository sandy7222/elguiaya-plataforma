import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http; // 'http://localhost:11434'
import 'package:path_provider/path_provider.dart';
import 'el_guia_context.dart';
import 'guia_local_updater.dart';
import 'el_guia_app_engine.dart';
import 'el_guia_humor_engine.dart';
import 'guia_logger.dart';
import '../models/el_guia_respuesta.dart';

/// Motor Conversacional Híbrido — El Guía  v2.0
/// Arquitectura de tres capas:
///   Capa 1: Personalidad (personalidad.json)
///   Capa 2: Motor de Intenciones (tabla de prioridades interna)
///   Capa 3: Librerías de Conocimiento (JSON por tema)
///
/// Novedades v2.0:
///   - Nuevas intenciones: agradecimiento, hora, charla_cotidiana
///   - Frases ambient por estado del GIF (frases_ambiente.json)
///   - Libreto completamente reescrito en español argentino ribereño
class ElGuiaEngine {
  static final ElGuiaEngine _instance = ElGuiaEngine._internal();
  factory ElGuiaEngine() => _instance;
  ElGuiaEngine._internal();

  // ── Estado ────────────────────────────────────────────────────────────────
  bool _inicializado = false;
  final ElGuiaContext _contexto = ElGuiaContext();
  final Random _random = Random();

  // ── Datos cargados desde assets ───────────────────────────────────────────
  Map<String, dynamic> _personalidad = {};
  final Map<String, Map<String, dynamic>> _librerias = {};

  // ── Motor de navegación de la app ───────────────────────────────────────────────
  final ElGuiaAppEngine _appEngine = ElGuiaAppEngine();

  // ── Motor de humor contextual ───────────────────────────────────────────────
  final ElGuiaHumorEngine _humor = ElGuiaHumorEngine();

  // ── Tabla de Prioridades (nivel más bajo = mayor prioridad) ───────────────
  static const Map<int, String> _prioridades = {
    1: 'emergencia',
    2: 'prefectura_naval_argentina',
    3: 'perdido',
    4: 'agua',
    5: 'refugio',
    6: 'fuego',
    7: 'alimento',
    8: 'clima',
    9: 'crear_viaje',
    10: 'ver_cotizaciones',
    11: 'estado_viaje',
    12: 'pagar_viaje',
    13: 'confirmar_viaje',
    14: 'calificar',
    15: 'gps',
    16: 'primeros_auxilios',
    17: 'peces',
    18: 'carnadas',
    19: 'nudos',
    20: 'boyas',
    21: 'plomadas',
    22: 'canas_y_reeles',
    23: 'rio',
    24: 'tienda',
    25: 'notificaciones',
    26: 'perfil_pescador',
    27: 'activar_guia',
    28: 'reserva',
    29: 'ayuda_app',
    30: 'hora',
    31: 'agradecimiento',
    32: 'preguntas_humanas',
    33: 'mate',
    34: 'charla_cotidiana',
    35: 'chiste',
    36: 'saludo',
    37: 'despedida',
    38: 'que_puede_hacer_bot',
    39: 'elegir_capitan',
    40: 'carrito',
    41: 'historial_viajes',
    42: 'ayuda_general',
    43: 'fallback',
  };

  // ── Activadores de intenciones ────────────────────────────────────────────
  static final Map<String, List<String>> _activadores = {
    'prefectura_naval_argentina': [
      'prefectura',
      'pna',
      'canal 16',
      'canal vhf',
      'vhf 16',
      'canal de socorro',
      'llamar por radio',
      'radio vhf',
      'estaciones de prefectura',
      'estacion de prefectura',
      'estación de prefectura',
      'estaciones por zona',
      'frecuencia de radio',
      'frecuencia de prefectura',
      'frecuencia prefectura',
      'prefectura naval',
      'radio',
      'canales',
      'canal',
      'frecuencia',
      'frecuencias',
      'comunicar',
      'comunicacion',
      'comunicación',
    ],
    'emergencia': [
      'ayuda urgente',
      'socorro',
      'emergencia',
      'accidente',
      'me lastime',
      'me lastimé',
      'me corte',
      'me corté',
      'mordedura',
      'picadura de vibora',
      'estoy atrapado',
      'auxilio',
      'sangre',
      'herida',
      'me clavo un anzuelo',
      'me clavé un anzuelo',
      'serpiente',
      'vibora',
      'víbora',
      'emergencya',
      'emergecia',
      'soccorro',
      'me lastimo',
    ],
    'perdido': [
      'me perdi',
      'me perdí',
      'estoy perdido',
      'no encuentro salida',
      'no encuentro el camino',
      'estoy solo en la isla',
      'aislado',
      'no puedo salir',
      'atrapado en la isla',
      'no se donde estoy',
      'no sé dónde estoy',
    ],
    'agua': [
      'agua',
      'tengo sed',
      'como conseguir agua',
      'agua potable',
      'no tengo agua',
      'buscar agua',
      'deshidratado',
    ],
    'refugio': [
      'refugio',
      'donde dormir',
      'dónde dormir',
      'hacer refugio',
      'pasar la noche',
      'quedarme aca',
      'quedarme acá',
      'dormir en la isla',
      'armar refugio',
    ],
    'fuego': [
      'fuego',
      'hacer fuego',
      'encender fuego',
      'fogata',
      'como prender',
      'cómo prender',
      'necesito calor',
      'como hacer fuego',
      'cómo hacer fuego',
      'prender fuego',
    ],
    'alimento': [
      'hambre',
      'comida',
      'como conseguir comida',
      'buscar alimento',
      'que comer',
      'qué comer',
      'no tengo comida',
      'plantas comestibles',
    ],
    'clima': [
      'lluvia',
      'tormenta',
      'viento fuerte',
      'mucho frio',
      'mucho frío',
      'clima peligroso',
      'sudestada',
      'zonda',
      'temporal',
      'niebla',
      'como esta el clima',
      'cómo está el clima',
      'va a llover',
      'hay tormenta',
      'temperatura',
      'pronostico',
      'pronóstico',
    ],
    'gps': [
      'gps',
      'mapa',
      'ubicacion',
      'ubicación',
      'donde estoy',
      'dónde estoy',
      'mi posicion',
      'mi posición',
      'coordenadas',
      'como llegar',
      'mostrar mapa',
      'abrir gps',
      'llevame al',
      'orientarme',
      'gepeese',
      'jps',
      'mapaa',
      'ubikacion',
      'hubicacion',
      'el mapa',
      'ver mapa',
      'abrir el mapa',
      'carta nautica',
      'puntos de pesca',
    ],
    'primeros_auxilios': [
      'me corte',
      'me corté',
      'me clavo',
      'me clavé',
      'dolor',
      'herida',
      'sangre',
      'quemadura',
      'picadura de insecto',
      'torcedura',
      'golpe',
      'me desmaye',
      'me desmaié',
      'me lastime',
      'me lastimé',
    ],
    'peces': [
      'dorado',
      'surubi',
      'surubí',
      'boga',
      'bagre',
      'pati',
      'patí',
      'tararira',
      'carpa',
      'pejerrey',
      'sabalo',
      'sábalo',
      'pacu',
      'pacú',
      'armado',
      'peces del parana',
      'peces del paraná',
      'especies',
      'bagre de mar',
      'mimoso',
      'moncholo',
      'monchuelo',
      'genidens barbus',
      'que pez',
      'qué pez',
      'cual pez',
      'cuál pez',
      'informacion del pez',
      'como pesco',
      'dorao',
      'doradoo',
      'suvuri',
      'suburi',
      'pejerey',
      'pegerrey',
      'tararirra',
      'que peces hay',
      'que se pesca aca',
    ],
    'carnadas': [
      'carnada',
      'cebo',
      'que carnada',
      'qué carnada',
      'mejor carnada',
      'que pongo de carnada',
      'qué pongo de carnada',
      'lombriz',
      'masa',
      'morena',
      'senuelo',
      'señuelo',
      'para boga',
      'para surubi',
      'para dorado',
      'para bagre',
      'para pejerrey',
      'carnaa',
      'karnada',
      'cevo',
      'lombris',
      'lomvriz',
      'senuelos',
      'mosca artificial',
      'con que pesco',
      'que le pongo',
      'que uso de carnada',
    ],
    'nudos': [
      'nudo',
      'nudos',
      'como atar',
      'cómo atar',
      'atar anzuelo',
      'atar linea',
      'atar línea',
      'palomar',
      'clinch',
      'albright',
      'nudo fuerte',
      'como uno',
      'cómo uno',
      'como ato',
      'cómo ato',
      'como hago un nudo',
      'cómo hago un nudo',
    ],
    'boyas': [
      'boya',
      'boyas',
      'flotador',
      'que boya',
      'qué boya',
      'boya para',
      'chupetona',
      'yo-yo',
      'palito',
      'boya luminosa',
      'corcho',
      'boya para pejerrey',
    ],
    'plomadas': [
      'plomada',
      'plomo',
      'que plomada',
      'qué plomada',
      'peso de plomada',
      'plomada para rio',
      'plomada para río',
      'satelite',
      'satélite',
      'pera',
      'torpedo',
      'plomada pasante',
      'cuanto plomo',
    ],
    'canas_y_reeles': [
      'cana',
      'caña',
      'reel',
      'reeles',
      'equipo de pesca',
      'que cana',
      'qué caña',
      'reel frontal',
      'reel rotativo',
      'equipo recomendado',
      'que equipo',
      'con que pesco',
      'canas',
      'cania',
      'carrete',
      'carretel',
      'que caña uso',
      'que reel compro',
      'equipo para pescar',
      'armado de pesca',
    ],
    'rio': [
      'crecida',
      'bajada del rio',
      'bajada del río',
      'agua turbia',
      'agua clara',
      'corriente',
      'nivel del rio',
      'nivel del río',
      'rio crecido',
      'río crecido',
      'comportamiento del rio',
      'el rio esta',
      'el río está',
      'rio bajo',
      'río bajo',
      'barroso',
      'como viene el rio',
      'cómo viene el río',
      'como esta el rio',
      'como esta el parana',
      'como esta el agua',
      'estado del rio',
      'estado del parana',
      'el rio hoy',
      'el parana hoy',
      'como viene el parana',
      'creciente',
    ],
    'tienda': [
      'tienda',
      'comprar',
      'productos',
      'catalogo',
      'catálogo',
      'stock',
      'oferta',
      'que venden',
      'qué venden',
      'la tienda',
      'productos de pesca',
      'equipamiento',
      'accesorios',
      'donde compro',
      'quiero comprar',
      'que tienen',
      'qué tienen',
    ],
    // ── Intenciones de viaje (motor_viajes) ─────────────────────────────────
    'crear_viaje': [
      'quiero pescar',
      'quiero un capitan',
      'buscar capitan',
      'como contrato',
      'como hago para pescar',
      'quiero salir a pescar',
      'busco guia',
      'contratar guia',
      'pedir capitan',
      'nuevo pedido',
      'crear viaje',
      'crear pedido',
      'hacer reserva',
      'como arranco',
      'por donde empiezo',
      'primer paso',
      'quiero una salida',
      'quero pescar',
      'kiero pescar',
      'quiero ir a pescar',
      'busco un capitan',
      'necesito un guia',
      'necesito guia de pesca',
      'quiero reservar una salida',
      'como pido un capitan',
      'quiero contratar',
      'quiero salir',
      'reservar salida',
      'como hago el pedido',
      'salida de pesca',
      'planificar salida',
      'quiero ir al rio',
    ],
    'ver_cotizaciones': [
      'ver cotizaciones',
      'ver ofertas',
      'capitanes disponibles',
      'llegaron propuestas',
      'me mandaron algo',
      'cuantos capitanes',
      'comparar capitanes',
      'ver propuestas',
      'no me llego ninguna',
      'nadie me cotizo',
      'propuestas de capitanes',
      'cotisacion',
      'cotizasion',
      'contizacion',
      'cuanto me cobran',
      'que precios tienen',
      'llegaron precios',
    ],
    'elegir_capitan': [
      'como elijo',
      'que capitan conviene',
      'como comparo capitanes',
      'cual es el mejor',
      'cuál elijo',
      'que capitanes hay',
      'ver perfil del capitan',
      'el capitan tiene buenas notas',
      'tiene buenas calificaciones',
      'cuantas anclas tiene el capitan',
      'resenas del capitan',
      'opinion del capitan',
      'que otros dicen',
      'el mejor capitan',
      'capitan recomendado',
      'como veo el perfil',
    ],
    'estado_viaje': [
      'estado del viaje',
      'en que esta mi viaje',
      'como va mi viaje',
      'mi viaje esta',
      'que significa pendiente',
      'que significa pagado',
      'que significa en curso',
      'que significa listo para confirmar',
      'que significa cerrado',
      'cuando zarpo',
      'cuando arranca',
      'cuando empieza',
      'no entiendo el estado',
      'en que etsado esta',
      'el estado',
      'ya arranco',
      'ya empezo',
      'que paso con mi viaje',
      'cuando salimos',
      'cuando zarpa el capitan',
    ],
    'pagar_viaje': [
      'como pago',
      'pagar el viaje',
      'mercado pago',
      'el pago',
      'donde pago',
      'pago fallido',
      'no me salio el pago',
      'me dio error el pago',
      'no se proceso',
      'no pude pagar',
      'metodo de pago',
      'pago con tarjeta',
      'mercadopago',
      'mercado-pago',
      'como pagar',
      'quiero pagar',
      'el pago no me salio',
      'pago no funciona',
      'no me deja pagar',
      'pago rechazado',
      'no me acepta el pago',
    ],
    'confirmar_viaje': [
      'confirmar arribo',
      'confirmar llegada',
      'termino el viaje',
      'llegamos',
      'volvimos',
      'el capitan termino',
      'arribo',
      'listo para confirmar',
      'ya volvimos',
      'ya terminamos',
      'el capitan finalizo',
      'como confirmo',
      'como confirmo el arribo',
      'volvimos del rio',
      'el viaje termino',
      'ya regresamos',
      'llegamos al puerto',
      'tengo que confirmar',
    ],
    'calificar': [
      'calificar',
      'calificacion',
      'anclas',
      'puntaje',
      'como califico',
      'dar estrellas',
      'puntuar',
      'que son las anclas',
      'cuantas anclas',
      'dejar resena',
      'dejar comentario',
      'evaluar capitan',
      'valorar',
      'calificasion',
      'puntuacion',
      'dar nota',
      'poner estrellas',
      'como puntuo',
      'escribir comentario',
      'opinion sobre el capitan',
    ],
    'notificaciones': [
      'notificaciones',
      'campanita',
      'avisos',
      'alertas',
      'no veo las notificaciones',
      'donde estan las notificaciones',
      'como activo notificaciones',
      'me llegan avisos',
      'notificasiones',
      'la campanita',
      'el aviso',
      'me llego un aviso',
      'veo un numero rojo',
      'hay un numerito',
      'la campana',
      'no me llegan avisos',
      'activar las notis',
      'notis',
    ],
    'perfil_pescador': [
      'mi perfil',
      'mis datos',
      'editar perfil',
      'cambiar telefono',
      'cambiar domicilio',
      'mi foto',
      'cambiar contrasena',
      'mi cuenta',
      'datos personales',
      'informacion personal',
      'cuenta de pescador',
      'cambiar mis datos',
      'actualizar datos',
      'cambiar contraseña',
      'cambiar email',
      'cambiar correo',
      'mi informacion',
      'editar mis datos',
      'poner mi foto',
      'cambiar foto',
      'donde cambio el telefono',
    ],
    'activar_guia': [
      'activar asistente',
      'activar robot',
      'donde activo el robot',
      'donde activo el guia',
      'el robot no aparece',
      'como uso el robot',
      'activar guia',
      'asistente flotante',
      'donde esta el robot',
      'switch del asistente',
      'el robot',
      'donde esta el guia',
      'no veo el robot',
      'como te activo',
      'como te uso',
      'como hablo con vos',
      'el asistente',
      'la ia',
      'el bot',
      'como desactivo el robot',
      'apagar el robot',
      'desactivar guia',
    ],
    // ── Carrito de la tienda ───────────────────────────────────────
    'carrito': [
      'mi carrito',
      'el carrito',
      'que agregue',
      'lo que tengo en el carrito',
      'como compro',
      'finalizar compra',
      'ir al carrito',
      'pagar los productos',
      'ver mi carrito',
      'vaciar carrito',
      'mis productos',
      'lo que elegi',
      'como pago los productos',
      'terminar la compra',
      'checkout',
      'donde esta el carrito',
      'el carro',
      'agregue algo al carrito',
    ],
    // ── Historial de viajes ───────────────────────────────────────
    'historial_viajes': [
      'historial',
      'viajes viejos',
      'mis viajes anteriores',
      'viajes pasados',
      'viajes que hice',
      'como veo mis viajes',
      'ver mis viajes',
      'mis viajes antiguos',
      'que viajes hice',
      'registro de viajes',
      'viajes realizados',
      'cuantos viajes hice',
      'ver historial',
      'mis salidas anteriores',
      'viaje pasado',
      'el viaje que hice',
    ],
    // ── Qué puede hacer el bot ─────────────────────────────────────
    'que_puede_hacer_bot': [
      'que haces',
      'qué hacés',
      'como me ayudas',
      'cómo me ayudás',
      'que sabes hacer',
      'qué sabés hacer',
      'para que servis',
      'que podes hacer',
      'qué podés hacer',
      'que funciones tenes',
      'que puedo preguntarte',
      'que me podes decir',
      'que sos',
      'que hace el guia',
      'para que sirve el guia',
      'que puedo pedirte',
      'ayudame',
      'en que me ayudas',
      'cuales son tus funciones',
      'que temas sabes',
    ],
    // ── Ayuda general ────────────────────────────────────────────
    'ayuda_general': [
      'ayuda',
      'no entiendo',
      'estoy perdido',
      'no se que hacer',
      'como funciona todo',
      'explicame',
      'me explicas',
      'necesito ayuda',
      'no entiendo nada',
      'estoy confundido',
      'no tengo idea',
      'me podes ayudar',
      'podrias ayudarme',
      'que hago',
    ],
    // ── Reserva genérica (fallback de viajes) ───────────────────────────────
    'reserva': [
      'mi reserva',
      'tengo reserva',
      'mis viajes',
      'mis salidas',
      'cuando viajo',
      'historial de viajes',
      'viajes pasados',
    ],
    'hora': [
      'que hora es',
      'qué hora es',
      'hora',
      'decime la hora',
      'que hora tengo',
      'qué hora tengo',
      'me decis la hora',
    ],
    'ayuda_app': [
      'como funciona',
      'cómo funciona',
      'no encuentro',
      'donde esta',
      'dónde está',
      'como hago',
      'cómo hago',
      'ayuda con la app',
      'para que sirve',
      'para qué sirve',
      'no se usar',
      'no sé usar',
      'como uso',
      'cómo uso',
      'no entiendo la app',
      'me explicas la app',
      'no puedo entrar',
      'como entro a',
      'cómo entro a',
      'abrir mapa',
      'no veo mi ubicacion',
      'como reservo',
      'cómo reservo',
      'como comprar',
      'cómo comprar',
      'mi cuenta',
      'cambiar contraseña',
      'cambiar foto',
      'como usar el gps',
      'cómo usar el gps',
      'boton sos',
      'botón sos',
      'activar notificaciones',
      'como ver carnadas en la app',
      'cómo ver carnadas en la app',
    ],
    'agradecimiento': [
      'gracias',
      'muchas gracias',
      'joya gracias',
      'genial gracias',
      'barbaro gracias',
      'bárbaro gracias',
      'te lo agradezco',
      'de nada',
      'gracias guia',
      'gracias guía',
      'grax',
      'gracia',
      'te re agradezco',
      'mil gracias',
      'sos un genio',
      'sos lo mas',
      'joya',
      'barbaro',
      'copado',
      'genial',
    ],
    'charla_cotidiana': [
      'no pica nada',
      'no pica',
      'nada de pique',
      'no hay pique',
      'tengo hambre',
      'me muero de hambre',
      'estoy cansado',
      'estoy agotado',
      'me canse',
      'que aburrido',
      'qué aburrido',
      'me aburro',
      'me quiero ir',
      'quiero irme',
      'que dia mas largo',
      'no pega nada',
      'dia sin pique',
      'mucho calor hoy',
      'tarda en picar',
      'mucho viento',
      'se pico el viento',
      'se picó el viento',
      'marejada',
      'marejada fuerte',
      'mucho calor',
      'pesado el aire',
      'sol de frente',
      'planchado',
      'agua planchada',
      'rio planchado',
      'río planchado',
      'espejo',
      'agua turbia',
      'muy turbia',
      'color chocolate',
      'invierno',
      'mucho frio',
      'mucho frío',
      'helada',
      'escarcha',
      'primavera',
      'solcito',
      'agua templada',
      'verano',
      'calor intenso',
      'otono',
      'otoño',
      'barometro',
      'barómetro',
      'tormenta electrica',
      'tormenta eléctrica',
    ],
    'mate': [
      'tomas mate',
      'tomás mate',
      'podes tomar mate',
      'podés tomar mate',
      'hacete un mate',
      'hacete unos mates',
      'preparate un mate',
      'podes preparar mate',
      'podés preparar mate',
      'un mate',
      'tomate un mate',
      'te gustan los mates',
      'te gusta el mate',
      'sabes cebar mate',
      'sabés cebar mate',
      'cebas mate',
      'cebás mate',
      'queres mate',
      'querés mate',
      'tenes mate',
      'tenés mate',
    ],
    'chiste': [
      'chiste',
      'cuentame algo',
      'contame algo',
      'haceme reir',
      'haceme reír',
      'algo gracioso',
      'contame un chiste',
    ],
    'saludo': [
      'hola',
      'buenas',
      'buen dia',
      'buen día',
      'buenas tardes',
      'buenas noches',
      'que tal',
      'qué tal',
      'como va',
      'cómo va',
      'hay alguien',
      'como estas',
      'cómo estás',
      'como andas',
      'cómo andas',
      'quien sos',
      'quién sos',
    ],
    'despedida': [
      'chau',
      'adios',
      'adiós',
      'hasta luego',
      'nos vemos',
      'me voy',
      'hasta mañana',
      'gracias chau',
      'me retiro',
    ],
    'preguntas_humanas': [
      // Identidad
      'como te llamas', 'como te llaman', 'cual es tu nombre', 'tenes nombre',
      'quien sos', 'que sos', 'como te dicen',
      // Edad
      'cuantos anos tenes', 'que edad tenes', 'sos grande', 'sos viejo',
      // Humano o robot
      'sos humano', 'sos una persona', 'sos un robot', 'sos real',
      'hablo con una persona', 'sos de verdad', 'sos ia',
      // Creador
      'quien te creo', 'quien te hizo', 'quien te programo',
      // Risa
      'podes reirte', 'te reis', 'sabes reirte', 'tenes sentido del humor',
      // Sentimientos
      'te enojas', 'te pones triste', 'tenes sentimientos', 'sientes algo',
      // Familia / vida
      'tenes novia',
      'estas casado',
      'tenes hijos',
      'donde vivis',
      'tenes familia',
      // Existencial
      'que piensas', 'tenes conciencia', 'sabes todo',
      // Absurdo
      'boca o river', 'sabes cocinar', 'cantame algo', 'bailas',
      'me haces millonario', 'adivina mi futuro',
      // Inteligencia / capacidades
      'sos inteligente', 'sabes mucho', 'que podes hacer', 'para que servis',
      'que sabes hacer',
      // Afecto
      'sos mi amigo', 'me acompanas', 'te quiero', 'te extrane', 'me caes bien',
      // Disponibilidad
      'estas ahi', 'estas disponible', 'hay alguien', 'me escuchas',
    ],
  };

  Future<void> inicializar() async {
    if (_inicializado) return;

    try {
      final personalidadStr = await rootBundle.loadString(
        'assets/elguia/personalidad.json',
      );
      _personalidad = json.decode(personalidadStr) as Map<String, dynamic>;

      const archivos = [
        'activar_guia', 'agradecimiento', 'agua', 'alimento',
        'ayuda_general', 'bagre_de_mar', 'boyas', 'calificar',
        'canales_vhf_frecuencias', 'canas_y_reeles', 'carnadas', 'carrito',
        'charla_cotidiana', 'chistes', 'clima', 'como_hago_deriva_correcta_mosca',
        'como_hago_evitar_corte_parana', 'como_hago_evitar_enredo_boyas', 'como_hago_flotar_nylon_pejerrey', 'como_hago_leer_agua_indicador',
        'como_hago_no_quemar_tanza_mar', 'como_hago_nudo_rotor_mar', 'como_hago_profundidad_dorado_parana', 'como_hago_ver_boya_lejos',
        'como_pescar_bagre_de_mar_rio', 'como_se_hace_boya_elevadora_mar', 'como_se_hace_chupin_pescado', 'como_se_hace_comunicacion_mar_del_plata_maritimo',
        'como_se_hace_comunicacion_ushuaia_maritimo', 'como_se_hace_eleccion_cebo_pejerrey', 'como_se_hace_empanadas_pescado', 'como_se_hace_fritanga',
        'como_se_hace_fritanga_disco', 'como_se_hace_indicador_pique_mosca', 'como_se_hace_limpieza_salitre_mar', 'como_se_hace_linea_dorado_parana',
        'como_se_hace_linea_tres_boyas', 'como_se_hace_lubricacion_interna_wd40', 'como_se_hace_mantenimiento_anzuelo', 'como_se_hace_mantenimiento_profundo_anual',
        'como_se_hace_masa', 'como_se_hace_masa_empanadas', 'como_se_hace_nudo_union_tiburon', 'como_se_hace_pesca_kayak_mar',
        'como_se_hace_reel_jigging_vertical', 'como_se_prepara_brazolada_cometa', 'como_se_prepara_brazolada_pescadilla', 'como_se_prepara_carnada_corvina',
        'como_se_prepara_conserva_pescado', 'como_se_prepara_cuartos_luna_pesca', 'como_se_prepara_distancia_anzuelos_mar', 'como_se_prepara_empanada',
        'como_se_prepara_empanadas_boga', 'como_se_prepara_equipo_liviano_flote', 'como_se_prepara_freno_centrifugo_galleta', 'como_se_prepara_freno_estrella_rotativo',
        'como_se_prepara_freno_lanzamiento_senuelo', 'como_se_prepara_freno_magnetico_lance', 'como_se_prepara_guardado_reel_freno', 'como_se_prepara_lanzamiento_curvo',
        'como_se_prepara_linea_anclado', 'como_se_prepara_linea_garete', 'como_se_prepara_linea_trucha_mosca', 'como_se_prepara_linea_variada_costa',
        'como_se_prepara_linea_vuelo_pejerrey', 'como_se_prepara_luna_llena_pique', 'como_se_prepara_luna_surubi_parana', 'como_se_prepara_madre_dorado',
        'como_se_prepara_madre_pescadilla', 'como_se_prepara_profundidad_ninfa', 'como_se_prepara_reel_pejerrey', 'como_se_prepara_union_multi_boya',
        'como_se_prepara_viuda', 'como_se_prepara_viuda_pescado', 'como_sirve_accion_rapida', 'como_sirve_color_pejerrey',
        'como_sirve_material_fibra_vidrio', 'como_sirve_material_grafito', 'confirmar_viaje', 'crear_viaje',
        'cuando_hago_clavada_rapida_mosca', 'cuando_hago_uso_anteojos_polarizados', 'cuando_se_usa_frecuencia_posadas_formosa', 'cuando_sirve_boya_chica_pejerrey',
        'cuando_sirve_boya_clara_pejerrey', 'cuando_sirve_boya_elevadora_pique', 'cuando_sirve_boya_luminosa_nocturna', 'cuando_sirve_boya_oscura_pejerrey',
        'cuando_sirve_con_muerte_pejerrey', 'cuando_sirve_indicador_deriva_muerta', 'cuando_sirve_linea_flote_boga', 'cuando_sirve_marea_corvina_mar',
        'cuando_sirve_multifilamento_pejerrey', 'cuando_sirve_nylon_blando_duro', 'cuando_sirve_nylon_madre_pejerrey', 'cuando_sirve_pata_corta_pejerrey',
        'cuando_sirve_pata_larga_pejerrey', 'cuando_sirve_periodo_mayor_pesca', 'cuando_sirve_periodo_menor_pesca', 'cuando_sirve_presion_alta_pique',
        'cuando_sirve_presion_baja_pique', 'cuando_sirve_serenos_solunar_actividad', 'cuando_sirve_sin_muerte_pejerrey', 'despedidas',
        'donde_se_hace_compra_anzuelo', 'donde_se_hace_temporada_dorado_rio', 'donde_se_hace_temporada_pejerrey_laguna', 'donde_se_hace_temporada_tararira_verano',
        'donde_sirve_boya_elevadora', 'donde_sirve_boya_mandale', 'donde_sirve_boya_parana_remanso', 'donde_sirve_boya_ping_pong',
        'donde_sirve_frecuencia_corrientes', 'donde_sirve_frecuencia_mar_del_plata_portuario', 'donde_sirve_frecuencia_parana_diamante', 'donde_sirve_frecuencia_rio_de_la_plata_sector2',
        'donde_sirve_frecuencia_rosario', 'donde_sirve_frecuencia_san_isidro', 'donde_sirve_frecuencia_san_pedro_nicolas', 'donde_sirve_frecuencia_ushuaia_portuario',
        'donde_sirve_indicador_pique_arroyos', 'donde_sirve_paternoster_pejerrey', 'donde_sirve_reel_embarcado_mar_variada', 'donde_sirve_reel_rio_costa_variada',
        'donde_sirve_reel_surfcasting_mar', 'elegir_capitan', 'emergencia', 'frases_ambiente',
        'fuego', 'gps', 'historial_viajes', 'hora',
        'humor_contextual', 'mate', 'notificaciones', 'nudos',
        'orientacion', 'pagar_viaje', 'peces', 'perfil_pescador',
        'plomadas', 'prefectura_naval_argentina', 'preguntas_humanas', 'primeros_auxilios',
        'que_puede_hacer_bot', 'que_se_hace_luna_nueva_pique', 'que_se_hace_mareas_muertas_mar', 'que_se_hace_mareas_vivas_mar',
        'que_sirve_anzuelo_boga', 'que_sirve_anzuelo_corvina', 'que_sirve_anzuelo_dorado', 'que_sirve_anzuelo_numero_cuatro_mar',
        'que_sirve_anzuelo_pejerrey', 'que_sirve_anzuelo_tiburon', 'que_sirve_anzuelo_trucha', 'que_sirve_boya_chupetona',
        'que_sirve_boya_cometa', 'que_sirve_boya_doble_palito', 'que_sirve_boya_esferica', 'que_sirve_boya_fucsia_pejerrey',
        'que_sirve_boya_lagrima', 'que_sirve_boya_madera_balsa', 'que_sirve_boya_palito', 'que_sirve_boya_plastico',
        'que_sirve_boya_tergopol_dorado', 'que_sirve_boya_yoyo_pejerrey', 'que_sirve_cana_boga_spinning', 'que_sirve_cana_dorado_baitcasting',
        'que_sirve_cana_dorado_flycast', 'que_sirve_cana_mar_surfcasting', 'que_sirve_cana_pejerrey_flote', 'que_sirve_cana_surubi_trolling',
        'que_sirve_cana_tiburon_embarcado', 'que_sirve_cana_trucha_mosca', 'que_sirve_canal_emergencia', 'que_sirve_diferencia_frontal_rotativo',
        'que_sirve_frecuencia_buenos_aires_mitre', 'que_sirve_frecuencia_rio_de_la_plata_sector1', 'que_sirve_frecuencia_rio_de_la_plata_sector4', 'que_sirve_freno_dc_shimano',
        'que_sirve_guarnicion', 'que_sirve_indicador_pasta_patagonia', 'que_sirve_material_corvina', 'que_sirve_material_pejerrey',
        'que_sirve_multifilamento_baitcast_litoral', 'que_sirve_multifilamento_mar_distancia', 'que_sirve_nudo_corredizo_dorado', 'que_sirve_nudo_ocho_boyas',
        'que_sirve_nylon_tiburon_mar', 'que_sirve_plomito_antes_lider', 'que_sirve_puntero_impulsor', 'que_sirve_reel_baitcast_huevito',
        'que_sirve_reel_flycast_trucha', 'que_sirve_reel_fuerza_rio_rotativo', 'que_sirve_reel_pejerrey_frontal', 'que_sirve_reel_spinning_frontal',
        'que_sirve_reel_trolling_surubi', 'que_sirve_rotor_mar', 'que_sirve_separacion_boyas_pejerrey', 'que_sirve_simple_triple_pejerrey',
        'que_sirve_tamano_corvina', 'que_sirve_tamano_pejerrey', 'que_sirve_volumen_boya_puntero', 'refugio',
        'reserva', 'rio', 'saludos', 'seguridad_pesca_bagre_de_mar',
        'supervivencia', 'tienda', 'ver_cotizaciones',
        // Lenguaje cotidiano (sincronizables)
        'charla_cotidiana', 'emociones_pescador', 'celebraciones', 
        'chistes', 'reacciones_clima', 'acompanamiento'
      ];

      String? baseDirPath;
      try {
        final dir = await getApplicationDocumentsDirectory().timeout(
          const Duration(seconds: 3),
        );
        baseDirPath = dir.path;
      } catch (e) {
        // ignore: avoid_print
        print('[ElGuiaEngine] ⚠️ Timeout o error obteniendo getApplicationDocumentsDirectory, usando assets: $e');
      }

      // Carga en paralelo — todos los JSONs al mismo tiempo (buscando overrides primero)
      final resultados = await Future.wait(
        archivos.map((nombre) async {
          try {
            String contenido = '';
            bool cargadoDeOverride = false;

            if (baseDirPath != null) {
              final overrideFile = File('$baseDirPath/elguia/librerias/$nombre.json');
              try {
                final exists = await overrideFile.exists().timeout(const Duration(milliseconds: 500));
                if (exists) {
                  contenido = await overrideFile.readAsString().timeout(const Duration(seconds: 1));
                  cargadoDeOverride = true;
                }
              } catch (_) {
                // Timeout o error de archivo individual -> cae en fallback de asset
              }
            }

            if (!cargadoDeOverride) {
              contenido = await rootBundle.loadString(
                'assets/elguia/librerias/$nombre.json',
              );
            }

            return MapEntry(
              nombre,
              json.decode(contenido) as Map<String, dynamic>,
            );
          } catch (_) {
            return null; // Librería no disponible — no bloquear
          }
        }),
      );

      for (final entry in resultados) {
        if (entry != null) _librerias[entry.key] = entry.value;
      }

      // Cargar intenciones dinámicas de las librerías cargadas (incluyendo sincronizadas)
      _librerias.forEach((libName, libData) {
        if (libData.containsKey('intenciones')) {
          final intencionesList = libData['intenciones'];
          if (intencionesList is List) {
            for (final item in intencionesList) {
              if (item is Map<String, dynamic>) {
                final String intentName = item['intencion']?.toString() ?? '';
                final List<String> acts = List<String>.from((item['activadores'] as List? ?? []).map((e) => e.toString().toLowerCase().trim()));
                if (intentName.isNotEmpty && acts.isNotEmpty) {
                  _activadores[intentName] = acts;
                }
              }
            }
          }
        }
      });

      // _appEngine y _humor también en paralelo
      await Future.wait([_appEngine.inicializar(), _humor.inicializar()]);

      _inicializado = true;
      debugPrint('✅ [EL-GUIA] v2.0 inicializado. Librerías: ${_librerias.length}');
      // Cargar aprendizajes del local updater
      await GuiaLocalUpdater.cargar();
    } catch (e) {
      debugPrint('⚠️ [EL-GUIA] Error al inicializar: $e');
    }
  }

  // ── RESPUESTA PRINCIPAL ────────────────────────────────────────────────────
  Future<ElGuiaRespuesta> responder(String entrada) async {
    if (!_inicializado) await inicializar();

    _contexto.registrarActividad();
    final texto = _limpiarYNormalizarEntrada(entrada);

    // Búsqueda directa inteligente en librerías locales basada en frases de acción ("cómo se prepara", "qué hago", etc.)
    final respuestaBusquedaDinamica = await _buscarEnLibreriasDinamico(texto);
    if (respuestaBusquedaDinamica != null) {
      _actualizarContexto('informacion', texto);
      return respuestaBusquedaDinamica;
    }

    final intenciones = detectarIntenciones(texto);
    final intencionPrincipal = _obtenerMayorPrioridad(intenciones);

    // Registrar actividad en logger
    GuiaLogger.registrar(
      texto: entrada,
      intencion: intencionPrincipal,
      esFallback: intencionPrincipal == 'fallback',
    );

    // Manejar frustración
    if (intencionPrincipal == 'fallback') {
      if (_contexto.ultimaIntencion == 'fallback') {
        _contexto.nivelFrustracion = (_contexto.nivelFrustracion + 1).clamp(
          0,
          5,
        );
      }
    } else {
      if (texto.contains('no anda') ||
          texto.contains('anda mal') ||
          texto.contains('no funciona') ||
          texto.contains('no sirve') ||
          texto.contains('me anda mal')) {
        _contexto.nivelFrustracion = (_contexto.nivelFrustracion + 1).clamp(
          0,
          5,
        );
      }
    }

    ElGuiaRespuesta respuesta;

    // Si la frustración es alta, responder de forma asistida
    if (_contexto.nivelFrustracion >= 2) {
      respuesta = ElGuiaRespuesta(
        texto:
            'Pará, chamigo, vamos con calma que el río está picado. Veo que andás con problemas con la app. ¿Querés que te guíe paso a paso? Decime "sí" o "ayuda" y lo hacemos juntos.',
        gifSugerido: 'duda',
      );
    } else {
      respuesta = await _generarRespuesta(
        intencionPrincipal,
        texto,
        intenciones,
      );
    }

    _actualizarContexto(intencionPrincipal, texto);

    // Intentar humor contextual (10% probabilidad, solo en modo normal y sin frustración)
    if (_contexto.nivelFrustracion == 0 &&
        !respuesta.esHumorContextual &&
        intencionPrincipal != 'chiste') {
      final conHumor = _humor.intentarHumorContextual(
        respuesta.texto,
        intencionPrincipal,
        _contexto,
      );
      if (conHumor != null) return conHumor;
    }

    return respuesta;
  }

  // ── DETECCIÓN DE INTENCIONES ──────────────────────────────────────────────
  List<String> detectarIntenciones(String textoNormalizado) {
    final intenciones = <String>[];

    // Primero revisar activadores estáticos en _activadores
    for (final entry in _activadores.entries) {
      for (final activador in entry.value) {
        if (textoNormalizado.contains(activador)) {
          if (!intenciones.contains(entry.key)) {
            intenciones.add(entry.key);
          }
          break;
        }
      }
    }

    // Integrar GuiaLocalUpdater: buscar coincidencias en intenciones aprendidas consolidadas
    final intencionAprendida = GuiaLocalUpdater.detectarIntencion(
      textoNormalizado,
    );
    if (intencionAprendida != null &&
        !intenciones.contains(intencionAprendida)) {
      intenciones.add(intencionAprendida);
    }

    return intenciones;
  }

  // ── EVALUAR CONFIANZA (CONFIDENCE ROUTER) ──────────────────────────────────
  double evaluarConfianza(
    String texto,
    String intencionPrincipal,
    ElGuiaContext contexto,
  ) {
    if (intencionPrincipal == 'fallback') return 0.0;

    final palabrasConsulta = texto
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 2)
        .toList();
    if (palabrasConsulta.isEmpty) return 0.0;

    // Obtener activadores de la intención
    final activadores = <String>[];
    if (_activadores.containsKey(intencionPrincipal)) {
      activadores.addAll(_activadores[intencionPrincipal]!);
    }
    final learnedActivadores =
        GuiaLocalUpdater.obtenerActivadoresParaMotor()[intencionPrincipal];
    if (learnedActivadores != null) {
      activadores.addAll(learnedActivadores);
    }

    // 1. Base por palabras clave (40%)
    int palabrasCoincidentes = 0;
    final palabrasActivadores = activadores
        .expand((act) => act.split(RegExp(r'\s+')))
        .map((w) => _normalizar(w))
        .where((w) => w.length > 2)
        .toSet();

    for (final pal in palabrasConsulta) {
      if (palabrasActivadores.contains(pal)) {
        palabrasCoincidentes++;
      }
    }
    final ratioPalabras = palabrasCoincidentes / palabrasConsulta.length;
    final scorePalabras = ratioPalabras * 0.40;

    // 2. Similitud de activadores (30%)
    double scoreActivador = 0.0;
    for (final act in activadores) {
      final actNorm = _normalizar(act);
      if (texto == actNorm) {
        scoreActivador = 0.30;
        break;
      } else if (texto.contains(actNorm)) {
        scoreActivador = 0.15;
      }
    }

    // 3. Contexto de pantalla (20% boost, max 0.20)
    double scorePantalla = 0.0;
    if (contexto.pantallaActual.isNotEmpty &&
        contexto.pantallaActual ==
            _obtenerPantallaAsociada(intencionPrincipal)) {
      scorePantalla = 0.20;
    }

    // 4. Intención previa (10% boost, max 0.10)
    double scorePrevio = 0.0;
    if (contexto.ultimaIntencion == intencionPrincipal) {
      scorePrevio = 0.10;
    }

    return (scorePalabras + scoreActivador + scorePantalla + scorePrevio).clamp(
      0.0,
      1.0,
    );
  }

  String _obtenerPantallaAsociada(String intent) {
    switch (intent) {
      case 'crear_viaje':
      case 'ver_cotizaciones':
      case 'estado_viaje':
      case 'pagar_viaje':
      case 'confirmar_viaje':
      case 'calificar':
      case 'reserva':
      case 'elegir_capitan':
      case 'historial_viajes':
        return 'mis_viajes';
      case 'tienda':
      case 'carrito':
        return 'tienda';
      case 'gps':
        return 'gps';
      case 'perfil_pescador':
      case 'activar_guia':
        return 'perfil';
      case 'notificaciones':
        return 'notificaciones';
      default:
        return '';
    }
  }

  // ── PRIORIDAD ─────────────────────────────────────────────────────────────
  String _obtenerMayorPrioridad(List<String> intenciones) {
    if (intenciones.isEmpty) return 'fallback';

    int mejorNivel = 999;
    String mejorIntencion = 'fallback';

    for (final intencion in intenciones) {
      bool found = false;
      for (final entry in _prioridades.entries) {
        if (entry.value == intencion) {
          found = true;
          if (entry.key < mejorNivel) {
            mejorNivel = entry.key;
            mejorIntencion = intencion;
          }
        }
      }
      if (!found && mejorIntencion == 'fallback') {
        mejorIntencion = intencion;
      }
    }

    return mejorIntencion;
  }

  // ── GENERACIÓN DE RESPUESTA ──────────────────────────────────────────────────────
  Future<ElGuiaRespuesta> _generarRespuesta(
    String intencion,
    String texto,
    List<String> todasIntenciones,
  ) async {
    final respuestaAprendida = GuiaLocalUpdater.obtenerRespuesta(intencion);
    if (respuestaAprendida != null) {
      return ElGuiaRespuesta(
        texto: respuestaAprendida,
        gifSugerido: GuiaLocalUpdater.obtenerGif(intencion),
      );
    }

    // Buscar en intenciones dinámicas sincronizadas en las librerías
    for (final lib in _librerias.values) {
      if (lib.containsKey('intenciones')) {
        final intencionesList = lib['intenciones'];
        if (intencionesList is List) {
          for (final item in intencionesList) {
            if (item is Map<String, dynamic> && item['intencion'] == intencion) {
              final respuestas = List<String>.from(item['respuestas'] ?? [item['respuesta_limpia']]);
              final gif = item['gif']?.toString() ?? 'hablaConMate';
              final String respuestaTexto = respuestas[_random.nextInt(respuestas.length)];
              return ElGuiaRespuesta(
                texto: respuestaTexto,
                gifSugerido: gif,
              );
            }
          }
        }
      }
    }

    final gif = _humor.gifParaIntencion(intencion);

    switch (intencion) {
      case 'saludo':
        return ElGuiaRespuesta(
          texto: _responderSaludo(),
          gifSugerido: 'saludo',
        );
      case 'despedida':
        return ElGuiaRespuesta(
          texto: _responderDespedida(),
          gifSugerido: 'saludo',
        );
      case 'agradecimiento':
        return ElGuiaRespuesta(
          texto: _responderAgradecimiento(),
          gifSugerido: 'exito',
        );
      case 'hora':
        return ElGuiaRespuesta(
          texto: _responderHora(),
          gifSugerido: 'piensaLeve',
        );
      case 'ayuda_app':
        return await _responderAyudaApp(texto);
      case 'charla_cotidiana':
        return ElGuiaRespuesta(
          texto: _responderCharlaCotidiana(texto),
          gifSugerido: 'hablaConMate',
        );
      case 'preguntas_humanas':
        return ElGuiaRespuesta(
          texto: _responderPreguntasHumanas(texto),
          gifSugerido: 'hablaConMate',
        );
      case 'mate':
        return ElGuiaRespuesta(
          texto: _responderMate(),
          gifSugerido: _random.nextBool() ? 'tomaMate' : 'hablaConMate',
        );
      case 'chiste':
        return _humor.responderChiste();
      case 'prefectura_naval_argentina':
        return ElGuiaRespuesta(
          texto: _responderPrefectura(texto),
          gifSugerido: 'explica',
        );
      case 'emergencia':
        return ElGuiaRespuesta(
          texto: _responderEmergencia(texto),
          gifSugerido: 'duda',
        );
      case 'perdido':
        _contexto.modoActual = 'supervivencia';
        return ElGuiaRespuesta(
          texto: _responderSupervivencia(),
          gifSugerido: 'duda',
        );
      case 'agua':
        return ElGuiaRespuesta(texto: _responderAgua(), gifSugerido: gif);
      case 'refugio':
        return ElGuiaRespuesta(texto: _responderRefugio(), gifSugerido: gif);
      case 'fuego':
        return ElGuiaRespuesta(texto: _responderFuego(), gifSugerido: gif);
      case 'alimento':
        return ElGuiaRespuesta(texto: _responderAlimento(), gifSugerido: gif);
      case 'clima':
        return ElGuiaRespuesta(
          texto: _responderClima(texto),
          gifSugerido: 'piensaProfundo',
        );
      case 'gps':
        final lib = _librerias['gps'];
        final ruta = lib != null ? lib['ruta_navegacion'] as String? : null;
        return ElGuiaRespuesta(
          texto: _responderGps(texto),
          gifSugerido: 'piensaLeve',
          rutaNavegacion: ruta,
        );
      case 'primeros_auxilios':
        return ElGuiaRespuesta(
          texto: _responderPrimerosAuxilios(texto),
          gifSugerido: 'duda',
        );
      case 'peces':
        return ElGuiaRespuesta(
          texto: _responderPeces(texto),
          gifSugerido: 'explica',
        );
      case 'carnadas':
        return ElGuiaRespuesta(
          texto: _responderCarnadas(texto, todasIntenciones),
          gifSugerido: 'explica',
        );
      case 'nudos':
        return ElGuiaRespuesta(
          texto: _responderNudos(texto),
          gifSugerido: 'explica',
        );
      case 'boyas':
        return ElGuiaRespuesta(
          texto: _responderBoyas(texto),
          gifSugerido: 'explica',
        );
      case 'plomadas':
        return ElGuiaRespuesta(
          texto: _responderPlomadas(texto),
          gifSugerido: 'explica',
        );
      case 'canas_y_reeles':
        return ElGuiaRespuesta(
          texto: _responderCanasReeles(texto),
          gifSugerido: 'explica',
        );
      case 'rio':
        return ElGuiaRespuesta(
          texto: _responderRio(texto),
          gifSugerido: 'piensaProfundo',
        );
      case 'tienda':
        final lib = _librerias['tienda'];
        final ruta = lib != null ? lib['ruta_navegacion'] as String? : null;
        return ElGuiaRespuesta(
          texto: _responderTienda(texto),
          gifSugerido: 'exito',
          rutaNavegacion: ruta,
        );
      // ── Intenciones del ciclo de viaje (motor_viajes) ──────────────────────
      case 'crear_viaje':
        return ElGuiaRespuesta(
          texto: _responderCrearViaje(),
          gifSugerido: 'exito',
          rutaNavegacion: '/mapa',
        );
      case 'ver_cotizaciones':
        return ElGuiaRespuesta(
          texto: _responderVerCotizaciones(texto),
          gifSugerido: 'explica',
        );
      case 'estado_viaje':
        return ElGuiaRespuesta(
          texto: _responderEstadoViaje(texto),
          gifSugerido: 'piensaLeve',
        );
      case 'pagar_viaje':
        return ElGuiaRespuesta(
          texto: _responderPagarViaje(texto),
          gifSugerido: 'explica',
        );
      case 'confirmar_viaje':
        return ElGuiaRespuesta(
          texto: _responderConfirmarArribo(),
          gifSugerido: 'exito',
        );
      case 'calificar':
        return ElGuiaRespuesta(
          texto: _responderCalificar(texto),
          gifSugerido: 'exito',
        );
      case 'notificaciones':
        return ElGuiaRespuesta(
          texto: _responderNotificaciones(),
          gifSugerido: 'piensaLeve',
          rutaNavegacion: '/notificaciones',
        );
      case 'perfil_pescador':
        final lib = _librerias['perfil_pescador'];
        final ruta = lib != null ? lib['ruta_navegacion'] as String? : null;
        return ElGuiaRespuesta(
          texto: _responderPerfilPescador(texto),
          gifSugerido: 'explica',
          rutaNavegacion: ruta ?? '/perfil',
        );
      case 'activar_guia':
        return ElGuiaRespuesta(
          texto: _responderActivarGuia(),
          gifSugerido: 'saludo',
          rutaNavegacion: '/perfil',
        );
      case 'reserva':
        return ElGuiaRespuesta(
          texto: _responderReserva(),
          gifSugerido: 'piensaLeve',
        );
      // ── Nuevas intenciones v3.1 ─────────────────────────────────────────────
      case 'elegir_capitan':
        return ElGuiaRespuesta(
          texto: _responderElegirCapitan(),
          gifSugerido: 'explica',
        );
      case 'carrito':
        return ElGuiaRespuesta(
          texto: _responderCarrito(),
          gifSugerido: 'exito',
          rutaNavegacion: '/carrito',
        );
      case 'historial_viajes':
        return ElGuiaRespuesta(
          texto: _responderHistorialViajes(),
          gifSugerido: 'piensaLeve',
          rutaNavegacion: '/inicio',
        );
      case 'que_puede_hacer_bot':
        return ElGuiaRespuesta(
          texto: _responderQuePuedeHacer(),
          gifSugerido: 'saludo',
        );
      case 'ayuda_general':
        return ElGuiaRespuesta(
          texto: _responderAyudaGeneral(),
          gifSugerido: 'explica',
        );
      default:
        return ElGuiaRespuesta(texto: _fallback(), gifSugerido: 'duda');
    }
  }

  // ── HANDLERS ─────────────────────────────────────────────────────────────

  String _responderSaludo() {
    final lib = _librerias['saludos'];
    if (lib == null) return 'Hola, pescador. ¿En qué te puedo ayudar?';

    // 30% de probabilidad de usar variante por momento del día
    final h = DateTime.now().hour;
    String clave;
    if (h >= 5 && h < 12)
      clave = 'respuestas_manana';
    else if (h >= 12 && h < 20)
      clave = 'respuestas_tarde';
    else
      clave = 'respuestas_noche';

    final listaMomento = lib[clave] as List<dynamic>?;
    if (listaMomento != null &&
        listaMomento.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      return listaMomento[_random.nextInt(listaMomento.length)] as String;
    }

    final respuestas = List<String>.from(lib['respuestas'] as List);
    return respuestas[_random.nextInt(respuestas.length)];
  }

  String _responderDespedida() {
    final lib = _librerias['despedidas'];
    if (lib == null) return 'Nos vemos, pescador.';

    final h = DateTime.now().hour;
    String clave;
    if (h >= 5 && h < 12)
      clave = 'respuestas_manana';
    else if (h >= 12 && h < 20)
      clave = 'respuestas_tarde';
    else
      clave = 'respuestas_noche';

    final listaMomento = lib[clave] as List<dynamic>?;
    if (listaMomento != null &&
        listaMomento.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      return listaMomento[_random.nextInt(listaMomento.length)] as String;
    }

    final respuestas = List<String>.from(lib['respuestas'] as List);
    return respuestas[_random.nextInt(respuestas.length)];
  }

  String _responderAgradecimiento() {
    final lib = _librerias['agradecimiento'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Dale. Cualquier cosa avisame.';
  }

  String _responderHora() {
    final ahora = DateTime.now();
    final hora = ahora.hour.toString().padLeft(2, '0');
    final minutos = ahora.minute.toString().padLeft(2, '0');
    final horaStr = '$hora:$minutos';

    final lib = _librerias['hora'];
    if (lib == null) return 'Son las $horaStr.';

    // Determinar momento del día y devolver frase contextual con tip de pesca
    final contextoMomentos =
        lib['contexto_por_momento'] as Map<String, dynamic>?;
    if (contextoMomentos != null) {
      final h = ahora.hour;
      final String momento;
      if (h < 6)
        momento = 'madrugada';
      else if (h < 8)
        momento = 'amanecer';
      else if (h < 12)
        momento = 'manana';
      else if (h < 15)
        momento = 'mediodia';
      else if (h < 18)
        momento = 'tarde';
      else if (h < 20)
        momento = 'atardecer';
      else
        momento = 'noche';

      final lista = contextoMomentos[momento] as List<dynamic>?;
      if (lista != null && lista.isNotEmpty) {
        final resp = lista[_random.nextInt(lista.length)] as String;
        return resp.replaceAll('[HORA]', horaStr);
      }
    }

    // Fallback al formato anterior
    final puente = List<String>.from(lib['respuestas_puente'] as List);
    final frasePuente = puente[_random.nextInt(puente.length)];
    final respFinal = (lib['respuesta_final'] as String).replaceAll(
      '[HORA]',
      horaStr,
    );
    return '$frasePuente $respFinal';
  }

  String _responderCharlaCotidiana(String texto) {
    final lib = _librerias['charla_cotidiana'];
    if (lib == null) return 'Y bueno, hay días así también.';

    final porSituacion = lib['por_situacion'] as Map<String, dynamic>;

    String respBase;
    // ── Clima y Estaciones (Fase 2) ──────────────────────────
    if (texto.contains('viento') ||
        texto.contains('ventoso') ||
        texto.contains('marejada')) {
      final lista = porSituacion['viento'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('planchado') ||
        texto.contains('espejo') ||
        texto.contains('mansito') ||
        texto.contains('sin viento')) {
      final lista = porSituacion['planchado'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('lluvia') ||
        texto.contains('llueve') ||
        texto.contains('llover') ||
        texto.contains('lloviendo') ||
        texto.contains('se larg')) {
      final lista = porSituacion['lluvia'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('invierno') ||
        texto.contains('frio') ||
        texto.contains('frío') ||
        texto.contains('helada') ||
        texto.contains('escarcha')) {
      final lista = porSituacion['frio_invierno'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('primavera') ||
        texto.contains('solcito') ||
        texto.contains('templada')) {
      final lista = porSituacion['sol_primavera'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('verano') || texto.contains('calor intenso')) {
      final lista = porSituacion['calor_verano'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('calor') ||
        texto.contains('pesado') ||
        texto.contains('sol de frente') ||
        texto.contains('caluroso') ||
        texto.contains('temperatura')) {
      final lista = porSituacion['calor'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('otono') ||
        texto.contains('otoño') ||
        texto.contains('barometro') ||
        texto.contains('barómetro') ||
        texto.contains('tormenta electrica') ||
        texto.contains('tormenta eléctrica')) {
      final lista = porSituacion['tormenta_otono'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    } else if (texto.contains('turbia') ||
        texto.contains('turbio') ||
        texto.contains('chocolate') ||
        texto.contains('barroso')) {
      final lista = porSituacion['turbia'] as List<dynamic>?;
      respBase = (lista != null && lista.isNotEmpty)
          ? lista[_random.nextInt(lista.length)] as String
          : '';
    }
    // ── Situaciones originales ────────────────────────────────
    else if (texto.contains('no pica') || texto.contains('pique')) {
      final lista = List<String>.from(porSituacion['no_pica'] as List);
      respBase = lista[_random.nextInt(lista.length)];
    } else if (texto.contains('hambre')) {
      final lista = List<String>.from(porSituacion['hambre'] as List);
      respBase = lista[_random.nextInt(lista.length)];
    } else if (texto.contains('cansado') ||
        texto.contains('agotado') ||
        texto.contains('canse')) {
      final lista = List<String>.from(porSituacion['cansado'] as List);
      respBase = lista[_random.nextInt(lista.length)];
    } else if (texto.contains('aburrido') || texto.contains('aburro')) {
      final lista = List<String>.from(porSituacion['aburrido'] as List);
      respBase = lista[_random.nextInt(lista.length)];
    } else {
      respBase =
          'Y bueno, hay días así también. A veces hay que tener un poco de paciencia.';
    }

    if (respBase.isEmpty) {
      respBase =
          'Y bueno, hay días así también. A veces hay que tener un poco de paciencia.';
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderEmergencia(String texto) {
    _contexto.modoActual = 'emergencia';
    final lib = _librerias['emergencia'];
    if (lib == null) {
      return 'Prefectura Naval Argentina: canal VHF 16. Emergencia: 106. Con señal, llamá al 911.';
    }

    String respBase = '';
    bool subintencionEncontrada = false;
    final subintenciones = lib['subintenciones'] as Map<String, dynamic>? ?? {};
    for (final entry in subintenciones.entries) {
      final sub = entry.value as Map<String, dynamic>;
      final activadores = List<String>.from(sub['activadores'] as List);
      for (final act in activadores) {
        if (texto.contains(act)) {
          final respuestas = List<String>.from(sub['respuestas'] as List);
          respBase = respuestas[_random.nextInt(respuestas.length)];
          subintencionEncontrada = true;
          break;
        }
      }
      if (subintencionEncontrada) break;
    }

    if (!subintencionEncontrada) {
      final puente = List<String>.from(lib['respuestas_puente'] as List);
      respBase = puente[_random.nextInt(puente.length)];
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  // Tabla estática de localidades a kilómetros para la Prefectura Naval Argentina
  static const Map<String, List<List<int>>> _localidadesKm = {
    'zarate': [[56, 240], [0, 121]],
    'zárate': [[56, 240], [0, 121]],
    'san pedro': [[240, 310]],
    'san nicolas': [[310, 376]],
    'san nicolás': [[310, 376]],
    'rosario': [[376, 480]],
    'diamante': [[480, 568]],
    'parana': [[568, 677]],
    'paraná': [[568, 677]],
    'la paz': [[677, 827]],
    'goya': [[827, 1135]],
    'corrientes': [[1135, 1242]],
    'itati': [[1242, 1330]],
    'itatí': [[1242, 1330]],
    'ita ibate': [[1330, 1410]],
    'itá ibaté': [[1330, 1410]],
    'ituzaingo': [[1410, 1522]],
    'ituzaingó': [[1410, 1522]],
    'posadas': [[1522, 1710]],
    'lib. gral. san martin': [[1710, 1774]],
    'lib. gral. san martín': [[1710, 1774]],
    'eldorado': [[1774, 1842]],
    'iguazu': [[1842, 1927]],
    'iguazú': [[1842, 1927]],
    'bermejo': [[1240, 1360]],
    'formosa': [[1360, 1520]],
    'pilcomayo': [[1520, 1619]],
  };

  bool _estaEnZonaKm(String localidad, int km) {
    final cleanLocalidad = localidad.toLowerCase();
    final rangos = _localidadesKm[cleanLocalidad];
    if (rangos != null) {
      for (final rango in rangos) {
        if (km >= rango[0] && km <= rango[1]) {
          return true;
        }
      }
    }
    return false;
  }

  String _responderPrefectura(String texto) {
    final lib = _librerias['prefectura_naval_argentina'];
    if (lib == null || lib['prefectura_naval_argentina'] == null) {
      return 'La Prefectura Naval Argentina (PNA) es la autoridad marítima y fluvial. En caso de emergencia, podés llamar por radio en el canal 16 VHF (canal internacional de socorro) o por teléfono al 0800-999-7622.';
    }

    final pna = lib['prefectura_naval_argentina'] as Map<String, dynamic>;
    final estaciones = pna['estaciones'] as List<dynamic>? ?? [];

    // 1. Buscar si se menciona un kilómetro en la consulta
    final kmRegex = RegExp(r'(?:km|kilometro|kilómetro|k\.m\.|k\s+m)\s*(\d+)');
    final kmMatch = kmRegex.firstMatch(texto);
    if (kmMatch != null) {
      final kmVal = int.tryParse(kmMatch.group(1) ?? '');
      if (kmVal != null) {
        final coincidentes = <Map<String, dynamic>>[];
        for (final est in estaciones) {
          final estMap = est as Map<String, dynamic>;
          final localidad = estMap['localidad'] as String? ?? '';
          if (_estaEnZonaKm(localidad, kmVal)) {
            coincidentes.add(estMap);
          }
        }

        if (coincidentes.isNotEmpty) {
          if (coincidentes.length == 1) {
            final est = coincidentes.first;
            final canalesStr = (est['canales'] as List<dynamic>? ?? []).join(', ');
            return 'Esa zona del río (km $kmVal) la cubre Prefectura ${est['localidad']}, indicativo ${est['indicativo']}, en los canales $canalesStr VHF. Si no lográs comunicación en el canal local, recordá que el canal 16 VHF es el internacional de socorro y lo escuchan permanentemente, chamigo.';
          } else {
            final buffer = StringBuffer();
            buffer.write('Mire chamigo, para el km $kmVal tiene estas estaciones de Prefectura en zona:\n');
            for (final est in coincidentes) {
              final canalesStr = (est['canales'] as List<dynamic>? ?? []).join(', ');
              buffer.writeln('• Prefectura ${est['localidad']} (indicativo ${est['indicativo']}): canales $canalesStr VHF.');
            }
            buffer.write('Si no responde ninguna en su canal local, recuerde que el canal 16 VHF siempre está activo para emergencias.');
            return buffer.toString();
          }
        }
      }
    }

    // 2. Buscar si menciona una localidad específica de las estaciones
    final coincidentesPorNombre = <Map<String, dynamic>>[];
    for (final est in estaciones) {
      final estMap = est as Map<String, dynamic>;
      final localidad = (estMap['localidad'] as String? ?? '').toLowerCase();
      final localidadNormalizada = _normalizar(localidad);
      if (texto.contains(localidadNormalizada)) {
        coincidentesPorNombre.add(estMap);
      }
    }

    if (coincidentesPorNombre.isNotEmpty) {
      final buffer = StringBuffer();
      buffer.write('Para esa zona que me decís, chamigo, te paso los datos de Prefectura:\n');
      for (final est in coincidentesPorNombre) {
        final canalesStr = (est['canales'] as List<dynamic>? ?? []).join(', ');
        buffer.writeln('• Prefectura ${est['localidad']} (indicativo ${est['indicativo']}): canales $canalesStr VHF.');
      }
      buffer.write('No te olvides que el canal 16 VHF es de escucha obligatoria y permanente para emergencias en el agua.');
      return buffer.toString();
    }

    // A. Buscar coincidencia exacta en las preguntas de qa_canales del archivo canales_vhf_frecuencias
    final libCanales = _librerias['canales_vhf_frecuencias'];
    if (libCanales != null && libCanales['canales_vhf_frecuencias'] != null) {
      final vhf = libCanales['canales_vhf_frecuencias'] as Map<String, dynamic>;
      final qaCanales = vhf['qa_canales'] as List<dynamic>? ?? [];
      
      for (final qa in qaCanales) {
        final qaMap = qa as Map<String, dynamic>;
        final preguntaJson = (qaMap['pregunta'] as String? ?? '').toLowerCase();
        final preguntaNormalizada = _normalizar(preguntaJson);
        
        if (preguntaNormalizada.contains('canal llamo') && (RegExp(r'\bque canal\b').hasMatch(texto) || RegExp(r'\ben que canal\b').hasMatch(texto) || (RegExp(r'\bcanal\b').hasMatch(texto) && RegExp(r'\bllamo\b').hasMatch(texto) && !RegExp(r'\bcomo\b').hasMatch(texto)))) {
          return qaMap['respuesta'] as String;
        }
        if (preguntaNormalizada.contains('para que es el canal 16') && (texto.contains('para que') && (texto.contains('16') || texto.contains('dieciseis')))) {
          return qaMap['respuesta'] as String;
        }
        if (preguntaNormalizada.contains('que es el canal 70') && (texto.contains('canal 70') || texto.contains('que es el 70'))) {
          return qaMap['respuesta'] as String;
        }
        if (preguntaNormalizada.contains('puedo usar el canal 16 para hablar') && (texto.contains('hablar') && (texto.contains('16') || texto.contains('dieciseis')))) {
          return qaMap['respuesta'] as String;
        }
        if (preguntaNormalizada.contains('frecuencia del canal 16') && (texto.contains('frecuencia') && (texto.contains('16') || texto.contains('dieciseis')))) {
          return qaMap['respuesta'] as String;
        }
      }

      // B. Buscar si preguntan por un canal específico (ej: "canal 12", "canal 16", "canal 70")
      final canalRegex = RegExp(r'\b(12|16|70|9|14|72|71|6|8)\b');
      final canalMatch = canalRegex.firstMatch(texto);
      if (canalMatch != null && (texto.contains('canal') || texto.contains('frecuencia') || texto.contains('sirve') || texto.contains('uso'))) {
        final canalNumStr = canalMatch.group(1);
        final canalNum = int.tryParse(canalNumStr ?? '');

        final principales = vhf['canales_principales'] as List<dynamic>? ?? [];
        for (final c in principales) {
          final cMap = c as Map<String, dynamic>;
          if (cMap['canal'] == canalNum) {
            final freqNum = cMap['frecuencia_mhz'] as num;
            final freq = freqNum.toStringAsFixed(3);
            final uso = cMap['uso'];
            final regla = cMap['regla_oro'] != null ? '\nRegla de oro: ${cMap['regla_oro']}' : '';
            return 'El canal $canalNum trabaja en la frecuencia de $freq MHz. Uso: $uso$regla';
          }
        }

        final secundarios = vhf['canales_secundarios'] as List<dynamic>? ?? [];
        for (final c in secundarios) {
          final cMap = c as Map<String, dynamic>;
          if (cMap['canal'] == canalNum || (canalNumStr != null && cMap['canal'].toString().contains(canalNumStr))) {
            final freqVal = cMap['frecuencia_mhz'];
            final freq = freqVal != null ? ' (${(freqVal as num).toStringAsFixed(3)} MHz)' : '';
            final uso = cMap['uso'];
            return 'El canal ${cMap['canal']}$freq se usa para: $uso';
          }
        }
      }
    }

    // 3. Buscar si pregunta cómo llamar o procedimiento de radio
    if (texto.contains('como llamar') ||
        texto.contains('como llamo') ||
        texto.contains('como se llama') ||
        texto.contains('como hablo') ||
        texto.contains('como hablar') ||
        texto.contains('como se usa') ||
        texto.contains('como uso') ||
        texto.contains('como se utiliza') ||
        texto.contains('como utilizar') ||
        texto.contains('como comunicarse') ||
        texto.contains('comunicarme') ||
        texto.contains('procedimiento') ||
        texto.contains('pasos') ||
        texto.contains('protocolo')) {
      final pasos = pna['como_llamar_por_radio'] as List<dynamic>?;
      if (pasos != null && pasos.isNotEmpty) {
        final buffer = StringBuffer();
        buffer.writeln('¡Atento chamigo! Para llamar a Prefectura por radio tenés que seguir estos pasos:');
        for (int i = 0; i < pasos.length; i++) {
          buffer.writeln('${i + 1}. ${pasos[i]}');
        }
        return buffer.toString();
      }
    }

    // 4. Buscar si pregunta sobre recomendaciones de equipo o uso de canales
    if (texto.contains('recomendacion') ||
        texto.contains('consejo') ||
        texto.contains('equipo') ||
        texto.contains('llevar') ||
        texto.contains('que radio') ||
        texto.contains('que llevar') ||
        texto.contains('bateria') ||
        texto.contains('pilas') ||
        texto.contains('uso de canales') ||
        texto.contains('canales de uso') ||
        texto.contains('canal para hablar') ||
        texto.contains('entre barcos') ||
        texto.contains('canales') ||
        texto.contains('frecuencia') ||
        texto.contains('radio')) {
      final recs = pna['recomendaciones_equipo_radio'] as List<dynamic>?;
      final usoCanales = pna['uso_de_canales'] as Map<String, dynamic>?;
      final buffer = StringBuffer();

      if (usoCanales != null) {
        buffer.writeln('El uso correcto de los canales de radio VHF según la reglamentación, chamigo, es:');
        final entreBarcos = (usoCanales['entre_barcos'] as List<dynamic>? ?? []).join(', ');
        final prefCanales = (usoCanales['prefectura_naval'] as List<dynamic>? ?? []).join(', ');
        final clubes = usoCanales['clubes_y_guarderias'];
        
        buffer.writeln('• Entre barcos deportivos: canales $entreBarcos VHF.');
        buffer.writeln('• Prefectura Naval (operativos): canales $prefCanales VHF.');
        buffer.writeln('• Clubes y guarderías náuticas: canal $clubes VHF.');
        buffer.writeln('');
      }

      if (recs != null && recs.isNotEmpty) {
        buffer.writeln('Y tené en cuenta estas recomendaciones bien camperas para tu equipo:');
        for (final rec in recs) {
          buffer.writeln('• $rec');
        }
      }
      return buffer.toString();
    }

    // 5. Fallback general: descripción y emergencia nacional
    final desc = pna['descripcion'] as String? ?? '';
    final universal = pna['canal_universal_emergencia'] as Map<String, dynamic>?;
    final numNacional = pna['numero_emergencia_nacional'] as String? ?? '0800-999-7622';

    String resp = '$desc\n\n';
    if (universal != null) {
      resp += '• Canal universal de emergencia: canal ${universal['canal']} ${universal['banda']}. ${universal['uso']}\n';
    }
    resp += '• Teléfono de emergencia nacional: $numNacional\n\n';
    resp += 'Si querés saber qué canal de radio corresponde a tu zona de pesca, decime en qué kilómetro o localidad del río estás y te lo busco al toque, chamigo.';

    return resp;
  }

  String _responderSupervivencia() {
    final lib = _librerias['supervivencia'];
    if (lib == null)
      return 'Bueno, tranquilo. Vamos paso a paso. Primero agua, después refugio.';

    final puente = List<String>.from(lib['respuestas_puente'] as List);
    final intro = puente[_random.nextInt(puente.length)];
    final respBase = '$intro ${lib['consejo_general']}';

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderAgua() {
    final lib = _librerias['agua'];
    if (lib == null)
      return 'Herví el agua del río durante 5 minutos mínimo antes de tomar.';
    final fuentes = lib['fuentes'] as Map<String, dynamic>;
    return (fuentes['lluvia']?['consejo'] as String?) ??
        (fuentes['rio']?['consejo'] as String?) ??
        (lib['advertencia'] as String);
  }

  String _responderRefugio() {
    final lib = _librerias['refugio'];
    if (lib == null)
      return 'Buscá zona elevada, protegida del viento. Construí el refugio antes de que anochezca.';
    final tipos = lib['tipos'] as Map<String, dynamic>;
    return (tipos['delta'] as String?) ?? (tipos['natural'] as String);
  }

  String _responderFuego() {
    final lib = _librerias['fuego'];
    if (lib == null)
      return 'Usá ramas secas finas y empezá desde abajo. Tené listo el material antes de encender.';
    final metodos = lib['metodos'] as Map<String, dynamic>;
    final encendedor = List<String>.from(
      metodos['encendedor_o_fosforos'] as List? ?? [],
    );
    if (encendedor.isNotEmpty)
      return encendedor[_random.nextInt(encendedor.length)];
    return lib['consejo'] as String;
  }

  String _responderAlimento() {
    final lib = _librerias['alimento'];
    if (lib == null)
      return 'Si estás cerca del río, la pesca es la fuente más confiable de alimento.';
    final fuentes = lib['fuentes'] as Map<String, dynamic>;
    return (fuentes['pesca']?['consejo'] as String?) ??
        (lib['advertencia'] as String);
  }

  String _responderClima(String texto) {
    final lib = _librerias['clima'];
    if (lib == null)
      return 'Con tormenta eléctrica alejate del agua de inmediato.';
    final fenomenos = lib['fenomenos'] as Map<String, dynamic>;

    String respBase;
    if (texto.contains('sudestada')) {
      respBase = (fenomenos['sudestada']?['consejo'] as String?) ?? '';
    } else if (texto.contains('zonda')) {
      respBase = (fenomenos['zonda']?['consejo'] as String?) ?? '';
    } else if (texto.contains('tormenta') || texto.contains('rayo')) {
      respBase = (fenomenos['tormenta']?['consejo'] as String?) ?? '';
    } else if (texto.contains('niebla')) {
      respBase = (fenomenos['niebla']?['consejo'] as String?) ?? '';
    } else {
      respBase =
          (fenomenos['tormenta']?['consejo'] as String?) ??
          (fenomenos['sudestada']?['consejo'] as String?) ??
          '';
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderGps(String query) {
    final lib = _librerias['gps'];
    if (lib == null)
      return 'El GPS funciona sin internet. Abrí el mapa en la app.';

    final qLower = query.toLowerCase();
    if (qLower.contains('llevame') ||
        qLower.contains('llevá') ||
        qLower.contains('consigue') ||
        qLower.contains('abrir') ||
        qLower.contains('como llego') ||
        qLower.contains('cómo llego')) {
      return 'Si chamigo ahí te lo alcanso.';
    }

    // Si el contexto es "sin señal" o "perdido", usar tips de orientación real
    final modo = _contexto.modoActual;
    final orientacion = lib['orientacion_sin_senal'] as List<dynamic>?;
    String respBase;
    if (orientacion != null &&
        orientacion.isNotEmpty &&
        (modo == 'supervivencia' || modo == 'sin_senal')) {
      respBase = orientacion[_random.nextInt(orientacion.length)] as String;
    } else {
      final puente = List<String>.from(
        lib['respuestas_puente'] as List? ?? lib['consejos'] as List,
      );
      respBase = puente[_random.nextInt(puente.length)];
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderPrimerosAuxilios(String texto) {
    final lib = _librerias['primeros_auxilios'];
    if (lib == null)
      return 'Presioná la herida con tela limpia. Si no mejora, buscá atención médica.';
    final situaciones = lib['situaciones'] as Map<String, dynamic>;

    String respBase = '';
    bool sitEncontrada = false;
    for (final entry in situaciones.entries) {
      final sit = entry.value as Map<String, dynamic>;
      final activadores = List<String>.from(sit['activadores'] as List);
      for (final act in activadores) {
        if (texto.contains(act)) {
          final pasos = List<String>.from(sit['pasos'] as List);
          respBase = pasos.join(' ');
          sitEncontrada = true;
          break;
        }
      }
      if (sitEncontrada) break;
    }

    if (!sitEncontrada) {
      final corte = situaciones['corte'] as Map<String, dynamic>?;
      if (corte != null) {
        respBase = (List<String>.from(corte['pasos'] as List)).first;
      } else {
        respBase = 'Contame qué pasó exactamente para orientarte mejor.';
      }
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderPeces(String texto) {
    final lib = _librerias['peces'];
    if (lib == null)
      return 'En el Paraná encontrás dorado, surubí, boga, bagre, patí, tararira, pejerrey, sábalo y pacú.';
    final especies = lib['especies'] as Map<String, dynamic>;
    final puente = List<String>.from(lib['respuestas_puente'] as List);

    String respBase =
        'En el Paraná encontrás: dorado, surubí, boga, bagre, patí, tararira, pejerrey y sábalo. Cuál te interesa?';
    for (final entry in especies.entries) {
      if (texto.contains(entry.key)) {
        final especie = entry.value as Map<String, dynamic>;
        _contexto.especieActual = entry.key;
        final carnadas = List<String>.from(especie['carnada'] as List);
        final intro = puente[_random.nextInt(puente.length)];
        respBase =
            '$intro ${especie['descripcion']} Carnada: ${carnadas.take(2).join(' o ')}. ${especie['equipo']}';
        break;
      }
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderCarnadas(String texto, List<String> todasIntenciones) {
    final lib = _librerias['carnadas'];
    if (lib == null)
      return 'Para variada usá lombriz. Para boga y carpa, masa con vainilla. Para dorado, morena viva.';

    final puente = List<String>.from(lib['respuestas_puente'] as List);
    final porEspecie = lib['por_especie'] as Map<String, dynamic>;
    final porCondicion = lib['por_condicion'] as Map<String, dynamic>;

    final especieDetectada = _contexto.especieActual.isNotEmpty
        ? _contexto.especieActual
        : _detectarEspecie(texto);

    final estadoRio = _contexto.estadoRioActual.isNotEmpty
        ? _contexto.estadoRioActual
        : _detectarEstadoRio(texto);

    final buffer = StringBuffer();
    final intro = puente[_random.nextInt(puente.length)];
    buffer.write(intro);

    if (especieDetectada.isNotEmpty &&
        porEspecie.containsKey(especieDetectada)) {
      final carnadas = List<String>.from(porEspecie[especieDetectada] as List);
      buffer.write(' Para $especieDetectada: ${carnadas.take(2).join(' o ')}.');
    }

    if (estadoRio.isNotEmpty && porCondicion.containsKey(estadoRio)) {
      buffer.write(' ${porCondicion[estadoRio]}');
    }

    if (buffer.toString() == intro) {
      return lib['respuesta_sin_especie'] as String;
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '${buffer.toString()} $pregunta';
    }

    return buffer.toString();
  }

  String _responderNudos(String texto) {
    final lib = _librerias['nudos'];
    if (lib == null)
      return 'Para atar anzuelos usá el nudo Palomar. Para unir dos líneas, el Albright.';
    final puente = List<String>.from(lib['respuestas_puente'] as List);
    final nudos = lib['nudos'] as Map<String, dynamic>;
    final intro = puente[_random.nextInt(puente.length)];

    if (texto.contains('palomar') ||
        texto.contains('anzuelo') ||
        texto.contains('senuelo') ||
        texto.contains('señuelo')) {
      final nudo = nudos['palomar'] as Map<String, dynamic>;
      final pasos = List<String>.from(nudo['pasos'] as List);
      return '$intro Nudo Palomar, para ${nudo['uso']}: ${pasos.take(3).join(' ')}';
    }
    if (texto.contains('albright') ||
        texto.contains('unir') ||
        texto.contains('lider') ||
        texto.contains('líder')) {
      final nudo = nudos['albright'] as Map<String, dynamic>;
      final pasos = List<String>.from(nudo['pasos'] as List);
      return '$intro Nudo Albright, para ${nudo['uso']}: ${pasos.take(3).join(' ')}';
    }
    if (texto.contains('clinch') || texto.contains('delgada')) {
      final nudo = nudos['clinch_mejorado'] as Map<String, dynamic>;
      final pasos = List<String>.from(nudo['pasos'] as List);
      return '$intro Clinch Mejorado, para ${nudo['uso']}: ${pasos.take(3).join(' ')}';
    }

    // Fallback genérico con pregunta de seguimiento
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null && preguntas.isNotEmpty) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return pregunta;
    }
    return 'Para atar anzuelos usá el Palomar. Para unir líneas de distinto grosor, el Albright. Cuál querés?';
  }

  String _responderBoyas(String texto) {
    final lib = _librerias['boyas'];
    if (lib == null)
      return 'La chupetona es la más versátil. Para pesca nocturna, siempre boya luminosa.';
    final puente = List<String>.from(lib['respuestas_puente'] as List);
    final tipos = lib['tipos'] as Map<String, dynamic>;
    final porCondicion = lib['por_condicion'] as Map<String, dynamic>;

    if (texto.contains('noche') || texto.contains('nocturna'))
      return porCondicion['noche'] as String;
    if (texto.contains('corriente') || texto.contains('crecida'))
      return porCondicion['corriente'] as String;
    if (texto.contains('laguna') || texto.contains('tranquila'))
      return porCondicion['laguna'] as String;
    if (texto.contains('luminosa') || texto.contains('luz')) {
      return (tipos['luminosa'] as Map<String, dynamic>)['uso'] as String;
    }

    final intro = puente[_random.nextInt(puente.length)];
    final respBase =
        '$intro La chupetona sirve para la mayoría de las pescas. El palito es más sensible para peces pequeños. La luminosa es indispensable de noche.';

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }
    return respBase;
  }

  String _responderPlomadas(String texto) {
    final lib = _librerias['plomadas'];
    if (lib == null)
      return 'Para el Paraná usá plomada satélite de 60g a 120g. Para laguna, pasante liviana.';
    final puente = List<String>.from(lib['respuestas_puente'] as List);
    final tipos = lib['tipos'] as Map<String, dynamic>;
    final porCondicion = lib['por_condicion'] as Map<String, dynamic>;

    if (texto.contains('corriente') ||
        texto.contains('parana') ||
        texto.contains('paraná') ||
        texto.contains('fuerte')) {
      return porCondicion['corriente_fuerte'] as String;
    }
    if (texto.contains('laguna') || texto.contains('tranquila')) {
      return porCondicion['laguna'] as String;
    }
    if (texto.contains('satelite') || texto.contains('satélite')) {
      final t = tipos['satelite'] as Map<String, dynamic>;
      return '${t['descripcion']}: ${t['uso']}. Peso: ${t['peso_recomendado']}.';
    }

    final intro = puente[_random.nextInt(puente.length)];
    return '$intro Para el Paraná con corriente fuerte usá satélite de 60g a 120g. Para laguna, pasante de 10g a 30g.';
  }

  String _responderCanasReeles(String texto) {
    final lib = _librerias['canas_y_reeles'];
    if (lib == null)
      return 'Para dorado y patí usá caña media con reel frontal. Para surubí, caña pesada.';
    final canas = lib['canas'] as Map<String, dynamic>;
    final reeles = lib['reeles'] as Map<String, dynamic>;

    final especie = _contexto.especieActual;
    String respBase;
    if (especie == 'surubi' || especie == 'surubí' || especie == 'armado') {
      final c = canas['pesada'] as Map<String, dynamic>;
      final r = reeles['rotativo'] as Map<String, dynamic>;
      respBase =
          'Para $especie: ${c['caracteristicas']}. Reel: ${r['descripcion']}.';
    } else if (especie == 'dorado' ||
        especie == 'pati' ||
        especie == 'patí' ||
        especie == 'bagre') {
      final c = canas['media'] as Map<String, dynamic>;
      final r = reeles['frontal'] as Map<String, dynamic>;
      respBase =
          'Para $especie: ${c['caracteristicas']}. Reel: ${r['descripcion']}.';
    } else if (especie == 'pejerrey' || especie == 'boga') {
      final c = canas['liviana'] as Map<String, dynamic>;
      respBase = 'Para $especie: ${c['caracteristicas']}.';
    } else if (texto.contains('reel') || texto.contains('carrete')) {
      final frontal = reeles['frontal'] as Map<String, dynamic>;
      respBase =
          'El reel frontal es el más popular en el Paraná: ${frontal['uso']}.';
    } else {
      respBase =
          'Para pesca liviana (pejerrey, boga): caña liviana. Para dorado y patí: caña media. Para surubí: caña pesada.';
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderRio(String texto) {
    final lib = _librerias['rio'];
    if (lib == null)
      return 'Con río crecido usá carnadas con olor fuerte y buscá remansos.';
    final estados = lib['estados'] as Map<String, dynamic>;

    String respBase;
    if (texto.contains('crecido') ||
        texto.contains('crecida') ||
        texto.contains('crece')) {
      _contexto.estadoRioActual = 'rio_crecido';
      final e = estados['crecido'] as Map<String, dynamic>;
      respBase = '${e['efecto_pesca']} ${e['zona_pesca']}';
    } else if (texto.contains('bajo') ||
        texto.contains('bajante') ||
        texto.contains('bajando')) {
      _contexto.estadoRioActual = 'rio_bajo';
      final e = estados['bajo'] as Map<String, dynamic>;
      respBase = '${e['efecto_pesca']} ${e['zona_pesca']}';
    } else if (texto.contains('turbio') ||
        texto.contains('barroso') ||
        texto.contains('turbia')) {
      _contexto.estadoRioActual = 'agua_turbia';
      final e = estados['turbio'] as Map<String, dynamic>;
      respBase = e['efecto_pesca'] as String;
    } else if (texto.contains('claro') ||
        texto.contains('limpia') ||
        texto.contains('clara')) {
      _contexto.estadoRioActual = 'agua_clara';
      final e = estados['claro'] as Map<String, dynamic>;
      respBase = e['efecto_pesca'] as String;
    } else {
      respBase =
          lib['pregunta_estado'] as String? ??
          'Cómo está el río hoy? Crecido, bajo, turbio o claro? Eso me ayuda a darte el consejo correcto.';
    }

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  String _responderTienda(String query) {
    final lib = _librerias['tienda'];
    if (lib == null)
      return 'La tienda está disponible en la app cuando tengas conexión.';
    final qLower = query.toLowerCase();
    if (qLower.contains('llevame') ||
        qLower.contains('llevá') ||
        qLower.contains('abrir') ||
        qLower.contains('como llego') ||
        qLower.contains('cómo llego')) {
      return 'No hay problema chamigo yo te llevo.';
    }
    final puente = List<String>.from(lib['respuestas_puente'] as List);
    return puente[_random.nextInt(puente.length)];
  }

  // ── Ayuda de navegación de la app ───────────────────────────────────────────────
  Future<ElGuiaRespuesta> _responderAyudaApp(String texto) async {
    final textoNormalizado = _normalizar(texto);
    final String? modulo = _appEngine.detectarPantalla(textoNormalizado);

    String? ruta;
    String? frase;

    if (modulo != null) {
      switch (modulo) {
        case 'tienda_app':
          ruta = '/tienda';
          frase = 'Esperá que te llevo a la tienda, chamigo.';
          break;
        case 'carrito_app':
          ruta = '/carrito';
          frase = 'Te llevo al carrito a ver las compras, chamigo.';
          break;
        case 'pago_app':
          ruta = '/carrito';
          frase = 'Ahí te llevo a la pasarela a pagar, chamigo.';
          break;
        case 'inicio':
          ruta = '/inicio';
          frase = 'Volvemos al inicio, chamigo. A recalcular el rumbo.';
          break;
        case 'mapa_app':
          ruta = '/mapa';
          frase = 'Mirá el mapa, acá nos ubicamos al toque.';
          break;
        case 'notificaciones_app':
          ruta = '/notificaciones';
          frase = 'A ver qué avisos y alertas tenemos por acá, chamigo.';
          break;
        case 'perfil_app':
          ruta = '/perfil';
          frase = 'Vamos a ver tus datos y perfil, patrón.';
          break;
        case 'historial_app':
          ruta = '/historial';
          frase = 'Vamos a revisar los viajes anteriores, chamigo.';
          break;
        case 'favoritos_app':
          ruta = '/favoritos';
          frase = 'Acá tenés tus favoritos guardados, chamigo.';
          break;
        case 'blog_app':
          ruta = '/blog';
          frase = 'Vamos a leer un poco del blog y aprender, chamigo.';
          break;
        case 'solunar_app':
          ruta = '/solunar';
          frase = 'Acá tenés la tabla solunar para ver cómo está la luna, chamigo.';
          break;
        case 'clima_app':
          ruta = '/clima';
          frase = 'Mirá el pronóstico del tiempo y el viento, chamigo.';
          break;
      }
    }

    if (ruta != null && frase != null) {
      if (modulo != null) {
        _contexto.pantallaActual = modulo;
        _contexto.pasoActualEnGuia = 0;
      }
      return ElGuiaRespuesta(
        texto: frase,
        rutaNavegacion: ruta,
        gifSugerido: 'explica',
      );
    }

    final textoRespuesta = await _appEngine.responder(textoNormalizado, _contexto);
    return ElGuiaRespuesta(
      texto: textoRespuesta,
      gifSugerido: 'explica',
    );
  }

  // ── Preguntas humanas recurrentes ────────────────────────────────────────────
  String _responderPreguntasHumanas(String texto) {
    final lib = _librerias['preguntas_humanas'];
    if (lib == null)
      return 'Soy El Guía. Estoy para ayudarte con pesca y la app.';

    final categorias = lib['categorias'] as Map<String, dynamic>;

    // Buscar la categoría con el activador más largo que coincida
    String? mejorCategoria;
    int mejorLongitud = 0;

    for (final entry in categorias.entries) {
      final cat = entry.value as Map<String, dynamic>;
      final activadores = List<String>.from(cat['activadores'] as List);
      for (final act in activadores) {
        if (texto.contains(act) && act.length > mejorLongitud) {
          mejorLongitud = act.length;
          mejorCategoria = entry.key;
        }
      }
    }

    if (mejorCategoria != null) {
      final cat = categorias[mejorCategoria] as Map<String, dynamic>;

      String respBase;
      if (mejorCategoria == 'existencial_baqueano') {
        final situaciones = cat['situaciones'] as Map<String, dynamic>;

        String sitClave = 'feliz'; // fallback por defecto
        if (texto.contains('dia') ||
            texto.contains('hoy') ||
            texto.contains('hiciste') ||
            texto.contains('fue')) {
          sitClave = 'dia';
        } else if (texto.contains('encerrado') ||
            texto.contains('celular') ||
            texto.contains('telefono') ||
            texto.contains('teléfono') ||
            texto.contains('siente') ||
            texto.contains('adentro')) {
          sitClave = 'encerrado';
        } else if (texto.contains('contar') ||
            texto.contains('cuentes') ||
            texto.contains('algo') ||
            texto.contains('tienes') ||
            texto.contains('tenes')) {
          sitClave = 'contar';
        }

        final respuestas = List<String>.from(situaciones[sitClave] as List);
        respBase = respuestas[_random.nextInt(respuestas.length)];
      } else {
        final respuestas = List<String>.from(cat['respuestas'] as List);
        respBase = respuestas[_random.nextInt(respuestas.length)];
      }

      // Pregunta de seguimiento (30% de probabilidad)
      final preguntas = cat['preguntas_seguimiento'] as List<dynamic>?;
      if (preguntas != null &&
          preguntas.isNotEmpty &&
          _random.nextDouble() < 0.3) {
        final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
        return '$respBase $pregunta';
      }

      return respBase;
    }

    // Fallback genérico con personalidad
    return 'Soy El Guía. Estoy para ayudarte con pesca, el río y la app. ¿Qué necesitás?';
  }

  String _responderMate() {
    final lib = _librerias['mate'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return '¿Mate? Por supuesto. Sin mate no hay buena pesca, eso es sabido.';
  }

  String _responderReserva() {
    final lib = _librerias['reserva'];
    if (lib == null)
      return 'Para ver tu viaje, entrá a la pestaña Mis Viajes en la barra de abajo.';
    final puente = List<String>.from(lib['respuestas_puente'] as List);
    final respBase = puente[_random.nextInt(puente.length)];

    // Pregunta de seguimiento (30% de probabilidad)
    final preguntas = lib['preguntas_seguimiento'] as List<dynamic>?;
    if (preguntas != null &&
        preguntas.isNotEmpty &&
        _random.nextDouble() < 0.3) {
      final pregunta = preguntas[_random.nextInt(preguntas.length)] as String;
      return '$respBase $pregunta';
    }

    return respBase;
  }

  // ── HANDLERS DEL CICLO DE VIAJE (motor_viajes) ───────────────────────────

  String _responderCrearViaje() {
    _contexto.viajeContexto = 'creando';
    final lib = _librerias['crear_viaje'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Tocá "Mis Viajes" abajo y presioná "Crear Nuevo Pedido". Completás destino, fecha y pasajeros.';
  }

  String _responderVerCotizaciones(String texto) {
    _contexto.viajeContexto = 'cotizando';
    final lib = _librerias['ver_cotizaciones'];

    if (texto.contains('nadie') ||
        texto.contains('no me llego') ||
        texto.contains('sin cotizacion')) {
      return lib?['sin_cotizaciones'] as String? ??
          'Si no llegó ninguna cotización, esperá unas horas o probá con otra fecha o zona.';
    }
    if (texto.contains('comparar') || texto.contains('elegir')) {
      return lib?['comparar'] as String? ??
          'Tocá el viaje pendiente en "Mis Viajes" y compará las propuestas.';
    }
    if (texto.contains('capitan rechaz') || texto.contains('no me cotizo')) {
      return lib?['rechazo'] as String? ??
          'Un capitán puede no cotizar. Solo ves los que aceptaron. Es normal.';
    }

    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Abrí el viaje pendiente en "Mis Viajes" para ver las cotizaciones.';
  }

  String _responderEstadoViaje(String texto) {
    final lib = _librerias['reserva'];
    final estados = lib != null
        ? lib['estados'] as Map<String, dynamic>?
        : null;

    // Detectar estado específico en el texto
    final estadoMapa = {
      'pendiente': 'pendiente',
      'aceptado': 'aceptado',
      'pagado': 'pagado',
      'en curso': 'en_curso',
      'en_curso': 'en_curso',
      'listo para confirmar': 'listo_para_confirmar',
      'listo_para_confirmar': 'listo_para_confirmar',
      'cerrado': 'cerrado',
    };

    for (final entry in estadoMapa.entries) {
      if (texto.contains(entry.key) && estados != null) {
        final estadoData = estados[entry.value] as Map<String, dynamic>?;
        if (estadoData != null) {
          return '${estadoData['descripcion']}\n\n¿Qué sigue? ${estadoData['que_sigue']}';
        }
      }
    }

    // Respuesta general sobre estados
    return 'En "Mis Viajes" vas a ver el estado actual de cada viaje.\n\n'
        '📌 Pendiente → esperando cotizaciones de capitanes\n'
        '✅ Pagado → reserva confirmada, listo para zarpar\n'
        '⛵ En Curso → la salida ya arrancó\n'
        '🏁 Listo para Confirmar → el capitán finalizó, te toca confirmar\n'
        '🔒 Cerrado → viaje completado, ambos calificaron\n\n'
        '¿En qué estado está el tuyo?';
  }

  String _responderPagarViaje(String texto) {
    _contexto.viajeContexto = 'pagando';
    final lib = _librerias['pagar_viaje'];

    if (texto.contains('fallo') ||
        texto.contains('error') ||
        texto.contains('no se proceso') ||
        texto.contains('no pude')) {
      return lib?['pago_fallido'] as String? ??
          'Si el pago falló, revisá los datos de tu tarjeta o probá con otro método.';
    }
    if (texto.contains('pendiente')) {
      return lib?['pago_pendiente'] as String? ??
          'Si el pago quedó pendiente, esperá unos minutos y revisá el estado del viaje.';
    }

    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Aceptá la cotización y tocá "Pagar con Mercado Pago".';
  }

  String _responderConfirmarArribo() {
    _contexto.viajeContexto = 'confirmando';
    final lib = _librerias['confirmar_viaje'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Cuando el capitán finaliza, te llega un aviso. Abrí el viaje y tocá "Confirmar Arribo".';
  }

  String _responderCalificar(String texto) {
    _contexto.viajeContexto = 'calificando';
    final lib = _librerias['calificar'];

    if (texto.contains('ancla') ||
        texto.contains('que significa') ||
        texto.contains('cuantas')) {
      return lib?['anclas'] as String? ??
          'Usamos anclas del 1 al 5. 5 anclas es la mejor calificación.';
    }
    if (texto.contains('etiqueta') ||
        texto.contains('que etiquetas') ||
        texto.contains('que opciones')) {
      return lib?['etiquetas'] as String? ??
          'Las etiquetas son opcionales: Buena onda, Sabe dónde pescar, Puntual, etc.';
    }

    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Después de confirmar el arribo se abre la calificación. Ponés anclas del 1 al 5.';
  }

  String _responderNotificaciones() {
    final lib = _librerias['notificaciones'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Las notificaciones están en la campanita arriba a la derecha.';
  }

  String _responderPerfilPescador(String texto) {
    final lib = _librerias['perfil_pescador'];

    final qLower = texto.toLowerCase();
    if (qLower.contains('llevame') ||
        qLower.contains('llevá') ||
        qLower.contains('como llego') ||
        qLower.contains('cómo llego')) {
      return 'Yo te alcanso el lugar donde configurar tus datos.';
    }

    if (texto.contains('contrasena') ||
        texto.contains('password') ||
        texto.contains('clave')) {
      return lib?['contrasena'] as String? ??
          'Para cambiar la contraseña: Perfil → Seguridad → Cambiar Contraseña.';
    }
    if (texto.contains('foto') ||
        texto.contains('imagen') ||
        texto.contains('avatar')) {
      return lib?['foto'] as String? ??
          'Para cambiar tu foto: Perfil → tocá tu foto actual.';
    }

    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Tu perfil está en el ícono arriba a la izquierda.';
  }

  String _responderActivarGuia() {
    final lib = _librerias['activar_guia'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Para activarme: Perfil → Editar Perfil → switch "ACTIVA TU ASISTENTE" al final.';
  }

  String _fallback() {
    final fallbacks = _personalidad['fallback'] != null
        ? List<String>.from(_personalidad['fallback'] as List)
        : [
            'No terminé de entender. Me lo decís de otra forma?',
            'Perdón, no te seguí del todo. Podés explicarme un poco más?',
            'No me quedó claro. Probemos de nuevo.',
          ];
    return fallbacks[_random.nextInt(fallbacks.length)];
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  String _normalizar(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ñ', 'n')
        .trim();
  }

  String _limpiarYNormalizarEntrada(String entrada) {
    // 1. Normalización básica (minúsculas y acentos)
    String texto = _normalizar(entrada);

    // 2. Reemplazo de abreviaturas con límites de palabra (\b)
    texto = texto.replaceAll(RegExp(r'\bxq\b'), 'porque');
    texto = texto.replaceAll(RegExp(r'\bpq\b'), 'porque');
    texto = texto.replaceAll(RegExp(r'\bq\b'), 'que');
    texto = texto.replaceAll(RegExp(r'\bpra\b'), 'para');
    texto = texto.replaceAll(RegExp(r'\bpa\b'), 'para');

    // 3. Diccionario de Alias de dominio
    texto = texto.replaceAll(RegExp(r'\bpeje\b'), 'pejerrey');
    texto = texto.replaceAll(RegExp(r'\btaru\b'), 'tararira');
    texto = texto.replaceAll(RegExp(r'\bmoncho\b'), 'bagre');

    // 4. Eliminar ruido con límites de palabra (\b)
    final ruido = RegExp(r'\b(che|guia|hola|buenas|eh|porfa)\b');
    texto = texto.replaceAll(ruido, '');

    // 5. Limpiar espacios múltiples resultantes
    texto = texto.replaceAll(RegExp(r'\s+'), ' ').trim();

    return texto;
  }

  String _detectarEspecie(String texto) {
    const especies = [
      'dorado',
      'surubi',
      'boga',
      'bagre',
      'pati',
      'tararira',
      'carpa',
      'pejerrey',
      'sabalo',
      'pacu',
      'armado',
    ];
    for (final especie in especies) {
      if (texto.contains(especie)) return especie;
    }
    return '';
  }

  String _detectarEstadoRio(String texto) {
    if (texto.contains('crecido') || texto.contains('crecida'))
      return 'rio_crecido';
    if (texto.contains('bajo') || texto.contains('bajante')) return 'rio_bajo';
    if (texto.contains('turbio') || texto.contains('barroso'))
      return 'agua_turbia';
    if (texto.contains('claro') || texto.contains('limpia'))
      return 'agua_clara';
    return '';
  }

  void _actualizarContexto(String intencion, String texto) {
    _contexto.ultimaIntencion = intencion;

    final especie = _detectarEspecie(texto);
    if (especie.isNotEmpty) _contexto.especieActual = especie;

    final estadoRio = _detectarEstadoRio(texto);
    if (estadoRio.isNotEmpty) _contexto.estadoRioActual = estadoRio;

    // Actualizar estado del viaje en contexto
    final estadoViaje = _detectarEstadoViaje(texto);
    if (estadoViaje.isNotEmpty) _contexto.estadoViajeActual = estadoViaje;

    if (intencion == 'emergencia') _contexto.modoActual = 'emergencia';
    if (intencion == 'perdido' || intencion == 'supervivencia') {
      _contexto.modoActual = 'supervivencia';
    }
    if (intencion == 'saludo') _contexto.modoActual = 'normal';
  }

  String _detectarEstadoViaje(String texto) {
    if (texto.contains('pendiente')) return 'pendiente';
    if (texto.contains('aceptado')) return 'aceptado';
    if (texto.contains('pagado')) return 'pagado';
    if (texto.contains('en curso') || texto.contains('en_curso'))
      return 'en_curso';
    if (texto.contains('listo para confirmar') ||
        texto.contains('listo_para_confirmar'))
      return 'listo_para_confirmar';
    if (texto.contains('cerrado')) return 'cerrado';
    return '';
  }

  // ── HANDLERS v3.1 ────────────────────────────────────────────────────────

  String _responderElegirCapitan() {
    final lib = _librerias['elegir_capitan'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Abrí el viaje pendiente en "Mis Viajes" y compará las propuestas por precio y anclas.';
  }

  String _responderCarrito() {
    final lib = _librerias['carrito'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'El carrito está en la pestaña "Tienda", arriba a la derecha.';
  }

  String _responderHistorialViajes() {
    final lib = _librerias['historial_viajes'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Tus viajes anteriores están en la pestaña "Mis Viajes", abajo de los activos.';
  }

  String _responderQuePuedeHacer() {
    final lib = _librerias['que_puede_hacer_bot'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Puedo ayudarte con pesca, viajes, GPS, tienda, perfil y supervivencia. ¿Qué necesitás?';
  }

  String _responderAyudaGeneral() {
    final lib = _librerias['ayuda_general'];
    if (lib != null) {
      final respuestas = List<String>.from(lib['respuestas'] as List);
      return respuestas[_random.nextInt(respuestas.length)];
    }
    return 'Contame qué necesitás y lo vemos juntos. ¿Viaje, tienda, mapa o perfil?';
  }

  // ── Acceso público ────────────────────────────────────────────────────────
  /// [estadoGif] corresponde a los nombres del enum CapitanState en minúscula.
  String frasePorEstado(String estadoGif) {
    final lib = _librerias['frases_ambiente'];
    if (lib == null) return 'Acá estoy. Decime qué necesitás.';

    final estados = lib['estados'] as Map<String, dynamic>?;
    if (estados == null) return 'Acá estoy. Decime qué necesitás.';

    final lista = estados[estadoGif] as List<dynamic>?;
    if (lista == null || lista.isEmpty) {
      // Fallback al estado tomaMate si el solicitado no existe
      final mateLista = estados['tomaMate'] as List<dynamic>?;
      if (mateLista != null && mateLista.isNotEmpty) {
        return mateLista[_random.nextInt(mateLista.length)] as String;
      }
      return 'Acá estoy. Decime qué necesitás.';
    }

    return lista[_random.nextInt(lista.length)] as String;
  }

  Future<ElGuiaRespuesta?> _buscarEnLibreriasDinamico(String texto) async {
    final t = texto.trim().toLowerCase();

    // Limpiar signos de puntuación al principio
    final queryLimpia = t.replaceAll(RegExp(r'^[¿¡\s\-\.\,\:\?]+'), '');

    // 1. Primer Filtro: El Espectro (Scoring de Intención Dominante)
    final scores = <String, int>{
      'diagnostico': 0,
      'comparacion': 0,
      'conveniencia': 0,
      'cantidad': 0,
      'como': 0,
      'donde': 0,
      'cuando': 0,
      'que': 0,
    };

    if (queryLimpia.contains(RegExp(r'\b(porque|por\s+que)\b'))) {
      scores['diagnostico'] = 6;
    }
    // Sub-intención Causal (Boost)
    if (queryLimpia.contains(RegExp(r'\b(no\s+pica|no\s+sale|no\s+anda)\b'))) {
      scores['diagnostico'] = (scores['diagnostico'] ?? 0) + 3;
    }
    if (queryLimpia.contains(RegExp(r'\b(cual|mejor|sirve\s+mas|conviene\s+mas)\b'))) {
      scores['comparacion'] = 5;
    }
    if (queryLimpia.contains(RegExp(r'\bconviene\b'))) {
      scores['conveniencia'] = 5;
    }
    if (queryLimpia.contains(RegExp(r'\b(cuanto|cuantos|cuanta|cuantas)\b'))) {
      scores['cantidad'] = 4;
    }
    if (queryLimpia.contains(RegExp(r'\b(como|de\s+que\s+manera)\b'))) {
      scores['como'] = 3;
    }
    if (queryLimpia.contains(RegExp(r'\b(donde|adonde|a\s+donde)\b'))) {
      scores['donde'] = 3;
    }
    if (queryLimpia.contains(RegExp(r'\bcuando\b'))) {
      scores['cuando'] = 3;
    }
    if (queryLimpia.contains(RegExp(r'\bque\b'))) {
      scores['que'] = 1;
    }

    String? tipo;
    int maxScore = 0;
    scores.forEach((key, value) {
      if (value > maxScore) {
        maxScore = value;
        tipo = key;
      }
    });

    // Con el nuevo enrutamiento flexible por contains, la cadena a analizar es la query limpia completa
    final rest = queryLimpia;

    // 2. Segundo Filtro: La Acción (listado expandido con verbos del pescador)
    String? accion;
    if (rest.contains(RegExp(r'\b(se\s+prepara|prepara|preparar|cocino|cocina|cocinar)\b'))) {
      accion = 'se_prepara';
    } else if (rest.contains(RegExp(r'\b(se\s+hace|hace|hacer|armo|armar)\b'))) {
      accion = 'se_hace';
    } else if (rest.contains(RegExp(r'\b(hago\s+si|hago|hacer\s+si)\b'))) {
      accion = 'hago';
    } else if (rest.contains(RegExp(r'\b(sirve|sirven|uso|usar|usa)\b'))) {
      accion = 'sirve';
    } else if (rest.contains(RegExp(r'\b(se\s+come|como|comer)\b'))) {
      accion = 'se_come';
    } else if (rest.contains(RegExp(r'\b(ir|voy|vamos)\b'))) {
      accion = 'ir';
    } else if (rest.contains(RegExp(r'\b(llevar|llevo|llevas|llevan)\b'))) {
      accion = 'llevar';
    } else if (rest.contains(RegExp(r'\b(pescar|pesco|pesca|pescan)\b'))) {
      accion = 'pescar';
    } else if (rest.contains(RegExp(r'\b(tirar|tiro|tiras|tiran)\b'))) {
      accion = 'tirar';
    } else if (rest.contains(RegExp(r'\b(probar|pruebo|pruebas|prueban)\b'))) {
      accion = 'probar';
    }

    // 3. Tercer Filtro: La Precisión del Objetivo (excluyendo enlaces e intenciones)
    final palabrasEnlace = {
      'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas',
      'de', 'del', 'al', 'para', 'por', 'con', 'sin', 'entre', 'sobre', 'en', 'mi', 'tu', 'su',
      'conviene', 'sirve', 'mejor', 'porque', 'como', 'cuando', 'donde', 'que', 'y', 'si', 'es',
      'se', 'hace', 'hacer', 'prepara', 'preparar', 'hago', 'sirven', 'uso', 'usar', 'mas', 'cual',
      'ir', 'voy', 'vamos', 'llevo', 'llevar', 'pesco', 'pescar', 'tiro', 'tirar', 'pruebo', 'probar',
      'cocinar', 'comer', 'esta', 'este', 'estos', 'estas', 'ahora', 'y ahora',
      'hoy', 'ayer', 'manana', 'tarde', 'noche', 'dia',
      'nudo', 'nudos', 'boya', 'boyas', 'plomada', 'plomadas', 'carnada', 'carnadas', 'caña', 'cañas',
      'cana', 'canas', 'reel', 'reeles', 'pez', 'peces', 'rio', 'rios', 'agua', 'aguas', 'prefectura',
      'pna', 'no', 'nada', 'masa'
    };

    final palabrasObjetivo = rest
        .replaceAll(RegExp(r'[¿?.,!;\(\)]'), ' ')
        .split(RegExp(r'\s+'))
        .map((w) => w.trim())
        .where((w) => w.length > 2 && !palabrasEnlace.contains(w))
        .toList();

    // Anti-Rescate (Patrones de Estado)
    final esConsultaEstado = queryLimpia.contains(RegExp(r'\b(como\s+esta|como\s+anda|que\s+tal)\b'));
    if (esConsultaEstado) {
      tipo = 'consulta_estado';
      palabrasObjetivo.clear();
    }

    // Memoria contextual ligera: Si falta objetivo y no es consulta de estado, inferir desde el contexto anterior
    if (palabrasObjetivo.isEmpty && !esConsultaEstado && _contexto.objetivosRecientes.isNotEmpty) {
      // Probar primero con el elemento más reciente (el último de la lista)
      for (final anterior in _contexto.objetivosRecientes.reversed) {
        if (anterior.isNotEmpty) {
          palabrasObjetivo.add(anterior);
          break;
        }
      }
    }

    // Rescate Nivel 1: Rescatar el último token significativo de la query con longitud > 2
    if (palabrasObjetivo.isEmpty && !esConsultaEstado) {
      final todosTokens = rest
          .replaceAll(RegExp(r'[¿?.,!;\(\)]'), ' ')
          .split(RegExp(r'\s+'))
          .map((w) => w.trim())
          .where((w) => w.length > 2)
          .toList();
      if (todosTokens.isNotEmpty) {
        palabrasObjetivo.add(todosTokens.last);
      }
    }

    // Si logramos resolver un objetivo, actualizar el contexto
    if (palabrasObjetivo.isNotEmpty && !esConsultaEstado) {
      final nuevoObj = palabrasObjetivo.first;
      if (nuevoObj.isNotEmpty) {
        _contexto.objetivosRecientes.remove(nuevoObj);
        _contexto.objetivosRecientes.add(nuevoObj);
        if (_contexto.objetivosRecientes.length > 5) {
          _contexto.objetivosRecientes.removeAt(0);
        }
      }
    }

    String? matchedFile;

    // Helper para intentar cargar y cachear un asset JSON local
    Future<bool> intentarCargarJSON(String candidateName) async {
      if (_librerias.containsKey(candidateName)) {
        return true;
      }
      try {
        final contenido = await rootBundle.loadString(
          'assets/elguia/librerias/$candidateName.json',
        );
        _librerias[candidateName] = json.decode(contenido) as Map<String, dynamic>;
        return true;
      } catch (_) {
        return false;
      }
    }

    final List<String> objetivosEvaluados = [];
    if (palabrasObjetivo.length > 1) {
      objetivosEvaluados.add(palabrasObjetivo.join('_'));
    }
    objetivosEvaluados.addAll(palabrasObjetivo);

    // Búsqueda jerárquica de archivos:
    for (final obj in objetivosEvaluados) {
      // Nivel 1: tipo_accion_objetivo
      if (tipo != null && accion != null) {
        final candidate = '${tipo}_${accion}_$obj';
        if (await intentarCargarJSON(candidate)) {
          matchedFile = candidate;
          break;
        }
      }

      // Nivel 2: tipo_objetivo
      if (tipo != null) {
        final candidate = '${tipo}_$obj';
        if (await intentarCargarJSON(candidate)) {
          matchedFile = candidate;
          break;
        }
      }

      // Nivel 3: accion_objetivo
      if (accion != null) {
        final candidate = '${accion}_$obj';
        if (await intentarCargarJSON(candidate)) {
          matchedFile = candidate;
          break;
        }
      }

      // Nivel 4: objetivo
      final candidate = obj;
      if (await intentarCargarJSON(candidate)) {
        matchedFile = candidate;
        break;
      }
    }

    // Nivel 5: Fallback a bibliotecas base si no hay coincidencia directa
    if (matchedFile == null) {
      for (final obj in objetivosEvaluados) {
        if (_librerias.containsKey(obj)) {
          return _generarRespuestaPorIntencion(obj, texto);
        }
        // Buscar si el objetivo es un activador de alguna intención base para delegar con contexto
        for (final entry in _activadores.entries) {
          if (entry.value.contains(obj)) {
            final textoConContexto = '$texto $obj';
            return _generarRespuestaPorIntencion(entry.key, textoConContexto);
          }
        }
      }
    }

    // Nivel 6 / Rescate Nivel 2: Fallback genérico por tipo de intención
    if (matchedFile == null && tipo != null) {
      final candidate = tipo!;
      if (await intentarCargarJSON(candidate)) {
        matchedFile = candidate;
      }
    }

    if (matchedFile != null) {
      return _generarRespuestaPorLibreriaDinamica(matchedFile, texto);
    }

    // Telemetría de Fallos Offline: Registrar el fallo
    String motivo = 'sin_coincidencia';
    if (tipo == null && accion == null) {
      motivo = 'sin_intencion_ni_accion';
    } else if (palabrasObjetivo.isEmpty) {
      motivo = 'sin_objetivo';
    }

    GuiaLogger.registrarFalloOffline(
      pregunta: texto,
      motivo: motivo,
    );

    return null;
  }

  ElGuiaRespuesta _generarRespuestaPorLibreriaDinamica(
    String fileName,
    String textoOriginal,
  ) {
    // Si es una intención estática nativa con lógica compleja, delegar a _generarRespuestaPorIntencion
    final intencionesNativas = {
      'prefectura_naval_argentina', 'boyas', 'nudos', 'carnadas', 'plomadas', 
      'canas_y_reeles', 'emergencia', 'supervivencia', 'agua', 'refugio', 
      'fuego', 'alimento', 'clima', 'peces', 'rio'
    };
    if (intencionesNativas.contains(fileName)) {
      return _generarRespuestaPorIntencion(fileName, textoOriginal);
    }

    final lib = _librerias[fileName]!;

    // Si la librería tiene respuestas directas (puente), elegir una aleatoria
    if (lib.containsKey('respuestas_puente')) {
      final puente = List<String>.from(lib['respuestas_puente'] as List);
      final intro = puente[_random.nextInt(puente.length)];

      // Si tiene tipos detallados (ej: diferentes masas o boyas)
      if (lib.containsKey('tipos')) {
        final tipos = lib['tipos'] as Map<String, dynamic>;
        final buffer = StringBuffer(intro);
        buffer.writeln('\n');
        tipos.forEach((key, val) {
          final desc = val['descripcion'] ?? '';
          final uso = val['uso'] ?? '';
          buffer.writeln('• ${key.toUpperCase()}: $desc ($uso)');
        });
        return ElGuiaRespuesta(
          texto: buffer.toString(),
          gifSugerido: 'explica',
        );
      }
      return ElGuiaRespuesta(texto: intro, gifSugerido: 'explica');
    }

    return ElGuiaRespuesta(
      texto:
          'Encontré información en la biblioteca sobre $fileName, chamigo. Te la muestro en breve.',
      gifSugerido: 'exito',
    );
  }

  ElGuiaRespuesta _generarRespuestaPorIntencion(
    String intencion,
    String textoOriginal,
  ) {
    final gif = _humor.gifParaIntencion(intencion);
    switch (intencion) {
      case 'prefectura_naval_argentina':
        return ElGuiaRespuesta(
          texto: _responderPrefectura(textoOriginal),
          gifSugerido: 'explica',
        );
      case 'boyas':
        return ElGuiaRespuesta(
          texto: _responderBoyas(textoOriginal),
          gifSugerido: 'explica',
        );
      case 'nudos':
        return ElGuiaRespuesta(
          texto: _responderNudos(textoOriginal),
          gifSugerido: 'explica',
        );
      case 'carnadas':
        return ElGuiaRespuesta(
          texto: _responderCarnadas(textoOriginal, [intencion]),
          gifSugerido: 'explica',
        );
      case 'plomadas':
        return ElGuiaRespuesta(
          texto: _responderPlomadas(textoOriginal),
          gifSugerido: 'explica',
        );
      case 'canas_y_reeles':
        return ElGuiaRespuesta(
          texto: _responderCanasReeles(textoOriginal),
          gifSugerido: 'explica',
        );
      case 'emergencia':
        return ElGuiaRespuesta(
          texto: _responderEmergencia(textoOriginal),
          gifSugerido: 'duda',
        );
      case 'supervivencia':
        return ElGuiaRespuesta(
          texto: _responderSupervivencia(),
          gifSugerido: 'duda',
        );
      case 'agua':
        return ElGuiaRespuesta(texto: _responderAgua(), gifSugerido: gif);
      case 'refugio':
        return ElGuiaRespuesta(texto: _responderRefugio(), gifSugerido: gif);
      case 'fuego':
        return ElGuiaRespuesta(texto: _responderFuego(), gifSugerido: gif);
      case 'alimento':
        return ElGuiaRespuesta(texto: _responderAlimento(), gifSugerido: gif);
      case 'clima':
        return ElGuiaRespuesta(
          texto: _responderClima(textoOriginal),
          gifSugerido: 'piensaProfundo',
        );
      case 'peces':
        return ElGuiaRespuesta(
          texto: _responderPeces(textoOriginal),
          gifSugerido: 'explica',
        );
      case 'rio':
        return ElGuiaRespuesta(
          texto: _responderRio(textoOriginal),
          gifSugerido: 'piensaProfundo',
        );
      default:
        final lib = _librerias[intencion];
        if (lib != null && lib.containsKey('respuestas_puente')) {
          final puente = List<String>.from(lib['respuestas_puente'] as List);
          return ElGuiaRespuesta(
            texto: puente[_random.nextInt(puente.length)],
            gifSugerido: 'explica',
          );
        }
        return ElGuiaRespuesta(
          texto:
              'Dejame ver qué tengo sobre $intencion, chamigo. Te recomiendo revisar los equipos o manuales.',
          gifSugerido: 'duda',
        );
    }
  }

  String obtenerIntencionPrincipal(String textoNormalizado) {
    return _obtenerMayorPrioridad(detectarIntenciones(textoNormalizado));
  }

  ElGuiaContext get contexto => _contexto;
  bool get estaInicializado => _inicializado;
  void dispose() => _contexto.dispose();

  Map<String, dynamic>? obtenerLibreria(String nombre) => _librerias[nombre];
}
