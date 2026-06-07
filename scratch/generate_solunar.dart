import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, dynamic>> data = {
    "cuando_sirve_periodo_mayor_pesca": {
      "respuestas_puente": [
        "🌙 QUÉ SON Y CUÁNDO SIRVEN LOS PERÍODOS MAYORES\n\nLos períodos mayores solunares ocurren cuando la luna se encuentra directamente sobre nuestras cabezas (tránsito o cenit) o directamente bajo nuestros pies (tránsito opuesto o nadir).\n\nDetalles del pique:\n- Duración: Aproximadamente de 2 a 3 horas.\n- Comportamiento: Es el momento de máxima actividad. No hay especie de pez deportivo que no se encuentre comiendo durante este lapso. La atracción gravitacional agudiza su necesidad de buscar alimento.\n\nConsejo del Baqueano: Son los momentos más calientes del día. Si tu jornada coincide con un período mayor, tené la línea en el agua, el anzuelo bien encarnado y la máxima concentración. Las chances de clavar el trofeo de tu vida se duplican en esta franja horaria."
      ],
      "tipos": [
        "Tránsito Lunar (Cenit - Luna arriba)",
        "Nadir Lunar (Luna abajo)"
      ]
    },
    "cuando_sirve_periodo_menor_pesca": {
      "respuestas_puente": [
        "🌔 QUÉ SON Y CUÁNDO SIRVEN LOS PERÍODOS MENORES\n\nLos períodos menores son franjas intermedias de actividad solunar que coinciden con la salida (orto) y la puesta (ocaso) de la luna en el horizonte.\n\nDetalles del pique:\n- Duración: Suelen extenderse entre 45 y 90 minutos (promedio 1 hora).\n- Comportamiento: Generan un incremento notable en la actividad de los peces respecto al resto del día, impulsándolos a patrullar sus zonas de caza.\n\nConsejo del Baqueano: Aunque son más cortos que los mayores, no los subestimes. Si un período menor coincide con el amanecer o atardecer solar, preparate para un pique explosivo de especies cazadoras como el dorado o la tararira."
      ],
      "tipos": [
        "Orto Lunar (Salida de la luna)",
        "Ocaso Lunar (Puesta de la luna)"
      ]
    },
    "que_se_hace_luna_nueva_pique": {
      "respuestas_puente": [
        "🌑 EL PODER DE LA LUNA NUEVA EN LA PESCA\n\nLa luna nueva (cuando la luna está oscura en el cielo) es considerada estadísticamente como una de las mejores fases para la pesca deportiva, con un pronóstico catalogado como 'Muy Bueno'.\n\nComportamiento del pez:\n- En el mar: Provoca mareas vivas, aumentando las corrientes y activando el apetito de especies marinas.\n- En el río: Al haber noches muy oscuras, ciertas especies nocturnas se sienten protegidas, pero la verdadera fiesta ocurre de día, ya que los peces no pudieron cazar a la vista durante la noche.\n\nConsejo del Baqueano: Ideal para jornadas diurnas largas. En el mar, preparate para usar plomadas pesadas por la fuerte corriente. En el río, madrugá: la actividad desde el alba hasta la media tarde suele ser excelente."
      ],
      "tipos": [
        "Mareas vivas fuertes",
        "Alta actividad diurna",
        "Oscuridad nocturna total"
      ]
    },
    "como_se_prepara_luna_llena_pique": {
      "respuestas_puente": [
        "🌕 LA LUNA LLENA: UN ARMA DE DOBLE FILO\n\nLa luna llena ilumina la noche como si fuera de día. Esto altera fuertemente el reloj biológico de las especies, considerándose una fase 'Mala' o 'Regular' para la pesca diurna.\n\nComportamiento del pez:\n- Mucha luz nocturna expone a los peces presa, volviéndolos cautelosos y recelosos.\n- Los predadores grandes aprovechan esta claridad para cazar toda la noche, por lo que al llegar el día, están llenos y aletargados.\n\nConsejo del Baqueano: Cambiá tus horarios. Con luna llena, la clave es pescar al atardecer, de noche o al alba. Durante el pleno día, buscá los pozones más profundos o zonas de sombra densa donde el pez busca refugio para descansar."
      ],
      "tipos": [
        "Alta luminosidad nocturna",
        "Pesca diurna floja",
        "Mareas vivas marinas"
      ]
    },
    "como_se_prepara_cuartos_luna_pesca": {
      "respuestas_puente": [
        "🌗 PESCANDO EN CUARTO CRECIENTE Y MENGUANTE\n\nLas fases intermedias de la luna estabilizan el ambiente acuático. El Cuarto Menguante suele tener un pronóstico 'Bueno', mientras que el Creciente es más 'Regular'.\n\nComportamiento del pez:\n- En el mar: Producen las llamadas 'mareas muertas'. Hay menos movimiento de agua, lo que reduce el estímulo de alimentación, pero facilita la técnica al no haber corrientes extremas.\n- En el río: Los peces mantienen rutinas de alimentación más predecibles en los horarios centrales del día (mediodía y media tarde).\n\nConsejo del Baqueano: Son días ideales para pescar cómodo. Al no tener corrientes agresivas, podés usar equipos más livianos, líneas más sutiles y disfrutar de una pesca de espera. Enfocate en los períodos solunares para encontrar el pico de pique."
      ],
      "tipos": [
        "Cuarto Creciente (Regular)",
        "Cuarto Menguante (Bueno)",
        "Mareas Muertas"
      ]
    },
    "cuando_sirve_presion_baja_pique": {
      "respuestas_puente": [
        "🌩️ PRESIÓN BAROMÉTRICA EN DESCENSO (TORMENTAS)\n\nLa presión barométrica es el peso del aire sobre el agua. Los peces tienen una vejiga natatoria extremadamente sensible a estas variaciones. El rango ideal es de 1010 a 1020 hPa.\n\nComportamiento del pez:\n- Cuando la presión baja rápidamente, indica que se acerca un frente de tormenta. Esto enciende una alerta de supervivencia: los peces se vuelven hiperactivos y agresivos para alimentarse antes de que el clima empeore.\n\nConsejo del Baqueano: ¡Es el mejor momento para estar en el agua! Usá señuelos de recuperación rápida o carnadas voluminosas, y apuntá a zonas de poca profundidad. Apenas pase la tormenta y la presión suba de golpe, el pique se va a cortar abruptamente."
      ],
      "tipos": [
        "Presión en caída (tormenta)",
        "Alta actividad alimentaria"
      ]
    },
    "cuando_sirve_presion_alta_pique": {
      "respuestas_puente": [
        "☀️ PRESIÓN BAROMÉTRICA ALTA O EN AUMENTO\n\nCuando la presión barométrica sube, generalmente viene acompañada de cielos despejados y frentes fríos. Esto empuja físicamente sobre el agua y los peces lo sienten.\n\nComportamiento del pez:\n- La presión alta incomoda a muchas especies, haciéndolas bajar a zonas más profundas. Se aletargan, reducen su ventana de alimentación y se refugian en estructuras (piedras, raigambres).\n\nConsejo del Baqueano: Toca pescar fino y tener paciencia. Usá cebos de movimiento lento, profundizá tus líneas al máximo y pasá el engaño muy cerca de sus narices (en las estructuras protegidas). El pez no va a perseguir la carnada; tenés que llevársela a la boca."
      ],
      "tipos": [
        "Presión en aumento (despejado)",
        "Peces inactivos o profundos"
      ]
    },
    "como_se_prepara_luna_surubi_parana": {
      "respuestas_puente": [
        "🌙 LA LUNA Y EL SURUBÍ EN EL PARANÁ\n\nEl surubí (pintado y atigrado) es el gigante de piel de nuestra cuenca. A diferencia del dorado, es un cazador de emboscada por su falta de velocidad extrema.\n\nComportamiento del pez:\n- Caza de noche saltando hacia sus presas (morenas, tarariras chicas) desde su escondite.\n- Prefiere cazar 'al reparo de la luna', ya que el exceso de luz expone su enorme silueta y espanta a sus presas. \n- Aborrece las aguas muertas, busca las corrientes oxigenadas cálidas (octubre a mayo).\n\nConsejo del Baqueano: En la cuna del surubí (Goya a Reconquista), buscá las correderas al atardecer y de noche. Si te toca luna llena, buscá los veriles profundos o zonas de mucha sombra. Usá naylon del 40/50, anzuelos 8/0 o 9/0, carnada blanca o morena viva, y plomada corrediza para no generar resistencia al pique."
      ],
      "tipos": [
        "Cazador nocturno de emboscada",
        "Preferencia por aguas cálidas y oscuras"
      ]
    },
    "donde_se_hace_temporada_dorado_rio": {
      "respuestas_puente": [
        "🐅 TEMPORADA Y COMPORTAMIENTO DEL DORADO\n\nEl 'Tigre de los Ríos' (Salminus brasiliensis) es el predador más icónico del Litoral (Ríos Paraná, Uruguay, Pilcomayo).\n\nComportamiento del pez:\n- Su mejor temporada va de septiembre a mayo (aguas cálidas).\n- Se rige mucho por los serenos (orto y ocaso solar) y los períodos solunares mayores. Es un cazador visual que adora la corriente y las aguas oxigenadas.\n\nConsejo del Baqueano: Armate un buen equipo de baitcasting o spinning con leaders de acero. Con luna llena, probá pescar de noche con señuelos oscuros que recorten silueta hacia arriba. De día, buscalo golpeando las barrancas, piedras y correderas. ¡Recordá que en muchas zonas la devolución es obligatoria!"
      ],
      "tipos": [
        "Temporada cálida (Sept-May)",
        "Cazador visual de corriente"
      ]
    },
    "cuando_sirve_marea_corvina_mar": {
      "respuestas_puente": [
        "🌊 MAREAS Y LA CORVINA EN EL MAR ARGENTINO\n\nPara la pesca marítima (ej. corvina rubia de octubre a marzo), la tabla de mareas y la luna son la regla de oro. Las mareas generan movimiento de agua que es vital para la alimentación costera.\n\nComportamiento del pez:\n- Las mareas vivas (Luna Nueva y Llena) generan corrientes fuertes. A la corvina le encanta porque el agua revuelve los fondos de arena y desentierra su alimento (camarones, cangrejos, almejas).\n- Las primeras dos horas de la creciente (pleamar) y las últimas de la bajamar son los momentos de frenesí.\n\nConsejo del Baqueano: Pescando desde playa (ej. Mar del Plata a Bahía San Blas), usá línea de fondo. Si hay marea viva, vas a necesitar un plomo de destrabe (con alambres) pesado para anclar la línea. El repunte de marea es tu momento clave; en la marea parada (estoa), aprovechá para tomar unos mates."
      ],
      "tipos": [
        "Mareas vivas (corrientes fuertes)",
        "Mareas muertas (aguas calmas)",
        "Pleamar y Bajamar"
      ]
    },
    "donde_se_hace_temporada_pejerrey_laguna": {
      "respuestas_puente": [
        "❄️ TEMPORADA DE PEJERREY EN INVIERNO\n\nEl pejerrey (Odobenus argentinus) es el rey del invierno en Argentina. A diferencia de otras especies, adora las aguas frías y cristalinas.\n\nComportamiento del pez:\n- Su temporada alta va de mayo a agosto.\n- Habita lagunas bonaerenses, embalses de Córdoba y la costa atlántica.\n- Es sensible a los vientos. Una brisa rizando la superficie oxigena el agua y lo activa, mientras que una laguna 'planchada' suele dificultar la pesca.\n\nConsejo del Baqueano: Usá líneas de flote (tres boyas) o paternóster si están más profundos. Armate con anzuelos finos y encarná prolijo con mojarra viva. Buscá las costas donde muere el viento, porque ahí se acumula el plancton y el alimento."
      ],
      "tipos": [
        "Temporada fría (May-Ago)",
        "Pesca de flote y paternóster"
      ]
    },
    "donde_se_hace_temporada_tararira_verano": {
      "respuestas_puente": [
        "🔥 LA TARARIRA Y LAS AGUAS SOMERAS\n\nLa tararira (Hoplias malabaricus) es un pez prehistórico sumamente agresivo y territorial que domina zanjones, lagunas y arroyos de baja profundidad.\n\nComportamiento del pez:\n- Explota en los meses cálidos (octubre a abril).\n- Son cazadoras de acecho que se ocultan en la vegetación densa (juncos, camalotes).\n- Los períodos solunares que coinciden con la caída del sol las vuelven extremadamente violentas.\n\nConsejo del Baqueano: Armá tu equipo de spinning o baitcasting. Usá señuelos anti-enganche de superficie (ranas de goma) o de media agua. Si hace mucho calor al mediodía, se entierran en el barro; esperá al atardecer y preparate para los ataques explosivos en superficie."
      ],
      "tipos": [
        "Temporada cálida (Oct-Abr)",
        "Cazador territorial de acecho"
      ]
    },
    "cuando_sirve_serenos_solunar_actividad": {
      "respuestas_puente": [
        "🌅 LOS SERENOS Y EL EFECTO MULTIPLICADOR\n\nEn la teoría solunar, además de la luna, el sol juega un papel clave. Los 'serenos' son los momentos de orto (amanecer) y ocaso (atardecer) solar, que actúan como períodos menores secundarios.\n\nComportamiento del pez:\n- Las horas de penumbra son por instinto los mejores momentos de caza, ya que las presas se confunden por el cambio de luz.\n- Cuando un período solunar (mayor o menor) se superpone con un amanecer o atardecer (especialmente en luna nueva o llena), la actividad del pez se amplifica de forma espectacular.\n\nConsejo del Baqueano: Si la app te marca un período mayor a las 6:00 AM o a las 19:00 PM, prepará todo el equipo la noche anterior. Ese momento es el 'Holy Grail' de la pesca; los peces morderán cualquier carnada o señuelo que se les cruce."
      ],
      "tipos": [
        "Orto solar (Amanecer)",
        "Ocaso solar (Atardecer)",
        "Efecto multiplicador"
      ]
    },
    "que_se_hace_mareas_vivas_mar": {
      "respuestas_puente": [
        "🌊 MAREAS VIVAS: ACCIÓN EXTREMA EN EL MAR\n\nLas mareas vivas (o mareas de sicigia) ocurren durante las fases de Luna Llena y Luna Nueva, cuando el Sol, la Tierra y la Luna se alinean, sumando sus fuerzas gravitacionales.\n\nComportamiento del pez:\n- Producen la mayor amplitud de marea (las altas son más altas y las bajas más bajas).\n- Esto genera corrientes submarinas muy potentes que arrastran alimento, enloqueciendo a especies como la lubina, la corvina y el pez elefante.\n\nConsejo del Baqueano: Es la mejor marea para pescar, pero la más dura físicamente. Prepará tu equipo pesado: cañas de surfcasting rígidas, tanzas gruesas y plomos de destrabe de más de 150 gramos. Encarná bien atado con hilo elástico para que la corriente no te robe la carnada."
      ],
      "tipos": [
        "Alta amplitud de marea",
        "Corrientes submarinas fuertes"
      ]
    },
    "que_se_hace_mareas_muertas_mar": {
      "respuestas_puente": [
        "💧 MAREAS MUERTAS: PESCA RELAJADA\n\nLas mareas muertas (o mareas de cuadratura) ocurren durante el Cuarto Creciente y el Cuarto Menguante, cuando el Sol y la Luna forman un ángulo recto, contrarrestando sus fuerzas.\n\nComportamiento del pez:\n- El agua sube y baja muy poco, generando corrientes muy débiles o nulas.\n- Al no haber movimiento en el fondo, los peces bentónicos (que comen en el suelo) reducen su actividad alimentaria, ya que no les 'llueve' la comida.\n\nConsejo del Baqueano: Aunque la actividad sea menor, es el escenario ideal para el pescador novato o el que busca relax. Podés usar plomadas livianitas (satélites o peritas), afinar los grosores de la línea y disfrutar de pescas sutiles (como el pejerrey de mar o la pescadilla) sin pelear contra la fuerza del océano."
      ],
      "tipos": [
        "Baja amplitud de marea",
        "Corrientes nulas o débiles"
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
