

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';


class TicketDemoScreen extends StatefulWidget {
  final String reservaId;

  const TicketDemoScreen({super.key, required this.reservaId});

  @override
  State<TicketDemoScreen> createState() => _TicketDemoScreenState();
}

class _TicketDemoScreenState extends State<TicketDemoScreen> {
  bool _isProcessing = false;
  final bool _isGeneratingTicket = false;
  bool _isLoading = true;
  
  // Datos de la reserva cargados desde Supabase
  Map<String, dynamic>? _reservaData;
  Map<String, dynamic>? _guiaData;
  String? _guiaCbu;

  // Colores CapitanYA - Alto contraste para exteriores
  final Color _fondoOscuro = const Color(0xFF1A1A1A);      // Fondo oscuro
  final Color _blancoPuro = const Color(0xFFFFFFFF);        // Blanco puro
  final Color _azulVibrante = const Color(0xFF0066FF);      // Azul vibrante
  final Color _verdeBrillante = const Color(0xFF00FF00);     // Verde brillante
  final Color _naranjaIntenso = const Color(0xFFFF6600);     // Naranja intenso
  final Color _rojoFuerte = const Color(0xFFFF0000);          // Rojo fuerte

  @override
  void initState() {
    super.initState();
    _loadReservaData();
  }

