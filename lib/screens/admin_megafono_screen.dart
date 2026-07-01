import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/notificacion_service.dart';
import '../services/supabase_service.dart';

class AdminMegafonoScreen extends StatefulWidget {
  const AdminMegafonoScreen({super.key});

  @override
  State<AdminMegafonoScreen> createState() => _AdminMegafonoScreenState();
}

class _AdminMegafonoScreenState extends State<AdminMegafonoScreen> {
  String _alcance = 'Directo a un Usuario'; 
  String _categoria = 'logistica'; 
  String _prioridad = 'informativa'; 
  
  final _tituloController = TextEditingController();
  final _contenidoController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _selectedUser;
  
  List<Map<String, dynamic>> _todosLosUsuarios = [];

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    try {
      final capitanes = await SupabaseService.getDirectorioCapitanes();
      final pescadores = await SupabaseService.getDirectorioPescadores();
      
      if (mounted) {
        setState(() {
          _todosLosUsuarios = [...capitanes, ...pescadores];
        });
      }
    } catch (e) {
      debugPrint('Error cargando usuarios: $e');
    }
  }

  void _aplicarPlantilla(String tipo) {
    setState(() {
      switch (tipo) {
        case 'Alerta Climática':
          _categoria = 'seguridad';
          _prioridad = 'critica';
          _tituloController.text = '⚠️ Alerta Climática Severa';
          _contenidoController.text = 'Se ha emitido una alerta meteorológica en tu zona. Por favor, tomá precauciones y suspendé salidas si es necesario.';
          break;
        case 'Nuevo Beneficio':
          _categoria = 'comercial';
          _prioridad = 'informativa';
          _tituloController.text = '🎁 Nuevo Beneficio Disponible';
          _contenidoController.text = 'Acabamos de sumar un nuevo descuento en equipo de pesca. ¡Revisá la app para enterarte más!';
          break;
        case 'Recordatorio':
          _categoria = 'logistica';
          _prioridad = 'informativa';
          _tituloController.text = '⚓ Recordatorio de Viaje';
          _contenidoController.text = 'Recordá confirmar la tripulación de tu próxima salida y verificar el clima.';
          break;
      }
    });
  }

  Future<void> _enviarAlerta() async {
    if (_tituloController.text.trim().isEmpty || _contenidoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completá el título y contenido de la alerta.')));
      return;
    }

    if (_alcance == 'Directo a un Usuario' && _selectedUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, seleccioná un destinatario usando el buscador.')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final template = {
        'tipo_actor': 'admin',
        'categoria': _categoria,
        'prioridad': _prioridad,
        'titulo': _tituloController.text.trim(),
        'contenido': _contenidoController.text.trim(),
        'leido': false,
      };

      if (_alcance == 'Directo a un Usuario') {
        template['receptor_id'] = _selectedUser!['user_id'] ?? _selectedUser!['id'];
        await NotificacionService().enviarNotificacion(template);
      } else {
        List<String> receptoresIds = [];
        if (_alcance == 'Masivo: Capitanes') {
          receptoresIds = _todosLosUsuarios
              .where((u) => u['es_capitan'] == true)
              .map((u) => (u['user_id'] ?? u['id']).toString())
              .toList();
        } else if (_alcance == 'Masivo: Pescadores') {
          receptoresIds = _todosLosUsuarios
              .where((u) => u['es_capitan'] == false)
              .map((u) => (u['user_id'] ?? u['id']).toString())
              .toList();
        } else {
          receptoresIds = _todosLosUsuarios
              .map((u) => (u['user_id'] ?? u['id']).toString())
              .toList();
        }
        await NotificacionService().enviarNotificacionMasiva(receptoresIds, template);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('¡Alerta enviada con éxito! 🚀'),
          backgroundColor: Colors.green,
        ));
        _tituloController.clear();
        _contenidoController.clear();
        setState(() {
          _selectedUser = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar alerta: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E12),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Consola del Megáfono', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Plantillas Rápidas
                  Text('Plantillas Rápidas', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildPlantillaChip('Alerta Climática', Colors.redAccent),
                      _buildPlantillaChip('Nuevo Beneficio', Colors.greenAccent),
                      _buildPlantillaChip('Recordatorio', Colors.blueAccent),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Configuración de Destino
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Configuración de Destino', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildDropdown('Alcance', _alcance, ['Directo a un Usuario', 'Masivo: Capitanes', 'Masivo: Pescadores', 'Masivo: Todos'], (v) => setState(() => _alcance = v!)),
                        
                        if (_alcance == 'Directo a un Usuario') ...[
                          const SizedBox(height: 16),
                          Autocomplete<Map<String, dynamic>>(
                            displayStringForOption: (option) => '${option['nombre']} (${option['es_capitan'] == true ? 'Capitán' : 'Pescador'})',
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                              return _todosLosUsuarios.where((u) {
                                final nombre = (u['nombre'] ?? '').toLowerCase();
                                final dni = (u['dni'] ?? '').toString();
                                final query = textEditingValue.text.toLowerCase();
                                return nombre.contains(query) || dni.contains(query);
                              });
                            },
                            onSelected: (selection) => setState(() => _selectedUser = selection),
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextField(
                                controller: controller,
                                focusNode: focusNode,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Buscar por Nombre o DNI',
                                  labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                  prefixIcon: const Icon(Icons.search, color: Colors.cyan),
                                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(12)),
                                  focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.cyan), borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width - 72,
                                    margin: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, index) {
                                        final option = options.elementAt(index);
                                        return ListTile(
                                          title: Text(option['nombre'] ?? 'Sin Nombre', style: const TextStyle(color: Colors.white)),
                                          subtitle: Text(option['es_capitan'] == true ? 'Capitán' : 'Pescador', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                                          onTap: () => onSelected(option),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          if (_selectedUser != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text('Usuario Seleccionado: ${_selectedUser!['nombre']}', style: const TextStyle(color: Colors.cyan, fontWeight: FontWeight.bold)),
                            ),
                        ],
                        
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildDropdown('Categoría', _categoria, ['logistica', 'comercial', 'seguridad', 'marketing'], (v) => setState(() => _categoria = v!))),
                            const SizedBox(width: 16),
                            Expanded(child: _buildDropdown('Prioridad', _prioridad, ['informativa', 'critica', 'historica'], (v) => setState(() => _prioridad = v!))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Mensaje Principal
                  _buildGlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Redacción del Mensaje', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _tituloController,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                          decoration: InputDecoration(
                            labelText: 'Título de la Alerta',
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.cyan), borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _contenidoController,
                          maxLines: 4,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Contenido Detallado',
                            alignLabelWithHint: true,
                            labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)), borderRadius: BorderRadius.circular(12)),
                            focusedBorder: OutlineInputBorder(borderSide: const BorderSide(color: Colors.cyan), borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Botón de Disparo
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _enviarAlerta,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.cyan,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 10,
                        shadowColor: Colors.cyan.withValues(alpha: 0.5),
                      ),
                      child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.black)
                          : Text('DISPARAR ALERTA', style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlantillaChip(String label, Color color) {
    return ActionChip(
      label: Text(
        label,
        style: GoogleFonts.outfit(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
      backgroundColor: Colors.white.withValues(alpha: 0.05),
      surfaceTintColor: Colors.transparent,
      side: BorderSide(color: color.withValues(alpha: 0.5), width: 1.5),
      onPressed: () => _aplicarPlantilla(label),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF0F172A),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.cyan),
              style: const TextStyle(color: Colors.white),
              items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
