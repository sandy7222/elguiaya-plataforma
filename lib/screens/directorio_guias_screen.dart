
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectorioGuiasScreen extends StatefulWidget {
  const DirectorioGuiasScreen({super.key});

  @override
  State<DirectorioGuiasScreen> createState() => _DirectorioGuiasScreenState();
}

class _DirectorioGuiasScreenState extends State<DirectorioGuiasScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _guias = [];

  @override
  void initState() {
    super.initState();
    _cargarGuias();
  }

  Future<void> _cargarGuias() async {
    try {
      // Cargamos solo capitanes activos
      final data = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('es_capitan', true)
          .eq('estado', 'activo');

      if (mounted) {
        setState(() {
          _guias = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar guías: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('GUÍAS Y CAPITANES', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
        : _guias.isEmpty
          ? const Center(child: Text('No hay capitanes disponibles en este momento.', style: TextStyle(color: Colors.white70)))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _guias.length,
              itemBuilder: (context, index) {
                final guia = _guias[index];
                return _buildCapitanCard(guia);
              },
            ),
    );
  }

  Widget _buildCapitanCard(Map<String, dynamic> guia) {
    final bool ofreceCarnada = (guia['servicio_carnada'] ?? 'No') != 'No';
    final bool ofreceLenia = guia['servicio_lenia'] ?? false;
    final bool ofreceAlmacen = guia['servicio_almacen'] ?? false;
    
    // Decodificar nuevos servicios en bio_pescador
    bool ofreceCabania = false;
    bool ofreceBanio = false;
    bool ofreceParrilla = false;
    String bioTexto = '';
    
    final bioRaw = guia['bio_pescador']?.toString() ?? '';
    if (bioRaw.startsWith('{')) {
      try {
        final Map<String, dynamic> jsonBio = jsonDecode(bioRaw);
        ofreceCabania = jsonBio['cabania'] ?? false;
        ofreceBanio = jsonBio['banio'] ?? false;
        ofreceParrilla = jsonBio['parrilla'] ?? false;
      } catch (_) {
        bioTexto = bioRaw;
      }
    } else {
      bioTexto = bioRaw;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen de Embarcación con Avatar superpuesto
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  image: guia['embarcacion_url'] != null 
                    ? DecorationImage(image: NetworkImage(guia['embarcacion_url']), fit: BoxFit.cover)
                    : guia['avatar_url'] != null 
                      ? DecorationImage(image: NetworkImage(guia['avatar_url']), fit: BoxFit.cover)
                      : null,
                ),
                child: (guia['embarcacion_url'] == null && guia['avatar_url'] == null) 
                  ? const Icon(Icons.sailing, color: Colors.white24, size: 80)
                  : null,
              ),
              // Avatar Circular Destacado
              Positioned(
                bottom: -30,
                left: 20,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Color(0xFF001F3F), shape: BoxShape.circle),
                  child: CircleAvatar(
                    radius: 35,
                    backgroundColor: const Color(0xFF0D47A1),
                    backgroundImage: guia['avatar_url'] != null ? NetworkImage(guia['avatar_url']) : null,
                    child: guia['avatar_url'] == null ? const Icon(Icons.person, color: Colors.white, size: 30) : null,
                  ),
                ),
              ),
            ],
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 45, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        (guia['nombre'] ?? 'Capitán').toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E676).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text('ACTIVO', style: TextStyle(color: Color(0xFF00E676), fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Descripción de Servicios (las 100 palabras o el JSON fallido)
                if (bioTexto.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      bioTexto,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontStyle: FontStyle.italic),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                Text(
                  'Embarcación: ${guia['nombre_embarcacion'] ?? 'No declarada'}',
                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                
                // Especificaciones Técnicas
                Row(
                  children: [
                    _buildSpec(Icons.groups, '${guia['capacidad_personas'] ?? 0} pers'),
                    const SizedBox(width: 16),
                    _buildSpec(Icons.scale, '${guia['capacidad_kilos'] ?? 0} kg'),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(color: Colors.white12),
                const SizedBox(height: 10),
                
                // Servicios Adicionales
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    if (ofreceCarnada) _buildServiceIcon(Icons.phishing, 'Carnada'),
                    if (ofreceLenia) _buildServiceIcon(Icons.fireplace, 'Leña'),
                    if (ofreceAlmacen) _buildServiceIcon(Icons.shopping_basket, 'Almacén'),
                    if (ofreceCabania) _buildServiceIcon(Icons.house, 'Cabaña'),
                    if (ofreceBanio) _buildServiceIcon(Icons.wc, 'Baño'),
                    if (ofreceParrilla) _buildServiceIcon(Icons.outdoor_grill, 'Parrilla'),
                    if (!ofreceCarnada && !ofreceLenia && !ofreceAlmacen && !ofreceCabania && !ofreceBanio && !ofreceParrilla)
                      const Text('Servicios base de navegación', style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Botón de Acción
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // Lógica para contactar/reservar
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Text('CONSULTAR DISPONIBILIDAD', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpec(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E676), size: 16),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildServiceIcon(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: Column(
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ],
      ),
    );
  }
}
