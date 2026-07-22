import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:capitanya_master/models/categoria.dart';
import 'package:capitanya_master/models/producto.dart';
import 'package:capitanya_master/models/producto_variante.dart';
import 'package:capitanya_master/models/rubro.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/services/storage_service.dart';
import 'package:capitanya_master/screens/product_detail_screen.dart';

class AdminCatalogoScreen extends StatefulWidget {
  const AdminCatalogoScreen({super.key});

  @override
  State<AdminCatalogoScreen> createState() => _AdminCatalogoScreenState();
}

class _AdminCatalogoScreenState extends State<AdminCatalogoScreen> {
  // Colores y Estilo Admin
  static const Color _capitanAzul = Color(0xFF001F3F);
  static const Color _capitanAzulClaro = Color(0xFF0074D9);
  static const Color _capitanNaranja = Color(0xFF00E676);
  final Color _glassColor = Colors.white.withOpacity(0.05);
  final Color _glassBorder = Colors.white.withOpacity(0.1);

  // Controladores
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _galeriaController = TextEditingController(); // URLs separadas por coma
  final ScrollController _scrollController = ScrollController();

  // Estado
  List<Producto> _productos = [];
  List<Producto> _productosFiltrados = [];
  List<Rubro> _rubros = [];
  List<Categoria> _categorias = [];
  String? _rubroSeleccionado;
  String? _categoriaPadreSeleccionada;
  String? _subcategoriaSeleccionada;
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _idEditando;
  bool _isPublicado = true;

  // Paginación
  int _paginaActualAdmin = 1;
  static const int _productosPorPaginaAdmin = 15;

  int get _totalPaginasAdmin => (_productosFiltrados.length / _productosPorPaginaAdmin).ceil();

  List<Producto> get _productosEnPaginaAdmin {
    final inicio = (_paginaActualAdmin - 1) * _productosPorPaginaAdmin;
    final fin = inicio + _productosPorPaginaAdmin;
    if (inicio >= _productosFiltrados.length) return [];
    return _productosFiltrados.sublist(
      inicio,
      fin > _productosFiltrados.length ? _productosFiltrados.length : fin,
    );
  }

  // Galería de Imágenes (Multi-Upload Asíncrono)
  final List<Map<String, dynamic>> _gallerySlots = []; // { 'url': String?, 'isUploading': bool, 'fileName': String? }

