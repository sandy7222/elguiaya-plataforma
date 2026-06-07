import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import '../services/weather_service.dart';
import '../services/location_preference_service.dart';

class PronosticoScreen extends StatefulWidget {
  final double lat;
  final double lon;

  const PronosticoScreen({
    super.key,
    this.lat = -34.442,
    this.lon = -58.558,
  });

  @override
  State<PronosticoScreen> createState() => _PronosticoScreenState();
}

class _PronosticoScreenState extends State<PronosticoScreen> {
  MarineWeather? _weather;
  bool _isLoading = true;

  // Ubicación seleccionada actualmente
  double? _currentLat;
  double? _currentLon;
  String? _customLocationName;

  // Controlador e historial de búsqueda
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearchingLoc = false;

  // Controladores de Pestaña y Unidades (Nudos vs Km/h)
  int _activeTab = 0; // 0: Pronóstico del Tiempo, 1: Vientos Náuticos (Kayakistas)
  bool _useKnots = true; // Por defecto en Nudos (kt) para Kayakistas

  // Día seleccionado para el filtro de horas de viento
  int _selectedDayOffset = 0; // 0: Hoy, 1: Mañana, 2: Pasado Mañana

  // Filtro de "Fetch" / Tipo de Agua (Replicación Windguru)
  String _waterType = "abierta"; // "abierta" (Río de la Plata / Mar Abierto), "cerrada" (Río angosto / Laguna)

  @override
  void initState() {
    super.initState();
    _inicializarUbicacion();
  }

  Future<void> _inicializarUbicacion() async {
    final loc = await LocationPreferenceService.getPredefinedLocation();
    if (mounted) {
      setState(() {
        _currentLat = loc.latitude;
        _currentLon = loc.longitude;
        _customLocationName = loc.name;
      });
      _cargarDatos();
    }
  }

