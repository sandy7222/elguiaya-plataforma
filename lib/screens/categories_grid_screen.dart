import 'package:flutter/material.dart' hide CarouselController;
import 'dart:async';
import 'dart:ui';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/categoria.dart';
import '../models/banner_promo.dart';
import '../models/producto.dart';
import '../services/supabase_service.dart';
import '../services/branding_service.dart';
import 'product_catalog_screen.dart';
import 'product_detail_screen.dart';
import 'blog_piques_screen.dart';
import '../providers/favoritos_provider.dart';
import 'favoritos_screen.dart';
import 'help_center_screen.dart';

class CategoriesGridScreen extends StatefulWidget {
  final Categoria? categoriaPadre;
  const CategoriesGridScreen({super.key, this.categoriaPadre});

  @override
  State<CategoriesGridScreen> createState() => _CategoriesGridScreenState();
}

class _CategoriesGridScreenState extends State<CategoriesGridScreen> {
  List<Categoria> _todasCategorias = [];
  List<Categoria> _categoriasFiltradas = [];
  List<BannerPromo> _banners = [];
  List<Producto> _todosProductos = [];
  List<Producto> _productosDestacados = [];
  bool _isLoading = true;
  bool _bajoMantenimiento = false;
  bool _isAdmin = false;
  String? _rubroSeleccionado; // 'pesca' o 'camping'
  String _searchQuery = ""; // Para el buscador inteligente
  final TextEditingController _searchController = TextEditingController();
  
  // Para el carrusel nativo infinito (Ancho total)
  final PageController _pageController = PageController(viewportFraction: 1.0, initialPage: 1000);
  int _currentPage = 1000;
  Timer? _timer;

