

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/supabase_service.dart';
import '../widgets/safe_button.dart';

class QuoteFormScreen extends StatefulWidget {
  final String cotizacionId;

  const QuoteFormScreen({
    super.key,
    required this.cotizacionId,
  });

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  final _presupuestoController = TextEditingController();
  final _respuestaController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  
  Map<String, dynamic>? _cotizacionData;
  bool _isLoading = true;
  bool _isEnviando = false;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  
  // Colores El Guia YA - Alto contraste para exteriores
  static const Color _fondoOscuro = Color(0xFF1A1A1A);      // Fondo oscuro
  static const Color _blancoPuro = Color(0xFFFFFFFF);        // Blanco puro
  static const Color _azulVibrante = Color(0xFF0066FF);      // Azul vibrante
  static const Color _verdeBrillante = Color(0xFF00FF00);     // Verde brillante
  static const Color _naranjaIntenso = Color(0xFFFF6600);     // Naranja intenso
  static const Color _rojoFuerte = Color(0xFFFF0000);          // Rojo fuerte
  static const Color _amarilloVivo = Color(0xFFFFFF00);       // Amarillo vivo

  @override
  void initState() {
    super.initState();
    _presupuestoController.text = '50000'; // $50.000 por defecto
    _cargarCotizacion();
    
    // Listener para formateo en tiempo real
    _presupuestoController.addListener(_onPresupuestoChanged);
  }

