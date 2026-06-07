import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, dynamic>> data = {
    "que_sirve_reel_pejerrey_frontal": {
      "respuestas_puente": [
        "🎣 REEL FRONTAL PARA PEJERREY\n\nPara la pesca del pejerrey en lagunas, muelles o costa, el reel frontal chico es la estrella indiscutida por su bajo peso y facilidad de uso.\n\nDetalles técnicos:\n- Tamaño ideal: Categorías 1000 a 3000.\n- Peso y materiales: Se buscan cuerpos de grafito ligeros para no fatigar el brazo tras largas horas de sostener la caña.\n- Ratio de recuperación: Rápido (ej. 5.1:1 a 7.1:1) para recoger rápidamente el nylon.\n- Rulemanes: Desde 1 hasta 9+1, priorizando la suavidad y el andar sedoso.\n\nConsejo del Baqueano: Calibrale el freno flojito. El peje tiene boca de seda; si clavás con el freno trabado le cortás el labio. Usá siempre carreteles de repuesto cargados, uno con multifilamento (que flota y ayuda a la línea de 3 boyas) y otro con nylon."
      ],
      "tipos": [
        "Spinit RX3000",
        "Gamma Blader CK 3000",
        "Okuma Aria 3000",
        "Flounder Eminence LR 3000",
        "Shimano FX C2500",
        "Bamboo Fishing Advance 1000",
        "Kunnan Reaction 4007 High Speed"
      ]
    },
    "que_sirve_reel_baitcast_huevito": {
      "respuestas_puente": [
        "🎣 REEL DE PERFIL BAJO (HUEVITO) PARA BAITCAST\n\nEl reel rotativo de perfil bajo, popularmente llamado 'huevito' o 'sapito', es el arma letal para el baitcast de precisión buscando dorados o tarariras entre los palos y juncos.\n\nDetalles técnicos:\n- Ergonomía: Diseño achatado que permite mantener el reel mirando al cielo y el dedo pulgar apoyado en la bobina todo el tiempo.\n- Freno: Requieren ajuste fino de frenos de carrete, magnéticos y/o centrífugos según el peso del señuelo.\n\nConsejo del Baqueano: Esta máquina requiere paciencia, no quieras tirar al otro lado del río el primer día. Dominar un huevito lleva tiempo; usá señuelos pesados al principio y el dedo pulgar siempre listo para frenar el tambor apenas el artificial toque el agua. Si no lo hacés, la galleta va a ser de novela."
      ],
      "tipos": [
        "Spinit X-Treme",
        "Spinit Magma",
        "Spinit Mega Cast",
        "Spinit KF"
      ]
    },
    "como_se_hace_limpieza_salitre_mar": {
      "respuestas_puente": [
        "🧼 LIMPIEZA DEL SALITRE Y CUIDADO POST-PESCA\n\nEl peor enemigo de un reel no es el pez grande, es el salitre del mar, la arena y el barro de las lagunas. Una buena limpieza duplica la vida útil de tu equipo.\n\nDetalles técnicos:\n- Procedimiento: Para agua dulce, usar un paño humedecido con agua tibia cuidando la bobina y el pick-up. Para mar, el lavado bajo canilla con chorro suave y controlado es vital para frenar la corrosión.\n- Secado: Pasar siempre un trapo completamente seco luego del enjuague.\n\nConsejo del Baqueano: ¡Ojo al piojo! Nunca, pero nunca, sumerjas el reel adentro de un balde con agua dulce pensando que así lo limpiás mejor. Lo único que lográs es empujar la humedad y la mugre directo a los engranajes internos."
      ]
    },
    "como_se_prepara_freno_estrella_rotativo": {
      "respuestas_puente": [
        "⭐ CÓMO REGULAR EL FRENO DE ESTRELLA O COMBATE\n\nEl freno de estrella es el responsable de ceder sedal antes de que la línea se corte durante la pelea con un buen trofeo.\n\nDetalles técnicos:\n- Ubicación: Se encuentra detrás de la manivela en los rotativos.\n- Regulación: Se debe calibrar a un cuarto o un quinto de la resistencia estática de la línea (ej. línea de 10 kg, freno a 2 o 2,5 kg).\n- Acción: Un buen freno suelta línea de manera pareja y sedosa, sin saltos abruptos.\n\nConsejo del Baqueano: Calibralo usando una balanza enganchada en la punta de la línea o a ojo, dejando que ceda a un tercio de la curvatura máxima de tu caña. Y si pescás bichos de boca dura como el dorado, podés apretarlo un poco más al clavar, pero acordate de aflojarlo enseguida para no cortar en la corrida."
      ]
    },
    "como_se_prepara_freno_magnetico_lance": {
      "respuestas_puente": [
        "🧲 CÓMO REGULAR EL FRENO MAGNÉTICO\n\nEste sistema lateral es el ángel guardián de los lanzadores de rotativos, controlando la velocidad de la bobina mediante imanes para evitar excesos de giro.\n\nDetalles técnicos:\n- Escala: Va indicado por números, habitualmente del 1 al 10.\n- Acción: El número 1 significa que el imán está muy ajustado (frena mucho), y el 10 da libertad casi total al carretel (lances largos pero riesgosos).\n\nConsejo del Baqueano: Si sos nuevo, no te hagas el guapo con el número 10. Empezá con el freno en 5 o 6 para tantear cómo vuela el señuelo. A medida que tu pulgar se ponga más educado, le vas aflojando los imanes para ganar distancia."
      ]
    },
    "como_se_prepara_freno_centrifugo_galleta": {
      "respuestas_puente": [
        "⚙️ CÓMO REGULAR EL FRENO CENTRÍFUGO\n\nOculto bajo la tapa lateral del reel rotativo, el freno centrífugo actúa por pura física para evitar las famosas y temidas 'galletas' de hilo.\n\nDetalles técnicos:\n- Mecanismo: Tiene entre 2 y 6 pesas o clavijas (pines) en radios. Al girar rápido el carrete, la fuerza centrífuga empuja las pesas hacia afuera, generando fricción y frenando la bobina.\n- Ajuste: Pesas hacia afuera = activadas. Pesas hacia el centro = desactivadas.\n\nConsejo del Baqueano: Arrancá tus primeras salidas con todos los pines activados. Cuando le agarres la mano, andá desactivándolos de a poco para ganar distancia. ¡Pero ojo! Siempre activá o desactivá de a pares enfrentados, si no el carrete pierde equilibrio y te vibra toda la máquina."
      ]
    },
    "como_se_prepara_freno_lanzamiento_senuelo": {
      "respuestas_puente": [
        "🎣 CÓMO REGULAR EL FRENO DE CARRETE (LANZAMIENTO)\n\nEs esa perillita o botón redondo en la placa lateral que salva a más de uno de pasar la tarde desenredando multifilamento.\n\nDetalles técnicos:\n- Función: Controla la aceleración del giro del tambor y presiona el eje del carrete.\n- Regulación continua: Debe ajustarse cada vez que se cambia el peso del señuelo o la plomada que estemos usando.\n\nConsejo del Baqueano: Para dejarlo a punto caramelo, poné la caña a 45 grados, apretá el botón liberador y dejá que el señuelo caiga libremente. Ajustá la perilla para que caiga lento, unos 10 a 20 centímetros, sin saltos. Cuando el señuelo toque el piso, el carrete debe frenarse seco, ¡sin dar ni media vuelta extra!"
      ]
    },
    "que_sirve_reel_trolling_surubi": {
      "respuestas_puente": [
        "🚤 REEL ROTATIVO PESADO PARA TROLLING Y SURUBÍ\n\nCuando vas a arrastrar señuelos con la lancha en movimiento (trolling) o a buscar las bestias del río (grandes dorados o surubíes), necesitás un malacate de verdad.\n\nDetalles técnicos:\n- Max Drag (Arrastre): Frenos potentes, rondando las 30 libras con discos híbridos de acero y carbono.\n- Rulemanes: Abundantes, ej. 11 rodamientos de acero inoxidable para soportar combates pesados.\n- Capacidad: Tienen que alojar sobradamente monofilamentos gruesos (250 m de 0.35 mm a 0.50 mm).\n- Relación de recuperación: Variables, algunos modernos superan el 7.3:1.\n\nConsejo del Baqueano: Al hacer trolling, el pique es un misilazo. Llevá la estrella del freno floja mientras navegás. Si el freno está duro cuando el tigre de los ríos ataca, te revienta el sedal o te saca la caña de las manos. Que lleve un poco, y ahí nomás lo ajustás."
      ],
      "tipos": [
        "Tigon Bg 300 R/L",
        "Spinit Paraná River",
        "Spinit RC3500",
        "Spinit Ultimate"
      ]
    },
    "como_se_hace_lubricacion_interna_wd40": {
      "respuestas_puente": [
        "🛢️ MANTENIMIENTO INTERMEDIO: LUBRICACIÓN CORRECTA\n\nEl reel es relojería fina. Para que siga girando sedoso y no te deje a gamba, requiere lubricación periódica.\n\nDetalles técnicos:\n- Frecuencia: Cada tres o cuatro salidas intensas.\n- Puntos de aplicación: Una gota en el eje de la manivela, en el pick-up y rodamientos visibles.\n- Producto: Solo lubricantes y aceites diseñados específicamente para reels o rodamientos de precisión.\n\nConsejo del Baqueano: Aleja el tubo de WD-40 o los aceites de cocina de tu caja de pesca. Los desengrasantes barren la grasa original de fábrica, resecan los plásticos y con el tiempo te arruinan el mecanismo. El aceite para armas o de máquina de coser fina es mucho mejor si no tenés el original."
      ]
    },
    "como_se_prepara_guardado_reel_freno": {
      "respuestas_puente": [
        "📦 CÓMO GUARDAR TU REEL FUERA DE TEMPORADA\n\nGuardar el reel correctamente durante los meses de invierno o pausas largas asegura que el primer tiro de la temporada no termine en rotura.\n\nDetalles técnicos:\n- Almacenamiento: Funda de tela, neopreno o caja plástica ventilada, en un lugar seco sin humedad.\n- Línea: Si lo guardás con el nylon o multifilamento puesto, asegurate de que esté 100% seco para evitar hongos y malos olores.\n\nConsejo del Baqueano: Hay un error de principiante que te liquida el equipo: guardar el reel con la estrella del freno ajustada. Si dejás los discos apretados por meses, se deforman y la próxima vez que te pique un dorado, el freno te va a dar tirones a los saltos. ¡Aflojá todo antes de guardarlo!"
      ]
    },
    "que_sirve_reel_spinning_frontal": {
      "respuestas_puente": [
        "🎣 REEL FRONTAL PARA SPINNING Y SEÑUELOS\n\nEl 'Spinning' es la técnica por excelencia para cubrir grandes superficies de agua (barrer agua) usando señuelos y un reel frontal clásico.\n\nDetalles técnicos:\n- Ventaja balística: Como la línea sale suelta del tambor formando un 'spin' (rulo), es ideal para ganar distancia y resistir mejor los vientos laterales sin hacer galleta.\n- Curva de aprendizaje: Muy rápida, ideal para novatos. Solo se levanta el pick-up, se sostiene con el dedo índice y se lanza.\n- Limitación: Menor precisión milimétrica frente a estructuras comparado al baitcast.\n\nConsejo del Baqueano: Si vas a un río abierto o una laguna a lanzar cucharas y vinilos buscando tarariras a lo lejos, llevate el frontal. Es un fierro que no te va a fallar ni te va a frustrar con enredos."
      ],
      "tipos": [
        "Spinit Style",
        "Spinit Classe",
        "Spinit SX",
        "Spinit Phanter",
        "Spinit Proton",
        "Spinit Vortex",
        "Spinit Triumph Titan"
      ]
    },
    "donde_sirve_reel_surfcasting_mar": {
      "respuestas_puente": [
        "🌊 REEL PARA SURFCASTING (PESCA DE PLAYA)\n\nLanzar un plomo pesado a la segunda canaleta del mar requiere un equipo que sea una verdadera catapulta.\n\nDetalles técnicos:\n- Tipo de reel: Frontales extra grandes (tamaños 9000) o rotativos sin devanador.\n- Bobina (Frontal): Se buscan carretes anchos, cónicos y poco profundos para disminuir el roce de la salida del nylon.\n- Capacidad: Requieren cargar entre 300 y 400 metros de un nylon grueso (ej. 0.40 mm a 0.50 mm) más el espacio para el chicote de salida.\n\nConsejo del Baqueano: Si usás un frontal para tirar de costa en el mar, asegurate siempre de usar un dedal protector. La fricción del nylon grueso al hacer el chicotazo te puede cortar el dedo índice hasta el hueso."
      ],
      "tipos": [
        "Spinit Oceanic 9000",
        "Spinit Pro Distance"
      ]
    },
    "donde_sirve_reel_embarcado_mar_variada": {
      "respuestas_puente": [
        "⚓ REEL PARA VARIADA DE MAR EMBARCADO\n\nEn mar abierto, pescando de altura o embarcado, el torque y la capacidad de hilo son más importantes que la distancia de lanzamiento.\n\nDetalles técnicos:\n- Variada Chica-Mediana: Se prefieren reeles rotativos medianos cargados con 250 a 300 metros de nylon (0.40 mm a 0.50 mm) o multifilamento (0.22 a 0.25 mm).\n- Variada Grande: Reeles rotativos potentes con nylon del 0.60 mm al 0.70 mm. En caso de bestias pelágicas, puede subir hasta 1.3 mm con cargas de más de 500 metros.\n\nConsejo del Baqueano: El rotativo es amo y señor acá. Cuando dejás caer la plomada en vertical a 30 metros de profundidad, la fuerza de recuperación de este tipo de reel absorbe todo el esfuerzo, y no sufrís la pesca sacando peces pesados desde el fondo."
      ],
      "tipos": [
        "Spinit Offshore",
        "Spinit Mariner"
      ]
    },
    "que_sirve_reel_flycast_trucha": {
      "respuestas_puente": [
        "🪰 REEL MOSQUERO PARA FLY CAST (TRUCHA Y DORADO)\n\nEl reel de Fly Cast funciona distinto a todos. No se usa para lanzar, sino principalmente como alojamiento de reserva (backing) de la gruesa 'cola de ratón' y para balancear la caña.\n\nDetalles técnicos:\n- Clasificación: Se miden en números (#2 hasta #8 son los más usados en Argentina) y el reel debe coincidir exactamente con el número de la caña.\n- Especies: Principalmente truchas en la Patagonia, pero totalmente adaptable a dorados, tarariras y hasta pejerreyes usando moscas secas o ninfas.\n\nConsejo del Baqueano: En el Fly la distancia la ponés vos con la caña, 'trabajando' la salida de la línea de manera progresiva y cíclica por los aires (falso cast). El reel casi ni interviene hasta que tenés una trucha grande enganchada y corre llevándose el hilo."
      ]
    },
    "como_se_hace_reel_jigging_vertical": {
      "respuestas_puente": [
        "⬇️ REEL PARA JIGGING O PESCA VERTICAL\n\nEl jigging trata de dejar caer señuelos muy pesados (plomados) hasta el fondo desde la lancha y recuperarlos a tirones, incitando a los predadores profundos.\n\nDetalles técnicos:\n- Compatibilidad: Se puede realizar indistintamente con reeles frontales de gran tamaño y poder de freno, o con rotativos potentes de carretel angosto.\n- Sedal: Multifilamentos resistentes para asegurar que no haya estiramiento y que el movimiento de la caña llegue directo al señuelo a 40 metros abajo.\n\nConsejo del Baqueano: Necesitás brazos de hierro y un reel con un eje principal que no sea de juguete. Si la máquina no es de calidad, el esfuerzo constante de tironear piezas de metal pesadas desde el fondo te termina desgranando los rulemanes en dos salidas."
      ]
    },
    "que_sirve_freno_dc_shimano": {
      "respuestas_puente": [
        "💻 REEL CON FRENO 'DC' O MICROCOMPUTADORA\n\nEl pináculo tecnológico en los reeles rotativos modernos para evitar completamente los enredos al lanzar.\n\nDetalles técnicos:\n- Tecnología: Invención aplicada a los modelos tope de gama (ej. Shimano).\n- Funcionamiento: Posee una microcomputadora (Digital Control) interna que monitorea la velocidad del carrete ¡mil veces por segundo!\n- Acción: Aplica la cantidad exacta y milimétrica de frenado a la bobina, previniendo el giro excesivo.\n\nConsejo del Baqueano: Si el bolsillo te da para uno de estos, es como manejar un auto automático en medio del tráfico. Vos solo tirás y la maquinita piensa por vos, optimizando la distancia y eliminando la galleta sin que toques la placa magnética."
      ]
    },
    "que_sirve_diferencia_frontal_rotativo": {
      "respuestas_puente": [
        "⚖️ FRONTAL VS ROTATIVO: DIFERENCIAS CLAVE\n\nEl dilema eterno del pescador. Conocer sus diferencias mecánicas es clave para no comprar un equipo equivocado.\n\nDetalles técnicos:\n- Frontal: Bobina fija, la línea sale libre y haciendo rulos. Es ideal para ganar distancia, evitar galletas y cambiar carreteles rápido (uno con nylon, otro con multi). Es el mejor para arrancar.\n- Rotativo: La bobina gira sobre un eje transversal. Logra mayor precisión y capacidad de línea.\n- Fuerza: El rotativo tiene el 'efecto malacate', es decir, ejerce fuerza directa sobre un eje sinfín, haciéndolo ideal para arrastrar peces pesados o zafar de enganches sin romper la manija (un error común al forzar los frontales).\n\nConsejo del Baqueano: Arrancá con un frontal, que es la escuela primaria. Una vez que no enganches más ni cortes por hacer macanas, pasate al rotativo para ganar control milimétrico al lado de los palos."
      ]
    },
    "donde_sirve_reel_rio_costa_variada": {
      "respuestas_puente": [
        "🏕️ REEL PARA VARIADA DE RÍO DESDE LA COSTA\n\nPara tentar bogas, bagres o patíes desde la costa del Paraná, el Río de la Plata o lagunas de llanura profunda.\n\nDetalles técnicos:\n- Tamaño de reel: Frontal o rotativo mediano.\n- Capacidad de carga: Suficiente para cargar entre 150 a 250 metros de un buen nylon o monofilamento de 0.30 a 0.40 mm.\n- Si usás multifilamento: Elegir diámetros del 0.20 al 0.24 mm.\n\nConsejo del Baqueano: Si tirás plomadas pesadas para que no derive la corriente, siempre usá un 'chicote' (un pedazo de tanza más gruesa al final) para absorber el impacto del lanzamiento. Esto te permite usar hilos más finos en el carrete, ganando metros y evitando que el viento o el agua te arrastren la línea."
      ]
    },
    "que_sirve_reel_fuerza_rio_rotativo": {
      "respuestas_puente": [
        "🐟 REEL PARA PECES GRANDES DE RÍO (EMBARCADO/COSTA)\n\nCuando vamos a cazar grandes surubíes o patíes gigantes, necesitamos equipos robustos donde la palanca la haga la máquina y no la caña.\n\nDetalles técnicos:\n- Tipo de reel: Rotativos cilíndricos de perfil redondo.\n- Capacidad: Nylon grueso de 0.40 mm a 0.50 mm, o multifilamentos de 0.24 mm a 0.27 mm.\n- Mecánica: Aprovechan la fuerza del malacate directo para subir peso muerto desde la profundidad.\n\nConsejo del Baqueano: A diferencia del pejerrey, acá el pez te va a dar pelea de fondo. Ajustale bien la estrella y usá el rotativo como un guinche, bombeando con la caña hacia arriba y recogiendo al bajar. ¡Nunca recojas mientras el pez está tirando con fuerza porque reventás los engranajes!"
      ],
      "tipos": [
        "Spinit Paraná River",
        "Spinit RC3500",
        "Spinit Ultimate"
      ]
    },
    "como_se_hace_mantenimiento_profundo_anual": {
      "respuestas_puente": [
        "🛠️ MANTENIMIENTO PROFUNDO ANUAL\n\nMás allá de la aceitadita superficial, todo reel fiel necesita una visita al doctor al terminar la temporada para quedar como 0 km.\n\nDetalles técnicos:\n- Procedimiento: Desarme completo del carrete, limpieza interna, engrasado de engranajes y reemplazo de partes desgastadas.\n- Herramientas: Muchos talleres usan limpieza por ultrasonido y reemplazo por grasas originales de fábrica.\n\nConsejo del Baqueano: Si sos curioso y tenés maña, hacelo vos, pero armate en una mesa limpia y sacale una foto con el celu a cada pieza que sacás. Ahora, si tu reel es de gama alta (o sos de los que les sobran tornillos al armar), gastate unos mangos y llevalo a un servicio técnico de confianza en tu casa de pesca. Vale cada centavo."
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
