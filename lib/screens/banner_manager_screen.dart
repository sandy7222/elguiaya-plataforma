
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/banner_promo.dart';
import '../models/categoria.dart';
import '../models/producto.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class BannerManagerScreen extends StatefulWidget {
  const BannerManagerScreen({super.key});

  @override
  State<BannerManagerScreen> createState() => _BannerManagerScreenState();
}

class _BannerManagerScreenState extends State<BannerManagerScreen>
    with AutomaticKeepAliveClientMixin {
  List<BannerPromo> _banners = [];
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarBanners();
  }

  Future<void> _cargarBanners() async {
    try {
      setState(() => _isLoading = true);
      final banners = await SupabaseService.getAllBanners();
      setState(() {
        _banners = banners;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar banners: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleBannerEstado(String bannerId, bool nuevoEstado) async {
    try {
      await SupabaseService.toggleBannerEstado(bannerId, nuevoEstado);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Banner ${nuevoEstado ? 'activado' : 'desactivado'}')),
          backgroundColor: Colors.green,
        ),
      );
      _cargarBanners();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Error al cambiar estado: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _eliminarBanner(String bannerId, String imageUrl) async {
    try {
      // Eliminar imagen del storage
      await StorageService.deleteBannerImage(imageUrl);
      
      // Eliminar banner de la base de datos
      await SupabaseService.eliminarBanner(bannerId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Banner eliminado correctamente')),
          backgroundColor: Colors.green,
        ),
      );
      
      _cargarBanners();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(child: Text('Error al eliminar banner: $e')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _mostrarFormularioBanner({BannerPromo? banner}) {
    showDialog(
      context: context,
      builder: (context) => _BannerFormDialog(
        banner: banner,
        onGuardar: (bannerGuardado) async {
          try {
            if (banner == null) {
              // Crear nuevo banner
              await SupabaseService.crearBanner(bannerGuardado);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Center(child: Text('Banner creado correctamente')),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              // Actualizar banner existente
              await SupabaseService.actualizarBanner(bannerGuardado);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Center(child: Text('Banner actualizado correctamente')),
                  backgroundColor: Colors.green,
                ),
              );
            }
            
            Navigator.pop(context);
            _cargarBanners();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Center(child: Text('Error al guardar banner: $e')),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _reordenarBanners() {
    showDialog(
      context: context,
      builder: (context) => _ReorderDialog(
        banners: List.from(_banners),
        onGuardar: (bannersOrdenados) async {
          try {
            final bannersData = bannersOrdenados.asMap().entries.map((entry) {
              return {
                'id': entry.value.id,
                'orden': entry.key,
              };
            }).toList();
            
            await SupabaseService.reordenarBanners(bannersData);
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Center(child: Text('Banners reordenados correctamente')),
                backgroundColor: Colors.green,
              ),
            );
            
            Navigator.pop(context);
            _cargarBanners();
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Center(child: Text('Error al reordenar banners: $e')),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Gestor de Banners',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _reordenarBanners,
            icon: const Icon(Icons.sort),
            tooltip: 'Reordenar',
          ),
          IconButton(
            onPressed: _cargarBanners,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _banners.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.image_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay banners configurados',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea tu primer banner para promocionar tus productos',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _mostrarFormularioBanner(),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear Banner'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D47A1),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _cargarBanners,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _banners.length,
                    itemBuilder: (context, index) {
                      return _buildBannerCard(_banners[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _mostrarFormularioBanner(),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBannerCard(BannerPromo banner) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen del banner con overlay de texto
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Stack(
              children: [
                // Imagen de fondo
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                     banner.imagenUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
                    ),
                  ),
                ),
                
                // Gradiente overlay para legibilidad
                Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
                
                // Textos superpuestos
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        banner.titulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        banner.subtitulo,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                
                // Badge de estado
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: banner.activo ? Colors.green[600] : Colors.red[600],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      banner.estadoFormateado,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Acciones del banner
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Informacion del banner
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Orden: ${banner.orden}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        'Creado: ${_formatDate(banner.createdAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Botones de accion
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _mostrarFormularioBanner(banner: banner),
                      icon: const Icon(Icons.edit),
                      color: const Color(0xFF0D47A1),
                      tooltip: 'Editar',
                    ),
                    IconButton(
                      onPressed: () => _toggleBannerEstado(banner.id, !banner.activo),
                      icon: Icon(banner.activo ? Icons.visibility_off : Icons.visibility),
                      color: banner.activo ? Colors.orange : Colors.green,
                      tooltip: banner.activo ? 'Desactivar' : 'Activar',
                    ),
                    IconButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Eliminar Banner'),
                            content: const Text('¿Esta seguro que quiere eliminar este banner?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancelar'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _eliminarBanner(banner.id, banner.imagenUrl);
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Eliminar'),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete),
                      color: Colors.red,
                      tooltip: 'Eliminar',
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

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

// Dialogo para formulario de banner
class _BannerFormDialog extends StatefulWidget {
  final BannerPromo? banner;
  final Function(BannerPromo) onGuardar;

  const _BannerFormDialog({
    this.banner,
    required this.onGuardar,
  });

  @override
  State<_BannerFormDialog> createState() => _BannerFormDialogState();
}

class _BannerFormDialogState extends State<_BannerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tituloController = TextEditingController();
  final _subtituloController = TextEditingController();
  int _orden = 0;
  bool _activo = true;
  String? _productoId;
  String? _categoriaId;
  File? _imagenFile;
  XFile? _xFileSeleccionado;
  Uint8List? _webBytes;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.banner != null) {
      _tituloController.text = widget.banner!.titulo;
      _subtituloController.text = widget.banner!.subtitulo;
      _orden = widget.banner!.orden;
      _activo = widget.banner!.activo;
      _productoId = widget.banner!.productId;
      _categoriaId = widget.banner!.categoriaId;
    }
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _subtituloController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _xFileSeleccionado = image;
            _webBytes = bytes;
          });
        } else {
          setState(() => _imagenFile = File(image.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al seleccionar imagen: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _tomarFoto() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          setState(() {
            _xFileSeleccionado = image;
            _webBytes = bytes;
          });
        } else {
          setState(() => _imagenFile = File(image.path));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al tomar foto: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildBannerPreview() {
    if (kIsWeb) {
      if (_webBytes != null) {
        return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.memory(_webBytes!, fit: BoxFit.cover));
      }
    } else {
      if (_imagenFile != null) {
        return ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_imagenFile!, fit: BoxFit.cover));
      }
    }

    if (widget.banner != null && widget.banner!.imagenUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
           widget.banner!.imagenUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[200],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.grey[200],
            child: const Center(child: Icon(Icons.error)),
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.image, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text('Sin imagen', style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_imagenFile == null && widget.banner == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Center(child: Text('Por favor, seleccione una imagen')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imagenUrl = widget.banner?.imagenUrl ?? '';
      
      // Si hay una nueva imagen, subirla
      if (_xFileSeleccionado != null || _imagenFile != null) {
        final bannerId = widget.banner?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
        imagenUrl = await StorageService.uploadAdminDocument(
          file: _xFileSeleccionado ?? _imagenFile,
          folder: 'admin_banners',
          prefix: 'banner_$bannerId',
        );
      }

      final banner = BannerPromo(
        id: widget.banner?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        titulo: _tituloController.text.trim(),
        subtitulo: _subtituloController.text.trim(),
        imagenUrl: imagenUrl,
        activo: _activo,
        orden: _orden,
        productId: _productoId,
        categoriaId: _categoriaId,
        createdAt: widget.banner?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      widget.onGuardar(banner);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al guardar: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.banner == null ? 'Crear Banner' : 'Editar Banner'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Vista previa de la imagen
                Container(
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildBannerPreview(),
                ),
                const SizedBox(height: 12),
                
                // Botones para seleccionar imagen
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _seleccionarImagen,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galeria'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _tomarFoto,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camara'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Campos de texto
                TextFormField(
                  controller: _tituloController,
                  decoration: InputDecoration(
                    labelText: 'Titulo *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  },
                  maxLength: 200,
                ),
                const SizedBox(height: 12),
                
                TextFormField(
                  controller: _subtituloController,
                  decoration: InputDecoration(
                    labelText: 'Subtitulo *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Requerido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Campo de orden y estado
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        initialValue: _orden.toString(),
                        decoration: InputDecoration(
                          labelText: 'Orden',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          _orden = int.tryParse(value) ?? 0;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          Switch(
                            value: _activo,
                            onChanged: (value) => setState(() => _activo = value),
                          ),
                          const SizedBox(width: 8),
                          const Text('Activo'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(),
                const Text('Vincular a (Opcional)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // Selectores de Producto y Categoria
                FutureBuilder<List<Categoria>>(
                  future: SupabaseService.getCategorias(),
                  builder: (context, snapshot) {
                    final cats = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: _categoriaId,
                      decoration: InputDecoration(
                        labelText: 'Vincular a Categoría',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Ninguna')),
                        ...cats.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))),
                      ],
                      onChanged: (val) => setState(() {
                        _categoriaId = val;
                        if (val != null) _productoId = null; // Reset product if category is selected
                      }),
                    );
                  },
                ),
                const SizedBox(height: 12),
                
                FutureBuilder<List<Producto>>(
                  future: SupabaseService.getProductos(),
                  builder: (context, snapshot) {
                    final prods = snapshot.data ?? [];
                    return DropdownButtonFormField<String?>(
                      initialValue: _productoId,
                      decoration: InputDecoration(
                        labelText: 'Vincular a Producto',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        prefixIcon: const Icon(Icons.shopping_bag_outlined),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Ninguno')),
                        ...prods.map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre))),
                      ],
                      onChanged: (val) => setState(() {
                        _productoId = val;
                        if (val != null) _categoriaId = null; // Reset category if product is selected
                      }),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _guardar,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// Dialogo para reordenar banners
class _ReorderDialog extends StatefulWidget {
  final List<BannerPromo> banners;
  final Function(List<BannerPromo>) onGuardar;

  const _ReorderDialog({
    required this.banners,
    required this.onGuardar,
  });

  @override
  State<_ReorderDialog> createState() => _ReorderDialogState();
}

class _ReorderDialogState extends State<_ReorderDialog> {
  late List<BannerPromo> _banners;

  @override
  void initState() {
    super.initState();
    _banners = List.from(widget.banners);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reordenar Banners'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: ReorderableListView.builder(
          itemCount: _banners.length,
          onReorder: (oldIndex, newIndex) {
            if (oldIndex < newIndex) {
              newIndex -= 1;
            }
            final banner = _banners.removeAt(oldIndex);
            _banners.insert(newIndex, banner);
            setState(() {});
          },
          itemBuilder: (context, index) {
            final banner = _banners[index];
            return Card(
              key: ValueKey(banner.id),
              margin: const EdgeInsets.symmetric(vertical: 2),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0D47A1),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(banner.titulo),
                subtitle: Text(banner.subtitulo),
                trailing: const Icon(Icons.drag_handle),
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onGuardar(_banners);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0D47A1),
            foregroundColor: Colors.white,
          ),
          child: const Text('Guardar Orden'),
        ),
      ],
    );
  }
}
