import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/categoria.dart';
import '../models/producto.dart';
import '../models/rubro.dart';
import '../services/supabase_service.dart';
import 'product_detail_screen.dart';

class AdminInventarioScreen extends StatefulWidget {
  const AdminInventarioScreen({super.key});

  @override
  State<AdminInventarioScreen> createState() => _AdminInventarioScreenState();
}

class _AdminInventarioScreenState extends State<AdminInventarioScreen> {
  // Estado
  bool _isLoading = true;
  List<Producto> _productos = [];
  List<Categoria> _categorias = [];
  List<Rubro> _rubros = [];
  final _busquedaController = TextEditingController();
  List<Producto> _productosFiltrados = [];

  // Colores Premium CapitanYA
  static const Color _capitanAzul = Color(0xFF001F3F);
  static const Color _capitanNaranja = Color(0xFF00E676);
  static const Color _capitanAzulClaro = Color(0xFF7FDBFF);
  static const Color _glassColor = Color(0x33FFFFFF);
  static const Color _glassBorder = Color(0x4DFFFFFF);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      final productos = await SupabaseService.getProductos();
      final rubros = await SupabaseService.getRubros();
      final categorias = await SupabaseService.getCategorias();
      
      if (mounted) {
        setState(() {
          _productos = productos;
          _productosFiltrados = productos;
          _rubros = rubros;
          _categorias = categorias;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _notificar('Error al cargar datos: $e', isError: true);
      }
    }
  }

  void _filtrarProductos(String query) {
    setState(() {
      if (query.isEmpty) {
        _productosFiltrados = _productos;
      } else {
        final q = query.toLowerCase();
        _productosFiltrados = _productos.where((p) =>
          p.nombre.toLowerCase().contains(q) ||
          p.descripcion.toLowerCase().contains(q) ||
          p.rubro.toLowerCase().contains(q)
        ).toList();
      }
    });
  }

  Map<String, dynamic> _getStockStats() {
    int total = _productos.length;
    int stockBajo = _productos.where((p) => p.stock > 0 && p.stock < 5).length;
    int sinStock = _productos.where((p) => p.stock == 0).length;
    double valorTotal = _productos.fold(0.0, (sum, p) => sum + (p.precio * p.stock));
    
    return {
      'total': total,
      'stockBajo': stockBajo,
      'sinStock': sinStock,
      'valorTotal': valorTotal.toInt(),
    };
  }

  Future<void> _togglePublicacion(Producto producto) async {
    try {
      final nuevoEstado = !producto.activo;
      final productoActualizado = Producto(
        id: producto.id,
        nombre: producto.nombre,
        descripcion: producto.descripcion,
        precio: producto.precio,
        stock: producto.stock,
        rubro: producto.rubro,
        rubroId: producto.rubroId,
        categoriaId: producto.categoriaId,
        imagenUrl: producto.imagenUrl,
        activo: nuevoEstado,
        createdAt: producto.createdAt,
        updatedAt: DateTime.now(),
      );
      
      await SupabaseService.actualizarProducto(productoActualizado);
      _cargarDatos();
      _notificar(nuevoEstado ? 'Producto Republicado' : 'Producto Pausado');
    } catch (e) {
      _notificar('Error: $e', isError: true);
    }
  }

