


import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/branding_service.dart';

class BrandingEditorScreen extends StatefulWidget {
  const BrandingEditorScreen({super.key});

  @override
  State<BrandingEditorScreen> createState() => _BrandingEditorScreenState();
}

class _BrandingEditorScreenState extends State<BrandingEditorScreen> {
  // Estado de carga
  bool _isLoading = false;
  bool _isUploading = false;
  
  // Configuracion actual
  String? _logoUrl;
  String? _faviconUrl;
  String? _backgroundUrl;
  double _opacity = 0.5;
  double _brightness = 1.0;
  
  // Archivos seleccionados - usar dynamic para compatibilidad Web/Mobile
  dynamic _selectedLogo;
  dynamic _selectedFavicon;
  dynamic _selectedBackground;
  
  // Colores
  Color _colorPrimario = const Color(0xFF0D6EFD);
  Color _colorSecundario = const Color(0xFF6C757D);
  Color _colorAcento = const Color(0xFF198754);
  Color _colorFondo = const Color(0xFFF8F9FA);
  
  // Tipografia
  String _fontFamily = 'Roboto';
  bool _enableAnimations = true;
  
  // Textos Legales
  final TextEditingController _ayudaController = TextEditingController();
  final TextEditingController _terminosController = TextEditingController();
  
  // Archivos seleccionados - ya declarados como dynamic arriba
  
  // Colores del diseno profesional
  static const Color _fondoClaro = Color(0xFFF8F9FA);
  static const Color _fondoBlanco = Color(0xFFFFFFFF);
  static const Color _colorTexto = Color(0xFF212529);
  static const Color _colorTextoSecundario = Color(0xFF6C757D);
  static const Color _colorBorde = Color(0xFFDEE2E6);
  static const Color _colorPrimarioApp = Color(0xFF0D6EFD);
  
  // Fuentes predefinidas
  final List<String> _fuentesDisponibles = [
    'Roboto',
    'Open Sans',
    'Montserrat',
    'Poppins',
    'Lato',
    'Raleway',
    'Ubuntu',
    'Playfair Display',
  ];
  
