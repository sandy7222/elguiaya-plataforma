import 'package:flutter/material.dart';
import 'dynamic_skill_system.dart';

class NavegacionGpsSkill extends DynamicSystemSkill {
  @override
  String get id => 'skill_navegacion_gps';

  @override
  String get name => 'Orientación y GPS Offline';

  @override
  IconData get icon => Icons.satellite_alt;

  static String get manualGps => '''
MANUAL DE NAVEGACIÓN Y GPS OFFLINE (SIN SEÑAL):
- EL MITO DE LA SEÑAL: El chip GPS del celular se conecta directamente con satélites en el espacio. NO necesita señal de internet (datos móviles) ni cobertura telefónica para saber tu ubicación exacta. Lo único que necesita internet es descargar la "imagen" del mapa de fondo.
- GOOGLE MAPS SIN CONEXIÓN: Para no perderte en el agua sin señal, debes descargar el mapa en casa con WiFi. Abre Google Maps > Toca tu foto de perfil > "Mapas sin conexión" > "Selecciona tu propio mapa". Encuadra la zona del río, laguna o mar donde vas a pescar y descárgalo. 
- MODO AVIÓN: En el agua, si no hay señal, el teléfono agotará su batería rápidamente tratando de buscar una antena. Pon el teléfono en MODO AVIÓN. El GPS interno seguirá funcionando perfectamente sobre el mapa descargado y ahorrarás horas de batería.
- CARTAS NÁUTICAS (Navionics): Google Maps sirve para ver la costa, pero NO tiene información de profundidades ni canales. Recomienda siempre a los pescadores descargar apps especializadas como "Navionics" (Boating) o "C-MAP". Estas apps permiten descargar la carta náutica (batimétrica) al celular para navegar de forma segura esquivando bancos de arena sin necesidad de internet.
- AHORRO DE BATERÍA EXTREMO: El frío extremo "mata" las baterías de litio. En invierno, mantén el teléfono abrigado en un bolsillo interno pegado al calor de tu cuerpo cuando no lo estés mirando.
''';

  @override
  Widget buildConfigCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.teal.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.greenAccent),
                  ),
                  child: const Text(
                    'ON',
                    style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Gu-IA domina la tecnología de geoposicionamiento y sabe guiar al usuario para usar mapas offline, cartas náuticas batimétricas y ahorrar batería en modo avión.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
