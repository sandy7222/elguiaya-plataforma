import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:capitanya_master/services/storage_service.dart';
import 'package:capitanya_master/services/supabase_service.dart';
import 'package:capitanya_master/screens/custom_camera_screen.dart';
import 'package:capitanya_master/screens/custom_crop_screen.dart';

class RegistroCapitanScreen extends StatefulWidget {
  const RegistroCapitanScreen({super.key});

  @override
  State<RegistroCapitanScreen> createState() => _RegistroCapitanScreenState();
}

class _RegistroCapitanScreenState extends State<RegistroCapitanScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controladores
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _dniController = TextEditingController();
  final _calleController = TextEditingController();
  final _alturaController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _cpController = TextEditingController();

  // Archivos
  XFile? _avatarFile, _dniFile, _carnetFile, _seguroFile, _embarcacionFile;
  Uint8List? _avatarBytes, _dniBytes, _carnetBytes, _seguroBytes, _embarcacionBytes;
  
  bool _isSaving = false;

  DateTime? _vencimientoSeguro;
  DateTime? _vencimientoCarnet;

  final _referidoController = TextEditingController();
  bool _traeReferido = false;

  // Colores Premium CapitanYA
  static const Color _capitanAzul = Color(0xFF001F3F);
  static const Color _capitanNaranja = Color(0xFF00E676); // Ahora Verde Premium
  static const Color _capitanAzulClaro = Color(0xFF7FDBFF);
  static const Color _glassColor = Color(0x33FFFFFF);
  static const Color _glassBorder = Color(0x4DFFFFFF);

  @override
  void initState() {
    super.initState();
    _checkLostData();
  }

  Future<void> _checkLostData() async {
    try {
      final ImagePicker picker = ImagePicker();
      final LostDataResponse response = await picker.retrieveLostData();
      if (response.isEmpty) return;
      
      if (response.file != null) {
        // Si recuperamos una foto tras un cierre, necesitamos saber de qué tipo era.
        // Por defecto la asignaremos al último campo intentado o mostraremos un aviso.
        debugPrint('📸 [CAMARA] Foto recuperada tras cierre de app: ${response.file!.path}');
        setState(() {
          // Nota: En una implementacion mas compleja guardamos el tipo en SharedPreferences
          // Por ahora, si recuperamos, la pondremos en el primer campo vacio obligatorio (DNI)
          _dniFile ??= response.file;
        });
      }
    } catch (e) {
      debugPrint('ℹ️ Recuperación de datos perdidos no disponible en esta plataforma: $e');
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _dniController.dispose();
    _calleController.dispose();
    _alturaController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    _cpController.dispose();
    _referidoController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarImagen(String tipo) async {
    final dynamic result = await showModalBottomSheet(
      context: context,
      backgroundColor: _capitanAzul,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('SELECCIONAR ORIGEN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _capitanNaranja),
              title: const Text('Cámara (Sacar foto ahora)', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomCameraScreen(
                      title: 'Capturar ${tipo.toUpperCase()}',
                      isDocument: tipo != 'avatar',
                    ),
                  ),
                );
                if (photo != null) {
                  _procesarFotoCapturada(tipo, photo);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _capitanAzulClaro),
              title: const Text('Galería (Elegir de fotos)', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );

    if (result is ImageSource && result == ImageSource.gallery) {
      try {
        final ImagePicker picker = ImagePicker();
        final XFile? image = await picker.pickImage(
          source: ImageSource.gallery, 
          imageQuality: 60,
          maxWidth: 1600,
          maxHeight: 1600,
        );
        
        if (image != null) {
          _procesarFotoCapturada(tipo, image);
        }
      } catch (e) {
        debugPrint('Error al seleccionar imagen: $e');
      }
    }
  }

  Future<void> _procesarFotoCapturada(String tipo, XFile image) async {
    final Uint8List imageBytes = await image.readAsBytes();

    // 1. Recorte Personalizado (100% Flutter)
    final Uint8List? croppedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CustomCropScreen(
          imageData: imageBytes,
          isCircular: tipo == 'avatar',
        ),
      ),
    );

    if (croppedData == null) return;

    setState(() {
      switch (tipo) {
        case 'avatar':
          _avatarFile = image;
          _avatarBytes = croppedData;
          break;
        case 'dni':
          _dniFile = image;
          _dniBytes = croppedData;
          break;
        case 'carnet':
          _carnetFile = image;
          _carnetBytes = croppedData;
          break;
        case 'seguro':
          _seguroFile = image;
          _seguroBytes = croppedData;
          break;
        case 'embarcacion':
          _embarcacionFile = image;
          _embarcacionBytes = croppedData;
          break;
      }
    });
  }

  Future<void> _enviarInscripcion() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validacion de archivos (simulada o real)
    if (_avatarFile == null || _dniFile == null || _carnetFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, carga los documentos obligatorios (Avatar, DNI y Carnet)'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_vencimientoCarnet == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, declará la fecha de vencimiento del Carnet de Timonel.'), backgroundColor: Colors.orange),
      );
      return;
    }

    if (_seguroFile != null && _vencimientoSeguro == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, declará la fecha de vencimiento de la Póliza de Seguro.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        throw Exception('Debes iniciar sesión para inscribirte');
      }

      // Validar código de referido si se especificó
      String? comisionistaId;
      String? codigoReferidoFinal;
      if (_traeReferido && _referidoController.text.trim().isNotEmpty) {
        final String inputCodigo = _referidoController.text.trim().toUpperCase();
        final promotor = await SupabaseService.validarCodigoPromotor(inputCodigo);
        if (promotor == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Código de referido no válido. Registrando sin referido.'), backgroundColor: Colors.orange),
          );
        } else {
          comisionistaId = promotor['id']?.toString();
          codigoReferidoFinal = promotor['codigo_comision']?.toString().toUpperCase();
        }
      }

      // 1. Subir archivos al Storage
      String? avatarUrl = await _uploadDoc(_avatarFile, 'avatar');
      String? dniUrl = await _uploadDoc(_dniFile, 'dni');
      String? carnetUrl = await _uploadDoc(_carnetFile, 'carnet');
      String? seguroUrl = await _uploadDoc(_seguroFile, 'seguro');
      String? embarcacionUrl = await _uploadDoc(_embarcacionFile, 'embarcacion');

      // 2. Crear/Actualizar Perfil en Supabase
      await supabase.from('profiles').upsert({
        'user_id': user.id,
        'nombre': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'dni': _dniController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'avatar_url': avatarUrl,
        'foto_dni_url': dniUrl,
        'carnet_url': carnetUrl,
        'seguro_url': seguroUrl,
        'embarcacion_url': embarcacionUrl,
        'vencimiento_seguro': _vencimientoSeguro?.toIso8601String(),
        'vencimiento_carnet': _vencimientoCarnet?.toIso8601String(),
        'referido': codigoReferidoFinal,
        'referido_id': comisionistaId,
        'es_capitan': true,
        'direccion_calle': _calleController.text.trim(),
        'direccion_numero': _alturaController.text.trim(),
        'localidad': _localidadController.text.trim(),
        'cp': _cpController.text.trim(), // Lo tratamos como texto por si tiene guiones
        'provincia': _provinciaController.text.trim(),
        'estado': 'pendiente',
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Tambien guardar en tabla guias si existe
      try {
        await supabase.from('guias').upsert({
          'id': user.id, // Usamos 'id' en lugar de 'user_id' según vimos en Supabase
          'nombre': _nombreController.text.trim(),
          'dni': _dniController.text.trim(),
          'email': _emailController.text.trim(),
          'telefono': _telefonoController.text.trim(),
          'calle': _calleController.text.trim(),
          'altura': _alturaController.text.trim(),
          'localidad': _localidadController.text.trim(),
          'provincia': _provinciaController.text.trim(),
          'referido': codigoReferidoFinal,
          'referido_id': comisionistaId,
          'verificado': false,
        });
      } catch (e) {
        debugPrint('Error no critico al guardar en tabla guias: $e');
      }

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: _capitanAzul,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), 
              side: const BorderSide(color: _capitanNaranja)
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 30),
                SizedBox(width: 10),
                Text('¡INSCRIPCIÓN ENVIADA!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text(
              'Tu documentación ha sido enviada con éxito. Un administrador revisará tu perfil en las próximas 24-48hs. ¡Bienvenido a la flota!',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Cerrar dialog
                  Navigator.pop(context); // Volver atras
                },
                style: ElevatedButton.styleFrom(backgroundColor: _capitanNaranja),
                child: const Text('ENTENDIDO'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _uploadDoc(XFile? file, String tipo) async {
    if (file == null) return null;
    
    final userId = SupabaseService.currentUserId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';

    return await StorageService.uploadAdminDocument(
      file: file,
      folder: userId,
      prefix: tipo,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Inscripción de Capitán', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_capitanAzul, Color(0xFF003366), Color(0xFF001122)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 30),
                  _buildGlassSection(
                    title: 'DATOS PERSONALES',
                    icon: Icons.person_outline,
                    children: [
                      _buildTextField(_nombreController, 'Nombre Completo', Icons.person),
                      const SizedBox(height: 15),
                      _buildTextField(_emailController, 'Email de Contacto', Icons.email, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_dniController, 'DNI / Identificación', Icons.badge, keyboardType: TextInputType.number)),
                          const SizedBox(width: 15),
                          Expanded(child: _buildTextField(_telefonoController, 'Teléfono / WhatsApp', Icons.phone, keyboardType: TextInputType.phone)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text('DIRECCIÓN DE RESIDENCIA', style: TextStyle(color: _capitanNaranja, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(flex: 3, child: _buildTextField(_calleController, 'Calle', Icons.location_on_outlined)),
                          const SizedBox(width: 10),
                          Expanded(flex: 2, child: _buildTextField(_alturaController, 'N°', null, keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildTextField(_localidadController, 'Localidad', Icons.map_outlined),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(_provinciaController, 'Provincia', Icons.explore_outlined)),
                          const SizedBox(width: 10),
                          Expanded(child: _buildTextField(_cpController, 'C.P.', Icons.mark_as_unread_sharp, keyboardType: TextInputType.number)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: _glassBorder, height: 1),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Text(
                              '¿Fuiste referido por un promotor?',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Switch(
                            value: _traeReferido,
                            activeColor: _capitanNaranja,
                            onChanged: (val) {
                              setState(() {
                                _traeReferido = val;
                              });
                            },
                          ),
                        ],
                      ),
                      if (_traeReferido) ...[
                        const SizedBox(height: 12),
                        _buildTextField(
                          _referidoController,
                          'Código de Promotor (Ej: PROMO-1234)',
                          Icons.card_giftcard_rounded,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 25),
                  _buildGlassSection(
                    title: 'DOCUMENTACIÓN REQUERIDA',
                    icon: Icons.description_outlined,
                    children: [
                      _buildFileSelector('Foto de Perfil (Avatar)', 'avatar', _avatarBytes, _avatarFile),
                      _buildFileSelector('Foto de DNI (Frente)', 'dni', _dniBytes, _dniFile),
                      _buildFileSelector('Carnet de Timonel / Guía', 'carnet', _carnetBytes, _carnetFile),
                      _buildFileSelector('Seguro de Embarcación', 'seguro', _seguroBytes, _seguroFile),
                      _buildFileSelector('Foto de la Embarcación', 'embarcacion', _embarcacionBytes, _embarcacionFile),
                    ],
                  ),
                  const SizedBox(height: 40),
                  _buildSubmitButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('UNITE A LA FLOTA', style: TextStyle(color: _capitanNaranja, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 8),
        const Text('CAPITAN YA', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Text('Completá tu perfil y subí la documentación para empezar a recibir reservas de pescadores.', 
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16)),
      ],
    );
  }

  Widget _buildGlassSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _glassColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _capitanNaranja, size: 20),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const Divider(color: _glassBorder, height: 30),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData? icon, {TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: icon != null ? Icon(icon, color: _capitanAzulClaro) : null,
        filled: true,
        fillColor: Colors.black26,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: _glassBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: _capitanAzulClaro)),
        errorStyle: const TextStyle(color: Colors.orangeAccent),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Campo requerido' : null,
    );
  }

  Future<void> _seleccionarFechaVencimiento(BuildContext context, String tipo) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: _capitanNaranja,
              onPrimary: Colors.black,
              surface: _capitanAzul,
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: _capitanAzul,
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (tipo == 'seguro') {
          _vencimientoSeguro = picked;
        } else if (tipo == 'carnet') {
          _vencimientoCarnet = picked;
        }
      });
    }
  }

  Widget _buildFileSelector(String label, String tipo, Uint8List? bytes, XFile? file) {
    bool requiereFecha = tipo == 'seguro' || tipo == 'carnet';
    DateTime? fechaSeleccionada = tipo == 'seguro' ? _vencimientoSeguro : _vencimientoCarnet;
    String labelFecha = tipo == 'seguro'
        ? 'Fecha de Vencimiento del Seguro'
        : 'Fecha de Vencimiento del Registro de Timonel';

    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── FECHA DE VENCIMIENTO: SIEMPRE VISIBLE, ARRIBA DEL DOCUMENTO ──
          if (requiereFecha) ...[
            InkWell(
              onTap: () => _seleccionarFechaVencimiento(context, tipo),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: fechaSeleccionada != null
                        ? _capitanNaranja.withOpacity(0.7)
                        : Colors.redAccent.withOpacity(0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      color: fechaSeleccionada != null ? _capitanNaranja : Colors.redAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            labelFecha,
                            style: TextStyle(
                              color: fechaSeleccionada != null ? _capitanAzulClaro : Colors.redAccent,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            fechaSeleccionada != null
                                ? '${fechaSeleccionada.day.toString().padLeft(2, '0')}/${fechaSeleccionada.month.toString().padLeft(2, '0')}/${fechaSeleccionada.year}'
                                : '⚠️ Tocá para seleccionar la fecha',
                            style: TextStyle(
                              color: fechaSeleccionada != null ? Colors.white : Colors.redAccent.withOpacity(0.8),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      fechaSeleccionada != null ? Icons.edit_calendar_rounded : Icons.add_rounded,
                      color: Colors.white38,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // ── SELECTOR DE ARCHIVO ──
          InkWell(
            onTap: () => _seleccionarImagen(tipo),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: file != null ? _capitanAzulClaro : _glassBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _buildPreview(bytes, file),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(file != null ? '¡Archivo cargado!' : 'Tocar para subir foto',
                          style: TextStyle(color: file != null ? _capitanAzulClaro : Colors.white38, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(file != null ? Icons.check_circle : Icons.add_a_photo,
                    color: file != null ? Colors.green : Colors.white38),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(Uint8List? bytes, XFile? file) {
    if (kIsWeb) {
      if (bytes != null) {
        return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(bytes, fit: BoxFit.cover));
      }
    } else {
      if (file != null) {
        return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(file.path, fit: BoxFit.cover));
      }
    }
    return const Icon(Icons.image, color: Colors.white24);
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _enviarInscripcion,
        style: ElevatedButton.styleFrom(
          backgroundColor: _capitanNaranja,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 10,
          shadowColor: _capitanNaranja.withOpacity(0.5),
        ),
        child: _isSaving
            ? const CircularProgressIndicator(color: Colors.white)
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.send),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'ENVIAR INSCRIPCIÓN',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
