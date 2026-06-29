import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import 'capitan_vidriera_screen.dart';

class CapitanPerfilEditScreen extends StatefulWidget {
  const CapitanPerfilEditScreen({super.key});

  @override
  State<CapitanPerfilEditScreen> createState() =>
      _CapitanPerfilEditScreenState();
}

class _CapitanPerfilEditScreenState extends State<CapitanPerfilEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controladores
  final _capacidadKilosController = TextEditingController();
  final _capacidadPersonasController = TextEditingController();

  // Estados de servicios
  String _servicioCarnada = 'No';
  bool _servicioLenia = false;
  bool _servicioAlmacen = false;
  
  // Nuevos servicios extra en JSON
  bool _servicioCabania = false;
  bool _servicioBanio = false;
  bool _servicioParrilla = false;
  
  // Foto embarcacion
  String? _embarcacionUrl;

  // Vidriera (kiosko)
  int _vidrieraTotalProductos = 0;
  int _vidrieraProductosActivos = 0;

  @override
  void initState() {
    super.initState();
    _cargarDatosPerfil();
  }

  Future<void> _cargarDatosPerfil() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final perfil = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('user_id', user.id)
          .single();

      if (mounted) {
        setState(() {
          _capacidadKilosController.text = (perfil['capacidad_kilos'] ?? 0)
              .toString();
          _capacidadPersonasController.text =
              (perfil['capacidad_personas'] ?? 0).toString();
          _servicioCarnada = perfil['servicio_carnada'] ?? 'No';
          _servicioLenia = perfil['servicio_lenia'] ?? false;
          _servicioAlmacen = perfil['servicio_almacen'] ?? false;
          _embarcacionUrl = perfil['embarcacion_url'];
          
          final bio = perfil['bio_pescador'] ?? '';
          try {
            if (bio.toString().startsWith('{')) {
              final jsonBio = jsonDecode(bio);
              _servicioCabania = jsonBio['cabania'] ?? false;
              _servicioBanio = jsonBio['banio'] ?? false;
              _servicioParrilla = jsonBio['parrilla'] ?? false;
            }
          } catch (_) {}
          _isLoading = false;
        });
      }

      await _cargarResumenVidriera(user.id);
    } catch (e) {
      print('Error al cargar perfil: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cargarResumenVidriera(String userId) async {
    try {
      final productos = await Supabase.instance.client
          .from('kiosko_capitan')
          .select('activo')
          .eq('capitan_id', userId);

      final lista = List<Map<String, dynamic>>.from(productos);
      final activos = lista.where((p) => p['activo'] == true).length;

      if (mounted) {
        setState(() {
          _vidrieraTotalProductos = lista.length;
          _vidrieraProductosActivos = activos;
        });
      }
    } catch (_) {
      // Silencioso: el resumen es informativo
    }
  }

  Future<void> _abrirGestionVidriera() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CapitanVidrieraScreen()),
    );
    if (!mounted) return;
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) await _cargarResumenVidriera(user.id);
  }

  Future<void> _guardarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      Map<String, dynamic> jsonBioMap = {
        'cabania': _servicioCabania,
        'banio': _servicioBanio,
        'parrilla': _servicioParrilla,
      };
      try {
        final originalPerfil = await Supabase.instance.client
            .from('profiles')
            .select('bio_pescador')
            .eq('user_id', user.id)
            .single();
        final originalBio = originalPerfil['bio_pescador'] ?? '';
        if (originalBio.toString().startsWith('{')) {
          final jsonBio = jsonDecode(originalBio.toString());
          if (jsonBio['guia_memoria'] != null) {
            jsonBioMap['guia_memoria'] = jsonBio['guia_memoria'];
          }
        }
      } catch (_) {}
      final jsonBio = jsonEncode(jsonBioMap);

      final data = {
        'capacidad_personas': int.tryParse(_capacidadPersonasController.text) ?? 0,
        'capacidad_kilos': int.tryParse(_capacidadKilosController.text) ?? 0,
        'servicio_carnada': _servicioCarnada,
        'servicio_lenia': _servicioLenia,
        'servicio_almacen': _servicioAlmacen,
        'bio_pescador': jsonBio,
        'embarcacion_url': _embarcacionUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Actualizar en profiles y guias (sincronizado)
      final dataGuias = {
        'capacidad_personas': int.tryParse(_capacidadPersonasController.text) ?? 0,
        'capacidad_kilos': int.tryParse(_capacidadKilosController.text) ?? 0,
        'servicio_carnada': _servicioCarnada,
        'servicio_lenia': _servicioLenia,
        'servicio_almacen': _servicioAlmacen,
        'especialidad': jsonBio,
        'embarcacion_url': _embarcacionUrl,
      };
      await Supabase.instance.client
          .from('profiles')
          .update(data)
          .eq('user_id', user.id);
      
      await Supabase.instance.client
          .from('guias')
          .update(dataGuias)
          .eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Declaración de Servicio actualizada con éxito!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _seleccionarFotoEmbarcacion() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image == null) return;

      setState(() => _isSaving = true);

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final url = await StorageService.uploadXFile(
        xFile: image,
        bucket: 'fotos_perfil',
        folderPath: user.id,
        fileNamePrefix: 'embarcacion',
      );

      setState(() {
        _embarcacionUrl = url;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Foto de embarcación subida con éxito'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text(
          'DECLARACIÓN DE SERVICIO',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('DATOS TÉCNICOS DE EMBARCACIÓN'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Capacidad Personas',
                          _capacidadPersonasController,
                          Icons.groups,
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          'Carga Neta Máxima (Kilos)',
                          _capacidadKilosController,
                          Icons.scale,
                        ),

                        _buildDropdownField(
                          '¿Ofrece Carnada?',
                          _servicioCarnada,
                          ['No', 'Si - Incluida', 'Si - Para la venta'],
                          (val) {
                            setState(() => _servicioCarnada = val!);
                          },
                        ),

                        _buildSwitchField(
                          '¿Ofrece Leña para acampar?',
                          _servicioLenia,
                          (val) {
                            setState(() => _servicioLenia = val);
                          },
                          Icons.fireplace,
                        ),

                        _buildSwitchField(
                          '¿Ofrece Almacén / Provisiones?',
                          _servicioAlmacen,
                          (val) {
                            setState(() => _servicioAlmacen = val);
                          },
                          Icons.shopping_basket,
                        ),

                        _buildSwitchField(
                          '¿Ofrece Cabaña? (Precio a convenir)',
                          _servicioCabania,
                          (val) {
                            setState(() => _servicioCabania = val);
                          },
                          Icons.house,
                        ),

                        _buildSwitchField(
                          '¿Tiene Baño?',
                          _servicioBanio,
                          (val) {
                            setState(() => _servicioBanio = val);
                          },
                          Icons.wc,
                        ),

                        _buildSwitchField(
                          '¿Tiene Parrilla?',
                          _servicioParrilla,
                          (val) {
                            setState(() => _servicioParrilla = val);
                          },
                          Icons.outdoor_grill,
                        ),

                        const SizedBox(height: 32),
                        _buildVidrieraSection(),

                        const SizedBox(height: 32),
                        _buildSectionTitle('FOTO DE LA EMBARCACIÓN'),
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: _isSaving ? null : _seleccionarFotoEmbarcacion,
                          child: Container(
                            height: 200,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.white.withOpacity(0.1), width: 2),
                              image: _embarcacionUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(_embarcacionUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _embarcacionUrl == null
                                ? const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.directions_boat, size: 50, color: Colors.white24),
                                      SizedBox(height: 8),
                                      Text('Toca para subir una foto de tu embarcación', style: TextStyle(color: Colors.white54)),
                                    ],
                                  )
                                : Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.edit, color: Colors.white, size: 40),
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 40),
                        SizedBox(
                          width: double.infinity,
                          height: 55,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _guardarPerfil,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00E676),
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isSaving
                                ? const CircularProgressIndicator(
                                    color: Colors.black,
                                  )
                                : const Text(
                                    'GUARDAR CAMBIOS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Center(
                          child: Text(
                            'Esta información será visible para los pescadores en el directorio.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }



  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF00E676),
        fontSize: 13,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildVidrieraSection() {
    final resumen = _vidrieraTotalProductos == 0
        ? 'Sin productos publicados'
        : _vidrieraProductosActivos == _vidrieraTotalProductos
            ? '$_vidrieraProductosActivos producto(s) activo(s)'
            : '$_vidrieraProductosActivos activo(s) de $_vidrieraTotalProductos publicado(s)';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.purpleAccent.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purpleAccent.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Colors.purpleAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle('MI VIDRIERA (KIOSKO)'),
                    const SizedBox(height: 6),
                    Text(
                      'Publicá productos y extras (carnada, leña, alojamiento, etc.) visibles para pescadores.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            resumen,
            style: TextStyle(
              color: _vidrieraTotalProductos > 0
                  ? const Color(0xFF00E676)
                  : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _abrirGestionVidriera,
              icon: const Icon(Icons.inventory_2_outlined, size: 18),
              label: const Text(
                'Gestionar productos',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.purpleAccent,
                side: BorderSide(color: Colors.purpleAccent.withOpacity(0.5)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          prefixIcon: Icon(icon, color: const Color(0xFF00E676)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLockedField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        enabled: false,
        style: const TextStyle(color: Colors.white38),
        decoration: InputDecoration(
          labelText: '$label (No editable)',
          labelStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: Colors.white24),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchField(
    String label,
    bool value,
    Function(bool) onChanged,
    IconData icon,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF00E676)),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white, fontSize: 14),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF00E676),
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: const Color(0xFF001F3F),
              isExpanded: true,
              style: const TextStyle(color: Colors.white),
              items: options
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
