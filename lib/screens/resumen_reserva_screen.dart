import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_asistido_screen.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';

class ResumenReservaScreen extends StatefulWidget {
  final String cotizacionId;

  const ResumenReservaScreen({
    super.key,
    required this.cotizacionId,
  });

  @override
  State<ResumenReservaScreen> createState() => _ResumenReservaScreenState();
}

class _ResumenReservaScreenState extends State<ResumenReservaScreen> {
  Map<String, dynamic>? _reservaData;
  bool _isLoading = true;
  bool _isProcesando = false;
  
  // Colores CapitanYA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);
  static const Color _grisDescanso = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _cargarReserva();
  }

  Future<void> _cargarReserva() async {
    try {
      final client = Supabase.instance.client;

      // 1. Obtener la cotización
      final cotizacion = await client
          .from('cotizaciones')
          .select('*, profiles:pescador_id(nombre)')
          .eq('id', widget.cotizacionId)
          .single();

      // 2. Obtener el presupuesto activo de esta cotización
      final presupuestosResponse = await client
          .from('presupuestos')
          .select('*, profiles:capitan_id(*)')
          .eq('cotizacion_id', widget.cotizacionId)
          .order('created_at', ascending: false)
          .limit(1);

      if ((presupuestosResponse as List).isEmpty) {
        throw Exception('No se encontró una oferta activa para esta solicitud.');
      }

      final presupuesto = presupuestosResponse.first;
      final rawCapitanProfile = presupuesto['profiles'];
      
      // Convertir a Map mutable para poder enriquecerlo
      final Map<String, dynamic> capitanProfile = rawCapitanProfile is List 
          ? (rawCapitanProfile.isNotEmpty ? Map<String, dynamic>.from(rawCapitanProfile.first) : <String, dynamic>{})
          : (rawCapitanProfile != null ? Map<String, dynamic>.from(rawCapitanProfile) : <String, dynamic>{});

      // Consultar tabla guias para enriquecer datos de embarcación y capacidad
      try {
        final guiaData = await client
            .from('guias')
            .select('*')
            .eq('id', presupuesto['capitan_id'])
            .maybeSingle();
        if (guiaData != null) {
          guiaData.forEach((key, value) {
            if (value != null && (capitanProfile[key] == null || capitanProfile[key] == 0 || capitanProfile[key] == '')) {
              capitanProfile[key] = value;
            }
          });
        }
      } catch (e) {
        debugPrint('Error al consultar tabla guias: $e');
      }

      final rawPescadorProfile = cotizacion['profiles'];
      final pescadorProfile = rawPescadorProfile is List
          ? (rawPescadorProfile.isNotEmpty ? rawPescadorProfile.first as Map<String, dynamic> : null)
          : rawPescadorProfile as Map<String, dynamic>?;

      // Parseo seguro de monto
      final rawMonto = presupuesto['monto'];
      final monto = rawMonto != null ? double.tryParse(rawMonto.toString()) ?? 0.0 : 0.0;

      // 3. Mapear datos reales al formato de la pantalla
      setState(() {
        _reservaData = {
          'id_viaje': widget.cotizacionId,
          'fecha_embarque': presupuesto['fecha_hora_viaje'] != null 
              ? presupuesto['fecha_hora_viaje'].toString().split('T').first 
              : 'Fecha no definida',
          'hora_encuentro': presupuesto['fecha_hora_viaje'] != null 
              ? (presupuesto['fecha_hora_viaje'].toString().split('T').length > 1 
                  ? presupuesto['fecha_hora_viaje'].toString().split('T')[1].substring(0, 5) 
                  : '08:00')
              : '08:00',
          'lugar_encuentro': cotizacion['destino_direccion'] ?? 'Puerto Base',
          'capitan': {
            'id': presupuesto['capitan_id'],
            'nombre': capitanProfile['nombre'] ?? 'Capitán Profesional',
            'telefono': capitanProfile['telefono'] ?? 'No provisto',
            'foto_url': capitanProfile['avatar_url'] ?? '',
            'embarcacion_url': capitanProfile['embarcacion_url'],
            'servicio_carnada': capitanProfile['servicio_carnada'] ?? 'No',
            'servicio_lenia': capitanProfile['servicio_lenia'] == true,
            'servicio_almacen': capitanProfile['servicio_almacen'] == true,
            'capacidad_personas': capitanProfile['capacidad_personas'] ?? 0,
            'capacidad_kilos': capitanProfile['capacidad_kilos'] ?? 0,
            'calificacion': 4.9,
            'viajes_realizados': 84
          },
          'pescador': {
            'id': cotizacion['pescador_id'],
            'nombre': pescadorProfile?['nombre'] ?? 'Pescador'
          },
          'detalles_viaje': {
            'descripcion': presupuesto['detalles'] ?? cotizacion['descripcion'] ?? 'Viaje de pesca deportiva',
            'cantidad_personas': cotizacion['cantidad_personas'] ?? 1,
            'duracion_horas': cotizacion['duracion_horas'] ?? 6,
          },
          'costos': {
            'presupuesto_viaje': monto,
            'productos_tienda': 0.0,
            'envio_correo': 0.0,
            'total_final': monto,
            'comision_plataforma': monto * 0.1,
            'monto_neto': monto * 0.9,
          },
          'productos_tienda': [],
          'pasajeros': [],
          'bultos': {
            'total_bultos': 0,
            'detalle': []
          },
          'estado': {
            'cotizacion': cotizacion['estado'],
            'pago': 'pendiente',
            'contacto_habilitado': false,
            'viaje_confirmado': false
          }
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar reserva: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _aceptarReserva() async {
    setState(() => _isProcesando = true);
    
    try {
      final cart = Provider.of<CartProvider>(context, listen: false);
      
      final baseViajeMonto = (_reservaData!['costos']['presupuesto_viaje'] as num).toDouble();
      
      // Agregar el viaje al carrito
      cart.agregarViajeAlCarrito(
        idCotizacion: _reservaData!['id_viaje'],
        nombreCapitan: _reservaData!['capitan']['nombre'],
        monto: baseViajeMonto,
        descripcion: _reservaData!['detalles_viaje']['descripcion'],
        fecha: _reservaData!['fecha_embarque'],
      );

      // Si hay productos en la reserva (carnada, etc), también los sumamos (mock)
      if (_reservaData!['productos_tienda'] != null) {
        // En una implementación real, aquí se agregarían los productos reales
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('✅ Viaje añadido al carrito')),
            backgroundColor: _verdeExito,
          ),
        );
        
        Navigator.pushReplacementNamed(context, '/carrito');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al añadir al carrito: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isProcesando = false);
    }
  }

  void _consultarIA() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatAsistidoScreen(
          reservaId: widget.cotizacionId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final itemsTienda = cart.itemsTienda;
    final totalTienda = itemsTienda.fold<double>(0.0, (sum, item) => sum + item.subtotal);

    if (_reservaData != null) {
      final baseViajeMonto = (_reservaData!['costos']['presupuesto_viaje'] as num).toDouble();
      final totalFinal = baseViajeMonto + totalTienda;
      
      _reservaData!['productos_tienda'] = itemsTienda.map((item) => {
        'nombre': item.producto.nombre,
        'cantidad': item.cantidad,
        'precio_unitario': item.producto.precio,
        'subtotal': item.subtotal,
      }).toList();
      
      _reservaData!['costos']['productos_tienda'] = totalTienda;
      _reservaData!['costos']['total_final'] = totalFinal;
      _reservaData!['costos']['comision_plataforma'] = totalFinal * 0.1;
      _reservaData!['costos']['monto_neto'] = totalFinal * 0.9;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('Resumen de Reserva'),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reservaData == null
              ? _buildEstadoVacio()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header principal
                      _buildHeaderPrincipal(),
                      
                      // Tarjeta del Capitan
                      _buildTarjetaCapitan(),
                      
                      // Servicios y Embarcacion (NUEVO)
                      _buildServiciosYEmbarcacion(),
                      
                      // Detalles del Viaje
                      _buildDetallesViaje(),
                      
                      // Resumen Financiero
                      _buildResumenFinanciero(),
                      
                      // Productos de Tienda
                      _buildProductosTienda(),
                      
                      // Espacio para botones
                      const SizedBox(height: 20),
                      
                      // Botones de accion
                      _buildBotonesAccion(),
                      
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
              color: _azulNautico.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.summarize,
              size: 64,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Resumen No Disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se pudo cargar la informacion\ndel resumen de la reserva.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPrincipal() {
    final reserva = _reservaData!;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _azulNautico,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'RESUMEN DE RESERVA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _verdeExito,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'PRESUPUESTADO',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha de Embarque',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      reserva['fecha_embarque'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Hora de Encuentro',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      reserva['hora_encuentro'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reserva['lugar_encuentro'],
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTarjetaCapitan() {
    final capitan = _reservaData!['capitan'];
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Tu Capitan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _azulNautico.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _azulNautico, width: 2),
                ),
                child: capitan['foto_url'] != null && capitan['foto_url'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: Image.network(
                          capitan['foto_url'],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, color: _azulNautico, size: 30),
                        ),
                      )
                    : const Icon(Icons.person, color: _azulNautico, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      capitan['nombre'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _azulNautico,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.lock_outline, color: Colors.orangeAccent, size: 14),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Teléfono (Se libera al pagar)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Estrellas de calificacion
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (index) {
                            return Icon(
                              index < 4 ? Icons.star : Icons.star_border,
                              color: _naranjaAlerta,
                              size: 16,
                            );
                          }),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${capitan['calificacion']} (${capitan['viajes_realizados']} viajes)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiciosYEmbarcacion() {
    final capitan = _reservaData!['capitan'];
    final bool ofreceCarnada = (capitan['servicio_carnada'] ?? 'No') != 'No';
    final bool ofreceLenia = capitan['servicio_lenia'] ?? false;
    final bool ofreceAlmacen = capitan['servicio_almacen'] ?? false;
    
    // Decodificar servicios extra de bio_pescador si es JSON
    bool ofreceCabania = false;
    bool ofreceBanio = false;
    bool ofreceParrilla = false;
    
    final bioRaw = capitan['bio_pescador']?.toString() ?? '';
    if (bioRaw.startsWith('{')) {
      try {
        final Map<String, dynamic> jsonBio = jsonDecode(bioRaw);
        ofreceCabania = jsonBio['cabania'] ?? false;
        ofreceBanio = jsonBio['banio'] ?? false;
        ofreceParrilla = jsonBio['parrilla'] ?? false;
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_boat, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Embarcación y Servicios',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (capitan['embarcacion_url'] != null && capitan['embarcacion_url'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                capitan['embarcacion_url'],
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 120,
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sailing, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text('Foto de embarcación no disponible', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
          
          const SizedBox(height: 16),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildInfoCard(
                'Capacidad',
                '${capitan['capacidad_personas']} pers.',
                Icons.groups,
                _verdeExito,
              ),
              _buildInfoCard(
                'Carga Máx',
                '${capitan['capacidad_kilos']} kg',
                Icons.scale,
                _grisDescanso,
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          
          const Text(
            'Servicios Incluidos / Disponibles',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              if (ofreceCarnada) _buildChipServicio(Icons.phishing, 'Carnada: ${capitan['servicio_carnada']}'),
              if (ofreceLenia) _buildChipServicio(Icons.fireplace, 'Leña disponible'),
              if (ofreceAlmacen) _buildChipServicio(Icons.shopping_basket, 'Almacén a bordo'),
              if (ofreceCabania) _buildChipServicio(Icons.house, 'Cabaña (Precio a convenir)'),
              if (ofreceBanio) _buildChipServicio(Icons.wc, 'Baño a bordo'),
              if (ofreceParrilla) _buildChipServicio(Icons.outdoor_grill, 'Parrilla'),
              if (!ofreceCarnada && !ofreceLenia && !ofreceAlmacen && !ofreceCabania && !ofreceBanio && !ofreceParrilla)
                const Text('Servicios base de navegación únicamente', style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChipServicio(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _verdeExito.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _verdeExito.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _verdeExito),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: _verdeExito, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesViaje() {
    final detalles = _reservaData!['detalles_viaje'];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.directions_boat, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Detalles del Viaje',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            detalles['descripcion'],
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Pasajeros',
                  detalles['cantidad_personas'].toString(),
                  Icons.people,
                  _verdeExito,
                ),
              ),
              Expanded(
                child: _buildInfoCard(
                  'Duracion',
                  '${detalles['duracion_horas']}h',
                  Icons.schedule,
                  _naranjaAlerta,
                ),
              ),
              Expanded(
                child: _buildInfoCard(
                  'Bultos',
                  _reservaData!['bultos']['total_bultos'].toString(),
                  Icons.inventory_2,
                  _grisDescanso,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenFinanciero() {
    final costos = _reservaData!['costos'];
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_money, color: _verdeExito),
              const SizedBox(width: 8),
              const Text(
                'Resumen Financiero',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _verdeExito,
                ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          
          // Desglose de costos
          _buildCostoItem('Presupuesto Viaje', costos['presupuesto_viaje']),
          _buildCostoItem('Productos Tienda', costos['productos_tienda']),
          _buildCostoItem('Envio Correo Argentino', costos['envio_correo']),
          
          const Divider(height: 24),
          
          // Total destacado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _verdeExito.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _verdeExito.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'TOTAL FINAL',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _verdeExito,
                      ),
                    ),
                    Text(
                      '\$${costos['total_final'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: _verdeExito,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Comision plataforma (10%)',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '\$${costos['comision_plataforma'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Monto neto',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '\$${costos['monto_neto'].toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostoItem(String concepto, double monto) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            concepto,
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            '\$${monto.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductosTienda() {
    final productos = _reservaData!['productos_tienda'] as List;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shopping_cart, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Productos de Tienda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (productos.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no has agregado productos adicionales del catálogo a tu reserva.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ...productos.map((producto) => _buildProductoItem(producto)),
        ],
      ),
    );
  }

  Widget _buildProductoItem(Map<String, dynamic> producto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  producto['nombre'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${producto['cantidad']} x \$${producto['precio_unitario'].toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${producto['subtotal'].toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Acciones',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 16),
          
          // Boton Aceptar
          SizedBox(
            width: double.infinity,
            height: 56, // Altura estandar para botones moviles
            child: ElevatedButton.icon(
              onPressed: _isProcesando ? null : _aceptarReserva,
              icon: _isProcesando 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle),
              label: Text(
                _isProcesando ? 'Procesando...' : 'Aceptar Reserva',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _verdeExito,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Boton Consultar IA
          SizedBox(
            width: double.infinity,
            height: 56, // Altura estandar para botones moviles
            child: OutlinedButton.icon(
              onPressed: _consultarIA,
              icon: const Icon(Icons.chat),
              label: const Text(
                'Consultar IA',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _azulNautico,
                side: BorderSide(color: _azulNautico, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Informacion adicional
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _naranjaAlerta.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _naranjaAlerta.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _naranjaAlerta, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Al aceptar, confirmaras tu reserva y podras cargar los datos de los pasajeros para el manifiesto.',
                    style: TextStyle(
                      fontSize: 12,
                      color: _naranjaAlerta,
                    ),
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
}
