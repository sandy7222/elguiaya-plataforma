import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';

class CapitanVidrieraScreen extends StatefulWidget {
  const CapitanVidrieraScreen({super.key});

  @override
  State<CapitanVidrieraScreen> createState() => _CapitanVidrieraScreenState();
}

class _CapitanVidrieraScreenState extends State<CapitanVidrieraScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _productos = [];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('kiosko_capitan')
          .select('*')
          .eq('capitan_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _productos = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar la vidriera: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleActivo(String id, bool actual) async {
    try {
      await _supabase.from('kiosko_capitan').update({'activo': !actual}).eq('id', id);
      _cargarProductos(); // Recargar para mostrar el cambio
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar estado: $e')));
      }
    }
  }

  Future<void> _eliminarProducto(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: const Text('¿Estás seguro que deseas eliminar este producto de tu vidriera?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('kiosko_capitan').delete().eq('id', id);
        _cargarProductos();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
        }
      }
    }
  }

  void _abrirModalCrear() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FormularioProducto(onGuardado: _cargarProductos),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Mi Vidriera 🏪', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _productos.isEmpty
              ? _buildEmptyState()
              : _buildListaProductos(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirModalCrear,
        backgroundColor: const Color(0xFF00E676),
        icon: const Icon(Icons.add_a_photo_rounded, color: Colors.white),
        label: const Text('Publicar Producto', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_rounded, size: 100, color: Colors.grey.shade400),
          const SizedBox(height: 20),
          const Text('Tu vidriera está vacía', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Publica leña, carnada, o alojamiento. Los pescadores lo verán al confirmar su viaje.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListaProductos() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _productos.length,
      itemBuilder: (context, index) {
        final p = _productos[index];
        final bool activo = p['activo'] ?? true;
        final String imagen = p['imagen_url'] ?? '';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 3,
          child: Opacity(
            opacity: activo ? 1.0 : 0.6,
            child: Row(
              children: [
                // Imagen del producto
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
                    color: Colors.grey.shade200,
                    image: imagen.isNotEmpty
                        ? DecorationImage(image: NetworkImage(imagen), fit: BoxFit.cover)
                        : null,
                  ),
                  child: imagen.isEmpty ? const Icon(Icons.image_not_supported, color: Colors.grey) : null,
                ),
                // Detalles
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(p['categoria'] ?? 'Extra', style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold)),
                            ),
                            Switch(
                              value: activo,
                              onChanged: (v) => _toggleActivo(p['id'], p['activo']),
                              activeColor: const Color(0xFF00E676),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(p['nombre_producto'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Text('\$${p['precio']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1))),
                      ],
                    ),
                  ),
                ),
                // Acciones
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _eliminarProducto(p['id']),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FormularioProducto extends StatefulWidget {
  final VoidCallback onGuardado;
  const _FormularioProducto({required this.onGuardado});

  @override
  State<_FormularioProducto> createState() => _FormularioProductoState();
}

class _FormularioProductoState extends State<_FormularioProducto> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();
  String _categoria = 'Carnada';
  XFile? _imagenFile;
  bool _guardando = false;

  String? _validarContacto(String? value) {
    if (value == null || value.isEmpty) return null;

    final cleanValue = value.toLowerCase();

    // Detectar @ o #
    if (cleanValue.contains('@') || cleanValue.contains('#')) {
      return 'No se permiten @, # o datos de contacto.';
    }

    // Detectar palabras de redes sociales o contacto
    final forbiddenWords = [
      'facebook', 'face', 'fb', 'instagram', 'insta', 'ig',
      'whatsapp', 'wathsapp', 'watsapp', 'watsap', 'whats', 'wsp', 'whastapp',
      'telefono', 'teléfono', 'celular', 'cel', 'contacto', 'llamar', 'llamadas',
      'correo', 'email', 'mail'
    ];

    for (final word in forbiddenWords) {
      final regex = RegExp('\\b$word\\b', caseSensitive: false);
      if (regex.hasMatch(cleanValue)) {
        return 'No se permiten redes sociales ni datos de contacto.';
      }
    }

    // Detectar números de teléfono (7 o más dígitos consecutivos o separados por espacios/guiones)
    final phoneRegex = RegExp(r'(?:\d[\s-]*){7,}');
    if (phoneRegex.hasMatch(cleanValue)) {
      return 'No se permiten números de teléfono.';
    }

    return null;
  }

  Future<void> _seleccionarImagen() async {
    final XFile? image = await StorageService.pickImageFromGallery();
    if (image != null) {
      setState(() => _imagenFile = image);
    }
  }

  Future<void> _guardarProducto() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imagenFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Es obligatorio subir una foto de lo que vendes.')));
      return;
    }

    setState(() => _guardando = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('No autenticado');

      // 1. Subir imagen
      final imageUrl = await StorageService.uploadProductImage(
        file: _imagenFile!,
        folder: userId,
        prefix: 'vidriera',
      );

      // 2. Insertar en DB
      await Supabase.instance.client.from('kiosko_capitan').insert({
        'capitan_id': userId,
        'nombre_producto': _nombreCtrl.text.trim(),
        'descripcion': _descCtrl.text.trim(),
        'precio': double.parse(_precioCtrl.text),
        'categoria': _categoria,
        'imagen_url': imageUrl,
        'activo': true,
      });

      if (mounted) {
        widget.onGuardado();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Producto publicado en tu vidriera!'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        top: 20,
        left: 20,
        right: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Nuevo Producto / Servicio', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1)), textAlign: TextAlign.center),
              const SizedBox(height: 20),
              
              // Selector de Imagen
              GestureDetector(
                onTap: _seleccionarImagen,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.grey.shade300, width: 2, style: BorderStyle.solid),
                  ),
                  child: _imagenFile == null
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text('Tocar para subir foto', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                          ],
                        )
                      : const Center(child: Text('✅ Foto seleccionada (se subirá al guardar)', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                ),
              ),
              const SizedBox(height: 20),

              // Campos de texto
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _categoria,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: 'Categoría', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      items: ['Carnada', 'Leña', 'Comida/Bebida', 'Alojamiento', 'Otro'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _categoria = v!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _precioCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Precio (\$)', prefixText: '\$ ', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                      validator: (v) => v == null || v.isEmpty ? 'Falta el precio' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nombreCtrl,
                decoration: InputDecoration(labelText: 'Nombre del Producto (Ej: Docena de Morenas)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Obligatorio';
                  return _validarContacto(v);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: InputDecoration(labelText: 'Descripción corta (Opcional)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                maxLines: 2,
                validator: _validarContacto,
              ),
              const SizedBox(height: 24),
              
              ElevatedButton(
                onPressed: _guardando ? null : _guardarProducto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _guardando 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Publicar en mi Vidriera', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
