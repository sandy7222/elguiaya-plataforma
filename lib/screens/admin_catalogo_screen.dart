import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:El Guia YA_master/models/categoria.dart';
import 'package:El Guia YA_master/models/producto.dart';
import 'package:El Guia YA_master/models/rubro.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';
import 'package:El Guia YA_master/services/storage_service.dart';
import 'package:El Guia YA_master/screens/product_detail_screen.dart';

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

  // Galería de Imágenes (Multi-Upload Asíncrono)
  final List<Map<String, dynamic>> _gallerySlots = []; // { 'url': String?, 'isUploading': bool, 'fileName': String? }

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      final results = await Future.wait([
        SupabaseService.getProductos(),
        SupabaseService.getRubros(),
        SupabaseService.getCategorias(),
      ]);

      setState(() {
        _productos = results[0] as List<Producto>;
        _productosFiltrados = _productos;
        _rubros = results[1] as List<Rubro>;
        _categorias = results[2] as List<Categoria>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al cargar datos admin: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filtrarProductos(String query) {
    setState(() {
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
      // La imagen principal es el primer slot
      final String finalImageUrl = _gallerySlots.isNotEmpty ? (_gallerySlots[0]['url'] ?? '') : '';
      
      // La galeria son todos los slots que tienen URL
      final List<String> galeriaLinks = _gallerySlots
          .where((s) => s['url'] != null)
          .map((s) => s['url'] as String)
          .toList();

      final rubroObj = _rubros.firstWhere((r) => r.id == _rubroSeleccionado, orElse: () => Rubro.empty());

      final producto = Producto(
        id: _idEditando ?? DateTime.now().millisecondsSinceEpoch.toString(),
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        precio: double.tryParse(_precioController.text) ?? 0.0,
        stock: int.tryParse(_stockController.text) ?? 0,
        rubro: rubroObj.nombre,
        rubroId: rubroObj.id,
        categoriaId: _subcategoriaSeleccionada ?? _categoriaPadreSeleccionada ?? '',
        imagenUrl: finalImageUrl ?? '',
        galeriaUrls: galeriaLinks,
        videoUrl: _videoUrlController.text.trim(),
        activo: _isPublicado,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_idEditando != null) {
        await SupabaseService.actualizarProducto(producto);
      } else {
        await SupabaseService.guardarProducto(producto);
      }
      
      _limpiarFormulario();
      _cargarDatos();
      _showMsg('Producto guardado con éxito', Colors.green);
    } catch (e) {
      _showMsg('Error al guardar: $e', Colors.red);
    } finally {
      setState(() => _isSaving = false);
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
      _isPublicado = true;
    });
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
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
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
      onTap: () => _pickAndUploadImage(_gallerySlots.length),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _glassBorder),
        ),
        child: const Icon(Icons.add_a_photo_outlined, color: _capitanNaranja, size: 20),
      ),
    );
  }

  Widget _buildUploadSlot(int index) {
    final slot = _gallerySlots[index];
    final isUploading = slot['isUploading'] as bool;
    final url = slot['url'] as String?;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.black45,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: url != null ? _capitanNaranja : _glassBorder),
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
        if (url != null)
          const Positioned(
            top: 4, right: 4,
            child: Icon(Icons.check_circle, color: _capitanNaranja, size: 14),
          ),
        Positioned(
          top: 0, left: 0,
          child: GestureDetector(
            onTap: () => setState(() => _gallerySlots.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 8),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadImage(int index) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (image != null) {
      setState(() {
        if (index == _gallerySlots.length) {
          _gallerySlots.add({'url': null, 'isUploading': true, 'fileName': image.name});
        } else {
          _gallerySlots[index] = {'url': null, 'isUploading': true, 'fileName': image.name};
        }
      });

      try {
        final url = await StorageService.uploadAdminDocument(
          file: image,
          folder: 'admin_catalogo',
          prefix: 'producto',
        );

        setState(() {
          _gallerySlots[index] = {
            'url': url,
            'isUploading': false,
            'fileName': image.name,
          };
        });
      } catch (e) {
        setState(() => _gallerySlots.removeAt(index));
        _showMsg('Error al subir: $e', Colors.red);
      }
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
      itemCount: _productosFiltrados.length,
      itemBuilder: (context, index) {
        final p = _productosFiltrados[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: _glassColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: _glassBorder)),
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: p.imagenUrl.isNotEmpty ? Image.network(p.imagenUrl, width: 45, height: 45, fit: BoxFit.cover) : const Icon(Icons.image, color: Colors.white24),
            ),
            title: Text(p.nombre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text('\$${p.precio} - Stock: ${p.stock}', style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
      
      // Cargar galeria en los slots
      _gallerySlots.clear();
      if (p.imagenUrl.isNotEmpty) {
        _gallerySlots.add({'url': p.imagenUrl, 'isUploading': false, 'fileName': 'Principal'});
      }
      for (var url in p.galeriaUrls) {
        _gallerySlots.add({'url': url, 'isUploading': false, 'fileName': 'Galeria'});
      }
    });
    _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut);
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
}