  // Variantes (tipo configurable: Color, Talle, Litros...)
  final List<_VarianteDraft> _variantes = [];
  List<OpcionVariante> _tiposVariante = [];
  List<OpcionVarianteValor> _valoresCatalogo = [];
  String? _tipoVarianteId;
  String _tipoVarianteNombre = 'Color';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    _cargarTiposVariante();
  }

  Future<void> _cargarTiposVariante() async {
    final tipos = await SupabaseService.getOpcionesVariante();
    if (!mounted) return;
    setState(() {
      _tiposVariante = tipos;
      if (_tipoVarianteId == null && tipos.isNotEmpty) {
        OpcionVariante color = tipos.first;
        for (final t in tipos) {
          if (t.nombre.toLowerCase() == 'color') {
            color = t;
            break;
          }
        }
        _tipoVarianteId = color.id;
        _tipoVarianteNombre = color.nombre;
      }
    });
    await _cargarValoresDelTipo();
  }

  Future<void> _cargarValoresDelTipo() async {
    if (_tipoVarianteId == null) {
      setState(() => _valoresCatalogo = []);
      return;
    }
    final valores =
        await SupabaseService.getValoresOpcionVariante(_tipoVarianteId!);
    if (!mounted) return;
    setState(() => _valoresCatalogo = valores);
  }

  Future<void> _cambiarTipoVariante(String? opcionId) async {
    if (opcionId == null) return;
    OpcionVariante? tipo;
    for (final t in _tiposVariante) {
      if (t.id == opcionId) {
        tipo = t;
        break;
      }
    }
    if (tipo == null) return;

    final cambiaTipo = _tipoVarianteId != opcionId;
    if (cambiaTipo && _variantes.isNotEmpty) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: _capitanAzul,
          title: const Text('Cambiar tipo de variante', style: TextStyle(color: Colors.white)),
          content: Text(
            'Al pasar a "${tipo!.nombre}" se borran las variantes actuales de este formulario. ¿Continuar?',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cambiar', style: TextStyle(color: _capitanNaranja)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    setState(() {
      _tipoVarianteId = opcionId;
      _tipoVarianteNombre = tipo!.nombre;
      if (cambiaTipo) _variantes.clear();
    });
    await _cargarValoresDelTipo();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      final results = await Future.wait([
        SupabaseService.getProductos(forceRefresh: true),
        SupabaseService.getRubros(),
        SupabaseService.getCategorias(),
      ]);

      setState(() {
        _productos = results[0] as List<Producto>;
        _productosFiltrados = _productos;
        _rubros = results[1] as List<Rubro>;
        _categorias = results[2] as List<Categoria>;
        _paginaActualAdmin = 1;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos admin: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filtrarProductos(String query) {
    setState(() {
      _paginaActualAdmin = 1;
      _productosFiltrados = _productos.where((p) => 
        p.nombre.toLowerCase().contains(query.toLowerCase()) || 
        p.rubro.toLowerCase().contains(query.toLowerCase())
      ).toList();
    });
  }

  Future<void> _guardarProducto() async {
    if (_nombreController.text.isEmpty || _precioController.text.isEmpty) {
      _showMsg('Nombre y precio son requeridos', Colors.orange);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Portada = primer slot con URL; galería = el resto (sin duplicar la portada)
      final urlsConImagen = _gallerySlots
          .where((s) => s['url'] != null && (s['url'] as String).isNotEmpty)
          .map((s) => s['url'] as String)
          .toList();
      final String finalImageUrl =
          urlsConImagen.isNotEmpty ? urlsConImagen.first : '';
      final List<String> galeriaLinks =
          urlsConImagen.length > 1 ? urlsConImagen.sublist(1) : <String>[];

      final rubroObj = _rubros.firstWhere((r) => r.id == _rubroSeleccionado, orElse: () => Rubro.empty());

      final variantesDraft = _variantesAModelo(_idEditando ?? 'tmp');
      final stockCalculado = variantesDraft.isNotEmpty
          ? variantesDraft.fold<int>(0, (s, v) => s + v.stock)
          : (int.tryParse(_stockController.text) ?? 0);

      // Si no hay galería pero sí variante default con foto, usarla de portada
      var imagenPortada = finalImageUrl;
      if (imagenPortada.isEmpty && variantesDraft.isNotEmpty) {
        final def = variantesDraft.firstWhere(
          (v) => v.esDefault,
          orElse: () => variantesDraft.first,
        );
        if (def.imagenUrl != null && def.imagenUrl!.isNotEmpty) {
          imagenPortada = def.imagenUrl!;
        }
      }

      final producto = Producto(
        id: _idEditando ?? DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        precio: double.tryParse(_precioController.text) ?? 0.0,
        stock: stockCalculado,
        rubro: rubroObj.nombre,
        rubroId: rubroObj.id,
        categoriaId: _subcategoriaSeleccionada ?? _categoriaPadreSeleccionada ?? '',
        imagenUrl: imagenPortada,
        galeriaUrls: galeriaLinks,
        videoUrl: _videoUrlController.text.trim(),
        activo: _isPublicado,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        varianteOpcionId: _tipoVarianteId,
        varianteTipoNombre: _tipoVarianteNombre,
      );

      if (_idEditando != null) {
        await SupabaseService.actualizarProducto(producto);
        await SupabaseService.sincronizarVariantesProducto(
          productoId: producto.id,
          variantes: _variantesAModelo(producto.id),
        );
      } else {
        final nuevoId = await SupabaseService.guardarProducto(producto);
        await SupabaseService.sincronizarVariantesProducto(
          productoId: nuevoId,
          variantes: _variantesAModelo(nuevoId),
        );
      }
      
      _limpiarFormulario();
      await _cargarDatos();
      _showMsg('Producto guardado con éxito', Colors.green);
    } catch (e) {
      _showMsg('Error al guardar: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  List<ProductoVariante> _variantesAModelo(String productoId) {
    return List.generate(_variantes.length, (i) {
      final d = _variantes[i];
      return ProductoVariante(
        id: d.id,
        productoId: productoId,
        sku: d.sku.isEmpty ? null : d.sku,
        color: d.color,
        opcionValorId: d.opcionValorId,
        stock: d.stock,
        precio: d.precio,
        imagenUrl: d.imagenUrl,
        esDefault: d.esDefault || i == 0,
        activo: true,
        orden: i,
      );
    }).where((v) => v.color.trim().isNotEmpty).toList();
  }

  void _agregarVariante({String? color, String? opcionValorId}) {
    setState(() {
      _variantes.add(_VarianteDraft(
        id: 'tmp_${DateTime.now().microsecondsSinceEpoch}',
        color: color ?? '',
        opcionValorId: opcionValorId,
        stock: 0,
        esDefault: _variantes.isEmpty,
      ));
    });
  }

  Future<void> _subirImagenVariante(int index) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image == null) return;
    setState(() => _variantes[index].isUploading = true);
    try {
      final url = await StorageService.uploadAdminDocument(
        file: image,
        folder: 'admin_catalogo',
        prefix: 'variante',
      );
      if (!mounted) return;
      setState(() {
        _variantes[index].imagenUrl = url;
        _variantes[index].isUploading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _variantes[index].isUploading = false);
      _showMsg('Error al subir imagen de variante: $e', Colors.red);
    }
  }

  void _limpiarFormulario() {
    _nombreController.clear();
    _descripcionController.clear();
    _precioController.clear();
    _stockController.clear();
    _videoUrlController.clear();
    _galeriaController.clear();
    setState(() {
      _idEditando = null;
      _rubroSeleccionado = null;
      _categoriaPadreSeleccionada = null;
      _subcategoriaSeleccionada = null;
      _gallerySlots.clear();
      _variantes.clear();
      _isPublicado = true;
      // Mantener tipo actual; si no hay, Color
      if (_tiposVariante.isNotEmpty && _tipoVarianteId == null) {
        final color = _tiposVariante.firstWhere(
          (t) => t.nombre.toLowerCase() == 'color',
          orElse: () => _tiposVariante.first,
        );
        _tipoVarianteId = color.id;
        _tipoVarianteNombre = color.nombre;
      }
    });
    _cargarValoresDelTipo();
  }

  void _showMsg(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _capitanAzul,
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_capitanAzul, Color(0xFF001529)],
            ),
          ),
          child: _isLoading 
              ? const Center(child: CircularProgressIndicator(color: _capitanNaranja))
              : SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      _buildGlassForm(),
                      const SizedBox(height: 30),
                      const Text('PRODUCTOS REGISTRADOS', 
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                      const SizedBox(height: 15),
                      _buildSearchBar(),
                      const SizedBox(height: 15),
                      _buildProductList(),
                      _buildAdminPaginationControl(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        const Text('Gestión de Catálogo', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildGlassForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _glassColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_idEditando != null ? 'EDITAR PRODUCTO' : 'NUEVO PRODUCTO', 
            style: const TextStyle(color: _capitanNaranja, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 20),
          _buildTextField(_nombreController, 'Nombre del producto', Icons.shopping_bag_outlined),
          const SizedBox(height: 15),
          _buildTextField(_descripcionController, 'Descripción técnica', Icons.description_outlined, maxLines: 3),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(child: _buildTextField(_precioController, 'Precio', Icons.attach_money, isNumeric: true)),
              const SizedBox(width: 15),
              Expanded(child: _buildTextField(_stockController, 'Stock', Icons.inventory_2_outlined, isNumeric: true)),
            ],
          ),
          const SizedBox(height: 20),
          const Text('MULTIMEDIA Y LINKS', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildTextField(_videoUrlController, 'URL de Video (YouTube/Vimeo)', Icons.play_circle_outline),
          const SizedBox(height: 20),
          _buildCategorizacionSection(),
          const SizedBox(height: 20),
          _buildImageGallerySection(),
          const SizedBox(height: 25),
          _buildVariantesSection(),
          const SizedBox(height: 25),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildCategorizacionSection() {
    final categoriasPadre = _categorias.where((c) => c.parentId == null && (c.rubroId == null || c.rubroId == _rubroSeleccionado)).toList();
    final subcategorias = _categoriaPadreSeleccionada != null 
        ? _categorias.where((c) => c.parentId == _categoriaPadreSeleccionada).toList()
        : <Categoria>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CATEGORIZACIÓN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        
        // Rubro Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _rubroSeleccionado,
              hint: const Text('Seleccionar Rubro Principal', style: TextStyle(color: Colors.white30)),
              dropdownColor: _capitanAzul,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: _capitanAzulClaro),
              style: const TextStyle(color: Colors.white),
              items: _rubros.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nombre))).toList(),
              onChanged: (val) => setState(() {
                _rubroSeleccionado = val;
                _categoriaPadreSeleccionada = null;
                _subcategoriaSeleccionada = null;
              }),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Categoria Selector
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _categoriaPadreSeleccionada,
                    hint: const Text('Categoría', style: TextStyle(color: Colors.white30)),
                    dropdownColor: _capitanAzul,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down, color: _capitanAzulClaro),
                    style: const TextStyle(color: Colors.white),
                    items: categoriasPadre.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                    onChanged: _rubroSeleccionado == null ? null : (val) => setState(() {
                      _categoriaPadreSeleccionada = val;
                      _subcategoriaSeleccionada = null;
                    }),
                  ),
                ),
              ),
            ),
            if (subcategorias.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(12), border: Border.all(color: _glassBorder)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _subcategoriaSeleccionada,
                      hint: const Text('Subcategoría', style: TextStyle(color: Colors.white30)),
                      dropdownColor: _capitanAzul,
                      isExpanded: true,
                      icon: const Icon(Icons.arrow_drop_down, color: _capitanAzulClaro),
                      style: const TextStyle(color: Colors.white),
                      items: subcategorias.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))).toList(),
                      onChanged: (val) => setState(() => _subcategoriaSeleccionada = val),
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ],
    );
  }

  void _hacerPortada(int index) {
    if (index <= 0 || index >= _gallerySlots.length) return;
    setState(() {
      final slot = _gallerySlots.removeAt(index);
      _gallerySlots.insert(0, slot);
    });
    _showMsg('Imagen marcada como portada', _capitanNaranja);
  }

  void _moverImagen(int index, int delta) {
    final nuevo = index + delta;
    if (nuevo < 0 || nuevo >= _gallerySlots.length) return;
    setState(() {
      final slot = _gallerySlots.removeAt(index);
      _gallerySlots.insert(nuevo, slot);
    });
  }

  Widget _buildImageGallerySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('GALERÍA DE IMÁGENES (Carga Automática)', style: TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
            _buildStatusToggle(),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Tocá + para elegir varias fotos a la vez (Ctrl/Shift). ★ = portada · ← → = orden.',
          style: TextStyle(color: Colors.white38, fontSize: 10),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: _gallerySlots.length + 1,
          itemBuilder: (context, index) {
            if (index == _gallerySlots.length) return _buildAddSlot();
            return _buildUploadSlot(index);
          },
        ),
      ],
    );
  }

  Widget _buildStatusToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('PUBLICADO', style: TextStyle(color: Colors.white70, fontSize: 10)),
        Switch(
          value: _isPublicado, 
          onChanged: (v) => setState(() => _isPublicado = v), 
          activeThumbColor: _capitanNaranja,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }

  Widget _buildAddSlot() {
    return InkWell(
      onTap: _pickAndUploadImages,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _glassBorder),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: _capitanNaranja, size: 20),
            SizedBox(height: 4),
            Text(
              'Varias',
              style: TextStyle(color: Colors.white38, fontSize: 9),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadSlot(int index) {
    final slot = _gallerySlots[index];
    final isUploading = slot['isUploading'] as bool;
    final url = slot['url'] as String?;
    final esPortada = index == 0 && url != null;

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: esPortada
                        ? _capitanNaranja
                        : (url != null ? _capitanNaranja.withOpacity(0.45) : _glassBorder),
                    width: esPortada ? 2 : 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: isUploading
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _capitanNaranja))
                      : url != null
                          ? Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                          : const Center(child: Icon(Icons.image, color: Colors.white24)),
                ),
              ),
              if (esPortada)
                Positioned(
                  bottom: 4,
                  left: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: _capitanNaranja.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'PORTADA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () => setState(() => _gallerySlots.removeAt(index)),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: const Icon(Icons.close, color: Colors.white, size: 8),
                  ),
                ),
              ),
              if (url != null && !esPortada)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () => _hacerPortada(index),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: _capitanNaranja.withOpacity(0.6)),
                      ),
                      child: const Icon(Icons.star_border, color: _capitanNaranja, size: 12),
                    ),
                  ),
                ),
              if (esPortada)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                    child: const Icon(Icons.star, color: _capitanNaranja, size: 12),
                  ),
                ),
            ],
          ),
        ),
        if (url != null && _gallerySlots.length > 1) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _galleryMoveBtn(
                icon: Icons.chevron_left,
                enabled: index > 0,
                onTap: () => _moverImagen(index, -1),
              ),
              const SizedBox(width: 4),
              _galleryMoveBtn(
                icon: Icons.chevron_right,
                enabled: index < _gallerySlots.length - 1,
                onTap: () => _moverImagen(index, 1),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _galleryMoveBtn({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 22,
        height: 18,
        decoration: BoxDecoration(
          color: enabled ? Colors.black45 : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: enabled ? _glassBorder : Colors.transparent),
        ),
        child: Icon(icon, size: 14, color: enabled ? Colors.white70 : Colors.white24),
      ),
    );
  }

  Future<void> _pickAndUploadImages() async {
    final picker = ImagePicker();
    // En desktop/web permite seleccionar varias con Ctrl/Shift + click
    final images = await picker.pickMultiImage(imageQuality: 70);

    if (images.isEmpty) return;

    final slotIds = <String>[];
    setState(() {
      for (final image in images) {
        final id = '${DateTime.now().microsecondsSinceEpoch}_${image.name}_${slotIds.length}';
        slotIds.add(id);
        _gallerySlots.add({
          'id': id,
          'url': null,
          'isUploading': true,
          'fileName': image.name,
        });
      }
    });

    await Future.wait(
      List.generate(images.length, (i) async {
        final slotId = slotIds[i];
        final image = images[i];
        try {
          final url = await StorageService.uploadAdminDocument(
            file: image,
            folder: 'admin_catalogo',
            prefix: 'producto',
          );
          if (!mounted) return;
          setState(() {
            final idx = _gallerySlots.indexWhere((s) => s['id'] == slotId);
            if (idx >= 0) {
              _gallerySlots[idx] = {
                'id': slotId,
                'url': url,
                'isUploading': false,
                'fileName': image.name,
              };
            }
          });
        } catch (e) {
          if (!mounted) return;
          setState(() {
            _gallerySlots.removeWhere((s) => s['id'] == slotId);
          });
          _showMsg('Error al subir ${image.name}: $e', Colors.red);
        }
      }),
    );

    if (!mounted) return;
    if (images.length > 1) {
      _showMsg('${images.length} imágenes cargadas', Colors.green);
    }
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _guardarProducto,
        style: ElevatedButton.styleFrom(backgroundColor: _capitanNaranja, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('GUARDAR Y PUBLICAR', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: _glassColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
      child: TextField(
        controller: _searchController,
        onChanged: _filtrarProductos,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(hintText: 'Buscar productos...', hintStyle: TextStyle(color: Colors.white38), border: InputBorder.none, icon: Icon(Icons.search, color: Colors.white38)),
      ),
    );
  }

  Widget _buildProductList() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _productosEnPaginaAdmin.length,
      itemBuilder: (context, index) {
        final p = _productosEnPaginaAdmin[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: _glassColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: p.imagenUrl.isNotEmpty ? Image.network(p.imagenUrl, width: 45, height: 45, fit: BoxFit.cover) : const Icon(Icons.image, color: Colors.white24),
            ),
            title: Text(p.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              '\$${p.precio} - Stock: ${p.stockDisponible}'
              '${p.tieneVariantes ? ' · ${p.variantesActivas.length} colores' : ''}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(Icons.visibility, color: p.activo ? Colors.green : Colors.grey, size: 20),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailScreen(producto: p),
                      ),
                    );
                  },
                  tooltip: 'Ver Página Publicada',
                ),
                IconButton(
                  icon: const Icon(Icons.link, color: _capitanAzulClaro, size: 20),
                  onPressed: () {
                    final url = 'http://localhost:8080/#/producto?id=${p.id}';
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Link de producto copiado!'), backgroundColor: Colors.green));
                  },
                  tooltip: 'Copiar Link para WhatsApp',
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: _capitanAzulClaro, size: 20),
                  onPressed: () => _editarProducto(p),
                  tooltip: 'Editar Datos',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  void _editarProducto(Producto p) {
    setState(() {
      _idEditando = p.id;
      _nombreController.text = p.nombre;
      _descripcionController.text = p.descripcion;
      _precioController.text = p.precio.toString();
      _stockController.text = p.stock.toString();
      _videoUrlController.text = p.videoUrl ?? '';
      _isPublicado = p.activo;
      _rubroSeleccionado = p.rubroId;
      _categoriaPadreSeleccionada = p.categoriaId;
      
      // Portada primero; resto de galería sin duplicar la misma URL
      _gallerySlots.clear();
      final seen = <String>{};
      if (p.imagenUrl.isNotEmpty) {
        _gallerySlots.add({'url': p.imagenUrl, 'isUploading': false, 'fileName': 'Principal'});
        seen.add(p.imagenUrl);
      }
      for (final url in p.galeriaUrls) {
        if (url.isEmpty || seen.contains(url)) continue;
        seen.add(url);
        _gallerySlots.add({'url': url, 'isUploading': false, 'fileName': 'Galeria'});
      }

      _variantes
        ..clear()
        ..addAll(p.variantes.map((v) => _VarianteDraft.fromModelo(v)));

      if (p.varianteOpcionId != null && p.varianteOpcionId!.isNotEmpty) {
        _tipoVarianteId = p.varianteOpcionId;
        String? nombreTipo = p.varianteTipoNombre;
        if (nombreTipo == null || nombreTipo.isEmpty) {
          for (final t in _tiposVariante) {
            if (t.id == p.varianteOpcionId) {
              nombreTipo = t.nombre;
              break;
            }
          }
        }
        _tipoVarianteNombre = nombreTipo ?? 'Color';
      } else if (_tiposVariante.isNotEmpty) {
        final color = _tiposVariante.firstWhere(
          (t) => t.nombre.toLowerCase() == 'color',
          orElse: () => _tiposVariante.first,
        );
        _tipoVarianteId = color.id;
        _tipoVarianteNombre = color.nombre;
      }
    });
    _cargarValoresDelTipo();
    // Por si el listado no trajo el join, recargar variantes
    if (p.variantes.isEmpty) {
      SupabaseService.getVariantesProducto(p.id).then((vars) {
        if (!mounted || _idEditando != p.id) return;
        if (vars.isEmpty) return;
        setState(() {
          _variantes
            ..clear()
            ..addAll(vars.map((v) => _VarianteDraft.fromModelo(v)));
        });
      });
    }
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
  }

  Widget _buildVariantesSection() {
    final tipo = _tipoVarianteNombre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'VARIANTES POR ${tipo.toUpperCase()}',
          style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _glassBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _tipoVarianteId,
              hint: const Text('Tipo de variante', style: TextStyle(color: Colors.white30)),
              dropdownColor: _capitanAzul,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, color: _capitanAzulClaro),
              style: const TextStyle(color: Colors.white),
              items: _tiposVariante
                  .map((t) => DropdownMenuItem(value: t.id, child: Text(t.nombre)))
                  .toList(),
              onChanged: _cambiarTipoVariante,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Cada $tipo tiene su foto y stock. Si hay variantes, el stock total se calcula solo.',
                style: const TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ),
            TextButton.icon(
              onPressed: () => _agregarVariante(),
              icon: const Icon(Icons.add, size: 16, color: _capitanNaranja),
              label: Text('Agregar $tipo', style: const TextStyle(color: _capitanNaranja, fontSize: 12)),
            ),
          ],
        ),
        if (_valoresCatalogo.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _valoresCatalogo.map((c) {
              final ya = _variantes.any((v) => v.color.toLowerCase() == c.valor.toLowerCase());
              return ActionChip(
                label: Text(c.valor, style: TextStyle(fontSize: 11, color: ya ? Colors.white38 : Colors.white)),
                backgroundColor: ya ? Colors.white10 : Colors.black45,
                onPressed: ya
                    ? null
                    : () => _agregarVariante(color: c.valor, opcionValorId: c.id),
                avatar: c.codigoHex != null
                    ? CircleAvatar(
                        backgroundColor: _parseHex(c.codigoHex!),
                        radius: 8,
                      )
                    : null,
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 12),
        if (_variantes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _glassBorder),
            ),
            child: const Text(
              'Sin variantes: se vende con el stock e imagen principal del producto.',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            ),
          )
        else
          ...List.generate(_variantes.length, _buildVarianteCard),
      ],
    );
  }

  Widget _buildVarianteCard(int index) {
    final v = _variantes[index];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: v.esDefault ? _capitanNaranja : _glassBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _subirImagenVariante(index),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _glassBorder),
              ),
              child: v.isUploading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _capitanNaranja))
                  : v.imagenUrl != null && v.imagenUrl!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(v.imagenUrl!, fit: BoxFit.cover, width: 64, height: 64),
                        )
                      : const Icon(Icons.add_a_photo_outlined, color: _capitanNaranja, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('var_label_${v.id}_$_tipoVarianteNombre'),
                        initialValue: v.color,
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: _tipoVarianteNombre,
                          labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _glassBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _glassBorder)),
                        ),
                        onChanged: (val) => v.color = val,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: v.stock.toString(),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: 'Stock',
                          labelStyle: const TextStyle(color: Colors.white38, fontSize: 11),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.black26,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _glassBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _glassBorder)),
                        ),
                        onChanged: (val) => v.stock = int.tryParse(val) ?? 0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() {
                        for (final other in _variantes) {
                          other.esDefault = false;
                        }
                        v.esDefault = true;
                      }),
                      child: Row(
                        children: [
                          Icon(
                            v.esDefault ? Icons.star : Icons.star_border,
                            color: _capitanNaranja,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            v.esDefault ? 'Default' : 'Hacer default',
                            style: const TextStyle(color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                      onPressed: () => setState(() => _variantes.removeAt(index)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _parseHex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF888888);
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1, bool isNumeric = false}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: Icon(icon, color: _capitanAzulClaro, size: 20),
        filled: true,
        fillColor: Colors.black12,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: _glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _capitanNaranja)),
      ),
    );
  }

  Widget _buildAdminPaginationControl() {
    final total = _totalPaginasAdmin;
    if (total <= 1) return const SizedBox.shrink();

    List<Widget> pageButtons = [];
    for (int i = 1; i <= total; i++) {
      final isCurrent = i == _paginaActualAdmin;
      pageButtons.add(
        GestureDetector(
          onTap: () => _cambiarPaginaAdmin(i),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isCurrent ? _capitanNaranja : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent ? _capitanNaranja : _glassBorder,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '$i',
              style: TextStyle(
                color: isCurrent ? Colors.black87 : Colors.white,
                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(top: 20, bottom: 10),
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: _glassColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _glassBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
            disabledColor: Colors.white24,
            onPressed: _paginaActualAdmin > 1 ? () => _cambiarPaginaAdmin(_paginaActualAdmin - 1) : null,
          ),
          const SizedBox(width: 8),
          ...pageButtons,
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
            disabledColor: Colors.white24,
            onPressed: _paginaActualAdmin < total ? () => _cambiarPaginaAdmin(_paginaActualAdmin + 1) : null,
          ),
        ],
      ),
    );
  }

  void _cambiarPaginaAdmin(int pagina) {
    if (pagina < 1 || pagina > _totalPaginasAdmin) return;
    setState(() {
      _paginaActualAdmin = pagina;
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        650,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }
}

class _VarianteDraft {
  String id;
  String color;
  String? opcionValorId;
  int stock;
  double? precio;
  String? imagenUrl;
  String sku;
  bool esDefault;
  bool isUploading;

  _VarianteDraft({
    required this.id,
    required this.color,
    this.opcionValorId,
    required this.stock,
    this.precio,
    this.imagenUrl,
    this.sku = '',
    this.esDefault = false,
    this.isUploading = false,
  });

  factory _VarianteDraft.fromModelo(ProductoVariante v) {
    return _VarianteDraft(
      id: v.id,
      color: v.color,
      opcionValorId: v.opcionValorId,
      stock: v.stock,
      precio: v.precio,
      imagenUrl: v.imagenUrl,
      sku: v.sku ?? '',
      esDefault: v.esDefault,
    );
  }
}
