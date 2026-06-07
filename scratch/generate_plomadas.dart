import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, dynamic>> data = {
    "que_sirve_plomada_destrabe_mar": {
      "respuestas_puente": [
        "⚓ PLOMADAS DE DESTRABE PARA EL MAR\n\nPara pescar de costa con olas grandes y correntada lateral, la plomada de destrabe (o ganchos) es la que te mantiene la línea firme en el fondo.\n\nDetalles técnicos:\n- Pesos recomendados: De 120 a 180 gramos (la de 160g es muy usada).\n- Funcionamiento: Posee 4 alambres templados que actúan como anclas en la arena. Al clavar la caña, los alambres zafan hacia atrás y liberan el plomo.\n\nConsejo del Baqueano: Lanzá y dejá que la correntada estire la tanza. Cuando recojas, dale continuo y con ritmo para que suba rápido a la superficie y no se te clave en las piedras traicioneras."
      ],
      "tipos": [
        "Plomada de destrabe tradicional",
        "Plomada gancho con destrabe"
      ]
    },
    "que_sirve_plomada_pata_arana_parana": {
      "respuestas_puente": [
        "⚓ PLOMADA PATA DE ARAÑA PARA EL PARANÁ\n\nEn ríos caudalosos como el Paraná, una plomada redonda rueda y cruza las líneas de todos. La pata de araña es ley.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 160 gramos, dependiendo el remanso.\n- Funcionamiento: Sus alambres fijos se clavan en el barro o arena, inmovilizando la línea contra la fuerte corriente.\n\nConsejo del Baqueano: Tirá siempre medio en contra de la correntada. Al recoger, vas a tener que hacer un tironcito extra al principio para desenterrarla, pero te asegura no cruzar a los demás pescadores."
      ],
      "tipos": [
        "Plomada pata de araña",
        "Plomada con alambre fijo"
      ]
    },
    "como_se_hace_fusible_rocas": {
      "respuestas_puente": [
        "⚓ TÉCNICA DEL FUSIBLE EN ZONAS DE ENGANCHE\n\nSi pescás en escolleras o fondos de piedra, vas a dejar medio sueldo en plomadas si no usás fusible.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 150 gramos (plomos baratos).\n- Funcionamiento: Se vincula el plomo al esmerillón con un nylon fino (ej. 0.30mm) frente a una madre más gruesa.\n\nConsejo del Baqueano: Armate el fusible con un alambrecito abierto o un nylon fino. Si se traba en las piedras, pegás el tirón, cortás solo el plomo y salvás el resto de la línea y la pieza."
      ]
    },
    "donde_sirve_plomada_satelite_muelle": {
      "respuestas_puente": [
        "⚓ PLOMADA SATÉLITE PARA MUELLES\n\nDesde los muelles hay muchísimas líneas cortadas en el fondo. Los ganchos acá son suicidas.\n\nDetalles técnicos:\n- Pesos recomendados: 120 a 160 gramos.\n- Funcionamiento: Al ser compacta y tener aletas, se ancla moderadamente pero no tiene puntas que se enganchen en sedales viejos.\n\nConsejo del Baqueano: Tirá en diagonal desde las esquinas del muelle. Evitá el frente directo donde está el mayor cementerio de líneas enganchadas."
      ],
      "tipos": [
        "Plomada satélite clásica"
      ]
    },
    "donde_sirve_plomada_piramide_arena": {
      "respuestas_puente": [
        "⚓ PLOMADA PIRÁMIDE PARA FONDOS DE ARENA\n\nEs la reina de la playa cuando buscás buena fijación sin llegar a los ganchos.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 150 gramos.\n- Funcionamiento: Su forma hace que se entierre de cabeza en la arena suave, manteniendo la brazolada quieta.\n\nConsejo del Baqueano: Usala en la primera o segunda canaleta si la correntada lateral no es tan violenta. Si el mar tira mucho, cambiala por una de grapas."
      ],
      "tipos": [
        "Plomada pirámide chata",
        "Plomada pirámide larga"
      ]
    },
    "que_sirve_plomada_reloj_correntada": {
      "respuestas_puente": [
        "⚓ PLOMADA RELOJ PARA FUERTE CORRIENTE\n\nPara fondos planos, la reloj o corona es un ancla natural que copia el fondo.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 140 gramos.\n- Funcionamiento: Su base chata hace un efecto sopapa contra la arena o el barro, inmovilizando todo.\n\nConsejo del Baqueano: Tené en cuenta que frena muchísimo en el aire. No sirve para buscar grandes distancias porque la aerodinámica te juega en contra. Tirala cerca, en los veriles."
      ],
      "tipos": [
        "Plomada reloj lisa",
        "Plomada corona con puntas"
      ]
    },
    "que_sirve_plomada_perita_pasto": {
      "respuestas_puente": [
        "⚓ PLOMADA PERITA PARA ZONAS CON VEGETACIÓN\n\nEl comodín de las lagunas bonaerenses para pescar de fondo esquivando la \"ensalada\".\n\nDetalles técnicos:\n- Pesos recomendados: 40 a 90 gramos.\n- Funcionamiento: Su forma redondeada abajo y afinada arriba hace que se deslice entre juncos y algas sin juntar mugre.\n\nConsejo del Baqueano: Si la laguna tiene pasto en el fondo, mandale una perita. Además, si pescás al vuelo, rueda un poco y le da movimiento natural a la carnada."
      ]
    },
    "donde_sirve_plomada_almeja_calma": {
      "respuestas_puente": [
        "⚓ PLOMADA ALMEJA PARA AGUAS CALMAS\n\nExcelente cuando el mar o río parece un espejo y usamos equipos livianos.\n\nDetalles técnicos:\n- Pesos recomendados: 60 a 100 gramos.\n- Funcionamiento: Sus dos frentes convexos se pegan al fondo y no ofrecen resistencia a corrientes laterales suaves.\n\nConsejo del Baqueano: Es la mejor amiga para la pesca sutil. Si el día está planchado, no uses cascotes gigantes; con esta bajás bien y sentís cada toque del pescado."
      ]
    },
    "que_sirve_plomada_pasante_boga": {
      "respuestas_puente": [
        "⚓ PLOMADA PASANTE PARA PECES DESCONFIADOS\n\nFundamental para la boga, el pacú o la corvina negra, que escupen si sienten resistencia.\n\nDetalles técnicos:\n- Pesos recomendados: 40 a 80 gramos (río).\n- Funcionamiento: El hilo pasa por el centro del plomo. El pez toma la carnada, corre y no levanta el peso de la plomada.\n\nConsejo del Baqueano: Dejá el freno del reel flojito. Cuando la boga lleve, dale unos metros y recién ahí clavas. Si le ponés plomo fijo, te deja la carnada pelada."
      ],
      "tipos": [
        "Pasante redonda chata",
        "Pasante gota"
      ]
    },
    "que_sirve_plomada_voladora_enganches": {
      "respuestas_puente": [
        "⚓ PLOMADA VOLADORA ANTI-ENGANCHE\n\nEl salvavidas en pesqueros llenos de lajas, piedras o ramas sumergidas.\n\nDetalles técnicos:\n- Pesos recomendados: 80 a 140 gramos.\n- Funcionamiento: Tiene aletas aerodinámicas especiales que, apenas le das tracción al reel, la hacen subir y planear al ras del agua.\n\nConsejo del Baqueano: El secreto es no dudar. Levantá la caña y recogé a toda velocidad sin parar. Si aflojás, se hunde y quedás atracado."
      ],
      "tipos": [
        "Voladora fija",
        "Voladora pasante"
      ]
    },
    "donde_sirve_plomada_torpedo_embarcado": {
      "respuestas_puente": [
        "⚓ PLOMADA TORPEDO PARA PESCA EMBARCADA\n\nCuando estás mar adentro y necesitás bajar 30 metros de golpe contra la corriente.\n\nDetalles técnicos:\n- Pesos recomendados: 200 a 400 gramos.\n- Funcionamiento: Su gran masa y forma cilíndrica cortan el agua a pique, llegando al fondo velozmente.\n\nConsejo del Baqueano: Usá esmerillones de alta resistencia. Dejala golpear el fondo y subila un par de vueltas de manija. Cuidado al subirla al bote de no golpear la fibra de vidrio."
      ]
    },
    "donde_sirve_plomada_tornillo_escollera": {
      "respuestas_puente": [
        "⚓ PLOMADA TORNILLO PARA ESCOLLERAS\n\nEl agua rompiendo en los bloques de piedra te saca la línea para cualquier lado, acá entra el tornillo.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 140 gramos.\n- Funcionamiento: Su diseño espiralado se afianza mecánicamente entre la arena gruesa y las rocas chicas.\n\nConsejo del Baqueano: No busques distancia con esta. Tirala cerquita, al pie de la escollera, donde andan comiendo los sargos y borriquetas en la espuma."
      ]
    },
    "donde_sirve_plomada_triangular_rio": {
      "respuestas_puente": [
        "⚓ PLOMADA TRIANGULAR PARA POZONES DE RÍO\n\nIdeal para buscar los grandes surubíes o dorados en el fondo de las correderas.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 160 gramos.\n- Funcionamiento: Se pega de manera plana al fondo y sus vértices evitan que la corriente la haga rodar.\n\nConsejo del Baqueano: Cuesta un poco levantarla porque hace efecto vacío en el barro. Pegale un buen tirón inicial con la vara para despegarla."
      ]
    },
    "que_sirve_plomada_uruguaya_mixto": {
      "respuestas_puente": [
        "⚓ PLOMADA URUGUAYA: LA TODOTERRENO\n\nSi vas a un pesquero desconocido y tenés que elegir una sola plomada, llevá la uruguaya.\n\nDetalles técnicos:\n- Pesos recomendados: 90 a 150 gramos.\n- Funcionamiento: Sus cuatro frentes cóncavos anclan firme, y si tiene punta cónica, vuela hermoso.\n\nConsejo del Baqueano: Sirve tanto para río como para mar. Corta el viento como flecha y se asienta de maravilla. Nunca falla en el cajón de pesca."
      ]
    },
    "como_sirve_plomada_cebadora_espera": {
      "respuestas_puente": [
        "⚓ PLOMADA CEBADORA PARA PESCA A LA ESPERA\n\nDos funciones en uno: ancla tu línea y atrae al cardumen directo a tus anzuelos.\n\nDetalles técnicos:\n- Pesos recomendados: 90 a 120 gramos (más el peso de la ceba).\n- Funcionamiento: Es hueca o con alambres espiralados. Se rellena con masa, aceite de pescado o magrú picado.\n\nConsejo del Baqueano: Ideal para pescar carpas o variada de mar lenta. Apretá bien la ceba para que no se desarme en el aire y vaya soltando olorcito una vez en el fondo."
      ]
    },
    "donde_sirve_plomada_conica_piedras": {
      "respuestas_puente": [
        "⚓ PLOMADA CÓNICA PARA ESQUIVAR ROCAS\n\nLa forma de gota de lluvia invertida es ideal para terrenos ásperos sin llegar a ser inenganchable al 100%.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 150 gramos.\n- Funcionamiento: Se afirma bien al fondo si no hay corriente extrema, pero al recuperar, su frente fino patina sobre la piedra.\n\nConsejo del Baqueano: Si hay mucha piedra redonda o laja, es una opción excelente para traer rebotando suave sin clavar puntas."
      ]
    },
    "que_sirve_plomada_tubular_laguna": {
      "respuestas_puente": [
        "⚓ PLOMADA TUBULAR PARA LÍNEAS PATERNÓSTER\n\nEl lastre fino por excelencia para pescar pejerrey a distintas profundidades.\n\nDetalles técnicos:\n- Pesos recomendados: 10 a 40 gramos.\n- Funcionamiento: Es pasante y alargada. Mantiene la línea madre estirada hacia el fondo en vertical.\n\nConsejo del Baqueano: Dejale un margen entre los nudos para que deslice un poquito. Si está muy ajustada, el peje siente el tirón brusco y escupe la mojarra."
      ]
    },
    "cuando_sirve_plomada_oficial_casting": {
      "respuestas_puente": [
        "⚓ PLOMADA OFICIAL PARA LANZAMIENTO\n\nEstrictamente para torneos de casting o cuando la única forma de pescar es pasar la segunda rompiente sí o sí.\n\nDetalles técnicos:\n- Pesos recomendados: 115, 125, 150 y 170 gramos (según el reglamento o vara).\n- Funcionamiento: Aerodinámica pura, sin aristas ni enganches. Corta el viento como una bala.\n\nConsejo del Baqueano: No te sirve si hay mucha correntada lateral porque no se agarra a nada. Usala solo cuando el mar está calmo y los peces andan lejísimos."
      ]
    },
    "que_sirve_plomada_redonda_distancia": {
      "respuestas_puente": [
        "⚓ PLOMADA REDONDA PARA DISTANCIA Y ROCA\n\nLogra gran distancia y, curiosamente, zafa bastante bien de las trabas.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 140 gramos.\n- Funcionamiento: Al ser esférica y no tener aristas, no se acuña en las ranuras de las piedras.\n\nConsejo del Baqueano: En el río no la uses si el agua corre, porque va a rodar como pelota y armás un desastre de enredos. Solo para piedra o lagunas quietas."
      ]
    },
    "que_sirve_plomada_ahusada_aerodinamica": {
      "respuestas_puente": [
        "⚓ PLOMADA AHUSADA: EL ESTÁNDAR DE PLAYA\n\nLa más elegida por el pescador deportivo de costa por su balance envidiable.\n\nDetalles técnicos:\n- Pesos recomendados: 120 a 160 gramos.\n- Funcionamiento: Su forma de lágrima estirada o torpedo permite tiros muy largos, venciendo la resistencia del aire.\n\nConsejo del Baqueano: Si estás aprendiendo a lanzar de costa, arrancá con una ahusada de 150g (si tu caña lo banca). Te va a ayudar a ganar metros fácil y corrige errores de vuelo."
      ]
    },
    "cuando_sirve_plomada_lagrima_algas": {
      "respuestas_puente": [
        "⚓ PLOMADA LÁGRIMA PARA FONDOS SUCIOS\n\nSi el agua está llena de algas en suspensión o pasto flotante, esta te salva.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 150 gramos.\n- Funcionamiento: Al recogerla, las algas resbalan por su panza redonda sin tener ganchos donde quedar atoradas.\n\nConsejo del Baqueano: Ni se te ocurra meter una de destrabe si hay mugre en el agua. Vas a traer 5 kilos de ensalada verde en cada tiro y te vas a agotar los brazos."
      ]
    },
    "donde_sirve_plomada_corona_canto_rodado": {
      "respuestas_puente": [
        "⚓ PLOMADA CORONA PARA CANTO RODADO\n\nSi pescás en el sur o en zonas de piedritas redondas donde las grapas no se clavan.\n\nDetalles técnicos:\n- Pesos recomendados: 120 a 160 gramos.\n- Funcionamiento: Tiene un anillo con puntas (corona) que se encastra perfecto entre las piedras redondas.\n\nConsejo del Baqueano: Ojo al lanzarla. Frena mucho en el aire. Tirá con decisión pero sabiendo que no vas a romper récords de distancia."
      ]
    },
    "cuando_sirve_plomada_grapas_temporal": {
      "respuestas_puente": [
        "⚓ PLOMADA DE GRAPAS (BREAKAWAY) PARA TEMPORAL\n\nCuando sopla el vendaval cruzado y el mar es una batidora, sacá las grapas.\n\nDetalles técnicos:\n- Pesos recomendados: 140 a 160 gramos.\n- Funcionamiento: Sus varillas se entierran hondo. Al pegar el tirón para recoger, pivotan y se liberan.\n\nConsejo del Baqueano: Tensá bien la línea apenas toque fondo. Si dejás panza en el nylon, las grapas no trabajan bien y la correntada te desentierra el plomo."
      ]
    },
    "donde_sirve_plomada_bola_barro": {
      "respuestas_puente": [
        "⚓ PLOMO BOLA PARA FONDOS MUY BLANDOS\n\nExcepcional para arrastrar la carnada y levantar nubecitas que llamen la atención.\n\nDetalles técnicos:\n- Pesos recomendados: 40 a 90 gramos.\n- Funcionamiento: Extremadamente hidrodinámico. Rueda y se asienta sin enterrarse profundo en el fango.\n\nConsejo del Baqueano: En las rías o desembocaduras barrosas buscando lenguado, mandá plomo bola, vení traccionando suave y vas a ver cómo el bicho ataca el cebo en movimiento."
      ]
    },
    "que_sirve_plomada_estrella_corriente": {
      "respuestas_puente": [
        "⚓ PLOMADA ESTRELLA PARA CORRIENTES Y ESCALONES\n\nSi la playa tiene chupones o desniveles fuertes, la estrella se traba ahí.\n\nDetalles técnicos:\n- Pesos recomendados: 120 a 150 gramos.\n- Funcionamiento: Sus gruesas puntas macizas se encastran en la pared de arena de la canaleta.\n\nConsejo del Baqueano: A veces tirás lejos y el plomo viene rodando hasta que de golpe se frena. Ahí es donde encontró el escalón. Dejalo trabajar ahí, que es por donde patrulla la corvina."
      ]
    },
    "donde_sirve_plomada_gota_rocas": {
      "respuestas_puente": [
        "⚓ PLOMADA GOTA PARA FONDOS MIXTOS\n\nEs el equilibrio entre lanzar lejos y no dejar el aparejo en las lajas escondidas.\n\nDetalles técnicos:\n- Pesos recomendados: 80 a 120 gramos.\n- Funcionamiento: Concentra el peso abajo pero se afina arriba, lo que ayuda a zafar de enganches no muy duros.\n\nConsejo del Baqueano: Usá esta plomada con cañas que tengan pasahilos grandes para minimizar el roce y un reel frontal rápido, así salís del fondo como trompada."
      ]
    },
    "que_sirve_plomada_arana_rocas": {
      "respuestas_puente": [
        "⚓ PLOMADA ARAÑA PARA ROCA VIVA\n\nMuy popular (tipo Perú) para meterse de cabeza en los peñascales marítimos.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 150 gramos.\n- Funcionamiento: Lleva alambres blandos en forma de \"sombrilla\" hacia arriba. Si se atranca, tirás y el alambre cede y se endereza.\n\nConsejo del Baqueano: No tengas miedo de tirar fuerte. Si el alambre viene torcido, lo enderezás con la mano o pinza, encarnás de nuevo y al agua."
      ]
    },
    "que_sirve_plomada_pera_versatil": {
      "respuestas_puente": [
        "⚓ PLOMADA PERA: LA NAVAJA SUIZA\n\nLa más versátil de todas. Sirve en casi cualquier escenario estándar sin condiciones extremas.\n\nDetalles técnicos:\n- Pesos recomendados: 80 a 130 gramos.\n- Funcionamiento: Clava moderadamente, lanza muy bien y se recupera con poco esfuerzo.\n\nConsejo del Baqueano: Si estás armando tu primera caja de pesca y andás corto de presupuesto, comprate 5 peritas de distintos pesos. Nunca te van a dejar a pata."
      ]
    },
    "que_sirve_plomada_aceituna_deriva": {
      "respuestas_puente": [
        "⚓ PLOMADA ACEITUNA PARA BARRER EL FONDO\n\nSe usa intencionalmente para que la línea camine y cubra más terreno de pesca.\n\nDetalles técnicos:\n- Pesos recomendados: 40 a 80 gramos.\n- Funcionamiento: Totalmente ovalada, rueda sobre fondos parejos de arena o fango.\n\nConsejo del Baqueano: Si el pescado no está acardumado y hay que buscarlo, tirá con aceituna y dejá que la correntada mueva tu línea suavemente por el veril. El pique se siente violento."
      ]
    },
    "cuando_se_usa_plomo_ligero_sin_viento": {
      "respuestas_puente": [
        "⚓ PESO LIGERO (80-100g) SIN VIENTO\n\nCuando no sopla una brisa y el agua es un charco, bajá los pesos para ganar sensibilidad.\n\nDetalles técnicos:\n- Pesos recomendados: 80 a 100 gramos.\n- Funcionamiento: No requiere anclaje fuerte. No asusta al pescado y no sobrecarga la vara inútilmente.\n\nConsejo del Baqueano: Mandar 150 gramos con el mar planchado es un crimen. Achicá todo: tanza fina, plomo liviano y disfrutá de los piques sutiles de la variada menor."
      ]
    },
    "cuando_se_usa_plomo_medio_viento_moderado": {
      "respuestas_puente": [
        "⚓ PESO MEDIO (110-130g) PARA VIENTO NORMAL\n\nEl peso estándar que el 90% de los pescadores usa en la playa a diario.\n\nDetalles técnicos:\n- Pesos recomendados: 110, 120, 130 gramos.\n- Funcionamiento: Vence bien la panza de viento durante el vuelo y mantiene la tensión justa en el nylon.\n\nConsejo del Baqueano: Si ves que la puntera de la caña cabecea mucho de forma floja, es que el plomo está caminando. Ahí subí a 130g y fijate cómo se planta."
      ]
    },
    "cuando_se_usa_plomo_pesado_viento_fuerte": {
      "respuestas_puente": [
        "⚓ PESO MÁXIMO (140-180g) PARA TEMPORAL\n\nCuando el clima te castiga, necesitás peso y anclaje (grapas o destrabe).\n\nDetalles técnicos:\n- Pesos recomendados: 140 a 180 gramos.\n- Funcionamiento: Asegura que la línea se hunda rápido y que el viento o correntada no devuelvan tu aparejo a la orilla.\n\nConsejo del Baqueano: Revisá la inscripción de tu caña. Si dice máximo 150g, no le mandes 180g a lo bruto porque vas a hacer estallar la vara en pedazos en pleno lance."
      ]
    },
    "como_se_prepara_corta_distancia": {
      "respuestas_puente": [
        "⚓ LANZAMIENTO A CORTA DISTANCIA (<50m)\n\nMuchas especies cazan en la primera canaleta, en la espuma.\n\nDetalles técnicos:\n- Pesos recomendados: 80 a 100 gramos.\n- Funcionamiento: Tiro suave, tipo péndulo corto o sobre el hombro. Buscá precisión, no fuerza bruta.\n\nConsejo del Baqueano: Acá no necesitás salida trafilada gruesa. Pescá con nylon del 0.35 directo y un plomo cónico. Dejá el aparejo trabajando atrás del rompiente, ahí está el chucho."
      ]
    },
    "como_se_prepara_media_distancia": {
      "respuestas_puente": [
        "⚓ LANZAMIENTO A MEDIA DISTANCIA (50-90m)\n\nEl tiro habitual para sortear las olas y llegar al banco de arena.\n\nDetalles técnicos:\n- Pesos recomendados: 110 a 120 gramos (aerodinámicos).\n- Funcionamiento: Requiere técnica de lance por encima de la cabeza y cañas de entre 3.90m y 4.20m.\n\nConsejo del Baqueano: Usá siempre un chicote de salida. Un 0.35 a 0.70mm te permite meterle un buen latigazo sin riesgo de que la tanza te corte el dedo."
      ]
    },
    "como_se_prepara_larga_distancia": {
      "respuestas_puente": [
        "⚓ LANZAMIENTO A LARGA DISTANCIA (>90m)\n\nCuando la corvina grande anda lejos, en la segunda canaleta.\n\nDetalles técnicos:\n- Pesos recomendados: 130 a 150 gramos (plomos redondos, gota, ahusados).\n- Funcionamiento: Nailon de base muy fino (0.25 a 0.30mm), salida gruesa, reel rotativo o frontal grande, y uso intensivo de bait clip.\n\nConsejo del Baqueano: Todo el secreto está en afinar el nylon del reel. A menor diámetro, menos roza en los pasahilos y más metros volás. Eso sí, cargá la caña de forma progresiva."
      ]
    },
    "como_se_hace_bait_clip_mar": {
      "respuestas_puente": [
        "⚓ USO DEL BAIT CLIP CON PLOMADA\n\nEl invento mágico para evitar el \"efecto helicóptero\" de la carnada en el aire.\n\nDetalles técnicos:\n- Pesos recomendados: 140 a 150 gramos.\n- Funcionamiento: El anzuelo se traba en un clip junto al plomo. Vuelan como una sola unidad aerodinámica y se destraba al chocar con el agua.\n\nConsejo del Baqueano: Es clave atar muy bien la carnada con hilo de licra. Si la carnada es muy fofa, se rompe al impactar. Y usá plomos con la cabeza recta para que asiente bien."
      ]
    },
    "como_se_prepara_brazolada_mar_calmo": {
      "respuestas_puente": [
        "⚓ BRAZOLADAS PARA MAR PLANCHADO\n\nEl pez tiene mucho tiempo para mirar la carnada y desconfiar.\n\nDetalles técnicos:\n- Pesos recomendados: Plomadas livianas sin anclaje.\n- Funcionamiento: Brazoladas muy largas, de 80 a 90 centímetros de longitud (nylon 0.40 a 0.50mm).\n\nConsejo del Baqueano: Queremos que la carnada flamee suave y natural. Atala prolija y dejá que el metro de brazolada haga el engaño. Si le metés un destrabe grande, el pez huye."
      ]
    },
    "como_se_prepara_brazolada_mar_movido": {
      "respuestas_puente": [
        "⚓ BRAZOLADAS PARA MAR MOVIDO\n\nCuando el agua es una lavadora, la brazolada larga termina hecha un matambre.\n\nDetalles técnicos:\n- Pesos recomendados: 140 a 180 gramos (destrabe o grapas).\n- Funcionamiento: Brazoladas cortas, de 60 centímetros como máximo. Siempre montadas sobre esmerillones.\n\nConsejo del Baqueano: Evitá los rotores plásticos que se parten o no giran con tensión. Mandale buen mosquetón con esmerillón, carnada chica y apretada con licra."
      ]
    },
    "donde_sirve_gancho_arena_fina": {
      "respuestas_puente": [
        "⚓ PLOMADAS DE GANCHO EN ARENA FINA\n\nEl terreno ideal para clavar las estacas de acero.\n\nDetalles técnicos:\n- Pesos recomendados: 140 a 160 gramos.\n- Funcionamiento: En arena suelta casi todos los plomos se deslizan con temporal, excepto los de gancho que se entierran hondo.\n\nConsejo del Baqueano: Ni bien tirás, dejá que hunda y pegale un leve tironcito a la caña para asegurar que los alambres agarren la arena firme. Después, apoyá la caña en el posacañas y esperá."
      ]
    },
    "donde_sirve_plomo_mixto_arena_roca": {
      "respuestas_puente": [
        "⚓ FONDOS MIXTOS (ARENA ENTRE ROCAS)\n\nEl peor dolor de cabeza. Creés que tiraste en arena pero en el fondo hay lajas que se tragan el plomo.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 130 gramos (pera o estrella).\n- Funcionamiento: Evitar ganchos si venís pescando al vuelo o recogiendo seguido, porque el gancho busca la roca y se aferra.\n\nConsejo del Baqueano: Si sabés que hay manchones de piedra, usá un plomo gota y recogé con la puntera de la caña bien arriba. Y si podés, usá fusible."
      ]
    },
    "donde_sirve_plomo_plano_barro": {
      "respuestas_puente": [
        "⚓ PLOMOS PLANOS PARA BARRO Y FANGO\n\nEn las rías o veriles del Paraná profundo, el lodo se chupa los plomos redondos.\n\nDetalles técnicos:\n- Pesos recomendados: 80 a 120 gramos.\n- Funcionamiento: Mayor superficie de apoyo impide que el aparejo se hunda 20 centímetros en el barro oscuro.\n\nConsejo del Baqueano: Un plomo reloj chato acá va genial. Mantiene tus anzuelos a la vista del bagre de mar o la boga, y no tapados de lodo."
      ]
    },
    "que_sirve_plomada_espiral_currican": {
      "respuestas_puente": [
        "⚓ PLOMO ESPIRAL PARA TROLLING / CURRICÁN\n\nPara llevar señuelos a profundidad navegando a motor.\n\nDetalles técnicos:\n- Pesos recomendados: Desde 100 hasta 400 gramos.\n- Funcionamiento: Se colocan en la línea madre y bajan el engaño mientras el barco avanza.\n\nConsejo del Baqueano: Vienen pasantes o tipo clip. Tené varios pesos a mano porque según la velocidad del bote, vas a tener que sumar plomo para que no salga el señuelo a la superficie."
      ]
    },
    "que_sirve_plomo_aletas_lanzado": {
      "respuestas_puente": [
        "⚓ PLOMADA CON ALETAS PARA VUELO PERFECTO\n\nTecnología balística al servicio del pescador deportivo.\n\nDetalles técnicos:\n- Pesos recomendados: 120 a 150 gramos.\n- Funcionamiento: Sus alerones rectifican el vuelo evitando que rote y se frene con el viento.\n\nConsejo del Baqueano: Espectacular para la playa abierta. Esas mismas aletas, al tocar fondo, actúan como pequeñas anclas direccionales que se clavan en la arena."
      ]
    },
    "donde_sirve_destrabe_marchiquita": {
      "respuestas_puente": [
        "⚓ DESTRABE PESADO PARA EL SUDESTE (MAR CHIQUITA)\n\nZonas de mar bravío constante exigen el límite del material.\n\nDetalles técnicos:\n- Pesos recomendados: 160 gramos fijos, con alambres de 1.5 milímetros.\n- Funcionamiento: La rompiente violenta y los planchones de piedra tapados de arena destrozan los destrabes finos.\n\nConsejo del Baqueano: Como explicaba Guille en su video, usá destrabes cojudos. Cuando recojas, tensioná de a poco la caña, sentí que los ganchos se doblan para destrabar y ahí recién dale rápido al reel."
      ]
    },
    "como_se_hace_plomada_casera_tubo": {
      "respuestas_puente": [
        "⚓ PLOMADAS CASERAS (TIPO BUJÍA)\n\nEl ingenio popular para pescar en pedregales donde dejás una fortuna por hora.\n\nDetalles técnicos:\n- Pesos recomendados: Lo que dé el tubo o tuerca (50 a 100g).\n- Funcionamiento: Se usa un trozo de caño, hierro de obra o bujías atadas con alambre.\n\nConsejo del Baqueano: Si estás pescando roca pura y dura (onda sur o escollera marplatense extrema), agarrá tubos viejos, haceles un lacito de nylon y pesquen sin culpa que si se pierde, no duele el bolsillo."
      ]
    },
    "como_se_prepara_esmerillon_mar": {
      "respuestas_puente": [
        "⚓ ESMERILLONES EN LA LÍNEA DE MAR\n\nEl mar no perdona errores de armado; tuerce y retuerce todo sin piedad.\n\nDetalles técnicos:\n- Pesos recomendados: Tolerancia máxima (mosquetones de 40 lbs o más).\n- Funcionamiento: La plomada jamás debe ir atada directo. Se engancha en un mosquetón con esmerillón.\n\nConsejo del Baqueano: Armá todo con esmerillones (hasta las brazoladas). Si podés, metele nudos corredizos para que al clavar la pieza gorda, todo deslice hasta el plomo y lo traigas sin que el pez ande colgando arriba."
      ]
    },
    "como_se_prepara_chicote_salida": {
      "respuestas_puente": [
        "⚓ SALIDA TRAFILADA O CHICOTE\n\nSin esto, revolear 150 gramos te arranca el dedo y perdes el plomo en el aire.\n\nDetalles técnicos:\n- Pesos recomendados: Exigido para plomos de 100 a 180 gramos en surfcasting.\n- Funcionamiento: Se empalma la línea fina del reel (0.25) con un chicote que arranca en 0.35 y termina en 0.70mm.\n\nConsejo del Baqueano: Comprate las salidas que vienen ya recortadas de fábrica (10-15 metros) y hacé un nudo de sangre o barrilito bien pulido para que no raspe en los pasahilos."
      ]
    },
    "como_hago_balance_cana_plomo": {
      "respuestas_puente": [
        "⚓ BALANCE ENTRE CAÑA Y PLOMO\n\nSi le errás acá, ahogás el tiro (tipo manguera) o podés partir la caña al medio.\n\nDetalles técnicos:\n- Pesos recomendados: Respetar la nomenclatura impresa (ej: 100-150g).\n- Funcionamiento: La caña acumula energía en el arqueo y la despide. Un peso muy chico no carga la vara; uno excesivo la vence.\n\nConsejo del Baqueano: Como dice Viciconte, si dice 100g, no le mandes 150. Y recordá que a los gramos del plomo de la caña tenés que sumarle la tremenda resistencia al viento que hace la carnada gruesa."
      ]
    },
    "donde_sirve_muere_viento": {
      "respuestas_puente": [
        "⚓ PESCAR DONDE MUERE EL VIENTO\n\nLa regla de oro sagrada para lagunas, pejerreyes y zonas costeras.\n\nDetalles técnicos:\n- Pesos recomendados: Según equipo (viento en contra exigirá mayor peso o aerodinámica).\n- Funcionamiento: El viento arrastra microorganismos y plancton contra la costa. Atrás viene el forraje y atrás los grandes predadores.\n\nConsejo del Baqueano: Sí, tirar con viento en la cara es molesto, perdés distancia y hace frío. Pero ahí mismo, a 20 metro tuyos, tenés acardumada toda la pesca de la jornada. Bancatela."
      ]
    },
    "cuando_sirve_nylon_viento": {
      "respuestas_puente": [
        "⚓ NYLON VS MULTIFILAMENTO CON VIENTO\n\nEl gran debate. El multi es letal clavando, pero es un barrilete con vendaval.\n\nDetalles técnicos:\n- Pesos recomendados: 130 a 160 gramos para compensar.\n- Funcionamiento: El nylon absorbe agua, se pega más a la superficie y no hace tanta \"panza\" lateral en el aire ni en el agua.\n\nConsejo del Baqueano: Si hay temporal en el mar, guardá la bobina de multifilamento y poné la de nylon. El multi embolsa tanto viento que te saca el plomo destrabe de 160g de la arena."
      ]
    },
    "como_se_hace_afinar_nylon_corriente": {
      "respuestas_puente": [
        "⚓ AFINAR EL NYLON PARA EVITAR CORRENTADAS\n\nEl secreto que pocos saben: si la línea camina, no siempre es falta de plomo.\n\nDetalles técnicos:\n- Pesos recomendados: Mantener 120-150g.\n- Funcionamiento: Un nylon 0.50 opone muchísima más superficie a la corriente de agua que un 0.28mm. Esa presión levanta el plomo.\n\nConsejo del Baqueano: Si ya no podés poner un plomo más pesado porque tu caña no da más, bajá el grosor de la línea principal (usando chicote). El agua la \"corta\" más fácil y el plomo queda estático."
      ]
    },
    "como_se_hace_achicar_carnada_corriente": {
      "respuestas_puente": [
        "⚓ ACHICAR LA CARNADA EN CORRIENTE FUERTE\n\nEl segundo gran secreto cuando te arrastra la correntada lateral.\n\nDetalles técnicos:\n- Pesos recomendados: Mantener el plomo adecuado a la caña.\n- Funcionamiento: Un langostino entero envuelto en anchoa funciona como un paracaídas bajo el agua, recibiendo toda la fuerza de la ola.\n\nConsejo del Baqueano: Si ves que con el plomo de 150g garra igual te corre la línea, agarrá el cuchillo y afiná los filetitos. Carnada chica, aerodinámica, y se soluciona el problema."
      ]
    },
    "que_sirve_plomo_coloreado_concurso": {
      "respuestas_puente": [
        "⚓ PLOMOS DE COLORES Y FOSFORESCENTES\n\nIdeales para torneos o pesca nocturna, no es solo un capricho estético.\n\nDetalles técnicos:\n- Pesos recomendados: 110 a 150 gramos.\n- Funcionamiento: Están plastificados en tonos flúor (rojo, amarillo) o pintados con rotuladores nocturnos.\n\nConsejo del Baqueano: Además de atraer curiosos, a la noche te salvan la vida lanzando con rotativo. Ves el destello cuando toca el agua, frenás la bobina con el pulgar y evitás una galleta infernal."
      ]
    },
    "como_se_hace_anclaje_bote_viento": {
      "respuestas_puente": [
        "⚓ FONDEO DE EMBARCACIÓN CON VIENTO\n\nCómo lograr que el bote sea una plataforma de pesca y no una coctelera.\n\nDetalles técnicos:\n- Pesos recomendados: Anclas fonderas pesadas.\n- Funcionamiento: Uso de dos anclas (una por proa y un muerto o ancla menor por popa).\n\nConsejo del Baqueano: Tirate siempre donde el sol te quede de espaldas (si el viento lo permite) y fondeate firme de costado. Así tus líneas bajan derechas y no se enriedan abajo del bote."
      ]
    },
    "como_se_prepara_garete_laguna": {
      "respuestas_puente": [
        "⚓ PESCA AL GARETE EN LAGUNA (PEJERREY)\n\nDejar que el bote derive suave con el viento para ir peinando el agua.\n\nDetalles técnicos:\n- Pesos recomendados: Ninguno pesado, solo lastres internos o punteros livianos.\n- Funcionamiento: Todo el aparejo de 3 boyas se desliza arrastrado por el bote.\n\nConsejo del Baqueano: La última boya de tu línea (la más alejada) tiene que oficiar de timón. Ponele a esa la brazolada más pesada o profunda para que mantenga toda la línea derechita y tensa."
      ]
    },
    "como_se_prepara_anclado_laguna": {
      "respuestas_puente": [
        "⚓ PESCA ANCLADO EN LAGUNA (PEJERREY)\n\nSi diste con la variada o el cardumen y clavás ancla en el medio del espejo.\n\nDetalles técnicos:\n- Pesos recomendados: Puntero impulsor pesado (30 a 50g) para alejar la línea.\n- Funcionamiento: El viento ahora empuja tu boya lejos de vos.\n\nConsejo del Baqueano: Al revés que al garete, la boya guía (la que vuela primero) tiene que llevar la brazolada más CORTA. Así embolsa bien el viento superficial y te estira el sedal rapidísimo."
      ]
    },
    "cuando_sirve_lluvia_leve": {
      "respuestas_puente": [
        "⚓ PESCAR CON LLUVIA LEVE (Y VIENTO SUAVE)\n\nEl clima ideal que muchos desprecian por comodidad.\n\nDetalles técnicos:\n- Pesos recomendados: Acorde al lugar.\n- Funcionamiento: La gota de lluvia constante rompe la superficie y oxigena enormemente el agua, activando al pescado.\n\nConsejo del Baqueano: Si llueve tranqui y no hay rayos, ponete el piloto y mandate. Esa lluvia lava barrancas y mueve comida. Ahora, si hay temporal y rayos, rajá de ahí con la caña de carbono porque te transformás en pararrayos."
      ]
    },
    "como_se_prepara_mosca_viento": {
      "respuestas_puente": [
        "⚓ FLY CASTING CON VIENTO EN CONTRA\n\nLa pesadilla del mosquero buscando truchas en el sur.\n\nDetalles técnicos:\n- Pesos recomendados: Lastres pesados en la mosca.\n- Funcionamiento: Requiere línea de perfil más fino para cortar el aire denso.\n\nConsejo del Baqueano: Afina tu running line, achicá un poco el volumen de la mosca pero agregale peso (ojos de plomo o tungsteno) y acomodá el cuerpo para que el viento no te clave el anzuelo en la nuca."
      ]
    },
    "que_sirve_plomada_lapicera_piedra": {
      "respuestas_puente": [
        "⚓ PLOMADA LAPICERA PARA PIEDRA Y CORRIENTE\n\nUna variante flaquita y audaz para fondos traicioneros de piedra bocha.\n\nDetalles técnicos:\n- Pesos recomendados: 60 a 100 gramos.\n- Funcionamiento: Es una varilla de plomo alargada que lleva un gancho. \n\nConsejo del Baqueano: Se usa donde corre el agua pero abajo hay piedras. Como es flaquita, suele escabullirse por entre las grietas al recoger en lugar de atascarse de plano."
      ]
    },
    "donde_sirve_plomada_triangular_mar": {
      "respuestas_puente": [
        "⚓ PLOMADA TRIANGULAR PARA COSTA DE MAR\n\nLa hermana menor de la versión de pozón, excelente para playas de arena.\n\nDetalles técnicos:\n- Pesos recomendados: 100 a 150 gramos.\n- Funcionamiento: Para corrientes que no llegan a requerir destrabe pero donde la pera rueda demasiado.\n\nConsejo del Baqueano: Se asienta bárbara. Con corrientes medias a moderadas anda bárbaro."
      ]
    },
    "que_sirve_plomada_voladora_pasante": {
      "respuestas_puente": [
        "⚓ VOLADORA PASANTE MULTIFUNCIÓN\n\nCombina el efecto anti-enganche de la voladora con la sutileza de la pasante.\n\nDetalles técnicos:\n- Pesos recomendados: 70 a 110 gramos.\n- Funcionamiento: Sube rápido a superficie al traccionar, pero deja correr el hilo si pica una boga.\n\nConsejo del Baqueano: Espectacular para pescar en ríos pedregosos (como en Concordia). Tirás, el dorado o boga la toma sin sentir peso, y cuando recogés venís surfeando las piedras."
      ]
    },
    "como_se_prepara_pasante_paternoster": {
      "respuestas_puente": [
        "⚓ ARMADO TUBULAR PASANTE EN PATERNÓSTER\n\nClave para que las brazoladas pejerreyeras no se amontonen.\n\nDetalles técnicos:\n- Pesos recomendados: 10 a 30 gramos.\n- Funcionamiento: El nylon madre se enhebra por la plomada. Se asegura entre perlitas y nudos corredizos.\n\nConsejo del Baqueano: Dejá un jueguito de un centímetro. Cuando el pejerrey tome el anzuelo más profundo, el nudo se va a delezar libre y la boyita marca el pique sin que el bicho suelte la carnada."
      ]
    },
    "que_sirve_plomada_agarraderas_costa": {
      "respuestas_puente": [
        "⚓ PLOMADA CON AGARRADERAS (TIPO ARAÑA/DESTRABE)\n\nEl anclaje puro para lances de playa.\n\nDetalles técnicos:\n- Pesos recomendados: 140 a 180 gramos.\n- Funcionamiento: Se fijan en la arena. Su forma base suele ser aerodinámica para lograr grandes vuelos antes de enterrarse.\n\nConsejo del Baqueano: Mismo principio que el destrabe. Cuidado si hay mucha gente pescando y tenés que cruzarte, porque estas no sueltan fácil hasta que clavas la caña."
      ]
    },
    "como_se_hace_fusible_alambre": {
      "respuestas_puente": [
        "⚓ FUSIBLE CASERO DE ALAMBRE\n\nOtra variante popular, mencionada por Wilmar Merino, para salvar tu aparejo de mar.\n\nDetalles técnicos:\n- Pesos recomendados: Plomadas genéricas o redondas de 120-150g.\n- Funcionamiento: Se fabrica un pequeño gancho de alambre blando. Engancha el mosquetón y luego se vincula con un sedal del 0.30mm.\n\nConsejo del Baqueano: Al aguantar el tiro, el ganchito libera la tensión. Cuando cae al agua queda agarrado del hilo fino. Así, lanzás con seguridad de 0.70mm y si trabás, cortás 0.30mm."
      ]
    },
    "que_sirve_plomada_pasante_surubi": {
      "respuestas_puente": [
        "⚓ PLOMADAS PASANTES PARA EL SURUBÍ\n\nEl cachorro es cazador de fondo y no le gusta que la carnada (morena) esté trabada con un cascote fijo.\n\nDetalles técnicos:\n- Pesos recomendados: 60 a 120 gramos (corredizos en la madre).\n- Funcionamiento: Mantiene la línea en el cauce pero le permite a la morena desplazarse unos metros de forma natural.\n\nConsejo del Baqueano: En pescas específicas de peces bentónicos (de fondo), un plomo corredizo siempre te va a dar la ventaja. Clavan más confiados."
      ]
    },
    "cuando_sirve_plomo_115g_playa": {
      "respuestas_puente": [
        "⚓ PLOMOS LIGEROS-MEDIOS (115g) EN PLAYA\n\nEl gramaje de inicio de casi todas las cañas de costa.\n\nDetalles técnicos:\n- Pesos recomendados: 115 gramos (medida oficial y de pesca).\n- Funcionamiento: Permite cargado rápido de varas livianas y excelentes distancias.\n\nConsejo del Baqueano: Si el mar te lo permite, pescá liviano. Tirar 115 gramos toda la noche cansa infinitamente menos que tirar 150. Tus hombros lo van a agradecer."
      ]
    },
    "cuando_sirve_plomo_150g_ideal": {
      "respuestas_puente": [
        "⚓ EL PESO IDEAL: 150 GRAMOS\n\nEl \"sweet spot\" o punto dulce de la pesca de costa atlántica.\n\nDetalles técnicos:\n- Pesos recomendados: 150 gramos exactos.\n- Funcionamiento: Las mejores distancias y tensión en mar abierto se logran acá. Las cañas estándar (ej. 115-170g) trabajan a la perfección.\n\nConsejo del Baqueano: Si querés practicar a larga distancia (más de 100m) o no sabés qué comprar, llevate ahusadas y destrabes de 150g. Es la medida mágica para nuestras playas."
      ]
    },
    "cuando_sirve_plomo_170g_max": {
      "respuestas_puente": [
        "⚓ LÍMITE DE POTENCIA (170-180g)\n\nEl límite absoluto de la mayoría de las varas de tres tramos convencionales.\n\nDetalles técnicos:\n- Pesos recomendados: 170 o 180 gramos (destrabe puro).\n- Funcionamiento: Se usa únicamente para contrarrestar fuerza de marea brutal.\n\nConsejo del Baqueano: Cuando usés este ladrillo, tu tiro tiene que ser una caricia progresiva. No le pegues el latigazo rabioso que le das al de 115g porque te quedás con tres varitas de un metro en las manos."
      ]
    },
    "como_se_hace_anclaje_proa_popa": {
      "respuestas_puente": [
        "⚓ ANCLAJE CRUZADO EMBARCADO\n\nPara que la laguna o el mar no te giren como calesita.\n\nDetalles técnicos:\n- Pesos recomendados: Anclas fonderas según la eslora del bote.\n- Funcionamiento: Bajar la de proa, dejar correr cadena y soga. Bajar la de popa (muerto) y tensar.\n\nConsejo del Baqueano: Esto te permite pescar cruzado de forma súper cómoda. Eso sí, armalo con ojo. Si viene un lanchón y te hace ola de costado, el bote rígido te puede dar un buen susto."
      ]
    },
    "como_hago_lectura_agua_corriente": {
      "respuestas_puente": [
        "⚓ LECTURA DE CORRIENTES Y CORREDERAS\n\nEl agua habla, chamigo. Y si la sabés leer, pescás.\n\nDetalles técnicos:\n- Pesos recomendados: Adaptar a la velocidad observada.\n- Funcionamiento: La presión del agua genera turbulencia detrás de obstáculos (piedras). Ahí hay oxigenación y predadores.\n\nConsejo del Baqueano: Mirá la superficie. Donde veas que el agua hace un remolino o rizado distinto, ahí hay un desnivel o una corredera. Tirale el plomo ahí mismo y preparate para el pique."
      ]
    },
    "como_hago_lectura_color_agua": {
      "respuestas_puente": [
        "⚓ LECTURA DEL COLOR DEL AGUA Y PROFUNDIDAD\n\nSaber dónde están los bancos y las canaletas antes de lanzar.\n\nDetalles técnicos:\n- Pesos recomendados: Plomos de lanzamiento según la distancia a la canaleta elegida.\n- Funcionamiento: El agua marrón es arena en suspensión (poca agua o rompiente). El agua verde oscura o azulada denota profundidad.\n\nConsejo del Baqueano: Siempre apuntale al agua verde o a la franja oscura que está atrás de las olas blancas. Ahí está el pez. Y ojo con pescar el chucho; anda cerquita, en el agua más revuelta."
      ]
    },
    "como_se_hace_evitar_cruces_parana": {
      "respuestas_puente": [
        "⚓ CORTESÍA Y TIROS EN EL PARANÁ\n\nUn consejo de convivencia de Miguel Araya: no cruzar líneas.\n\nDetalles técnicos:\n- Pesos recomendados: Plomos ancla (pata de araña) de +120g.\n- Funcionamiento: Al usar redondas en correntada (Rosario, San Lorenzo), la plomada viaja 50 metros lateralmente.\n\nConsejo del Baqueano: No seas mala leche. Si usás redonda, barres a los 4 tipos que tenés al lado. Usá pata de araña, tirá levemente en contra de la corriente y mantenete en tu franja de pesca."
      ]
    },
    "que_sirve_plomada_esferica_plano": {
      "respuestas_puente": [
        "⚓ PLOMADA ESFÉRICA DE DESLIZAMIENTO\n\nPara fondos planos de arena sin corriente.\n\nDetalles técnicos:\n- Pesos recomendados: 60 a 100 gramos.\n- Funcionamiento: Al ser deslizante, la línea corre por el medio, pero su forma la hace rodar lateralmente si hay flujo de agua.\n\nConsejo del Baqueano: Hermosa para sondear y sentir la llevada del pescado, pero si vas a zona rocosa, olvidate, entra justito como bola de metegol en los huecos de la piedra."
      ]
    },
    "que_sirve_plomada_tubular_economica": {
      "respuestas_puente": [
        "⚓ PLOMADA TUBULAR (ECONÓMICA Y BÁSICA)\n\nEl plomito barato para salir del paso.\n\nDetalles técnicos:\n- Pesos recomendados: De 20 a 80 gramos.\n- Funcionamiento: Cilíndrica y pasante. Muy usada en ríos calmos o canales.\n\nConsejo del Baqueano: Es la plomada más gasolera. Cumple su función pero los atascos son re comunes porque se clava de punta. Llevate un puñado porque vas a dejar varias."
      ]
    },
    "que_sirve_plomada_fija_argolla": {
      "respuestas_puente": [
        "⚓ PLOMADAS FIJAS CON ARGOLLA\n\nEl formato de anclaje tradicional al final de la madre.\n\nDetalles técnicos:\n- Pesos recomendados: Todos los rangos.\n- Funcionamiento: Se atan (o mosquetonean) al final de la línea. Los anzuelos van arriba en brazoladas.\n\nConsejo del Baqueano: Asegurate que la argolla sea gruesa (preferible de bronce incrustado). Si la argolla es finita o de cobre berreta, el peso del plomo (150g) en el lance te la corta como manteca."
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
