
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/safe_button.dart';

import '../models/categoria.dart';
import '../models/producto.dart';
import '../models/rubro.dart';
import '../models/atributo.dart';
import '../models/producto_atributo.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _precioController = TextEditingController();
  final _stockController = TextEditingController();
  final _videoController = TextEditingController();
  
  // State

  Rubro? _rubroSeleccionado;
  Categoria? _categoriaSeleccionada;
  List<Rubro> _rubros = [];
  List<Categoria> _todasCategorias = [];
  bool _isLoading = false;
  bool _isInicializando = true;
  
  // Galería de Imágenes (Multi-Upload Asíncrono)
  final List<Map<String, dynamic>> _gallerySlots = []; // { 'url': String?, 'isUploading': bool, 'fileName': String? }
  
  // Atributos dinamicos
  List<Atributo> _todosLosAtributos = [];
  final List<ProductoAtributo> _atributosSeleccionados = [];

  // Design System El Guia YA
  static const Color _azulProfundo = Color(0xFF001F3F);
  static const Color _naranjaVibrante = Color(0xFF00E676);
  static const Color _grisFondo = Color(0xFFF4F7F6);
  static const Color _blancoPuro = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _nombreController.addListener(_ejecutarSugerenciaIA);
  }

  void _ejecutarSugerenciaIA() {
    final text = _nombreController.text.toLowerCase();
    if (text.length < 3) return;

    // Lógica Predictiva (AI Mock)
    Rubro? rubroSugerido;
    Categoria? catSugerida;

    if (text.contains('caña') || text.contains('reel') || text.contains('multifilamento') || text.contains('shimano') || text.contains('spinning')) {
      rubroSugerido = _rubros.firstWhere((r) => r.nombre.toLowerCase().contains('pesca'), orElse: () => _rubros.first);
      if (text.contains('caña')) {
        catSugerida = _todasCategorias.firstWhere((c) => c.nombre.toLowerCase().contains('caña'), orElse: () => Categoria.empty());
      } else if (text.contains('reel')) {
        catSugerida = _todasCategorias.firstWhere((c) => c.nombre.toLowerCase().contains('reel'), orElse: () => Categoria.empty());
      }
    } else if (text.contains('carpa') || text.contains('mochila') || text.contains('bolsa') || text.contains('camping')) {
      rubroSugerido = _rubros.firstWhere((r) => r.nombre.toLowerCase().contains('camping'), orElse: () => _rubros.first);
    }

    if (rubroSugerido != null && _rubroSeleccionado != rubroSugerido) {
      setState(() {
        _rubroSeleccionado = rubroSugerido;
        if (catSugerida != null && catSugerida.id.isNotEmpty) {
          _categoriaSeleccionada = catSugerida;
        }
        _actualizarAtributosPorRubro();
      });
    }
  }

  void _actualizarAtributosPorRubro() {
    if (_rubroSeleccionado == null) return;
    
    // Si es PESCA, inyectamos campos técnicos automáticamente
    if (_rubroSeleccionado!.nombre.toLowerCase().contains('pesca')) {
      final technicalKeys = ['Rulemanes', 'Acción', 'Libra', 'Material', 'Tramos'];
      
      for (var key in technicalKeys) {
        final def = _todosLosAtributos.firstWhere(
          (a) => a.nombre.toLowerCase() == key.toLowerCase(),
          orElse: () => Atributo.empty(),
        );
        
        if (def.id.isNotEmpty && !_atributosSeleccionados.any((a) => a.atributoId == def.id)) {
          _atributosSeleccionados.add(ProductoAtributo(
            id: '',
            productoId: '',
            atributoId: def.id,
            valor: '',
            detalle: def,
          ));
        }
      }
    }
  }

  @override
  void dispose() {
    _nombreController.removeListener(_ejecutarSugerenciaIA);
    _nombreController.dispose();
    _descripcionController.dispose();
    _precioController.dispose();
    _stockController.dispose();
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    try {
      final results = await Future.wait([
        SupabaseService.getRubros(),
        SupabaseService.getCategorias(),
      ]);
      
      setState(() {
        _rubros = results[0] as List<Rubro>;
        _todasCategorias = results[1] as List<Categoria>;
        _isInicializando = false;
      });
      _cargarAtributosDiccionario();
    } catch (e) {
      setState(() => _isInicializando = false);
      _mostrarNotificacion('Error al cargar datos: $e', isError: true);
    }
  }

  void _mostrarNotificacion(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickAndUploadImage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        if (index == _gallerySlots.length) {
          _gallerySlots.add({'url': null, 'isUploading': true, 'fileName': pickedFile.name});
        } else {
          _gallerySlots[index] = {'url': null, 'isUploading': true, 'fileName': pickedFile.name};
        }
      });

      try {
        String? url;
        url = await StorageService.uploadProductImage(
          file: pickedFile,
          folder: 'catalogo',
          prefix: 'galeria',
        );

        setState(() {
          _gallerySlots[index] = {
            'url': url,
            'isUploading': false,
            'fileName': pickedFile.name,
          };
        });
      } catch (e) {
        setState(() => _gallerySlots.removeAt(index));
        _mostrarNotificacion('Error al subir: $e', isError: true);
      }
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoriaSeleccionada == null) {
      _mostrarNotificacion('Debes seleccionar una categoria', isError: true);
      return;
    }
    
    final validImages = _gallerySlots.where((s) => s['url'] != null).toList();
    if (validImages.isEmpty) {
      _mostrarNotificacion('Debes subir al menos una imagen del producto', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String finalImageUrl = validImages.first['url'] as String;
      final List<String> galeria = validImages.map((s) => s['url'] as String).toList();

      final producto = Producto(
        id: '', // Se genera en DB
        nombre: _nombreController.text.trim(),
        descripcion: _descripcionController.text.trim(),
        precio: double.tryParse(_precioController.text) ?? 0.0,
        stock: int.tryParse(_stockController.text) ?? 0,
        rubro: _rubroSeleccionado?.nombre ?? '',
        categoriaId: _categoriaSeleccionada?.id ?? '',
        imagenUrl: finalImageUrl,
        galeriaUrls: galeria,
        videoUrl: _videoController.text.trim(),
        activo: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        rubroId: _rubroSeleccionado?.id,
        vendedorId: SupabaseService.currentUserId, // Vincular con el usuario logueado
      );

      final savedId = await SupabaseService.guardarProducto(producto);

      // GUARDAR ATRIBUTOS (Relacional)
      if (_atributosSeleccionados.isNotEmpty) {
        final List<Map<String, dynamic>> attrData = _atributosSeleccionados
            .where((a) => a.atributoId.isNotEmpty) // Filtro de seguridad
            .map((a) => {
          'producto_id': savedId,
          'atributo_id': a.atributoId,
          'valor': a.valor,
        }).toList();
        
        if (attrData.isNotEmpty) {
          await SupabaseService.supabase.from('producto_atributos').insert(attrData);
        }
      }

      if (mounted) {
        _mostrarNotificacion('¡Producto publicado exitosamente!');
        Navigator.pop(context); // Volver al catalogo
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarNotificacion('Error al guardar: $e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grisFondo,
      appBar: AppBar(
        title: const Text('PUBLICAR ARTICULO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        backgroundColor: _azulProfundo,
        foregroundColor: _blancoPuro,
        elevation: 0,
      ),
      body: _isInicializando 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 32),
                  
                  _buildImagePickerSection(),
                  const SizedBox(height: 32),
                  
                  _buildCategorizacionSection(),
                  const SizedBox(height: 32),
                  
                  _buildDetallesSection(),
                  const SizedBox(height: 32),

                  _buildMultimediaSection(),
                  const SizedBox(height: 32),
                  
                  _buildAtributosTecnicosSection(),
                  const SizedBox(height: 40),
                  
                  _buildPublishButton(),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Nuevo Articulo para el Catalogo', 
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _azulProfundo)),
        const SizedBox(height: 8),
        Text('Completa los detalles para que los pescadores puedan encontrar tu producto.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildImagePickerSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('GALERÍA DE MEDIOS (Carga Directa)', style: TextStyle(fontWeight: FontWeight.bold, color: _azulProfundo, fontSize: 12)),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _gallerySlots.length + 1,
          itemBuilder: (context, index) {
            if (index == _gallerySlots.length) {
              return _buildAddSlot();
            }
            return _buildUploadSlot(index);
          },
        ),
      ],
    );
  }

  Widget _buildAddSlot() {
    return GestureDetector(
      onTap: () => _pickAndUploadImage(_gallerySlots.length),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: const Icon(Icons.add_a_photo_outlined, color: _naranjaVibrante),
      ),
    );
  }

  Widget _buildUploadSlot(int index) {
    final slot = _gallerySlots[index];
    final isUploading = slot['isUploading'] as bool;
    final url = slot['url'] as String?;
    final fileName = slot['fileName'] as String?;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: url != null ? _naranjaVibrante : Colors.grey.shade300),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isUploading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : url != null
                    ? Image.network(url, fit: BoxFit.cover, width: double.infinity, height: double.infinity)
                    : const Center(child: Icon(Icons.image, color: Colors.grey)),
          ),
        ),
        if (fileName != null)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
              color: Colors.black54,
              child: Text(
                fileName,
                style: const TextStyle(color: Colors.white, fontSize: 6),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (url != null)
          const Positioned(
            top: 2,
            right: 2,
            child: Icon(Icons.check_circle, color: _naranjaVibrante, size: 16),
          ),
        Positioned(
          top: 0,
          left: 0,
          child: GestureDetector(
            onTap: () => setState(() => _gallerySlots.removeAt(index)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close, color: Colors.white, size: 10),
            ),
          ),
        ),
      ],
    );
  }



  Widget _buildCategorizacionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('CATEGORIZACION', style: TextStyle(fontWeight: FontWeight.bold, color: _azulProfundo, fontSize: 12)),
        const SizedBox(height: 16),
        
        // Selector de Rubro
        DropdownButtonFormField<Rubro>(
          initialValue: _rubroSeleccionado,
          decoration: _inputStyle('Rubro Principal', Icons.category),
          items: _rubros.map((r) => DropdownMenuItem(value: r, child: Text(r.nombreLegible))).toList(),
          onChanged: (val) {
            setState(() {
              _rubroSeleccionado = val;
              _categoriaSeleccionada = null; // Reset al cambiar rubro
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Selector de Categoria Hierarquica
        _buildHierarchicalCategorySelector(),
      ],
    );
  }

  Widget _buildHierarchicalCategorySelector() {
    final categoriasFiltradas = _todasCategorias.where((c) => 
      _rubroSeleccionado == null || c.rubroId == _rubroSeleccionado!.id
    ).toList();

    // Agrupar por padres
    final parents = categoriasFiltradas.where((c) => c.parentId == null).toList();

    return DropdownButtonFormField<Categoria>(
      initialValue: _categoriaSeleccionada,
      isExpanded: true,
      decoration: _inputStyle('Categoria / Subcategoria', Icons.account_tree),
      items: [
        for (var parent in parents) ...[
          // Item de Categoria Padre (Negrita)
          DropdownMenuItem<Categoria>(
            value: parent,
            child: Text(parent.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          // Subcategorias
          ...categoriasFiltradas.where((c) => c.parentId == parent.id).map((sub) => 
            DropdownMenuItem<Categoria>(
              value: sub,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Text('+ ${sub.nombre}', style: TextStyle(color: Colors.grey.shade700)),
              ),
            )
          ),
        ]
      ],
      onChanged: (val) => setState(() => _categoriaSeleccionada = val),
      validator: (val) => val == null ? 'Seleccione una categoria' : null,
    );
  }

  Widget _buildDetallesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('DETALLES DEL PRODUCTO', style: TextStyle(fontWeight: FontWeight.bold, color: _azulProfundo, fontSize: 12)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nombreController,
          decoration: _inputStyle('Nombre del Producto', Icons.shopping_bag),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'El nombre es requerido';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descripcionController,
          decoration: _inputStyle('Descripción', Icons.description),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'La descripción es requerida';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _precioController,
                decoration: _inputStyle('Precio (\$)', Icons.attach_money),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El precio es requerido';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Precio inválido';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _stockController,
                decoration: _inputStyle('Stock disponible', Icons.inventory),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El stock es requerido';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Stock inválido';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMultimediaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('MULTIMEDIA Y LINKS', style: TextStyle(fontWeight: FontWeight.bold, color: _azulProfundo, fontSize: 12)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _videoController,
          decoration: _inputStyle('URL de Video (YouTube/Vimeo)', Icons.play_circle_fill),
        ),
        const SizedBox(height: 8),
        Text('Pega aquí el link del video demostrativo para que los clientes puedan verlo.',
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
      ],
    );
  }

  Widget _buildPublishButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _guardarProducto,
        style: ElevatedButton.styleFrom(
          backgroundColor: _azulProfundo,
          foregroundColor: _blancoPuro,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 8,
          shadowColor: _azulProfundo.withOpacity(0.4),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: _blancoPuro)
          : const Text('PUBLICAR AHORA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2)),
      ),
    );
  }

  Future<void> _cargarAtributosDiccionario() async {
    try {
      final res = await SupabaseService.supabase.from('atributos').select().order('nombre');
      setState(() {
        _todosLosAtributos = List<Atributo>.from(res.map((x) => Atributo.fromSupabase(x)));
      });
    } catch (e) {
      debugPrint('Error cargando diccionario: $e');
    }
  }

  Widget _buildAtributosTecnicosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('FICHA TÉCNICA (ATRIBUTOS)', style: TextStyle(fontWeight: FontWeight.bold, color: _azulProfundo, fontSize: 12)),
            SafeTextIconButton(
  onPressed: _mostrarSelectorAtributos,
  icon: Icons.add_circle_outline,
  iconSize: 16,
  label: 'AÑADIR',
  textStyle: TextStyle(fontSize: 12),
),
          ],
        ),
        const SizedBox(height: 8),
        if (_atributosSeleccionados.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
            child: const Center(child: Text('No hay especificaciones técnicas añadidas.', style: TextStyle(fontSize: 12, color: Colors.grey))),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _atributosSeleccionados.length,
            itemBuilder: (context, index) {
              final attr = _atributosSeleccionados[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(attr.detalle?.nombre ?? 'Atributo', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  subtitle: TextFormField(
                    initialValue: attr.valor,
                    onChanged: (val) => attr.valor = val,
                    decoration: const InputDecoration(hintText: 'Valor (ej: 7+1, Fast, Grafito)', border: InputBorder.none, isDense: true),
                    style: const TextStyle(fontSize: 14),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                    onPressed: () => setState(() => _atributosSeleccionados.removeAt(index)),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  void _mostrarSelectorAtributos() {
    if (_rubroSeleccionado == null) {
      _mostrarNotificacion('Primero selecciona un rubro para ver los atributos correspondientes', isError: true);
      return;
    }

    // Filtrar atributos que pertenezcan al rubro seleccionado o que no tengan rubro asignado (generales)
    final atributosFiltrados = _todosLosAtributos.where((a) => 
      a.rubroId == null || a.rubroId == _rubroSeleccionado!.id
    ).toList();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Atributos para ${_rubroSeleccionado!.nombre}', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: atributosFiltrados.length,
              itemBuilder: (context, index) {
                final def = atributosFiltrados[index];
                final exists = _atributosSeleccionados.any((a) => a.atributoId == def.id);
                
                return ListTile(
                  enabled: !exists,
                  title: Text(def.nombre),
                  subtitle: Text(def.unidad ?? 'Sin unidad'),
                  trailing: exists ? const Icon(Icons.check_circle, color: Colors.green) : null,
                  onTap: () {
                    setState(() {
                      _atributosSeleccionados.add(ProductoAtributo(
                        id: '',
                        productoId: '',
                        atributoId: def.id,
                        valor: '',
                        detalle: def,
                      ));
                    });
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _azulProfundo, size: 20),
      filled: true,
      fillColor: _blancoPuro,
      labelStyle: const TextStyle(color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _naranjaVibrante, width: 2)),
    );
  }
}
