import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/categoria.dart';
import '../models/producto.dart';
import '../providers/cart_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/cart_floating_button.dart';
import 'product_detail_screen.dart';

class ProductCatalogScreen extends StatefulWidget {
  final String? initialCategoryId;
  
  const ProductCatalogScreen({
    super.key,
    this.initialCategoryId,
  });

  @override
  State<ProductCatalogScreen> createState() => _ProductCatalogScreenState();
}

class _ProductCatalogScreenState extends State<ProductCatalogScreen> {
  // Estado de Datos
  List<Producto> _todosProductos = [];
  List<Producto> _productosFiltrados = [];
  List<Categoria> _todasCategorias = [];
  bool _isLoading = true;

  // Estado de Filtros
  String _searchQuery = '';
  String? _categoriaSeleccionada;
  RangeValues _priceRange = const RangeValues(0, 500000);
  String _sortBy = 'relevancia'; // 'precio_bajo', 'precio_alto'
  bool _soloConStock = false;

  @override
  void initState() {
    super.initState();
    _categoriaSeleccionada = widget.initialCategoryId;
    _cargarDatos();
  }

  Future<void> _cargarDatos({bool forceRefresh = false}) async {
    try {
      final hasData = _todosProductos.isNotEmpty && _todasCategorias.isNotEmpty;
      if (!hasData) {
        setState(() => _isLoading = true);
      }
      final results = await Future.wait([
        SupabaseService.getProductos(forceRefresh: forceRefresh),
        SupabaseService.getCategorias(soloActivas: true, forceRefresh: forceRefresh),
      ]);

      setState(() {
        _todosProductos = results[0] as List<Producto>;
        _todasCategorias = results[1] as List<Categoria>;
        _isLoading = false;
      });
      _aplicarFiltros();
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error en catálogo: $e');
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _productosFiltrados = _todosProductos.where((p) {
        final matchSearch = p.nombre.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchCat = _categoriaSeleccionada == null || p.categoriaId == _categoriaSeleccionada;
        final matchPrice = p.precio >= _priceRange.start && p.precio <= _priceRange.end;
        final matchStock = !_soloConStock || p.stock > 0;
        return matchSearch && matchCat && matchPrice && matchStock && p.activo;
      }).toList();

      // Ordenamiento
      if (_sortBy == 'precio_bajo') {
        _productosFiltrados.sort((a, b) => a.precio.compareTo(b.precio));
      } else if (_sortBy == 'precio_alto') {
        _productosFiltrados.sort((a, b) => b.precio.compareTo(a.precio));
      }
    });
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('FILTRAR Y ORDENAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.2)),
                  const SizedBox(height: 24),
                  
                  const Text('Rango de Precio', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  RangeSlider(
                    values: _priceRange,
                    min: 0,
                    max: 1000000,
                    divisions: 20,
                    activeColor: const Color(0xFF00E676),
                    labels: RangeLabels('$_priceRange.start', '$_priceRange.end'),
                    onChanged: (values) {
                      setModalState(() => _priceRange = values);
                      setState(() => _priceRange = values);
                      _aplicarFiltros();
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  const Text('Ordenar por', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 12),
                  _buildSortOption('Relevancia', 'relevancia', setModalState),
                  _buildSortOption('Menor Precio', 'precio_bajo', setModalState),
                  _buildSortOption('Mayor Precio', 'precio_alto', setModalState),

                  const SizedBox(height: 24),
                  SwitchListTile(
                    title: const Text('Solo con Stock disponible', style: TextStyle(fontWeight: FontWeight.bold)),
                    value: _soloConStock,
                    activeThumbColor: const Color(0xFF00E676),
                    onChanged: (val) {
                      setModalState(() => _soloConStock = val);
                      setState(() => _soloConStock = val);
                      _aplicarFiltros();
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      child: const Text('APLICAR FILTROS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSortOption(String label, String value, StateSetter setModalState) {
    final isSelected = _sortBy == value;
    return GestureDetector(
      onTap: () {
        setModalState(() => _sortBy = value);
        setState(() => _sortBy = value);
        _aplicarFiltros();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D47A1).withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? const Color(0xFF0D47A1) : Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF0D47A1) : Colors.black)),
            const Spacer(),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF0D47A1), size: 18),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 600) {
            return _buildDesktopLayout();
          }
          return _buildMobileLayout();
        },
      ),
      floatingActionButton: _buildFloatingCart(),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildHeader(),
        _buildFilterBar(),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _cargarDatos(forceRefresh: true),
                color: const Color(0xFF0D47A1),
                child: _productosFiltrados.isEmpty 
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.5,
                        alignment: Alignment.center,
                        child: _buildEmptyState(),
                      ),
                    )
                  : MasonryGridView.count(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      itemCount: _productosFiltrados.length,
                      itemBuilder: (context, index) => _buildProductCard(_productosFiltrados[index]),
                    ),
              ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Menú Lateral Fijo
        Container(
          width: 260,
          color: Colors.white,
          child: Column(
            children: [
              _buildDesktopHeader(),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildDesktopLateralMenu(),
                ),
              ),
            ],
          ),
        ),
        // Área Principal Expandida
        Expanded(
          child: Column(
            children: [
              _buildDesktopFilterBar(),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: () => _cargarDatos(forceRefresh: true),
                      color: const Color(0xFF0D47A1),
                      child: _productosFiltrados.isEmpty 
                        ? SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Container(
                              height: MediaQuery.of(context).size.height * 0.6,
                              alignment: Alignment.center,
                              child: _buildEmptyState(),
                            ),
                          )
                        : MasonryGridView.count(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(24),
                            crossAxisCount: 4, // 4 columnas en desktop
                            mainAxisSpacing: 24,
                            crossAxisSpacing: 24,
                            itemCount: _productosFiltrados.length,
                            itemBuilder: (context, index) => _buildProductCard(_productosFiltrados[index]),
                          ),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF0D47A1),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20), 
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('TIENDA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 45,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
            child: TextField(
              onChanged: (val) { 
                setState(() => _searchQuery = val); 
                _aplicarFiltros(); 
              },
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
                prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLateralMenu() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CATEGORÍAS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildLateralCategoryItem('Toda la Tienda', null),
          ..._todasCategorias.map((c) => _buildLateralCategoryItem(c.nombre, c.id)),
          
          const SizedBox(height: 32),
          const Text('FILTROS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: Colors.grey, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          const Text('Rango de Precio', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          RangeSlider(
            values: _priceRange,
            min: 0,
            max: 1000000,
            divisions: 20,
            activeColor: const Color(0xFF00E676),
            labels: RangeLabels('\$${_priceRange.start.toInt()}', '\$${_priceRange.end.toInt()}'),
            onChanged: (values) {
              setState(() => _priceRange = values);
              _aplicarFiltros();
            },
          ),
          
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo con Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            value: _soloConStock,
            activeColor: const Color(0xFF00E676),
            onChanged: (val) {
              setState(() => _soloConStock = val);
              _aplicarFiltros();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLateralCategoryItem(String name, String? id) {
    final isSelected = _categoriaSeleccionada == id;
    return InkWell(
      onTap: () {
        setState(() => _categoriaSeleccionada = id);
        _aplicarFiltros();
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D47A1).withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          name, 
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, 
            color: isSelected ? const Color(0xFF0D47A1) : Colors.black87,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          Text('${_productosFiltrados.length} productos encontrados', style: const TextStyle(color: Colors.grey, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          const Text('Ordenar por: ', style: TextStyle(fontSize: 13, color: Colors.grey)),
          DropdownButton<String>(
            value: _sortBy,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.bold),
            items: const [
              DropdownMenuItem(value: 'relevancia', child: Text('Relevancia')),
              DropdownMenuItem(value: 'precio_bajo', child: Text('Menor Precio')),
              DropdownMenuItem(value: 'precio_alto', child: Text('Mayor Precio')),
            ],
            onChanged: (val) {
              if (val != null) {
                setState(() => _sortBy = val);
                _aplicarFiltros();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final catName = _categoriaSeleccionada == null 
        ? 'TODA LA TIENDA' 
        : _todasCategorias.firstWhere((c) => c.id == _categoriaSeleccionada, orElse: () => Categoria.empty()).nombre;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D47A1),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.white), onPressed: () => Navigator.pop(context)),
              Expanded(
                child: Text(catName.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 1.5), textAlign: TextAlign.center),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            height: 50,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(16)),
            child: TextField(
              onChanged: (val) { _searchQuery = val; _aplicarFiltros(); },
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Buscar en esta categoría...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Text('${_productosFiltrados.length} productos encontrados', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
          const Spacer(),
          TextButton.icon(
            onPressed: _showFilterSheet,
            icon: const Icon(Icons.tune, size: 18, color: Color(0xFF0D47A1)),
            label: const Text('FILTROS', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Producto prod) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(producto: prod))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'prod_${prod.id}',
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: CachedNetworkImage(
                  imageUrl: prod.imagenUrl,
                  width: double.infinity,
                  height: 140,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 140,
                    color: const Color(0xFFF0F4F8),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D47A1)),
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 140,
                    color: const Color(0xFFF0F4F8),
                    child: const Center(
                      child: Icon(Icons.image_not_supported, color: Colors.grey, size: 32),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prod.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0A0E12)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    prod.precioFormateado,
                    style: const TextStyle(
                      color: Color(0xFF00C853), // Verde Esmeralda Náutico
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _buildStockBadge(prod),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(Producto prod) {
    final color = prod.stock > 0 ? (prod.stock < 5 ? Colors.orange : Colors.blue) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(prod.estadoStock.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text('No hay productos que coincidan', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget? _buildFloatingCart() {
    return Consumer<CartProvider>(
      builder: (_, cart, _) {
        if (cart.totalItems == 0) return const SizedBox.shrink();
        return CartFloatingButton(
          itemCount: cart.totalItems,
          total: cart.totalFormateado,
          onTap: () => Navigator.pushNamed(context, '/carrito'),
        );
      },
    );
  }
}
