import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/admin_service.dart';
import '../services/postulaciones_service.dart';
import '../theme/admin_theme.dart';

class AdminPostulantesScreen extends StatefulWidget {
  const AdminPostulantesScreen({super.key});

  @override
  State<AdminPostulantesScreen> createState() => _AdminPostulantesScreenState();
}

class _AdminPostulantesScreenState extends State<AdminPostulantesScreen> {
  final _busquedaCtrl = TextEditingController();
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String _estado = 'todas';
  String _area = 'todas';
  int _nuevas = 0;

  static const _estados = [
    'todas',
    'nueva',
    'en_revision',
    'contactado',
    'entrevista',
    'descartado',
    'contratado',
  ];

  static const _areas = [
    'todas',
    'Promotor de Ventas',
    'Guía / Capitán',
    'Logística y Operaciones',
    'Administración',
    'Tecnología y Diseño',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _loading = true);
    try {
      final rows = await PostulacionesService.listarAdmin(
        estado: _estado,
        area: _area,
        busqueda: _busquedaCtrl.text,
      );
      final nuevas = await PostulacionesService.contarNuevas();
      if (!mounted) return;
      setState(() {
        _items = rows;
        _nuevas = nuevas;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar postulantes: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'nueva':
        return const Color(0xFF00E676);
      case 'en_revision':
        return Colors.amber;
      case 'contactado':
        return Colors.lightBlueAccent;
      case 'entrevista':
        return Colors.purpleAccent;
      case 'contratado':
        return Colors.tealAccent;
      case 'descartado':
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  Future<void> _abrirCv(Map<String, dynamic> p) async {
    final path = p['cv_path']?.toString();
    if (path == null || path.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esta postulación no tiene CV'), backgroundColor: Colors.orange),
      );
      return;
    }
    try {
      final url = await PostulacionesService.urlCvFirmada(path);
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir el CV'), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir CV: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  Future<void> _mostrarDetalle(Map<String, dynamic> p) async {
    final notasCtrl = TextEditingController(text: p['notas_admin']?.toString() ?? '');
    String estadoSel = p['estado']?.toString() ?? 'nueva';
    final df = DateFormat('dd/MM/yyyy HH:mm');

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.deepNavy,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      p['nombre']?.toString() ?? 'Postulante',
                      style: GoogleFonts.outfit(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text(p['email']?.toString() ?? '', style: const TextStyle(color: Colors.white70)),
                    Text(p['telefono']?.toString() ?? '', style: const TextStyle(color: Colors.white54)),
                    const SizedBox(height: 8),
                    Text('Área: ${p['area_interes'] ?? '-'}', style: const TextStyle(color: Color(0xFF00E676))),
                    Text(
                      'Fecha: ${p['created_at'] != null ? df.format(DateTime.parse(p['created_at']).toLocal()) : '-'}',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    if ((p['presentacion']?.toString() ?? '').isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(p['presentacion'].toString(), style: const TextStyle(color: Colors.white70, height: 1.4)),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => _abrirCv(p),
                      icon: const Icon(Icons.download_rounded, color: Color(0xFF00E676)),
                      label: Text(
                        'Ver / Descargar CV${p['cv_nombre_original'] != null ? ' (${p['cv_nombre_original']})' : ''}',
                        style: const TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Estado', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: estadoSel,
                      dropdownColor: const Color(0xFF001A33),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _estados
                          .where((e) => e != 'todas')
                          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setSheet(() => estadoSel = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: notasCtrl,
                      maxLines: 3,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Notas internas',
                        labelStyle: const TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          try {
                            await PostulacionesService.actualizarEstado(
                              id: p['id'].toString(),
                              estado: estadoSel,
                              notasAdmin: notasCtrl.text.trim(),
                            );
                            await AdminService.registrarAccion(
                              'actualizar_postulacion',
                              'postulaciones',
                              p['id']?.toString(),
                              {'estado': estadoSel},
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            await _cargar();
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('GUARDAR', style: TextStyle(fontWeight: FontWeight.bold)),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.deepNavy,
      appBar: AppBar(
        backgroundColor: AdminTheme.deepNavy,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Postulantes y CV', style: GoogleFonts.outfit(fontWeight: FontWeight.w800)),
            if (_nuevas > 0)
              Text('$_nuevas nueva(s)', style: const TextStyle(color: Color(0xFF00E676), fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(onPressed: _cargar, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: [
                TextField(
                  controller: _busquedaCtrl,
                  style: const TextStyle(color: Colors.white),
                  onSubmitted: (_) => _cargar(),
                  decoration: InputDecoration(
                    hintText: 'Buscar por nombre, email o teléfono',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.search, color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.filter_alt, color: Color(0xFF00E676)),
                      onPressed: _cargar,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _estado,
                        dropdownColor: const Color(0xFF001A33),
                        decoration: InputDecoration(
                          labelText: 'Estado',
                          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _estados
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 13))))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _estado = v);
                          _cargar();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _area,
                        dropdownColor: const Color(0xFF001A33),
                        decoration: InputDecoration(
                          labelText: 'Área',
                          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.06),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _areas
                            .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() => _area = v);
                          _cargar();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : _items.isEmpty
                    ? Center(
                        child: Text('Sin postulaciones', style: GoogleFonts.outfit(color: Colors.white54)),
                      )
                    : RefreshIndicator(
                        color: const Color(0xFF00E676),
                        onRefresh: _cargar,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _items.length,
                          itemBuilder: (context, i) {
                            final p = _items[i];
                            final estado = p['estado']?.toString() ?? '';
                            final isNueva = estado == 'nueva';
                            return GestureDetector(
                              onTap: () => _mostrarDetalle(p),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isNueva
                                      ? const Color(0xFF00E676).withOpacity(0.08)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isNueva
                                        ? const Color(0xFF00E676).withOpacity(0.45)
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: _colorEstado(estado),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p['nombre']?.toString() ?? '-',
                                            style: GoogleFonts.outfit(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            '${p['area_interes'] ?? '-'} · ${p['email'] ?? ''}',
                                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      estado,
                                      style: TextStyle(
                                        color: _colorEstado(estado),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right, color: Colors.white24),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
