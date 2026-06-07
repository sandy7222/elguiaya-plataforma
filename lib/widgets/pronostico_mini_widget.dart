import 'package:flutter/material.dart';
import 'dart:ui';
import '../screens/pronostico_screen.dart';
import '../services/weather_service.dart';
import '../services/location_preference_service.dart';

class PronosticoMiniWidget extends StatefulWidget {
  final double lat;
  final double lon;

  const PronosticoMiniWidget({
    super.key,
    this.lat = -34.442,
    this.lon = -58.558,
  });

  @override
  State<PronosticoMiniWidget> createState() => _PronosticoMiniWidgetState();
}

class _PronosticoMiniWidgetState extends State<PronosticoMiniWidget> {
  MarineWeather? _weather;
  bool _isLoading = true;
  String? _localidadName;

  @override
  void initState() {
    super.initState();
    _cargarClima();
  }

  Future<void> _cargarClima() async {
    try {
      final loc = await LocationPreferenceService.getPredefinedLocation();
      final weather = await WeatherService.fetchMarineWeather(loc.latitude, loc.longitude);
      if (mounted) {
        setState(() {
          _weather = weather;
          _localidadName = loc.name;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        height: 120,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF001F3F).withOpacity(0.95),
          borderRadius: BorderRadius.circular(25),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: const CircularProgressIndicator(color: Colors.amber),
      );
    }

    final weather = _weather ?? MarineWeather(
      temperatura: 22.0,
      velocidadViento: 12.0,
      direccionViento: 45.0,
      alturaOlas: 0.4,
      humedad: 65,
      presion: 1013.0,
      descripcion: "IDEAL PARA PESCA",
      pronosticoExtendido: const [],
      pronosticoHorario: const [],
    );

    // Mapear icono y color según el clima y la hora del día (Día vs Noche)
    final hora = DateTime.now().hour;
    final esNoche = hora < 6 || hora > 19;

    IconData climaIcon = esNoche ? Icons.nightlight_round : Icons.wb_sunny_rounded;
    Color iconColor = esNoche ? const Color(0xFFE2E8F0) : Colors.amberAccent; // Moon silver vs Sun amber

    if (weather.velocidadViento > 25.0) {
      climaIcon = Icons.thunderstorm_rounded;
      iconColor = Colors.lightBlueAccent;
    } else if (weather.velocidadViento > 15.0) {
      climaIcon = Icons.cloud_queue_rounded;
      iconColor = Colors.white70;
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context, 
        MaterialPageRoute(builder: (context) => PronosticoScreen(lat: widget.lat, lon: widget.lon))
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF00152B).withOpacity(0.96),
                  const Color(0xFF002244).withOpacity(0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Izquierda: Icono grande con tonos sombreados/resplandor + Temperatura
                      Row(
                        children: [
                          _buildGlowIcon(climaIcon, iconColor, 48),
                          const SizedBox(width: 12),
                          Text(
                            '${weather.temperatura.toStringAsFixed(1)}°C', 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 28, 
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      // Derecha: Localidad en mayúsculas + Estado del clima
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_outlined, 
                                    color: Colors.white70, 
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      (_localidadName ?? '').toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                weather.descripcion.split(' - ').first.toUpperCase(), 
                                style: const TextStyle(
                                  color: Colors.amberAccent, 
                                  fontSize: 10, 
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(color: Colors.white12, thickness: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMiniDetail(Icons.air, '${weather.velocidadViento.toStringAsFixed(1)}km/h'),
                    _buildMiniDetail(Icons.water_drop, '${weather.humedad}%'),
                    _buildMiniDetail(Icons.waves, '${weather.alturaOlas.toStringAsFixed(1)}m'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniDetail(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildGlowIcon(IconData icon, Color color, double size) {
    return Stack(
      alignment: Alignment.center,
      children: [
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Icon(
            icon,
            color: color.withOpacity(0.35),
            size: size + 4,
          ),
        ),
        Icon(
          icon,
          color: color,
          size: size,
        ),
      ],
    );
  }
}