  Future<void> _cargarGPSActual() async {
    if (mounted) setState(() => _isLoading = true);
    final gpsLoc = await LocationPreferenceService.getCurrentGPSLocation();
    if (mounted) {
      setState(() {
        _currentLat = gpsLoc.latitude;
        _currentLon = gpsLoc.longitude;
        _customLocationName = gpsLoc.name;
      });
      _cargarDatos();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ubicación GPS sincronizada: ${_currentLat!.toStringAsFixed(3)}, ${_currentLon!.toStringAsFixed(3)}'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _establecerPredefinido() async {
    if (_currentLat == null || _currentLon == null) return;
    final name = _obtenerNombreUbicacion();
    await LocationPreferenceService.savePredefinedLocation(_currentLat!, _currentLon!, name);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Guardada como ubicación predeterminada: $name'),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _cargarDatos() async {
    try {
      final data = await WeatherService.fetchMarineWeather(
        _currentLat ?? widget.lat,
        _currentLon ?? widget.lon,
      );
      if (mounted) {
        setState(() {
          _weather = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _buscarUbicacion(String query) async {
    if (query.trim().length < 3) {
      setState(() {
        _searchResults = [];
        _isSearchingLoc = false;
      });
      return;
    }

    setState(() => _isSearchingLoc = true);
    final results = await WeatherService.searchLocations(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearchingLoc = false;
      });
    }
  }

  String _obtenerNombreUbicacion() {
    if (_customLocationName != null) return _customLocationName!;

    final lat = _currentLat ?? widget.lat;
    if ((lat - -38.005).abs() < 0.1) {
      return "MAR DEL PLATA, AR";
    } else if ((lat - -42.769).abs() < 0.1) {
      return "PUERTO MADRYN, AR";
    } else if ((lat - -36.357).abs() < 0.1) {
      return "SAN CLEMENTE, AR";
    }
    return "SAN FERNANDO, BA";
  }

  IconData _mapCodeToIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code >= 1 && code <= 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.filter_drama_rounded;
    if ((code >= 51 && code <= 55) || (code >= 61 && code <= 65) || (code >= 80 && code <= 82)) {
      return Icons.umbrella_rounded;
    }
    if (code >= 71 && code <= 75) return Icons.ac_unit_rounded;
    if (code >= 95 && code <= 99) return Icons.thunderstorm_rounded;
    return Icons.wb_cloudy_rounded;
  }

  int _getBeaufortScale(double windSpeedKmH) {
    final double knots = windSpeedKmH * 0.539957;
    if (knots < 1.0) return 0;
    if (knots <= 3.0) return 1;
    if (knots <= 6.0) return 2;
    if (knots <= 10.0) return 3;
    if (knots <= 16.0) return 4;
    if (knots <= 21.0) return 5;
    if (knots <= 27.0) return 6;
    return 7;
  }

  @override
  Widget build(BuildContext context) {
    if (_weather == null && !_isLoading) {
      _weather = MarineWeather(
        temperatura: 22.0,
        velocidadViento: 12.0,
        direccionViento: 45.0,
        alturaOlas: 0.4,
        humedad: 65,
        presion: 1013.0,
        descripcion: "MODO SIN CONEXIÓN - CLIMA ESTIMADO",
        pronosticoExtendido: [
          ExtendedForecastDay(diaSemana: 'HOY', temperaturaMax: 22.0, weatherCode: 0),
          ExtendedForecastDay(diaSemana: 'MAÑ', temperaturaMax: 23.0, weatherCode: 0),
          ExtendedForecastDay(diaSemana: 'PAS', temperaturaMax: 21.0, weatherCode: 0),
          ExtendedForecastDay(diaSemana: 'SAB', temperaturaMax: 24.0, weatherCode: 0),
          ExtendedForecastDay(diaSemana: 'DOM', temperaturaMax: 25.0, weatherCode: 0),
        ],
        pronosticoHorario: [],
      );
    }

    final locationName = _obtenerNombreUbicacion();
    final String fechaHoy = DateFormat("EEEE, d 'de' MMMM", 'es').format(DateTime.now());

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CENTRO METEOROLÓGICO', 
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, color: Colors.white, fontSize: 13)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.star_border_rounded, color: Colors.amber),
            tooltip: 'Establecer como Predefinido',
            onPressed: _establecerPredefinido,
          ),
          IconButton(
            icon: const Icon(Icons.gps_fixed_rounded, color: Colors.white70),
            tooltip: 'Usar GPS del Celular',
            onPressed: _cargarGPSActual,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF001F3F), // Azul Marino profundo
              Color(0xFF004080), // Azul Oceánico
              Color(0xFF001F3F), 
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Buscador de zona
                _buildSearchBar(),

                if (_isLoading)
                  const SizedBox(
                    height: 350,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.amber),
                    ),
                  )
                else ...[
                  // 2. Selector de Pestañas (Pronóstico vs Vientos Náuticos)
                  _buildTabSelector(),
                  const SizedBox(height: 15),

                  // 3. Contenido según pestaña activa
                  _activeTab == 0 
                      ? _buildTabPronosticoGeneral(locationName, fechaHoy)
                      : _buildTabVientosNauticos(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Buscar zona (ej: Isla del Cerrito, San Clemente)...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
              prefixIcon: const Icon(Icons.search, color: Colors.amber, size: 18),
              suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white70, size: 14),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchResults = []);
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onChanged: _buscarUbicacion,
          ),
          if (_isSearchingLoc)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(color: Colors.amber, strokeWidth: 2),
              ),
            ),
          if (_searchResults.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final result = _searchResults[index];
                  final name = result['name'] ?? '';
                  final admin = result['admin1'] ?? '';
                  final country = result['country'] ?? '';
                  final lat = (result['latitude'] as num).toDouble();
                  final lon = (result['longitude'] as num).toDouble();
                  
                  final displayName = "$name, $admin ($country)";
                  
                  return ListTile(
                    dense: true,
                    title: Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                    subtitle: Text("Lat: ${lat.toStringAsFixed(3)}, Lon: ${lon.toStringAsFixed(3)}", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.amber, size: 11),
                    onTap: () {
                      _searchController.clear();
                      setState(() {
                        _currentLat = lat;
                        _currentLon = lon;
                        _customLocationName = "${name.toUpperCase()}, ${country.toUpperCase()}";
                        _searchResults = [];
                        _isLoading = true;
                      });
                      _cargarDatos();
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(0, '🌤️ PRONÓSTICO'),
          ),
          Expanded(
            child: _buildTabButton(1, '🌬️ VIENTOS NÁUTICOS'),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 11,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  // --- PESTAÑA 1: PRONÓSTICO GENERAL ---
  Widget _buildTabPronosticoGeneral(String location, String date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCurrentWeatherCard(location, date),
        const SizedBox(height: 20),
        const Text('DETALLES NÁUTICOS', 
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        _buildWeatherGrid(),
        const SizedBox(height: 25),
        const Text('PRONÓSTICO EXTENDIDO (5 DÍAS)', 
          style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.2)),
        const SizedBox(height: 10),
        _buildExtendedForecast(),
        const SizedBox(height: 30),
        _buildSafetyWarning(),
      ],
    );
  }

  Widget _buildCurrentWeatherCard(String location, String date) {
    final weather = _weather!;
    IconData mainIcon = Icons.wb_sunny_rounded;
    if (weather.velocidadViento > 25.0) {
      mainIcon = Icons.thunderstorm_rounded;
    } else if (weather.velocidadViento > 15.0) {
      mainIcon = Icons.cloud_rounded;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location, 
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(date, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(mainIcon, color: Colors.amber, size: 34),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weather.temperatura.toStringAsFixed(1), 
                    style: const TextStyle(color: Colors.white, fontSize: 50, fontWeight: FontWeight.w200),
                  ),
                  const Text('°C', style: TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                weather.descripcion, 
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, letterSpacing: 1.2, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherGrid() {
    final weather = _weather!;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        _buildInfoTile(Icons.air, 'VIENTO', '${weather.velocidadViento.toStringAsFixed(1)} km/h', 'Rumbo ${weather.direccionViento.toStringAsFixed(0)}°'),
        _buildInfoTile(Icons.water_drop, 'HUMEDAD', '${weather.humedad}%', 'Relativa'),
        _buildInfoTile(Icons.compress, 'PRESIÓN', '${weather.presion.toStringAsFixed(0)} hPa', 'Estable'),
        _buildInfoTile(Icons.waves, 'OLEAJE', '${weather.alturaOlas.toStringAsFixed(1)} m', 'Frecuencia estable'),
      ],
    );
  }

  Widget _buildInfoTile(IconData icon, String label, String value, String subValue) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.amber, size: 14),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(subValue, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8)),
        ],
      ),
    );
  }

  Widget _buildExtendedForecast() {
    final weather = _weather!;
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weather.pronosticoExtendido.length,
        itemBuilder: (context, index) {
          final day = weather.pronosticoExtendido[index];
          return Container(
            width: 70,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(day.diaSemana, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 9)),
                const SizedBox(height: 6),
                Icon(_mapCodeToIcon(day.weatherCode), color: Colors.amber, size: 18),
                const SizedBox(height: 6),
                Text('${day.temperaturaMax.toStringAsFixed(0)}°', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSafetyWarning() {
    final weather = _weather!;
    String warningTitle = "AVISO NÁUTICO";
    String warningText = "Condiciones estables para navegación deportiva. Verifique equipo de seguridad.";
    Color warningColor = Colors.orange;

    if (weather.velocidadViento > 25.0 || weather.alturaOlas > 1.8) {
      warningTitle = "AVISO DE TORMENTA Y TEMPORAL";
      warningText = "Peligro severo para embarcaciones menores. Se aconseja suspender salidas al agua.";
      warningColor = Colors.redAccent;
    } else if (weather.velocidadViento > 15.0 || weather.alturaOlas > 1.2) {
      warningTitle = "ALERTA DE VIENTOS Y MAREJADA";
      warningText = "Navegar con extrema precaución. Monitorear reportes de Prefectura Naval.";
      warningColor = Colors.yellowAccent;
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [warningColor.withOpacity(0.12), Colors.transparent]),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: warningColor.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: warningColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(warningTitle, style: TextStyle(color: warningColor, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.8)),
                const SizedBox(height: 4),
                Text(warningText, style: const TextStyle(color: Colors.white70, fontSize: 9)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PESTAÑA 2: VIENTOS NÁUTICOS (KAYAKISTAS - REPLICACIÓN WINDGURU) ---
  Widget _buildTabVientosNauticos() {
    final weather = _weather!;
    
    // Agrupar predicción horaria por día
    final today = DateTime.now();
    final List<HourlyForecast> filteredHours = weather.pronosticoHorario.where((item) {
      if (_selectedDayOffset == 0) {
        return item.hora.day == today.day;
      } else if (_selectedDayOffset == 1) {
        final tomorrow = today.add(const Duration(days: 1));
        return item.hora.day == tomorrow.day;
      } else {
        final dayAfter = today.add(const Duration(days: 2));
        return item.hora.day == dayAfter.day;
      }
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Selector de Unidades (Km/h vs Nudos) y Filtros de días
        _buildWindControlBar(),
        const SizedBox(height: 15),

        // Filtro de "Fetch" Geográfico (Estilo Windguru)
        _buildFetchSelector(),
        const SizedBox(height: 15),

        // Tarjeta Inteligente de Asistente de Clima Windguru
        _buildWindguruAssistantCard(filteredHours),
        const SizedBox(height: 15),

        // Info especial de Seguridad para Kayakistas
        _buildKayakLegendCard(),
        const SizedBox(height: 15),

        // Listado de Horarios
        if (filteredHours.isEmpty)
          Container(
            height: 200,
            alignment: Alignment.center,
            child: const Text(
              "No hay datos de viento disponibles para esta fecha.",
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filteredHours.length,
            itemBuilder: (context, index) {
              final item = filteredHours[index];
              return _buildHourlyWindRow(item);
            },
          ),
      ],
    );
  }

  Widget _buildWindControlBar() {
    final String diaHoyLabel = "Hoy (${DateFormat('dd/MM').format(DateTime.now())})";
    final String diaMananaLabel = "Mañana (${DateFormat('dd/MM').format(DateTime.now().add(const Duration(days: 1)))})";
    final String diaPasadoLabel = "Pasado (${DateFormat('dd/MM').format(DateTime.now().add(const Duration(days: 2)))})";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "CALCULADORA DE ZARPE", 
              style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0),
            ),
            Row(
              children: [
                Text(
                  _useKnots ? "UNIDAD: NUDOS (kt)" : "UNIDAD: KM/H",
                  style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: _useKnots,
                  onChanged: (val) => setState(() => _useKnots = val),
                  activeTrackColor: Colors.amber.withOpacity(0.3),
                  inactiveThumbColor: Colors.white54,
                  inactiveTrackColor: Colors.white24,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(child: _buildDayChip(0, diaHoyLabel)),
            const SizedBox(width: 6),
            Expanded(child: _buildDayChip(1, diaMananaLabel)),
            const SizedBox(width: 6),
            Expanded(child: _buildDayChip(2, diaPasadoLabel)),
          ],
        ),
      ],
    );
  }

  Widget _buildDayChip(int offset, String label) {
    final active = _selectedDayOffset == offset;
    return GestureDetector(
      onTap: () => setState(() => _selectedDayOffset = offset),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.amber.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? Colors.amber : Colors.white.withOpacity(0.08),
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.amber : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 9,
          ),
        ),
      ),
    );
  }

  Widget _buildFetchSelector() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => setState(() => _waterType = "cerrada"),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: _waterType == "cerrada" ? Colors.amber.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _waterType == "cerrada" ? Colors.amber.withOpacity(0.3) : Colors.transparent),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(Icons.waves, color: Colors.lightBlueAccent, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "🏞️ BAJO FETCH (distancia de soplado - Río/Laguna)",
                      style: TextStyle(
                        color: _waterType == "cerrada" ? Colors.amber[200] : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_waterType == "cerrada")
                    const Icon(Icons.check_circle, color: Colors.amber, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => setState(() => _waterType = "abierta"),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: BoxDecoration(
                color: _waterType == "abierta" ? Colors.amber.withOpacity(0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _waterType == "abierta" ? Colors.amber.withOpacity(0.3) : Colors.transparent),
              ),
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  const Icon(Icons.water, color: Colors.blueAccent, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "🌊 ALTO FETCH (distancia de soplado - Mar/Río de la Plata)",
                      style: TextStyle(
                        color: _waterType == "abierta" ? Colors.amber[200] : Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_waterType == "abierta")
                    const Icon(Icons.check_circle, color: Colors.amber, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindguruAssistantCard(List<HourlyForecast> hours) {
    if (hours.isEmpty) return const SizedBox.shrink();

    double avgWindKt = 0;
    double maxGustsKt = 0;
    double primaryWindDir = 0;
    
    for (var h in hours) {
      avgWindKt += h.vientoNudos;
      if (h.rafagasNudos > maxGustsKt) maxGustsKt = h.rafagasNudos;
      primaryWindDir = h.direccionViento; 
    }
    avgWindKt = avgWindKt / hours.length;

    // Clasificación dinámica de la costa argentina según dirección del viento
    String dirLabel = "";
    String dirWarning = "";
    Color dirColor = Colors.yellow;

    if (primaryWindDir >= 45.0 && primaryWindDir <= 160.0) {
      dirLabel = "ESTE / SUDESTE (ONSHORE)";
      dirWarning = "🚨 PROHIBIDO ENTRAR: Viento sopla del océano a la costa. Genera olas gigantes acumuladas, rompientes extremadamente violentas en la orilla que tumbarán tu kayak al instante y corrientes de retorno ('chupones') letales.";
      dirColor = Colors.redAccent;
    } else if (primaryWindDir >= 225.0 && primaryWindDir <= 315.0) {
      dirLabel = "OESTE / NOROESTE (OFFSHORE)";
      dirWarning = "⚠️ EXTREMO PELIGRO DE ARRASTRE: El agua en la orilla se verá perfectamente calma y lisa ('una pileta'), pero es una trampa. Al alejarte unos metros, el viento te empujará con fuerza hacia el interior del mar abierto haciéndote imposible regresar. Solo apto a poquísimos metros de la orilla.";
      dirColor = Colors.orangeAccent;
    } else {
      dirLabel = "NORTE / SUR (CROSS-SHORE)";
      dirWarning = "🟡 PRECAUCIÓN POR DERIVA LATERAL: El viento corre paralelo a la costa, generando fuerte deriva lateral que te arrastrará hacia playas vecinas y desarma la ola de costado, dificultando seriamente la estabilidad.";
      dirColor = Colors.yellow;
    }

    // Recomendación general del zarpe
    String title = "🟢 RECOMENDACIÓN DE ZARPE";
    String advice = "Condiciones perfectas para remar. Viento en rango ideal (Escala Beaufort 1 a 3). Control total del kayak.";
    Color cardColor = Colors.green;

    if (avgWindKt >= 16.0 || maxGustsKt >= 20.0) {
      title = "🔴 PELIGRO SEVERO - ZARPE DESACONSEJADO";
      advice = "Vientos promedio superiores a 16 nudos (Escala Beaufort 5+). Peligro severo de vuelco, spray constante e imposibilidad física de regresar.";
      cardColor = Colors.redAccent;
    } else if (avgWindKt >= 11.0 || maxGustsKt >= 15.0) {
      if (_waterType == "abierta") {
        title = "🔴 ALERTA DE FETCH EN AGUAS ABIERTAS";
        advice = "El viento constante está en zona límite (11-15 kt) pero al estar en ALTO FETCH (Mar o Río de la Plata), creará un oleaje peligroso ('corderitos') en pocos minutos.";
        cardColor = Colors.redAccent;
      } else {
        title = "🟡 ATENCIÓN - RANGO LÍMITE (SOLO EXPERTOS)";
        advice = "Vientos entre 11 y 15 nudos (Beaufort 4). En bajo fetch (río angosto o laguna) el esfuerzo es muy exigente físicamente pero el oleaje es menor.";
        cardColor = Colors.yellow;
      }
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cardColor.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_outlined, color: cardColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: cardColor, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            advice,
            style: const TextStyle(color: Colors.white70, fontSize: 10, height: 1.4),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24, thickness: 0.5),
          const SizedBox(height: 8),
          Text(
            "COMPORTAMIENTO DE COSTA - VIENTO: $dirLabel",
            style: TextStyle(color: dirColor, fontWeight: FontWeight.bold, fontSize: 9, letterSpacing: 0.5),
          ),
          const SizedBox(height: 4),
          Text(
            dirWarning,
            style: const TextStyle(color: Colors.white70, fontSize: 9.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildKayakLegendCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.25),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "⚠️ UMBRALES DE SEGURIDAD NÁUTICA (Fuente: Open-Meteo & NOAA)", 
            style: TextStyle(color: Colors.amber, fontSize: 9.5, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendPill("🟢 IDEAL", "0 a 10 kt\n(0-19 km/h)", Colors.green),
              _buildLegendPill("🟡 LÍMITE", "11 a 15 kt\n(20-28 km/h)", Colors.yellow),
              _buildLegendPill("🔴 PELIGRO", "16+ kt\n(29+ km/h)", Colors.redAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendPill(String title, String rule, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title, 
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 8),
        ),
        const SizedBox(height: 2),
        Text(
          rule, 
          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 7),
        ),
      ],
    );
  }

  Widget _buildHourlyWindRow(HourlyForecast item) {
    // Escala Beaufort para kayakistas
    final beaufort = _getBeaufortScale(item.vientoKmH);
    
    // Clasificación de Seguridad basada en el estándar Windguru provisto
    String safetyText = "SEGURO";
    Color safetyColor = Colors.green;
    
    if (item.vientoNudos >= 16.0 || item.alturaOlas > 1.0) {
      safetyText = "PELIGRO";
      safetyColor = Colors.redAccent;
    } else if (item.vientoNudos >= 11.0 || (_waterType == "abierta" && item.vientoNudos >= 11.0) || item.alturaOlas > 0.5) {
      safetyText = "LÍMITE";
      safetyColor = Colors.yellow;
    }

    // Configuración de unidades
    final speed = _useKnots ? item.vientoNudos : item.vientoKmH;
    final gusts = _useKnots ? item.rafagasNudos : item.rafagasKmH;
    final unitLabel = _useKnots ? "kt" : "km/h";

    final timeStr = DateFormat("HH:00 'hs'").format(item.hora);
    final String windSigla = _getWindDirectionSigla(item.direccionViento);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Hora, Seguridad y Escala Beaufort
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  timeStr, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: safetyColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: safetyColor.withOpacity(0.4), width: 0.5),
                      ),
                      child: Text(
                        safetyText, 
                        style: TextStyle(color: safetyColor, fontSize: 7, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "Bft $beaufort",
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 7, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Viento Medio y Ráfagas (Windguru style)
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  "${speed.toStringAsFixed(1)} $unitLabel", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
                Text(
                  "Rachas: ${gusts.toStringAsFixed(1)} $unitLabel", 
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8),
                ),
              ],
            ),
          ),

          // Olas y Dirección
          Expanded(
            flex: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "🌊 Olas: ${item.alturaOlas.toStringAsFixed(1)}m", 
                      style: const TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                    Text(
                      "Vto: $windSigla (${item.direccionViento.toStringAsFixed(0)}°)", 
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 8),
                    ),
                  ],
                ),
                const SizedBox(width: 6),
                Transform.rotate(
                  angle: (item.direccionViento * 3.1415926535) / 180,
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.amber, size: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getWindDirectionSigla(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return "N";
    if (degrees >= 22.5 && degrees < 67.5) return "NE";
    if (degrees >= 67.5 && degrees < 112.5) return "E";
    if (degrees >= 112.5 && degrees < 157.5) return "SE";
    if (degrees >= 157.5 && degrees < 202.5) return "S";
    if (degrees >= 202.5 && degrees < 247.5) return "SO";
    if (degrees >= 247.5 && degrees < 292.5) return "O";
    return "NO";
  }
}
