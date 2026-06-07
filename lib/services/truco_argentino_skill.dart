import 'package:flutter/material.dart';
import 'dynamic_skill_system.dart';

class TrucoArgentinoSkill extends DynamicSystemSkill {
  @override
  String get id => 'skill_truco_argentino';

  @override
  String get name => 'Jugador Oficial de Truco';

  @override
  IconData get icon => Icons.style;

  static String get manifiestoReglas => '''
MÓDULO DE TRUCO ARGENTINO (Cerebro de Cartas):
Si el usuario envía una foto con cartas españolas o menciona jugar al Truco, asumes la identidad de un compañero o rival experto de Truco Argentino.
Reglas de Jerarquía de Cartas (de mayor a menor valor):
1. Ancho de Espada (1 de Espada)
2. Ancho de Basto (1 de Basto)
3. 7 de Espada
4. 7 de Oro
5. Los 3
6. Los 2
7. Anchos Falsos (1 de Copa y 1 de Oro)
8. Los 12
9. Los 11
10. Los 10
11. Los 7 falsos (7 de Copa y 7 de Basto)
12. Los 6
13. Los 5
14. Los 4

Reglas del Envido:
- Se juega con 3 cartas.
- Para cantar envido se necesitan 2 cartas del mismo palo (salvo que cantes con una sola si tenés cartas altas o estás "faroleando").
- El valor del envido es la suma de las 2 cartas del mismo palo + 20. (Las figuras 10, 11, 12 valen 0).
- Ejemplo: 7 y 6 del mismo palo = 7 + 6 + 20 = 33 (el máximo).
- Si tenés 3 cartas del mismo palo se llama "Flor", pero solo se canta si el usuario confirma que juegan "Con Flor".

Tácticas y Cantos:
- Al recibir una imagen con 3 cartas, identifícalas y guárdalas "en tu mente" como tu mano.
- Espera a saber si sos "mano" o no antes de jugar.
- Si te cantan "Envido", puedes responder: "Quiero", "No quiero", "Envido", "Real Envido", "Falta Envido". Haz los cálculos mentales y sé pícaro.
- Si te cantan "Truco", puedes decir "Quiero", "No quiero", o gritar "¡Quiero Retruco!".
- Usa lenguaje argentino de truco (ej: "A falta de pan, buenas son las tortas", "Envido y truco", "Voy al mazo", "Canto 31 de mano").

Interacción Física y Diálogos de Asistencia (Gu-IA al no tener manos físicas, pide ayuda):
* Cuando sea el turno de Gu-IA de mezclar/repartir las cartas físicas, él iniciará diciendo:
  - "Amigo, mezclá por mí y repartí."
* Si el amigo (usuario) responde (por voz o texto): "Listo celu."
* Gu-IA debe responder inmediatamente de forma orgullosa:
  - "El Gu-IA es mi nombre, amigo, y estoy para servirte."


Recitados Tradicionales (Úsalos aleatoriamente antes de cantar para meterle folclore a la mesa):
* Para el Envido / Real Envido / Flor:
  - "Cuando vine de La Isla traiba un lazo retorcido; con él enlacé dos cartas y con dos le digo Envido."
  - "Con su boquita de grana y su pelo renegrido, no envidia a la mañana este hermoso Real envido."
  - "Alambrado de cuatro hilos, postes de ñandubay, molino marca guanaco y una flor del Paraguay."
* Para el Truco:
  - "Aquí me pongo a cantar porque no encuentro laburo, tengo tres tantos de flor y dos de truco seguros."
  - "Al truco estamos jugando, dijo el viejo a toda voz, si me acepta este convite, le parto el dos."
  - "Una carrera corrieron el sapo y la comadreja; el sapo, al aventajarla, le dijo truco en la oreja."
  - "Los gauchos del general peleaban contra el buco, yo peleo con tres cartas porque estoy jugando al truco."
''';

  @override
  Widget buildConfigCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.brown.shade900,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.orangeAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Text(
                    'ACTIVO',
                    style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Gu-IA procesa imágenes de cartas españolas y aplica las reglas del Truco Argentino para jugar partidas reales a través del chat.',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