  @override
  void dispose() {
    _presupuestoController.removeListener(_onPresupuestoChanged);
    _presupuestoController.dispose();
    _respuestaController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _onPresupuestoChanged() {
    final text = _presupuestoController.text;
    if (text.isEmpty) return;
    
    // Formatear a moneda argentina en tiempo real
    final cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
    if (cleanText.isEmpty) return;
    
    final value = int.tryParse(cleanText);
    if (value != null) {
      final formatted = _formatCurrency(value);
      if (_presupuestoController.text != formatted) {
        _presupuestoController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
  }

  String _formatCurrency(int amount) {
    // Formato moneda argentina: $XX.XXX
    final String amountStr = amount.toString();
    final int length = amountStr.length;
    
    if (length <= 3) return '\$$amountStr';
    
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < length; i++) {
      if ((length - i) % 3 == 0 && i != 0) {
        buffer.write('.');
      }
      buffer.write(amountStr[i]);
    }
    
    return '\$$buffer';
  }

  Future<void> _cargarCotizacion() async {
    try {
      // Simular carga de datos de cotizacion
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _cotizacionData = {
          'id': widget.cotizacionId,
          'pescador_id': null,
          'pescador_nombre': 'Pescador Test', // Solo nombre, sin apellido
          'descripcion': 'Viaje de pesca maritima con amigos',
          'fecha_ida': '2026-03-15',
          'fecha_vuelta': '2026-03-15',
          'hora_encuentro': '08:00',
          'lugar_encuentro': 'Puerto de Mar del Plata',
          'cantidad_personas': 4,
          'coordenada_origen_lat': -38.0022,
          'coordenada_origen_lng': -57.5575,
          'coordenada_destino_lat': -38.0022,
          'coordenada_destino_lng': -57.5575,
          'estado': 'cotizado',
          'created_at': '2026-03-10T10:00:00Z',
          // NOTA: No incluimos telefono ni apellido del pescador (proteccion anti-puenteo)
        };
        _isLoading = false;
      });
      
      // Agregar marcador estatico en el mapa
      _agregarMarcadorEstatico();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar cotizacion: $e')),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  void _agregarMarcadorEstatico() {
    if (_cotizacionData == null) return;
    
    final lat = _cotizacionData!['coordenada_origen_lat'];
    final lng = _cotizacionData!['coordenada_origen_lng'];
    
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId(widget.cotizacionId),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: 'Punto de Encuentro',
            snippet: _cotizacionData!['lugar_encuentro'],
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange, // Marcador naranja estatico
          ),
        ),
      );
    });
  }

  Future<void> _enviarPresupuesto() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isEnviando = true);

    try {
      // Extraer valor numerico del presupuesto formateado
      final presupuestoText = _presupuestoController.text.replaceAll(RegExp(r'[^\d]'), '');
      final presupuesto = double.tryParse(presupuestoText) ?? 0.0;
      final respuesta = _respuestaController.text.trim();
      
      // 1. Actualizar estado en Supabase a 'presupuestado'
      await SupabaseService.actualizarCotizacionConRespuesta(
        widget.cotizacionId,
        presupuesto,
        respuesta,
      );
      
      // 2. Notificar al Administrador en Glew
      await _notificarAdministradorGlew(presupuesto, respuesta);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                '? Presupuesto de ${_formatCurrency(presupuesto.toInt())} enviado exitosamente'
              ),
            ),
            backgroundColor: _verdeBrillante,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Volver al panel principal
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al enviar presupuesto: $e')),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    } finally {
      setState(() => _isEnviando = false);
    }
  }

  Future<void> _notificarAdministradorGlew(double presupuesto, String respuesta) async {
    try {
      // Simular notificacion a Glew
      // En produccion, aqui iria la integracion real con la API de Glew
      await Future.delayed(const Duration(milliseconds: 500));
      
      final notificacionData = {
        'evento': 'presupuesto_enviado',
        'cotizacion_id': widget.cotizacionId,
        'capitan_id': SupabaseService.currentUserId,
        'pescador_id': _cotizacionData!['pescador_id'],
        'presupuesto': presupuesto,
        'respuesta': respuesta,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          'lugar_encuentro': _cotizacionData!['lugar_encuentro'],
          'fecha_viaje': _cotizacionData!['fecha_ida'],
          'cantidad_personas': _cotizacionData!['cantidad_personas'],
        }
      };
      
      // Aqui iria la llamada real a la API de Glew
      // await GlewService.sendNotification(notificacionData);
      
      print('?? Notificacion enviada a Glew: $notificacionData');
      
    } catch (e) {
      print('? Error al notificar a Glew: $e');
      // No fallamos el flujo principal si falla la notificacion a Glew
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      // Header con boton Atras y titulo
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back, color: _blancoPuro),
        ),
        title: const Text(
          'Cotizacion',
          style: TextStyle(
            color: _blancoPuro,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(_blancoPuro),
            ),
          )
          : _cotizacionData == null
              ? _buildEstadoVacio()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Seccion Mapa con marcador naranja estatico
                      _buildSeccionMapa(),
                      
                      // Tarjeta del Pescador con Datos Protegidos
                      _buildTarjetaPescador(),
                      
                      // Tarjeta de informacion del viaje
                      _buildTarjetaViaje(),
                      
                      // Formulario de presupuesto
                      _buildFormularioPresupuesto(),
                      
                      // Espacio inferior
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
    );
  }

  Widget _buildEstadoVacio() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _azulVibrante.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.directions_boat,
              size: 64,
              color: _blancoPuro,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cotizacion No Disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _blancoPuro,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se pudo cargar la informacion\nde la cotizacion solicitada.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _blancoPuro.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionMapa() {
    return Container(
      height: 300, // Contenedor de 300px de alto
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _azulVibrante.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: GoogleMap(
          onMapCreated: (GoogleMapController controller) {
            _mapController = controller;
            _centrarMapaEnMarcador();
          },
          initialCameraPosition: CameraPosition(
            target: LatLng(
              _cotizacionData!['coordenada_origen_lat'],
              _cotizacionData!['coordenada_origen_lng'],
            ),
            zoom: 15,
          ),
          markers: _markers, // Marcador naranja estatico
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapType: MapType.normal,
          compassEnabled: true,
        ),
      ),
    );
  }

  void _centrarMapaEnMarcador() {
    if (_mapController != null && _markers.isNotEmpty) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _markers.first.position,
            zoom: 15,
          ),
        ),
      );
    }
  }

  Widget _buildTarjetaPescador() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _blancoPuro,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _azulVibrante.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de la tarjeta
            Row(
              children: [
                Icon(Icons.person, color: _azulVibrante),
                const SizedBox(width: 8),
                const Text(
                  'Pescador',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _fondoOscuro,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Informacion del pescador (sin contacto)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _fondoOscuro,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cotizacionData!['pescador_nombre'],
                    style: const TextStyle(
                      color: _blancoPuro,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Aviso de Datos Protegidos
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _amarilloVivo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _amarilloVivo.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.security, color: _amarilloVivo, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '??? Datos Protegidos',
                                style: TextStyle(
                                  color: _amarilloVivo,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Los datos de contacto del pescador estan protegidos para evitar el puenteo del negocio. Solo podras verlos cuando la cotizacion sea aceptada.',
                                style: TextStyle(
                                  color: _fondoOscuro,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarjetaViaje() {
    final cotizacion = _cotizacionData!;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _blancoPuro,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _naranjaIntenso.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de la tarjeta
            Row(
              children: [
                Icon(Icons.info, color: _naranjaIntenso),
                const SizedBox(width: 8),
                const Text(
                  'Informacion del Viaje',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _fondoOscuro,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Descripcion del viaje
            Text(
              cotizacion['descripcion'],
              style: const TextStyle(
                fontSize: 14,
                color: _fondoOscuro,
                height: 1.3,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Detalles en formato de tarjetas pequenas
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    'Fecha',
                    cotizacion['fecha_ida'],
                    Icons.calendar_today,
                    _azulVibrante,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoCard(
                    'Hora',
                    cotizacion['hora_encuentro'],
                    Icons.schedule,
                    _naranjaIntenso,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildInfoCard(
                    'Personas',
                    cotizacion['cantidad_personas'].toString(),
                    Icons.people,
                    _verdeBrillante,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Lugar de encuentro
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _azulVibrante.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: _azulVibrante, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Lugar de Encuentro',
                          style: TextStyle(
                            color: _azulVibrante,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          cotizacion['lugar_encuentro'],
                          style: TextStyle(
                            color: _fondoOscuro,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormularioPresupuesto() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: _blancoPuro,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _verdeBrillante.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(Icons.attach_money, color: _verdeBrillante),
                  const SizedBox(width: 8),
                  const Text(
                    'Presupuesto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _fondoOscuro,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Campo de presupuesto con formato moneda argentina
              TextFormField(
                controller: _presupuestoController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: InputDecoration(
                  labelText: 'Presupuesto (ARS)',
                  labelStyle: const TextStyle(color: _fondoOscuro),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: _azulVibrante),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _azulVibrante),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _verdeBrillante, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: _blancoPuro,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixText: '\$',
                  prefixStyle: const TextStyle(
                    color: _verdeBrillante,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _fondoOscuro,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, ingresa el presupuesto';
                  }
                  final cleanText = value.replaceAll(RegExp(r'[^\d]'), '');
                  final monto = double.tryParse(cleanText);
                  if (monto == null || monto <= 0) {
                    return 'El presupuesto debe ser mayor a 0';
                  }
                  if (monto < 10000) {
                    return 'El presupuesto minimo es \$10.000';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Campo de respuesta
              TextFormField(
                controller: _respuestaController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Mensaje para el Pescador',
                  labelStyle: const TextStyle(color: _fondoOscuro),
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: _azulVibrante),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _azulVibrante),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: _verdeBrillante, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: _blancoPuro,
                  hintStyle: TextStyle(color: Colors.grey[600]),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingresa un mensaje para el pescador';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Informacion adicional
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _naranjaIntenso.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: _naranjaIntenso, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Informacion Importante',
                          style: TextStyle(
                            color: _naranjaIntenso,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '� El presupuesto sera visible para el pescador\n'
                      '� Tu mensaje sera enviado directamente\n'
                      '� Los datos de contacto estan protegidos\n'
                      '� No compartas informacion personal',
                      style: TextStyle(
                        color: _fondoOscuro,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Boton de envio
              SizedBox(
                width: double.infinity,
                height: 56, // Altura estandar para botones moviles
                child: ElevatedButton(
                  onPressed: _isEnviando ? null : _enviarPresupuesto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verdeBrillante,
                    foregroundColor: _blancoPuro,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: SafeButtonLoadingContent(
                    loading: _isEnviando,
                    icon: Icons.send,
                    idleLabel: 'Enviar presupuesto',
                    loadingLabel: 'Enviando...',
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _blancoPuro,
                    ),
                    spinnerColor: _blancoPuro,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
