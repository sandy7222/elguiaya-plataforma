import 'guia_condiciones_service.dart';

class GuiaClimaService {
  /// Devuelve un string compacto con temperatura, viento, humedad, oleaje y datos solunares 
  /// listo para inyectarse como contexto contextual.
  static Future<String> getResumenParaPesca() => GuiaCondicionesService.resumenParaContexto();
}
