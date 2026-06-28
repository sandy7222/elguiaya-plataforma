import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/safe_button.dart';

import 'chat_screen.dart';

class CapitanVidrieraPublicScreen extends StatefulWidget {
  final String capitanId;
  final String pedidoId;
  final String nombreCapitan;
  final String? fechaViaje;

  const CapitanVidrieraPublicScreen({
    super.key,
    required this.capitanId,
    required this.pedidoId,
    required this.nombreCapitan,
    this.fechaViaje,
  });

  @override
  State<CapitanVidrieraPublicScreen> createState() =>
      _CapitanVidrieraPublicScreenState();
}

class _CapitanVidrieraPublicScreenState extends State<CapitanVidrieraPublicScreen> {
  final _supabase = Supabase.instance.client;
  bool _loading = true;
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from('kiosko_capitan')
          .select('*')
          .eq('capitan_id', widget.capitanId)
          .eq('activo', true)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _productos = List<Map<String, dynamic>>.from(response);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar vidriera: $e')),
        );
      }
    }
  }

  String _fmtFechaViaje() {
    final raw = widget.fechaViaje;
    if (raw == null || raw.isEmpty) return 'próximo viaje';
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(raw).toLocal());
    } catch (_) {
      return raw;
    }
  }

  void _consultarProducto(Map<String, dynamic> producto) {
    final nombre = producto['nombre_producto']?.toString() ?? 'producto';
    final precio = (producto['precio'] as num?)?.toDouble() ?? 0;
    final mensaje =
        'Hola ${widget.nombreCapitan.split(' ').first}, vi en tu Vidriera "$nombre" '
        '(\$${precio.toStringAsFixed(0)}). ¿Podés reservarme para el viaje del ${_fmtFechaViaje()}?';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          reservaId: widget.pedidoId,
          nombreServicio: 'Vidriera — $nombre',
          nombreCliente: widget.nombreCapitan,
          mensajeInicial: mensaje,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Vidriera de ${widget.nombreCapitan.split(' ').first}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0D2847),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _productos.isEmpty
              ? _emptyState()
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _productos.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _productoCard(_productos[i]),
                ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.storefront_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Este capitán aún no publicó productos en su Vidriera.',
              textAlign: TextAlign.center,
              style: GoogleFonts.outfit(fontSize: 15, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            SafeElevatedIconButton(
  onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ChatScreen(
                      reservaId: widget.pedidoId,
                      nombreServicio: 'Consulta Vidriera',
                      nombreCliente: widget.nombreCapitan,
                      mensajeInicial:
                          'Hola ${widget.nombreCapitan.split(' ').first}, ¿tenés carnada, leña u otros insumos disponibles para nuestro viaje del ${_fmtFechaViaje()}?',
                    ),
                  ),
                );
              },
  icon: Icons.message_outlined,
  label: 'Consultar al capitán',
),
          ],
        ),
      ),
    );
  }

  Widget _productoCard(Map<String, dynamic> p) {
    final imagen = p['imagen_url']?.toString();
    final precio = (p['precio'] as num?)?.toDouble() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
            child: imagen != null && imagen.isNotEmpty
                ? Image.network(
                    imagen,
                    width: 90,
                    height: 90,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _placeholderImg(),
                  )
                : _placeholderImg(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1565C0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      p['categoria']?.toString() ?? 'Producto',
                      style: const TextStyle(
                        color: Color(0xFF1565C0),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p['nombre_producto']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  if (p['descripcion'] != null &&
                      p['descripcion'].toString().trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        p['descripcion'].toString(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    '\$${precio.toStringAsFixed(0)}',
                    style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(
              onPressed: () => _consultarProducto(p),
              child: const Text(
                'Reservar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImg() {
    return Container(
      width: 90,
      height: 90,
      color: Colors.grey.shade200,
      child: Icon(Icons.image_outlined, color: Colors.grey.shade400),
    );
  }
}
