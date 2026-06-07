

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class TicketEmbarqueScreen extends StatefulWidget {
  final String cotizacionId;

  const TicketEmbarqueScreen({
    super.key,
    required this.cotizacionId,
  });

  @override
  State<TicketEmbarqueScreen> createState() => _TicketEmbarqueScreenState();
}

class _TicketEmbarqueScreenState extends State<TicketEmbarqueScreen> {
  Map<String, dynamic>? _ticketData;
  bool _isLoading = true;
  
  // Colores CapitanYA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _verdeExito = Color(0xFF10B981);
  static const Color _naranjaAlerta = Color(0xFFF59E0B);
  static const Color _rojoProblema = Color(0xFFEF4444);
  static const Color _grisDescanso = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _cargarTicketEmbarque();
  }

  Future<void> _cargarTicketEmbarque() async {
    try {
      // Simular carga del JSON del ticket (en produccion, llamar al servicio real)
      await Future.delayed(const Duration(seconds: 1));
      
      // Datos simulados basados en el script SQL
      setState(() {
        _ticketData = {
          'ticket_embarque': {
            'id_viaje': widget.cotizacionId,
            'fecha_embarque': '2026-03-15',
            'hora_encuentro': '08:00',
            'lugar_encuentro': 'Puerto de Mar del Plata',
            'capitan': {
              'id': '22222222-2222-2222-2222-222222222222',
              'nombre': 'Capitan Juan Perez',
              'telefono': '+5492231234567'
            },
            'pescador': {
              'id': '11111111-1111-1111-1111-111111111111',
              'nombre': 'Pescador Test'
            },
            'detalles_viaje': {
              'descripcion': 'Viaje de pesca maritima con amigos - Incluye equipo completo',
              'cantidad_personas': 4,
              'coordenadas': {
                'origen': {'lat': -38.0022, 'lng': -57.5575},
                'destino': {'lat': -38.0022, 'lng': -57.5575}
              }
            },
            'costos': {
              'presupuesto_viaje': 50000.00,
              'productos_tienda': 15000.00,
              'envio_correo': 3500.00,
              'total_final': 68500.00
            },
            'productos_tienda': [
              {
                'nombre': 'Carnada fresca especial',
                'cantidad': 2,
                'precio_unitario': 5000.00,
                'subtotal': 10000.00,
                'categoria': 'carnada'
              },
              {
                'nombre': 'Bebidas isotonicas pack x6',
                'cantidad': 1,
                'precio_unitario': 2000.00,
                'subtotal': 2000.00,
                'categoria': 'bebidas'
              },
              {
                'nombre': 'Protector solar factor 50',
                'cantidad': 2,
                'precio_unitario': 1500.00,
                'subtotal': 3000.00,
                'categoria': 'proteccion'
              }
            ],
            'pasajeros': [
              {
                'nombre_completo': 'Juan Carlos Perez',
                'dni': '12345678',
                'foto_dni_url': 'https://example.com/fotos_dni/juan_perez.jpg',
                'datos_validados': true
              },
              {
                'nombre_completo': 'Maria Gonzalez',
                'dni': '87654321',
                'foto_dni_url': 'https://example.com/fotos_dni/maria_gonzalez.jpg',
                'datos_validados': true
              },
              {
                'nombre_completo': 'Roberto Lopez',
                'dni': '11223344',
                'foto_dni_url': 'https://example.com/fotos_dni/roberto_lopez.jpg',
                'datos_validados': true
              },
              {
                'nombre_completo': 'Ana Martinez',
                'dni': '55667788',
                'foto_dni_url': 'https://example.com/fotos_dni/ana_martinez.jpg',
                'datos_validados': true
              }
            ],
            'bultos': {
              'total_bultos': 3,
              'detalle': [
                {'tipo': 'carnada', 'cantidad': 2},
                {'tipo': 'bebidas', 'cantidad': 1},
                {'tipo': 'proteccion', 'cantidad': 2}
              ]
            },
            'estado': {
              'cotizacion': 'presupuestado',
              'pago': 'pendiente',
              'contacto_habilitado': false,
              'viaje_confirmado': false
            },
            'timestamps': {
              'creado': '2026-03-10T10:00:00Z',
              'presupuesto_enviado': '2026-03-10T14:30:00Z',
              'ultima_actualizacion': '2026-03-10T14:30:00Z'
            },
            'resumen_financiero': {
              'monto_viaje': 50000.00,
              'monto_productos': 15000.00,
              'monto_envio': 3500.00,
              'monto_total': 68500.00,
              'forma_pago': 'pendiente',
              'comision_plataforma': 6850.00,
              'monto_neto': 61650.00
            }
          }
        };
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar ticket: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _llamarCapitan() async {
    final telefono = _ticketData?['ticket_embarque']?['capitan']?['telefono'];
    if (telefono == null || telefono.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Telefono del capitan no disponible')),
          backgroundColor: _rojoProblema,
        ),
      );
      return;
    }

    final uri = Uri.parse('tel:$telefono');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        throw 'No se pudo iniciar la llamada';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al realizar llamada: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.confirmation_number, color: Colors.white),
            const SizedBox(width: 8),
            const Text('Ticket de Embarque'),
          ],
        ),
        backgroundColor: _azulNautico,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarTicketEmbarque,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _ticketData == null
              ? _buildEstadoVacio()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header del ticket
                      _buildTicketHeader(),
                      
                      // Informacion del viaje
                      _buildViajeInfo(),
                      
                      // Informacion del capitan
                      _buildCapitanInfo(),
                      
                      // Resumen financiero
                      _buildResumenFinanciero(),
                      
                      // Productos de tienda
                      _buildProductosTienda(),
                      
                      // Pasajeros
                      _buildPasajeros(),
                      
                      // Bultos
                      _buildBultos(),
                      
                      // Estado y acciones
                      _buildEstadoYAcciones(),
                      
                      // Footer
                      _buildFooter(),
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
              Icons.confirmation_number_outlined,
              size: 64,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ticket No Disponible',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _azulNautico,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No se pudo cargar la informacion\ndel ticket de embarque.',
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

  Widget _buildTicketHeader() {
    final ticket = _ticketData!['ticket_embarque'];
    
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
                Icons.confirmation_number,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'TICKET DE EMBARQUE',
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
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ACTIVO',
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
                      ticket['fecha_embarque'],
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
                      ticket['hora_encuentro'],
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
            ticket['lugar_encuentro'],
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViajeInfo() {
    final ticket = _ticketData!['ticket_embarque'];
    final detalles = ticket['detalles_viaje'];
    
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
          const SizedBox(height: 12),
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
                  '1 dia',
                  Icons.schedule,
                  _naranjaAlerta,
                ),
              ),
              Expanded(
                child: _buildInfoCard(
                  'Distancia',
                  '0 km',
                  Icons.straighten,
                  _grisDescanso,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCapitanInfo() {
    final ticket = _ticketData!['ticket_embarque'];
    final capitan = ticket['capitan'];
    
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
              Icon(Icons.person, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Capitan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: _azulNautico.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: _azulNautico, width: 2),
                ),
                child: const Icon(Icons.person, color: _azulNautico),
              ),
              const SizedBox(width: 12),
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
                    Text(
                      capitan['telefono'],
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _llamarCapitan,
                icon: const Icon(Icons.phone),
                label: const Text('Llamar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verdeExito,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenFinanciero() {
    final ticket = _ticketData!['ticket_embarque'];
    final costos = ticket['costos'];
    final resumen = ticket['resumen_financiero'];
    
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
            child: Row(
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
          ),
          
          const SizedBox(height: 12),
          
          // Informacion adicional
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Comision (10%)',
                  '\$${resumen['comision_plataforma'].toStringAsFixed(2)}',
                  Icons.percent,
                  _naranjaAlerta,
                ),
              ),
              Expanded(
                child: _buildInfoCard(
                  'Monto Neto',
                  '\$${resumen['monto_neto'].toStringAsFixed(2)}',
                  Icons.account_balance_wallet,
                  _azulNautico,
                ),
              ),
            ],
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
    final ticket = _ticketData!['ticket_embarque'];
    final productos = ticket['productos_tienda'] as List;
    
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

  Widget _buildPasajeros() {
    final ticket = _ticketData!['ticket_embarque'];
    final pasajeros = ticket['pasajeros'] as List;
    
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
              Icon(Icons.people, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Pasajeros',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...pasajeros.map((pasajero) => _buildPasajeroItem(pasajero)),
        ],
      ),
    );
  }

  Widget _buildPasajeroItem(Map<String, dynamic> pasajero) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _azulNautico.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: _azulNautico, width: 2),
            ),
            child: const Icon(Icons.person, color: _azulNautico, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pasajero['nombre_completo'],
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      'DNI: ${pasajero['dni']}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: pasajero['datos_validados'] 
                            ? _verdeExito.withOpacity(0.1)
                            : _naranjaAlerta.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        pasajero['datos_validados'] ? '✅ Validado' : '⏳ Pendiente',
                        style: TextStyle(
                          fontSize: 10,
                          color: pasajero['datos_validados'] ? _verdeExito : _naranjaAlerta,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildBultos() {
    final ticket = _ticketData!['ticket_embarque'];
    final bultos = ticket['bultos'];
    
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
              Icon(Icons.inventory_2, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Bultos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildInfoCard(
                  'Total Bultos',
                  bultos['total_bultos'].toString(),
                  Icons.inventory,
                  _azulNautico,
                ),
              ),
              Expanded(
                child: _buildInfoCard(
                  'Carnada',
                  bultos['detalle'][0]['cantidad'].toString(),
                  Icons.set_meal,
                  _naranjaAlerta,
                ),
              ),
              Expanded(
                child: _buildInfoCard(
                  'Bebidas',
                  bultos['detalle'][1]['cantidad'].toString(),
                  Icons.local_drink,
                  _verdeExito,
                ),
              ),
              Expanded(
                child: _buildInfoCard(
                  'Proteccion',
                  bultos['detalle'][2]['cantidad'].toString(),
                  Icons.wb_sunny,
                  _grisDescanso,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadoYAcciones() {
    final ticket = _ticketData!['ticket_embarque'];
    final estado = ticket['estado'];
    
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
              Icon(Icons.info, color: _azulNautico),
              const SizedBox(width: 8),
              const Text(
                'Estado del Viaje',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _azulNautico,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildEstadoChip('Cotizacion', estado['cotizacion']),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEstadoChip('Pago', estado['pago']),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildEstadoChip('Contacto', estado['contacto_habilitado'] ? 'Habilitado' : 'No habilitado'),
              ),
            ],
          ),
          
          if (!estado['contacto_habilitado']) ...[
            const SizedBox(height: 16),
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
                      'El contacto con el capitan se habilitara una vez que el pago sea confirmado.',
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
        ],
      ),
    );
  }

  Widget _buildEstadoChip(String titulo, String estado) {
    Color color;
    IconData icon;
    
    switch (estado.toLowerCase()) {
      case 'presupuestado':
      case 'habilitado':
        color = _verdeExito;
        icon = Icons.check_circle;
        break;
      case 'pendiente':
        color = _naranjaAlerta;
        icon = Icons.schedule;
        break;
      case 'no habilitado':
        color = _rojoProblema;
        icon = Icons.block;
        break;
      default:
        color = _grisDescanso;
        icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            titulo,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            estado,
            style: TextStyle(
              color: color,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final ticket = _ticketData!['ticket_embarque'];
    final timestamps = ticket['timestamps'];
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.history, color: _grisDescanso, size: 16),
              const SizedBox(width: 8),
              Text(
                'Ticket generado: ${_formatDate(timestamps['creado'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: _grisDescanso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.update, color: _grisDescanso, size: 16),
              const SizedBox(width: 8),
              Text(
                'Ultima actualizacion: ${_formatDate(timestamps['ultima_actualizacion'])}',
                style: TextStyle(
                  fontSize: 12,
                  color: _grisDescanso,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${widget.cotizacionId.substring(0, 8)}...',
            style: TextStyle(
              fontSize: 10,
              color: _grisDescanso,
              fontFamily: 'monospace',
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return 'Fecha desconocida';
    }
  }
}