  Future<void> _eliminarProducto(Producto producto) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _capitanAzul,
        title: const Text('¿Eliminar producto?', style: TextStyle(color: Colors.white)),
        content: Text('Esta acción eliminará "${producto.nombre}" de forma permanente.', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.redAccent))
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService.eliminarProductoReal(producto.id);
        _cargarDatos();
        _notificar('Producto eliminado');
      } catch (e) {
        _notificar('Error al eliminar: $e', isError: true);
      }
    }
  }

  void _notificar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stats = _getStockStats();
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('CONTROL DE INVENTARIO', 
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos),
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_capitanAzul, Color(0xFF003366)],
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: _capitanNaranja))
          : Column(
              children: [
                const SizedBox(height: 100),
                _buildKpiHeader(stats),
                _buildSearchBar(),
                _buildTableHeader(),
                Expanded(
                  child: _productosFiltrados.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 40),
                        itemCount: _productosFiltrados.length,
                        itemBuilder: (context, index) => _buildProductoRow(_productosFiltrados[index]),
                      ),
                ),
              ],
            ),
      ),
    );
  }

  Widget _buildKpiHeader(Map<String, dynamic> stats) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildKpiCard('TOTAL', stats['total'].toString(), Icons.inventory_2, _capitanAzulClaro),
          const SizedBox(width: 10),
          _buildKpiCard('ALERTA', stats['stockBajo'].toString(), Icons.warning_amber, Colors.orange),
          const SizedBox(width: 10),
          _buildKpiCard('AGOTADO', stats['sinStock'].toString(), Icons.error_outline, Colors.redAccent),
          const SizedBox(width: 10),
          _buildKpiCard('CAPITAL', '\$${stats['valorTotal']}', Icons.account_balance_wallet, Colors.greenAccent),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: _glassColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 5),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _busquedaController,
        onChanged: _filtrarProductos,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true,
          fillColor: _glassColor,
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _glassBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _capitanAzulClaro)),
        ),
      ),
    );
  }

  Widget _buildTableHeader() {
    return const SizedBox.shrink(); // No se necesita cabecera tabular para tarjetas premium responsivas
  }

  Widget _buildProductoRow(Producto p) {
    final stockColor = p.stock == 0 ? Colors.redAccent : (p.stock < 5 ? Colors.orange : Colors.greenAccent);
    final categoria = _categorias.firstWhere((c) => c.id == p.categoriaId, orElse: () => Categoria(id: '', nombre: 'General', descripcion: '', activa: true, createdAt: DateTime.now(), updatedAt: DateTime.now()));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _glassColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Parte Superior: Información Principal (Imagen, Título, Precio y Stock)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 44, height: 44,
                    color: Colors.white10,
                    child: p.imagenUrl.isNotEmpty 
                      ? Image.network(p.imagenUrl, fit: BoxFit.cover, errorBuilder: (_,_,_) => const Icon(Icons.image, color: Colors.white24, size: 20))
                      : const Icon(Icons.image, color: Colors.white24, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.nombre, 
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13), 
                        maxLines: 1, 
                        overflow: TextOverflow.ellipsis
                      ),
                      const SizedBox(height: 2),
                      Text(categoria.nombre, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('\$${p.precio}', style: const TextStyle(color: _capitanAzulClaro, fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Stock: ${p.stock}', style: TextStyle(color: stockColor, fontWeight: FontWeight.bold, fontSize: 11)),
                        const SizedBox(width: 2),
                        GestureDetector(
                          onTap: () => _mostrarDialogoStockRapido(p),
                          child: const Icon(Icons.edit_note, color: Colors.white70, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(color: Colors.white10, height: 1, thickness: 1),
          
          // 2. Parte Inferior: Botones de Acción Rápidos y Responsivos
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Toggle Activo/Pausado con texto descriptivo
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: p.activo,
                      onChanged: (val) => _togglePublicacion(p),
                      activeThumbColor: _capitanNaranja,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    Text(
                      p.activo ? 'Público' : 'Pausado',
                      style: TextStyle(
                        color: p.activo ? _capitanNaranja : Colors.white38,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                
                // Botón Previa
                IconButton(
                  icon: const Icon(Icons.visibility, color: Colors.white70, size: 18),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(producto: p),
                      ),
                    );
                  },
                  tooltip: 'Ver Previa Exacta',
                ),
                
                // Botón Copiar Link
                IconButton(
                  icon: const Icon(Icons.link, color: _capitanAzulClaro, size: 18),
                  onPressed: () {
                    final url = 'http://localhost:8080/#/producto?id=${p.id}';
                    Clipboard.setData(ClipboardData(text: url));
                    _notificar('¡Link copiado para compartir!');
                  },
                  tooltip: 'Copiar Link para WhatsApp',
                ),
                
                // Botón Eliminar
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                  onPressed: () => _eliminarProducto(p),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _mostrarDialogoStockRapido(Producto p) async {
    final controller = TextEditingController(text: p.stock.toString());
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _capitanAzul,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Ajustar Stock: ${p.nombre}', style: const TextStyle(color: Colors.white, fontSize: 16)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cantidad disponible', 
            labelStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final nuevoStock = int.tryParse(controller.text) ?? p.stock;
              try {
                await SupabaseService.actualizarStock(p.id, nuevoStock);
                Navigator.pop(context);
                _cargarDatos();
                _notificar('Stock actualizado');
              } catch (e) {
                _notificar('Error: $e', isError: true);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _capitanNaranja),
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 16),
          const Text('No hay productos en el inventario', style: TextStyle(color: Colors.white54)),
        ],
      ),
    );
  }
}
