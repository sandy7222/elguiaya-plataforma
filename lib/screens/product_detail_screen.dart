import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';
import '../models/producto.dart';
import '../models/producto_variante.dart';
import '../models/user_profile.dart';
import '../models/producto_atributo.dart';
import '../models/categoria.dart';
import '../providers/cart_provider.dart';
import '../services/supabase_service.dart';
import '../widgets/ficha_tecnica_widget.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/favoritos_provider.dart';
import '../services/el_guia_engine.dart';
import '../services/guia_copilot_brain.dart';

class ProductDetailScreen extends StatefulWidget {
  final Producto producto;

  const ProductDetailScreen({
    super.key,
    required this.producto,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  UserProfile? _vendedor;
  Categoria? _categoria;
  bool _isLoadingVendedor = true;
  bool _isFavorite = false;
  late PageController _galleryController;
  int _currentGalleryIndex = 0;
  late Stream<List<Map<String, dynamic>>> _productStream;
  late Producto _producto;
  ProductoVariante? _varianteSeleccionada;

  // Colores Pro 2026 (Modern Clean Style)
  static const Color _capitanBlue = Color(0xFF001F3F); // Azul más profundo para contraste
  static const Color _vibrantGreen = Color(0xFF00E676);
  static const Color _softGrey = Color(0xFFF4F7F6);
  static const Color _darkGrey = Color(0xFF1A1A1A);

  List<Producto> _relatedProducts = [];
  bool _isLoadingRelated = true;

  @override
  void initState() {
    super.initState();
    _producto = widget.producto;
    _varianteSeleccionada = _producto.varianteDefault;
    _galleryController = PageController();
    _productStream = SupabaseService.supabase
        .from('productos')
        .stream(primaryKey: ['id'])
        .eq('id', widget.producto.id);
    _cargarDatosAdicionales();
    _cargarVariantesSiFaltan();
    
    // Registrar contexto activo para Gu-IA
    ElGuiaEngine().contexto.productoActual = widget.producto;
    GuiaCopilotBrain.instance.pantallaCargada(ScreenContext.tienda);
  }

  Future<void> _cargarVariantesSiFaltan() async {
    try {
      // FK explícita: evita que falle el embed y se pierda el tipo (Color vs Variante)
      final row = await SupabaseService.supabase
          .from('productos')
          .select(
            '*, producto_variantes(*), opciones_variante!variante_opcion_id(nombre)',
          )
          .eq('id', widget.producto.id)
          .maybeSingle();

      Map<String, dynamic>? data = row == null
          ? null
          : Map<String, dynamic>.from(row);

      // Fallback si el embed de opción no vino
      if (data != null &&
          data['variante_opcion_id'] != null &&
          data['opciones_variante'] == null) {
        final op = await SupabaseService.supabase
            .from('opciones_variante')
            .select('nombre')
            .eq('id', data['variante_opcion_id'])
            .maybeSingle();
        if (op != null) {
          data['variante_tipo_nombre'] = op['nombre']?.toString();
        }
      }

      if (!mounted) return;
      if (data == null) {
        await _cargarSoloVariantes();
        return;
      }

      final fresh = Producto.fromSupabase(data);
      setState(() {
        _producto = fresh;
        // Preferir default con stock; si todas en 0, igual mostrar la default para ver foto
        _varianteSeleccionada = fresh.varianteDefault ??
            (fresh.variantesActivas.isNotEmpty
                ? fresh.variantesActivas.first
                : null);
        _currentGalleryIndex = 0;
      });
    } catch (e) {
      debugPrint('Error al refrescar producto/variantes: $e');
      await _cargarSoloVariantes();
    }
  }

  Future<void> _cargarSoloVariantes() async {
    final vars = await SupabaseService.getVariantesProducto(_producto.id);
    if (!mounted || vars.isEmpty) return;
    setState(() {
      _producto = _producto.copyWith(variantes: vars);
      _varianteSeleccionada = _producto.varianteDefault;
    });
  }

  Future<void> _cargarDatosAdicionales() async {
    _cargarDatosVendedor();
    _cargarCategoria();
    _cargarRelacionados();
  }

  Future<void> _cargarRelacionados() async {
    try {
      final related = await SupabaseService.getProductosPorCategoria(widget.producto.categoriaId);
      if (mounted) {
        setState(() {
          _relatedProducts = related.where((p) => p.id != widget.producto.id).toList();
          _isLoadingRelated = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar relacionados: $e');
      if (mounted) setState(() => _isLoadingRelated = false);
    }
  }

  Future<void> _cargarCategoria() async {
    try {
      final cat = await SupabaseService.getCategoriaById(widget.producto.categoriaId);
      if (mounted) setState(() => _categoria = cat);
    } catch (e) {
      debugPrint('Error al cargar categoria: $e');
    }
  }



  @override
  void dispose() {
    // Limpiar contexto activo de Gu-IA si corresponde
    if (ElGuiaEngine().contexto.productoActual?.id == widget.producto.id) {
      ElGuiaEngine().contexto.productoActual = null;
    }
    _galleryController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosVendedor() async {
    try {
      if (widget.producto.vendedorId != null) {
        final profile = await SupabaseService.getProfile(widget.producto.vendedorId!);
        if (mounted) {
          setState(() {
            _vendedor = profile;
            _isLoadingVendedor = false;
          });
        }
      } else {
        setState(() => _isLoadingVendedor = false);
      }
    } catch (e) {
      debugPrint('Error al cargar datos del vendedor: $e');
      if (mounted) setState(() => _isLoadingVendedor = false);
    }
  }

  Future<void> _contactarVendedor() async {
    final telefono = _vendedor?.telefono ?? '5491100000000';
    final mensaje = '⚓ ¡Hola Capitán! Estoy interesado en el producto: ${widget.producto.nombre} que vi en la tienda.';
    final url = 'https://wa.me/$telefono?text=${Uri.encodeComponent(mensaje)}';
    
    try {
      if (widget.producto.vendedorId != null) {
        await SupabaseService.registrarSolicitudContacto(
          idCapitan: widget.producto.vendedorId!,
          idProducto: widget.producto.id,
          mensaje: mensaje,
        );
      }

      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final allImages = _imagenesActuales;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _darkGrey, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Consumer<FavoritosProvider>(
            builder: (context, favoritos, _) {
              final esFavorito = favoritos.esFavorito(widget.producto.id);
              return IconButton(
                icon: Icon(esFavorito ? Icons.favorite : Icons.favorite_border, color: esFavorito ? Colors.red : _darkGrey),
                onPressed: () {
                  if (SupabaseService.supabase.auth.currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes iniciar sesión para guardar favoritos')));
                    return;
                  }
                  favoritos.toggleFavorito(widget.producto);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: _darkGrey),
            onPressed: _compartirProducto,
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Galería principal — tocá para zoom
            Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height * 0.48,
                  width: double.infinity,
                  color: _softGrey,
                  child: allImages.isEmpty
                      ? const Center(child: Icon(Icons.image, size: 48, color: Colors.black26))
                      : PageView.builder(
                          controller: _galleryController,
                          itemCount: allImages.length,
                          onPageChanged: (index) =>
                              setState(() => _currentGalleryIndex = index),
                          itemBuilder: (context, index) {
                            return Hero(
                              tag: index == 0
                                  ? 'prod_${widget.producto.id}'
                                  : 'prod_${widget.producto.id}_$index',
                              child: GestureDetector(
                                onTap: () => _abrirZoomImagen(
                                  allImages,
                                  index,
                                ),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.zoomIn,
                                  child: SizedBox.expand(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: _softGrey,
                                        image: DecorationImage(
                                          image: NetworkImage(allImages[index]),
                                          fit: BoxFit.cover,
                                          alignment: Alignment.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                if (allImages.isNotEmpty)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: Material(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                      child: InkWell(
                        onTap: () => _abrirZoomImagen(
                          allImages,
                          _currentGalleryIndex,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Ampliar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            
            // Miniaturas (Gallery Strip)
            if (allImages.length > 1)
              Container(
                height: 80,
                margin: const EdgeInsets.symmetric(vertical: 16),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: allImages.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        _galleryController.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _currentGalleryIndex == index ? _capitanBlue : Colors.grey.shade200,
                            width: 2,
                          ),
                          image: DecorationImage(image: NetworkImage(allImages[index]), fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // 2. Información Principal
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildTechBadge(_producto.rubro.toUpperCase(), _capitanBlue),
                      if (_stockActual < 5 && _stockActual > 0)
                        _buildUrgencyPulse(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _producto.nombre,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _darkGrey, letterSpacing: -0.5),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '\$${_precioActual.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: _capitanBlue),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: _vibrantGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                        child: const Text('ENVÍO GRATIS', style: TextStyle(color: _vibrantGreen, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  if (_producto.tieneVariantes) ...[
                    const SizedBox(height: 20),
                    _buildSelectorColor(),
                  ],
                  const SizedBox(height: 24),
                  
                  // Botones de Acción Estilo Moderno
                  _buildModernActionButtons(),
                  
                  const SizedBox(height: 40),
                  const _SectionHeader(title: 'DESCRIPCIÓN'),
                  const SizedBox(height: 12),
                  Text(
                    _producto.descripcion,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.6),
                  ),
                  
                  const SizedBox(height: 32),
                  const _SectionHeader(title: 'ESPECIFICACIONES TÉCNICAS'),
                  const SizedBox(height: 16),
                  FutureBuilder<List<ProductoAtributo>>(
                    future: SupabaseService.getAtributosPorProducto(widget.producto.id),
                    builder: (context, attrSnapshot) {
                      return FichaTecnicaWidget(atributos: attrSnapshot.data ?? []);
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  _buildReviewSectionMock(),
                  
                  const SizedBox(height: 40),
                  _buildRelatedSection(),
                  
                  const SizedBox(height: 60),
                  _buildFooter(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> get _imagenesActuales {
    final result = <String>[];
    final seen = <String>{};

    void add(String? url) {
      final u = url?.trim() ?? '';
      if (u.isEmpty || seen.contains(u)) return;
      seen.add(u);
      result.add(u);
    }

    // 1) Foto de la variante elegida (para ver qué se compra)
    final v = _varianteSeleccionada;
    if (v != null) {
      add(v.imagenUrl);
      for (final g in v.galeriaUrls) {
        add(g);
      }
    }

    // 2) Galería de la publicación (portada + decorativas) — siempre
    add(_producto.imagenUrl);
    for (final g in _producto.galeriaUrls) {
      add(g);
    }

    // 3) Fallback si aún no hay nada
    if (result.isEmpty) {
      for (final vari in _producto.variantesActivas) {
        add(vari.imagenUrl);
      }
    }
    return result;
  }

  int get _stockActual =>
      _varianteSeleccionada?.stock ?? _producto.stockDisponible;

  double get _precioActual =>
      _varianteSeleccionada?.precioEfectivo(_producto.precio) ?? _producto.precio;

  Widget _buildSelectorColor() {
    final variantes = _producto.variantesActivas;
    final tipo = _producto.etiquetaTipoVariante;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${tipo.toUpperCase()}: ${_varianteSeleccionada?.color ?? 'Elegí uno'}',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: _darkGrey,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: variantes.map((v) {
            final selected = _varianteSeleccionada?.id == v.id;
            final sinStock = v.stock <= 0;
            return GestureDetector(
              // Siempre se puede tocar para ver la foto; el stock solo bloquea la compra
              onTap: () {
                setState(() {
                  _varianteSeleccionada = v;
                  _currentGalleryIndex = 0;
                });
                // Ir a la foto de esa variante (queda primera en la galería)
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_galleryController.hasClients) {
                    _galleryController.jumpToPage(0);
                  }
                });
              },
              child: Opacity(
                opacity: sinStock ? 0.55 : 1,
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected ? _capitanBlue : Colors.grey.shade300,
                          width: selected ? 2.5 : 1,
                        ),
                        color: Colors.grey.shade100,
                        image: (v.imagenUrl != null && v.imagenUrl!.isNotEmpty)
                            ? DecorationImage(
                                image: NetworkImage(v.imagenUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: (v.imagenUrl == null || v.imagenUrl!.isEmpty)
                          ? Center(
                              child: Text(
                                v.color.length > 8
                                    ? v.color.substring(0, 7)
                                    : v.color,
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            )
                          : (sinStock
                              ? Container(
                                  alignment: Alignment.bottomCenter,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.55),
                                      ],
                                    ),
                                  ),
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: const Text(
                                    'Agotado',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: 64,
                      child: Text(
                        v.color,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          color: selected ? _capitanBlue : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          _stockActual > 0
              ? 'Stock ($tipo): $_stockActual'
              : 'Sin stock en esta $tipo — podés mirar las fotos, pero no comprar',
          style: TextStyle(
            fontSize: 12,
            color: _stockActual > 0 ? Colors.grey.shade600 : Colors.redAccent,
          ),
        ),
      ],
    );
  }

  Widget _buildModernActionButtons() {
    final puedeComprar = _stockActual > 0 &&
        (!_producto.tieneVariantes || _varianteSeleccionada != null);
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: puedeComprar
            ? () => _agregarAlCarrito(Provider.of<CartProvider>(context, listen: false))
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _darkGrey,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: const Text('AÑADIR AL CARRITO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
      ),
    );
  }

  Widget _buildReviewSectionMock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'VALORACIONES DE PESCADORES'),
        const SizedBox(height: 20),
        Row(
          children: [
            Column(
              children: [
                const Text('4.8', style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: _darkGrey)),
                Row(
                  children: List.generate(5, (i) => Icon(Icons.star, color: Colors.orange, size: 16)),
                ),
                const SizedBox(height: 4),
                Text('128 reseñas', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
            const SizedBox(width: 40),
            Expanded(
              child: Column(
                children: [5, 4, 3, 2, 1].map((star) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Text('$star', style: const TextStyle(fontSize: 12)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: star == 5 ? 0.8 : (star == 4 ? 0.15 : 0.05),
                              backgroundColor: Colors.grey.shade100,
                              valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRelatedSection() {
    if (_isLoadingRelated) return const SizedBox();
    if (_relatedProducts.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'TAMBIÉN PODRÍA INTERESARTE'),
        const SizedBox(height: 20),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedProducts.length,
            itemBuilder: (context, index) {
              final p = _relatedProducts[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailScreen(producto: p)));
                },
                child: Container(
                  width: 160,
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(p.imagenUrl, height: 160, width: 160, fit: BoxFit.cover),
                      ),
                      const SizedBox(height: 12),
                      Text(p.nombre, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 4),
                      Text(p.precioFormateado, style: const TextStyle(color: _capitanBlue, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _softGrey,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Text('EL GUIA YA', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _capitanBlue)),
          const SizedBox(height: 8),
          const Text('Tu aliado en el agua.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _socialIcon(FontAwesomeIcons.facebook),
              const SizedBox(width: 20),
              _socialIcon(FontAwesomeIcons.instagram),
              const SizedBox(width: 20),
              _socialIcon(FontAwesomeIcons.youtube),
            ],
          ),
          const SizedBox(height: 32),
          Text('© 2026 EL GUIA YA - Todos los derechos reservados.', style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        ],
      ),
    );
  }

  Widget _socialIcon(FaIconData icon) {
    return FaIcon(icon, color: Colors.grey.shade400, size: 20);
  }

  Widget _buildTechBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1),
      ),
    );
  }

  Widget _buildUrgencyPulse() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.bolt, color: Colors.orange, size: 14),
          SizedBox(width: 4),
          Text('¡QUEDAN POCOS!', style: TextStyle(color: Colors.orange, fontSize: 9, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }


  void _abrirZoomImagen(List<String> images, int initialIndex) {
    if (images.isEmpty) return;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
      builder: (ctx) => _ProductImageZoomDialog(
        images: images,
        initialIndex: initialIndex.clamp(0, images.length - 1),
      ),
    );
  }

  void _agregarAlCarrito(CartProvider cart) {
    if (_producto.tieneVariantes && _varianteSeleccionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elegí un color antes de agregar al carrito')),
      );
      return;
    }
    final success = cart.agregarAlCarrito(
      _producto,
      variante: _varianteSeleccionada,
    );
    if (success) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      
      final nombre = _varianteSeleccionada != null
          ? '${_producto.nombre} (${_varianteSeleccionada!.color})'
          : _producto.nombre;
      final controller = ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '¡$nombre añadido a tu red!',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
          ),
          backgroundColor: _vibrantGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 6,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'VER CARRITO',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.pushNamed(context, '/carrito');
            },
          ),
        ),
      );

      // 🕒 Solución al bug de congelamiento por hover en Flutter Web: Forzamos el cierre a los 3 segundos
      Future.delayed(const Duration(seconds: 3), () {
        try {
          controller.close();
        } catch (_) {}
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay stock suficiente para ese color')),
      );
    }
  }

  void _compartirProducto() {
    final String texto = '⚓ ¡Mira este equipo en EL GUIA YA!\n\n'
        '*${widget.producto.nombre}*\n'
        '💰 Precio: ${widget.producto.precioFormateado}\n\n'
        '📍 Ver más detalles en la app o en la web:\n'
        'https://elguiaya.com/producto?id=${widget.producto.id}';
    
    Share.share(texto, subject: 'Interés en ${widget.producto.nombre}');
  }
}

/// Zoom a pantalla completa: rueda del mouse / pellizco / arrastrar.
class _ProductImageZoomDialog extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _ProductImageZoomDialog({
    required this.images,
    required this.initialIndex,
  });

  @override
  State<_ProductImageZoomDialog> createState() => _ProductImageZoomDialogState();
}

class _ProductImageZoomDialogState extends State<_ProductImageZoomDialog> {
  late final PageController _pageController;
  late final TransformationController _transformController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _resetZoom();
            },
            itemBuilder: (context, i) {
              return InteractiveViewer(
                transformationController: i == _index ? _transformController : null,
                minScale: 1,
                maxScale: 5,
                panEnabled: true,
                scaleEnabled: true,
                child: Center(
                  child: Image.network(
                    widget.images[i],
                    fit: BoxFit.contain,
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.images.length}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _resetZoom,
                    tooltip: 'Restablecer zoom',
                    icon: const Icon(Icons.fit_screen, color: Colors.white, size: 22),
                    style: IconButton.styleFrom(backgroundColor: Colors.black45),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Text(
              'Rueda del mouse o pellizco para acercar · Arrastrá para mover',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14, 
        fontWeight: FontWeight.bold, 
        letterSpacing: 1.2, 
        color: Color(0xFF001F3F)
      ),
    );
  }
}
