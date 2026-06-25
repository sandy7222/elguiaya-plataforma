import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_catalogo_screen.dart';
import 'admin_categorias_screen.dart';
import 'admin_inventario_screen.dart';
import 'admin_pedidos_screen.dart';
import 'admin_envios_screen.dart';
import 'admin_banners_screen.dart';
import 'admin_blog_screen.dart';
import 'admin_atributos_screen.dart';
import 'categories_grid_screen.dart';

class AdminTiendaTab extends StatelessWidget {
  const AdminTiendaTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _buildSectionHeader('🛒 MÓDULO TIENDA', 'Catálogo, pedidos, inventario y contenido'),
        const SizedBox(height: 16),

        // Vista previa de la tienda
        _buildStorePreviewCard(context),
        const SizedBox(height: 16),

        // Grilla 2x2 de accesos rápidos
        _buildSectionTitle('GESTIÓN DE PRODUCTOS'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _buildGridCard(
              context,
              icon: Icons.inventory_2_rounded,
              color: const Color(0xFF6B73FF),
              title: 'Catálogo',
              subtitle: 'Administrar productos',
              screen: const AdminCatalogoScreen(),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildGridCard(
              context,
              icon: Icons.category_rounded,
              color: const Color(0xFFFF922B),
              title: 'Categorías',
              subtitle: 'Jerarquía de rubros',
              screen: const AdminCategoriasScreen(),
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildGridCard(
              context,
              icon: Icons.warehouse_rounded,
              color: const Color(0xFFFF6B6B),
              title: 'Inventario',
              subtitle: 'Control de stock',
              screen: const AdminInventarioScreen(),
            )),
            const SizedBox(width: 12),
            Expanded(child: _buildGridCard(
              context,
              icon: Icons.text_snippet_rounded,
              color: const Color(0xFF0D47A1),
              title: 'Diccionario',
              subtitle: 'Atributos técnicos',
              screen: const AdminAtributosScreen(),
            )),
          ],
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('PEDIDOS Y LOGÍSTICA'),
        const SizedBox(height: 10),
        _buildNavCard(
          context,
          icon: Icons.shopping_cart_rounded,
          color: const Color(0xFF4ECDC4),
          title: 'Gestión de Pedidos',
          subtitle: 'Ver y procesar pedidos de la tienda',
          screen: const AdminPedidosScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF45B7D1),
          title: 'Envíos y Trazabilidad',
          subtitle: 'Seguimiento de entregas en curso',
          screen: const AdminEnviosScreen(),
        ),

        const SizedBox(height: 20),
        _buildSectionTitle('MARKETING Y CONTENIDO'),
        const SizedBox(height: 10),
        _buildNavCard(
          context,
          icon: Icons.view_carousel_rounded,
          color: const Color(0xFF9C27B0),
          title: 'Banners y Publicaciones',
          subtitle: 'Gestionar publicidad y destacados',
          screen: const AdminBannersScreen(),
        ),
        _buildNavCard(
          context,
          icon: Icons.article_rounded,
          color: const Color(0xFF00B0FF),
          title: 'Blog de Pesca',
          subtitle: 'Artículos — redacción asistida por IA (Groq)',
          screen: const AdminBlogScreen(),
        ),
      ],
    );
  }

  Widget _buildStorePreviewCard(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const CategoriesGridScreen())),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6B73FF).withOpacity(0.2),
              const Color(0xFF9C27B0).withOpacity(0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF6B73FF).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.storefront_rounded, color: Color(0xFF6B73FF), size: 32),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ver Tienda como Cliente',
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Vista espejo de la tienda pública',
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: Colors.white38, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: GoogleFonts.outfit(
            color: Colors.white54, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5));
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: GoogleFonts.outfit(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1)),
        const SizedBox(height: 4),
        Text(subtitle,
            style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
      ],
    );
  }

  Widget _buildGridCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const Spacer(),
            Text(title,
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            Text(subtitle,
                style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildNavCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required Widget screen,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => screen)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.outfit(
                          color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle,
                      style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }
}