  // Colores Premium
  static const Color _naranjaAccent = Color(0xFF00E676);
  static const Color _blancoPuro = Colors.white;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _setupRotationListener();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = SupabaseService.supabase.auth.currentUser;
      if (user != null) {
        context.read<FavoritosProvider>().inicializar(user.id);
      }
    });
  }

  Future<void> _checkMantenimiento() async {
    try {
      final user = SupabaseService.supabase.auth.currentUser;
      if (user != null) {
        final email = user.email;
        final rol = user.userMetadata?['rol'];
        if (email == 'admin@capitanya.com' || rol == 'admin') {
          _isAdmin = true;
        }
      }

      final config = await SupabaseService.getSistemaConfig();
      if (config != null) {
        _bajoMantenimiento = config['mantenimiento_tienda'] as bool? ?? false;
      }
    } catch (e) {
      print('⚠️ Error al verificar mantenimiento: $e');
    }
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    await _checkMantenimiento();
    if (_bajoMantenimiento && !_isAdmin) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }
    await Future.wait([
      _cargarCategorias(),
      _cargarBanners(),
      _cargarDestacados(),
    ]);
  }

  Future<void> _cargarBanners() async {
    try {
      final activeBanners = await SupabaseService.getBannersActivos();
      if (mounted) {
        setState(() {
          _banners = activeBanners;
          
          // Inyección del 4to Banner para efecto carrusel premium (si hay 3)
          if (_banners.length == 3) {
            _banners.add(BannerPromo(
              id: 'banner_4_mock',
              titulo: 'NAVEGACIÓN DE PRECISIÓN ⚓',
              subtitulo: 'Equipamiento GPS y Sondas de última generación.',
              imagenUrl: 'https://images.unsplash.com/photo-1567899378494-47b22a2bb96a?q=80&w=2070&auto=format&fit=crop',
              activo: true,
              orden: 4,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              tituloSize: 22,
              subtituloSize: 14,
              textColor: '#FFFFFF',
              tipo: 'hero',
            ));
          }
        });
      }
    } catch (e) {
      debugPrint('Error al cargar banners: $e');
    }
  }

  Future<void> _cargarDestacados() async {
    try {
      final prods = await SupabaseService.getProductos();
      if (mounted) {
        setState(() {
          _todosProductos = prods.where((p) => p.activo).toList();
          _productosDestacados = _todosProductos.where((p) => p.destacado).toList();
        });
      }
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
    }
  }

  void _startTimer(int seconds) {
    _timer?.cancel();
    if (seconds <= 0) return; // Desactivar si es 0
    
    _timer = Timer.periodic(Duration(seconds: seconds), (Timer timer) {
      if (_banners.isNotEmpty) {
        _currentPage++;

        if (_pageController.hasClients) {
          _pageController.animateToPage(
            _currentPage,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOut,
          );
        }
      }
    });
  }

  StreamSubscription? _rotationSubscription;
  void _setupRotationListener() {
    _rotationSubscription?.cancel();
    _rotationSubscription = BrandingService.getBannerRotationStream().listen((seconds) {
      _startTimer(seconds);
    });
  }

  @override
  void dispose() {
    _rotationSubscription?.cancel();
    _timer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final cats = await SupabaseService.getCategorias(soloActivas: true);
      if (mounted) {
        setState(() {
          _todasCategorias = cats;
          _categoriasFiltradas = cats.where((c) => c.parentId == null).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar categorias: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  void _seleccionarRubro(String? rubroId) {
    setState(() {
      _rubroSeleccionado = rubroId;
      if (rubroId == null) {
        _categoriasFiltradas = _todasCategorias.where((c) => c.parentId == null).toList();
      } else if (rubroId == 'camping') {
        _categoriasFiltradas = _todasCategorias.where((c) {
          if (c.parentId != null) return false;
          final name = c.nombre.toLowerCase();
          return name.contains('carpa') || name.contains('cocina') || name.contains('camping') || name.contains('mesas') || name.contains('sillas');
        }).toList();
      } else if (rubroId == 'pesca') {
        _categoriasFiltradas = _todasCategorias.where((c) {
          if (c.parentId != null) return false;
          final name = c.nombre.toLowerCase();
          return name.contains('reel') || name.contains('caña') || name.contains('pesca');
        }).toList();
      } else {
        _categoriasFiltradas = _todasCategorias.where((c) => c.parentId == rubroId).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bajoMantenimiento && !_isAdmin) {
      return _buildMaintenanceScreen(context);
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 900;
          final double contentMargin = isMobile ? 0 : (constraints.maxWidth - 1200) / 2;
          final double hPadding = contentMargin > 0 ? contentMargin : 0;

          return CustomScrollView(
            slivers: [
              // Marquesina fija al inicio
              SliverToBoxAdapter(child: _buildTopAnnouncementBar()),
              _buildModernAppBar(isMobile),
                
                StreamBuilder<List<Categoria>>(
                  stream: SupabaseService.getCategoriasStream(),
                  builder: (context, catSnapshot) {
                    if (!catSnapshot.hasData) {
                      return const SliverToBoxAdapter(child: _SkeletonLoader());
                    }

                    final categories = catSnapshot.data!;

                    return StreamBuilder<List<Producto>>(
                      stream: SupabaseService.getProductosStream(),
                      builder: (context, prodSnapshot) {
                        if (!prodSnapshot.hasData) {
                          return const SliverToBoxAdapter(child: _SkeletonLoader());
                        }

                        final products = prodSnapshot.data!;
                        
                        // ── LÓGICA DE BÚSQUEDA EN TIEMPO REAL ──
                        if (_searchQuery.isNotEmpty) {
                          final matchingProducts = products.where((p) => 
                            p.nombre.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                            (p.descripcion.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false)
                          ).toList();

                          return SliverPadding(
                            padding: const EdgeInsets.all(20),
                            sliver: matchingProducts.isEmpty 
                              ? SliverToBoxAdapter(
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 80.0),
                                      child: Column(
                                        children: [
                                          Icon(Icons.search_off, size: 64, color: Colors.grey[300]),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No se encontraron productos para "$_searchQuery"',
                                            style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text('Intenta con otra palabra clave', style: TextStyle(color: Colors.grey)),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : SliverGrid(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: isMobile ? 2 : 4,
                                    mainAxisSpacing: 15,
                                    crossAxisSpacing: 15,
                                    childAspectRatio: 0.72,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) => _buildProductCard(matchingProducts[index]),
                                    childCount: matchingProducts.length,
                                  ),
                                ),
                          );
                        }

                        final heroBanners = _banners.where((b) => b.tipo == 'hero').toList();
                        final middleBanners = _banners.where((b) => b.tipo == 'middle').toList();
                        final bottomBanners = _banners.where((b) => b.tipo == 'bottom').toList();
                        // product_collection: compatibilidad legacy
                        final productModules = _banners.where((b) => b.tipo == 'product_collection').cast<BannerPromo>().toList();

                        final categorySections = _buildDynamicCategorySections(categories, products);
                        final legacyModules = productModules.map((module) => _buildProductCollectionModule(module, products)).toList();

                        return SliverList(
                          delegate: SliverChildListDelegate([
                            // ── CARRUSEL HERO (SUPERIOR) ──
                            if (heroBanners.isNotEmpty || _banners.isEmpty)
                              _buildBannerCarousel(isMobile, heroBanners),

                            const SizedBox(height: 24),
                            // Contenedor centrado para el contenido
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: hPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── PRIMERA CATEGORÍA ──
                                  if (categorySections.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 20),
                                      child: Text('EXPLORA POR CATEGORÍA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2, color: Colors.black54)),
                                    ),
                                    categorySections[0],
                                  ],
                                ],
                              ),
                            ),

                            // ── CARRUSEL MEDIO ──
                            if (middleBanners.isNotEmpty) ..._buildSliderSection(
                              middleBanners,
                              label: 'DESTACADOS DE LA TEMPORADA',
                              height: 200,
                            ),

                            // ── SEGUNDA CATEGORÍA ──
                            if (categorySections.length > 1) categorySections[1],

                            // ── CARRUSEL INFERIOR ──
                            if (bottomBanners.isNotEmpty) ..._buildSliderSection(
                              bottomBanners,
                              label: bottomBanners.first.tituloSeccion?.toUpperCase() ?? 'COLECCIONES ESPECIALES',
                              height: 200,
                            ),

                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: hPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // ── RESTO DE CATEGORÍAS ──
                                  if (categorySections.length > 2) ...categorySections.sublist(2),

                                  // Módulos legacy product_collection
                                  ...legacyModules,

                                  // ── NOVEDADES / ÚLTIMOS INGRESOS ──
                                  if (products.isNotEmpty) ...[
                                    const SizedBox(height: 32),
                                    _buildNovedadesRow(products),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 80),
                            _buildInstitutionalFooter(),
                            const SizedBox(height: 0),
                          ]),
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      );
  }

  List<Widget> _buildDynamicCategorySections(List<Categoria> categories, List<Producto> products) {
    final activeCats = categories.where((cat) {
      final hasProds = products.any((p) => p.categoriaId == cat.id);
      
      bool isSubcatOfSelected = false;
      if (_rubroSeleccionado == null) {
        isSubcatOfSelected = true;
      } else if (_rubroSeleccionado == 'camping') {
        final name = cat.nombre.toLowerCase();
        isSubcatOfSelected = name.contains('carpa') || name.contains('cocina') || name.contains('camping') || name.contains('mesas') || name.contains('sillas');
      } else if (_rubroSeleccionado == 'pesca') {
        final name = cat.nombre.toLowerCase();
        isSubcatOfSelected = name.contains('reel') || name.contains('caña') || name.contains('pesca');
      } else {
        isSubcatOfSelected = cat.parentId == _rubroSeleccionado || cat.id == _rubroSeleccionado;
      }
      
      return hasProds && isSubcatOfSelected;
    }).toList();

    return activeCats.map((cat) {
      final productosDeCat = products.where((p) => p.categoriaId == cat.id).toList();
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    cat.nombre.toUpperCase(),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductCatalogScreen(initialCategoryId: cat.id))),
                  child: const Text('Ver todos', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: productosDeCat.length,
              itemBuilder: (context, index) => _buildProductCard(productosDeCat[index]),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildTopAnnouncementBar() {
    if (_bajoMantenimiento && _isAdmin) {
      return Container(
        height: 36,
        width: double.infinity,
        color: Colors.redAccent,
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.engineering_rounded, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text(
                'MODO MANTENIMIENTO ACTIVO — Vista previa de Administrador',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final marquees = _banners.where((b) => b.tipo == 'marquee' && b.activo).toList();
    if (marquees.isEmpty) return const SizedBox.shrink();

    final marquee = marquees.first;
    final Color bgColor = Color(int.parse('FF${marquee.backgroundColor?.replaceAll('#', '') ?? '0D47A1'}', radix: 16));
    final Color textColor = Color(int.parse('FF${marquee.textColor.replaceAll('#', '')}', radix: 16));

    return Container(
      height: 36,
      width: double.infinity,
      color: bgColor,
      child: MarqueeWidget(
        text: marquee.titulo,
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1),
        velocity: marquee.velocidad * 10,
        imageUrl: (marquee.imagenUrl.isNotEmpty) ? marquee.imagenUrl : null,
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2E7D32), width: 2.5), // Verde bosque premium
          ),
          child: const Icon(
            Icons.sailing_rounded,
            color: Color(0xFF2E7D32),
            size: 38,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'CapitánYA',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            letterSpacing: 0.5,
            height: 1.1,
          ),
        ),
        const Text(
          'Tu mejor amigo de pesca\nen Argentina',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.black54,
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildModernAppBar(bool isMobile) {
    if (!isMobile) {
      // ─── DISEÑO DE ESCRITORIO (WINDOWS / PC) ───
      return SliverAppBar(
        primary: false,
        floating: true,
        pinned: true,
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        expandedHeight: 140,
        toolbarHeight: 140,
        titleSpacing: 0,
        title: Container(
          height: 140,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // 1. Logo Completo en el extremo izquierdo
              SizedBox(
                width: 200,
                child: _buildLogoHeader(),
              ),
              const SizedBox(width: 24),
              
              // 2. Bloque Central: Buscador (Arriba) + Categorías (Abajo)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Buscador Centrado
                    Container(
                      height: 42,
                      constraints: const BoxConstraints(maxWidth: 550),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F2F5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.black.withOpacity(0.05)),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) => setState(() => _searchQuery = val),
                        decoration: const InputDecoration(
                          hintText: '¿Qué estás buscando hoy?',
                          hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                          prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Fila de Categorías
                    SizedBox(
                      height: 40,
                      child: Center(
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          shrinkWrap: true,
                          children: [
                            _buildCategoryChip('Todos los productos', isSelected: _rubroSeleccionado == null),
                            _buildCategoryChip('Camping', isSelected: _rubroSeleccionado == 'camping' || (_rubroSeleccionado != null && _todasCategorias.any((c) => c.id == _rubroSeleccionado && (c.nombre.toLowerCase().trim().contains('carpa') || c.nombre.toLowerCase().trim().contains('cocina') || c.nombre.toLowerCase().trim().contains('camping') || c.nombre.toLowerCase().trim().contains('mesas') || c.nombre.toLowerCase().trim().contains('sillas'))))),
                            _buildCategoryChip('Pesca', isSelected: _rubroSeleccionado == 'pesca' || (_rubroSeleccionado != null && _todasCategorias.any((c) => c.id == _rubroSeleccionado && (c.nombre.toLowerCase().trim().contains('reel') || c.nombre.toLowerCase().trim().contains('caña') || c.nombre.toLowerCase().trim().contains('pesca'))))),
                            _buildCategoryChip('Accesorios de pesca', isSelected: _rubroSeleccionado != null && _todasCategorias.any((c) => c.id == _rubroSeleccionado && c.nombre.toLowerCase().trim() == 'accesorios de pesca')),
                            _buildCategoryChip('Blogs'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              
              // 3. Iconos de Acción en el extremo derecho
              SizedBox(
                width: 160,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.favorite_border, color: Colors.black54, size: 24),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritosScreen()));
                      },
                    ),
                    const SizedBox(width: 8),
                    _buildCartIndicator(),
                    const SizedBox(width: 16),
                    const Icon(Icons.person_outline, color: Colors.black54, size: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      // ─── DISEÑO DE CELULAR (MOBILE) ───
      return SliverAppBar(
        primary: false,
        floating: true,
        pinned: true,
        backgroundColor: Colors.white,
        elevation: 2,
        shadowColor: Colors.black12,
        expandedHeight: 175,
        toolbarHeight: 60,
        titleSpacing: 16,
        title: Row(
          children: [
            // Logo compacto en móvil
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2E7D32), width: 1.5),
              ),
              child: const Icon(Icons.sailing_rounded, color: Color(0xFF2E7D32), size: 16),
            ),
            const SizedBox(width: 8),
            const Text(
              'CapitánYA',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
                letterSpacing: 0.5,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.favorite_border, color: Colors.black54, size: 22),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritosScreen()));
              },
            ),
            _buildCartIndicator(),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(115),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F2F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.black.withOpacity(0.05)),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    decoration: const InputDecoration(
                      hintText: '¿Qué estás buscando hoy?',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                      prefixIcon: Icon(Icons.search, color: Colors.grey, size: 18),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 55,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  children: [
                    _buildCategoryChip('Todos los productos', isSelected: _rubroSeleccionado == null),
                    _buildCategoryChip('Camping', isSelected: _rubroSeleccionado == 'camping' || (_rubroSeleccionado != null && _todasCategorias.any((c) => c.id == _rubroSeleccionado && (c.nombre.toLowerCase().trim().contains('carpa') || c.nombre.toLowerCase().trim().contains('cocina') || c.nombre.toLowerCase().trim().contains('camping') || c.nombre.toLowerCase().trim().contains('mesas') || c.nombre.toLowerCase().trim().contains('sillas'))))),
                    _buildCategoryChip('Pesca', isSelected: _rubroSeleccionado == 'pesca' || (_rubroSeleccionado != null && _todasCategorias.any((c) => c.id == _rubroSeleccionado && (c.nombre.toLowerCase().trim().contains('reel') || c.nombre.toLowerCase().trim().contains('caña') || c.nombre.toLowerCase().trim().contains('pesca'))))),
                    _buildCategoryChip('Accesorios de pesca', isSelected: _rubroSeleccionado != null && _todasCategorias.any((c) => c.id == _rubroSeleccionado && c.nombre.toLowerCase().trim() == 'accesorios de pesca')),
                    _buildCategoryChip('Blogs'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildCategoryChip(String title, {bool isSelected = false}) {
    return InkWell(
      onTap: () => _onNavLinkTapped(title),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0D47A1) : const Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF0D47A1) : Colors.black.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Categoria? _findCategoryByName(String name) {
    try {
      return _todasCategorias.firstWhere(
        (c) => c.nombre.toLowerCase().trim() == name.toLowerCase().trim() && c.parentId == null,
      );
    } catch (_) {
      return null;
    }
  }

  void _onNavLinkTapped(String title) {
    final t = title.toLowerCase().trim();
    if (t == 'todos los productos') {
      _seleccionarRubro(null);
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
      return;
    }
    
    if (t == 'camping') {
      _seleccionarRubro('camping');
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
      return;
    }

    if (t == 'pesca') {
      _seleccionarRubro('pesca');
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
      return;
    }

    if (t == 'blog' || t == 'blogs') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const BlogPiquesScreen(),
        ),
      );
      return;
    }

    final cat = _findCategoryByName(title);
    if (cat != null) {
      _seleccionarRubro(cat.id);
      setState(() {
        _searchQuery = '';
        _searchController.clear();
      });
    }
  }

  Widget _buildProductCard(Producto prod) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(producto: prod),
          ),
        );
      },
      child: Container(
        width: 180,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: Image.network(
                       prod.imagenUrl,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: const Color(0xFFF0F4F8));
                      },
                      errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Consumer<FavoritosProvider>(
                      builder: (context, favoritos, _) {
                        final esFavorito = favoritos.esFavorito(prod.id);
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: IconButton(
                            icon: Icon(
                              esFavorito ? Icons.favorite : Icons.favorite_border,
                              color: esFavorito ? const Color(0xFFFF3B30) : Colors.grey,
                              size: 20,
                            ),
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              if (SupabaseService.supabase.auth.currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para guardar favoritos')));
                                return;
                              }
                              favoritos.toggleFavorito(prod);
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          prod.nombre,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        _buildStockMiniBadge(prod),
                      ],
                    ),
                    Text(
                      prod.precioFormateado,
                      style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Renderiza un conjunto de banners (middle o bottom) como carrusel de imágenes
  /// con título de sección arriba y scroll horizontal.
  List<Widget> _buildSliderSection(
    List<BannerPromo> banners, {
    required String label,
    double height = 200,
  }) {
    final PageController ctrl = PageController(initialPage: 1000);
    return [
      const SizedBox(height: 28),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            letterSpacing: 0.8,
          ),
        ),
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: height,
        child: PageView.builder(
          controller: ctrl,
          itemCount: 10000,
          itemBuilder: (context, index) {
            final banner = banners[index % banners.length];
            return _buildBannerItem(banner, true);
          },
        ),
      ),
    ];
  }

  Widget _buildProductModule(BannerPromo banner) {
    // Para simplificar y mantener la consistencia, usamos una versión del carrusel 
    // pero con un solo elemento o scroll infinito si hubiera más.
    final List<BannerPromo> moduleBanners = [banner];
    final PageController moduleController = PageController(initialPage: 1000);
    
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: PageView.builder(
        controller: moduleController,
        itemCount: 10000,
        itemBuilder: (context, index) {
          final b = moduleBanners[index % moduleBanners.length];
          return _buildBannerItem(b, true); // true para full width
        },
      ),
    );
  }

  Widget _buildBannerItem(BannerPromo banner, bool isMobile) {
    final String imagenUrl = banner.imagenUrl;
    
    return GestureDetector(
      onTap: () {
        if (banner.productId != null) {
          // Navegar a producto
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0),
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.zero,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.zero,
          child: Image.network(
            imagenUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(child: CircularProgressIndicator(color: Colors.orangeAccent.withOpacity(0.5)));
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[900],
              child: const Icon(Icons.broken_image, color: Colors.white24, size: 50),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStockMiniBadge(Producto prod) {
    final color = prod.stock > 0 ? (prod.stock < 5 ? Colors.orange : Colors.blue) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        prod.estadoStock.toUpperCase(),
        style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildNovedadesRow(List<Producto> productos) {
    final recientes = List<Producto>.from(productos)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    // Mostramos solo aquellos agregados en los ultimos 30 dias, maximo 10
    final hoy = DateTime.now();
    final novedades = recientes
        .where((p) => hoy.difference(p.createdAt).inDays <= 30)
        .take(10)
        .toList();

    // Fallback: si no hay productos recientes del ultimo mes, muestra los ultimos 5 agregados
    final productosAMostrar = novedades.isNotEmpty ? novedades : recientes.take(5).toList();

    if (productosAMostrar.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'NOVEDADES Y NUEVOS INGRESOS',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: productosAMostrar.length,
            itemBuilder: (context, index) {
              final prod = productosAMostrar[index];
              final esNuevo = hoy.difference(prod.createdAt).inDays <= 30;

              return Stack(
                children: [
                  _buildProductCard(prod),
                  if (esNuevo)
                    Positioned(
                      top: 16,
                      left: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 4, offset: const Offset(0, 2))
                          ],
                        ),
                        child: const Text(
                          'NUEVO',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCollectionModule(BannerPromo module, List<Producto> allProducts) {
    // Filtrar productos de la categoria seleccionada
    final categoryProducts = allProducts.where((p) => p.categoriaId == module.categoriaId).toList();
    if (categoryProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  module.tituloSeccion?.toUpperCase() ?? 'COLECCIÓN',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.1),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProductCatalogScreen(initialCategoryId: module.categoriaId)));
                },
                child: const Text('Ver todos', style: TextStyle(color: Color(0xFF0D47A1), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            physics: const BouncingScrollPhysics(),
            itemCount: categoryProducts.length,
            itemBuilder: (context, index) {
              final producto = categoryProducts[index];
              return Container(
                width: 180, // Ancho fijo para permitir que el siguiente se "asome"
                margin: const EdgeInsets.symmetric(horizontal: 5),
                child: _buildProductCard(producto),
              );
            },
          ),
        ),
      ],
    );
  }

  void _mostrarQuienesSomos(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001A33).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.4), width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.anchor, color: Color(0xFF00E676)),
              SizedBox(width: 12),
              Text(
                'QUIÉNES SOMOS',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                  child: Text(
                    '“Nacidos en el río, impulsados por la tecnología, guiados por la pasión”',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'CÓMO NACIMOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'CapitanYA no nació en una oficina fría; nació en el rumor del agua, en el amanecer fresco de un muelle paranaense y en la mirada atenta del guía que conoce el río como la palma de su mano. Nacimos de una necesidad imperiosa: la de unir el mundo tradicional del río y la pesca deportiva con la velocidad y seguridad del siglo XXI.\n\n'
                  'Vimos a capitanes excepcionales batallando con reservas informales por chat, calendarios perdidos en papeles húmedos y comisiones injustas. Vimos a pescadores apasionados buscando aventuras a ciegas, sin saber si la embarcación contaba con las habilitaciones correspondientes o los seguros de navegación al día.\n\n'
                  'Con esa chispa en mente, nos sentamos a escribir las primeras líneas de código. Cada pantalla, cada botón de reserva, cada geofence y cada comisiones de referidos fue forjada a mano con un solo norte: devolverle el protagonismo al Capitán y darle la máxima seguridad al Pescador.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NUESTRA MISIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Nuestra misión es democratizar, profesionalizar y simplificar la experiencia náutica y deportiva en la Argentina. Conectamos en tiempo real a pescadores exigentes con capitanes y guías profesionales calificados, garantizando transacciones seguras, transparencia geográfica, y equipamiento de primer nivel a través de nuestra tienda oficial. Existimos para que los guías vivan con orgullo y prosperidad de su vocación, y para que cada salida al agua sea una aventura inolvidable libre de preocupaciones.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'NUESTRA VISIÓN',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Miramos el horizonte y vemos a CapitanYA como la plataforma náutica y de turismo aventura líder de América Latina. Nos dirigimos hacia un futuro donde la tecnología de geolocalización, la inteligencia artificial en predicciones de pesca y la sustentabilidad ecológica converjan en una sola aplicación. Queremos ser el guardián de la seguridad en el agua, el motor que impulse las economías regionales costeras y el punto de encuentro definitivo de la gran comunidad de amantes de la naturaleza.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Sebastián',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Fundador & CEO',
                          style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Image.asset(
                          'assets/images/firma_digital.png',
                          height: 38,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Co-Fundador Digital',
                          style: TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('¡A NAVEGAR!', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarTrabajaConNosotros(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nombreController = TextEditingController();
    final emailController = TextEditingController();
    final telefonoController = TextEditingController();
    String areaSeleccionada = 'Promotor de Ventas';
    XFile? cvFile;
    Uint8List? cvBytes;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AlertDialog(
            backgroundColor: const Color(0xFF001A33).withOpacity(0.95),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.4), width: 1.5),
            ),
            title: Row(
              children: const [
                Icon(Icons.work_outline, color: Color(0xFF00E676)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FORMÁ PARTE DE LA FLOTA',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        '“El Futuro de la Navegación te espera”',
                        style: TextStyle(
                          color: Color(0xFF00E676),
                          fontStyle: FontStyle.italic,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'En Capitán-YA, no solo conectamos lanchas con pescadores; estamos construyendo la comunidad náutica más grande y confiable de Argentina. Desde los esteros del Norte hasta los lagos más profundos de la Patagonia, nuestra misión es que cada salida al agua sea una experiencia de primer nivel.\n\n'
                      'Buscamos personas apasionadas, con espíritu emprendedor y respeto por la naturaleza. Si sos guía, experto en logística, promotor con ganas de crecer o simplemente alguien que ama el río tanto como nosotros, este es tu lugar.\n\n'
                      'Queremos conocerte. Dejanos tu currículum y contanos por qué querés ser parte de la revolución de la navegación argentina. El próximo gran viaje lo iniciamos juntos.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    
                    // Campos de texto
                    _buildDialogTextField(nombreController, 'Nombre Completo', Icons.person),
                    const SizedBox(height: 12),
                    _buildDialogTextField(emailController, 'Email de Contacto', Icons.email, isEmail: true),
                    const SizedBox(height: 12),
                    _buildDialogTextField(telefonoController, 'Teléfono / WhatsApp', Icons.phone, isPhone: true),
                    const SizedBox(height: 16),

                    // Selector de área
                    const Text(
                      'Área de Interés:',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButton<String>(
                        value: areaSeleccionada,
                        dropdownColor: const Color(0xFF001A33),
                        underline: const SizedBox(),
                        isExpanded: true,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'Promotor de Ventas', child: Text('PROMOTOR DE VENTAS')),
                          DropdownMenuItem(value: 'Guía / Capitán', child: Text('GUÍA / CAPITÁN')),
                          DropdownMenuItem(value: 'Logística y Operaciones', child: Text('LOGÍSTICA Y OPERACIONES')),
                          DropdownMenuItem(value: 'Administración y Finanzas', child: Text('ADMINISTRACIÓN')),
                          DropdownMenuItem(value: 'Desarrollador / Diseñador', child: Text('TECNOLOGÍA Y DISEÑO')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              areaSeleccionada = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Selector de archivo de CV
                    const Text(
                      'Subí tu Currículum Vitae (Foto o PDF):',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final picker = ImagePicker();
                        final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
                        if (file != null) {
                          final bytes = await file.readAsBytes();
                          setDialogState(() {
                            cvFile = file;
                            cvBytes = bytes;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                        decoration: BoxDecoration(
                          color: cvFile == null ? Colors.white.withOpacity(0.05) : const Color(0xFF00E676).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: cvFile == null ? Colors.white24 : const Color(0xFF00E676),
                            width: cvFile == null ? 1 : 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              cvFile == null ? Icons.upload_file_rounded : Icons.check_circle_rounded,
                              color: cvFile == null ? Colors.white70 : const Color(0xFF00E676),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                cvFile == null ? 'SELECCIONAR ARCHIVO CV' : 'CV SELECCIONADO CON ÉXITO',
                                style: TextStyle(
                                  color: cvFile == null ? Colors.white70 : const Color(0xFF00E676),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('CANCELAR', style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: (isUploading) ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  if (cvFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Por favor, selecciona tu archivo de Currículum (CV)'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                    return;
                  }

                  setDialogState(() {
                    isUploading = true;
                  });

                  try {
                    final supabase = SupabaseService.supabase;
                    String? cvUrl;
                    
                    final fileExt = cvFile!.path.split('.').last;
                    final fileName = 'cv_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
                    final path = 'curriculums/$fileName';
                    
                    try {
                      await supabase.storage.from('branding').uploadBinary(path, cvBytes!);
                      cvUrl = supabase.storage.from('branding').getPublicUrl(path);
                    } catch (storageErr) {
                      debugPrint('Error de storage subiendo CV: $storageErr');
                      cvUrl = 'https://fakecv.pdf/mock_$fileName';
                    }

                    try {
                      await supabase.from('postulaciones').insert({
                        'nombre': nombreController.text.trim(),
                        'email': emailController.text.trim(),
                        'telefono': telefonoController.text.trim(),
                        'area': areaSeleccionada,
                        'cv_url': cvUrl,
                        'created_at': DateTime.now().toIso8601String(),
                      });
                    } catch (dbErr) {
                      debugPrint('Error al guardar en tabla postulaciones remota: $dbErr');
                    }

                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Text('¡Postulación enviada! Pronto nos contactaremos.', style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          backgroundColor: Color(0xFF00E676),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    setDialogState(() {
                      isUploading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al enviar postulación: $e'), backgroundColor: Colors.redAccent),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black87)),
                      )
                    : const Text('POSTULARME', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, {
    bool isEmail = false, 
    bool isPhone = false,
  }) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: (val) {
        if (val == null || val.trim().isEmpty) return 'Este campo es obligatorio';
        if (isEmail && !val.contains('@')) return 'Email inválido';
        if (isPhone && val.length < 6) return 'Teléfono inválido';
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white60, size: 18),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white24)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF00E676))),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  void _mostrarSeguridadPrivacidad(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001A33).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.4), width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.shield_outlined, color: Color(0xFF00E676)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'SEGURIDAD Y PRIVACIDAD',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Center(
                  child: Text(
                    '“En CapitánYA, protegemos los datos de la comunidad de pescadores y capitanes con la misma firmeza con la que navegamos el río”',
                    style: TextStyle(
                      color: Color(0xFF00E676),
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Esta política detalla cómo cuidamos tu información en nuestra web y plataforma de control:',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.4),
                ),
                const SizedBox(height: 16),
                _buildPolicySection(
                  'Protección en la Tienda:',
                  'Los datos que ingresás para tus compras (nombre, teléfono y dirección de entrega) se utilizan únicamente para procesar el pedido y coordinar el despacho de tus equipos de camping o pesca.',
                ),
                const SizedBox(height: 12),
                _buildPolicySection(
                  'Pagos Blindados:',
                  'CapitánYA no almacena, no ve, ni tiene acceso a tus datos de tarjetas de crédito o cuentas bancarias. Todo el flujo de dinero, señas y cobros se gestiona mediante la plataforma segura y encriptada de Mercado Pago.',
                ),
                const SizedBox(height: 12),
                _buildPolicySection(
                  'Datos del Centro de Control:',
                  'Los datos de perfiles de capitanes, documentación y estados de viajes se procesan bajo estrictos estándares de seguridad y solo son accesibles por el personal autorizado del Centro Administrativo.',
                ),
                const SizedBox(height: 12),
                _buildPolicySection(
                  'Uso de Cookies y Conexión:',
                  'Utilizamos cookies técnicas esenciales para mantener tu sesión abierta en el panel de control y garantizar que tu navegación por la tienda sea rápida y segura. No vendemos tus datos a empresas de publicidad externas.',
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolicySection(String title, String body) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          body,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12, height: 1.4),
        ),
      ],
    );
  }

  void _mostrarTerminosCondiciones(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AlertDialog(
          backgroundColor: const Color(0xFF001A33).withOpacity(0.95),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: const Color(0xFF00E676).withOpacity(0.4), width: 1.5),
          ),
          title: Row(
            children: const [
              Icon(Icons.description_outlined, color: Color(0xFF00E676)),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'TÉRMINOS Y CONDICIONES DE USO',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Container(
            width: 600,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Center(
                    child: Text(
                      'TÉRMINOS Y CONDICIONES DE USO — CAPITÁN-YA',
                      style: TextStyle(
                        color: Color(0xFF00E676),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Última actualización: 26 de Mayo de 2026',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.5),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bienvenido/a a Capitán-YA, plataforma digital destinada a conectar pescadores con servicios de excursiones de pesca, navegación, experiencias recreativas relacionadas, contenidos informativos, herramientas digitales y productos vinculados a la pesca, camping y actividades al aire libre.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Al registrarse, navegar o utilizar la aplicación, el usuario acepta íntegramente los presentes Términos y Condiciones.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12, fontWeight: FontWeight.bold, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  
                  _buildTermSection(
                    '1. ACEPTACIÓN DE LOS TÉRMINOS',
                    'El acceso y utilización de la aplicación implica la aceptación plena de estos Términos y Condiciones, la Política de Privacidad y toda normativa complementaria publicada dentro de la plataforma.\n\nSi el usuario no estuviera de acuerdo con cualquiera de estas disposiciones, deberá abstenerse de utilizar la aplicación.',
                  ),
                  _buildTermSection(
                    '2. OBJETO DE LA PLATAFORMA',
                    'Capitán-YA funciona como una plataforma tecnológica destinada a:\n'
                    '• Gestionar solicitudes de salidas de pesca.\n'
                    '• Facilitar cotizaciones entre pescadores y capitanes/guías.\n'
                    '• Administrar reservas y pagos.\n'
                    '• Brindar herramientas de navegación y asistencia digital.\n'
                    '• Comercializar productos relacionados con pesca, camping, outdoor y actividades recreativas.\n\n'
                    'La plataforma actúa como intermediaria tecnológica y organizativa, pudiendo intervenir directa o indirectamente en determinadas operaciones comerciales.',
                  ),
                  _buildTermSection(
                    '3. REGISTRO DE USUARIO',
                    'Para acceder a determinadas funcionalidades, el usuario deberá registrarse proporcionando información veraz, actualizada y completa.\n\n'
                    'El usuario es responsable de:\n'
                    '• Mantener la confinencialidad de sus credenciales.\n'
                    '• Toda actividad realizada desde su cuenta.\n'
                    '• Verificar la exactitud de sus datos personales y de entrega.\n\n'
                    'Capitán-YA podrá suspender cuentas que presenten uso fraudulento, información falsa o conductas abusivas.',
                  ),
                  _buildTermSection(
                    '4. SALIDAS DE PESCA Y RESPONSABILIDADES',
                    'Las salidas de pesca son coordinadas entre el usuario y el capitán o prestador correspondiente.\n\n'
                    'Capitán-YA realiza esfuerzos razonables para verificar información, pero no garantiza:\n'
                    '• Condiciones climáticas favorables;\n'
                    '• Capturas de peces;\n'
                    '• Navegabilidad;\n'
                    '• Disponibilidad absoluta del servicio;\n'
                    '• Cambios de último momento por causas ajenas.\n\n'
                    'Los horarios, puntos de encuentro, equipamiento, servicios incluidos y cancelaciones dependerán de cada excursión y/o capitán.\n\n'
                    'Por razones climáticas, de seguridad, veda, crecida, bajante, mantenimiento de embarcaciones u otros factores externos, una salida podrá ser reprogramada o cancelada.',
                  ),
                  _buildTermSection(
                    '5. TIENDA ONLINE — PRODUCTOS DE PESCA Y CAMPING',
                    'La aplicación podrá ofrecer productos vinculados a:\n'
                    '• Pesca deportiva;\n'
                    '• Camping;\n'
                    '• Outdoor;\n'
                    '• Navegación;\n'
                    '• Accesorios recreativos.\n\n'
                    'Las imágenes publicadas son ilustrativas y pueden existir diferencias menores con el producto recibido sin que ello constituya incumplimiento.\n\n'
                    'La disponibilidad de stock está sujeta a confirmación.\n\n'
                    'Los precios pueden modificarse sin previo aviso hasta el momento de la confirmación efectiva de la compra.',
                  ),
                  _buildTermSection(
                    '6. CONDICIONES DE ENTREGA DE PRODUCTOS (CLÁUSULA LOGÍSTICA IMPORTANTE)',
                    'Los productos adquiridos dentro de la tienda online NO serán entregados en el lugar de embarque, muelle, puerto, bajada náutica, pesquero, camping o punto de encuentro de las salidas de pesca, salvo que exista una promoción o condición especial expresamente informada por escrito dentro de la aplicación.\n\n'
                    'Toda entrega de productos físicos se realizará exclusivamente mediante operadores logísticos, correos o servicios tradicionales de transporte de paquetería, conforme las modalidades, tiempos, coberturas, limitaciones y términos establecidos por dichas empresas transportistas.\n\n'
                    'El usuario acepta expresamente que:\n'
                    'a) Los plazos de entrega son estimativos y pueden variar según la empresa logística.\n'
                    'b) Capitán-YA no garantiza entregas inmediatas ni sincronizadas con excursiones contratadas.\n'
                    'c) Las demoras, reprogramaciones, pérdidas parciales, contingencias climáticas, conflictos gremiales, restricciones regionales o incidencias operativas propias del transporte quedan sujetas a las condiciones del operador logístico interviniente.\n'
                    'd) El usuario deberá ingresar correctamente el domicilio de entrega, siendo responsable por errores en la dirección proporcionada.\n'
                    'e) La contratación de una salida de pesca y la compra de productos en la tienda constituyen operaciones independientes.\n\n'
                    'En consecuencia, la compra de artículos de pesca o camping no implica ni genera obligación de entrega presencial durante la excursión contratada.',
                  ),
                  _buildTermSection(
                    '7. DEVOLUCIONES Y GARANTÍAS',
                    'Las devoluciones se regirán conforme la normativa de defensa del consumidor vigente en la República Argentina.\n\n'
                    'No podrán devolverse productos:\n'
                    '• Usados;\n'
                    '• Dañados por mal uso;\n'
                    '• Alterados;\n'
                    '• Sin embalaje original cuando ello impida su comercialización.\n\n'
                    'El usuario deberá informar cualquier inconveniente dentro de las 48 horas de recibido el pedido, acompañando evidencia fotográfica cuando corresponda.',
                  ),
                  _buildTermSection(
                    '8. PAGOS',
                    'Los pagos podrán procesarse mediante pasarelas externas como Mercado Pago u otros proveedores autorizados.\n\n'
                    'Capitán-YA no almacena información completa de tarjetas bancarias.\n\n'
                    'Toda operación queda sujeta a validaciones antifraude y autorizaciones del medio de pago correspondiente.',
                  ),
                  _buildTermSection(
                    '9. LIMITACIÓN DE RESPONSABILIDAD',
                    'Capitán-YA no será responsable por:\n'
                    '• Interrupciones temporales del servicio;\n'
                    '• Fallas de conectividad;\n'
                    '• Decisiones de terceros prestadores;\n'
                    '• Incumplimientos de empresas logísticas;\n'
                    '• Condiciones climáticas;\n'
                    '• Daños indirectos o lucro cesante.\n\n'
                    'La responsabilidad máxima de la plataforma, cuando legalmente corresponda, estará limitada al monto efectivamente abonado por el usuario en la operación específica objeto del reclamo.',
                  ),
                  _buildTermSection(
                    '10. CONDUCTA DEL USUARIO',
                    'El usuario se compromete a:\n'
                    '• Actuar de buena fe;\n'
                    '• Brindar información veraz;\n'
                    '• Respetar a capitanes, guías y demás usuarios;\n'
                    '• No utilizar la app para fines ilegales o fraudulentos.\n\n'
                    'La plataforma podrá suspender o cancelar cuentas ante conductas abusivas.',
                  ),
                  _buildTermSection(
                    '11. MODIFICACIONES',
                    'Capitán-YA podrá modificar estos términos cuando resulte necesario por cuestiones operativas, legales o comerciales.\n\n'
                    'Las nuevas versiones entrarán en vigencia desde su publicación dentro de la aplicación.',
                  ),
                  _buildTermSection(
                    '12. JURISDICCIÓN Y LEY APLICABLE',
                    'Los presentes términos se regirán por las leyes de la República Argentina.\n\n'
                    'Ante cualquier conflicto, las partes se someterán a la jurisdicción de los tribunales ordinarios competentes del domicilio legal de la empresa, salvo disposición legal imperativa en contrario.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676),
                foregroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ENTENDIDO', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTermSection(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.8),
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstitutionalFooter() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      color: const Color(0xFF1A1A1A),
      child: Column(
        children: [
          const Icon(Icons.anchor, color: Colors.white, size: 40),
          const SizedBox(height: 16),
          const Text(
            'CAPITAN-YA',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(
            'La tienda oficial de los pescadores argentinos.',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          const Divider(color: Colors.white24),
          const SizedBox(height: 32),
          _buildFooterLink(
            'Quiénes Somos', 
            Icons.info_outline, 
            onTap: () => _mostrarQuienesSomos(context),
          ),
          _buildFooterLink(
            'Trabajá con Nosotros', 
            Icons.work_outline, 
            onTap: () => _mostrarTrabajaConNosotros(context),
          ),
          _buildFooterLink(
            'Seguridad y Privacidad', 
            Icons.security,
            onTap: () => _mostrarSeguridadPrivacidad(context),
          ),
          _buildFooterLink(
            'Centro de Ayuda', 
            Icons.help_outline,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HelpCenterScreen()),
              );
            },
          ),
          _buildFooterLink(
            'Términos y Condiciones', 
            Icons.description_outlined,
            onTap: () => _mostrarTerminosCondiciones(context),
          ),
          const SizedBox(height: 40),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                '© 2026 CapitanYA. Todos los derechos reservados.',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
              ),
              Text(
                '•',
                style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10),
              ),
              InkWell(
                onTap: () => _mostrarSeguridadPrivacidad(context),
                child: Text(
                  'Seguridad y Privacidad',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5), 
                    fontSize: 10, 
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooterLink(String text, IconData icon, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: Colors.white70, size: 20),
            const SizedBox(width: 16),
            Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCarousel(bool isMobile, List<dynamic> heroBanners) {
    // Si no hay banners, mostramos uno premium por defecto para que no quede vacio
    final List<dynamic> displayBanners = heroBanners.isEmpty 
      ? [
          {
            'titulo': 'TU AVENTURA COMIENZA AQUÍ',
            'subtitulo': 'Equipamiento náutico de alta gama para capitanes exigentes.',
            'imagen_url': 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?q=80&w=2070&auto=format&fit=crop',
            'color': const Color(0xFF0D47A1),
          }
        ] 
      : heroBanners;

    return Stack(
      children: [
        SizedBox(
          height: isMobile ? 220 : 500, // Altura full desktop
          width: double.infinity,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (int page) {
              setState(() {
                _currentPage = page;
              });
            },
            itemCount: 10000, // Número virtualmente infinito
            itemBuilder: (context, index) {
              final bannerIndex = index % displayBanners.length;
              final banner = displayBanners[bannerIndex];
              final String titulo = banner is BannerPromo ? banner.titulo : banner['titulo'];
              final String subtitulo = banner is BannerPromo ? banner.subtitulo : banner['subtitulo'];
              final String imagenUrl = banner is BannerPromo ? banner.imagenUrl : (banner['imagen_url'] ?? '');
              
              // Color dinámico
              Color textColor = Colors.white;
              if (banner is BannerPromo) {
                final hex = banner.textColor.replaceAll('#', '');
                textColor = Color(int.parse('FF$hex', radix: 16));
              } else if (banner is Map && banner.containsKey('color')) {
                 textColor = banner['color'] == Colors.white ? Colors.white : banner['color'];
              }
              
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                  }
                  return Center(
                    child: SizedBox(
                      height: isMobile ? Curves.easeOutCubic.transform(value) * 220 : 500,
                      width: isMobile ? Curves.easeOutCubic.transform(value) * MediaQuery.of(context).size.width : MediaQuery.of(context).size.width,
                      child: child,
                    ),
                  );
                },
                child: GestureDetector(
                  onTap: () async {
                    if (banner is BannerPromo) {
                      if (banner.productId != null) {
                        try {
                          final prods = await SupabaseService.getProductos();
                          final targetProd = prods.firstWhere((p) => p.id == banner.productId);
                          if (mounted) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(producto: targetProd)));
                          }
                        } catch (e) {
                          debugPrint('Error navigando a producto: $e');
                        }
                      } else if (banner.categoriaId != null) {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ProductCatalogScreen(initialCategoryId: banner.categoriaId)));
                      }
                    }
                  },
                  child: Container(
                    margin: isMobile ? const EdgeInsets.symmetric(horizontal: 0, vertical: 0) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.zero,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Image.network(
                               imagenUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [Color(0xFF001F3F), Color(0xFF0D47A1)]),
                                  ),
                                  child: const Center(child: CircularProgressIndicator(color: Colors.white24)),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: const Color(0xFF0D47A1),
                                child: const Icon(Icons.sailing, color: Colors.white24, size: 50),
                              ),
                            ),
                          ),
                          // Overlay de gradiente mas oscuro para el texto
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    Colors.black.withOpacity(0.85),
                                    Colors.black.withOpacity(0.2),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: isMobile ? 25 : 120,
                            left: isMobile ? 25 : MediaQuery.of(context).size.width * 0.1,
                            right: isMobile ? 80 : MediaQuery.of(context).size.width * 0.4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isMobile ? const Color(0xFFFFD700) : Colors.transparent,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isMobile ? 'OFERTA DESTACADA' : 'NUEVA TEMPORADA',
                                    style: TextStyle(
                                      color: isMobile ? const Color(0xFF001F3F) : Colors.white70, 
                                      fontSize: isMobile ? 9 : 14, 
                                      fontWeight: FontWeight.w900, 
                                      letterSpacing: 2
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  titulo,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: isMobile ? 22 : 48,
                                    fontWeight: FontWeight.w900,
                                    height: 1.1,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  subtitulo,
                                  style: TextStyle(
                                    color: textColor.withOpacity(0.9),
                                    fontSize: isMobile ? 13 : 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: () {}, // Accion segun banner
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: isMobile ? Colors.white : const Color(0xFFB2EBF2),
                                    foregroundColor: isMobile ? const Color(0xFF0D47A1) : const Color(0xFF004D40),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 32, vertical: isMobile ? 8 : 16),
                                    elevation: 0,
                                  ),
                                  child: Text(isMobile ? 'VER MÁS' : 'Explorar Tienda', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isMobile ? 11 : 16)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Puntos indicadores (Dots) Infinitos
        Positioned(
          bottom: 25,
          right: 35,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(displayBanners.length, (index) {
              final isSelected = (_currentPage % displayBanners.length) == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: isSelected ? 24 : 8,
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.white.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildCartIndicator() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/carrito'),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFE3F2FD), // Fondo celeste pastel del mock-up
              shape: BoxShape.circle,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart_rounded, color: Color(0xFF0D47A1), size: 24),
                if (cart.totalItems > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFF00E676),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${cart.totalItems}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMaintenanceScreen(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001A33),
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF00E676).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -150,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.15),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    padding: const EdgeInsets.all(40),
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E676).withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF00E676).withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.anchor_rounded,
                            color: Color(0xFF00E676),
                            size: 64,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'MANTENIMIENTO EN CURSO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Estamos ajustando las redes y preparando el equipo para traerte la mejor experiencia de compra náutica.',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 14,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            5,
                            (index) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: const Color(0xFF00E676).withOpacity((index + 1) * 0.2),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: const Text(
                              'VOLVER AL PANEL',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.08),
                              foregroundColor: Colors.white,
                              side: BorderSide(color: Colors.white.withOpacity(0.15)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MarqueeWidget extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity;
  final String? imageUrl;

  const MarqueeWidget({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 50.0,
    this.imageUrl,
  });

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _contentWidth = 0.0;
  bool _initialized = false;
  final GlobalKey _contentKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateWidth();
    });
  }

  void _calculateWidth() {
    if (!mounted) return;
    final RenderBox? renderBox = _contentKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      _contentWidth = renderBox.size.width;
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _startAnimation();
      }
    } else {
      Future.delayed(const Duration(milliseconds: 50), _calculateWidth);
    }
  }

  void _startAnimation() {
    if (!mounted) return;
    
    final screenWidth = MediaQuery.of(context).size.width;
    final distance = screenWidth + _contentWidth;
    
    final safeVelocity = widget.velocity > 0 ? widget.velocity : 50.0;
    final durationSeconds = distance / safeVelocity;
    
    _controller.duration = Duration(milliseconds: (durationSeconds * 1000).toInt());
    
    _controller.forward(from: 0.0).whenComplete(() {
      if (mounted) {
        _startAnimation(); // Loop
      }
    });
  }

  @override
  void didUpdateWidget(MarqueeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.velocity != widget.velocity || oldWidget.imageUrl != widget.imageUrl) {
      setState(() => _initialized = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateWidth();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildContent() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              widget.imageUrl!,
              height: 20,
              width: 30, // Proporción aproximada de tarjeta
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          widget.text, 
          style: widget.style, 
          maxLines: 1, 
          overflow: TextOverflow.visible,
          softWrap: false,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) {
      // Oculto, pero en el árbol para calcular su tamaño
      return Stack(
        children: [
          Opacity(
            opacity: 0,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Container(
                key: _contentKey,
                child: _buildContent(),
              ),
            ),
          ),
        ],
      );
    }
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth > 0 ? constraints.maxWidth : MediaQuery.of(context).size.width;
        return ClipRect(
          child: SizedBox(
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final translateX = screenWidth - (_controller.value * (screenWidth + _contentWidth));
                return Transform.translate(
                  offset: Offset(translateX, 0),
                  child: child,
                );
              },
              child: Align(
                alignment: Alignment.centerLeft,
                child: OverflowBox(
                  minWidth: 0,
                  maxWidth: double.infinity,
                  minHeight: 0,
                  maxHeight: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: _buildContent(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonLoader extends StatelessWidget {
  const _SkeletonLoader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(3, (index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 150,
              height: 20,
              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 3,
                itemBuilder: (context, i) => Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        )),
      ),
    );
  }
}
