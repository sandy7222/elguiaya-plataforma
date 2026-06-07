import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, dynamic>> data = {
    "como_se_hace_linea_dorado_parana": {
      "respuestas_puente": [
        "🎣 CÓMO ARMAR LA LÍNEA CON BOYAS EN EL PARANÁ\n\nPara pescar a flote en las correntadas del Paraná (buscando doradillos, surubíes o bogas), necesitás una línea simple pero reforzada.\n\nPreparación paso a paso:\n1. Usá una madre de nylon del 0.50 o 0.60 para aguantar los roces.\n2. Colocá una boya grande (tipo doble cono o chupetona de buen volumen) como boya guía, sujetada con nudos corredizos para regular la profundidad.\n3. Añadí un plomito pasante liviano (10 a 20g) antes del líder para que la carnada baje rápido y no quede flameando en la superficie.\n4. Terminá con un líder de acero de 20 a 40 lb y un buen anzuelo forjado.\n\nConsejo del Baqueano: El Paraná tiene mucha correntada. Si la boya es muy chica, el peso de la carnada viva (morena) o la misma fuerza del agua la van a hundir. Usá boyas de buen flote y colores bien visibles como el naranja o amarillo flúor."
      ],
      "tipos": [
        "Boya Doble Cono de poliuretano expandido",
        "Boya Chupetona grande",
        "Boya Plana o zanahoria (para correntada fuerte)"
      ]
    },
    "que_sirve_nudo_corredizo_dorado": {
      "respuestas_puente": [
        "🎣 NUDO CORREDIZO PARA BOYAS DE RÍO\n\nEl nudo corredizo (o lazo corredizo) es fundamental para poder regular a qué profundidad trabaja la carnada sin tener que cortar la línea madre.\n\nPreparación:\n1. Usá hilo de polietileno o multifilamento para atar el nudo corredizo sobre la madre de nylon.\n2. Colocá perlitas antes y después de la boya para que el nudo no se meta en el ojal de la misma.\n\nConsejo del Baqueano: Nunca aprietes de más el nudo sin mojarlo antes. Si quemás el nylon de la madre moviendo el nudo en seco, cuando clave un dorado grande, se te va a cortar por ahí mismo."
      ]
    },
    "como_se_prepara_union_multi_boya": {
      "respuestas_puente": [
        "🎣 UNIÓN DE MULTIFILAMENTO CON BOYA DE TERGOPOL\n\nCuando pescás dorados con multifilamento directo como madre, este hilo puede cortar o quemar las boyas blandas por la fricción.\n\nArmado paso a paso:\n1. Hacé un pequeño tramo de tanza gruesa (0.50 o 0.60) antes de la boya.\n2. Uní el multifilamento a la tanza con un nudo de sangre o barrilito.\n3. Fijá la boya en la porción de tanza.\n\nConsejo del Baqueano: El multifilamento es un serrucho para el tergopol. Si le hacés un nudito tope en la tanza para que el multi no resbale, salvás la boya y mantenés la regulación exacta de la profundidad."
      ]
    },
    "donde_sirve_boya_parana_remanso": {
      "respuestas_puente": [
        "🎣 BOYAS EN LOS REMANSOS DEL PARANÁ\n\nLos remansos son zonas donde la corriente pega en la costa y gira, creando un embudo ideal donde cazan los grandes predadores.\n\nUso táctico:\n1. Lanzá la línea de flote justo donde se une el agua rápida con el remanso.\n2. Dejá que la boya derive naturalmente copiando el giro del agua.\n3. Ajustá la profundidad a 80 cm aprox.\n\nConsejo del Baqueano: En el remanso, el dorado espera a las mojarras desorientadas. Mantené la línea tensa porque el pique suele ser de un tirón explosivo que hunde la boya de golpe."
      ]
    },
    "que_sirve_plomito_antes_lider": {
      "respuestas_puente": [
        "🎣 PLOMITO LASTRE PARA FLOTE\n\nEs un pequeño peso pasante o de pellizco que se coloca justo arriba del rotor o del líder de acero.\n\nFunción:\n1. Vence la fuerza de flotación de la correntada.\n2. Hace que la carnada (maíz, corazón o morena) baje vertical a la profundidad que dicta la boya.\n\nConsejo del Baqueano: Si pescás dorados y no ponés un plomito de 10 a 20 gramos, el mismo empuje del agua del Paraná te levanta la carnada y la deja flameando en la superficie. Así no pescás nada."
      ]
    },
    "como_hago_profundidad_dorado_parana": {
      "respuestas_puente": [
        "🎣 CALIBRAR PROFUNDIDAD PARA EL DORADO\n\nEl dorado suele cazar a media agua o cerca de las correderas, mirando siempre hacia arriba.\n\nAjuste:\n1. Movés el nudo corredizo superior de la boya.\n2. Medí desde la boya hasta el anzuelo.\n3. Lo ideal estándar en el río son unos 80 centímetros.\n\nConsejo del Baqueano: Si ves que los doradillos saltan cazando mojarras, subí la boya a 40 cm. Si no hay actividad visible, bajala a un metro. ¡Pero los 80 cm son el número mágico del Litoral!"
      ]
    },
    "que_sirve_boya_tergopol_dorado": {
      "respuestas_puente": [
        "🎣 BOYA DE TERGOPOL EN EL RÍO\n\nLas boyas de tergopol (poliestireno expandido) son grandes, rústicas y muy flotadoras.\n\nVentajas:\n1. Soportan carnadas grandes sin hundirse.\n2. Son económicas si las perdés en las ramas o palos del río.\n\nConsejo del Baqueano: A veces enganchás troncos sumergidos o tapias. Con una boya barata de tergopol y madre de piolín, si tenés que tironear y cortar, no te duele el bolsillo como perder una boya de madera balsa torneada."
      ],
      "tipos": [
        "Zanahoria de tergopol",
        "Chupetona de tergopol"
      ]
    },
    "cuando_sirve_linea_flote_boga": {
      "respuestas_puente": [
        "🎣 LÍNEA DE FLOTE LIVIANA (BOGA/PIRÁ PITÁ)\n\nNo todo es equipo pesado en el río; para variada fina a flote se achican los tamaños.\n\nArmado:\n1. Boya pequeña o paternóster.\n2. Líder de nylon grueso o fluorocarbono fino (no acero grueso).\n3. Anzuelo chico tipo maruseigo.\n\nConsejo del Baqueano: Si el dorado no quiere comer y hay boga o pirá pitá, armá un equipo bien livianito con una boya sutil. Sentir la llevada suave de una boga en caña ligera es un lujo."
      ]
    },
    "como_se_prepara_madre_dorado": {
      "respuestas_puente": [
        "🎣 MADRE ROBUSTA PARA LÍNEA DE RÍO\n\nLa madre es la línea principal del aparejo donde corre la boya.\n\nArmado:\n1. Usá nylon de diámetro entre 0.50 mm y 0.80 mm.\n2. Realizá lazos fuertes en los extremos (nudo en 8) para atar mosquetones.\n\nConsejo del Baqueano: En el norte hay palos, raigones y piedras. Una madre fina te la corta un dorado al primer roce. Armá las líneas como para sacar un tronco, el río no perdona."
      ]
    },
    "como_hago_evitar_corte_parana": {
      "respuestas_puente": [
        "🎣 EVITAR CORTES EN PESCA DE FLOTE AL DORADO\n\nLos dientes del dorado cortan cualquier nylon monofilamento al instante.\n\nAcciones:\n1. Colocá siempre un líder de acero termocontraíble de 20 a 40 lb al final de la línea.\n2. Asegurá los destorcedores y rotores con nudos corredizos bien ceñidos.\n\nConsejo del Baqueano: Usá esmerillones de buena calidad. Muchos arman bien la boya y el líder, pero ponen un ganchito/mosquetón ordinario que el dorado abre en la primera llevada. ¡Todo tiene que ser robusto!"
      ]
    },
    "que_sirve_boya_yoyo_pejerrey": {
      "respuestas_puente": [
        "🎣 LA BOYA YO-YO PARA PEJERREY\n\nLa boya Yo-Yo es una boya circular que cuenta con una canaleta central. \n\nUtilidad y armado:\n1. Se pasa la tanza por su centro.\n2. Permite enrollar la brazolada sobre sí misma para cambiar la profundidad velozmente.\n\nConsejo del Baqueano: En las lagunas bonaerenses, el peje te cambia de profundidad a cada rato por el calor o el viento. La Yo-Yo te salva de cambiar toda la línea; enrollás un par de vueltas y pasás de pescar de 50 cm a 10 cm en segundos."
      ],
      "tipos": [
        "Boya Yo-Yo esférica grande",
        "Boya Yo-Yo chica (para brisa)"
      ]
    },
    "cuando_sirve_boya_oscura_pejerrey": {
      "respuestas_puente": [
        "🎣 BOYAS OSCURAS CON SOL DE FRENTE\n\nEl contraste de las boyas cambia totalmente dependiendo de dónde pegue la luz solar en el agua.\n\nUso correcto:\n1. Colocá boyas de tonos oscuros cuando navegues o pesques apuntando hacia donde nace o se pone el sol.\n2. Optá por acabados mate para evitar los destellos.\n\nConsejo del Baqueano: Si tenés el sol pegándote en la cara, el agua parece un espejo blanco. Si tirás boyas blancas o amarillas, vas a quedar ciego. Una boya negra mate o fucsia oscura resalta perfecto contra el brillo."
      ],
      "tipos": [
        "Negra mate",
        "Naranja fuerte oscura",
        "Roja mate"
      ]
    },
    "cuando_sirve_boya_clara_pejerrey": {
      "respuestas_puente": [
        "🎣 BOYAS CLARAS CON SOL DE ESPALDAS\n\nSi el sol ilumina el agua desde atrás del pescador, el fondo del río o laguna se ve más oscuro.\n\nUso correcto:\n1. Usá boyas claras y brillantes que reflejen la luz.\n2. Observalas a la distancia, vas a notar cómo \"explotan\" visualmente.\n\nConsejo del Baqueano: Con el sol dándote en la nuca, el agua se pone azul o negra. Tirale una boya verde limón, amarilla o blanca brillante y la vas a ver desde 100 metros como si tuviera luz propia."
      ],
      "tipos": [
        "Blanca laca",
        "Amarilla brillante",
        "Verde limón"
      ]
    },
    "que_sirve_boya_fucsia_pejerrey": {
      "respuestas_puente": [
        "🎣 BOYA FUCSIA PARA DÍAS NUBLADOS\n\nEl clima nublado genera una iluminación difusa y grisácea sobre el espejo de agua que aplasta los colores tradicionales.\n\nUso:\n1. Cambiá el aparejo a boyas de tonos flúor combinados, destacándose el fucsia o el amarillo potente.\n\nConsejo del Baqueano: Cuando el cielo se pone panza de burro y no hay sol directo, el blanco y el negro se pierden en el gris del agua. Un palito fucsia resalta hermoso y te avisa hasta el toque más sutil del matungo."
      ]
    },
    "como_se_hace_linea_tres_boyas": {
      "respuestas_puente": [
        "🎣 ARMADO DE LÍNEA DE 3 BOYAS\n\nEs la línea reina para la pesca del pejerrey de flote, permitiendo presentar tres carnadas escalonadas.\n\nArmado:\n1. Tomá un nylon de unos 3.5 a 4 metros.\n2. Colocá tres boyas separadas entre sí por al menos 1 a 1.20 metros.\n3. Trabá cada boya con nudos corredizos y colocá rotores para atar las brazoladas.\n\nConsejo del Baqueano: ¡Ojo con hacerlas cortitas! Si dejas menos de un metro entre boyas, cuando haya un poco de oleaje en la laguna, las boyas van a empezar a 'saltar' juntas y el pejerrey, que es desconfiado, te va a escupir la carnada."
      ]
    },
    "como_se_prepara_linea_garete": {
      "respuestas_puente": [
        "🎣 LÍNEA PREPARADA PARA GARETEAR\n\nEl garete es pescar a la deriva desde una embarcación, arrastrados por el viento, dejando que las boyas se alejen solas.\n\nAjuste técnico:\n1. La última boya (la más alejada del pescador) debe oficiar de guía.\n2. Colocale a esta boya la brazolada más larga y amplia para anclar sutilmente la línea y que trabaje derecha.\n\nConsejo del Baqueano: Si vas navegando sueltito con el bote, dejá el pick-up del reel abierto. La última boya te alinea todo el aparejo si la brazolada es larga. Si no, se te cruzan todas las boyas y hacés una enzalada."
      ]
    },
    "como_se_prepara_linea_anclado": {
      "respuestas_puente": [
        "🎣 LÍNEA PREPARADA PARA PESCAR ANCLADO\n\nSi tiramos el ancla, la dinámica del viento y la corriente sobre la línea cambia por completo frente al garete.\n\nAjuste técnico:\n1. La boya guía (la más alejada) debe llevar la brazolada más CORTA.\n2. Esto permite que trabaje más libre, embolse el viento y aleje el aparejo de la lancha.\n\nConsejo del Baqueano: Cuando estás fijo en un punto, querés que el viento te estire la línea lejos para no espantar al cardumen. Con la última brazolada corta, la boya no se frena y 'viaja' mejor por el agua."
      ]
    },
    "que_sirve_puntero_impulsor": {
      "respuestas_puente": [
        "🎣 EL PUNTERO CARGADOR / IMPULSOR\n\nEs una boya adicional con peso propio que se coloca al final de la línea de tres boyas.\n\nArmado y función:\n1. Atalo en el mosquetón del final de la madre.\n2. Usa punteros circulares si querés que la línea se alinee mejor.\n\nConsejo del Baqueano: Si el viento te da en la cara y no podés tirar la línea lejos del bote o de la costa, el puntero impulsor es tu salvavidas. Le da masa al tiro y mantiene la línea tirante. ¡Recordá que por ley solo podés tener 3 anzuelos en total!"
      ]
    },
    "donde_sirve_boya_mandale": {
      "respuestas_puente": [
        "🎣 LA BOYA MANDALE PARA MUELLES\n\nLa Mandale es un aparejo inventado específicamente para los muelles del Río de la Plata.\n\nCaracterísticas:\n1. Es un sistema anclado que sujeta la línea de flote convencional.\n2. Tiene un plomo en un extremo para fijarse al fondo y contrarrestar la fuerte correntada transversal.\n\nConsejo del Baqueano: En muelles largos, la corriente te lleva las boyas cruzadas y molestás al pescador de al lado. Tirás el ancla de la Mandale y tu línea queda flameando paralela al muelle, pescando a flote pero atada al fondo. ¡Una genialidad porteña!"
      ]
    },
    "que_sirve_boya_palito": {
      "respuestas_puente": [
        "🎣 BOYA TIPO PALITO\n\nLas boyas palito son flotadores cilíndricos largos y delgados.\n\nUso:\n1. Ideales para aguas muy tranquilas.\n2. Al detectar un pique de abajo hacia arriba, se \"acuestan\" o se paran sacando medio cuerpo del agua.\n\nConsejo del Baqueano: Si la laguna parece un aceite (planchada), la boya palito es mortífera. Cualquier peje que chupe la carnada, te para el palito al instante y lo ves cantado. Pero si hay viento, olvidate, salta como un sapo."
      ]
    },
    "que_sirve_boya_doble_palito": {
      "respuestas_puente": [
        "🎣 BOYA DOBLE PALITO PARA MAREJADA\n\nEste formato tiene palitos simétricos en ambos extremos del bulbo central.\n\nUso:\n1. Se implementa en lagunas o ríos abiertos cuando hay muchas olas (marejada).\n2. El diseño equilibrado le da mejor \"tenida\" y agarre en el pelo del agua.\n\nConsejo del Baqueano: Cuando el Río de la Plata o la laguna se pican en serio, el doble palito no se te escapa de la vista. Se amarra bien al agua y cuando hay pique, se clava de cabeza o se para recto marcando el cañazo."
      ]
    },
    "que_sirve_boya_lagrima": {
      "respuestas_puente": [
        "🎣 BOYA FORMATO LÁGRIMA\n\nSu forma es redondeada abajo y afinada arriba, imitando una gota.\n\nUtilidad:\n1. Se usa en zonas con oleaje medio a moderado.\n2. Su morfología le permite \"copiar\" perfectamente la forma de la ola sin frenar a la línea.\n\nConsejo del Baqueano: La lágrima es el comodín de la laguna. Acompaña el vaivén del agua sin generar resistencia anormal. Si la boya no salta, el pejerrey come mucho más confiado."
      ]
    },
    "que_sirve_boya_chupetona": {
      "respuestas_puente": [
        "🎣 BOYA CHUPETONA / CHUPETE\n\nTienen una cabeza voluminosa plana y se afinan hacia la cola.\n\nUtilidad:\n1. Brindan volumen sobre la superficie, ideales para ver de muy lejos.\n2. Su diseño hace que se bamboleen mucho con el oleaje, lo que le da \"vida\" a la carnada.\n\nConsejo del Baqueano: La chupetona hace bailar a la mojarra allá abajo y eso vuelve loco al pejerrey grandote. Eso sí, si el viento arranca fuerte, te las arrastra mucho porque ofrecen demasiada resistencia."
      ]
    },
    "que_sirve_boya_esferica": {
      "respuestas_puente": [
        "🎣 BOYA ESFÉRICA O REDONDA\n\nModelos como el ping-pong o esferas lisas.\n\nComportamiento:\n1. Muy estables en corrientes pesadas.\n2. Ante el pique, en lugar de pararse, suelen desplazarse lateralmente sobre la superficie.\n\nConsejo del Baqueano: Con las redondas tenés que tener ojo de lince. No vas a ver que se acuestan; tenés que notar que una de las boyas rompe la fila india y arranca en diagonal. Ahí nomás pegale el cañazo."
      ]
    },
    "que_sirve_boya_cometa": {
      "respuestas_puente": [
        "🎣 BOYA COMETA\n\nFlotador asimétrico que consta de un cono corto de un lado y un cono largo del otro.\n\nVentaja técnica:\n1. Navega muy bien cruzando el viento.\n2. Se puede armar de forma invertida dependiendo si querés que el pique hunda la boya o la pare.\n\nConsejo del Baqueano: Es la boya todoterreno de los concursos. Corta bien el agua y su forma aerodinámica vuela espectacular en los lances largos."
      ]
    },
    "como_se_prepara_brazolada_cometa": {
      "respuestas_puente": [
        "🎣 ARMADO DEL ROTOR EN LA BOYA COMETA\n\nLa dirección de los conos determina cómo acusará el pique.\n\nArmado:\n1. Pescador experto: Pone el rotor del lado del cono MÁS CORTO, apuntando hacia el puntero. Así el pique se desplaza y no hunde la boya ofreciendo menos resistencia.\n2. Pescador novato: Pone el cono LARGO del lado del puntero, para que la boya se pare y marque el pique obvio.\n\nConsejo del Baqueano: Armala del lado corto si estás en un torneo. El peje no siente que tira de nada y traga tranquilo. La llevada es suave pero letal."
      ]
    },
    "cuando_sirve_boya_chica_pejerrey": {
      "respuestas_puente": [
        "🎣 BOYAS CHICAS PARA MUCHO VIENTO\n\nEl exceso de viento arruina las jornadas si la línea deriva demasiado rápido.\n\nTáctica:\n1. Cambiá rápidamente a una línea de tres boyas bien pequeñas (o un paternóster chico).\n2. El menor volumen evitará que el viento las use de vela.\n\nConsejo del Baqueano: Si hay ventarrón y usás boyas grandes, te sacan las carnadas de la profundidad que mediste y las levantan casi a la superficie. Achicá el boyerío para que navegue clavado al agua."
      ]
    },
    "que_sirve_boya_madera_balsa": {
      "respuestas_puente": [
        "🎣 BOYA DE MADERA BALSA\n\nEl material clásico por excelencia, reemplazado hoy por el plástico pero muy amado por los puristas.\n\nVentajas:\n1. Flotabilidad inigualable y extrema sensibilidad.\n2. Son muy livianas en relación a su volumen.\n\nConsejo del Baqueano: No hay con qué darle a la madera balsa cuando pescás de garete. El pez, por más arisco que esté, no nota la resistencia del material y lleva confiado. Cuidalas que valen oro."
      ]
    },
    "que_sirve_boya_plastico": {
      "respuestas_puente": [
        "🎣 BOYA DE PLÁSTICO INYECTADO\n\nEl material más común y resistente en la actualidad.\n\nVentajas:\n1. Soportan golpes contra botes, cañas y piedras.\n2. Son muy livianas y responden perfecto ante brisas suaves.\n\nConsejo del Baqueano: Si vas a pescar anclado y no vuela una mosca (poco viento), meté boyas plásticas. Cualquier brisita las empuja lindo y te aleja el aparejo del bote para poder pescar."
      ]
    },
    "como_hago_ver_boya_lejos": {
      "respuestas_puente": [
        "🎣 TÁCTICAS PARA VISUALIZAR BOYAS LEJANAS\n\nEn el Río de la Plata a veces se pesca tan lejos que las boyas se pierden en el horizonte.\n\nTácticas:\n1. Usar siempre anteojos polarizados para matar el reflejo del agua.\n2. Aumentar el tamaño de la boya (ej: tipo chupetona grande).\n3. Pescar \"con el dedo\" sintiendo la tensión de la línea si no se ve.\n\nConsejo del Baqueano: Si no dominás las boyas con la vista, perdés el 90% de los piques. Invertí en unos buenos lentes polarizados; son tan importantes como el reel o la caña."
      ]
    },
    "cuando_sirve_multifilamento_pejerrey": {
      "respuestas_puente": [
        "🎣 MULTIFILAMENTO PARA PEJERREY\n\nEl multifilamento es un trenzado de fibras sin elasticidad.\n\nUso ideal:\n1. Días de poco viento.\n2. Lances muy largos o de embarcado.\n3. Flota naturalmente, evitando que se haga comba bajo el agua.\n\nConsejo del Baqueano: Como no estira nada, el cañazo es directo a la boca del pejerrey. Pero ojo, si hay viento cruzado, vuela mucho y te hace una 'panza' en el aire que te enreda todo."
      ]
    },
    "cuando_sirve_nylon_madre_pejerrey": {
      "respuestas_puente": [
        "🎣 NYLON MONOFILAMENTO EN LA MADRE\n\nEl clásico tanza de nylon sigue siendo útil bajo condiciones climáticas bravas.\n\nUso ideal:\n1. Días de muchísimo viento.\n2. Se pega mejor al agua y vuela menos que el multifilamento.\n3. No se desplaza tanto de costado ni forma panzas en el aire.\n\nConsejo del Baqueano: Si Eolo está soplando con furia, olvidate del multi. Pasate al buen nylon viejo. Se acuesta sobre el agua y te deja clavar sin tener 20 metros de comba."
      ]
    },
    "como_hago_flotar_nylon_pejerrey": {
      "respuestas_puente": [
        "🎣 MANTENER EL NYLON A FLOTE\n\nEl problema del monofilamento es que, a diferencia del multifilamento, tiende a hundirse con el rato.\n\nAplicación:\n1. Secar bien el tramo de nylon del reel.\n2. Aplicar un \"flota líneas\" (en pasta o aerosol) sobre los metros que estarán en el agua.\n\nConsejo del Baqueano: Si la tanza se te hunde, forma una panza o 'guata' submarina. Cuando el pejerrey pica y pegás el cañazo, primero tenés que levantar toda esa agua y llegás re tarde a la clavada. ¡Pastita siempre!"
      ]
    },
    "que_sirve_nudo_ocho_boyas": {
      "respuestas_puente": [
        "🎣 EL NUDO EN OCHO (8) PARA ARMAR LÍNEAS\n\nEs un lazo robusto y muy confiable utilizado en los extremos de la madre o brazoladas.\n\nArmado:\n1. Formás un bucle, le das una vuelta completa por detrás y pasás la punta por el ojal principal, dibujando un '8'.\n2. Sirve para atar mosquetones o iniciar la línea.\n\nConsejo del Baqueano: Todo pescador debe saber hacer el ocho. Es la base de un aparejo que no te va a dejar a gamba cuando te pique el trofeo de la jornada."
      ]
    },
    "donde_sirve_boya_ping_pong": {
      "respuestas_puente": [
        "🎣 BOYAS TIPO PING-PONG DE COSTA\n\nSon esferas grandes, del tamaño y forma de una pelota de ping-pong.\n\nUso táctico:\n1. Se emplean exclusivamente cuando pescamos desde la costa o a la misma altura del agua.\n2. Al estar a ras del agua, necesitamos volumen extremo para no perderlas de vista.\n\nConsejo del Baqueano: Desde la orilla no tenés el ángulo de visión de un muelle. Las ping-pong o chupetonas gigantes son tu radar. Y te marcan hermoso la corrida cuando el peje lleva."
      ]
    },
    "como_se_hace_boya_elevadora_mar": {
      "respuestas_puente": [
        "🎣 APAREJO CON BOYA ELEVADORA PARA MAR\n\nLínea diseñada para la pesca de costa (pescadilla, burriqueta) evitando enganches.\n\nArmado paso a paso:\n1. En la parte superior de la madre, colocá una boya elevadora trabada con dos perlitas y nudos corredizos (dejá un leve juego).\n2. Abajo, atá los rotores para dos anzuelos espaciados.\n3. Al final, colocá el mosquetón para la plomada.\n\nConsejo del Baqueano: Esta boya te tira la línea para arriba. Los anzuelos quedan trabajando a media agua, la plomada en el fondo y no enganchás las rocas cuando recogés."
      ]
    },
    "donde_sirve_boya_elevadora": {
      "respuestas_puente": [
        "🎣 PESCA EN ZONAS DE MUCHO ENGANCHE\n\nLa costa atlántica tiene planchones de piedra que se comen los aparejos de fondo.\n\nUtilidad de la elevadora:\n1. Mantiene el sedal y los anzuelos lo más verticales posibles.\n2. Separa el anzuelo principal unos 15 cm del fondo y el otro a media agua.\n\nConsejo del Baqueano: Pescando pescadilla, que es cazadora de media agua, esta línea es veneno. Además, al pegar el cañazo, la boya ayuda a que la plomada se levante rápido del fondo evitando que claves la piedra."
      ]
    },
    "como_se_prepara_madre_pescadilla": {
      "respuestas_puente": [
        "🎣 MADRE PARA LÍNEA ELEVADORA DE COSTA\n\nPara el mar necesitamos materiales rudos que aguanten lances pesados y salitre.\n\nArmado:\n1. Cortá 2 metros de nylon monofilamento del 0.60.\n2. Hacé el lacito de arriba pasando dos veces por adentro para mayor seguridad.\n\nConsejo del Baqueano: Con el mar no se jode. Si tirás un plomo pesado con un nylon finito de madre, al primer latigazo se te corta. El 0.60 te da tranquilidad para meterle fuerza al lance."
      ]
    },
    "que_sirve_rotor_mar": {
      "respuestas_puente": [
        "🎣 ROTORES EN LÍNEA DE MAR\n\nPiezas fundamentales para fijar la brazolada a la madre sin perder movilidad.\n\nInstalación:\n1. Van sujetados entre nudos corredizos y perlitas de tope.\n2. La brazolada se anuda en la ranura lateral o anillo del rotor.\n\nConsejo del Baqueano: El mar revuelve todo. Si atás el anzuelo fijo a la madre, sacás una bola de nudos. El rotor gira loco y desenrosca la tanza salvándote de las galletas."
      ]
    },
    "como_hago_nudo_rotor_mar": {
      "respuestas_puente": [
        "🎣 NUDO PARA EL ROTOR CON \"JUEGO\"\n\nCuando asegurás los rotores en la madre, la distancia entre nudos es clave.\n\nEjecución:\n1. Hacé el nudo corredizo superior.\n2. Poné la perlita, rotor, perlita.\n3. Hacé el nudo inferior, pero dejale unos milímetros de espacio.\n\nConsejo del Baqueano: ¡Nunca lo aprietes de tope a tope! Ese pequeño \"juego\" es lo que permite que el rotor gire y el anzuelo no se te enrolle en la madre principal de la línea."
      ]
    },
    "como_se_prepara_brazolada_pescadilla": {
      "respuestas_puente": [
        "🎣 BRAZOLADA PARA PESCADILLA DE COSTA\n\nEs el tramo final que va desde el rotor hasta el anzuelo.\n\nArmado:\n1. Cortá unos 60 cm de nylon del 0.50 (luego de atar te quedarán 40-50 cm netos).\n2. Asegurá el anzuelo con el típico nudo de barril.\n3. Enganchá la otra punta en el rotor.\n\nConsejo del Baqueano: No te enrosques haciendo brazoladas de un metro. Si pescás con boya elevadora buscando verticalidad, con 40 cm el anzuelo baila perfecto y no se cruza con el resto del equipo."
      ]
    },
    "cuando_sirve_boya_elevadora_pique": {
      "respuestas_puente": [
        "🎣 CAÑAZO CON BOYA ELEVADORA\n\nAl pescar con este aparejo, la tensión del nylon es particular.\n\nTáctica:\n1. Mantené la tanza del reel media floja.\n2. Al notar el toque firme (usualmente de la pescadilla de media agua), cañá con fuerza para arriba y traé rápido.\n\nConsejo del Baqueano: Al estar la línea vertical por la boya, el pique no arrastra por el fondo, levanta directo el aparejo. Si traés a buena velocidad con un reel rápido, pasás limpio por arriba de las piedras."
      ]
    },
    "que_sirve_anzuelo_numero_cuatro_mar": {
      "respuestas_puente": [
        "🎣 ANZUELO NÚMERO 4 PARA VARIADA\n\nEs el tamaño comodín para la costa atlántica cuando buscamos diversidad.\n\nSelección:\n1. Pata mediana o larga.\n2. Ideal para atar el nudo directamente en la pata.\n\nConsejo del Baqueano: Con un N°4 sacás pescadilla, pero también corvinas chicas o burriquetas. Es el todoterreno de la variada de costa; ni tan chico que se lo tragan, ni tan grande que errás el pique."
      ]
    },
    "como_hago_no_quemar_tanza_mar": {
      "respuestas_puente": [
        "🎣 LUBRICAR LOS NUDOS SIEMPRE\n\nEl error número uno al armar aparejos de cualquier tipo, mar o río, es ceñir en seco.\n\nAcción vital:\n1. Cuando termines de dar las vueltas del nudo, llenalo de saliva o mojalo con agua.\n2. Recién ahí tirá fuerte para ceñirlo.\n\nConsejo del Baqueano: Si pasás el nudo en seco, vas a ver cómo la tanza se pone rulo y opaca. Eso está quemado por fricción. Al primer tirón de un pescado lindo, te quedás mirando la caña vacía."
      ]
    },
    "como_se_prepara_distancia_anzuelos_mar": {
      "respuestas_puente": [
        "🎣 DISTANCIA ENTRE ANZUELOS EN LA ELEVADORA\n\nLa distribución del espacio evita enredos cruzados en el mar.\n\nMedida:\n1. Desde el anzuelo superior (debajo de la boya) dale 40 a 50 cm de madre hasta el próximo anzuelo.\n2. Del inferior hacia la plomada también un buen margen (15 cm libres tras la brazolada).\n\nConsejo del Baqueano: Separalos bien. Si una ola te revuelve la línea y las brazoladas se tocan, sacás un bollo. Dale margen para que cada pescadilla tenga su \"sector\" de comida."
      ]
    },
    "como_se_hace_indicador_pique_mosca": {
      "respuestas_puente": [
        "🎣 INDICADOR DE PIQUE EN PESCA CON MOSCA\n\nEn la Patagonia y Mendoza, se usa para pescar con moscas hundidas (ninfas) a deriva muerta.\n\nUso técnico:\n1. Funciona como una mini boyita atada al líder.\n2. Advierte el pique al frenarse o hundirse.\n3. Acorta la distancia visible entre el pescador y la mosca oculta.\n\nConsejo del Baqueano: Muchos le dicen 'pescar con boya' despectivamente, pero es un arte. Ayuda a lograr la deriva natural del insecto y a no perder los toques milimétricos de una trucha recelosa."
      ]
    },
    "que_sirve_indicador_pasta_patagonia": {
      "respuestas_puente": [
        "🎣 INDICADOR EN PASTA O MASILLA\n\nEs un compuesto moldeable flotante que se pega directamente al tippet o leader de fly cast.\n\nVentajas:\n1. Se dosifica a gusto; podés poner una pizca para ninfas diminutas o un bollo para aguas movidas.\n2. No genera resistencia extra al castear ni salpica mucho al caer.\n\nConsejo del Baqueano: En los arroyos chicos de Córdoba o Cuyo, la pasta es oro. Si te acercás sigiloso a la trucha, levantás la caña y usás la masilla solo como \"indicador de nivel\", pescás a pez visto sin espantarlo."
      ]
    },
    "cuando_sirve_indicador_deriva_muerta": {
      "respuestas_puente": [
        "🎣 DERIVA MUERTA Y EL DRAG\n\nLa deriva muerta es lograr que la ninfa se mueva a la velocidad natural de la corriente.\n\nTáctica:\n1. Evitar la tensión en la línea (arrastre o drag).\n2. El indicador flota suelto acompañando el ritmo del agua.\n\nConsejo del Baqueano: Es un juego de equilibrio. Si dejás demasiada soltura, la trucha pica, suelta y vos ni te enteraste. Si dejás la línea tensa, la mosca raya el agua (drag) y no pica ninguna. El indicador te marca si vas bien."
      ]
    },
    "donde_sirve_indicador_pique_arroyos": {
      "respuestas_puente": [
        "🎣 USO DEL INDICADOR EN ARROYOS CHICOS\n\nEn cursos pequeños, el sol, los obstáculos y las distancias cortas son el desafío.\n\nEjecución:\n1. Usá el punto ciego de la trucha acercándote por detrás.\n2. Acompañá la corriente con la caña en alto (High Sticking), dejando casi solo el leader y el indicador en el agua.\n\nConsejo del Baqueano: Mantené el indicador siempre a la misma altura. Funciona para marcar que tu ninfa va rozando las piedras del fondo, justo donde la marrón está esperando comer."
      ]
    },
    "como_hago_deriva_correcta_mosca": {
      "respuestas_puente": [
        "🎣 IGUALAR VELOCIDADES DE AGUA\n\nLos ríos tienen canales y capas de distintas velocidades. Arriba va rápido, en el fondo lento.\n\nCompensación:\n1. El indicador va por la superficie (rápida).\n2. La ninfa va por el fondo (lenta).\n3. Hay que compensar el canal por el que va el indicador cruzándolo.\n\nConsejo del Baqueano: No te aferres ciegamente al indicador. Capaz tu indicador va lindo en un remanso, pero tu mosca ya cruzó a la correntada y está flameando a 2 metros de profundidad. Aprendé a 'leer' dónde está la mosca abajo."
      ]
    },
    "como_se_prepara_profundidad_ninfa": {
      "respuestas_puente": [
        "🎣 REGULAR PROFUNDIDAD EN FLY CAST\n\nEl indicador nos asegura a qué capa de agua estamos pescando.\n\nCálculo:\n1. Medir la distancia entre el indicador y la ninfa.\n2. Asegurarse que el indicador soporte el peso de la mosca de tungsteno o plomo.\n\nConsejo del Baqueano: Si le erraste a la profundidad, pescás agua. En pozones patagónicos hondos, separá bien el indicador. La regla es: la mosca deriva a una profundidad igual a la distancia que le diste al indicador."
      ]
    },
    "cuando_hago_clavada_rapida_mosca": {
      "respuestas_puente": [
        "🎣 REFLEJOS EN LA CLAVADA CON NINFA\n\nLas truchas tienen una sensibilidad extraordinaria en la boca; usan la boca para explorar.\n\nReacción:\n1. Al más mínimo parate, hundimiento o vibración del indicador, hay que tensar (clavar).\n2. Las truchas escupen el alambre y las plumas en milisegundos.\n\nConsejo del Baqueano: Si venís de pescar con cucharita o carnada, esperás sentir el tirón en la mano. Acá no. Pescando a deriva muerta no sentís nada. Ves que el indicador parpadea e instintivamente tenés que clavar rapidísimo."
      ]
    },
    "que_sirve_separacion_boyas_pejerrey": {
      "respuestas_puente": [
        "🎣 SEPARACIÓN ENTRE BOYAS EN LAGUNAS\n\nEl armado de la línea es simétrico y vital para sortear el clima.\n\nNorma:\n1. Distanciar cada boya entre 1,10 y 1,20 metros como mínimo.\n\nConsejo del Baqueano: En el Río Uruguay o el de la Plata se arma mucha ola cruzada. Si ponés las boyas pegaditas a medio metro, van a cabalgar la misma ola juntas y el pejerrey, que no es tonto, nota la falsedad y larga."
      ]
    },
    "como_hago_leer_agua_indicador": {
      "respuestas_puente": [
        "🎣 LECTURA DE CAPAS VERTICALES Y HORIZONTALES\n\nEl pescador de mosca avanzado pesca con la imaginación y la lectura del régimen laminar.\n\nTáctica:\n1. Saber exactamente dónde cae la mosca tras el casteo.\n2. Descifrar por dónde va la mosca bajo el agua mientras seguís el indicador por la superficie.\n\nConsejo del Baqueano: Muchas veces el indicador deriba limpio y no hay pique. La diferencia entre pescar o hacer turismo está en saber acomodar la línea transversalmente para que ninfa y boyita naveguen sin tironearse entre sí."
      ]
    },
    "como_se_prepara_lanzamiento_curvo": {
      "respuestas_puente": [
        "🎣 LANZAMIENTO CURVO (CURVE CAST)\n\nUna técnica de lanzamiento en mosca para acomodar la línea frente a corrientes caprichosas.\n\nUso con indicador:\n1. Deposita el indicador y la mosca en ángulos perpendiculares o transversales.\n2. Permite que el indicador derive en su canal superficial sin cruzar la mosca en el fondo.\n\nConsejo del Baqueano: Cuando dominás las correcciones en el aire o los 'mends' en el agua, dejás de depender de la suerte. Ubicás el indicador exacto y le regalás la mosca a la trucha en bandeja."
      ]
    },
    "como_se_prepara_equipo_liviano_flote": {
      "respuestas_puente": [
        "🎣 CAÑAS LIGERAS PARA PEJERREY\n\nEl desgaste de pescar con boyas a pulso durante horas es alto.\n\nSelección:\n1. Cañas telescópicas o de tramos entre 3.60 m y 4.20 m.\n2. Deben ser de carbono/grafito para aligerar peso.\n\nConsejo del Baqueano: Si vas a caminar el muelle todo el día con una caña pesada, terminás con el brazo acalambrado. Buscá una varita de 4 metros bien liviana; vas a clavar a tiempo y disfrutar el doble la jornada."
      ]
    },
    "donde_sirve_paternoster_pejerrey": {
      "respuestas_puente": [
        "🎣 EL PATERNÓSTER\n\nEs una línea con una boya grande y plomo al final que permite explorar varias profundidades al mismo tiempo.\n\nUso ideal:\n1. Búsqueda vertical. Ponés un anzuelo a 50 cm, otro a 1 metro, otro a 1.5 metros.\n2. Útil a principio de jornada para descubrir dónde come el cardumen.\n\nConsejo del Baqueano: Si llegás a la laguna y no sabés dónde anda el matungo, tirá el paternóster. En cuanto veas qué anzuelo pica más, armás la línea de tres boyas a esa misma profundidad."
      ]
    },
    "como_hago_evitar_enredo_boyas": {
      "respuestas_puente": [
        "🎣 PREVENIR NUDOS EN LOS LANZAMIENTOS\n\nLa línea de 3 boyas es larga y propensa a los 'galletazos'.\n\nTécnica:\n1. Orientá siempre la parte de mayor volumen de la boya hacia el puntero (hacia adelante).\n2. El viento las estabilizará en el aire y en el agua.\n\nConsejo del Baqueano: Si ponés la cabeza gorda de la boya mirando para tu lado, en el aire flamean, se juntan y caen hechas un nudo. Aerodinámica simple, muchacho."
      ]
    },
    "que_sirve_volumen_boya_puntero": {
      "respuestas_puente": [
        "🎣 ALINEACIÓN POR VOLUMEN\n\nEl diseño físico de la boya impacta directamente en cómo deriva rectilínea o cruzada.\n\nArmado:\n1. Boyas esféricas: no importa.\n2. Boyas asimétricas (lágrima, cometa, chupete): parte gruesa mirando a la línea distal (hacia el impulsor).\n\nConsejo del Baqueano: Si querés que la línea 'navegue recto' como un tren sobre rieles en el garete de laguna, respetá siempre hacia dónde apunta el volumen. Actúa como el timón de un botecito."
      ]
    },
    "como_se_prepara_reel_pejerrey": {
      "respuestas_puente": [
        "🎣 REEL PARA PESCA A FLOTE\n\nLa tracción y velocidad al recuperar líneas de 3 boyas son determinantes.\n\nSetup:\n1. Frontal chico y liviano, o huevito (rotativo de bajo perfil).\n2. Carga mínima de 100 metros de nylon o multifilamento.\n3. Ratio de recuperación alta.\n\nConsejo del Baqueano: Necesitás juntar tanza rápido cuando el peje lleva hacia vos. Si tenés un reel lento, perdés tensión y se destraba el anzuelo. Livianito y picante, esa es la receta."
      ]
    },
    "cuando_sirve_boya_luminosa_nocturna": {
      "respuestas_puente": [
        "🎣 CUÁNDO USAR BOYAS LUMINOSAS\n\nLas boyas luminosas son indispensables para la pesca nocturna, especialmente buscando el pejerrey de mar en muelles o el pati y surubí en los remansos del río.\n\nConsejo del Baqueano: La noche en el río o el mar te deja ciego. Si tirás una boya común, no vas a ver la picada y vas a errar todos los toques. La boya luminosa (LED o con alojamiento para luz química 'chemical light') te marca el rumbo exacto y te avisa al instante cuando el pez 'lleva' o la boya se acuesta."
      ],
      "tipos": [
        "Boya Luminosa LED",
        "Boya porta luz química"
      ]
    },
    "cuando_hago_uso_anteojos_polarizados": {
      "respuestas_puente": [
        "🎣 ANTEOJOS POLARIZADOS EN EMBARCADO\n\nElemento de seguridad y de eficiencia pesquera.\n\nUtilidad:\n1. Filtran los rayos solares reflejados en el espejo de agua.\n2. Permiten dominar perfectamente las boyas con la vista y ver el cuerpo de los peces cerca de la lancha.\n\nConsejo del Baqueano: Pescador que dice que no necesita anteojos, es pescador que vuelve zapatero a la casa con dolor de cabeza. Un buen polarizado te deja ver las llevadas a milímetros bajo el agua. ¡No te subas al bote sin ellos!"
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
