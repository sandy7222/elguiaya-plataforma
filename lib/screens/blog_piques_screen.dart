import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:hive/hive.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/articulo_blog.dart';
import '../services/supabase_service.dart';
import '../services/news_compiler_service.dart';
import '../services/connectivity_bridge.dart';
import '../services/gemini_ai_service.dart';
import 'articulo_detalle_screen.dart';
import 'articulo_offline_screen.dart';
import 'youtube_player_screen.dart';
import '../widgets/safe_button.dart';

// --- Paleta de Colores -------------------------------------------------------
const Color darkBg    = Color(0xFF0A0E12);
const Color cardBg    = Color(0xFF0F172A);
const Color accentColor = Color(0xFF00E676);
const Color cyanColor   = Color(0xFF00E5FF);

// Clave del caché Hive del blog
const String _kBoxBlog      = 'blog_cache_v2';
const String _kKeyFeed      = 'feed_items';
const String _kKeyReviews   = 'reviews';
const String _kKeyTimestamp = 'last_sync';

class BlogPiquesScreen extends StatefulWidget {
  const BlogPiquesScreen({super.key});

  @override
  State<BlogPiquesScreen> createState() => _BlogPiquesScreenState();
}

class _BlogPiquesScreenState extends State<BlogPiquesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // -- Estado del feed -----------------------------------------------------
  List<Map<String, dynamic>> _feedItems   = [];
  List<Map<String, dynamic>> _reviews     = [];
  bool   _isLoading       = true;
  bool   _isSyncing       = false;
  bool   _haySenal        = true;
  String _lastSyncLabel   = '';
  String _searchText      = '';
  String _selectedCategory = 'Todos';

  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'Todos', 'Videos', 'Novedades',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _haySenal = ConnectivityBridge.estaConectado;
    ConnectivityBridge.conexionStream.listen((conectado) {
      if (mounted) {
        setState(() => _haySenal = conectado);
        if (conectado && _feedItems.isEmpty) _cargarFeed(forzar: false);
      }
    });
    _cargarFeed(forzar: false);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // -- Carga central del feed ----------------------------------------------
  Future<void> _cargarFeed({bool forzar = false}) async {
    if (_isSyncing) return;
    setState(() { _isLoading = true; _isSyncing = forzar; });

    try {
      // 1. Intentar leer desde caché primero (respuesta instantánea)
      final cached = await _leerCache();
      if (cached != null && !forzar) {
        setState(() {
          _feedItems      = cached['feed'];
          _reviews        = cached['reviews'];
          _lastSyncLabel  = cached['label'];
          _isLoading      = false;
          _isSyncing      = false;
        });
        // Si hay señal, actualizar en background silenciosamente
        if (_haySenal) _actualizarEnBackground();
        return;
      }

      // 2. Sin caché o forzado: descargar si hay señal
      if (_haySenal) {
        await _descargarYGuardar();
      } else {
        // Sin señal y sin caché: feed vacío con aviso
        setState(() { _isLoading = false; _isSyncing = false; });
      }
    } catch (e) {
      debugPrint('?? [BLOG] Error en _cargarFeed: $e');
      setState(() { _isLoading = false; _isSyncing = false; });
    }
  }

  Future<void> _actualizarEnBackground() async {
    try {
      await _descargarYGuardar();
    } catch (_) {}
  }

  Future<void> _descargarYGuardar() async {
    try {
      // FASE 1: Carga Rápida (YouTube RSS + Blogspot + Reviews + Supabase en paralelo)
      final resultados = await Future.wait([
        NewsCompilerService.obtenerVideosRecientesYoutube(''),
        SupabaseService.obtenerReviewsPublicas(),
        NewsCompilerService.scrapearBlogspot(), // Blogger oficial
      ]);

      final List<Map<String, dynamic>> videos   = List<Map<String, dynamic>>.from(resultados[0] as List);
      final List<Map<String, dynamic>> reviews  = List<Map<String, dynamic>>.from(resultados[1] as List);
      final List<Map<String, dynamic>> blogspot = List<Map<String, dynamic>>.from(resultados[2] as List);

      // Intentar también artículos de Supabase (si los hay)
      List<ArticuloBlog> articulosBD = [];
      try {
        articulosBD = await SupabaseService.obtenerArticulosBlog();
      } catch (_) {}

      // Convertir artículos de BD al formato unificado del feed
      final List<Map<String, dynamic>> articulosFeed = articulosBD.map((a) => {
        'tipo':     a.fuenteUrl != null &&
                    (a.fuenteUrl!.contains('youtube.com') || a.fuenteUrl!.contains('youtu.be'))
                    ? 'video' : 'nota',
        'id':       a.id,
        'titulo':   a.titulo,
        'fragmento': a.resumen,
        'fuente':   a.autor,
        'url':      a.fuenteUrl ?? '',
        'imagen':   a.imagenPortada,
        'fecha':    a.createdAt.toIso8601String(),
        'fecha_legible': DateFormat('dd MMM').format(a.createdAt),
        'categoria': a.categoria,
        'minutos':  a.minutosLectura,
        'desde_bd': true,
        'articulo_id': a.id,
      }).toList();

      // Marcar videos
      for (final v in videos) { v['tipo'] = 'video'; }

      // 1. Obtener ítems previamente guardados en el caché para no borrarlos al actualizar
      List<Map<String, dynamic>> itemsViejos = [];
      try {
        final cached = await _leerCache();
        if (cached != null && cached['feed'] != null) {
          itemsViejos = List<Map<String, dynamic>>.from(cached['feed'] as List);
        }
      } catch (e) {
        debugPrint('?? [BLOG] No se pudo leer el caché anterior para fusionar: $e');
      }

      final notasViejas = itemsViejos.where((i) => i['tipo'] == 'nota').toList();
      final videosViejas = itemsViejos.where((i) => i['tipo'] == 'video').toList();

      // Fusionar las listas rápidas nuevas con las del caché
      final notasNuevas = [
        ...blogspot,
        ...articulosFeed.where((i) => i['tipo'] == 'nota'),
      ];
      final videosNuevos = [
        ...articulosFeed.where((i) => i['tipo'] == 'video'),
        ...videos,
      ];

      final List<Map<String, dynamic>> todasLasNotas = _fusionarYFiltrar(notasNuevas, notasViejas);
      final List<Map<String, dynamic>> todosLosVideos = _fusionarYFiltrar(videosNuevos, videosViejas);

      // Separar el Blog Oficial para que siempre aparezca primero en las notas,
      // y ordenar el resto de forma cronológica
      final notasOficiales = todasLasNotas.where((n) => n['fuente'] == 'Blog Oficial').toList();
      final notasRestantes = todasLasNotas.where((n) => n['fuente'] != 'Blog Oficial').toList();

      notasOficiales.sort(_compararFechas);
      notasRestantes.sort(_compararFechas);

      final List<Map<String, dynamic>> notasOrdenadas = [...notasOficiales, ...notasRestantes];
      todosLosVideos.sort(_compararFechas);

      // Intercalar: nota ? video ? nota ? video
      final List<Map<String, dynamic>> feedIntercalado = [];
      final int maxLen = notasOrdenadas.length > todosLosVideos.length
          ? notasOrdenadas.length : todosLosVideos.length;
      for (int i = 0; i < maxLen; i++) {
        if (i < notasOrdenadas.length)  feedIntercalado.add(notasOrdenadas[i]);
        if (i < todosLosVideos.length) feedIntercalado.add(todosLosVideos[i]);
      }

      // Guardar en Hive (Caché rápido inicial)
      await _guardarCache(feedIntercalado, reviews);

      if (mounted) {
        setState(() {
          _feedItems     = feedIntercalado;
          _reviews       = reviews;
          _lastSyncLabel = _labelAhora();
          _isLoading     = false;
        });
      }

      // FASE 2: Enriquecimiento lento en segundo plano (revistas + Gemini + contenido completo)
      _enriquecerFeedEnBackground(
        videosOriginales: videos,
        reviews: reviews,
        articulosFeed: articulosFeed,
        blogspot: blogspot,
      );

    } catch (e) {
      debugPrint('?? [BLOG] Error descargando: $e');
      if (mounted) setState(() { _isLoading = false; _isSyncing = false; });
    }
  }

  Future<void> _enriquecerFeedEnBackground({
    required List<Map<String, dynamic>> videosOriginales,
    required List<Map<String, dynamic>> reviews,
    required List<Map<String, dynamic>> articulosFeed,
    required List<Map<String, dynamic>> blogspot,
  }) async {
    try {
      // 1. Descargar revistas en paralelo lento (hace scraping web)
      final List<Map<String, dynamic>> noticias = await NewsCompilerService.scrapearRevistas(maxPorRevista: 5);

      // 2. Comentarios de Gemini para videos
      final tareasDescripcion = videosOriginales
          .where((v) => v['descripcion_real'] != true)
          .map((v) async {
            try {
              final comentario = await GeminiAIService.generarComentarioVideo(
                tituloVideo: v['titulo'] as String? ?? '',
                canalNombre: v['fuente'] as String? ?? '',
              ).timeout(const Duration(seconds: 6));
              if (comentario != null && comentario.isNotEmpty) {
                v['fragmento'] = comentario;
              }
            } catch (_) {}
          }).toList();

      // 3. Descargar texto completo de las noticias
      for (final n in noticias) { n['tipo'] = 'nota'; }
      final noticiasConImagen = noticias.where((n) => n['tiene_imagen_real'] == true).toList();

      final tareasTexto = noticiasConImagen.map((nota) async {
        final url = nota['url'] as String? ?? '';
        if (url.isNotEmpty && url.startsWith('http')) {
          try {
            final texto = await NewsCompilerService.extraerTextoCompletoArticulo(url)
                .timeout(const Duration(seconds: 8));
            if (texto != null && texto.isNotEmpty) {
              nota['contenido_completo'] = texto;
            }
          } catch (_) {}
        }
      }).toList();

      // Esperar descargas y gemini en paralelo
      await Future.wait([...tareasDescripcion, ...tareasTexto]);

      // 4. Leer el caché actualizado
      List<Map<String, dynamic>> itemsViejos = [];
      try {
        final cached = await _leerCache();
        if (cached != null && cached['feed'] != null) {
          itemsViejos = List<Map<String, dynamic>>.from(cached['feed'] as List);
        }
      } catch (_) {}

      final notasViejas = itemsViejos.where((i) => i['tipo'] == 'nota').toList();
      final videosViejas = itemsViejos.where((i) => i['tipo'] == 'video').toList();

      final notasNuevas = [
        ...blogspot,
        ...articulosFeed.where((i) => i['tipo'] == 'nota'),
        ...noticiasConImagen,
      ];
      final videosNuevos = [
        ...articulosFeed.where((i) => i['tipo'] == 'video'),
        ...videosOriginales,
      ];

      final List<Map<String, dynamic>> todasLasNotas = _fusionarYFiltrar(notasNuevas, notasViejas);
      final List<Map<String, dynamic>> todosLosVideos = _fusionarYFiltrar(videosNuevos, videosViejas);

      final notasOficiales = todasLasNotas.where((n) => n['fuente'] == 'Blog Oficial').toList();
      final notasRestantes = todasLasNotas.where((n) => n['fuente'] != 'Blog Oficial').toList();

      notasOficiales.sort(_compararFechas);
      notasRestantes.sort(_compararFechas);

      final List<Map<String, dynamic>> notasOrdenadas = [...notasOficiales, ...notasRestantes];
      todosLosVideos.sort(_compararFechas);

      final List<Map<String, dynamic>> feedIntercalado = [];
      final int maxLen = notasOrdenadas.length > todosLosVideos.length
          ? notasOrdenadas.length : todosLosVideos.length;
      for (int i = 0; i < maxLen; i++) {
        if (i < notasOrdenadas.length)  feedIntercalado.add(notasOrdenadas[i]);
        if (i < todosLosVideos.length) feedIntercalado.add(todosLosVideos[i]);
      }

      // Guardar caché enriquecido definitivo
      await _guardarCache(feedIntercalado, reviews);

      final bool wasSyncing = _isSyncing;

      if (mounted) {
        setState(() {
          _feedItems     = feedIntercalado;
          _lastSyncLabel = _labelAhora();
          _isSyncing     = false;
        });

        if (wasSyncing) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('? Blog actualizado y guardado para usar sin señal'),
              backgroundColor: Color(0xFF00E676),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('?? [BLOG] Error en background enrichment: $e');
      if (mounted) setState(() { _isSyncing = false; });
    }
  }

  int _compararFechas(Map<String, dynamic> a, Map<String, dynamic> b) {
    DateTime parsedDate(dynamic raw) {
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw) ?? DateTime.now();
      return DateTime.now();
    }
    return parsedDate(b['fecha']).compareTo(parsedDate(a['fecha']));
  }

  List<Map<String, dynamic>> _fusionarYFiltrar(
    List<Map<String, dynamic>> nuevas,
    List<Map<String, dynamic>> viejas,
  ) {
    final Map<String, Map<String, dynamic>> mapa = {};

    String obtenerClave(Map<String, dynamic> item) {
      final String dbId = item['articulo_id']?.toString() ?? item['id']?.toString() ?? '';
      if (dbId.isNotEmpty) return 'db_$dbId';

      final String url = item['url'] as String? ?? '';
      if (url.isNotEmpty) return 'url_$url';

      return 'title_${item['titulo'] ?? ''}';
    }

    for (final item in viejas) {
      final key = obtenerClave(item);
      if (key.isNotEmpty) mapa[key] = item;
    }
    for (final item in nuevas) {
      final key = obtenerClave(item);
      if (key.isNotEmpty) mapa[key] = item;
    }

    // Filtrar por fecha: sostener items externos por 7 días, oficiales no expiran
    final limite = DateTime.now().subtract(const Duration(days: 7));
    return mapa.values.where((item) {
      final fuente = item['fuente'] as String? ?? '';
      final desdeBD = item['desde_bd'] == true;
      if (fuente == 'Blog Oficial' || desdeBD) return true;

      final rawFecha = item['fecha'];
      DateTime? fecha;
      if (rawFecha is DateTime) {
        fecha = rawFecha;
      } else if (rawFecha is String) {
        fecha = DateTime.tryParse(rawFecha);
      }
      if (fecha == null) return true;
      return fecha.isAfter(limite);
    }).toList();
  }

  // -- Caché Hive ------------------------------------------------------------
  Future<Map<String, dynamic>?> _leerCache() async {
    try {
      final box = await Hive.openBox(_kBoxBlog);
      final rawFeed    = box.get(_kKeyFeed);
      final rawReviews = box.get(_kKeyReviews);
      final ts         = box.get(_kKeyTimestamp) as String?;
      if (rawFeed == null) return null;

      final List<Map<String, dynamic>> feed = (rawFeed as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final List<Map<String, dynamic>> revs = rawReviews == null
          ? []
          : (rawReviews as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      String label = 'Caché local';
      if (ts != null) {
        final dt = DateTime.tryParse(ts);
        if (dt != null) label = 'Guardado ${DateFormat('dd/MM HH:mm').format(dt.toLocal())}';
      }
      return {'feed': feed, 'reviews': revs, 'label': label};
    } catch (e) {
      debugPrint('?? [BLOG_CACHE] Error leyendo caché: $e');
      return null;
    }
  }

  Future<void> _guardarCache(
    List<Map<String, dynamic>> feed,
    List<Map<String, dynamic>> reviews,
  ) async {
    try {
      final box = await Hive.openBox(_kBoxBlog);
      // Serializar dates a string para compatibilidad con Hive
      final serialFeed = feed.map((item) {
        final m = Map<String, dynamic>.from(item);
        if (m['fecha'] is DateTime) m['fecha'] = (m['fecha'] as DateTime).toIso8601String();
        return m;
      }).toList();
      await box.put(_kKeyFeed,      serialFeed);
      await box.put(_kKeyReviews,   reviews);
      await box.put(_kKeyTimestamp, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('?? [BLOG_CACHE] Error guardando caché: $e');
    }
  }

  String _labelAhora() => 'Guardado ${DateFormat('dd/MM HH:mm').format(DateTime.now())}';

  // -- Filtrado --------------------------------------------------------------
  List<Map<String, dynamic>> get _feedFiltrado {
    return _feedItems.where((item) {
      final tipo    = item['tipo'] as String? ?? '';
      final titulo  = (item['titulo']  as String? ?? '').toLowerCase();
      final frag    = (item['fragmento'] as String? ?? '').toLowerCase();
      final fuente  = (item['fuente']  as String? ?? '').toLowerCase();

      if (_selectedCategory == 'Videos' && tipo != 'video') return false;
      if (_selectedCategory != 'Todos' && _selectedCategory != 'Videos') {
        final cat = (item['categoria'] as String? ?? '').toLowerCase();
        if (!cat.contains(_selectedCategory.toLowerCase()) &&
            !titulo.contains(_selectedCategory.toLowerCase())) return false;
      }
      if (_searchText.isNotEmpty) {
        return titulo.contains(_searchText) ||
               frag.contains(_searchText)   ||
               fuente.contains(_searchText);
      }
      return true;
    }).toList();
  }

  // -------------------------------------------------------------------------
  //  BUILD
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
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
                _buildAppBar(),

                // Banner offline
                if (!_haySenal) _buildOfflineBanner(),

                // Banner de última sincronización (cuando hay caché)
                if (_haySenal && _lastSyncLabel.isNotEmpty && !_isSyncing)
                  _buildSyncLabel(),

                _buildSearchBar(),
                _buildTabBar(),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRevistasTab(),
                      _buildComunidadTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- App Bar ---------------------------------------------------------------
  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EL GUIA YA Pesca',
                  style: GoogleFonts.outfit(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Últimas noticias y videos de pesca deportiva',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10),
                ),
              ],
            ),
          ),
          // Botón "Sincronizar para llevar"
          if (_haySenal)
            Tooltip(
              message: 'Sincronizar para usar sin señal',
              child: _isSyncing
                  ? const SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(color: cyanColor, strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.cloud_download_outlined, color: cyanColor),
                      onPressed: () => _cargarFeed(forzar: true),
                    ),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cyanColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phishing, color: cyanColor, size: 20),
          ),
        ],
      ),
    );
  }

  // -- Banner sin señal ------------------------------------------------------
  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '?? Sin señal  Modo Isla',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                Text(
                  _feedItems.isNotEmpty
                      ? 'Mostrando contenido guardado · $_lastSyncLabel'
                      : 'No hay caché guardado. Sincronizá antes de salir a la isla.',
                  style: TextStyle(color: Colors.orange.withOpacity(0.75), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncLabel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: accentColor, size: 12),
          const SizedBox(width: 4),
          Text(
            _lastSyncLabel,
            style: const TextStyle(color: accentColor, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // -- Search bar ------------------------------------------------------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => FocusScope.of(context).unfocus(),
          onChanged: (val) => setState(() => _searchText = val.trim().toLowerCase()),
          decoration: InputDecoration(
            hintText: 'Buscar noticias, videos, canales...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
            suffixIcon: _searchText.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.white70),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchText = '');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  // -- Tab bar ---------------------------------------------------------------
  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
        ),
        child: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.newspaper_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Revistas'),
                  ],
                ),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.groups_outlined, size: 16),
                    SizedBox(width: 6),
                    Text('Comunidad'),
                  ],
                ),
              ),
            ),
          ],
          indicator: BoxDecoration(
            color: cyanColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: cyanColor.withOpacity(0.3)),
          ),
          labelColor: cyanColor,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 13),
          dividerColor: Colors.transparent,
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  TAB 1: REVISTAS (feed de noticias + videos)
  // -------------------------------------------------------------------------
  Widget _buildRevistasTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cyanColor));
    }

    // Si no hay señal y tampoco hay ningún elemento en caché, mostrar estado vacío general
    if (_feedItems.isEmpty && !_haySenal) {
      return _buildEmptyState(
        '?? Sin caché guardado\n\nAndá a una zona con señal y tocá el botón ?? para guardar las noticias y llevarlas a la isla.',
        icono: Icons.cloud_off_rounded,
        color: Colors.orange,
      );
    }

    final feed = _feedFiltrado;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isMobile = constraints.maxWidth < 600;
        final bool isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1024;
        final int crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 3);
        const double spacing = 14;

        return Column(
          children: [
            // Chips de categorías
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categories.length,
                itemBuilder: (context, idx) {
                  final cat = _categories[idx];
                  final sel = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? cyanColor.withOpacity(0.15) : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? cyanColor.withOpacity(0.4) : Colors.white.withOpacity(0.1),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          cat,
                          style: TextStyle(
                            color: sel ? cyanColor : Colors.white70,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: feed.isEmpty
                  ? _buildEmptyState('No se encontraron artículos.\nIntentá cambiar los filtros.')
                  : Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1200),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: CustomScrollView(
                            slivers: [
                              // Card destacada (Spotlight)
                              SliverToBoxAdapter(
                                child: _buildSpotlightCard(feed[0]),
                              ),
                              const SliverToBoxAdapter(child: SizedBox(height: 20)),

                              if (feed.length > 1) ...[
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 14),
                                    child: Text(
                                      'MÁS NOVEDADES Y VIDEOS',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white54,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                SliverGrid(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: spacing,
                                    mainAxisSpacing: spacing,
                                    childAspectRatio: isMobile ? 0.85 : 0.78,
                                  ),
                                  delegate: SliverChildBuilderDelegate(
                                    (context, i) => _buildFeedCard(feed[i + 1]),
                                    childCount: feed.length - 1,
                                  ),
                                ),
                                const SliverToBoxAdapter(child: SizedBox(height: 40)),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  // -- Spotlight Card ---------------------------------------------------------
  Widget _buildSpotlightCard(Map<String, dynamic> item) {
    final bool esVideo  = item['tipo'] == 'video';
    final String titulo = item['titulo'] as String? ?? '';
    final String frag   = item['fragmento'] as String? ?? '';
    final String fuente = item['fuente'] as String? ?? '';
    final String imagen = item['imagen'] as String? ?? '';
    final String fechaL = item['fecha_legible'] as String? ?? '';

    return GestureDetector(
      onTap: () => _abrirItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg.withOpacity(0.4),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: LayoutBuilder(
            builder: (context, bc) {
              final bool isWide = bc.maxWidth > 700;
              final imageWidget = _buildImageStack(imagen, esVideo, isWide: isWide);
              final contentWidget = Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Badge destacado
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.amber.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 11),
                          const SizedBox(width: 4),
                          Text(
                            esVideo ? 'VIDEO DESTACADO' : 'NOTA DESTACADA',
                            style: const TextStyle(
                              color: Colors.amber, fontWeight: FontWeight.w900,
                              fontSize: 8, letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      titulo,
                      style: GoogleFonts.outfit(
                        color: Colors.white, fontSize: isWide ? 22 : 17,
                        fontWeight: FontWeight.bold, height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      frag,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12.5, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: cyanColor.withOpacity(0.12),
                              radius: 11,
                              child: Icon(
                                esVideo ? Icons.play_circle_outline : Icons.edit_note,
                                color: cyanColor, size: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(fuente, style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                        Text(fechaL, style: TextStyle(color: Colors.white30, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              );

              if (isWide) {
                return Row(
                  children: [
                    Expanded(flex: 6, child: SizedBox(height: 260, child: imageWidget)),
                    Expanded(flex: 5, child: contentWidget),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 180, width: double.infinity, child: imageWidget),
                  contentWidget,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // -- Feed card (grid) -------------------------------------------------------
  Widget _buildFeedCard(Map<String, dynamic> item) {
    final bool esVideo  = item['tipo'] == 'video';
    final String titulo = item['titulo'] as String? ?? '';
    final String frag   = item['fragmento'] as String? ?? '';
    final String fuente = item['fuente'] as String? ?? '';
    final String imagen = item['imagen'] as String? ?? '';
    final String fechaL = item['fecha_legible'] as String? ?? '';
    final String cat    = item['categoria'] as String? ?? (esVideo ? 'Video' : 'Nota');

    return GestureDetector(
      onTap: () => _abrirItem(item),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg.withOpacity(0.4),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.06)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen
              Expanded(
                flex: 4,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildCachedImage(imagen),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withOpacity(0.75)],
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                    if (esVideo)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.9),
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.4), blurRadius: 10)],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    Positioned(
                      left: 10, bottom: 10,
                      child: Row(
                        children: [
                          _buildBadge(cat.toUpperCase(), cyanColor),
                          if (esVideo) ...[
                            const SizedBox(width: 6),
                            _buildBadge('VIDEO', Colors.red),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Texto
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        frag,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, height: 1.3),
                      ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            CircleAvatar(
                              backgroundColor: cyanColor.withOpacity(0.08),
                              radius: 8,
                              child: Icon(
                                esVideo ? Icons.play_circle_outline : Icons.edit_note,
                                color: cyanColor, size: 10,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                fuente, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.white60, fontSize: 10),
                              ),
                            ),
                          ]),
                          Text(fechaL, style: TextStyle(color: Colors.white30, fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -- Helpers de imagen -----------------------------------------------------
  Widget _buildImageStack(String imagen, bool esVideo, {bool isWide = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildCachedImage(imagen),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(isWide ? 0.4 : 0.85)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        if (esVideo)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.9),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.5), blurRadius: 15, spreadRadius: 2)],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
            ),
          ),
      ],
    );
  }

  Widget _buildCachedImage(String url) {
    if (url.isEmpty) {
      return Container(
        color: cardBg,
        child: const Icon(Icons.image_not_supported_outlined, color: Colors.white12, size: 40),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(
        color: cardBg,
        child: const Center(child: CircularProgressIndicator(color: cyanColor, strokeWidth: 1.5)),
      ),
      errorWidget: (_, __, ___) => Container(
        color: cardBg,
        child: const Icon(Icons.broken_image_outlined, color: Colors.white12, size: 40),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.85),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color == cyanColor ? Colors.black : Colors.white,
          fontWeight: FontWeight.bold, fontSize: 8,
        ),
      ),
    );
  }

  // -- Abrir ítem -------------------------------------------------------------
  void _abrirItem(Map<String, dynamic> item) {
    final bool desdeBD  = item['desde_bd'] == true;
    final String? artId = item['articulo_id'] as String?;
    final String tipo   = item['tipo'] as String? ?? '';
    final String url    = item['url'] as String? ?? '';

    // Artículos de la base de datos de Supabase ? pantalla de detalle completa
    if (desdeBD && artId != null && artId.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ArticuloDetalleScreen(articuloId: artId)),
      );
      return;
    }

    // Videos de YouTube ? reproductor INLINE (sin salir de la app)
    if (tipo == 'video') {
      if (url.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => YoutubePlayerScreen(
              videoUrl: url,
              titulo: item['titulo'] as String? ?? '',
              descripcion: item['fragmento'] as String? ?? '',
              fuente: item['fuente'] as String? ?? '',
              fechaLegible: item['fecha_legible'] as String? ?? '',
            ),
          ),
        );
      }
      return;
    }

    // Notas de revistas web ? abrir en pantalla de lectura offline
    // (muestra el texto guardado si hay señal o no)
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ArticuloOfflineScreen(articulo: item),
      ),
    );
  }

  // -------------------------------------------------------------------------
  //  TAB 2: COMUNIDAD (piques de usuarios)
  // -------------------------------------------------------------------------
  Widget _buildComunidadTab() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cyanColor));
    }

    final reviews = _reviews.where((r) {
      final aspectos  = r['aspectos_puntuados'] as Map<String, dynamic>? ?? {};
      final comentario = r['comentario'] as String? ?? '';
      if (_searchText.isNotEmpty) {
        final especie = (aspectos['especie_capturada'] as String? ?? '').toLowerCase();
        final zona    = (aspectos['destino_zona'] as String? ?? '').toLowerCase();
        return especie.contains(_searchText) ||
               comentario.toLowerCase().contains(_searchText) ||
               zona.contains(_searchText);
      }
      return true;
    }).toList();

    if (reviews.isEmpty) {
      return _buildEmptyState(
        _haySenal
            ? 'Aún no hay piques de la comunidad cargados.'
            : '?? Sin señal  los piques de la comunidad\nse muestran cuando hay caché guardado.',
        icono: Icons.people_outline,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          itemCount: reviews.length,
          itemBuilder: (context, i) => _buildReviewCard(review: reviews[i]),
        ),
      ),
    );
  }

  // -- Review Card -----------------------------------------------------------
  Widget _buildReviewCard({required Map<String, dynamic> review, bool showBadge = false}) {
    final aspectos  = review['aspectos_puntuados'] as Map<String, dynamic>? ?? {};
    final especie   = aspectos['especie_capturada'] as String? ?? 'Pesca Variada';
    final peso      = aspectos['peso_captura'];
    final fotos     = aspectos['fotos_capturas'] as List? ?? [];
    final comentario = review['comentario'] as String? ?? '';
    final rating    = (review['calificacion'] as num? ?? 5).toInt();
    final zona      = aspectos['destino_zona'] as String? ?? 'Zona del Río';
    final fechaStr  = review['created_at'] as String? ?? '';

    String fechaF = 'Reciente';
    if (fechaStr.isNotEmpty) {
      try { fechaF = DateFormat('dd MMM yyyy').format(DateTime.parse(fechaStr)); } catch (_) {}
    }
    final String? fotoUrl = fotos.isNotEmpty ? fotos.first as String? : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                CircleAvatar(
                  backgroundColor: cyanColor.withOpacity(0.1),
                  radius: 16,
                  child: Icon(Icons.person, color: cyanColor, size: 16),
                ),
                const SizedBox(width: 8),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Pescador Deportivo',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  Text('?? $zona',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
                ]),
              ]),
              Text(fechaF, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 12),
          if (fotoUrl != null) ...[
            GestureDetector(
              onTap: () => _mostrarZoomFoto(fotoUrl),
              child: Container(
                height: 160, width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _buildCachedImage(fotoUrl),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                _buildBadge(especie.toUpperCase(), accentColor),
                if (peso != null) ...[
                  const SizedBox(width: 6),
                  _buildBadge('$peso KG', cyanColor),
                ],
              ]),
              Row(
                children: List.generate(5, (si) => Icon(
                  Icons.anchor, size: 14,
                  color: si < rating ? cyanColor : Colors.white10,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comentario.isNotEmpty ? comentario : '¡Gran jornada de pesca!',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12.5, height: 1.3),
          ),
        ]),
      ),
    );
  }

  // -- Empty state -----------------------------------------------------------
  Widget _buildEmptyState(String mensaje, {IconData icono = Icons.waves_rounded, Color color = Colors.white}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 52, color: color.withOpacity(0.15)),
            const SizedBox(height: 16),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(color: color.withOpacity(0.5), fontSize: 14, height: 1.5),
            ),
            if (_haySenal) ...[
              const SizedBox(height: 24),
              SafeElevatedIconButton(
  onPressed: () => _cargarFeed(forzar: true),
  icon: Icons.refresh,
  label: 'Reintentar',
  style: ElevatedButton.styleFrom(
                  backgroundColor: cyanColor.withOpacity(0.15),
                  foregroundColor: cyanColor,
                  side: BorderSide(color: cyanColor.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
),
            ],
          ],
        ),
      ),
    );
  }

  // -- Zoom foto -------------------------------------------------------------
  void _mostrarZoomFoto(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(imageUrl: url),
              ),
            ),
            Positioned(
              top: 10, right: 10,
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.6),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
