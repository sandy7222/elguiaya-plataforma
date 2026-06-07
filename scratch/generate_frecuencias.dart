import 'dart:io';
import 'dart:convert';

void main() {
  final Map<String, Map<String, dynamic>> data = {
    "que_sirve_canal_emergencia": {
      "respuestas_puente": [
        "📻 CANAL 16 VHF (EMERGENCIA Y SOCORRO PNA)\n\nEl Canal 16 de VHF (frecuencia 156.800 MHz) es el canal internacional de llamada, emergencia, socorro y seguridad marítima obligatorio.\n\nDetalles técnicos:\n- Frecuencia: 156.800 MHz.\n- Uso: Exclusivo para llamadas de auxilio (MAYDAY), urgencia (PAN PAN), seguridad (SECURITE) o contacto inicial antes de pasar a un canal de trabajo.\n\nConsejo del Baqueano: Mantener escucha permanente en el Canal 16 mientras navegues es ley. Está prohibido usarlo para charlas informales o de pesca. La radio te puede salvar la vida ante un temporal o si te quedás sin motor."
      ],
      "tipos": [
        "Canal 16 PNA (Llamada y Socorro)"
      ]
    },
    "donde_sirve_frecuencia_corrientes": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS CORRIENTES (RÍO PARANÁ)\n\nEl VTS Corrientes coordina el tráfico portuario y fluvial en el Río Paraná, desde el Km 1240 hasta el 1135, limitando con Paraguay.\n\nDetalles técnicos:\n- Estación: VTS Corrientes (Indicativo L6Y).\n- Canal de Trabajo: Canal 12 VHF (156.600 MHz).\n- Canal de Seguridad y Clima: Canal 14 VHF (156.700 MHz).\n\nConsejo del Baqueano: Todo buque debe pedir autorización antes de ingresar al área. Sintonizá el Canal 14 a las 0010, 0410, 0810, 1210, 1610 y 2010 UTC para escuchar radioavisos y el boletín meteorológico de la zona."
      ],
      "tipos": [
        "Canal 12 VTS Corrientes L6Y (Trabajo)",
        "Canal 14 PNA (Seguridad/Clima)",
        "Canal 16 PNA (Llamada y Socorro)"
      ]
    },
    "donde_sirve_frecuencia_mar_del_plata_portuario": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS MAR DEL PLATA PORTUARIO\n\nControla un radio de 30 millas tomando como centro la escollera del Puerto de Mar del Plata.\n\nDetalles técnicos:\n- Estación: VTS Mar del Plata (Indicativo L2U).\n- Canal de Trabajo: Canal 09 VHF (156.450 MHz).\n- Canal de Seguridad: Canal 15 VHF (156.750 MHz).\n\nConsejo del Baqueano: Mantené siempre la escucha en el Canal 16. Si necesitás asistencia médica, comunícate por el Canal 09. Recordá informar a 30 millas, a 3 millas (para pedir práctico) y a 1 milla de la entrada al puerto."
      ],
      "tipos": [
        "Canal 09 VTS Mar del Plata L2U (Trabajo/Médico)",
        "Canal 15 PNA (Seguridad)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "como_se_hace_comunicacion_mar_del_plata_maritimo": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS MAR DEL PLATA MARÍTIMO (HF)\n\nCubre el Mar Argentino desde el paralelo 35° 50' Sur hasta el 42° 00' Sur, y hasta las 200 millas náuticas (ZEE).\n\nDetalles técnicos:\n- Estación: VTS Mar del Plata Marítimo (Indicativo L2T).\n- Frecuencias de Trabajo HF: 4354 kHz and 8713 kHz.\n- Frecuencias Médicas: 4354 kHz, 8713 kHz and 5630 kHz (aeroevacuaciones).\n\nConsejo del Baqueano: Ideal para altamar donde el VHF no llega. Los pesqueros deben reportarse a las 0000, 0800 y 1600. Podés recibir alertas NAVTEX en 518 kHz (Inglés) y 490 kHz (Español)."
      ],
      "tipos": [
        "HF 4354 kHz / 8713 kHz (Trabajo L2T)",
        "HF 2065 kHz / 4149 kHz / 8294 kHz (Seguridad)",
        "NAVTEX 518 kHz / 490 kHz"
      ]
    },
    "donde_sirve_frecuencia_rosario": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS ROSARIO (RÍO PARANÁ)\n\nCubre el vital corredor comercial del Río Paraná desde el Km 480 hasta el Km 376, operando las 24 horas.\n\nDetalles técnicos:\n- Estación: VTS Rosario (Indicativo L6I).\n- Canal de Trabajo: Canal 14 VHF (156.700 MHz).\n- Canal de Seguridad: Canal 15 VHF (156.750 MHz).\n\nConsejo del Baqueano: El practicaje es obligatorio en toda esta zona. Sintonizá el Canal 15 en horarios específicos (0310, 0710, etc.) para alertas de navegación. Las urgencias médicas también se cursan por el Canal 14 directamente a la estación L6I."
      ],
      "tipos": [
        "Canal 14 VTS Rosario L6I (Trabajo/Médico)",
        "Canal 15 PNA (Seguridad)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "que_sirve_frecuencia_rio_de_la_plata_sector1": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS RÍO DE LA PLATA - SECTOR 1\n\nCubre la crítica zona de ingreso y egreso por el Estacionario de Prácticos Recalada (Km 239,1) y el Canal Paso Banco Chico.\n\nDetalles técnicos:\n- Estación: VTS Río de la Plata (Indicativo L2G) / Estacionario Prácticos (L3Z).\n- Canal de Trabajo VTS: Canal 12 VHF (156.600 MHz).\n\nConsejo del Baqueano: Toda embarcación debe reportarse a L2G al pasar los puntos de control. Si vas a requerir zona de fondeo cerca de Recalada, comunicate con el estacionario L3Z en el Canal 12. La escucha en el Canal 16 es obligatoria."
      ],
      "tipos": [
        "Canal 12 L2G / L3Z (Trabajo y Fondeo)",
        "Canal 15 PNA (Seguridad)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "donde_sirve_frecuencia_rio_de_la_plata_sector2": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS RÍO DE LA PLATA - SECTOR 2 (PTO. BUENOS AIRES)\n\nAbarca el Canal de Acceso al Puerto de Buenos Aires (desde el Km 37), el Canal Norte, Sur y los movimientos portuarios internos.\n\nDetalles técnicos:\n- Estación: VTS Río de la Plata (Indicativo L2G).\n- Canal de Trabajo: Canal 09 VHF (156.450 MHz).\n- Prácticos en Rada La Plata: Canal 09 VHF.\n\nConsejo del Baqueano: Si ingresás a la zona del puerto o necesitás embarcar/desembarcar prácticos en Rada La Plata, pasate sí o sí al Canal 09. Las consultas médicas de la zona también se derivan por este canal."
      ],
      "tipos": [
        "Canal 09 L2G (Trabajo/Portuario)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "que_sirve_frecuencia_rio_de_la_plata_sector4": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS RÍO DE LA PLATA - SECTOR 4 (CANAL MARTÍN GARCÍA)\n\nControla el intenso tráfico fluvial desde el Km 39 hasta el Km 93 del Canal Martín García.\n\nDetalles técnicos:\n- Estación: VTS Río de la Plata (Indicativo L2G).\n- Canales de Trabajo: Canal 81 VHF (157.075 MHz and 161.675 MHz).\n\nConsejo del Baqueano: Navegá con atención; pasando el Km 93 inicia la jurisdicción de la Autoridad Marítima Uruguaya. Sintonizá el Canal 15 cada cuatro horas exactas (0000, 0400, etc.) para mantenerte actualizado con los reportes de seguridad."
      ],
      "tipos": [
        "Canal 81 L2G (Trabajo Martín García)",
        "Canal 15 PNA (Seguridad)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "donde_sirve_frecuencia_ushuaia_portuario": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS USHUAIA PORTUARIO (CANAL BEAGLE)\n\nAbarca el estratégico Canal Beagle en aguas argentinas, operando los cruces del Límite Internacional con Chile.\n\nDetalles técnicos:\n- Estación: VTS Ushuaia Portuario (Indicativo L3P).\n- Canal de Trabajo Principal: Canal 12 VHF (156.600 MHz).\n- Estaciones Secundarias: L4A (Lapataia), L4B (Almanza), L4C (Benítez), L4D (López).\n\nConsejo del Baqueano: Escucha simultánea en Canal 12 y 16 es mandatoria. Cada vez que cruces un punto de control (como el Paso Picton o el Canal Murray), debés reportarte a la estación secundaria correspondiente."
      ],
      "tipos": [
        "Canal 12 L3P / L4A / L4B / L4C / L4D (Trabajo)",
        "Canal 15 PNA (Seguridad/Clima)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "como_se_hace_comunicacion_ushuaia_maritimo": {
      "respuestas_puente": [
        "📻 FRECUENCIAS VTS USHUAIA MARÍTIMO (HF)\n\nCoordina el Mar Austral, desde el paralelo 54° 30' Sur hasta el límite exterior de la ZEE Argentina.\n\nDetalles técnicos:\n- Estación: VTS Ushuaia Marítimo (Indicativo L3O).\n- Frecuencias de Trabajo MF/HF: 2065 kHz and 4354 kHz.\n- NAVTEX (MF): 518 kHz (Inglés) and 490 kHz (Español).\n\nConsejo del Baqueano: Las gigantescas distancias patagónicas exigen equipos HF. Los pesqueros deben reportarse religiosamente a las 0900, 1500 y 2300 UTC. Toda comunicación de emergencia o médica por radio queda respaldada y grabada."
      ],
      "tipos": [
        "MF/HF 2065 kHz / 4354 kHz (Trabajo L3O)",
        "NAVTEX 518 kHz / 490 kHz",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "donde_sirve_frecuencia_san_isidro": {
      "respuestas_puente": [
        "📻 FRECUENCIAS DE PREFECTURA SAN ISIDRO\n\nSupervisa una de las zonas con mayor tráfico náutico y deportivo de todo el Río de la Plata.\n\nDetalles técnicos:\n- Estación Costera: San Isidro (Indicativo L5J).\n- Canal de Llamada y Emergencia: Canal 16 VHF.\n\nConsejo del Baqueano: Debido a la altísima cantidad de veleros, lanchas y cruceros en la zona, el uso del Canal 16 debe ser de extrema responsabilidad. Usalo únicamente para emergencias o llamadas iniciales muy cortas."
      ],
      "tipos": [
        "Canal 16 L5J (Emergencia y Socorro)"
      ]
    },
    "donde_sirve_frecuencia_parana_diamante": {
      "respuestas_puente": [
        "📻 FRECUENCIAS DE PREFECTURA PARANÁ Y DIAMANTE\n\nControlan el complejo tramo del Río Paraná Medio, abarcando desde el Km 480 hasta el Km 677.\n\nDetalles técnicos:\n- Estación Diamante: Indicativo L6M (Km 480 al 568).\n- Estación Paraná: Indicativo L6N (Km 568 al 677).\n- Canal de Trabajo Fluvial: Canal 12 VHF.\n\nConsejo del Baqueano: Ojo en esta zona, en los ríos interiores con abundante vegetación la señal VHF puede atenuarse porque los árboles actúan como una 'jaula de Faraday'. Asegurate de tener la antena impecable para comunicarte con L6N o L6M."
      ],
      "tipos": [
        "Canal 12 L6M Diamante (Trabajo)",
        "Canal 12 L6N Paraná (Trabajo)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "que_sirve_frecuencia_buenos_aires_mitre": {
      "respuestas_puente": [
        "📻 FRECUENCIAS BUENOS AIRES Y CANAL EMILIO MITRE\n\nZona de bifurcación neurálgica que abarca accesos al Canal Costanero, Canal Emilio Mitre y rutas de navegación al Delta y Río Honda.\n\nDetalles técnicos:\n- Estación Buenos Aires: Indicativo L2A (Canal 14 VHF).\n- Estación Dto. Braga: Indicativo L5L (Canal 16 y 72 VHF, cubre Canal Emilio Mitre).\n- Estación Martín García: Indicativo L5P (Canal 16 y 72 VHF).\n\nConsejo del Baqueano: Hay mucha convivencia entre buques mercantes y nautas deportivos. L2A emite reportes valiosos por Canal 14, pero si navegás por el Canal Emilio Mitre debés comunicarte en el 72 con la costera Braga L5L."
      ],
      "tipos": [
        "Canal 14 L2A Buenos Aires (Seguridad/Rutas)",
        "Canal 72 L5L Braga (Trabajo Canal E. Mitre)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "donde_sirve_frecuencia_san_pedro_nicolas": {
      "respuestas_puente": [
        "📻 FRECUENCIAS DE PREFECTURA SAN PEDRO Y SAN NICOLÁS\n\nFiscalizan el corazón productivo portuario del Río Paraná, comprendido entre el Km 240 y el Km 376.\n\nDetalles técnicos:\n- Estación San Pedro: Indicativo L6E (Km 240 a 310).\n- Estación San Nicolás: Indicativo L6G (Km 310 a 376).\n- Canal de Trabajo Fluvial: Canal 12 VHF.\n\nConsejo del Baqueano: Estás en una autopista de buques de gran porte (Panamax, graneleros). Siempre modulá por Canal 12 para coordinar maniobras de cruce con los buques y reportar tu posición a PNA."
      ],
      "tipos": [
        "Canal 12 L6E San Pedro (Trabajo)",
        "Canal 12 L6G San Nicolás (Trabajo)",
        "Canal 16 PNA (Emergencia)"
      ]
    },
    "cuando_se_usa_frecuencia_posadas_formosa": {
      "respuestas_puente": [
        "📻 FRECUENCIAS DEL ALTO PARANÁ Y ZONA NORTE\n\nEstaciones fundamentales para la seguridad de navegación y el control del tráfico en el litoral norte argentino.\n\nDetalles técnicos:\n- Estación Formosa: Indicativo L8I (Km 1360 a 1520 Río Paraná/Paraguay).\n- Estación Posadas: Indicativo L7N (Km 1522 a 1710 Río Paraná).\n- Canal de Trabajo General: Canal 12 VHF.\n\nConsejo del Baqueano: En aguas compartidas, tener el radio encendido y con buen alcance es esencial. El Canal 12 VHF te mantiene en línea directa con PNA Posadas o Formosa para reportes de entrada/salida o incidentes climáticos rápidos."
      ],
      "tipos": [
        "Canal 12 L7N Posadas (Trabajo)",
        "Canal 12 L8I Formosa (Trabajo)",
        "Canal 16 PNA (Emergencia)"
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
