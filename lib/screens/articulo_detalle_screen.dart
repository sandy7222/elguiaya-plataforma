import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/articulo_blog.dart';
import '../models/producto.dart';
import '../services/supabase_service.dart';
import 'product_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

class ArticuloDetalleScreen extends StatefulWidget {
  final String articuloId;

  const ArticuloDetalleScreen({
    super.key,
    required this.articuloId,
  });

  @override
  State<ArticuloDetalleScreen> createState() => _ArticuloDetalleScreenState();
}

class _ArticuloDetalleScreenState extends State<ArticuloDetalleScreen> {
  bool _isLoading = true;
  ArticuloBlog? _articulo;
  List<Producto> _productosSugeridos = [];
  bool _isLoadingProductos = false;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _cargarArticulo();
  }

  @override
  void dispose() {
    _youtubeController?.dispose();
    super.dispose();
  }

  Future<void> _cargarArticulo() async {
    try {
      final art = await SupabaseService.obtenerArticuloBlogPorId(widget.articuloId);
      if (art != null) {
        YoutubePlayerController? ytController;
        if (art.fuenteUrl != null &&
            (art.fuenteUrl!.contains('youtube.com') || art.fuenteUrl!.contains('youtu.be'))) {
          final videoId = YoutubePlayer.convertUrlToId(art.fuenteUrl!);
          if (videoId != null) {
            ytController = YoutubePlayerController(
              initialVideoId: videoId,
              flags: const YoutubePlayerFlags(
                autoPlay: false,
                mute: false,
                disableDragSeek: false,
                loop: false,
                isLive: false,
                forceHD: false,
                enableCaption: true,
              ),
            );
          }
        }

        setState(() {
          _articulo = art;
          _youtubeController = ytController;
          _isLoading = false;
        });
        
        // Cargar productos sugeridos si los hay
        if (art.productosSugeridos.isNotEmpty) {
          setState(() {
            _isLoadingProductos = true;
          });
          final prods = await SupabaseService.getProductosPorIds(art.productosSugeridos);
          setState(() {
            _productosSugeridos = prods;
            _isLoadingProductos = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _mostrarError('No se pudo encontrar el artículo.');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _mostrarError('Error de red al cargar el artículo.');
    }
  }

  void _mostrarError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color darkBg = Color(0xFF0A0E12);
    const Color cardBg = Color(0xFF0F172A);
    const Color cyanColor = Color(0xFF00E5FF);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: darkBg,
        body: Center(
          child: CircularProgressIndicator(color: cyanColor),
        ),
      );
    }

    if (_articulo == null) {
      return Scaffold(
        backgroundColor: darkBg,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Text(
            'Artículo no encontrado',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    final String fecha = DateFormat('dd MMMM, yyyy').format(_articulo!.createdAt);

    return Scaffold(
      backgroundColor: darkBg,
      body: CustomScrollView(
        slivers: [
          // Banner de Portada Colapsable
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: darkBg,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.5),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Hero(
                    tag: 'portada_articulo_${_articulo!.id}',
                    child: Image.network(
                      _articulo!.imagenPortada,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Gradiente para mejorar legibilidad
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent,
                          darkBg,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cuerpo de la Nota
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Categoría e Información
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: cyanColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cyanColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _articulo!.categoria.toUpperCase(),
                        style: const TextStyle(
                          color: cyanColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule, size: 14, color: Colors.white.withValues(alpha: 0.4)),
                    const SizedBox(width: 4),
                    Text(
                      '⏱️ ${_articulo!.minutosLectura} min',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Título Principal
                Text(
                  _articulo!.titulo,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Autor y Fecha
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cyanColor.withValues(alpha: 0.15),
                      radius: 14,
                      child: const Icon(Icons.edit_note, color: cyanColor, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Redactado por ${_articulo!.autor}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          fecha,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 32, color: Colors.white10),

                // Contenido Markdown parseado
                ..._buildParsedContent(_articulo!.contenido),

                const SizedBox(height: 12),
                // Enlace a fuente original si aplica
                if (_articulo!.fuenteUrl != null && _articulo!.fuenteUrl!.isNotEmpty) ...[
                  if (_articulo!.fuenteUrl!.contains('youtube.com') || _articulo!.fuenteUrl!.contains('youtu.be')) ...[
                    if (_youtubeController != null) ...[
                      // Reproductor de YouTube embebido directamente en la aplicación
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: YoutubePlayer(
                            controller: _youtubeController!,
                            showVideoProgressIndicator: true,
                            progressIndicatorColor: Colors.red,
                            progressColors: const ProgressBarColors(
                              playedColor: Colors.red,
                              handleColor: Colors.redAccent,
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Tarjeta de Video Interactiva de YouTube (Fallback)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        width: double.infinity,
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Miniatura del video como fondo
                              Image.network(
                                _articulo!.imagenPortada,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: Colors.white10,
                                  child: const Icon(Icons.video_library, color: Colors.white38, size: 40),
                                ),
                              ),
                              // Filtro oscuro
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withValues(alpha: 0.6),
                                      Colors.black.withValues(alpha: 0.2),
                                      Colors.black.withValues(alpha: 0.7),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                              // Icono de play y etiquetas
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () async {
                                        final uri = Uri.parse(_articulo!.fuenteUrl!);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(40),
                                      child: Container(
                                        height: 60,
                                        width: 60,
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(alpha: 0.9),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.red.withValues(alpha: 0.5),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.play_arrow,
                                          color: Colors.white,
                                          size: 36,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                    child: Text(
                                      'Ver video completo en YouTube',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        shadows: [
                                          const Shadow(
                                            color: Colors.black,
                                            offset: Offset(0, 2),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Canal: ${_articulo!.autor}',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      shadows: [
                                        const Shadow(
                                          color: Colors.black,
                                          offset: Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Distintivo de YouTube en la esquina superior derecha
                              Positioned(
                                top: 12,
                                right: 12,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.video_library, color: Colors.redAccent, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        'YOUTUBE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 9,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Enlace tradicional a fuente de internet
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardBg.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: cyanColor, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Fuente Oficial del Reporte',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _articulo!.fuenteUrl!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 32),

                // Sección Productos Recomendados
                _buildProductosSugeridosSeccion(cardBg, cyanColor),
                
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // --- PARSER DE MARKDOWN CUSTOMIZADO ---
  List<Widget> _buildParsedContent(String content) {
    final List<String> lines = content.split('\n');
    final List<Widget> widgets = [];

    for (final line in lines) {
      widgets.add(_parseLine(line));
    }

    return widgets;
  }

  Widget _parseLine(String line) {
    final trimmed = line.trim();
    if (trimmed.startsWith('# ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 24, bottom: 8),
        child: Text(
          trimmed.substring(2),
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF00E5FF),
          ),
        ),
      );
    } else if (trimmed.startsWith('## ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(
          trimmed.substring(3),
          style: GoogleFonts.outfit(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    } else if (trimmed.startsWith('### ')) {
      return Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(
          trimmed.substring(4),
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
      );
    } else if (trimmed.startsWith('> ')) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: Color(0xFF00E5FF), width: 3),
          ),
        ),
        child: _renderRichText(
          trimmed.substring(2),
          TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 13,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
      );
    } else if (trimmed.startsWith('* ') || trimmed.startsWith('- ')) {
      return Padding(
        padding: const EdgeInsets.only(left: 8, bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 6, right: 8),
              child: Icon(Icons.fiber_manual_record, size: 6, color: Color(0xFF00E5FF)),
            ),
            Expanded(
              child: _renderRichText(
                trimmed.substring(2),
                TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    } else if (trimmed.isEmpty) {
      return const SizedBox(height: 8);
    } else {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: _renderRichText(
          line, // Mantener espaciado original
          TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 13,
            height: 1.45,
          ),
        ),
      );
    }
  }

  Widget _renderRichText(String text, TextStyle baseStyle) {
    final List<String> parts = text.split('**');
    if (parts.length <= 1) {
      return Text(text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: baseStyle.copyWith(
            fontWeight: isBold ? FontWeight.bold : baseStyle.fontWeight,
            color: isBold ? Colors.white : baseStyle.color,
          ),
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans, style: baseStyle),
    );
  }

  // --- SECCION PRODUCTOS RECOMENDADOS ---
  Widget _buildProductosSugeridosSeccion(Color cardBg, Color cyanColor) {
    if (_articulo!.productosSugeridos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: cyanColor, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Equipamiento Sugerido',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_isLoadingProductos)
          SizedBox(
            height: 140,
            child: Center(
              child: CircularProgressIndicator(color: cyanColor),
            ),
          )
        else if (_productosSugeridos.isEmpty)
          Text(
            'No hay productos recomendados cargados en la tienda actualmente.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
          )
        else
          SizedBox(
            height: 150,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _productosSugeridos.length,
              itemBuilder: (context, index) {
                final p = _productosSugeridos[index];

                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(producto: p),
                      ),
                    );
                  },
                  child: Container(
                    width: 140,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: cardBg.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: NetworkImage(p.imagenUrl),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '\$${p.precio.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: cyanColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
