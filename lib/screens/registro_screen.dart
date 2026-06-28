
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';


import '../models/documento.dart';
import '../models/guia.dart';
import '../services/supabase_service.dart';
import '../widgets/camera_picker.dart';

enum RegistroStep { auth, profile }

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _calleController = TextEditingController();
  final _alturaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _especialidadController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _carnetController = TextEditingController();
  final _polizaController = TextEditingController();
  final _cbuController = TextEditingController();
  final _bancoController = TextEditingController();
  final _referidoController = TextEditingController();
  bool _traeReferido = false;

  @override
  void dispose() {
    _nombreController.dispose();
    _dniController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    _calleController.dispose();
    _alturaController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _especialidadController.dispose();
    _telefonoController.dispose();
    _carnetController.dispose();
    _polizaController.dispose();
    _cbuController.dispose();
    _bancoController.dispose();
    _referidoController.dispose();
    super.dispose();
  }

  RegistroStep _currentStep = RegistroStep.auth;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Control Anti-429
  int _cooldownSeconds = 0;
  int _attemptsCount = 0;
  DateTime? _lastAttemptTime;

  // URLs de archivos subidos
  String? _fotoPerfilUrl;
  String? _dniFrontUrl;
  String? _carnetTimonelUrl;
  String? _seguroUrl;
  String? _embarcacionUrl;

  bool _isLoading = false;
  String _statusMsg = '';
  String _currentUserId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

  // Configuración de fondo (Dinámica)
  final String _bgUrl = 'https://ntitpizisremsryclmzv.supabase.co/storage/v1/object/public/branding/fondo_registro.jpg';

  Future<void> _avanzarAlPerfil() async {
    // 1. Verificar Cooldown
    if (_cooldownSeconds > 0) {
      _showError('Por seguridad, espera $_cooldownSeconds segundos antes de reintentar.');
      return;
    }

    // 2. Cache de Sesion: Si ya hay usuario, saltar Auth
    final existingUser = Supabase.instance.client.auth.currentUser;
    if (existingUser != null) {
      print('?? [ANTI-429] Sesion existente detectada (${existingUser.id}). Saltando Auth.');
      setState(() {
        _currentUserId = existingUser.id;
        _currentStep = RegistroStep.profile;
      });
      return;
    }

    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError('Por favor completa Email y Contrasena');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Las contrasenas no coinciden');
      return;
    }

    // 3. Contador de Intentos
    final now = DateTime.now();
    if (_lastAttemptTime != null && now.difference(_lastAttemptTime!).inMinutes < 1) {
      _attemptsCount++;
    } else {
      _attemptsCount = 1;
      _lastAttemptTime = now;
    }
    print('?? [ANTI-429] Intento de Auth #$_attemptsCount en el ultimo minuto.');

    setState(() {
      _isLoading = true;
      _statusMsg = 'Creando cuenta segura...';
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        setState(() => _statusMsg = 'Cuenta creada. Aguardando 2s de seguridad...');
        await Future.delayed(const Duration(seconds: 2));

        setState(() {
          _currentUserId = response.user!.id;
          _currentStep = RegistroStep.profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (e.toString().contains('already registered')) {
        _showError('El email ya esta registrado. Intenta iniciar sesion.');
        _startCooldown(30);
      } else if (e.toString().contains('429') || e.toString().contains('over_email_send_rate_limit')) {
        _showError('BLOQUEO DE EMAIL: Usa el "MODO TEST" abajo para continuar sin correo.');
        _startCooldown(60);
      } else {
        _showError('Error: $e');
        _startCooldown(15);
      }
    }
  }

  // Bypass para fase de Test (Sin Emails)
  Future<void> _entrarComoInvitadoTest() async {
    setState(() {
      _isLoading = true;
      _statusMsg = 'Entrando en MODO TEST (Sin Email)...';
    });
    try {
      final response = await Supabase.instance.client.auth.signInAnonymously();
      if (response.user != null) {
        setState(() {
          _currentUserId = response.user!.id;
          _currentStep = RegistroStep.profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error en Modo Test: $e');
    }
  }

  void _startCooldown(int seconds) {
    setState(() => _cooldownSeconds = seconds);
    Stream.periodic(const Duration(seconds: 1), (i) => seconds - i - 1)
        .take(seconds)
        .listen((remaining) {
      if (mounted) setState(() => _cooldownSeconds = remaining);
    });
  }

  Future<void> _finalizarRegistro() async {
    setState(() {
      _isLoading = true;
      _statusMsg = 'Validando referido y guardando perfil...';
    });

    try {
      String? comisionistaId;
      String? codigoReferidoFinal;
      if (_traeReferido && _referidoController.text.trim().isNotEmpty) {
        final String inputCodigo = _referidoController.text.trim().toUpperCase();
        final promotor = await SupabaseService.validarCodigoPromotor(inputCodigo);
        if (promotor == null) {
          _showError('Código de referido no válido. Registrando sin referido.');
        } else {
          comisionistaId = promotor['id']?.toString();
          codigoReferidoFinal = promotor['codigo_comision']?.toString().toUpperCase();
        }
      }

      final guia = Guia(
        id: Supabase.instance.client.auth.currentUser?.id ?? _currentUserId,
        nombre: _nombreController.text.trim(),
        dni: _dniController.text.trim(),
        localidad: _localidadController.text.trim(),
        provincia: _provinciaController.text.trim(),
        calle: _calleController.text.trim(),
        altura: _alturaController.text.trim(),
        email: _emailController.text.trim(),
        especialidad: _especialidadController.text.trim(),
        telefono: _telefonoController.text.trim(),
        carnetTimonel: _carnetController.text.trim(),
        polizaSeguro: _polizaController.text.trim(),
        cbu: _cbuController.text.trim(),
        bancoNombre: _bancoController.text.trim(),
        avatarUrl: _fotoPerfilUrl,
        seguroUrl: _seguroUrl,
        embarcacionUrl: _embarcacionUrl,
        carnetUrl: _carnetTimonelUrl,
        dniUrl: _dniFrontUrl,
        referido: codigoReferidoFinal,
      );

      print('?? DEBUG DB: ${jsonEncode(guia.toMap())}');
      await SupabaseService.guardarGuia(guia, referidoId: comisionistaId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Bienvenido Capitan! Registro completado.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al guardar perfil: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Capa 0: Fondo Solido/Gradiente (Failsafe)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D47A1), Color(0xFF00153D)],
              ),
            ),
          ),
          
          // Capa 1: Fondo Dinamico Caching
          Image.network(
             _bgUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const SizedBox.shrink();
            },
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          ),

          // Capa 2: Filtro de Oscurecimiento
          Container(color: Colors.black.withOpacity(0.4)),

          // Capa 3: Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(begin: const Offset(0.1, 0), end: Offset.zero).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _currentStep == RegistroStep.auth ? _buildAuthStep() : _buildProfileStep(),
                ),
              ),
            ),
          ),
          
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildAuthStep() {
    return Column(
      key: const ValueKey('auth_step'),
      children: [
        const Icon(Icons.anchor, size: 60, color: Colors.white),
        const SizedBox(height: 10),
        const Text(
          'EL GUIA YA',
          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        const SizedBox(height: 30),
        _buildGlassContainer(
          child: Column(
            children: [
              const Text('Crea tu cuenta', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
              const SizedBox(height: 20),
              _buildModernField(_emailController, 'Email', Icons.email),
              _buildModernField(_passwordController, 'Contrasena', Icons.lock, isPassword: true, 
                obscure: _obscurePassword, onToggle: () => setState(() => _obscurePassword = !_obscurePassword)),
              _buildModernField(_confirmPasswordController, 'Confirmar Contrasena', Icons.lock_outline, isPassword: true,
                obscure: _obscureConfirmPassword, onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '¿Fuiste referido por un promotor?',
                      style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Switch(
                    value: _traeReferido,
                    activeColor: Colors.orangeAccent,
                    onChanged: (val) {
                      setState(() {
                        _traeReferido = val;
                      });
                    },
                  ),
                ],
              ),
              if (_traeReferido) ...[
                const SizedBox(height: 10),
                _buildModernField(_referidoController, 'Código de Promotor', Icons.card_giftcard_rounded),
              ],
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_isLoading || _cooldownSeconds > 0) ? null : _avanzarAlPerfil,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0D47A1),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _cooldownSeconds > 0 
                    ? Text('ESPERA ($_cooldownSeconds s)')
                    : const Text('SIGUIENTE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileStep() {
    return Column(
      key: const ValueKey('profile_step'),
      children: [
        const Text('Datos de Capitan', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildGlassContainer(
          child: Column(
            children: [
              _buildModernField(_nombreController, 'Nombre Completo', Icons.person),
              _buildModernField(_dniController, 'DNI', Icons.badge, type: TextInputType.number),
              _buildModernField(_telefonoController, 'Telefono', Icons.phone, type: TextInputType.phone),
              
              const SizedBox(height: 10),
              const Text('Domicilio', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(flex: 3, child: _buildModernField(_calleController, 'Calle', Icons.add_road)),
                  const SizedBox(width: 10),
                  Expanded(flex: 1, child: _buildModernField(_alturaController, 'Nº', Icons.numbers, type: TextInputType.number)),
                ],
              ),
              Row(
                children: [
                  Expanded(child: _buildModernField(_localidadController, 'Localidad', Icons.location_city)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildModernField(_provinciaController, 'Provincia', Icons.map)),
                ],
              ),
              
              Row(
                children: [
                  Expanded(flex: 3, child: _buildModernField(_cbuController, 'CBU / Alias', Icons.account_balance_wallet)),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: _buildModernField(_bancoController, 'Banco / Entidad', Icons.account_balance)),
                ],
              ),
              
              const SizedBox(height: 15),
              const Divider(color: Colors.white24),
              const Text('Documentacion', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              CameraPicker(
                userId: _currentUserId,
                tipoDoc: Documento.FOTO_PERFIL_CAPITAN,
                titulo: 'Foto de Perfil',
                icono: Icons.face,
                onImageSelected: (_) {},
                onUrlGenerated: (url) => setState(() => _fotoPerfilUrl = url),
              ),
              CameraPicker(
                userId: _currentUserId,
                tipoDoc: Documento.DNI_CAPITAN,
                titulo: 'DNI (Frente)',
                icono: Icons.badge,
                onImageSelected: (_) {},
                onUrlGenerated: (url) => setState(() => _dniFrontUrl = url),
              ),
              CameraPicker(
                userId: _currentUserId,
                tipoDoc: Documento.SEGURO,
                titulo: 'Poliza de Seguro',
                icono: Icons.verified_user,
                onImageSelected: (_) {},
                onUrlGenerated: (url) => setState(() => _seguroUrl = url),
              ),
              
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: (_isLoading || _dniFrontUrl == null) ? null : _finalizarRegistro,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent[400],
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text('FINALIZAR REGISTRO', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGlassContainer({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildModernField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, bool? obscure, VoidCallback? onToggle, TextInputType type = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? (obscure ?? true) : false,
        keyboardType: type,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          prefixIcon: Icon(icon, color: Colors.white70, size: 20),
          suffixIcon: isPassword ? IconButton(
            icon: Icon(obscure! ? Icons.visibility : Icons.visibility_off, color: Colors.white70, size: 20),
            onPressed: onToggle,
          ) : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white38)),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 20),
            Text(_statusMsg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
