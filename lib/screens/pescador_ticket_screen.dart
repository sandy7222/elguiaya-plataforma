

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/safe_button.dart';

class PescadorTicketScreen extends StatefulWidget {
  const PescadorTicketScreen({super.key});

  @override
  State<PescadorTicketScreen> createState() => _PescadorTicketScreenState();
}

class _PescadorTicketScreenState extends State<PescadorTicketScreen> {
  // Colores El Guia YA - Alto contraste para exteriores
  static const Color _fondoOscuro = Color(0xFF1A1A1A);      // Fondo oscuro
  static const Color _blancoPuro = Color(0xFFFFFFFF);        // Blanco puro
  static const Color _azulVibrante = Color(0xFF0066FF);      // Azul vibrante
  static const Color _verdeBrillante = Color(0xFF00FF00);     // Verde brillante
  static const Color _naranjaIntenso = Color(0xFFFF6600);     // Naranja intenso
  static const Color _rojoFuerte = Color(0xFFFF0000);          // Rojo fuerte
  static const Color _amarilloVivo = Color(0xFFFFFF00);       // Amarillo vivo

  // Datos simulados del JSON final ($68.500)
  // Pantalla demo � IDs ficticios, no usar en producci�n.
  static const _kDemoCotizacionId = 'demo-cotizacion-local';
  static const _kDemoCapitanId = 'demo-capitan-local';

  final Map<String, dynamic> _ticketData = {
    "oferta_recibida": {
      "cotizacion_id": _kDemoCotizacionId,
      "fecha_oferta": "2026-03-20T09:00:00Z",
      "estado": "cotizado",
      "capitan": {
        "id": _kDemoCapitanId,
        "nombre": "Capitan Juan Perez",
        "telefono": "+5492231234567",
        "calificacion": 4.8,
        "viajes_realizados": 127
      },
      "presupuesto_capitan": 50000.00,
      "mensaje_capitan": "Excelente dia para la pesca, incluye carnada fresca",
      "detalles_viaje": {
        "descripcion": "Viaje de pesca maritima con amigos - Test de vuelta",
        "fecha_ida": "2026-03-20",
        "hora_encuentro": "09:00",
        "lugar_encuentro": "Puerto de Mar del Plata",
        "cantidad_personas": 4,
        "coordenadas": {
          "origen": {"lat": -38.0022, "lng": -57.5575},
          "destino": {"lat": -38.0022, "lng": -57.5575}
        }
      },
      "productos_tienda": [
        {
          "nombre": "Carnada fresca especial",
          "cantidad": 2,
          "precio_unitario": 5000.00,
          "subtotal": 10000.00,
          "categoria": "carnada"
        },
        {
          "nombre": "Bebidas isotonicas pack x6",
          "cantidad": 1,
          "precio_unitario": 2000.00,
          "subtotal": 2000.00,
          "categoria": "bebidas"
        },
        {
          "nombre": "Protector solar factor 50",
          "cantidad": 2,
          "precio_unitario": 1500.00,
          "subtotal": 3000.00,
          "categoria": "proteccion"
        }
      ],
      "costos": {
        "presupuesto_viaje": 50000.00,
        "productos_tienda": 15000.00,
        "envio_correo": 3500.00,
        "total_final": 68500.00,
        "desglose": [
          {"concepto": "Presupuesto Capitan", "monto": 50000.00},
          {"concepto": "Carnada fresca especial", "monto": 10000.00},
          {"concepto": "Bebidas isotonicas", "monto": 2000.00},
          {"concepto": "Protector solar", "monto": 3000.00},
          {"concepto": "Envio Correo Argentino", "monto": 3500.00}
        ]
      },
      "resumen_financiero": {
        "monto_viaje": 50000.00,
        "monto_productos": 15000.00,
        "monto_envio": 3500.00,
        "monto_total": 68500.00,
        "comision_plataforma": 6850.00,
        "monto_neto": 61650.00,
        "forma_pago": "pendiente"
      },
      "acciones_disponibles": [
        "aceptar_oferta",
        "rechazar_oferta",
        "consultar_capitan",
        "modificar_productos"
      ]
    }
  };

  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final oferta = _ticketData['oferta_recibida'];
    final presupuesto = oferta['presupuesto_capitan'];
    final productos = oferta['productos_tienda'] as List<dynamic>;
    final costos = oferta['costos'];
    final totalFinal = costos['total_final'];