  // Colores predefinidos
  final List<Color> _coloresPredefinidos = [
    const Color(0xFF0D6EFD), // Azul
    const Color(0xFF198754), // Verde
    const Color(0xFFDC3545), // Rojo
    const Color(0xFFFFC107), // Amarillo
    const Color(0xFF6F42C1), // Purpura
    const Color(0xFF20C997), // Turquesa
    const Color(0xFFFD7E14), // Naranja
    const Color(0xFF343A40), // Gris oscuro
    const Color(0xFF6C757D), // Gris
    const Color(0xFFE9ECEF), // Gris claro
  ];

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionActual();
  }

  @override
  void dispose() {
    _ayudaController.dispose();
    _terminosController.dispose();
    super.dispose();
  }

  Future<void> _cargarConfiguracionActual() async {
    setState(() => _isLoading = true);
    
    try {
      final config = await BrandingService.getLoginConfig();
      final textosLegales = await BrandingService.getTextosLegales();
      
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
          _brightness = config.brightness;
          _ayudaController.text = textosLegales['texto_ayuda'] ?? '';
          _terminosController.text = textosLegales['texto_terminos'] ?? '';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar configuracion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Metodos de seleccion de archivos
  Future<void> _seleccionarLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
      maxHeight: 512,
    );
    
    if (pickedFile != null) {
      setState(() => _selectedLogo = pickedFile);
    }
  }
  
  Future<void> _seleccionarFavicon() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 64,
      maxHeight: 64,
    );
    
    if (pickedFile != null) {
      setState(() => _selectedFavicon = pickedFile);
    }
  }
  
  Future<void> _seleccionarBackground() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1080,
    );
    
    if (pickedFile != null) {
      setState(() => _selectedBackground = pickedFile);
    }
  }

  // Metodos de subida de archivos
  Future<void> _subirLogo() async {
    if (_selectedLogo == null) return;

    setState(() => _isUploading = true);

    try {
      final url = await BrandingService.subirImagenBranding(
        archivo: _selectedLogo!,
        carpeta: 'branding_images',
        nombrePersonalizado: 'logo',
      );

      // Persistir URL en Supabase
      await BrandingService.actualizarConfiguracion(
        clave: 'logo_url',
        valor: url,
        tipoValor: 'imagen_url',
        descripcion: 'URL del logo principal de la app',
      );

      setState(() {
        _logoUrl = url;
        _selectedLogo = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo subido y guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir logo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _subirFavicon() async {
    if (_selectedFavicon == null) return;

    setState(() => _isUploading = true);

    try {
      final url = await BrandingService.subirImagenBranding(
        archivo: _selectedFavicon!,
        carpeta: 'branding_images',
        nombrePersonalizado: 'favicon',
      );

      // Persistir URL en Supabase
      await BrandingService.actualizarConfiguracion(
        clave: 'favicon_url',
        valor: url,
        tipoValor: 'imagen_url',
        descripcion: 'URL del favicon de la app',
      );

      setState(() {
        _faviconUrl = url;
        _selectedFavicon = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Favicon subido y guardado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isUploading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir favicon: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _subirBackground() async {
    if (_selectedBackground == null) return;

    setState(() => _isUploading = true);

    try {
      final url = await BrandingService.subirImagenBranding(
        archivo: _selectedBackground!,
        carpeta: 'branding_images',
        nombrePersonalizado: 'background',
      );

      // Persistir URL en Supabase
      await BrandingService.actualizarConfiguracion(
        clave: 'login_background_url',
        valor: url,
        tipoValor: 'imagen_url',
        descripcion: 'URL de imagen de fondo del Login',
      );

      setState(() {
        _backgroundUrl = url;
        _selectedBackground = null;
        _isUploading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Imagen de fondo subida y guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al subir imagen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarConfiguracion() async {
    setState(() => _isLoading = true);
    
    try {
      // Guardar configuracion de login
      final resultadoLogin = await BrandingService.actualizarConfiguracionLogin(
        backgroundUrl: _backgroundUrl,
        opacity: _opacity,
        brightness: _brightness,
      );
      
      // Guardar textos legales
      final resultadoTextos = await BrandingService.actualizarTextosLegales(
        _ayudaController.text,
        _terminosController.text,
      );
      
      if (resultadoLogin && resultadoTextos) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Configuracion guardada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar configuracion: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  Future<void> _restablecerValoresPorDefecto() async {
    setState(() => _isLoading = true);
    
    try {
      await BrandingService.limpiarConfiguracionBranding();
      
      setState(() {
        _logoUrl = null;
        _faviconUrl = null;
        _backgroundUrl = null;
        _opacity = 0.5;
        _brightness = 1.0;
        _colorPrimario = const Color(0xFF0D6EFD);
        _colorSecundario = const Color(0xFF6C757D);
        _colorAcento = const Color(0xFF198754);
        _colorFondo = const Color(0xFFF8F9FA);
        _fontFamily = 'Roboto';
        _enableAnimations = true;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Valores restablecidos por defecto'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al restablecer valores: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: _fondoClaro,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Editor de Branding',
              style: TextStyle(color: _colorTexto, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (user != null)
              Text(
                'Sesion: ${user.email}',
                style: const TextStyle(fontSize: 10, color: Colors.green),
              ),
          ],
        ),
        backgroundColor: _fondoBlanco,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: _colorTexto),
        actions: [
          IconButton(
            onPressed: _guardarConfiguracion,
            icon: _isLoading 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _colorPrimarioApp,
                    ),
                  )
                : const Icon(Icons.save, color: _colorPrimarioApp),
            tooltip: 'Guardar Configuracion',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Vista Previa en Tiempo Real
                  _buildPreviewSection(),
                  const SizedBox(height: 24),
                  
                  // Seccion de Identidad
                  _buildIdentitySection(),
                  const SizedBox(height: 24),
                  
                  // Seccion de Fondo
                  _buildBackgroundSection(),
                  const SizedBox(height: 24),
                  
                  // Seccion de Colores
                  _buildColorsSection(),
                  const SizedBox(height: 24),
                  
                  // Seccion de Tipografia
                  _buildTypographySection(),
                  const SizedBox(height: 24),
                  
                  // Seccion de Textos Legales
                  _buildTextosLegalesSection(),
                  const SizedBox(height: 24),
                  
                  // Seccion de Acciones
                  _buildActionsSection(),
                ],
              ),
            ),
    );
  }

  // Widget para manejar imagenes compatibles con Web y Mobile
  Widget _buildImageFromFile(dynamic file, BoxFit fit) {
    if (file is XFile) {
      if (kIsWeb) {
        // En la Web, Image.network(file.path) puede dar error de codec si es un blob URL local no compatible directamente.
        // Lo correcto en web es leer sus bytes y mostrarlo con Image.memory.
        return FutureBuilder<Uint8List>(
          future: file.readAsBytes(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              return Image.memory(snapshot.data!, fit: fit);
            }
            return const Center(child: CircularProgressIndicator());
          },
        );
      }
      return Image.network(file.path, fit: fit);
    } else if (file is Uint8List) {
      return Image.memory(file, fit: fit);
    } else if (file is String) {
      return Image.network(file, fit: fit);
    } else {
      return const Icon(Icons.error_outline, color: Colors.red);
    }
  }

  Widget _buildPreviewSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.remove_red_eye, color: _colorPrimarioApp),
                const SizedBox(width: 8),
                Expanded(
                  child: const Text(
                    'VISTA PREVIA (MODO ESPEJO)',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                const Text('En tiempo real', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            height: 300,
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. IMAGEN DE FONDO (Espejo)
                  _selectedBackground != null
                      ? _buildImageFromFile(_selectedBackground!, BoxFit.cover)
                      : (_backgroundUrl != null && _backgroundUrl!.isNotEmpty)
                          ? Image.network(_backgroundUrl!, fit: BoxFit.cover)
                          : Container(color: const Color(0xFF001F3F)),
                  
                  // 2. CAPA DE BRILLO (Brightness)
                  Container(
                    color: Colors.black.withOpacity((1.0 - _brightness).clamp(0.0, 1.0)),
                  ),
                  
                  // 3. CAPA DE OPACIDAD (Overlay Azul de Marca)
                  Container(
                    color: const Color(0xFF001F3F).withOpacity(_opacity),
                  ),
                  
                  // 4. CONTENIDO (Login Box)
                  Center(
                    child: Container(
                      width: 220,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_logoUrl != null)
                            Image.network(_logoUrl!, height: 50)
                          else
                            const Icon(Icons.anchor, size: 50, color: Colors.white),
                          const SizedBox(height: 12),
                          const Text(
                            'EL GUIA YA',
                            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2),
                          ),
                          const SizedBox(height: 20),
                          Container(
                            height: 35,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 40,
                            decoration: BoxDecoration(
                              color: _colorPrimarioApp,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(child: Text('INGRESAR', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
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
      ),
    );
  }

  Widget _buildIdentitySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: _colorPrimarioApp),
                const SizedBox(width: 8),
                Text(
                  'Identidad Visual',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _colorTexto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Logo
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Logo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _colorTexto,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 80,
                        decoration: BoxDecoration(
                          border: Border.all(color: _colorBorde, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                          color: _fondoClaro,
                        ),
                        child: _selectedLogo != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImageFromFile(_selectedLogo!, BoxFit.cover),
                              )
                            : _logoUrl != null
                                ? Image.network(_logoUrl!, fit: BoxFit.cover)
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.cloud_upload_outlined),
                                        SizedBox(height: 4),
                                        Text('Arrastra o haz clic', style: TextStyle(fontSize: 12)),
                                      ],
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _seleccionarLogo,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Seleccionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorPrimarioApp,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_selectedLogo != null) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _subirLogo,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload),
                        label: Text(_isUploading ? 'Subiendo...' : 'Subir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Favicon
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Favicon',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _colorTexto,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 60,
                        decoration: BoxDecoration(
                          border: Border.all(color: _colorBorde, style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(8),
                          color: _fondoClaro,
                        ),
                        child: _selectedFavicon != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImageFromFile(_selectedFavicon!, BoxFit.cover),
                              )
                            : _faviconUrl != null
                                ? Image.network(_faviconUrl!, fit: BoxFit.cover)
                                : const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.cloud_upload_outlined),
                                        SizedBox(height: 4),
                                        Text('64x64px', style: TextStyle(fontSize: 10)),
                                      ],
                                    ),
                                  ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _seleccionarFavicon,
                      icon: const Icon(Icons.photo_library),
                      label: const Text('Seleccionar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _colorPrimarioApp,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    if (_selectedFavicon != null) ...[
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _isUploading ? null : _subirFavicon,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.upload),
                        label: Text(_isUploading ? 'Subiendo...' : 'Subir'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackgroundSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.image, color: _colorPrimarioApp),
                const SizedBox(width: 8),
                Text(
                  'Fondo de Pantalla',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _colorTexto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Imagen de fondo
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: _colorBorde, style: BorderStyle.solid),
                borderRadius: BorderRadius.circular(8),
                color: _fondoClaro,
              ),
              child: _selectedBackground != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: _buildImageFromFile(_selectedBackground!, BoxFit.cover),
                    )
                  : _backgroundUrl != null
                      ? Image.network(_backgroundUrl!, fit: BoxFit.cover)
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cloud_upload_outlined),
                              SizedBox(height: 4),
                              Text('Arrastra o haz clic para fondo', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
            ),
            
            const SizedBox(height: 16),
            
            // Controles de opacidad y brillo
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Opacidad: ${(_opacity * 100).round()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _colorTexto,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _opacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        activeColor: _colorPrimarioApp,
                        onChanged: (value) {
                          setState(() => _opacity = value);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Brillo: ${(_brightness * 100).round()}%',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _colorTexto,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Slider(
                        value: _brightness,
                        min: 0.0,
                        max: 2.0,
                        divisions: 40,
                        activeColor: _colorPrimarioApp,
                        onChanged: (value) {
                          setState(() => _brightness = value);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Botones de accion
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _seleccionarBackground,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Seleccionar Fondo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _colorPrimarioApp,
                    foregroundColor: Colors.white,
                  ),
                ),
                if (_selectedBackground != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _isUploading ? null : _subirBackground,
                    icon: _isUploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload),
                    label: Text(_isUploading ? 'Subiendo...' : 'Subir'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette, color: _colorPrimarioApp),
                const SizedBox(width: 8),
                Text(
                  'Paleta de Colores',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _colorTexto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Color Primario
            _buildColorPicker(
              'Color Primario',
              _colorPrimario,
              (color) => setState(() => _colorPrimario = color),
            ),
            
            const SizedBox(height: 16),
            
            // Color Secundario
            _buildColorPicker(
              'Color Secundario',
              _colorSecundario,
              (color) => setState(() => _colorSecundario = color),
            ),
            
            const SizedBox(height: 16),
            
            // Color de Acento
            _buildColorPicker(
              'Color de Acento',
              _colorAcento,
              (color) => setState(() => _colorAcento = color),
            ),
            
            const SizedBox(height: 16),
            
            // Color de Fondo
            _buildColorPicker(
              'Color de Fondo',
              _colorFondo,
              (color) => setState(() => _colorFondo = color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorPicker(String label, Color currentColor, Function(Color) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _colorTexto,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            // Color actual
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _colorBorde),
              ),
            ),
            const SizedBox(width: 16),
            
            // Selector de colores predefinidos
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _coloresPredefinidos.map((color) {
                  return GestureDetector(
                    onTap: () => onChanged(color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: currentColor == color ? _colorPrimarioApp : _colorBorde,
                          width: currentColor == color ? 2 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypographySection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, color: _colorPrimarioApp),
                const SizedBox(width: 8),
                Text(
                  'Tipografia',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _colorTexto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Selector de fuente
            DropdownButtonFormField<String>(
              initialValue: _fontFamily,
              decoration: InputDecoration(
                labelText: 'Fuente Principal',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _colorBorde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _colorPrimarioApp),
                ),
              ),
              items: _fuentesDisponibles.map((font) {
                return DropdownMenuItem(
                  value: font,
                  child: Text(
                    font,
                    style: TextStyle(fontFamily: font),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _fontFamily = value);
                }
              },
            ),
            
            const SizedBox(height: 16),
            
            // Checkbox para animaciones
            Row(
              children: [
                Checkbox(
                  value: _enableAnimations,
                  onChanged: (value) {
                    setState(() => _enableAnimations = value ?? false);
                  },
                  activeColor: _colorPrimarioApp,
                ),
                Text(
                  'Habilitar animaciones',
                  style: TextStyle(
                    fontSize: 14,
                    color: _colorTexto,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextosLegalesSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_snippet, color: _colorPrimarioApp),
                const SizedBox(width: 8),
                Text(
                  'Textos de Ayuda y Legales',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _colorTexto,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Texto de Ayuda
            Text(
              'Texto de Ayuda',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _colorTexto,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ayudaController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Ingrese el texto de ayuda...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _colorBorde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _colorPrimarioApp),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Texto de Terminos y Condiciones
            Text(
              'Terminos y Condiciones',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _colorTexto,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _terminosController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Ingrese los terminos y condiciones...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _colorBorde),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _colorPrimarioApp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsSection() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _guardarConfiguracion,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar Configuracion'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _colorPrimarioApp,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _restablecerValoresPorDefecto,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restablecer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
