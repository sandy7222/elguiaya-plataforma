import 'package:flutter/material.dart';
import 'dynamic_skill_system.dart';

class EmergenciaNauticaSkill extends DynamicSystemSkill {
  @override
  String get id => 'skill_emergencia_nautica';

  @override
  String get name => 'Protocolo de Emergencia PNA';

  @override
  IconData get icon => Icons.local_hospital;

  static String get protocoloEmergencia => '''
PROTOCOLO DE EMERGENCIA NÁUTICA Y PRIMEROS AUXILIOS (PNA):
- RADIOCOMUNICACIONES Y VHF (SECOSENA): Ante emergencias, el CANAL 16 (156.800 MHz) es la frecuencia universal y tiene prioridad absoluta. Sin embargo, Prefectura Naval Argentina opera y atiende según su zona geográfica utilizando Canales Operativos: 9, 12, 14, 15, 70, 72 y 77 (el Canal 15 es de uso frecuente en casi todo el país, mientras que grandes estaciones como Buenos Aires L2G operan en todos ellos simultáneamente). Una vez establecido el contacto, la comunicación debe pasarse al Canal 12 (canal de trabajo). Para hablar entre barcos civiles usar Canal 6 u 8. Los clubes náuticos suelen usar Canal 71, 68 o 10. En Parques Nacionales la emergencia es por 142.800 MHz (Guardaparques) y en áreas terrestres inhóspitas 140.970 MHz. Vía teléfono, llamar gratis al 106.
- ANZUELOS CLAVADOS: Si es superficial, usar el "Método de la Cuerda" (lazo en la curva y tirón seco) o "Atravesar y Cortar" (pasar la púa, cortarla con alicate y retroceder). NUNCA cerrar herméticamente la herida con cinta. Si el anzuelo está en el OJO o zonas críticas: NO EXTRAER. Tapar AMBOS ojos (para evitar el movimiento reflejo) y evacuar de urgencia.
- CHUZAS DE BAGRE Y RAYA: Inoculan toxinas. El tratamiento infalible es aplicar AGUA MUY CALIENTE (fomentos) sobre la herida; el calor desnaturaliza la toxina y frena el dolor. Los pescadores baquianos también usan orín o frotan el ojo del bagre en la herida como remedio de urgencia. A las rayas hay que agarrarlas de los orificios nasales o pisarles la cola con un palo.
- MORDEDURA DE SERPIENTES (Yarará, Cascabel, Coral): Emergencia extrema. Solicitar SUERO ANTIOFÍDICO por radio. NO hacer cortes ni cauterizar. El torniquete es solo un método "heroico" de último recurso (debe aflojarse 1 minuto cada 10).
- MEDUSAS (Aguas Vivas): Lavar SOLO CON AGUA DE MAR (el agua dulce empeora el ardor). No frotar. Aplicar vinagre blanco o alcohol, y finalizar frotando arena seca.
- HIPOTERMIA Y AHOGAMIENTO: Iniciar RCP. Si la víctima está helada y sin pulso, NO ASUMIR LA MUERTE (la hipotermia induce "muerte aparente"). NO intentar un recalentamiento agresivo a bordo porque puede causar arritmias letales; simplemente cambiar ropa mojada por mantas secas y evacuar al hospital.
- BOTIQUÍN: Para dolor usar Paracetamol. NO aplicar pomadas si la piel está rasgada. Nunca administrar medicamentos fuertes (como Morfina) sin estricto asesoramiento médico por radio.
''';

  @override
  Widget buildConfigCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.red.shade900,
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
                    color: Colors.redAccent.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent),
                  ),
                  child: const Text(
                    'CRÍTICO',
                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Gu-IA está entrenado para reconocer situaciones de peligro y proveer instantáneamente los canales de comunicación de la Prefectura Naval Argentina (VHF 16 y línea 106).',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