    return Scaffold(
      backgroundColor: _fondoOscuro,
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: _blancoPuro, size: 24),
            const SizedBox(width: 8),
            const Text(
              'Ticket de Embarque',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        backgroundColor: _fondoOscuro,
        foregroundColor: _blancoPuro,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header principal
            _buildHeaderPrincipal(oferta),
            
            // Informacion del Capitan
            _buildInfoCapitan(oferta['capitan']),
            
            // Detalles del Viaje
            _buildDetallesViaje(oferta['detalles_viaje']),
            
            // Productos de Tienda
            _buildProductosTienda(productos),
            
            // Resumen Financiero
            _buildResumenFinanciero(costos, totalFinal),
            
            // Botones de Accion
            _buildBotonesAccion(),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPrincipal(Map<String, dynamic> oferta) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_azulVibrante, _naranjaIntenso],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          const Text(
            '�OFERTA RECIBIDA!',
            style: TextStyle(
              color: _blancoPuro,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Presupuesto: \$${oferta['presupuesto_capitan'].toStringAsFixed(0)}',
            style: const TextStyle(
              color: _blancoPuro,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _blancoPuro.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              oferta['mensaje_capitan'],
              style: const TextStyle(
                color: _blancoPuro,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCapitan(Map<String, dynamic> capitan) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _azulVibrante.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person, color: _azulVibrante, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Capitan',
                      style: TextStyle(
                        color: _fondoOscuro,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      capitan['nombre'],
                      style: const TextStyle(
                        color: _fondoOscuro,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star, color: _amarilloVivo, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          capitan['calificacion'].toString(),
                          style: const TextStyle(
                            color: _fondoOscuro,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '(${capitan['viajes_realizados']} viajes)',
                          style: TextStyle(
                            color: _fondoOscuro.withOpacity(0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Boton de contacto
          SizedBox(
            width: double.infinity,
            height: 48,
            child: SafeElevatedIconButton(
  onPressed: () => _llamarCapitan(capitan['telefono']),
  icon: Icons.phone,
  iconColor: _blancoPuro,
  label: 'Llamar al Capitan',
  textStyle: TextStyle(color: _blancoPuro, fontWeight: FontWeight.bold),
  style: ElevatedButton.styleFrom(
                backgroundColor: _verdeBrillante,
                foregroundColor: _blancoPuro,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
),
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesViaje(Map<String, dynamic> detalles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              const Icon(Icons.info_outline, color: _naranjaIntenso),
              const SizedBox(width: 8),
              const Text(
                'Detalles del Viaje',
                style: TextStyle(
                  color: _fondoOscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDetalleItem('Descripcion', detalles['descripcion']),
          _buildDetalleItem('Fecha', detalles['fecha_ida']),
          _buildDetalleItem('Hora', detalles['hora_encuentro']),
          _buildDetalleItem('Lugar', detalles['lugar_encuentro']),
          _buildDetalleItem('Personas', '${detalles['cantidad_personas']} personas'),
        ],
      ),
    );
  }

  Widget _buildDetalleItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: _fondoOscuro.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _fondoOscuro,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductosTienda(List<dynamic> productos) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _blancoPuro,
        borderRadius: BorderRadius.circular(12),
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
          Row(
            children: [
              const Icon(Icons.shopping_cart, color: _naranjaIntenso),
              const SizedBox(width: 8),
              const Text(
                'Productos de Tienda',
                style: TextStyle(
                  color: _fondoOscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...productos.map((producto) => _buildProductoItem(producto)),
        ],
      ),
    );
  }

  Widget _buildProductoItem(Map<String, dynamic> producto) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _fondoOscuro.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _naranjaIntenso.withOpacity(0.3)),
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
                    color: _fondoOscuro,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${producto['cantidad']} x \$${producto['precio_unitario'].toStringAsFixed(0)}',
                  style: TextStyle(
                    color: _fondoOscuro.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '\$${producto['subtotal'].toStringAsFixed(0)}',
            style: const TextStyle(
              color: _naranjaIntenso,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenFinanciero(Map<String, dynamic> costos, double totalFinal) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_verdeBrillante.withOpacity(0.1), _verdeBrillante.withOpacity(0.2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _verdeBrillante.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money, color: _verdeBrillante),
              const SizedBox(width: 8),
              const Text(
                'Resumen Financiero',
                style: TextStyle(
                  color: _fondoOscuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildCostoItem('Presupuesto Capitan', costos['presupuesto_viaje']),
          _buildCostoItem('Productos Tienda', costos['productos_tienda']),
          _buildCostoItem('Envio Correo Argentino', costos['envio_correo']),
          const Divider(color: Color(0xFF666666)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TOTAL FINAL',
                style: TextStyle(
                  color: _fondoOscuro,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${totalFinal.toStringAsFixed(0)}',
                style: const TextStyle(
                  color: _verdeBrillante,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
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
            style: TextStyle(
              color: _fondoOscuro.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Text(
            '\$${monto.toStringAsFixed(0)}',
            style: TextStyle(
              color: _fondoOscuro,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotonesAccion() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Boton verde de ACEPTAR
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _aceptarOferta,
              style: ElevatedButton.styleFrom(
                backgroundColor: _verdeBrillante,
                foregroundColor: _blancoPuro,
                elevation: 6,
                shadowColor: _verdeBrillante.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: SafeButtonLoadingContent(
                loading: _isProcessing,
                icon: Icons.check_circle,
                iconColor: _blancoPuro,
                idleLabel: 'Aceptar',
                loadingLabel: 'Procesando...',
                textStyle: const TextStyle(
                  color: _blancoPuro,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                spinnerColor: _blancoPuro,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Boton secundario
          SizedBox(
            width: double.infinity,
            height: 48,
            child: SafeOutlinedIconButton(
  onPressed: () => _rechazarOferta(),
  icon: Icons.close,
  iconColor: _rojoFuerte,
  label: 'RECHAZAR',
  textStyle: TextStyle(
                  color: _rojoFuerte,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
  style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _rojoFuerte),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
),
          ),
        ],
      ),
    );
  }

  Future<void> _llamarCapitan(String telefono) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: telefono);
    
    try {
      await launchUrl(phoneUri);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo realizar la llamada: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    }
  }

  Future<void> _aceptarOferta() async {
    setState(() => _isProcessing = true);
    
    try {
      // Simular procesamiento
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: _blancoPuro),
                SizedBox(width: 8),
                Text('�Oferta aceptada exitosamente!'),
              ],
            ),
            backgroundColor: _verdeBrillante,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // Navegar a pantalla de confirmacion
        Navigator.of(context).pushReplacementNamed('/confirmacion');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar oferta: $e'),
            backgroundColor: _rojoFuerte,
          ),
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _rechazarOferta() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechazar Oferta'),
        content: const Text('�Estas seguro que deseas rechazar esta oferta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rechazar', style: TextStyle(color: _rojoFuerte)),
          ),
        ],
      ),
    );
    
    if (confirmar == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.info, color: _blancoPuro),
                SizedBox(width: 8),
                Text('Oferta rechazada'),
              ],
            ),
            backgroundColor: _naranjaIntenso,
            duration: const Duration(seconds: 2),
          ),
        );
        
        Navigator.of(context).pop();
      }
    }
  }
}
