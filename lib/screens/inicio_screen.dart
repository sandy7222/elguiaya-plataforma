
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';
import 'package:El Guia YA_master/services/branding_service.dart';
import 'package:El Guia YA_master/models/producto.dart';
import 'package:El Guia YA_master/models/categoria.dart';
import 'package:El Guia YA_master/models/banner_promo.dart';
import 'package:El Guia YA_master/providers/cart_provider.dart';
import 'package:El Guia YA_master/screens/product_detail_screen.dart';
import 'package:El Guia YA_master/screens/product_catalog_screen.dart';
import 'package:El Guia YA_master/widgets/cart_sheet.dart';
import 'package:El Guia YA_master/screens/blog_piques_screen.dart';

class InicioScreen extends StatefulWidget {
  const InicioScreen({super.key});

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PageController _heroPageController = PageController();
  List<Categoria> _categorias = [];
  List<BannerPromo> _allBanners = [];
  bool _isLoading = true;
  int _currentHeroPage = 0;
  Timer? _rotationTimer;
  int _rotationSeconds = 5;

  // Colores Premium 2026
  static const Color _primaryBlue = Color(0xFF0D47A1);
  static const Color _accentMint = Color(0xFF00E676);
  static const Color _darkBg = Color(0xFF0A0E12);
  static const Color _cardWhite = Colors.white;

