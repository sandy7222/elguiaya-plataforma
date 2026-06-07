
import 'package:flutter/material.dart';

import '../models/categoria.dart';
import '../models/producto.dart';
import '../services/supabase_service.dart';
import 'product_catalog_screen.dart';

class RubroLandingScreen extends StatefulWidget {
  final String rubroNombre;
  final String? parentCategoryId;
  final String? parentCategoryName;
  
  const RubroLandingScreen({
    super.key,
    required this.rubroNombre,
    this.parentCategoryId,
    this.parentCategoryName,
  });

  @override
  State<RubroLandingScreen> createState() => _RubroLandingScreenState();
}

class _RubroLandingScreenState extends State<RubroLandingScreen> {
  List<Categoria> _categorias = [];
  List<Producto> _destacados = [];
  bool _isLoading = true;

  static const Color _azulProfundo = Color(0xFF001529);
  static const Color _azulCapitan = Color(0xFF001F3F);
  static const Color _naranjaAccent = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      final results = await Future.wait([
        SupabaseService.getCategorias(soloActivas: true),
        SupabaseService.getProductosDestacados(),
      ]);

      if (mounted) {
        setState(() {
          final todas = results[0] as List<Categoria>;
          
          if (widget.parentCategoryId != null) {
            // Si venimos de una categoria padre, mostramos sus hijos
            _categorias = todas.where((c) => c.parentId == widget.parentCategoryId).toList();
          } else {
            // Si es la landing principal del rubro, mostramos solo las que no tienen padre
            final search = widget.rubroNombre.toLowerCase();
            _categorias = todas.where((c) {
              if (c.parentId != null) return false; // Solo padres
              
              final nombre = c.nombre.toLowerCase();
              final desc = c.descripcion.toLowerCase();
              return nombre.contains(search) || desc.contains(search) ||
                     (search == 'pesca' && (nombre.contains('reel') || nombre.contains('caña') || nombre.contains('ascesorio') || nombre.contains('accesor'))) ||
                     (search == 'camping' && (nombre.contains('carpa') || nombre.contains('cocina')));
            }).toList();
          }

          // Destacados específicos (mostramos solo 4 relacionados con el contexto)
          final todosDestacados = results[1] as List<Producto>;
          
          if (widget.parentCategoryId != null) {
            // Destacados de esta categoria especifica
            _destacados = todosDestacados.where((p) => p.categoriaId == widget.parentCategoryId).take(4).toList();
          } else {
            // Destacados del rubro general (Pesca/Camping)
            final search = widget.rubroNombre.toLowerCase();
            _destacados = todosDestacados.where((p) {
              return p.nombre.toLowerCase().contains(search) || 
                     p.descripcion.toLowerCase().contains(search) ||
                     (search == 'pesca' && (p.nombre.toLowerCase().contains('reel') || p.nombre.toLowerCase().contains('caña')));
            }).take(4).toList();
          }

          // Si no hay específicos, mostramos los generales para no dejar la vitrina vacía
          if (_destacados.isEmpty) {
            _destacados = todosDestacados.take(4).toList();
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _azulProfundo,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_azulCapitan, _azulProfundo],
          ),
        ),
        child: SafeArea(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator(color: _naranjaAccent))
            : CustomScrollView(
                slivers: [
                  _buildAppBar(),
                  if (widget.parentCategoryId == null) ...[
                    SliverToBoxAdapter(child: _buildFeaturedTitle()),
                    _buildFeaturedGrid(),
                  ],
                  SliverToBoxAdapter(child: _buildCategoriesTitle()),
                  _buildCategoriesGrid(),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 120,
      floating: false,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          (widget.parentCategoryName ?? widget.rubroNombre).toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16),
        ),
        centerTitle: true,
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildFeaturedTitle() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 20, 24, 16),
      child: Text(
        'ARTÍCULOS DESTACADOS',
        style: TextStyle(color: _naranjaAccent, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildFeaturedGrid() {
    if (_destacados.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(child: Text('Cargando novedades...', style: TextStyle(color: Colors.white24))),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final prod = _destacados[index];
            return _buildProductCard(prod);
          },
          childCount: _destacados.length,
        ),
      ),
    );
  }

  Widget _buildProductCard(Producto prod) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: Image.network(
                 prod.imagenUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(color: Colors.white10);
                },
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.shopping_bag, color: Colors.white24),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  prod.precioFormateado,
                  style: const TextStyle(color: _naranjaAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      child: Text(
        widget.parentCategoryName == null ? 'CATEGORÍAS DE PRODUCTOS' : 'SUBCATEGORÍAS DE ${widget.parentCategoryName?.toUpperCase()}',
        style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );
  }

  Widget _buildCategoriesGrid() {
    if (_categorias.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: Center(child: Text('Próximamente más subcategorías...', style: TextStyle(color: Colors.white24))),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.6,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final cat = _categorias[index];
            return _buildCategoryItem(cat);
          },
          childCount: _categorias.length,
        ),
      ),
    );
  }

  Widget _buildCategoryItem(Categoria cat) {
    return GestureDetector(
      onTap: () async {
        // Verificar si esta categoria tiene subcategorias (hijos)
        final todas = await SupabaseService.getCategorias(soloActivas: true);
        final tieneHijos = todas.any((c) => c.parentId == cat.id);

        if (tieneHijos) {
          // Si tiene hijos, abrimos otra Landing con esos hijos
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => RubroLandingScreen(
                  rubroNombre: widget.rubroNombre,
                  parentCategoryId: cat.id,
                  parentCategoryName: cat.nombre,
                ),
              ),
            );
          }
        } else {
          // Si no tiene hijos, vamos al catalogo
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductCatalogScreen(initialCategoryId: cat.id),
              ),
            );
          }
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _naranjaAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: _naranjaAccent.withOpacity(0.3)),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.parentCategoryId == null ? Icons.folder_open_rounded : Icons.label_important_outline_rounded, 
                color: _naranjaAccent, 
                size: 24
              ),
              const SizedBox(height: 6),
              Text(
                cat.nombre.toUpperCase(),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
