

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/supabase_service.dart';
import '../services/disponibilidad_service_final.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CaptainQuoteScreen extends StatefulWidget {
  final String cotizacionId;

  const CaptainQuoteScreen({
    super.key,
    required this.cotizacionId,
  });

  @override
  State<CaptainQuoteScreen> createState() => _CaptainQuoteScreenState();
}

class _CaptainQuoteScreenState extends State<CaptainQuoteScreen> {
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
  }

  @override
  void dispose() {
    _presupuestoController.dispose();
    _respuestaController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _cargarCotizacion() async {
    try {
      final data = await SupabaseService.getDetallesCotizacionCapitan(widget.cotizacionId);
      
      setState(() {
        _cotizacionData = {
          'id': data['id'],
          'pescador_id': data['pescador_id'],
          'pescador_nombre': data['profiles']?['nombre'] ?? 'Pescador',
          'descripcion': data['descripcion'] ?? 'Sin descripción',
          'fecha_ida': data['fecha_ida'] != null 
              ? data['fecha_ida'].toString().split('T').first 
              : 'Fecha no definida',
          'fecha_vuelta': data['fecha_vuelta'] != null 
              ? data['fecha_vuelta'].toString().split('T').first 
              : 'Fecha no definida',
          'hora_encuentro': data['hora_encuentro'] ?? '08:00',
          'lugar_encuentro': data['lugar_encuentro'] ?? 'Puerto Base',
          'cantidad_personas': data['cantidad_personas'] ?? 1,
          'coordenada_origen_lat': data['coordenada_origen_lat'] != null ? (data['coordenada_origen_lat'] as num).toDouble() : -38.0022,
          'coordenada_origen_lng': data['coordenada_origen_lng'] != null ? (data['coordenada_origen_lng'] as num).toDouble() : -57.5575,
          'coordenada_destino_lat': data['coordenada_destino_lat'] != null ? (data['coordenada_destino_lat'] as num).toDouble() : -38.0022,
          'coordenada_destino_lng': data['coordenada_destino_lng'] != null ? (data['coordenada_destino_lng'] as num).toDouble() : -57.5575,
          'estado': data['estado'],
          'created_at': data['created_at'],
        };
        _isLoading = false;
      });
      
      // Agregar marcador en el mapa
      _agregarMarcadorMapa();
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

  void _agregarMarcadorMapa() {
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
            BitmapDescriptor.hueOrange,
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
      // Simular envio del presupuesto
      await Future.delayed(const Duration(seconds: 2));
      
      final presupuesto = double.tryParse(_presupuestoController.text.replaceAll(',', '')) ?? 0.0;
      final respuesta = _respuestaController.text.trim();
      
      // Aqui iria la logica real para guardar en la base de datos
      await SupabaseService.actualizarCotizacionConRespuesta(
        widget.cotizacionId,
        presupuesto,
        respuesta,
      );

      // Reservar fecha en el calendario del capitán
      try {
        final capId = Supabase.instance.client.auth.currentUser?.id;
        final fechaIdaStr = _cotizacionData?['fecha_ida'];
        if (capId != null && fechaIdaStr != null && fechaIdaStr != 'Fecha no definida') {
          final DateTime? fecha = DateTime.tryParse(fechaIdaStr);
          if (fecha != null) {
            await DisponibilidadServiceFinal.marcarFechaReservadaConCapitan(fecha, capId);
          }
        }
      } catch (e) {
        print('Error al reservar fecha en calendario: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(
              child: Text(
                '✅ Presupuesto de \$${presupuesto.toStringAsFixed(2)} enviado exitosamente'
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.directions_boat, color: _blancoPuro),
            const SizedBox(width: 8),
            const Text(
              'Cotizacion',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _cargarCotizacion,
            icon: const Icon(Icons.refresh, color: _blancoPuro),
            tooltip: 'Recargar',
          ),
        ],
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
                      // Mapa con punto de encuentro
                      _buildMapaContainer(),
                      
                      // Informacion de la cotizacion
                      _buildInfoCotizacion(),
                      
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

  Widget _buildMapaContainer() {
    return Container(
      height: 300, // Altura fija para el mapa en moviles
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
          markers: _markers,
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

  Widget _buildInfoCotizacion() {
    final cotizacion = _cotizacionData!;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con titulo
          Row(
            children: [
              Icon(Icons.info, color: _azulVibrante),
              const SizedBox(width: 8),
              const Text(
                'Detalles de la Cotizacion',
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
                Row(
                  children: [
                    Icon(Icons.person, color: _blancoPuro, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Pescador:',
                      style: TextStyle(
                        color: _blancoPuro,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  cotizacion['pescador_nombre'],
                  style: const TextStyle(
                    color: _blancoPuro,
                    fontSize: 14,
                  ),
                ),
                // NOTA: No mostramos telefono ni apellido (proteccion anti-puenteo)
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.info_outline, color: _amarilloVivo, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Los datos de contacto estan protegidos para evitar el puenteo del negocio',
                        style: TextStyle(
                          color: _amarilloVivo,
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Detalles del viaje
          Text(
            cotizacion['descripcion'],
            style: const TextStyle(
              fontSize: 14,
              color: _fondoOscuro,
            ),
          ),
          
          const SizedBox(height: 12),
          
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
              Expanded(
                child: _buildInfoCard(
                  'Hora',
                  cotizacion['hora_encuentro'],
                  Icons.schedule,
                  _naranjaIntenso,
                ),
              ),
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
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _verdeBrillante.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
            
            // Campo de presupuesto
            TextFormField(
              controller: _presupuestoController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                ThousandsSeparatorInputFormatter(),
              ],
              decoration: InputDecoration(
                labelText: 'Presupuesto (ARS)',
                labelStyle: const TextStyle(color: _fondoOscuro),
                prefixText: '\$',
                prefixStyle: const TextStyle(color: _verdeBrillante, fontWeight: FontWeight.bold),
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
                if (value == null || value.isEmpty) {
                  return 'Por favor, ingresa el presupuesto';
                }
                final monto = double.tryParse(value.replaceAll(',', ''));
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
                    '• El presupuesto sera visible para el pescador\n'
                    '• Tu mensaje sera enviado directamente\n'
                    '• Los datos de contacto estan protegidos\n'
                    '• No compartas informacion personal',
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
              child: ElevatedButton.icon(
                onPressed: _isEnviando ? null : _enviarPresupuesto,
                icon: _isEnviando 
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _blancoPuro,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _isEnviando ? 'Enviando...' : 'Enviar Presupuesto',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verdeBrillante,
                  foregroundColor: _blancoPuro,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Formateador de miles para el campo de presupuesto
class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final String text = newValue.text.replaceAll(',', '');
    final int selectionIndex = newValue.selection.end;

    // Formatear con separadores de miles
    final String formattedText = _formatNumber(text);
    
    return TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(
        affinity: TextAffinity.downstream,
        offset: formattedText.length,
      ),
    );
  }

  String _formatNumber(String s) {
    final buffer = StringBuffer();
    final int length = s.length;
    for (int i = 0; i < length; i++) {
      if ((length - i) % 3 == 0 && i != 0) {
        buffer.write(',');
      }
      buffer.write(s[i]);
    }
    return buffer.toString();
  }
}
