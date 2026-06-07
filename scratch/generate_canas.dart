import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, dynamic>> data = {
    "que_sirve_cana_pejerrey_flote": {
      "respuestas_puente": [
        "🎣 CAÑAS TELESCÓPICAS PARA PEJERREY A FLOTE\n\nPara pescar pejerrey de flote, ya sea con línea de tres boyas en lagunas o en el Río de la Plata, necesitás cañas telescópicas muy largas y sumamente livianas [5, 6].\n\nDetalles técnicos:\n- Largo sugerido: Entre 3.60 y 4.20 metros, siendo 4.00 metros la medida más cómoda para tener dominio [6, 7].\n- Material: Grafito o combinación con fibra, siempre priorizando que sea de bajo peso y con pasahilos de óxido de aluminio (hardloy) [6, 8].\n- Acción: De punta (acción rápida) para lograr precisión y reacción inmediata al clavar [9].\n\nConsejo del Baqueano: Acordate de que la caña la vas a tener en la mano toda la jornada. Para armarla, estirá tramo por tramo con suavidad hacia arriba; nunca la saques de un tirón seco tipo latigazo porque se te van a trabar los tramos [10]."
      ],
      "tipos": [
        "Shimano Nexave AX 4.5m"
      ]
    },
    "que_sirve_cana_dorado_baitcasting": {
      "respuestas_puente": [
        "🎣 CAÑAS DE BAITCASTING PARA DORADO\n\nEl dorado o 'Tigre de los ríos' es agresivo y su boca es dura, por lo que buscamos dominarlo rápido en correderas usando baitcasting o spinning [3].\n\nDetalles técnicos:\n- Largo: Entre 6'6\" y 7' pies [3].\n- Potencia: Media a Pesada (15 a 30 lbs de resistencia) [3].\n- Acción: Rápida, fundamental para clavar con autoridad [3].\n- Material: Grafito para sentir la vibración del señuelo [11].\n\nConsejo del Baqueano: Buscá una caña sensible pero fuerte y usala con pasahilos hacia arriba si le montás un reel rotativo de bajo perfil [3, 12]. Al ser de grafito, transmiten rapidísimo el toque, pero cuidalas de los palazos contra la lancha porque son más frágiles [13, 14]."
      ],
      "tipos": [
        "St. Croix Mojo Bass 14 lb",
        "Shakespeare Ugly Stick GX2 MH",
        "Daiwa Procyon Bait 12-25 lbs"
      ]
    },
    "que_sirve_cana_dorado_flycast": {
      "respuestas_puente": [
        "🎣 CAÑAS DE FLY CAST PARA DORADO\n\nLa pesca de dorados con mosca es de las más extremas; las moscas son muy grandes, lastradas, y se necesitan líneas pesadas que destruyen los equipos convencionales [15, 16].\n\nDetalles técnicos:\n- Largo: Alrededor de 8'9\" pies para líneas número 8 [17].\n- Acción: Rápida o de punta, para acelerar la mosca pesada en el aire [4, 17].\n- Características: Pasahilos sobredimensionados, mangos 'full wells' de corcho y 'fighting butt' (talón de pelea) [16, 18, 19].\n\nConsejo del Baqueano: Olvidate de usar la caña truchera acá. Buscá cañas desarrolladas para el mar (Saltwater) con butts potentes [16, 18]. Vas a tener que dominar moscas voluminosas; una acción rápida te va a salvar los lances, pero requiere buena técnica de casteo [17]."
      ],
      "tipos": [
        "Sage Maverick (Saltwater)",
        "Sage Payload"
      ]
    },
    "que_sirve_cana_surubi_trolling": {
      "respuestas_puente": [
        "🎣 CAÑAS PARA SURUBÍ A TROLLING O FONDO\n\nPara bancar al Toro del Paraná pescando con morena viva o haciendo trolling (arrastre), necesitás un equipo robusto capaz de soportar peso y corridas fuertes [20].\n\nDetalles técnicos:\n- Largo: Entre 6' y 7' pies [20].\n- Potencia: Pesada o Extra Pesada (30 a 50 lbs) [20].\n- Acción: Media [20].\n- Tramos: Cañas enterizas de un solo tramo o de talón desmontable para mayor resistencia [12].\n\nConsejo del Baqueano: Acá no importa tanto la sensibilidad, sino la resistencia bruta de la vara para cansarlo [20]. Si vas al trolling, la acción media amortigua los cabeceos y evita que se desgarre el anzuelo [12, 20]."
      ]
    },
    "que_sirve_cana_mar_surfcasting": {
      "respuestas_puente": [
        "🎣 CAÑAS DE SURFCASTING PARA CORVINA EN LA PLAYA\n\nEn la costa atlántica argentina hay que lanzar detrás de la rompiente para llegar a la canaleta donde comen corvinas y pescadillas [2, 21, 22].\n\nDetalles técnicos:\n- Largo: De 3.50 a 4.20 metros, idealmente de 2 o 3 tramos [2, 23].\n- Potencia: Tienen que soportar lances con plomos pesados de entre 150 a 180 gramos [2, 23].\n- Pasahilos: Grandes, fundamental si usás reel frontal para que el nylon 0.35 salga sin golpear y logres distancia [23, 24].\n\nConsejo del Baqueano: La distancia lo es todo en la playa. Acordate siempre de armar un chicote de salida (nylon del 0.70 rebajado al 0.35) para amortiguar el latigazo del plomo pesado al lanzar [2, 24]."
      ],
      "tipos": [
        "Fistar 4.20m 3 tramos",
        "Okuma Cedros 3.00m"
      ]
    },
    "como_se_hace_pesca_kayak_mar": {
      "respuestas_puente": [
        "🎣 CAÑAS PARA PESCA EN KAYAK (MAR)\n\nArriba del kayak el espacio es mínimo; una caña larga es un estorbo gigante para maniobrar o arrimar la variada de mar [25].\n\nDetalles técnicos:\n- Largo: Nunca debe superar los 2.45 o 2.50 metros [25, 26].\n- Tipo: Corta, preferentemente de tramos desmontables y liviana [25].\n- Sensibilidad: Alta, para percibir los piques al instante [26].\n\nConsejo del Baqueano: Con fondearte pasadita la rompiente (unos 600 metros) ya te asegurás la pesca [27, 28]. Usá una caña cortita y un reel rotativo chico para estar bien cómodo; te va a permitir girar rápido si la correntada o el pez te cambian de ángulo [25, 27]."
      ],
      "tipos": [
        "Favistar 2.45m 3 tramos"
      ]
    },
    "que_sirve_cana_tiburon_embarcado": {
      "respuestas_puente": [
        "🎣 CAÑAS DE PESCA PESADA PARA TIBURÓN\n\nPara cazar escualos o pez limón embarcado estamos hablando de fuerza bruta y profundidad [29].\n\nDetalles técnicos:\n- Largo: Cortas, clavadas en 2.10 metros [30].\n- Potencia: Extrema, entre 40 y 80 lbs [29].\n- Acción: Lenta (Slow), para que el equipo absorba toda la fuerza del pez [29].\n- Construcción: 1 solo tramo (enteriza) de fibra de carbono/vidrio con roldanas en vez de pasahilos tradicionales [30].\n\nConsejo del Baqueano: Estas varas son garrotes hechas para acoplarse con abrazaderas al reel rotativo pesado y usarse con arnés de cintura [29]. Si te pica un buen bicho, la acción lenta te ayuda a no reventar la espalda en la pelea [29]."
      ],
      "tipos": [
        "Kunnan Ocean Deep 2.10m"
      ]
    },
    "que_sirve_cana_trucha_mosca": {
      "respuestas_puente": [
        "🎣 CAÑAS DE MOSCA (FLY CAST) PARA TRUCHA EN ARROYO\n\nPara buscar truchas en los prístinos arroyos de la Patagonia, vas a estar lanzando constantemente, requiriendo suma precisión y presentación suave [31].\n\nDetalles técnicos:\n- Peso y Flexibilidad: Ultralivianas, armadas en grafito para evitar la fatiga [31, 32].\n- Comportamiento: El grafito te otorga control para posar la mosca seca justo donde está comiendo el pez [31].\n\nConsejo del Baqueano: Si elegís pescar a mosca, el cansancio en el brazo te pasa factura al final del día. Huíle a la fibra de vidrio por el peso y metete de lleno al grafito ligero [31, 32]."
      ]
    },
    "que_sirve_cana_boga_spinning": {
      "respuestas_puente": [
        "🎣 CAÑAS LIVIANAS PARA BOGA Y PACÚ\n\nLa boga tiene un pique de 'descarnador' muy sutil, por lo que necesitás un equipo fino y sensible [12, 20].\n\nDetalles técnicos:\n- Largo: 6' a 6'6\" pies [12].\n- Potencia: Liviana (Ultralight / Light) de 6 a 12 lbs [12].\n- Acción: Rápida, para clavar en el instante que sentís el mordisco a la masa o el maíz [12].\n\nConsejo del Baqueano: Usá esta cañita con un reel frontal o de huevito bien calibrado. Al ser liviana, vas a disfrutar una enormidad la pelea deportiva, sintiendo cada cabezazo del 'Pirá Pitá' [12]."
      ]
    },
    "como_sirve_material_grafito": {
      "respuestas_puente": [
        "🎣 CAÑAS DE GRAFITO: SENSIBILIDAD Y LIGEREZA\n\nEl grafito es el rey de la pesca moderna de alto rendimiento por su estructura cristalina [11, 33].\n\nDetalles técnicos:\n- Módulo: Alto módulo, significa enorme rigidez y muy bajo peso [11, 32].\n- Ventajas: Transmite la señal del pique directo a la mano de forma instantánea [11, 13].\n- Desventajas: Al ser rígidas y de paredes finas, son frágiles ante golpes accidentales [14].\n\nConsejo del Baqueano: Ideal para pescar dorados, truchas o pejerreyes donde no te querés cansar [32, 34]. Tratalas como cristal cuando andes por la costa; un piedrazo te astilla la caña y la perdés [14, 35]."
      ]
    },
    "como_sirve_material_fibra_vidrio": {
      "respuestas_puente": [
        "🎣 CAÑAS DE FIBRA DE VIDRIO: GUERRERAS DEL RÍO\n\nUn material inorgánico que se la banca toda. Son cañas ideales para meterse al barro y los yuyos sin miedo [1].\n\nDetalles técnicos:\n- Módulo: Bajo, lo que se traduce en tremenda flexibilidad [1].\n- Ventajas: Aguantan impactos, duran años, amortiguan genial los tirones y son baratas [1, 14].\n- Desventajas: Son mucho más pesadas y menos sensibles, transmitiendo la señal con un pequeño 'lag' (retraso) [13, 32].\n\nConsejo del Baqueano: Si vas a pescar entre ramas o a lugares complejos, esta es tu aliada [35]. Te evitan los cortes si clavás accidentalmente un tronco, absorbiendo toda la curva [14, 35]."
      ]
    },
    "como_sirve_accion_rapida": {
      "respuestas_puente": [
        "🎣 ACCIÓN RÁPIDA (DE PUNTA)\n\nEs la famosa caña 'de punta' donde sólo se dobla el primer tercio superior de la vara al exigirla [9, 13].\n\nDetalles técnicos:\n- Respuesta: Inmediata. No hay retraso entre tu movimiento y el anzuelo [13].\n- Uso ideal: Dorado, pejerrey, boga y pesca con mosca pesada [3, 9, 12].\n\nConsejo del Baqueano: Usala cuando necesites levantar metros de nylon suelto del agua rapidísimo (como en las boyas de pejerrey) o cuando el pez tenga la boca durísima y precises una clavada seca y violenta [3, 9, 13]."
      ]
    }
  };

  final String dirPath = 'assets/elguia/librerias';
  final Directory dir = Directory(dirPath);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  final JsonEncoder encoder = const JsonEncoder.withIndent('  ');
  data.forEach((fileName, jsonMap) {
    final File file = File('$dirPath/$fileName.json');
    file.writeAsStringSync(encoder.convert(jsonMap));
    print('Generated: ${file.path}');
  });
  print('Successfully generated ${data.length} files.');
}
