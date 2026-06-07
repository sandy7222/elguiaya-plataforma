import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, dynamic>> data = {
    "como_se_prepara_linea_vuelo_pejerrey": {
      "respuestas_puente": [
        "🎣 LÍNEA DE VUELO PARA PEJERREY\n\nSi vas a buscar matungos a lagunas muy presionadas o diques serranos, la línea de vuelo es la que va. Se arma sin boya guía tradicional para que la carnada caiga de forma súper natural.\n\nDetalles técnicos:\n- Madre y brazoladas: Usá nylon de baja memoria. La falta de peso en la línea te obliga a tener todo bien equilibrado.\n- Reel y Principal: Cargá el reel con multifilamento muy fino, de 0.12 a 0.14 mm.\n\nConsejo del Baqueano: Como no tenés un plomo pesado, el contacto es directo. El multi fino te deja ganar metros a lo loco en el lance y sentís el 'toque' del peje al instante. Clavá rapidito que, como el hilo no se estira, la clavada es fulminante."
      ]
    },
    "como_se_hace_nudo_union_tiburon": {
      "respuestas_puente": [
        "🎣 NUDO PARA UNIR NYLON GRUESO Y MULTIFILAMENTO\n\nIdeal para pelear con bestias de más de 100 kilos como tiburones, atunes o marlines, donde venís con multi en el reel frontal y necesitás un chicote largo de nylon grueso o fluorocarbono.\n\nArmado paso a paso:\n1. Hacé un ojal (una colita simple) con el nylon grueso (ej. 1.10 mm).\n2. Pasá el multifilamento doble (unos 20 cm) por adentro de ese ojal.\n3. Enroscá el multi sobre las dos partes del nylon dando 6 o 7 vueltas bien apretadas hacia abajo.\n4. Volvé a enroscar subiendo, pisando las vueltas anteriores.\n5. Pasá el extremo del multi por el ojal entrando por el lado opuesto al que entraste al principio (si entraste por abajo, salí por arriba).\n\nConsejo del Baqueano: Humedecé todo con un poquito de saliva o agua antes de ceñir. Para probarlo y estar seguro, atá el nylon a un poste firme y tirá del multi enrollado en un palito de escoba. ¡Ese nudo no se te corta ni a palos!"
      ]
    },
    "que_sirve_nylon_tiburon_mar": {
      "respuestas_puente": [
        "🎣 NYLON Y APAREJO PARA PESCA DE TIBURÓN (CON DEVOLUCIÓN)\n\nSi vas a buscar bacotas, cazones o escalandrunes en la costa, la reglamentación te exige pesca con devolución obligatoria. Tenés que armar un aparejo que cuide al bicho.\n\nDetalles técnicos:\n- Línea madre: Nylon de la mayor resistencia posible, con un grosor mínimo de 0.70 mm.\n- Anzuelos: Exclusivamente curvos tipo Mustad 39960 BL (circle hooks) de tamaño 12/0 o 14/0, o de fácil degradación.\n\nConsejo del Baqueano: Mandale una boya tope a 25 cm del anzuelo si pescás de fondo; esto evita que el bicho trague la carnada y se lastime los órganos. Y no le mezquines diámetro al nylon: pescá con algo grueso para arrimarlo rápido y no agotarlo antes de devolverlo al agua."
      ]
    },
    "como_se_prepara_linea_variada_costa": {
      "respuestas_puente": [
        "🎣 LÍNEA DE COSTA PARA MAR (VARIADA Y LENGUADO)\n\nPara meter el plomo atrás de la rompiente buscando corvinas o pescadillas desde la playa o escollera, el equipo tiene que cortar bien el viento y aguantar la sacudida.\n\nDetalles técnicos:\n- Carga del reel: Nylon fino, del 0.25 al 0.35 mm para ganar distancia.\n- Chicote (Salida): Indispensable atarle un nylon grueso del 0.40 al 0.70 mm en los últimos metros para bancar el latigazo del plomo (de 130 a 250 gramos).\n- Brazolada: Nylon de 0.50 mm.\n\nConsejo del Baqueano: Armate una línea de un solo anzuelo con 'baitclip'. Es un fierrito donde trabás el anzuelo encarnado. Cuando pegás el cañazo, la carnada viaja pegada al plomo, no va flameando ni te frena el lance. ¡Ganás una banda de metros!"
      ]
    },
    "que_sirve_multifilamento_baitcast_litoral": {
      "respuestas_puente": [
        "🎣 MULTIFILAMENTO PARA BAITCAST Y SPINNING (DORADO Y TARARIRA)\n\nEn el Litoral y río Uruguay, si tirás señuelos contra los palos y barrancas, el multi es tu mejor aliado porque no estira nada y clava derecho en la boca dura de los cazadores.\n\nDetalles técnicos:\n- Resistencia: Mandale 40 lbs para aguantar la llevada del dorado. Para la tararira en arroyos podés bajar el equipo a 10-20 lbs.\n- Prestaciones: Flota por sí solo (no requiere flota-líneas) y transmite cada movimiento de la puntera al señuelo.\n\nConsejo del Baqueano: Como la fibra del multi es tan dura y resbala fácil, tené cuidado con los nudos. Hacele un nudito en ocho en la punta para que haga tope si patina. Y nunca te olvides de mandarle al final un buen leader de acero de 40 lbs con snap para salvarte de los dientes del tigre."
      ],
      "tipos": [
        "Spinit Spectra (40 lbs)"
      ]
    },
    "cuando_sirve_nylon_blando_duro": {
      "respuestas_puente": [
        "🎣 CUÁNDO USAR NYLON BLANDO (SOFT) O DURO\n\nEl monofilamento es el alma de la pesca, pero su dureza cambia totalmente la forma en que trabaja la línea bajo el agua.\n\nDetalles técnicos:\n- Nylon Blando (Soft): Tiene más elonagación (se estira hasta un 10%) y es súper sedoso. \n- Nylon Duro: Es mucho más rústico pero ofrece una resistencia tremenda a la abrasión a igual diámetro.\n\nConsejo del Baqueano: Para armar las brazoladas de las boyas del pejerrey, usá el soft sin dudarlo; se plancha joya, tiene nula memoria y labura natural en el agua. Ahora, si vas a buscar una boga o variada al fondo del Paraná donde hay mucha piedra, meté nylon duro para la madre, porque el soft se te deshilacha de mirarlo nomás."
      ]
    },
    "como_se_prepara_linea_trucha_mosca": {
      "respuestas_puente": [
        "🎣 ARMADO DE LÍNEA PARA TRUCHAS EN RÍOS Y LAGOS PATAGÓNICOS\n\nPara tentar arcoíris y marrones en aguas como el Traful o el lago Filo Hua Hum, la clave de la pesca con mosca (fly cast) está en cómo estructurás tu leader.\n\nDetalles técnicos:\n- Río con correntada: Cañas #4 a #6. Usá líneas sinking tip (punta de hundimiento) con un leader cortito de 6 pies, terminado en tippet 1X o 2X.\n- Lagos: Si usás línea de flote con moscas secas, poné un leader más largo de 7 a 8 pies. Si vas al fondo a imitar pancoras, bajalo a 5 pies.\n\nConsejo del Baqueano: En el río rápido, el leader corto es clave para que la mosca baje junto con la punta de la línea sinking. Tirá hacia los sauces orilleros de enfrente, meté correcciones (mends) rapiditas para ganarle profundidad y preparate para el pique."
      ]
    },
    "que_sirve_multifilamento_mar_distancia": {
      "respuestas_puente": [
        "🎣 MULTIFILAMENTO PARA PESCA DE MAR A LARGA DISTANCIA\n\nCuando la segunda canaleta está lejísimos y necesitás clavar el plomo en el horizonte, los pescadores de costa más pro están reemplazando el monofilamento por el hilo trenzado.\n\nDetalles técnicos:\n- Diámetros extremos: Para maximizar la distancia, se usan medidas finísimas de 0.06 mm a 0.10 mm de alta calidad.\n- Aerodinámica: Corta el viento de forma espectacular y no hace resistencia en el mar.\n\nConsejo del Baqueano: Ojo los días de sudestada. Si hay mucho viento frontal, el multi te va a hacer una galleta imposible de desatar. Y acordate: como no cede ni un milímetro, poné siempre un chicote largo que te aguante el chicotazo, y usá un buen dedal, porque te corta el dedo de cuajo al tirar."
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
