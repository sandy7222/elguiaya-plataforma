import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/articulo_blog.dart';
import '../models/producto.dart';
import '../services/news_compiler_service.dart';
import '../services/supabase_service.dart';
import '../services/storage_service.dart';
import '../services/speech_service.dart';
import '../services/groq_service.dart';
import 'package:intl/intl.dart';

class AdminBlogScreen extends StatefulWidget {
  const AdminBlogScreen({super.key});

  @override
  State<AdminBlogScreen> createState() => _AdminBlogScreenState();
}

class _AdminBlogScreenState extends State<AdminBlogScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Noticias encontradas
  List<Map<String, dynamic>> _noticiasEncontradas = [];
  bool _searchingNews = false;
  String _sourceType = 'web'; // 'web' o 'youtube'
  final TextEditingController _newsSearchController = TextEditingController(text: 'Paraná');

  // Buscador de artículos guardados
  final TextEditingController _blogSearchController = TextEditingController();
  String _blogSearchText = '';
  
  bool _isLoadingArticles = false;
  List<ArticuloBlog> _articulos = [];

  final List<String> _articleCategories = [
    'Todos',
    'Piques de la Semana',
    'Guías de Pesca',
    'Tutoriales',
    'Novedades',
    'Mis Salidas',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _cargarArticulos();
    _buscarNoticiasWeb();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newsSearchController.dispose();
    _blogSearchController.dispose();
    super.dispose();
  }

  Future<void> _cargarArticulos() async {
    setState(() {
      _isLoadingArticles = true;
    });
    try {
      final list = await SupabaseService.obtenerArticulosBlog(soloActivos: false);
      setState(() {
        _articulos = list;
        _isLoadingArticles = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingArticles = false;
      });
      _mostrarMensaje('Error al cargar artículos de Supabase.', esError: true);
    }
  }

  Future<void> _buscarNoticiasWeb() async {
    setState(() {
      _searchingNews = true;
    });
    try {
      final List<Map<String, dynamic>> list;
      if (_sourceType == 'youtube') {
        list = await NewsCompilerService.obtenerVideosRecientesYoutube(_newsSearchController.text);
      } else {
        list = await NewsCompilerService.obtenerNoticiasRecientesWeb(_newsSearchController.text);
      }
      setState(() {
        _noticiasEncontradas = list;
        _searchingNews = false;
      });
    } catch (e) {
      setState(() {
        _searchingNews = false;
      });
      _mostrarMensaje('Error al buscar información.', esError: true);
    }
  }

  Future<void> _cambiarEstadoActivo(ArticuloBlog art, bool nuevoEstado) async {
    final actualizado = ArticuloBlog(
      id: art.id,
      titulo: art.titulo,
      resumen: art.resumen,
      contenido: art.contenido,
      autor: art.autor,
      minutosLectura: art.minutosLectura,
      imagenPortada: art.imagenPortada,
      categoria: art.categoria,
      productosSugeridos: art.productosSugeridos,
      fuenteUrl: art.fuenteUrl,
      activo: nuevoEstado,
      createdAt: art.createdAt,
      updatedAt: DateTime.now(),
    );

    try {
      await SupabaseService.actualizarArticuloBlog(actualizado);
      _mostrarMensaje(nuevoEstado ? 'Artículo activado / publicado.' : 'Artículo desactivado a borrador.');
      _cargarArticulos();
    } catch (e) {
      _mostrarMensaje('No se pudo actualizar el estado del artículo.', esError: true);
    }
  }

  Future<void> _eliminarArticulo(String id) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: const Text('¿Eliminar artículo?', style: TextStyle(color: Colors.white)),
        content: const Text('Esta acción es irreversible y removerá el artículo del blog.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await SupabaseService.eliminarArticuloBlog(id);
        _mostrarMensaje('Artículo eliminado de forma permanente.');
        _cargarArticulos();
      } catch (e) {
        _mostrarMensaje('Error al eliminar el artículo.', esError: true);
      }
    }
  }

  Future<void> _generarConIA(Map<String, dynamic> noticia) async {
    // Mostrar overlay de carga con animación premium
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00E5FF)),
              const SizedBox(height: 20),
              Text(
                'Gu-IA está redactando...',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'Analizando reporte, estructurando markdown y sugiriendo productos de la tienda de forma inteligente.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final compilado = await NewsCompilerService.compilarArticuloConIA(
        tituloOriginal: noticia['titulo'],
        fragmentoOriginal: noticia['fragmento'],
        urlOriginal: noticia['url'],
        imagenOriginal: noticia['imagen'],
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader
      
      // Abrir formulario con los datos pre-cargados
      _abrirFormularioArticulo(compilado);
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Cerrar loader
      _mostrarMensaje('Error de IA al procesar la noticia. Abrir editor en blanco.', esError: true);
      _abrirFormularioArticulo(ArticuloBlog.empty());
    }
  }

  void _mostrarMensaje(String msg, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.redAccent : const Color(0xFF00E676),
      ),
    );
  }

  void _abrirModalSalidaPesca() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (context) {
        return _ModalSalidaPesca(
          alCompletar: (articulo) {
            _abrirFormularioArticulo(articulo);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBg = Color(0xFF0A0E12);
    const Color cyanColor = Color(0xFF00E5FF);
    const Color cardBg = Color(0xFF0F172A);

    return Scaffold(
      backgroundColor: darkBg,
      body: Stack(
        children: [
          // Fondo degradado
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A0E12), Color(0xFF020617), Color(0xFF0F172A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              'Panel de Blog',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                                foregroundColor: const Color(0xFF00E5FF),
                                side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              ),
                              icon: const Icon(Icons.record_voice_over, size: 15),
                              label: const Text('🎣 Mi Salida de Pesca', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              onPressed: () => _abrirModalSalidaPesca(),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: () {
                          if (_tabController.index == 0) {
                            _cargarArticulos();
                          } else {
                            _buscarNoticiasWeb();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                // Tabs
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      tabs: [
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.library_books_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Mis Artículos'),
                            ],
                          ),
                        ),
                        Tab(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.psychology_outlined, size: 16),
                              SizedBox(width: 8),
                              Text('Redactor Gu-IA'),
                            ],
                          ),
                        ),
                      ],
                      indicator: BoxDecoration(
                        color: cyanColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cyanColor.withValues(alpha: 0.3)),
                      ),
                      labelColor: cyanColor,
                      unselectedLabelColor: Colors.white54,
                      labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                      unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 13),
                      dividerColor: Colors.transparent,
                    ),
                  ),
                ),

                // TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Tab 1: Administrar mis artículos
                      _buildMisArticulosTab(cardBg, cyanColor),
                      
                      // Tab 2: Buscador e IA Generativa de noticias
                      _buildRedactorIATab(cardBg, cyanColor),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              backgroundColor: cyanColor,
              onPressed: () => _abrirFormularioArticulo(ArticuloBlog.empty()),
              child: const Icon(Icons.add, color: Colors.black),
            )
          : null,
    );
  }

  // --- WIDGET TAB 1: LISTADO Y CRUD ---
  Widget _buildMisArticulosTab(Color cardBg, Color cyanColor) {
    return Column(
      children: [
        // Buscador interno
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _blogSearchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              onChanged: (val) {
                setState(() {
                  _blogSearchText = val.toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Filtrar por título, autor o categoría...',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.4), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        Expanded(
          child: _isLoadingArticles
              ? Center(child: CircularProgressIndicator(color: cyanColor))
              : _articulos.isEmpty
                  ? Center(child: Text('No hay artículos cargados.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4))))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _articulos.length,
                      itemBuilder: (context, index) {
                        final art = _articulos[index];

                        // Filtrar
                        if (_blogSearchText.isNotEmpty) {
                          final match = art.titulo.toLowerCase().contains(_blogSearchText) ||
                              art.autor.toLowerCase().contains(_blogSearchText) ||
                              art.categoria.toLowerCase().contains(_blogSearchText);
                          if (!match) return const SizedBox.shrink();
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cardBg.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Row(
                            children: [
                              // Miniatura Portada
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  art.imagenPortada,
                                  height: 60,
                                  width: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    height: 60,
                                    width: 60,
                                    color: Colors.white10,
                                    child: const Icon(Icons.image, color: Colors.white38),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),

                              // Info del Artículo
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      art.titulo,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          art.categoria,
                                          style: TextStyle(color: cyanColor.withValues(alpha: 0.8), fontSize: 10, fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Por ${art.autor}',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Acciones
                              Column(
                                children: [
                                  Row(
                                    children: [
                                      // Switch Activo
                                      Switch(
                                        value: art.activo,
                                        activeThumbColor: const Color(0xFF00E676),
                                        onChanged: (val) => _cambiarEstadoActivo(art, val),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                                        onPressed: () => _abrirFormularioArticulo(art),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                        onPressed: () => _eliminarArticulo(art.id),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- WIDGET TAB 2: REDACTOR INTELIGENTE IA ---
  Widget _buildRedactorIATab(Color cardBg, Color cyanColor) {
    return Column(
      children: [
        // Selector de tipo de fuente (Web vs YouTube)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _sourceType = 'web';
                      _noticiasEncontradas = [];
                    });
                    _buscarNoticiasWeb();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _sourceType == 'web'
                          ? cyanColor.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sourceType == 'web'
                            ? cyanColor.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.language,
                          color: _sourceType == 'web' ? cyanColor : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Noticias Web',
                          style: TextStyle(
                            color: _sourceType == 'web' ? cyanColor : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    setState(() {
                      _sourceType = 'youtube';
                      _noticiasEncontradas = [];
                    });
                    _buscarNoticiasWeb();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _sourceType == 'youtube'
                          ? Colors.redAccent.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _sourceType == 'youtube'
                            ? Colors.redAccent.withValues(alpha: 0.3)
                            : Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_fill,
                          color: _sourceType == 'youtube' ? Colors.redAccent : Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Videos YouTube',
                          style: TextStyle(
                            color: _sourceType == 'youtube' ? Colors.redAccent : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Buscador de noticias / videos
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: TextField(
                    controller: _newsSearchController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: _sourceType == 'youtube'
                          ? 'Filtrar videos por título...'
                          : 'Zona o pez (ej. Paraná, Esquina, Dorado)...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 13),
                      prefixIcon: Icon(
                        _sourceType == 'youtube' ? Icons.play_circle : Icons.language,
                        color: _sourceType == 'youtube' ? Colors.redAccent : const Color(0xFF00E5FF),
                        size: 18,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sourceType == 'youtube' ? Colors.redAccent : cyanColor,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _buscarNoticiasWeb,
                child: Text(
                  'Buscar',
                  style: TextStyle(
                    color: _sourceType == 'youtube' ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Restricción informativa
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
          child: Row(
            children: [
              Icon(
                _sourceType == 'youtube' ? Icons.videocam_outlined : Icons.history_toggle_off,
                color: Colors.white30,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                _sourceType == 'youtube'
                    ? 'Últimos videos subidos por los canales oficiales de pesca.'
                    : 'Refinado automáticamente a reportes de menos de 7 días.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        Expanded(
          child: _searchingNews
              ? Center(child: CircularProgressIndicator(color: _sourceType == 'youtube' ? Colors.redAccent : cyanColor))
              : _noticiasEncontradas.isEmpty
                  ? Center(
                      child: Text(
                        _sourceType == 'youtube'
                            ? 'No se encontraron videos recientes para este término.'
                            : 'No se encontraron noticias recientes para este término.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: _noticiasEncontradas.length,
                      itemBuilder: (context, index) {
                        final noticia = _noticiasEncontradas[index];
                        final bool isVideo = noticia['is_video'] == true;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: cardBg.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Portada con indicador de video
                              ClipRRect(
                                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Image.network(
                                      noticia['imagen'],
                                      height: 140,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => Container(
                                        height: 140,
                                        width: double.infinity,
                                        color: Colors.white10,
                                        child: const Icon(Icons.image, color: Colors.white38),
                                      ),
                                    ),
                                    if (isVideo) ...[
                                      Container(
                                        height: 140,
                                        width: double.infinity,
                                        color: Colors.black38,
                                      ),
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.red.withValues(alpha: 0.9),
                                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 30),
                                      ),
                                    ],
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          isVideo ? '🎥 Canal: ${noticia['fuente']}' : 'Fuente: ${noticia['fuente']}',
                                          style: TextStyle(
                                            color: isVideo ? Colors.redAccent : cyanColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          noticia['fecha_legible'],
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 10),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    
                                    Text(
                                      noticia['titulo'],
                                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    const SizedBox(height: 6),

                                    Text(
                                      noticia['fragmento'],
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12, height: 1.3),
                                    ),
                                    const SizedBox(height: 16),

                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: isVideo
                                              ? Colors.redAccent.withValues(alpha: 0.15)
                                              : cyanColor.withValues(alpha: 0.15),
                                          side: BorderSide(
                                            color: isVideo
                                                ? Colors.redAccent.withValues(alpha: 0.3)
                                                : cyanColor.withValues(alpha: 0.3),
                                          ),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                        icon: Icon(
                                          Icons.auto_awesome,
                                          color: isVideo ? Colors.redAccent : cyanColor,
                                          size: 16,
                                        ),
                                        label: Text(
                                          isVideo
                                              ? 'REDACTAR NOTA DEL VIDEO CON GU-IA'
                                              : 'GENERAR BORRADOR CON GU-IA',
                                          style: TextStyle(
                                            color: isVideo ? Colors.redAccent : cyanColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 11,
                                          ),
                                        ),
                                        onPressed: () => _generarConIA(noticia),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  // --- FORMULARIO CREAR / EDITAR ARTÍCULO ---
  void _abrirFormularioArticulo(ArticuloBlog articuloExistente) async {
    final bool esEdicion = articuloExistente.id.isNotEmpty;
    
    // Controladores de texto
    final tituloCtrl = TextEditingController(text: articuloExistente.titulo);
    final resumenCtrl = TextEditingController(text: articuloExistente.resumen);
    final autorCtrl = TextEditingController(text: articuloExistente.autor.isEmpty ? 'Staff Capitán-YA' : articuloExistente.autor);
    final imagenCtrl = TextEditingController(text: articuloExistente.imagenPortada);
    final contenidoCtrl = TextEditingController(text: articuloExistente.contenido);
    final minutosCtrl = TextEditingController(text: articuloExistente.minutosLectura.toString());
    final fuenteCtrl = TextEditingController(text: articuloExistente.fuenteUrl ?? '');

    String seleccionCategoria = articuloExistente.categoria;
    bool activoForm = articuloExistente.activo;
    List<String> productosSeleccionados = List<String>.from(articuloExistente.productosSugeridos);

    // Cargar catálogo total de productos para la asignación sugerida
    List<Producto> catalogoTotal = [];
    try {
      catalogoTotal = await SupabaseService.getProductos();
    } catch (_) {}

    if (!mounted) return;

    VoidCallback? imageListener;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            if (imageListener == null) {
              imageListener = () {
                try {
                  setModalState(() {});
                } catch (_) {}
              };
              imagenCtrl.addListener(imageListener!);
            }
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.85,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Form
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          esEdicion ? 'Editar Artículo' : 'Nuevo Artículo Editorial',
                          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white10),

                    // Inputs Scrollables
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Titulo
                            _buildInputLabel('Título del Artículo'),
                            _buildTextField(tituloCtrl, 'Escribe un título atractivo...'),

                            // Categoria
                            _buildInputLabel('Categoría de Contenido'),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: seleccionCategoria,
                                  dropdownColor: const Color(0xFF0F172A),
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  isExpanded: true,
                                  items: _articleCategories.where((c) => c != 'Todos').map((c) {
                                    return DropdownMenuItem(value: c, child: Text(c));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setModalState(() {
                                        seleccionCategoria = val;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Fila de Autor y Tiempo
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('Redactor / Autor'),
                                      _buildTextField(autorCtrl, 'Nombre del redactor'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildInputLabel('Tiempo de Lectura (min)'),
                                      _buildTextField(minutosCtrl, 'Ej: 5', keyboardType: TextInputType.number),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Imagen Portada URL
                            _buildInputLabel('URL Imagen de Portada'),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTextField(imagenCtrl, 'Pegar link de imagen ilustrativa...'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF00E5FF),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  icon: const Icon(Icons.upload_file, color: Colors.black, size: 16),
                                  label: const Text('Subir', style: TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold)),
                                  onPressed: () async {
                                    try {
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        imageQuality: 70,
                                      );
                                      if (image != null) {
                                        setModalState(() {
                                          imagenCtrl.text = 'Subiendo imagen... ⏳';
                                        });
                                        String url;
                                        try {
                                          url = await StorageService.uploadXFile(
                                            xFile: image,
                                            bucket: 'branding',
                                            folderPath: 'blog_portadas',
                                            fileNamePrefix: 'portada',
                                          );
                                        } catch (uploadErr) {
                                          debugPrint('⚠️ Falló subida a branding, intentando en productos: $uploadErr');
                                          try {
                                            url = await StorageService.uploadXFile(
                                              xFile: image,
                                              bucket: 'productos',
                                              folderPath: 'blog_portadas',
                                              fileNamePrefix: 'portada',
                                            );
                                          } catch (prodErr) {
                                            debugPrint('⚠️ Falló subida a productos, intentando en fotos_perfil: $prodErr');
                                            url = await StorageService.uploadXFile(
                                              xFile: image,
                                              bucket: 'fotos_perfil',
                                              folderPath: 'blog_portadas',
                                              fileNamePrefix: 'portada',
                                            );
                                          }
                                        }
                                        setModalState(() {
                                          imagenCtrl.text = url;
                                        });
                                        _mostrarMensaje('¡Imagen subida con éxito!');
                                      }
                                    } catch (e) {
                                      setModalState(() {
                                        imagenCtrl.text = '';
                                      });
                                      _mostrarMensaje('Error al subir imagen: $e', esError: true);
                                    }
                                  },
                                ),
                              ],
                            ),

                            // Vista Previa de la Imagen (Live Preview)
                            if (imagenCtrl.text.isNotEmpty && !imagenCtrl.text.contains('Subiendo')) ...[
                              const SizedBox(height: 10),
                              Container(
                                height: 145,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    imagenCtrl.text,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      color: Colors.white.withValues(alpha: 0.05),
                                      child: const Center(
                                        child: Text(
                                          'URL de imagen inválida o rota',
                                          style: TextStyle(color: Colors.white38, fontSize: 11),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],

                            // Galería de Selección Rápida de Portadas Premium
                            _buildInputLabel('Selección Rápida de Portadas Premium'),
                            SizedBox(
                              height: 64,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=600&h=400&fit=crop', // pescador en río
                                  'https://images.unsplash.com/photo-1508193638397-1c4234db14d8?w=600&h=400&fit=crop', // pesca deportiva
                                  'https://images.unsplash.com/photo-1582560475093-ba66accbc424?w=600&h=400&fit=crop', // anzuelo y carnada
                                  'https://images.unsplash.com/photo-1559827260-dc66d52bef19?w=600&h=400&fit=crop', // río al atardecer
                                  'https://images.unsplash.com/photo-1621351183012-e2f9972dd9bf?w=600&h=400&fit=crop', // pesca en lancha
                                ].map((imageUrl) {
                                  final isSelected = imagenCtrl.text == imageUrl;
                                  return GestureDetector(
                                    onTap: () {
                                      setModalState(() {
                                        imagenCtrl.text = imageUrl;
                                      });
                                    },
                                    child: Container(
                                      width: 90,
                                      margin: const EdgeInsets.only(right: 8),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF00E5FF) : Colors.white12,
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          imageUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => const Icon(Icons.image_not_supported_outlined, color: Colors.white24),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),

                            // Fuente Original URL
                            _buildInputLabel('URL Fuente de Origen (Opcional)'),
                            _buildTextField(fuenteCtrl, 'Link original de noticia si aplica...'),

                            // Cuerpo Markdown
                            _buildInputLabel('Cuerpo del Artículo (Soporta Markdown)'),
                            Container(
                              height: 180,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: TextField(
                                controller: contenidoCtrl,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                                decoration: InputDecoration(
                                  hintText: '# Título de sección\n\nRedacta el informe aquí. Usa **negrita** para resaltar y guiones - para viñetas...',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.all(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Selector de Productos Sugeridos
                            _buildInputLabel('Vincular Productos del Catálogo (Monetización)'),
                            if (catalogoTotal.isEmpty)
                              Text('No hay productos disponibles en el catálogo.', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11))
                            else
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.02),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                                ),
                                child: Column(
                                  children: catalogoTotal.map((prod) {
                                    final bool estaSeleccionado = productosSeleccionados.contains(prod.id);
                                    return CheckboxListTile(
                                      title: Text(prod.nombre, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      subtitle: Text('\$${prod.precio.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 10)),
                                      value: estaSeleccionado,
                                      activeColor: const Color(0xFF00E5FF),
                                      checkColor: Colors.black,
                                      contentPadding: EdgeInsets.zero,
                                      onChanged: (bool? checked) {
                                        setModalState(() {
                                          if (checked == true) {
                                            productosSeleccionados.add(prod.id);
                                          } else {
                                            productosSeleccionados.remove(prod.id);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            const SizedBox(height: 16),

                            // Switch Publicado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Publicar artículo inmediatamente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(
                                      activoForm ? 'Visible para todos los pescadores' : 'Guardado como borrador / inactivo',
                                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: activoForm,
                                  activeThumbColor: const Color(0xFF00E676),
                                  onChanged: (val) {
                                    setModalState(() {
                                      activoForm = val;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),

                    // Botones de acción
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white24),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () async {
                                if (tituloCtrl.text.isEmpty || contenidoCtrl.text.isEmpty) {
                                  _mostrarMensaje('Completa Título y Cuerpo del artículo.', esError: true);
                                  return;
                                }

                                final int mins = int.tryParse(minutosCtrl.text) ?? 5;

                                final artForm = ArticuloBlog(
                                  id: esEdicion ? articuloExistente.id : '',
                                  titulo: tituloCtrl.text,
                                  resumen: resumenCtrl.text.isEmpty
                                      ? (contenidoCtrl.text.length > 100 ? '${contenidoCtrl.text.substring(0, 97)}...' : contenidoCtrl.text)
                                      : resumenCtrl.text,
                                  contenido: contenidoCtrl.text,
                                  autor: autorCtrl.text,
                                  minutosLectura: mins,
                                  imagenPortada: imagenCtrl.text.trim().isEmpty
                                      ? 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=600&h=400&fit=crop'
                                      : imagenCtrl.text.trim(),
                                  categoria: seleccionCategoria,
                                  productosSugeridos: productosSeleccionados,
                                  fuenteUrl: fuenteCtrl.text.isEmpty ? null : fuenteCtrl.text,
                                  activo: activoForm,
                                  createdAt: esEdicion ? articuloExistente.createdAt : DateTime.now(),
                                  updatedAt: DateTime.now(),
                                );

                                try {
                                  if (esEdicion) {
                                    await SupabaseService.actualizarArticuloBlog(artForm);
                                    _mostrarMensaje('Artículo editado correctamente.');
                                  } else {
                                    await SupabaseService.crearArticuloBlog(artForm);
                                    _mostrarMensaje('Artículo redactado y guardado.');
                                  }
                                  if (ctx.mounted) {
                                    Navigator.pop(ctx); // Cerrar Modal
                                  }
                                  _cargarArticulos(); // Recargar lista
                                } catch (e) {
                                  _mostrarMensaje('Error al guardar artículo en base de datos.', esError: true);
                                }
                              },
                              child: Text(
                                esEdicion ? 'Guardar Cambios' : 'Publicar Nota',
                                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (imageListener != null) {
      imagenCtrl.removeListener(imageListener!);
    }
  }

  Widget _buildInputLabel(String txt) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        txt,
        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {TextInputType keyboardType = TextInputType.text}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}

class _ModalSalidaPesca extends StatefulWidget {
  final Function(ArticuloBlog) alCompletar;

  const _ModalSalidaPesca({required this.alCompletar});

  @override
  State<_ModalSalidaPesca> createState() => _ModalSalidaPescaState();
}

class _ModalSalidaPescaState extends State<_ModalSalidaPesca> {
  int _pasoActual = 1;
  final SpeechService _speechService = SpeechService();
  bool _isListening = false;
  final TextEditingController _transcripcionCtrl = TextEditingController();

  DateTime _fechaSeleccionada = DateTime.now();
  final TextEditingController _zonaCtrl = TextEditingController();
  bool _hizoCampamento = false;

  String _notaRedactada = '';
  bool _generandoRedaccion = false;

  final List<String> _fotosSubidas = [];
  bool _subiendoFotos = false;
  final TextEditingController _videoUrlCtrl = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _speechService.inicializar();
  }

  @override
  void dispose() {
    _transcripcionCtrl.dispose();
    _zonaCtrl.dispose();
    _videoUrlCtrl.dispose();
    super.dispose();
  }

  void _mostrarMensaje(String msg, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.redAccent : const Color(0xFF00E676),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color cyanColor = Color(0xFF00E5FF);
    
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '🎣 Mi Salida de Pesca',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Colors.white10),
            
            // Stepper indicador
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(5, (index) {
                final paso = index + 1;
                final esActivo = paso == _pasoActual;
                final esPasado = paso < _pasoActual;
                return Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: esActivo 
                          ? cyanColor 
                          : (esPasado ? const Color(0xFF00E676) : Colors.white10),
                      child: Text(
                        paso.toString(),
                        style: TextStyle(
                          color: esActivo || esPasado ? Colors.black : Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (index < 4) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 20,
                        height: 2,
                        color: esPasado ? const Color(0xFF00E676) : Colors.white10,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                );
              }),
            ),
            const SizedBox(height: 20),

            // Contenido según paso actual
            Expanded(
              child: SingleChildScrollView(
                child: _buildContenidoPaso(cyanColor),
              ),
            ),
            
            // Botones de navegación
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Row(
                children: [
                  if (_pasoActual > 1 && !_generandoRedaccion)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () {
                          setState(() {
                            _pasoActual--;
                          });
                        },
                        child: const Text('Atrás', style: TextStyle(color: Colors.white70)),
                      ),
                    ),
                  if (_pasoActual > 1 && !_generandoRedaccion)
                    const SizedBox(width: 12),
                  
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: cyanColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _generandoRedaccion ? null : () => _avanzarPaso(cyanColor),
                      child: Text(
                        _textoBotonSiguiente(),
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
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

  String _textoBotonSiguiente() {
    switch (_pasoActual) {
      case 1:
        return 'Siguiente: Datos';
      case 2:
        return 'Redactar con El Guía';
      case 3:
        return 'Siguiente: Fotos';
      case 4:
        return 'Siguiente: Revisión';
      case 5:
        return 'Abrir en Editor Principal';
      default:
        return 'Siguiente';
    }
  }

  Widget _buildContenidoPaso(Color cyanColor) {
    switch (_pasoActual) {
      case 1:
        return _buildPaso1(cyanColor);
      case 2:
        return _buildPaso2(cyanColor);
      case 3:
        return _buildPaso3(cyanColor);
      case 4:
        return _buildPaso4(cyanColor);
      case 5:
        return _buildPaso5(cyanColor);
      default:
        return const SizedBox.shrink();
    }
  }

  // --- PASO 1: GRABACIÓN DE VOZ ---
  Widget _buildPaso1(Color cyanColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        Text(
          'Paso 1: Grabá tu relato',
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () async {
            if (_isListening) {
              await _speechService.detener();
              setState(() {
                _isListening = false;
              });
            } else {
              setState(() {
                _isListening = true;
              });
              try {
                await _speechService.escuchar(
                  alResultado: (texto) {
                    setState(() {
                      _transcripcionCtrl.text = texto;
                    });
                  },
                );
              } catch (e) {
                setState(() {
                  _isListening = false;
                });
                _mostrarMensaje('Error al activar el micrófono: $e', esError: true);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isListening ? Colors.redAccent.withValues(alpha: 0.15) : cyanColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: _isListening ? Colors.redAccent.withValues(alpha: 0.4) : cyanColor.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: _isListening ? Colors.redAccent : cyanColor,
              child: Icon(
                _isListening ? Icons.mic : Icons.mic_none,
                color: Colors.black,
                size: 36,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _isListening ? 'Escuchando tu relato... Tocá para detener 🎙️' : 'Tocá el micrófono para narrar tu salida de pesca',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _isListening ? Colors.redAccent : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Transcripción / Relato escrito:',
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _transcripcionCtrl,
            maxLines: 6,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Relato de tu salida (ej. Fuimos el sábado con Horacio a la laguna, el clima estaba nublado y frío pero pudimos meter lindas capturas...)',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(12),
            ),
          ),
        ),
      ],
    );
  }

  // --- PASO 2: DATOS DE LA SALIDA ---
  Widget _buildPaso2(Color cyanColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Paso 2: Datos de la salida',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        
        // Fecha
        _buildInputLabel('¿Cuándo fue la salida?'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white54, size: 18),
              const SizedBox(width: 12),
              Text(
                DateFormat('dd/MM/yyyy').format(_fechaSeleccionada),
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              const Spacer(),
              TextButton(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _fechaSeleccionada,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF00E5FF),
                            onPrimary: Colors.black,
                            surface: Color(0xFF0F172A),
                            onSurface: Colors.white,
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    setState(() {
                      _fechaSeleccionada = picked;
                    });
                  }
                },
                child: const Text('Seleccionar', style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        
        // Zona
        _buildInputLabel('¿Dónde pescaste? (Zona)'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _zonaCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Ej: Paraná Guazú, Esquina, Chascomús...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: Icon(Icons.place, color: Colors.white54, size: 18),
              border: InputBorder.none,
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Campamento Switch
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('¿Hicieron campamento o asado?', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Suma condimentos tradicionales a la redacción', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
              Switch(
                value: _hizoCampamento,
                activeThumbColor: const Color(0xFF00E676),
                onChanged: (val) {
                  setState(() {
                    _hizoCampamento = val;
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- PASO 3: REDACCIÓN AUTOMÁTICA (LOADER O TEXTO GENERADO) ---
  Widget _buildPaso3(Color cyanColor) {
    if (_generandoRedaccion) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Color(0xFF00E5FF)),
              const SizedBox(height: 24),
              Text(
                'El Guía está redactando tu relato...',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              const Text(
                'Estructurando en tono ribereño y ajustando modismos argentinos...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Paso 3: Redacción finalizada',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: SingleChildScrollView(
            child: Text(
              _notaRedactada,
              style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton.icon(
            onPressed: () => _generarRedaccionIA(),
            icon: const Icon(Icons.autorenew, color: Color(0xFF00E5FF), size: 16),
            label: const Text('Volver a redactar', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // --- PASO 4: CARGA DE MATERIAL ---
  Widget _buildPaso4(Color cyanColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Paso 4: Fotos y video de la salida',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),

        _buildInputLabel('Fotos del viaje (Hasta 5)'),
        if (_subiendoFotos)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: LinearProgressIndicator(color: Color(0xFF00E5FF)),
          ),
        
        // Grid de imágenes
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ..._fotosSubidas.map((url) {
              return Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _fotosSubidas.remove(url);
                      });
                    },
                    child: const CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.red,
                      child: Icon(Icons.close, size: 10, color: Colors.white),
                    ),
                  ),
                ],
              );
            }).toList(),
            if (_fotosSubidas.length < 5)
              GestureDetector(
                onTap: _subiendoFotos ? null : () async {
                  try {
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (image != null) {
                      setState(() {
                        _subiendoFotos = true;
                      });
                      final String url = await StorageService.uploadXFile(
                        xFile: image,
                        bucket: 'branding',
                        folderPath: 'blog_portadas',
                        fileNamePrefix: 'salida',
                      );
                      setState(() {
                        _fotosSubidas.add(url);
                      });
                    }
                  } catch (e) {
                    _mostrarMensaje('Error al cargar imagen: $e', esError: true);
                  } finally {
                    setState(() {
                      _subiendoFotos = false;
                    });
                  }
                },
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: const Icon(Icons.add_a_photo, color: Colors.white38, size: 20),
                ),
              ),
          ],
        ),
        if (_fotosSubidas.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'ℹ️ La primera foto se utilizará como portada del artículo.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10),
            ),
          ),
        
        const SizedBox(height: 16),
        _buildInputLabel('Video de YouTube de la salida (Opcional)'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            controller: _videoUrlCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Ej: https://www.youtube.com/watch?v=...',
              hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
              prefixIcon: Icon(Icons.video_library, color: Colors.white54, size: 18),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  // --- PASO 5: REVISIÓN Y PUBLICACIÓN ---
  Widget _buildPaso5(Color cyanColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Paso 5: Configurar publicación',
            style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilaResumen('Categoría', 'Mis Salidas'),
              const Divider(color: Colors.white10, height: 16),
              _buildFilaResumen('Estado', 'Borrador (Inactivo)'),
              const Divider(color: Colors.white10, height: 16),
              _buildFilaResumen('Fotos cargadas', '${_fotosSubidas.length}'),
              const Divider(color: Colors.white10, height: 16),
              _buildFilaResumen('Video enlazado', _videoUrlCtrl.text.isNotEmpty ? 'Sí' : 'No'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'ℹ️ Al hacer clic en el botón de abajo, se cerrará este modal y se abrirá el editor estándar de Markdown precompletado con la crónica generada para que le hagas los ajustes finales antes de guardarla.',
          style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
        ),
      ],
    );
  }

  Widget _buildFilaResumen(String titulo, String valor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(titulo, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        Text(valor, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Future<void> _generarRedaccionIA() async {
    setState(() {
      _generandoRedaccion = true;
    });
    try {
      final fechaStr = DateFormat('dd/MM/yyyy').format(_fechaSeleccionada);
      final campamentoDetalle = _hizoCampamento ? 'Sí, hicimos campamento/asado' : 'No hubo campamento';
      final transcripcionCompleta = '${_transcripcionCtrl.text}\nCampamento: $campamentoDetalle';
      
      final nota = await GroqService.redactarSalidaPesca(
        transcripcion: transcripcionCompleta,
        fecha: fechaStr,
        zona: _zonaCtrl.text,
      );
      
      setState(() {
        _notaRedactada = nota;
      });
    } catch (e) {
      _mostrarMensaje('Error al conectar con Groq: $e', esError: true);
      // Forzar retroceso
      setState(() {
        _pasoActual = 2;
      });
    } finally {
      setState(() {
        _generandoRedaccion = false;
      });
    }
  }

  void _avanzarPaso(Color cyanColor) async {
    if (_pasoActual == 1) {
      if (_transcripcionCtrl.text.trim().isEmpty) {
        _mostrarMensaje('Escribí o grabá un relato de tu salida primero.', esError: true);
        return;
      }
      setState(() {
        _pasoActual = 2;
      });
    } else if (_pasoActual == 2) {
      if (_zonaCtrl.text.trim().isEmpty) {
        _mostrarMensaje('Por favor, ingresá la zona de pesca.', esError: true);
        return;
      }
      setState(() {
        _pasoActual = 3;
      });
      _generarRedaccionIA();
    } else if (_pasoActual == 3) {
      setState(() {
        _pasoActual = 4;
      });
    } else if (_pasoActual == 4) {
      setState(() {
        _pasoActual = 5;
      });
    } else if (_pasoActual == 5) {
      // Completado: configurar el modelo de artículo y abrir el editor principal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF))),
      );

      try {
        final profile = await SupabaseService.obtenerPerfilGuiaActual();
        final autor = profile?['nombre'] ?? 'Staff Capitán-YA';
        
        final portada = _fotosSubidas.isNotEmpty 
            ? _fotosSubidas.first 
            : 'https://images.unsplash.com/photo-1544551763-46a013bb70d5?w=800&h=450&fit=crop';
            
        // Extraer un título simple
        String titulo = '🎣 Crónica de Pesca en ${_zonaCtrl.text}';
        final lineas = _notaRedactada.split('\n');
        for (var l in lineas) {
          final limpia = l.trim().replaceAll('*', '').replaceAll('#', '').trim();
          if (limpia.length > 5 && (limpia.startsWith('Título') || limpia.contains('🎣') || limpia.contains('Salida'))) {
            titulo = limpia;
            break;
          }
        }

        final articulo = ArticuloBlog(
          id: '',
          titulo: titulo,
          resumen: _transcripcionCtrl.text.length > 150 
              ? '${_transcripcionCtrl.text.substring(0, 147)}...' 
              : _transcripcionCtrl.text,
          contenido: _notaRedactada,
          autor: autor,
          minutosLectura: 4,
          imagenPortada: portada,
          categoria: 'Mis Salidas',
          productosSugeridos: [],
          fuenteUrl: _videoUrlCtrl.text.isEmpty ? null : _videoUrlCtrl.text,
          activo: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        if (mounted) {
          Navigator.pop(context); // Cerrar cargando
          Navigator.pop(context); // Cerrar modal salida pesca
          widget.alCompletar(articulo); // Abrir editor con el modelo pre-cargado
        }
      } catch (e) {
        if (mounted) {
          Navigator.pop(context); // Cerrar cargando
        }
        _mostrarMensaje('Error al configurar la nota: $e', esError: true);
      }
    }
  }

  Widget _buildInputLabel(String txt) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Text(
        txt,
        style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}
