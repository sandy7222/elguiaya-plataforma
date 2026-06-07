
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../widgets/document_capture_widget.dart';
import '../widgets/failsafe_background.dart';
import 'pescador_perfil_edit_screen.dart';
import 'bienvenida_definitiva_screen.dart';

class RegistroMaestroScreen extends StatefulWidget {
  final String? initialRole;
  const RegistroMaestroScreen({super.key, this.initialRole});

  @override
  State<RegistroMaestroScreen> createState() => _RegistroMaestroScreenState();
}

class _RegistroMaestroScreenState extends State<RegistroMaestroScreen> {
  final PageController _pageController = PageController();
  final _formKey = GlobalKey<FormState>();
  
  int _currentStep = 0;
  bool _isProcessing = false;
  late String _selectedRole; // 'pescador' o 'capitan'

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole ?? 'pescador';
  }

  // Data
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _dniTextController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _calleController = TextEditingController();
  final _alturaController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _cpController = TextEditingController();
  final _capacidadController = TextEditingController();
  final _referidoController = TextEditingController();
  bool _traeReferido = false;
  String? _comisionistaId;
  String? _codigoReferidoFinal;
  bool _showConfirmPassword = false;
  bool _showPassword = false;

  DateTime? _vencimientoSeguro;
  DateTime? _vencimientoCarnet;

  // Uploaded URLs
  String? _avatarUrl;
  String? _dniImageUrl;
  String? _carnetUrl;
  String? _seguroUrl;
  String? _embarcacionUrl;

  @override
  void dispose() {
    _pageController.dispose();
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dniTextController.dispose();
    _telefonoController.dispose();
    _calleController.dispose();
    _alturaController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    _cpController.dispose();
    _capacidadController.dispose();
    _referidoController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    if (_currentStep == 0) {
      if (_emailController.text.trim().isEmpty) {
        _showError('Por favor ingresa tu email.');
        return;
      }
      if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
        _showError('Por favor completa la contraseña y su confirmación.');
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Las contraseñas no coinciden.');
        return;
      }
      if (_passwordController.text.length < 6) {
        _showError('La contraseña debe tener al menos 6 caracteres.');
        return;
      }

      if (_traeReferido) {
        final codeInput = _referidoController.text.trim().toUpperCase();
        if (codeInput.isEmpty) {
          _showError('Por favor ingresa tu código de referido.');
          return;
        }

        setState(() => _isProcessing = true);
        try {
          final promotor = await SupabaseService.validarCodigoPromotor(codeInput);
          if (promotor == null) {
            _showError('Código de legajo inválido');
            setState(() => _isProcessing = false);
            return;
          } else {
            _comisionistaId = promotor['id']?.toString();
            _codigoReferidoFinal = promotor['codigo_comision']?.toString().toUpperCase();
          }
        } catch (e) {
          _showError('Error al validar código de referido: $e');
          setState(() => _isProcessing = false);
          return;
        }
        setState(() => _isProcessing = false);
      } else {
        _comisionistaId = null;
        _codigoReferidoFinal = null;
      }
    }

    if (_currentStep < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      setState(() => _currentStep--);
    }
  }

  Future<void> _finalizarRegistro() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validar documentos segun rol
    if (_avatarUrl == null || _dniImageUrl == null) {
      _showError('Por favor sube las fotos obligatorias (Avatar y DNI).');
      return;
    }

    if (_selectedRole == 'capitan' && (_carnetUrl == null || _seguroUrl == null)) {
      _showError('Los capitanes deben subir Carnet y Seguro.');
      return;
    }

    if (_selectedRole == 'capitan' && _vencimientoCarnet == null) {
      _showError('Por favor, ingresá la fecha de vencimiento de tu Carnet.');
      return;
    }

    if (_selectedRole == 'capitan' && _seguroUrl != null && _vencimientoSeguro == null) {
      _showError('Por favor, ingresá la fecha de vencimiento de tu Seguro.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Validaciones previas
      if (_passwordController.text != _confirmPasswordController.text) {
        _showError('Las contraseñas no coinciden.');
        return;
      }
      if (_passwordController.text.length < 6) {
        _showError('La contraseña debe tener al menos 6 caracteres.');
        return;
      }

      String? userId;

      // 2. Intentar crear el usuario en Auth
      try {
        final authResponse = await SupabaseService.signUp(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
        userId = authResponse.user?.id;
      } on AuthException catch (e) {
        // Si el usuario ya existe (Error 422/user_already_exists)
        if (e.message.contains('already registered') || e.statusCode == '422') {
          // Intentar Loguear para obtener el ID si ya existe
          try {
            final loginResponse = await SupabaseService.signIn(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            );
            userId = loginResponse.user?.id;
          } catch (loginErr) {
            _showError('Este email ya está en uso, pero la contraseña es incorrecta.');
            return;
          }
        } else {
          rethrow;
        }
      }

      if (userId == null) throw 'No se pudo obtener el ID de usuario.';

      // 3. Crear o Actualizar Perfil (Upsert)
      await SupabaseService.supabase.from('profiles').upsert({
        'user_id': userId,
        'email': _emailController.text.trim(),
        'nombre': _nombreController.text.trim(),
        'dni': _dniTextController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'avatar_url': _avatarUrl,
        'foto_dni_url': _dniImageUrl,
        'carnet_url': _carnetUrl,
        'seguro_url': _seguroUrl,
        'embarcacion_url': _embarcacionUrl,
        'es_capitan': _selectedRole == 'capitan',
        'direccion_calle': _calleController.text.trim(),
        'direccion_numero': _alturaController.text.trim(),
        'localidad': _localidadController.text.trim(),
        'provincia': _provinciaController.text.trim(),
        'cp': int.tryParse(_cpController.text.trim()) ?? 0,
        'capacidad_personas': int.tryParse(_capacidadController.text.trim()) ?? 0,
        'vencimiento_seguro': _vencimientoSeguro?.toIso8601String(),
        'vencimiento_carnet': _vencimientoCarnet?.toIso8601String(),
        'estado': _selectedRole == 'capitan' ? 'pendiente' : 'activo',
        'verificado': _selectedRole != 'capitan',
        'referido': _codigoReferidoFinal,
        'referido_id': _comisionistaId,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');

      if (mounted) {
        _showSuccessDialog();
      }

    } on AuthException catch (e) {
      _showError('Error de autenticación: ${e.message}');
    } catch (e) {
      _showError('Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccessDialog() {
    bool esCapitan = _selectedRole == 'capitan';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF001F3F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              esCapitan ? Icons.access_time_filled : Icons.check_circle, 
              color: const Color(0xFF00E676), 
              size: 30
            ),
            const SizedBox(width: 10),
            Text(esCapitan ? '¡REGISTRO ENVIADO!' : '¡ÉXITO!', style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          esCapitan 
            ? 'Tu legajo ha sido enviado a la Central de Admisiones. Un administrador revisará tu perfil. Te notificaremos por email cuando tu cuenta sea habilitada.'
            : 'Tu perfil ha sido creado correctamente. Ya puedes comenzar a usar Capitan-YA.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (esCapitan) {
                    // Capitán: Cerramos sesión y volvemos al inicio/login real
                    await SupabaseService.signOut();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const BienvenidaDefinitivaScreen()),
                        (route) => false,
                      );
                    }
                  } else {
                    // Pescador: Directo a configurar su identidad (Bio, Equipo, etc)
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const PescadorPerfilEditScreen()),
                      (route) => false,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  esCapitan ? 'ENTENDIDO' : 'INGRESAR AHORA', 
                  style: const TextStyle(fontWeight: FontWeight.bold)
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FailsafeBackground(
        imageUrl: '', // Forzamos a que no use la imagen de la portada para este flujo
        opacity: 0.9,
        overlayColor: const Color(0xFF001122), // Azul profundo
        child: SafeArea(
          child: Column(
            children: [
              _buildProgressHeader(),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _buildStep1(),
                      _buildStep2(),
                      _buildStep3(),
                    ],
                  ),
                ),
              ),
              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: _currentStep == 0 ? () => Navigator.pop(context) : _prevStep,
              ),
              Text(
                'REGISTRO MAESTRO',
                style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(width: 48), // Spacer para centrar texto
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(3, (index) {
              return Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index <= _currentStep ? const Color(0xFF00E676) : Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PASO 1: TU CUENTA', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Ingresa tus credenciales para crear tu perfil.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 25),
          
          _buildTextField(_emailController, 'Email', Icons.email, keyboardType: TextInputType.emailAddress),
          const SizedBox(height: 16),
          _buildTextField(
            _passwordController, 
            'Contraseña', 
            Icons.lock, 
            obscureText: !_showPassword,
            showEye: true,
            onEyeTap: () => setState(() => _showPassword = !_showPassword),
          ),
          const SizedBox(height: 16),
          _buildTextField(
            _confirmPasswordController, 
            'Confirmar Contraseña', 
            Icons.lock_outline, 
            obscureText: !_showConfirmPassword,
            showEye: true,
            onEyeTap: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
          ),
          
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  '¿TIENE CÓDIGO DE REFERIDO?',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Switch(
                value: _traeReferido,
                activeThumbColor: const Color(0xFF00E676),
                activeTrackColor: const Color(0xFF00E676).withValues(alpha: 0.5),
                onChanged: (val) {
                  setState(() {
                    _traeReferido = val;
                    if (!val) {
                      _referidoController.clear();
                      _comisionistaId = null;
                      _codigoReferidoFinal = null;
                    }
                  });
                },
              ),
              if (_traeReferido) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  height: 44,
                  child: TextFormField(
                    controller: _referidoController,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      hintText: 'CÓDIGO',
                      hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF00E676)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'CODIG.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 30),
          const Text('ELIGE TU ROL', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 15),
          
          _buildRoleCard('pescador', 'Soy Pescador', 'Busco excursiones y productos.', Icons.sailing),
          const SizedBox(height: 16),
          _buildRoleCard('capitan', 'Soy Capitán / Guía', 'Ofrezco mis servicios y embarcación.', Icons.anchor),
        ],
      ),
    );
  }

  Widget _buildRoleCard(String role, String title, String subtitle, IconData icon) {
    bool isSelected = _selectedRole == role;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF00E676).withOpacity(0.2) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF00E676) : Colors.white12, width: 2),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF00E676) : Colors.white38, size: 40),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: TextStyle(color: isSelected ? Colors.white70 : Colors.white38, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF00E676)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DATOS PERSONALES', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildTextField(_nombreController, 'Nombre Completo', Icons.person),
          const SizedBox(height: 16),
          _buildTextField(_dniTextController, 'DNI / Identificación', Icons.badge),
          const SizedBox(height: 16),
          _buildTextField(_telefonoController, 'Teléfono / WhatsApp', Icons.phone, keyboardType: TextInputType.phone),
          const SizedBox(height: 25),
          
          const Text('UBICACIÓN / DIRECCIÓN', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(flex: 3, child: _buildTextField(_calleController, 'Calle', Icons.location_on_outlined)),
              const SizedBox(width: 10),
              Expanded(
                flex: 2, 
                child: _buildTextField(
                  _alturaController, 
                  'Número', 
                  null, // SIN ICONO #
                  customPrefix: const Padding(
                    padding: EdgeInsets.only(left: 12, right: 8),
                    child: Text('N°', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  keyboardType: TextInputType.number
                )
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildTextField(_localidadController, 'Localidad', Icons.map_outlined),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildTextField(_provinciaController, 'Provincia', Icons.explore_outlined)),
              const SizedBox(width: 10),
              Expanded(child: _buildTextField(_cpController, 'C.P.', Icons.mark_as_unread_sharp, keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 30),
          
          DocumentCaptureWidget(
            label: 'FOTO DE PERFIL (AVATAR)',
            tipoDoc: 'avatar',
            isCircular: true,
            icon: Icons.person_pin_circle_outlined,
            onUploadComplete: (url) => setState(() => _avatarUrl = url),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DOCUMENTACIÓN', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Sube fotos legibles para validar tu perfil.', style: TextStyle(color: Colors.white60)),
          const SizedBox(height: 30),
          
          DocumentCaptureWidget(
            label: 'DNI / IDENTIFICACIÓN (FRENTE)',
            tipoDoc: 'dni',
            icon: Icons.badge_outlined,
            onUploadComplete: (url) => setState(() => _dniImageUrl = url),
          ),
          
          if (_selectedRole == 'capitan') ...[
            const SizedBox(height: 20),
            _buildDatePickerBox('Vencimiento del Carnet de Timonel', _vencimientoCarnet, 'carnet'),
            DocumentCaptureWidget(
              label: 'CARNET DE TIMONEL / GUÍA',
              tipoDoc: 'carnet',
              icon: Icons.assignment_ind_outlined,
              onUploadComplete: (url) => setState(() => _carnetUrl = url),
            ),
            const SizedBox(height: 20),
            _buildDatePickerBox('Vencimiento del Seguro de Embarcación', _vencimientoSeguro, 'seguro'),
            DocumentCaptureWidget(
              label: 'SEGURO DE EMBARCACIÓN',
              tipoDoc: 'seguro',
              icon: Icons.security_outlined,
              onUploadComplete: (url) => setState(() => _seguroUrl = url),
            ),
            const SizedBox(height: 20),
            DocumentCaptureWidget(
              label: 'FOTO DE LA EMBARCACIÓN',
              tipoDoc: 'embarcacion',
              icon: Icons.directions_boat_outlined,
              onUploadComplete: (url) => setState(() => _embarcacionUrl = url),
            ),
            const SizedBox(height: 25),
            const Text('CAPACIDAD DE CARGA', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const SizedBox(height: 15),
            _buildTextField(
              _capacidadController, 
              '¿Cuántas personas puede llevar?', 
              Icons.groups_outlined, 
              keyboardType: TextInputType.number
            ),
          ],
        ],
      ),
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
              primary: Color(0xFF00E676),
              onPrimary: Colors.black,
              surface: Color(0xFF001F3F),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF001F3F),
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

  Widget _buildDatePickerBox(String label, DateTime? date, String tipo) {
    return InkWell(
      onTap: () => _seleccionarFechaVencimiento(context, tipo),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: date != null
                ? const Color(0xFF00E676).withOpacity(0.7)
                : Colors.redAccent.withOpacity(0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_rounded,
              color: date != null ? const Color(0xFF00E676) : Colors.redAccent,
              size: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: date != null ? const Color(0xFF00E676) : Colors.redAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    date != null
                        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                        : '⚠️ Tocá para seleccionar la fecha',
                    style: TextStyle(
                      color: date != null ? Colors.white : Colors.redAccent.withOpacity(0.8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              date != null ? Icons.edit_calendar_rounded : Icons.add_rounded,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData? icon, {bool obscureText = false, TextInputType? keyboardType, bool showEye = false, VoidCallback? onEyeTap, Widget? customPrefix}) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38),
        prefixIcon: icon != null 
          ? Icon(icon, color: const Color(0xFF00E676)) 
          : customPrefix,
        suffixIcon: showEye ? IconButton(
          icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.white38),
          onPressed: onEyeTap,
        ) : null,
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFF00E676))),
      ),
      validator: (val) => val == null || val.isEmpty ? 'Requerido' : null,
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          if (_currentStep > 0) ...[
            Expanded(
              child: SizedBox(
                height: 60,
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _prevStep,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white38),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text('ATRÁS', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 60,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : (_currentStep == 2 ? _finalizarRegistro : _nextStep),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: 8,
                ),
                child: _isProcessing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _currentStep == 2 ? 'FINALIZAR REGISTRO' : 'CONTINUAR',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
