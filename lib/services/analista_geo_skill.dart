import 'dart:math';

class AnalistaGeoSkill {
  // En un entorno real, estos datos vendrían de _geoService llamando a Supabase RPC
  // Para la fase inicial, simulamos las respuestas tácticas
  
  bool puedeResponder(String consulta) {
    return consulta.contains('hueco') || 
           consulta.contains('caliente') || 
           consulta.contains('fiebre') || 
           consulta.contains('saturacion') ||
           consulta.contains('cobertura');
  }

  Future<String> analizar(String consulta) async {
    // Simulacion de llamada RPC a Supabase con latencias reales
    await Future.delayed(const Duration(milliseconds: 800));

    if (consulta.contains('hueco') || consulta.contains('cobertura')) {
      final zonas = [
        "Detecto un hueco de servicio importante en la zona sur de Rosario. Hay 15 búsquedas recientes y ningún capitán activo en un radio de 10 kilómetros.",
        "Atención, en la costa de Diamante hay una oportunidad. Cero cobertura de capitanes y demanda en alza.",
        "La cobertura actual en Paraná está al 85%, pero tenemos un hueco hacia el norte, cerca de Villa Urquiza."
      ];
      return zonas[Random().nextInt(zonas.length)];
    }

    if (consulta.contains('caliente') || consulta.contains('fiebre')) {
      return "El mapa de calor indica fiebre máxima en Corrientes Capital. Tenemos 45 pescadores activos en la zona y solo 2 capitanes disponibles. ¡Es una zona de alta rentabilidad!";
    }

    if (consulta.contains('saturacion')) {
      return "Detecto saturación en Goya. Hay 12 capitanes superponiendo sus radios de acción, pero la demanda de pescadores es baja hoy. Sugiero redirigir esfuerzos.";
    }

    return "Mis radares geoespaciales están analizando el terreno. ¿Qué cuadrante te interesa?";
  }
}