  Future<void> _loadReservaData() async {
    try {
      final data = await fetchReservaData(widget.reservaId);
      setState(() {
        _reservaData = data['reserva'];
        _guiaData = data['guia'];
        _guiaCbu = data['guiaCbu'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<Map<String, dynamic>> fetchReservaData(String reservaId) async {
    try {
      // Simulacion de datos - en produccion conectar con Supabase
      return {
        'reserva': {
          'id': reservaId,
          'fecha_salida': '2024-12-15',
          'hora_salida': '08:00',
          'punto_encuentro': 'Puerto de Mar del Plata',
          'cantidad_pescadores': 2,
          'precio_total': 25000.0,
          'estado': 'confirmada',
          'metodo_pago': 'transferencia',
          'fecha_pago': '2024-12-10',
        },
        'guia': {
          'nombre': 'Carlos Rodriguez',
          'dni': '12345678',
          'matricula': 'CAP-1234',
          'telefono': '+5491166789456',
          'localidad': 'Mar del Plata',
          'especialidad': 'Pesca de tiburon',
        },
        'guiaCbu': '00000031000000000000000123'
      };
    } catch (e) {
      throw Exception('Error al cargar datos: $e');
    }
  }

  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final formatter = DateFormat('dd/MM/yyyy');
      return formatter.format(date);
    } catch (e) {
      return dateString; // Retorna el string original si hay error
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: fetchReservaData(widget.reservaId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Mostrar spinner mientras carga
          return Scaffold(
            backgroundColor: _fondoOscuro,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_azulVibrante),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Cargando datos de la reserva...',
                    style: TextStyle(
                      color: _blancoPuro,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: _fondoOscuro,
            appBar: AppBar(
              title: const Text('Error'),
              backgroundColor: _rojoFuerte,
              foregroundColor: _blancoPuro,
            ),
            body: Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: TextStyle(
                  color: _blancoPuro,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final data = snapshot.data!;
        final reserva = data['reserva'] as Map<String, dynamic>;
        final guia = data['guia'] as Map<String, dynamic>;
        final guiaCbu = data['guiaCbu'] as String;

        return Scaffold(
          backgroundColor: _fondoOscuro,
          appBar: AppBar(
            title: Text(
              'Ticket - Reserva ${reserva['id']}',
              style: TextStyle(
                color: _blancoPuro,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: _azulVibrante,
            foregroundColor: _blancoPuro,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del ticket
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _azulVibrante,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _azulVibrante.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long,
                        color: _blancoPuro,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CAPITAN YA',
                        style: TextStyle(
                          color: _blancoPuro,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'TICKET DE RESERVA',
                        style: TextStyle(
                          color: _blancoPuro.withOpacity(0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Informacion de la reserva
                _buildSectionTitle('Informacion de la Reserva'),
                _buildInfoCard([
                  _buildInfoItem('ID Reserva', reserva['id'].toString()),
                  _buildInfoItem('Fecha Salida', _formatDate(reserva['fecha_salida'])),
                  _buildInfoItem('Hora', reserva['hora_salida']),
                  _buildInfoItem('Punto Encuentro', reserva['punto_encuentro']),
                  _buildInfoItem('Estado', reserva['estado'].toString().toUpperCase()),
                ]),
                
                const SizedBox(height: 24),
                
                // Informacion del guia
                _buildSectionTitle('Datos del Capitan'),
                _buildInfoCard([
                  _buildInfoItem('Nombre', guia['nombre']),
                  _buildInfoItem('DNI', guia['dni']),
                  _buildInfoItem('Matricula', guia['matricula']),
                  _buildInfoItem('Telefono', guia['telefono']),
                  _buildInfoItem('Localidad', guia['localidad']),
                  _buildInfoItem('Especialidad', guia['especialidad']),
                ]),
                
                const SizedBox(height: 24),
                
                // Detalles del pago
                _buildSectionTitle('Detalles del Pago'),
                _buildPaymentCard(reserva, guiaCbu),
                
                const SizedBox(height: 24),
                
                // Informacion fiscal
                _buildSectionTitle('Informacion Fiscal'),
                _buildFiscalCard(),
                
                const SizedBox(height: 32),
                
                // Boton de accion
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _generarTicketPDF,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verdeBrillante,
                      foregroundColor: _fondoOscuro,
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isProcessing
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(_fondoOscuro),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'GENERANDO...',
                                style: TextStyle(
                                  color: _fondoOscuro,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.picture_as_pdf, color: _fondoOscuro),
                              const SizedBox(width: 8),
                              Text(
                                'GENERAR TICKET PDF',
                                style: TextStyle(
                                  color: _fondoOscuro,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          color: _blancoPuro,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.2)),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: _blancoPuro,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> reserva, String guiaCbu) {
    final precioTotal = (reserva['precio_total'] as num).toDouble();
    final cantidadPescadores = reserva['cantidad_pescadores'] as int;
    final precioPorPersona = precioTotal / cantidadPescadores;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _naranjaIntenso.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _naranjaIntenso.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payment, color: _naranjaIntenso),
              const SizedBox(width: 8),
              Text(
                'RESUMEN DE PAGO',
                style: TextStyle(
                  color: _naranjaIntenso,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildProductoItem('Servicio de pesca', cantidadPescadores, precioPorPersona, precioTotal),
          
          const Divider(color: Colors.white24),
          
          _buildCostoItem('Subtotal', precioTotal),
          _buildCostoItem('Comision plataforma', precioTotal * 0.10),
          _buildCostoItem('Total', precioTotal * 1.10),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _fondoOscuro.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'DATOS DE TRANSFERENCIA',
                  style: TextStyle(
                    color: _naranjaIntenso,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CBU: $guiaCbu',
                  style: TextStyle(
                    color: _blancoPuro,
                    fontSize: 14,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Referencia: RESERVA-${reserva['id']}',
                  style: TextStyle(
                    color: _blancoPuro.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductoItem(String nombre, int cantidad, double precioUnitario, double subtotal) {
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
                  nombre,
                  style: TextStyle(
                    color: _fondoOscuro,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$cantidad x ${_formatCurrency(precioUnitario)}',
                  style: TextStyle(
                    color: _fondoOscuro.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatCurrency(subtotal),
            style: TextStyle(
              color: _naranjaIntenso,
              fontSize: 16,
              fontWeight: FontWeight.bold,
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
            style: TextStyle(
              color: _fondoOscuro.withOpacity(0.8),
              fontSize: 14,
            ),
          ),
          Text(
            _formatCurrency(monto),
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

  Widget _buildFiscalCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _fondoOscuro.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _blancoPuro.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.receipt, color: _azulVibrante),
              const SizedBox(width: 8),
              Text(
                'INFORMACION FISCAL',
                style: TextStyle(
                  color: _azulVibrante,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildInfoFiscal('CUIT', '30-12345678-9', 'Capitan YA S.A.'),
          _buildInfoFiscal('IVA', '21%', 'Responsable Inscripto'),
          _buildInfoFiscal('Ingresos Brutos', '3%', 'Convenio Multilateral'),
          _buildInfoFiscal('Condicion', 'IVA Responsable Inscripto', 'Factura A'),
          
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _azulVibrante.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _azulVibrante.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info, color: _azulVibrante, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Este ticket es un comprobante valido para fines fiscales y de seguro.',
                    style: TextStyle(
                      color: _azulVibrante,
                      fontSize: 12,
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

  Widget _buildInfoFiscal(String concepto, String valor, String descripcion) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$concepto:',
              style: TextStyle(
                color: _blancoPuro.withOpacity(0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    color: _blancoPuro,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  descripcion,
                  style: TextStyle(
                    color: _blancoPuro.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generarTicketPDF() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      // Simulacion de generacion de PDF
      await Future.delayed(const Duration(seconds: 3));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ticket PDF generado exitosamente'),
            backgroundColor: _verdeBrillante,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al generar ticket: $e'),
            backgroundColor: _rojoFuerte,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
}
