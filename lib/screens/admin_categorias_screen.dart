import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/categoria.dart';
import '../models/rubro.dart';
import '../services/supabase_service.dart';
import '../widgets/failsafe_background.dart';
import 'dart:ui' as ui;

class AdminCategoriasScreen extends StatefulWidget {
  const AdminCategoriasScreen({super.key});

  @override
  State<AdminCategoriasScreen> createState() => _AdminCategoriasScreenState();
}

class _AdminCategoriasScreenState extends State<AdminCategoriasScreen> {
  List<Categoria> _allCategorias = [];
  List<Rubro> _rubros = [];
  bool _isLoading = true;
  final _busquedaController = TextEditingController();
  String _filtroBusqueda = '';

  // Branding config
  String? _backgroundUrl;
  final double _opacity = 0.5;
  final double _brightness = 1.0;
  final Color _azulVibrante = const Color(0xFF0066FF);

  // Diseño Premium CapitanYA
  static const Color _capitanAzul = Color(0xFF001F3F);
  static const Color _capitanNaranja = Color(0xFF00E676);
  static const Color _capitanAzulClaro = Color(0xFF7FDBFF);
  static const Color _capitanGris = Color(0xFFDDDDDD);
  static const Color _capitanBlanco = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }



  Future<void> _cargarDatos() async {
    try {
      setState(() => _isLoading = true);
      
      // Carga paralela para mayor velocidad
      final results = await Future.wait([
        SupabaseService.getCategorias(),
        SupabaseService.getRubros(),
      ]);
      
      if (mounted) {
        setState(() {
          _allCategorias = results[0] as List<Categoria>;
          _rubros = results[1] as List<Rubro>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _mostrarNotificacion('Error al cargar datos: $e', isError: true);
      }
    }
  }

  void _mostrarNotificacion(String mensaje, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // Filtrar categorias jerarquicamente
  List<Categoria> get _categoriasPrincipales {
    return _allCategorias.where((c) {
      final matchesSearch = c.nombre.toLowerCase().contains(_filtroBusqueda.toLowerCase());
      return c.parentId == null && (_filtroBusqueda.isEmpty || matchesSearch || _tieneHijosQueCoinciden(c));
    }).toList();
  }

  bool _tieneHijosQueCoinciden(Categoria parent) {
    return _allCategorias.any((c) => 
      c.parentId == parent.id && 
      c.nombre.toLowerCase().contains(_filtroBusqueda.toLowerCase())
    );
  }

  List<Categoria> _getHijos(String parentId) {
    return _allCategorias.where((c) => 
      c.parentId == parentId && 
      (_filtroBusqueda.isEmpty || c.nombre.toLowerCase().contains(_filtroBusqueda.toLowerCase()))
    ).toList();
  }

  void _mostrarFormularioCategoria({Categoria? categoria, String? parentId}) {
    final isEditing = categoria != null;
    final nombreController = TextEditingController(text: isEditing ? categoria.nombre : '');
    final descripcionController = TextEditingController(text: isEditing ? categoria.descripcion : '');
    bool isActiva = isEditing ? categoria.activa : true;
    
    // Si estamos editando, usamos su rubro. Si es nueva subcategoria, heredamos del padre.
    String? defaultRubroId;
    if (isEditing) {
      defaultRubroId = categoria.rubroId;
    } else if (parentId != null) {
      defaultRubroId = _allCategorias.where((c) => c.id == parentId).firstOrNull?.rubroId;
    }
    
    String? rubroSeleccionado = defaultRubroId ?? (_rubros.isNotEmpty ? _rubros.first.id : null);
    String? parentSeleccionado = isEditing ? categoria.parentId : parentId;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEditing ? 'Editar Categoria' : (parentId != null ? 'Nueva Subcategoria' : 'Nueva Categoria'),
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _capitanAzul),
                ),
                const SizedBox(height: 24),
                
                TextField(
                  controller: nombreController,
                  decoration: _inputDecoration('Nombre de la categoria *', Icons.label_outline),
                ),
                const SizedBox(height: 16),
                
                TextField(
                  controller: descripcionController,
                  maxLines: 2,
                  decoration: _inputDecoration('Descripcion (opcional)', Icons.description_outlined),
                ),
                const SizedBox(height: 16),
                
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: rubroSeleccionado,
                        decoration: _inputDecoration('Rubro', Icons.category_outlined),
                        items: _rubros.map((r) => DropdownMenuItem(value: r.id, child: Text(r.nombre))).toList(),
                        onChanged: (val) => setDialogState(() => rubroSeleccionado = val),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                DropdownButtonFormField<String?>(
                  initialValue: parentSeleccionado,
                  decoration: _inputDecoration('Depende de (Padre)', Icons.account_tree_outlined),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('Categoria Principal')),
                    ..._allCategorias
                        .where((c) => c.parentId == null && c.id != categoria?.id)
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.nombre))),
                  ],
                  onChanged: (val) => setDialogState(() => parentSeleccionado = val),
                ),
                const SizedBox(height: 16),
                
                SwitchListTile(
                  title: const Text('Visible en App', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Si se desactiva, los pescadores no podran verla'),
                  value: isActiva,
                  activeThumbColor: _capitanNaranja,
                  onChanged: (val) => setDialogState(() => isActiva = val),
                ),
                const SizedBox(height: 32),
                
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      if (nombreController.text.trim().isEmpty) {
                        _mostrarNotificacion('El nombre es requerido', isError: true);
                        return;
                      }
                      
                      setDialogState(() => isSaving = true);
                      
                      try {
                        final newCat = Categoria(
                          id: isEditing ? categoria.id : '',
                          nombre: nombreController.text.trim(),
                          descripcion: descripcionController.text.trim(),
                          activa: isActiva,
                          rubroId: rubroSeleccionado,
                          parentId: parentSeleccionado,
                          createdAt: isEditing ? categoria.createdAt : DateTime.now(),
                          updatedAt: DateTime.now(),
                        );
                        
                        if (isEditing) {
                          await SupabaseService.actualizarCategoria(newCat);
                        } else {
                          await SupabaseService.guardarCategoria(newCat);
                        }
                        
                        if (mounted) {
                          Navigator.pop(context);
                          _cargarDatos();
                          _mostrarNotificacion(isEditing ? 'Categoria actualizada' : 'Categoria creada');
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        _mostrarNotificacion('Error al guardar: $e', isError: true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _capitanAzul,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    child: isSaving 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(isEditing ? 'GUARDAR CAMBIOS' : 'CREAR CATEGORIA', style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _capitanAzul),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _capitanAzul, width: 2)),
      filled: true,
      fillColor: Colors.grey.shade50,
    );
  }

  Future<void> _eliminarCategoria(Categoria cat) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar Categoria?'),
        content: Text('Esto eliminara "${cat.nombre}". Si tiene subcategorias o productos asociados, la operacion podria fallar por integridad.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ELIMINAR', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        setState(() => _isLoading = true);
        await SupabaseService.eliminarCategoria(cat.id);
        _cargarDatos();
        _mostrarNotificacion('Categoria eliminada correctamente');
      } catch (e) {
        setState(() => _isLoading = false);
        _mostrarNotificacion('No se pudo eliminar: $e', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      body: FailsafeBackground(
        imageUrl: null, // Forzamos fondo solido para administracion
        opacity: 1.0,
        overlayColor: _capitanAzul,
        brightness: 1.0,
        child: CustomScrollView(
          slivers: [
            // AppBar Premium con Estilo Cristal
            SliverAppBar(
              expandedHeight: 180,
              floating: false,
              pinned: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: const Text('CATEGORÍAS', 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 2.5, color: Colors.white)),
                centerTitle: true,
                background: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 80, left: 24, right: 24),
                      child: _buildSearchBar(),
                    ),
                  ],
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_circle, color: _capitanNaranja, size: 32),
                  onPressed: () => _mostrarFormularioCategoria(),
                ),
                const SizedBox(width: 12),
              ],
            ),
            
            // Cuerpo de la lista
            SliverToBoxAdapter(
              child: _isLoading 
                ? const Padding(padding: EdgeInsets.only(top: 100), child: Center(child: CircularProgressIndicator(color: _capitanNaranja)))
                : _categoriasPrincipales.isEmpty
                    ? _buildEmptyState()
                    : const SizedBox.shrink(),
            ),
            
            if (!_isLoading)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final cat = _categoriasPrincipales[index];
                      return _buildCategoryTree(cat);
                    },
                    childCount: _categoriasPrincipales.length,
                  ),
                ),
              ),
              
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: TextField(
            controller: _busquedaController,
            onChanged: (val) => setState(() => _filtroBusqueda = val),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar categorias o subcategorias...',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: Colors.white),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTree(Categoria parent) {
    final hijos = _getHijos(parent.id);
    
    return Column(
      children: [
        _buildCategoryCard(parent, isParent: true),
        if (hijos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 30),
            child: Column(
              children: hijos.map((hijo) => _buildCategoryCard(hijo, isParent: false)).toList(),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCategoryCard(Categoria cat, {required bool isParent}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            decoration: BoxDecoration(
              color: isParent 
                  ? Colors.white.withOpacity(0.12) 
                  : Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isParent 
                    ? Colors.white.withOpacity(0.3) 
                    : Colors.white.withOpacity(0.15),
                width: isParent ? 1.5 : 0.8,
              ),
              boxShadow: [
                if (isParent)
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (cat.activa ? (isParent ? _capitanNaranja : _capitanAzulClaro) : Colors.grey).withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (cat.activa ? (isParent ? _capitanNaranja : _capitanAzulClaro) : Colors.grey).withOpacity(0.4),
                  ),
                ),
                child: Icon(
                  isParent ? Icons.category : Icons.subdirectory_arrow_right, 
                  color: cat.activa ? (isParent ? _capitanNaranja : _capitanAzulClaro) : Colors.grey,
                  size: 24,
                ),
              ),
              title: Text(
                cat.nombre.toUpperCase(), 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  color: Colors.white,
                  letterSpacing: 1.1,
                  fontSize: isParent ? 16 : 14,
                )
              ),
              subtitle: Text(
                cat.descripcion.isNotEmpty ? cat.descripcion : 'Sin descripcion', 
                maxLines: 1, 
                overflow: TextOverflow.ellipsis, 
                style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.6))
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.visibility, color: Colors.white70, size: 22),
                    onPressed: () {
                      final url = '/categoria?id=${cat.id}';
                      Navigator.pushNamed(context, url);
                    },
                    tooltip: 'Ver Página Publicada',
                  ),
                  IconButton(
                    icon: const Icon(Icons.link, color: _capitanAzulClaro, size: 22),
                    onPressed: () {
                      final url = 'http://localhost:8080/#/categoria?id=${cat.id}';
                      Clipboard.setData(ClipboardData(text: url));
                      _mostrarNotificacion('Link de categoría copiado');
                    },
                    tooltip: 'Copiar Link Público',
                  ),
                  if (isParent)
                    IconButton(
                      icon: const Icon(Icons.add_box_rounded, color: Colors.greenAccent, size: 26),
                      onPressed: () => _mostrarFormularioCategoria(parentId: cat.id),
                      tooltip: 'Agregar Subcategoria',
                    ),
                  IconButton(
                    icon: const Icon(Icons.edit_note_rounded, color: Colors.white70, size: 26),
                    onPressed: () => _mostrarFormularioCategoria(categoria: cat),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 26),
                    onPressed: () => _eliminarCategoria(cat),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          Icon(Icons.category_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No se encontraron categorias', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
          if (_filtroBusqueda.isNotEmpty)
            TextButton(
              onPressed: () => setState(() {
                _busquedaController.clear();
                _filtroBusqueda = '';
              }),
              child: const Text('Limpiar busqueda'),
            ),
        ],
      ),
    );
  }
}
