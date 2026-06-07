import 'dart:async';
import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/failsafe_background.dart';

class ViajesProgramadosScreen extends StatefulWidget {
  final bool esCapitan;
  const ViajesProgramadosScreen({super.key, required this.esCapitan});

  @override
  State<ViajesProgramadosScreen> createState() =>
      _ViajesProgramadosScreenState();
}

class _ViajesProgramadosScreenState extends State<ViajesProgramadosScreen> {
  List<Map<String, dynamic>> _viajes = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cargarViajes();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {}); // Refresh para la cuenta regresiva
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _cargarViajes() async {
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;

      final query = SupabaseService.supabase.from('pedidos').select('''
        *,
        presupuestos (*),
        profiles:pescador_id (nombre, avatar_url, telefono),
        capitan:capitan_id (nombre, avatar_url, telefono)
      ''');

      final response =
          await (widget.esCapitan
                  ? query.eq('capitan_id', userId)
                  : query.eq('pescador_id', userId))
              .order('fecha_servicio', ascending: true);

      setState(() {
        _viajes = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      print('Error cargando viajes: $e');
      setState(() => _isLoading = false);
    }
  }

  String _getCuentaRegresiva(String fechaIso) {
    final fecha = DateTime.parse(fechaIso);
    final ahora = DateTime.now();
    final diferencia = fecha.difference(ahora);

    if (diferencia.isNegative) return "EN CURSO / FINALIZADO";

    final dias = diferencia.inDays;
    final horas = diferencia.inHours % 24;
    final minutos = diferencia.inMinutes % 60;
    final segundos = diferencia.inSeconds % 60;

    return "${dias}d ${horas}h ${minutos}m ${segundos}s";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: Text(
          widget.esCapitan ? 'MIS SERVICIOS' : 'MIS VIAJES',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: FailsafeBackground(
        opacity: 0.8,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E676)),
              )
            : _viajes.isEmpty
            ? _buildEmptyState()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _viajes.length,
                itemBuilder: (context, index) =>
                    _buildViajeCard(_viajes[index]),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.anchor_outlined,
            size: 80,
            color: Colors.white.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            'No hay viajes programados aún.',
            style: TextStyle(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildViajeCard(Map<String, dynamic> viaje) {
    final bool pagado = viaje['estado'] == 'pagado';
    final String countdown = _getCuentaRegresiva(viaje['fecha_servicio']);
    final Map<String, dynamic> contraparte = (widget.esCapitan
        ? viaje['profiles']
        : viaje['capitan']) ?? {};

    return GestureDetector(
      onTap: () {
        // Al tocar la tarjeta, abrimos el desglose de manifiesto de pasajeros y mercadería
        showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF001F3F),
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (context) => DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) => _ViajeDetallesSheetContent(
              viajeId: viaje['id']?.toString() ?? '',
              scrollController: scrollController,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: pagado
                ? const Color(0xFF00E676).withOpacity(0.3)
                : Colors.white10,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              // Header: Cuenta Regresiva
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                color: pagado
                    ? const Color(0xFF00E676).withOpacity(0.2)
                    : Colors.white.withOpacity(0.05),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ZARPE EN:',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      countdown,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 25,
                          backgroundColor: Colors.white10,
                          backgroundImage: contraparte['avatar_url'] != null
                              ? NetworkImage(contraparte['avatar_url'])
                              : null,
                          child: contraparte['avatar_url'] == null
                              ? const Icon(Icons.person, color: Colors.white54)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contraparte['nombre'] ?? 'Usuario',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.esCapitan
                                    ? 'Pescador (Tocar para ver manifiesto)'
                                    : 'Capitán Responsable',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '\$${viaje['monto_total']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              pagado ? 'PAGADO' : 'PENDIENTE',
                              style: TextStyle(
                                color: pagado
                                    ? const Color(0xFF00E676)
                                    : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 15),
                      child: Divider(color: Colors.white10),
                    ),

                    // SECCIÓN SEGURA: Datos de contacto
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: pagado
                          ? Row(
                              children: [
                                const Icon(
                                  Icons.phone,
                                  color: Color(0xFF00E676),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  contraparte['telefono'] ?? 'Sin teléfono',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () {}, // Lógica de WhatsApp
                                  icon: const Icon(
                                    Icons.message,
                                    color: Color(0xFF00E676),
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Contacto oculto hasta confirmar el pago',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {}, // Abrir pasarela
                                  child: const Text(
                                    'PAGAR',
                                    style: TextStyle(
                                      color: Color(0xFF00E676),
                                      fontWeight: FontWeight.bold,
                                    ),
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
      ),
    );
  }
}

// ─── HOJA DE DETALLES PREMIUM (MANIFIESTO + MERCADERÍA) ───────────────────────
class _ViajeDetallesSheetContent extends StatefulWidget {
  final String viajeId;
  final ScrollController scrollController;

  const _ViajeDetallesSheetContent({
    required this.viajeId,
    required this.scrollController,
  });

  @override
  State<_ViajeDetallesSheetContent> createState() => _ViajeDetallesSheetContentState();
}

class _ViajeDetallesSheetContentState extends State<_ViajeDetallesSheetContent> {
  bool _loading = true;
  List<Map<String, dynamic>> _pasajeros = [];
  List<Map<String, dynamic>> _items = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final supabase = SupabaseService.supabase;

      // 1. Cargar manifiesto de pasajeros
      final resPasajeros = await supabase
          .from('viajes_invitados')
          .select()
          .eq('pedido_id', widget.viajeId)
          .order('es_titular', ascending: false);

      // 2. Cargar items del pedido
      final resItems = await supabase
          .from('pedido_items')
          .select('*, productos(*)')
          .eq('pedido_id', widget.viajeId);

      if (mounted) {
        setState(() {
          _pasajeros = List<Map<String, dynamic>>.from(resPasajeros);
          _items = List<Map<String, dynamic>>.from(resItems);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _verFotoDNI(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF001F3F),
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: const Text('Foto DNI Pasajero', style: TextStyle(fontSize: 14)),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: InteractiveViewer(
                  maxScale: 4.0,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const SizedBox(
                        height: 200,
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
                      );
                    },
                    errorBuilder: (_, __, ___) => const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No se pudo cargar la imagen del DNI',
                          style: TextStyle(color: Colors.white60),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          // Indicador de arrastre
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.assignment_ind, color: Color(0xFF00E676), size: 24),
              SizedBox(width: 10),
              Text(
                'MANIFIESTO Y CARGA',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Reserva ID: ${widget.viajeId.toUpperCase().substring(0, 12)}...',
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white10),
          const SizedBox(height: 10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : _error != null
                    ? Center(
                        child: Text(
                          'Error al obtener detalles: $_error',
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    : ListView(
                        controller: widget.scrollController,
                        children: [
                          // ─── SECCIÓN 1: PASAJEROS ──────────────────────────────
                          _buildSeccionHeader('MANIFIESTO DE PASAJEROS (DDJJ)', Icons.people),
                          const SizedBox(height: 10),
                          if (_pasajeros.isEmpty)
                            _buildEmptyState('Aún no se han declarado pasajeros.')
                          else
                            ..._pasajeros.map((p) {
                              final bool esTitular = p['es_titular'] == true;
                              final String? fotoUrl = p['foto_dni_url'];

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: esTitular
                                        ? const Color(0xFF00E676).withOpacity(0.4)
                                        : Colors.white10,
                                    width: esTitular ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: esTitular
                                          ? const Color(0xFF00E676).withOpacity(0.2)
                                          : Colors.white10,
                                      child: Icon(
                                        esTitular ? Icons.star : Icons.person_outline,
                                        color: esTitular ? const Color(0xFF00E676) : Colors.white60,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${p['nombre'] ?? ''} ${p['apellido'] ?? ''}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'DNI: ${p['dni'] ?? 'Sin DNI'}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (fotoUrl != null && fotoUrl.isNotEmpty)
                                      IconButton(
                                        icon: const Icon(Icons.badge, color: Color(0xFF00E676)),
                                        tooltip: 'Ver foto DNI',
                                        onPressed: () => _verFotoDNI(fotoUrl),
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),

                          const SizedBox(height: 24),
                          const Divider(color: Colors.white10),
                          const SizedBox(height: 10),

                          // ─── SECCIÓN 2: MERCADERÍA ─────────────────────────────
                          _buildSeccionHeader('MERCADERÍA A PREPARAR A BORDO', Icons.shopping_bag_outlined),
                          const SizedBox(height: 6),
                          const Text(
                            '⚠️ Preparar en la lancha antes de salir de Glew',
                            style: TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (_items.isEmpty)
                            _buildEmptyState('Solo servicio de lancha (sin mercadería extra).')
                          else
                            ..._items.map((item) {
                              final prod = item['productos'] ?? {};
                              final String nombreProd = prod['nombre'] ?? 'Producto';
                              final String imgUrl = prod['imagen_url'] ?? '';
                              final int cant = (item['cantidad'] as num?)?.toInt() ?? 1;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: imgUrl.isNotEmpty
                                          ? Image.network(
                                              imgUrl,
                                              width: 50,
                                              height: 50,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.image_not_supported_outlined,
                                                  color: Colors.white24),
                                            )
                                          : const Icon(Icons.shopping_bag, color: Colors.white24),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            nombreProd,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Cant: $cant x \$${item['precio_unitario'] ?? '0'}',
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00E676).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'x$cant',
                                        style: const TextStyle(
                                          color: Color(0xFF00E676),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          const SizedBox(height: 40),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeccionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white60, size: 20),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String msg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Center(
        child: Text(
          msg,
          style: const TextStyle(color: Colors.white38, fontSize: 13, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
