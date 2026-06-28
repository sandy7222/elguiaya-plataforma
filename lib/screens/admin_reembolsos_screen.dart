import 'package:flutter/material.dart';
import '../widgets/safe_button.dart';
import '../services/supabase_service.dart';
import '../services/pago_service.dart';
import '../services/mercado_pago_service.dart';

class AdminReembolsosScreen extends StatefulWidget {
  const AdminReembolsosScreen({super.key});

  @override
  State<AdminReembolsosScreen> createState() => _AdminReembolsosScreenState();
}

class _AdminReembolsosScreenState extends State<AdminReembolsosScreen> {
  List<Map<String, dynamic>> _pagos = [];
  List<Map<String, dynamic>> _pagosFiltrados = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _filtroEstado = 'todos';
  String _filtroMetodo = 'todos';

  // Colores Premium CapitánYA
  static const Color _azulNautico = Color(0xFF1565C0);
  static const Color _azulGradiente = Color(0xFF0D47A1);
  static const Color _verdeAprobado = Color(0xFF10B981);
  static const Color _naranjaPendiente = Color(0xFFF59E0B);
  static const Color _rojoReembolsado = Color(0xFFEF4444);
  static const Color _grisDescanso = Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    try {
      setState(() => _isLoading = true);

      // Consulta robusta con join opcional
      dynamic response;
      try {
        response = await SupabaseService.supabase
            .from('pagos')
            .select('*, profiles(nombre, email)')
            .order('fecha_pago', ascending: false);
      } catch (e) {
        // Fallback si falla el join por políticas o claves foráneas
        response = await SupabaseService.supabase
            .from('pagos')
            .select('*')
            .order('fecha_pago', ascending: false);
      }

      final List<dynamic> data = response as List<dynamic>? ?? [];
      
      setState(() {
        _pagos = List<Map<String, dynamic>>.from(data);
        _aplicarFiltros();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar pagos: $e')),
            backgroundColor: _rojoReembolsado,
          ),
        );
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _pagosFiltrados = _pagos.where((pago) {
        // Filtro de búsqueda
        final query = _searchQuery.toLowerCase();
        final transaccionId = (pago['transaccion_id'] ?? '').toString().toLowerCase();
        final reservaId = (pago['reserva_id'] ?? '').toString().toLowerCase();
        final email = (pago['profiles']?['email'] ?? '').toString().toLowerCase();
        final nombre = (pago['profiles']?['nombre'] ?? '').toString().toLowerCase();
        
        final coincideSearch = query.isEmpty ||
            transaccionId.contains(query) ||
            reservaId.contains(query) ||
            email.contains(query) ||
            nombre.contains(query);

        // Filtro de estado
        final estado = (pago['estado'] ?? '').toString().toLowerCase();
        final coincideEstado = _filtroEstado == 'todos' || estado == _filtroEstado;

        // Filtro de método de pago
        final metodo = (pago['metodo_pago'] ?? '').toString().toLowerCase();
        final coincideMetodo = _filtroMetodo == 'todos' || metodo == _filtroMetodo;

        return coincideSearch && coincideEstado && coincideMetodo;
      }).toList();
    });
  }

  void _verificarEstadoMP(String paymentId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: _azulNautico),
      ),
    );

    try {
      final estadoMP = await MercadoPagoService.verificarPago(paymentId);
      if (mounted) {
        Navigator.pop(context); // Cerrar loader
        
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: _azulNautico),
                SizedBox(width: 8),
                Text('Estado en Mercado Pago'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID Transacción: ${estadoMP.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Estado Pasarela: ${estadoMP.status.toUpperCase()}'),
                Text('Detalle: ${estadoMP.statusDetail}'),
                Text('Monto: ${PagoService.formatearMonto(estadoMP.transactionAmount)}'),
                if (estadoMP.payerEmail != null)
                  Text('Pagador: ${estadoMP.payerEmail}'),
                if (estadoMP.dateApproved != null)
                  Text('Aprobado el: ${estadoMP.dateApproved!.toLocal().toString().substring(0, 16)}'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al verificar: $e'),
            backgroundColor: _rojoReembolsado,
          ),
        );
      }
    }
  }

  void _confirmarReembolso(Map<String, dynamic> pago) {
    final String pagoId = pago['id'].toString();
    final String transaccionId = pago['transaccion_id'] ?? 'N/A';
    final double monto = (pago['monto'] as num?)?.toDouble() ?? 0.0;
    final String metodo = pago['metodo_pago'] ?? '';
    final String reservaId = pago['reserva_id'] ?? '';
    final motivoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.settings_backup_restore_rounded, color: _rojoReembolsado),
            const SizedBox(width: 8),
            Text(metodo == 'mercado_pago' ? 'Reembolso Mercado Pago' : 'Confirmar Reembolso'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vas a realizar un reembolso por ${PagoService.formatearMonto(monto)}.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Reserva/Pedido: $reservaId'),
              Text('Transacción ID: $transaccionId'),
              const SizedBox(height: 16),
              if (metodo == 'mercado_pago')
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: _rojoReembolsado, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'IMPORTANTE: Esto devolverá el dinero real al cliente en su cuenta de Mercado Pago/Tarjeta.',
                          style: TextStyle(color: _rojoReembolsado, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              TextField(
                controller: motivoController,
                decoration: const InputDecoration(
                  labelText: 'Motivo del Reembolso',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: Cancelación del capitán, arrepentimiento...',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              _procesarReembolso(pagoId, motivoController.text);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _rojoReembolsado,
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirmar Reembolso'),
          ),
        ],
      ),
    );
  }

  Future<void> _procesarReembolso(String pagoId, String motivo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: _azulNautico),
      ),
    );

    try {
      final result = await PagoService.solicitarReembolso(
        pagoId: pagoId,
        motivo: motivo.isEmpty ? 'Reembolso administrativo' : motivo,
      );

      if (mounted) {
        Navigator.pop(context); // Cerrar loader
        
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('✅ Reembolso exitoso: ${result['mensaje']}')),
              backgroundColor: _verdeAprobado,
            ),
          );
          _cargarPagos(); // Recargar datos
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Error en Reembolso: ${result['error']}'),
              backgroundColor: _rojoReembolsado,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Cerrar loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Excepción: $e'),
            backgroundColor: _rojoReembolsado,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Cabecera con Degradé Premium
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_azulNautico, _azulGradiente],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Centro de Gestión de Reembolsos',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Monitoreá pagos y autorizá devoluciones de dinero de Mercado Pago con un clic.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          // Barra de Búsqueda y Filtros
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Buscá por Transacción ID, Reserva ID, Cliente o Email...',
                        prefixIcon: Icon(Icons.search, color: _azulNautico),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                          borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: (val) {
                        _searchQuery = val;
                        _aplicarFiltros();
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filtroEstado,
                            decoration: const InputDecoration(
                              labelText: 'Estado',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'todos', child: Text('Todos los Estados')),
                              DropdownMenuItem(value: 'confirmado', child: Text('Confirmado')),
                              DropdownMenuItem(value: 'reembolsado', child: Text('Reembolsado')),
                              DropdownMenuItem(value: 'fallido', child: Text('Fallido')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                _filtroEstado = val;
                                _aplicarFiltros();
                              }
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _filtroMetodo,
                            decoration: const InputDecoration(
                              labelText: 'Método de Pago',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'todos', child: Text('Todos los Métodos')),
                              DropdownMenuItem(value: 'mercado_pago', child: Text('Mercado Pago')),
                              DropdownMenuItem(value: 'tarjeta_credito', child: Text('Tarjeta de Crédito')),
                              DropdownMenuItem(value: 'tarjeta_debito', child: Text('Tarjeta de Crédito')),
                              DropdownMenuItem(value: 'transferencia', child: Text('Transferencia')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                _filtroMetodo = val;
                                _aplicarFiltros();
                              }
                            },
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),

          // Listado de Pagos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _azulNautico))
                : _pagosFiltrados.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey[400]),
                            const SizedBox(height: 16),
                            Text(
                              'No se encontraron pagos',
                              style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarPagos,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _pagosFiltrados.length,
                          itemBuilder: (context, index) {
                            final pago = _pagosFiltrados[index];
                            final String transaccionId = pago['transaccion_id'] ?? 'N/A';
                            final String reservaId = pago['reserva_id'] ?? 'N/A';
                            final double monto = (pago['monto'] as num?)?.toDouble() ?? 0.0;
                            final String metodo = pago['metodo_pago'] ?? '';
                            final String estado = pago['estado'] ?? 'pendiente';
                            final DateTime fecha = DateTime.tryParse(pago['fecha_pago'] ?? '') ?? DateTime.now();

                            final String clienteNombre = pago['profiles']?['nombre'] ?? 'Desconocido';
                            final String clienteEmail = pago['profiles']?['email'] ?? '';

                            // Badge de estado
                            Color badgeColor = _naranjaPendiente;
                            String estadoTexto = estado.toUpperCase();
                            if (estado == 'confirmado') {
                              badgeColor = _verdeAprobado;
                              estadoTexto = 'CONFIRMADO';
                            } else if (estado == 'reembolsado') {
                              badgeColor = _rojoReembolsado;
                              estadoTexto = 'REEMBOLSADO';
                            } else if (estado == 'fallido') {
                              badgeColor = _grisDescanso;
                              estadoTexto = 'FALLIDO';
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 1,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          PagoService.formatearMonto(monto),
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: _azulNautico,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: badgeColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: badgeColor.withOpacity(0.3)),
                                          ),
                                          child: Text(
                                            estadoTexto,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: badgeColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.person, size: 16, color: _grisDescanso),
                                        const SizedBox(width: 8),
                                        Text('Cliente: $clienteNombre ${clienteEmail.isNotEmpty ? "($clienteEmail)" : ""}'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.payment, size: 16, color: _grisDescanso),
                                        const SizedBox(width: 8),
                                        Text('Método: ${PagoService.formatearMetodoPago(metodo)}'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.vpn_key_rounded, size: 16, color: _grisDescanso),
                                        const SizedBox(width: 8),
                                        Text('Transacción MP: $transaccionId'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.sailing_rounded, size: 16, color: _grisDescanso),
                                        const SizedBox(width: 8),
                                        Text('Reserva/Pedido ID: $reservaId'),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 16, color: _grisDescanso),
                                        const SizedBox(width: 8),
                                        Text('Fecha: ${fecha.toLocal().toString().substring(0, 16)}'),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        if (metodo == 'mercado_pago' && transaccionId != 'N/A' && transaccionId.isNotEmpty) ...[
                                          SafeOutlinedIconButton(
                                            onPressed: () => _verificarEstadoMP(transaccionId),
                                            icon: Icons.cloud_sync_rounded,
                                            iconSize: 16,
                                            label: 'Verificar MP',
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: _azulNautico,
                                              side: const BorderSide(color: _azulNautico),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        if (estado == 'confirmado')
                                          SafeElevatedIconButton(
                                            onPressed: () => _confirmarReembolso(pago),
                                            icon: Icons.settings_backup_restore_rounded,
                                            iconSize: 16,
                                            label: 'Reembolsar',
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _rojoReembolsado,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          ),
                        ),
                      ),
        ],
      ),
    );
  }
}