  @override
  void initState() {
    super.initState();
    // Retrasar un poco la carga para que el primer render sea instantaneo
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _cargarDatos();
    });
  }

  @override
  void dispose() {
    _rotationTimer?.cancel();
    _heroPageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      List<Categoria> loadedCats = [];
      List<BannerPromo> loadedBanners = [];
      int loadedRotation = 5;

      // Cargar categorias
      try {
        final cats = await SupabaseService.getCategorias();
        loadedCats = cats.where((c) => c.parentId == null).toList();
      } catch (e) {
        print('❌ [INICIO] Error al cargar categorias: $e');
      }

      // Cargar banners
      try {
        loadedBanners = await SupabaseService.getAllBanners();
      } catch (e) {
        print('❌ [INICIO] Error al cargar banners: $e');
      }

      // Cargar configuracion de rotacion
      try {
        loadedRotation = await BrandingService.getBannerRotationSeconds();
      } catch (e) {
        print('⚠️ [INICIO] Error en rotacion: $e');
      }

      if (mounted) {
        setState(() {
          _categorias = loadedCats;
          _allBanners = loadedBanners;
          _rotationSeconds = loadedRotation;
          _isLoading = false;
        });
        _iniciarRotacionHero();
        print('✅ [INICIO] Estado actualizado con ${loadedBanners.length} banners.');
      }
    } catch (e) {
      print('❌ [INICIO] Error critico en _cargarDatos: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _iniciarRotacionHero() {
    _rotationTimer?.cancel();
    final heroBanners = _allBanners.where((b) => b.tipo == 'hero').toList();
    if (heroBanners.length <= 1) return;

    _rotationTimer = Timer.periodic(Duration(seconds: _rotationSeconds), (timer) {
      if (_heroPageController.hasClients) {
        _currentHeroPage = (_currentHeroPage + 1) % heroBanners.length;
        _heroPageController.animateToPage(
          _currentHeroPage,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Fondo más limpio y profesional
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildPremiumHeader(), // Logo y Carrito
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModernSearchBar(), // Buscador debajo del header
                    _buildCategorySelector(), // Categorías antes del Hero
                    _buildDynamicHeroSection(), // El gran banner
                    _buildDiscoveryFeed(), // Feed dinámico intercalado
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumHeader() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          const Icon(Icons.anchor, color: _primaryBlue, size: 28),
          const SizedBox(width: 8),
          Text(
            'EL GUIA YA',
            style: GoogleFonts.outfit(
              color: _primaryBlue,
              fontWeight: FontWeight.w900,
              fontSize: 22,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Consumer<CartProvider>(
            builder: (context, cart, _) => _buildIconButton(
              Icons.shopping_cart_outlined,
              iconColor: _primaryBlue,
              badgeCount: cart.totalItems,
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CartSheet(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: '¿Qué estás buscando hoy?',
            hintStyle: GoogleFonts.outfit(color: Colors.grey[500], fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: _primaryBlue, size: 22),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(IconData icon, {VoidCallback? onTap, int? badgeCount, Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor ?? Colors.white, size: 24),
          ),
          if (badgeCount != null && badgeCount > 0)
            Positioned(
              top: -5,
              right: -5,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: _accentMint, shape: BoxShape.circle),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDynamicHeroSection() {
    final heroBanners = _allBanners.where((b) => b.tipo == 'hero').toList();
    if (heroBanners.isEmpty) return _buildStaticHeroFallback();

    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: PageView.builder(
        controller: _heroPageController,
        itemCount: heroBanners.length,
        onPageChanged: (index) => setState(() => _currentHeroPage = index),
        itemBuilder: (context, index) => _buildHeroItem(heroBanners[index]),
      ),
    );
  }

  Widget _buildHeroItem(BannerPromo banner) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Image.network(
              banner.imagenUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.blueGrey),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    banner.titulo.toUpperCase(),
                    style: TextStyle(
                      color: Color(int.parse(banner.textColor.replaceAll('#', '0xFF'))),
                      fontWeight: FontWeight.w900,
                      fontSize: banner.tituloSize,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    banner.subtitulo,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: banner.subtituloSize,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticHeroFallback() {
    return Container(
      height: 190,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [_primaryBlue, _accentMint]),
      ),
      child: const Center(child: Text('EXPLORÁ LA TIENDA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 1.2, color: Colors.black54),
      ),
    );
  }

  Widget _buildCategorySelector() {
    if (_isLoading) return const SizedBox(height: 60);
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categorias.length,
        itemBuilder: (context, index) {
          final cat = _categorias[index];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: ActionChip(
              label: Text(cat.nombre.toUpperCase()),
              labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _primaryBlue),
              backgroundColor: Colors.white,
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductCatalogScreen(initialCategoryId: cat.id))),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryFeed() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    final middleBanners = _allBanners.where((b) => b.tipo == 'middle').toList();
    
    return Column(
      children: [
        // 1. Primer Carrusel: CARPAS (o similar)
        if (middleBanners.isNotEmpty)
          _buildCarouselSection(
            middleBanners.first.titulo.toUpperCase(), 
            middleBanners.first.categoriaId != null 
              ? SupabaseService.getProductosPorCategoria(middleBanners.first.categoriaId!)
              : SupabaseService.getNovedades(),
          ),

        // 2. Elemento de Ruptura: DESTACADOS DE LA TEMPORADA (Banner Ancho)
        _buildSeasonFeaturedBanner(),

        // 3. Segundo Carrusel: Pesca / Reeles (Diferente estilo)
        if (middleBanners.length > 1)
          _buildCarouselSection(
            middleBanners[1].titulo.toUpperCase(), 
            middleBanners[1].categoriaId != null 
              ? SupabaseService.getProductosPorCategoria(middleBanners[1].categoriaId!)
              : SupabaseService.getMasVendidos(),
            isAlternative: true,
          ),

        // 4. SECCIÓN SORPRESA: COMUNIDAD EL GUIA YA (Blog/Reviews)
        _buildCommunitySection(),

        // 5. Grid de Productos Sueltos (Para no repetir carruseles)
        _buildProductGridSection('EXPLORÁ MÁS PRODUCTOS'),
      ],
    );
  }

  Widget _buildSeasonFeaturedBanner() {
    return Container(
      width: double.infinity,
      height: 180,
      margin: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=2070'),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [Colors.black.withOpacity(0.6), Colors.transparent],
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'DESTACADOS DE LA TEMPORADA',
              style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
            Text(
              'Equipamiento pro para el invierno',
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildSectionHeader('BLOG DE PIQUES & COMUNIDAD')),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => BlogPiquesScreen(),
                    ),
                  );
                },
                child: const Text(
                  'Ver Todo',
                  style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: SupabaseService.obtenerReviewsPublicas(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 150,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                ),
              );
            }
            
            final reviews = snapshot.data ?? [];
            if (reviews.isEmpty) {
              return Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0F172A), const Color(0xFF020617).withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.phishing, color: Color(0xFF00E676), size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '¿Fuiste de pesca recientemente?',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Califica tu viaje y comparte tu gran captura en nuestro Blog público de piques.',
                            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            return SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: reviews.length,
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  final aspectos = review['aspectos_puntuados'] as Map<String, dynamic>? ?? {};
                  final especie = aspectos['especie_capturada'] as String? ?? 'Pesca';
                  final peso = aspectos['peso_captura'];
                  final fotos = aspectos['fotos_capturas'] as List? ?? [];
                  final comentario = review['comentario'] as String? ?? '';
                  final rating = (review['calificacion'] as num? ?? 5).toInt();

                  final String? fotoUrl = fotos.isNotEmpty ? fotos.first as String? : null;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BlogPiquesScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 15, bottom: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Stack(
                          children: [
                            if (fotoUrl != null)
                              Positioned.fill(
                                child: Image.network(
                                  fotoUrl,
                                  fit: BoxFit.cover,
                                ),
                              )
                            else
                              Positioned.fill(
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.phishing, color: Colors.white12, size: 50),
                                  ),
                                ),
                              ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.black.withOpacity(0.1), Colors.black.withOpacity(0.95)],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          especie,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (peso != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF00E676).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
                                          ),
                                          child: Text(
                                            '$peso kg',
                                            style: const TextStyle(
                                              color: Color(0xFF00E676),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: List.generate(5, (starIdx) {
                                      return Icon(
                                        Icons.anchor,
                                        size: 11,
                                        color: starIdx < rating
                                            ? const Color(0xFF00E676)
                                            : Colors.white24,
                                      );
                                    }),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    comentario.isNotEmpty ? comentario : '¡Gran pique de temporada!',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildProductGridSection(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(title),
        FutureBuilder<List<Producto>>(
          future: SupabaseService.getNovedades(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const SizedBox.shrink();
            final prods = snapshot.data!.take(4).toList();
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: prods.length,
                itemBuilder: (context, index) => _buildPremiumProductCard(prods[index]),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCarouselSection(String title, Future<List<Producto>> future, {bool isAlternative = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.w900,
                  fontSize: isAlternative ? 18 : 14,
                  letterSpacing: 0.5,
                  color: isAlternative ? Colors.black87 : _primaryBlue,
                ),
              ),
              Text(
                'VER TODO',
                style: GoogleFonts.outfit(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
        SizedBox(
          height: isAlternative ? 300 : 270,
          child: FutureBuilder<List<Producto>>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final prods = snapshot.data ?? [];
              if (prods.isEmpty) return const SizedBox.shrink();
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: prods.length,
                itemBuilder: (context, index) => _buildPremiumProductCard(prods[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPremiumProductCard(Producto p) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailScreen(producto: p))),
      child: Container(
        width: 170,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _cardWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: Image.network(
                    p.imagenUrl,
                    height: 150,
                    width: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(height: 150, width: 170, color: Colors.grey[200]),
                  ),
                ),
                Positioned(top: 10, right: 10, child: _buildStockBadge(p.stock)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _darkBg)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.precioFormateado, style: const TextStyle(color: _accentMint, fontWeight: FontWeight.w900, fontSize: 15)),
                      const Icon(Icons.add_circle_outline, color: _primaryBlue, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStockBadge(int stock) {
    final color = stock > 0 ? (stock < 5 ? Colors.orange : _accentMint) : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
      child: Text(stock > 0 ? (stock < 5 ? 'ÚLTIMOS' : 'STOCK') : 'AGOTADO', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}
