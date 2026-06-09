import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:El Guia YA_master/models/banner_promo.dart';
import 'package:El Guia YA_master/models/producto.dart';
import 'package:El Guia YA_master/models/categoria.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';
import 'package:El Guia YA_master/services/branding_service.dart';

class AdminBannersScreen extends StatefulWidget {
  const AdminBannersScreen({super.key});

  @override
  State<AdminBannersScreen> createState() => _AdminBannersScreenState();
}

class _AdminBannersScreenState extends State<AdminBannersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<BannerPromo> _allBanners = [];
  List<Producto> _productos = [];
  List<Categoria> _categorias = [];
  bool _isLoading = true;
  int _rotationSeconds = 5;
  Uint8List? _imageBytes;
  String? _selectedCategoryFilterId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final banners = await SupabaseService.getAllBanners();
      final prods = await SupabaseService.getProductos();
      final cats = await SupabaseService.getCategorias();
      final seconds = await BrandingService.getBannerRotationSeconds();
      
      if (mounted) {
        setState(() {
          _allBanners.clear();
          _allBanners.addAll(banners);
          _productos = prods;
          _categorias = cats;
          _rotationSeconds = seconds;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar datos iniciales: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateRotationConfig(int seconds) async {
    setState(() => _rotationSeconds = seconds);
    await BrandingService.actualizarConfiguracion(
      clave: 'banner_rotation_seconds',
      valor: seconds.toString(),
      tipoValor: 'numero',
      descripcion: 'Segundos de rotacion del carrusel de banners',
    );
  }

  List<BannerPromo> _getBannersByType(String type) {
    return _allBanners.where((b) => b.tipo == type).toList();
  }

  Future<void> _deleteBanner(String id) async {
    try {
      await SupabaseService.eliminarBanner(id);
      setState(() {
        _allBanners.removeWhere((b) => b.id == id);
      });
    } catch (e) {
      print('Error al eliminar banner: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('Publicaciones y Banners', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF001F3F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orangeAccent,
          indicatorWeight: 3,
          labelColor: Colors.orangeAccent,
          unselectedLabelColor: Colors.white54,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.shopping_bag_outlined), text: 'PUBLICACIONES'),
            Tab(icon: Icon(Icons.vertical_align_top), text: 'SUPERIOR'),
            Tab(icon: Icon(Icons.view_carousel), text: 'MEDIO'),
            Tab(icon: Icon(Icons.vertical_align_bottom), text: 'INFERIOR'),
            Tab(icon: Icon(Icons.linear_scale), text: 'MARQUESINA'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orangeAccent))
        : TabBarView(
            controller: _tabController,
            children: [
              _buildPublicacionesSection(),
              _buildEditorSection('hero', 'Hero Banners (Cabecera)'),
              _buildEditorSection('middle', 'Carrusel de Productos (Medio)'),
              _buildEditorSection('bottom', 'Colecciones Especiales (Inferior)'),
              _buildEditorSection('marquee', 'Marquesina de Anuncios (Superior)'),
            ],
          ),
      floatingActionButton: _tabController.index == 0
        ? null
        : FloatingActionButton.extended(
            onPressed: () => _addBannerDialog(_tabController.index),
            backgroundColor: Colors.orangeAccent,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('NUEVO MODELO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
    );
  }

  Widget _buildEditorSection(String type, String description) {
    final banners = _getBannersByType(type);
    
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          if (type == 'hero') _buildRotationRegulator(),
          const SizedBox(height: 10),
          Text(description, style: const TextStyle(color: Colors.white70, fontSize: 14, fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          Expanded(
            child: banners.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: banners.length,
                  itemBuilder: (context, index) => _buildBannerCard(banners[index]),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerCard(BannerPromo banner) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (banner.imagenUrl.isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              child: Image.network(
                banner.imagenUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(height: 120, color: Colors.grey[900], child: const Icon(Icons.broken_image, color: Colors.white24)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(banner.titulo, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      if (banner.tituloSeccion != null && banner.tituloSeccion!.isNotEmpty)
                        Text('Título Ext: ${banner.tituloSeccion}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                      Text(banner.subtitulo, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                  onPressed: () => _addBannerDialog(_tabController.index, existingBanner: banner),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => _deleteBanner(banner.id),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotationRegulator() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.orangeAccent, size: 18),
              const SizedBox(width: 10),
              const Text('ROTACIÓN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              const Spacer(),
              Text('$_rotationSeconds seg', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _rotationSeconds.toDouble(),
            min: 2,
            max: 15,
            divisions: 13,
            activeColor: Colors.orangeAccent,
            onChanged: (val) => _updateRotationConfig(val.toInt()),
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
          Icon(Icons.view_carousel, size: 60, color: Colors.white10),
          const SizedBox(height: 10),
          const Text('No hay carruseles configurados', style: TextStyle(color: Colors.white24)),
        ],
      ),
    );
  }

  Future<void> _addBannerDialog(int tabIndex, {BannerPromo? existingBanner}) async {
    String type = existingBanner?.tipo ?? (tabIndex == 1 ? 'hero' : (tabIndex == 2 ? 'middle' : (tabIndex == 3 ? 'bottom' : 'marquee')));
    String titulo = existingBanner?.titulo ?? '';
    String subtitulo = existingBanner?.subtitulo ?? '';
    String? tituloSeccion = existingBanner?.tituloSeccion;
    String? selectedProductId = existingBanner?.productId;
    String? selectedCategoriaId = existingBanner?.categoriaId;
    double velocidad = existingBanner?.velocidad ?? 5.0;
    String bgColorHex = existingBanner?.backgroundColor ?? '#0D47A1';
    String txtColorHex = existingBanner?.textColor ?? '#FFFFFF';
    _imageBytes = null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(existingBanner == null ? 'Nuevo Carrusel ${type.toUpperCase()}' : 'Editar Carrusel', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImagePicker(setDialogState, existingImageUrl: existingBanner?.imagenUrl),
                if (type == 'marquee') ...[
                  const Text('CONFIGURACIÓN DE MARQUESINA', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 15),
                TextFormField(
                  initialValue: titulo,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Título Interno (Banner)'),
                  onChanged: (v) => titulo = v,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: subtitulo,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Subtítulo'),
                  onChanged: (v) => subtitulo = v,
                ),
                if (type == 'marquee') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('Velocidad:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      Expanded(
                        child: Slider(
                          value: velocidad.clamp(1.0, 15.0),
                          min: 1, max: 15, divisions: 14,
                          activeColor: Colors.orangeAccent,
                          onChanged: (v) => setDialogState(() => velocidad = v),
                        ),
                      ),
                      Text('${velocidad.toInt()}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: bgColorHex,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Color Fondo (HEX)'),
                          onChanged: (v) => bgColorHex = v,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          initialValue: txtColorHex,
                          style: const TextStyle(color: Colors.white),
                          decoration: _inputDecoration('Color Texto (HEX)'),
                          onChanged: (v) => txtColorHex = v,
                        ),
                      ),
                    ],
                  ),
                ],
                if (type == 'bottom') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    initialValue: tituloSeccion,
                    style: const TextStyle(color: Colors.white),
                    decoration: _inputDecoration('Título Externo (Visible en Tienda)'),
                    onChanged: (v) => tituloSeccion = v,
                  ),
                ],
                const SizedBox(height: 20),
                const Divider(color: Colors.white10),
                const Text('VINCULAR A:', style: TextStyle(color: Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: (selectedProductId != null && _productos.any((p) => p.id == selectedProductId)) ? selectedProductId : null,
                  dropdownColor: const Color(0xFF1A1A1A),
                  decoration: _inputDecoration('Producto (Opcional)'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _productos.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) => selectedProductId = v,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: (selectedCategoriaId != null && _categorias.any((c) => c.id == selectedCategoriaId)) ? selectedCategoriaId : null,
                  dropdownColor: const Color(0xFF1A1A1A),
                  decoration: _inputDecoration('Categoría (Opcional)'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                  onChanged: (v) => selectedCategoriaId = v,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR', style: TextStyle(color: Colors.white24))),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    ).then((value) async {
      if (value == true && titulo.isNotEmpty) {
        if (existingBanner == null) {
          if (type == 'marquee' || _imageBytes != null) {
            await _saveNewBanner(type, titulo, subtitulo, tituloSeccion, selectedProductId, selectedCategoriaId, velocity: velocidad, bgColor: bgColorHex, txtColor: txtColorHex);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Error: Debes subir una imagen')));
          }
        } else {
          await _updateExistingBanner(existingBanner!, titulo, subtitulo, tituloSeccion, selectedProductId, selectedCategoriaId, velocity: velocidad, bgColor: bgColorHex, txtColor: txtColorHex);
        }
      }
    });
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
    );
  }

   Widget _buildImagePicker(StateSetter setDialogState, {String? existingImageUrl}) {
    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final image = await picker.pickImage(source: ImageSource.gallery);
        if (image != null) {
          final bytes = await image.readAsBytes();
          setDialogState(() => _imageBytes = bytes);
        }
      },
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white10),
        ),
        child: _imageBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.memory(_imageBytes!, fit: BoxFit.cover),
              )
            : (existingImageUrl != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.network(existingImageUrl, fit: BoxFit.cover),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo, color: Colors.white54, size: 30),
                      SizedBox(height: 8),
                      Text('Subir Imagen', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  )),
      ),
    );
  }

  Future<void> _saveNewBanner(String type, String titulo, String subtitulo, String? tituloSeccion, String? productId, String? categoriaId, {double? velocity, String? bgColor, String? txtColor}) async {
    setState(() => _isLoading = true);
    try {
      String imageUrl = '';
      if (_imageBytes != null) {
        final fileName = 'banner_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await SupabaseService.supabase.storage.from('branding').uploadBinary(fileName, _imageBytes!);
        imageUrl = SupabaseService.supabase.storage.from('branding').getPublicUrl(fileName);
      }

      final banner = BannerPromo.temporal(
        titulo: titulo,
        subtitulo: subtitulo,
        imagenUrl: imageUrl,
        tipo: type,
        tituloSeccion: tituloSeccion,
        productId: productId,
        categoriaId: categoriaId,
        velocidad: velocity ?? 5.0,
        backgroundColor: bgColor ?? '#0D47A1',
        textColor: txtColor ?? '#FFFFFF',
      );

      await SupabaseService.crearBanner(banner);
      await _loadInitialData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Carrusel guardado con éxito'), backgroundColor: Colors.green));
      }
    } catch (e) {
      print('Error al guardar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateExistingBanner(BannerPromo banner, String titulo, String subtitulo, String? tituloSeccion, String? productId, String? categoriaId, {double? velocity, String? bgColor, String? txtColor}) async {
    setState(() => _isLoading = true);
    try {
      String finalImageUrl = banner.imagenUrl;

      // Si se seleccionó una nueva imagen, subirla
      if (_imageBytes != null) {
        final fileName = 'banner_${banner.tipo}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await SupabaseService.supabase.storage.from('branding').uploadBinary(fileName, _imageBytes!);
        finalImageUrl = SupabaseService.supabase.storage.from('branding').getPublicUrl(fileName);
      }

      final updatedBanner = banner.copyWith(
        titulo: titulo,
        subtitulo: subtitulo,
        imagenUrl: finalImageUrl,
        updatedAt: DateTime.now(),
        tituloSeccion: tituloSeccion,
        productId: productId,
        categoriaId: categoriaId,
        velocidad: velocity,
        backgroundColor: bgColor,
        textColor: txtColor,
      );
      await SupabaseService.actualizarBanner(updatedBanner);
      await _loadInitialData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Carrusel actualizado con éxito'), backgroundColor: Colors.blueAccent));
      }
    } catch (e) {
      print('Error al actualizar: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Error al actualizar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleDestacado(Producto p) async {
    final newDestacado = !p.destacado;
    setState(() => _isLoading = true);
    try {
      final updatedProd = Producto(
        id: p.id,
        nombre: p.nombre,
        descripcion: p.descripcion,
        precio: p.precio,
        stock: p.stock,
        rubro: p.rubro,
        categoriaId: p.categoriaId,
        imagenUrl: p.imagenUrl,
        activo: p.activo,
        destacado: newDestacado,
        createdAt: p.createdAt,
        updatedAt: DateTime.now(),
        galeriaUrls: p.galeriaUrls,
        videoUrl: p.videoUrl,
        rubroId: p.rubroId,
        vendedorId: p.vendedorId,
      );
      
      await SupabaseService.actualizarProducto(updatedProd);
      await _loadInitialData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newDestacado
                  ? '⭐ ¡Producto agregado a la vidriera con éxito!'
                  : '❌ Producto removido de la vidriera.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: newDestacado ? Colors.green : Colors.orangeAccent,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('Error al alternar destacado: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildCategorySelector() {
    if (_categorias.isEmpty) return const SizedBox.shrink();
    
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categorias.length + 1,
        itemBuilder: (context, index) {
          final isAll = index == 0;
          final cat = isAll ? null : _categorias[index - 1];
          final catId = isAll ? null : cat!.id;
          final catName = isAll ? 'TODOS' : cat!.nombre;
          final isSelected = _selectedCategoryFilterId == catId;
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryFilterId = catId;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.orangeAccent : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? Colors.orangeAccent : Colors.white.withOpacity(0.1),
                  width: 1,
                ),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: Colors.orangeAccent.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ] : null,
              ),
              child: Center(
                child: Text(
                  catName.toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPublicacionesSection() {
    final filteredProds = _selectedCategoryFilterId == null
        ? _productos
        : _productos.where((p) => p.categoriaId == _selectedCategoryFilterId).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Banner de Instrucciones de Vidriera Principal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orangeAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.star_outline_rounded, color: Colors.orangeAccent, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'VIDRIERA DE LA PÁGINA PRINCIPAL',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Elige qué productos del catálogo destacar en la vidriera de la tienda de forma ágil:\n\n'
                  '• Filtro por Categorías: Selecciona cualquier categoría en el menú deslizante para filtrar al instante.\n'
                  '• Alternar Vidriera: Toca el icono de la estrella (⭐) en cada tarjeta para agregarlo o removerlo de la vitrina principal al instante.\n'
                  '• Editar Datos: Toca cualquier parte del producto para editar sus fotos, stock, rubro o precios en el catálogo general.',
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildCategorySelector(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                const Text(
                  'Listado de Publicaciones',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                ElevatedButton.icon(
                  onPressed: () => _editProductoDialog(null),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('NUEVA PUBLICACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orangeAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filteredProds.isEmpty
                ? const Center(child: Text('No hay productos cargados en esta categoría', style: TextStyle(color: Colors.white54)))
                : GridView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.72,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: filteredProds.length,
                    itemBuilder: (context, index) {
                      final p = filteredProds[index];
                      return _buildSimulatedProductCard(p);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedProductCard(Producto p) {
    final stockColor = p.stock > 0 ? (p.stock < 5 ? Colors.orange : const Color(0xFF00E676)) : Colors.red;
    final stockLabel = p.stock > 0 ? (p.stock < 5 ? 'ÚLTIMOS' : 'STOCK') : 'AGOTADO';
    final isDestacado = p.destacado;

    return GestureDetector(
      onTap: () => _editProductoDialog(p),
      child: Container(
        decoration: BoxDecoration(
          color: isDestacado ? Colors.orangeAccent.withOpacity(0.08) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestacado ? Colors.orangeAccent.withOpacity(0.5) : Colors.white.withOpacity(0.08),
            width: isDestacado ? 1.5 : 1,
          ),
          boxShadow: isDestacado ? [
            BoxShadow(
              color: Colors.orangeAccent.withOpacity(0.08),
              blurRadius: 10,
              spreadRadius: 2,
            )
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    child: p.imagenUrl.isNotEmpty
                        ? Image.network(
                            p.imagenUrl,
                            height: double.infinity,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.white12,
                              child: const Icon(Icons.broken_image, color: Colors.white30),
                            ),
                          )
                        : Container(
                            color: Colors.white10,
                            child: const Icon(Icons.image, color: Colors.white24),
                          ),
                  ),
                  if (isDestacado)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.white, size: 10),
                            SizedBox(width: 4),
                            Text(
                              'EN VIDRIERA',
                              style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: stockColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        stockLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          p.precioFormateado,
                          style: const TextStyle(
                            color: Color(0xFF00E676),
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          _toggleDestacado(p);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDestacado ? Colors.orangeAccent : Colors.white.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isDestacado ? Icons.star : Icons.star_border,
                            color: isDestacado ? Colors.white : Colors.white54,
                            size: 14,
                          ),
                        ),
                      ),
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

  Future<void> _editProductoDialog(Producto? existingProducto) async {
    String nombre = existingProducto?.nombre ?? '';
    String descripcion = existingProducto?.descripcion ?? '';
    double precio = existingProducto?.precio ?? 0.0;
    int stock = existingProducto?.stock ?? 0;
    String rubro = existingProducto?.rubro ?? 'Pesca';
    String categoriaId = existingProducto?.categoriaId ?? '';
    String imagenUrl = existingProducto?.imagenUrl ?? '';
    bool activo = existingProducto?.activo ?? true;
    bool destacado = existingProducto?.destacado ?? false;
    _imageBytes = null;

    if (categoriaId.isEmpty && _categorias.isNotEmpty) {
      categoriaId = _categorias.first.id;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: Text(
            existingProducto == null ? 'Nueva Publicación' : 'Editar Publicación',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildImagePicker(setDialogState, existingImageUrl: existingProducto?.imagenUrl),
                const SizedBox(height: 15),
                TextFormField(
                  initialValue: nombre,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Nombre del Producto'),
                  onChanged: (v) => nombre = v,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  initialValue: descripcion,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('Descripción'),
                  onChanged: (v) => descripcion = v,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: precio > 0 ? precio.toString() : '',
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Precio (\$)'),
                        onChanged: (v) => precio = double.tryParse(v) ?? 0.0,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        initialValue: stock.toString(),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white),
                        decoration: _inputDecoration('Stock'),
                        onChanged: (v) => stock = int.tryParse(v) ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: ['Pesca', 'Camping', 'Náutica'].contains(rubro) ? rubro : 'Pesca',
                  dropdownColor: const Color(0xFF1A1A1A),
                  decoration: _inputDecoration('Rubro'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: const [
                    DropdownMenuItem(value: 'Pesca', child: Text('Pesca')),
                    DropdownMenuItem(value: 'Camping', child: Text('Camping')),
                    DropdownMenuItem(value: 'Náutica', child: Text('Náutica')),
                  ],
                  onChanged: (v) {
                    if (v != null) rubro = v;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: (categoriaId.isNotEmpty && _categorias.any((c) => c.id == categoriaId)) ? categoriaId : null,
                  dropdownColor: const Color(0xFF1A1A1A),
                  decoration: _inputDecoration('Categoría'),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  items: _categorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                  onChanged: (v) {
                    if (v != null) categoriaId = v;
                  },
                ),
                const SizedBox(height: 15),
                SwitchListTile(
                  title: const Text('Producto Activo', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Visible en la tienda', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: activo,
                  activeColor: Colors.orangeAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => activo = v),
                ),
                SwitchListTile(
                  title: const Text('Producto Destacado', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text('Aparece en novedades', style: TextStyle(color: Colors.white54, fontSize: 11)),
                  value: destacado,
                  activeColor: Colors.orangeAccent,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setDialogState(() => destacado = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR', style: TextStyle(color: Colors.white24)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent),
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    ).then((value) async {
      if (value == true && nombre.isNotEmpty) {
        setState(() => _isLoading = true);
        try {
          String finalImageUrl = imagenUrl;
          if (_imageBytes != null) {
            final fileName = 'producto_${DateTime.now().millisecondsSinceEpoch}.jpg';
            await SupabaseService.supabase.storage.from('branding').uploadBinary(fileName, _imageBytes!);
            finalImageUrl = SupabaseService.supabase.storage.from('branding').getPublicUrl(fileName);
          }

          if (existingProducto == null) {
            final newProd = Producto(
              id: '',
              nombre: nombre,
              descripcion: descripcion,
              precio: precio,
              stock: stock,
              rubro: rubro,
              categoriaId: categoriaId,
              imagenUrl: finalImageUrl,
              activo: activo,
              destacado: destacado,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            );
            await SupabaseService.guardarProducto(newProd);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Producto creado con éxito'), backgroundColor: Colors.green),
            );
          } else {
            final updatedProd = Producto(
              id: existingProducto.id,
              nombre: nombre,
              descripcion: descripcion,
              precio: precio,
              stock: stock,
              rubro: rubro,
              categoriaId: categoriaId,
              imagenUrl: finalImageUrl,
              activo: activo,
              destacado: destacado,
              createdAt: existingProducto.createdAt,
              updatedAt: DateTime.now(),
              galeriaUrls: existingProducto.galeriaUrls,
              videoUrl: existingProducto.videoUrl,
              rubroId: existingProducto.rubroId,
              vendedorId: existingProducto.vendedorId,
            );
            await SupabaseService.actualizarProducto(updatedProd);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Producto actualizado con éxito'), backgroundColor: Colors.blueAccent),
            );
          }
          await _loadInitialData();
        } catch (e) {
          print('Error al guardar producto: $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
          );
        } finally {
          setState(() => _isLoading = false);
        }
      }
    });
  }
}
