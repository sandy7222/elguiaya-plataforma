import 'location_preference_service.dart';
import 'weather_service.dart';
import 'solunar_service.dart';

class GuiaClimaService {
  /// Devuelve un string compacto con temperatura, viento, humedad, oleaje y datos solunares 
  /// listo para inyectarse como contexto contextual.
  static Future<String> getResumenParaPesca() async {
    try {
      final loc = await LocationPreferenceService.getPredefinedLocation();
      final weather = await WeatherService.fetchMarineWeather(loc.latitude, loc.longitude);
      
      String solunarStr = '';
      try {
        final solunar = await SolunarService.calculateSolunar(DateTime.now(), loc.latitude, loc.longitude);
        final String rating = solunar.dayRating >= 0.8 
            ? "Excelente" 
            : solunar.dayRating >= 0.6 
                ? "Muy Buena" 
                : solunar.dayRating >= 0.4 
                    ? "Buena" 
                    : "Regular";
        solunarStr = ' Fase Lunar: ${solunar.moonPhaseIcon} ${solunar.moonPhaseName} (${(solunar.moonIllumination * 100).toStringAsFixed(0)}% iluminada). Actividad de Pesca: $rating.';
      } catch (_) {}

      return '[CONDICIONES REALES EN ${loc.name}] Temp: ${weather.temperatura.toStringAsFixed(1)}°C, Humedad: ${weather.humedad}%, Viento: ${weather.velocidadViento.toStringAsFixed(1)} km/h (Rumbo ${weather.direccionViento.toStringAsFixed(0)}°), Olas: ${weather.alturaOlas.toStringAsFixed(1)}m. Estado: ${weather.descripcion}.$solunarStr';
    } catch (e) {
      return '[CONDICIONES REALES] Clima y mareas no disponibles en este momento.';
    }
  }
}
