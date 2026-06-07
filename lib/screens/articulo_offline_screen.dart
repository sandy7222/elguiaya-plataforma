import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';

/// Pantalla de lectura de un artículo de revista guardado localmente (offline).
/// Recibe los datos completos del artículo como un Map y los muestra sin
/// necesidad de ninguna conexión a internet.
class ArticuloOfflineScreen extends StatelessWidget {
  final Map<String, dynamic> articulo;

  const ArticuloOfflineScreen({super.key, required this.articulo});

  // ─── Colores ──────────────────────────────────────────────────────────────
  static const Color _darkBg   = Color(0xFF0A0E12);
  static const Color _cardBg   = Color(0xFF0F172A);
  static const Color _cyan     = Color(0xFF00E5FF);
  static const Color _verde    = Color(0xFF00E676);

  @override
  Widget build(BuildContext context) {
    final String titulo     = articulo['titulo']     as String? ?? '';
    final String fragmento  = articulo['fragmento']  as String? ?? '';
    final String fuente     = articulo['fuente']     as String? ?? '';
    final String imagen     = articulo['imagen']     as String? ?? '';
    final String url        = articulo['url']        as String? ?? '';
    final String fechaL     = articulo['fecha_legible'] as String? ?? '';
    final String contenido  = articulo['contenido_completo'] as String? ?? '';
    final bool   tieneTexto = contenido.isNotEmpty;

    return Scaffold(
      backgroundColor: _darkBg,
      body: CustomScrollView(
        slivers: [
          // ── Portada colapsable ──────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            stretch: true,
            backgroundColor: _darkBg,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black.withOpacity(0.55),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              // Indicador "Sin señal requerida"
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Chip(
                  label: const Text('📴 Offline', style: TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: Colors.orange.withOpacity(0.25),
                  side: BorderSide(color: Colors.orange.withOpacity(0.4)),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground, StretchMode.blurBackground],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  if (imagen.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: imagen,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: _cardBg),
                    )
                  else
                    Container(color: _cardBg),
                  // Degradado inferior
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.transparent, _darkBg],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.4, 1.0],
                      ),
                    ),
                  ),
                  // Badge de fuente (revista de origen)
                  if (fuente.isNotEmpty)
                    Positioned(
                      left: 20,
                      bottom: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _cyan.withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.newspaper_outlined, size: 12, color: Colors.black),
                            const SizedBox(width: 5),
                            Text(
                              fuente.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
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

          // ── Cuerpo del artículo ─────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Título
                Text(
                  titulo,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Fuente + fecha
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: _cyan.withOpacity(0.12),
                      radius: 14,
                      child: const Icon(Icons.newspaper_outlined, color: _cyan, size: 15),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fuente,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          fechaL,
                          style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),

                const Divider(height: 32, color: Colors.white10),

                // ── Contenido del artículo ─────────────────────────────────
                if (tieneTexto) ...[
                  ..._buildContenido(contenido),
                ] else ...[
                  // Sin texto guardado: mostrar fragmento + botón leer online
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.orange, size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Contenido no guardado localmente',
                              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Este artículo fue sincronizado sin texto completo. '
                          'Usá el botón ☁️ en la pantalla del blog para descargar los artículos completos antes de salir a la isla.',
                          style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Fragmento disponible
                  Text(
                    fragmento,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 14, height: 1.5),
                  ),
                ],

                const SizedBox(height: 28),
                const Divider(color: Colors.white10),
                const SizedBox(height: 16),

                // ── Botón ver en revista original ─────────────────────────
                if (url.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _cyan,
                      side: BorderSide(color: _cyan.withOpacity(0.4)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    ),
                    icon: const Icon(Icons.open_in_browser, size: 18),
                    label: Text(
                      'Ver en ${fuente.isNotEmpty ? fuente : "la revista original"}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () async {
                      final uri = Uri.parse(url);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Parser de contenido (mismo estilo que ArticuloDetalleScreen) ──────────
  List<Widget> _buildContenido(String contenido) {
    final lineas = contenido.split('\n');
    final widgets = <Widget>[];
    for (final linea in lineas) {
      final t = linea.trim();
      if (t.startsWith('# ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 20, bottom: 8),
          child: Text(
            t.substring(2),
            style: GoogleFonts.outfit(color: _cyan, fontSize: 19, fontWeight: FontWeight.bold, height: 1.25),
          ),
        ));
      } else if (t.startsWith('## ')) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 6),
          child: Text(
            t.substring(3),
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ));
      } else if (t.startsWith('*') && t.endsWith('*') && t.length > 2) {
        // Descripción en cursiva
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            t.replaceAll('*', ''),
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ));
      } else if (t.isEmpty) {
        widgets.add(const SizedBox(height: 6));
      } else {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            t,
            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 14, height: 1.55),
          ),
        ));
      }
    }
    return widgets;
  }
}
