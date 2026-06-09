import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/documento.dart';
import '../models/pescador.dart';
import '../services/supabase_service.dart';
import '../widgets/camera_picker.dart';
import 'portal_pescador_screen.dart';

enum RegistroStep { auth, profile }

class RegistroPescadorScreen extends StatefulWidget {
  const RegistroPescadorScreen({super.key});

  @override
  State<RegistroPescadorScreen> createState() => _RegistroPescadorScreenState();
}

class _RegistroPescadorScreenState extends State<RegistroPescadorScreen> {
  final _nombreController = TextEditingController();
  final _dniController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _cpController = TextEditingController();
  final _calleController = TextEditingController();
  final _alturaController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _referidoController = TextEditingController();
  final _emergenciaNombreController = TextEditingController();
  final _emergenciaTelefonoController = TextEditingController();
  bool _traeReferido = false;

  // ── Tipo de viaje y servicios del capitán-pescador
  bool _haceSalidaPescaEmbarcada = false;
  bool _haceTraslado = false;
  bool _ofreceCabana = false;
  bool _tieneBano = false;
  String? _cabanaFotoUrl;
  String? _banoFotoUrl;

  RegistroStep _currentStep = RegistroStep.auth;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Control Anti-429
  int _cooldownSeconds = 0;
  int _attemptsCount = 0;
  DateTime? _lastAttemptTime;

  // URLs de archivos subidos
  String? _dniUrl;
  String? _avatarUrl;

  bool _isLoading = false;
  String _statusMsg = '';
  String _currentUserId = 'temp_${DateTime.now().millisecondsSinceEpoch}';

  @override
  void dispose() {
    _nombreController.dispose();
    _dniController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _telefonoController.dispose();
    _cpController.dispose();
    _calleController.dispose();
    _alturaController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    _referidoController.dispose();
    _emergenciaNombreController.dispose();
    _emergenciaTelefonoController.dispose();
    super.dispose();
  }

  Future<void> _avanzarAlPerfil() async {
    // 1. Verificar Cooldown
    if (_cooldownSeconds > 0) {
      _showError('Por seguridad, espera $_cooldownSeconds segundos antes de reintentar.');
      return;
    }

    // 2. Cache de Sesion: Si ya hay usuario, saltar Auth
    final existingUser = Supabase.instance.client.auth.currentUser;
    if (existingUser != null) {
      print('📦 [ANTI-429 PESCADOR] Sesion existente detectada. Saltando Auth.');
      setState(() {
        _currentUserId = existingUser.id;
        _currentStep = RegistroStep.profile;
      });
      return;
    }

    if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
      _showError('Por favor completa Email y Contraseña');
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Las contraseñas no coinciden');
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
    print('🚨 [ANTI-429 PESCADOR] Intento de Auth #$_attemptsCount');

    setState(() {
      _isLoading = true;
      _statusMsg = 'Preparando tu acceso seguro...';
    });

    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user != null) {
        setState(() => _statusMsg = 'Acceso seguro verificado (2s)...');
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
        _showError('El email ya existe. Inicia sesión.');
        _startCooldown(30);
      } else if (e.toString().contains('429') || e.toString().contains('over_email_send_rate_limit')) {
        _showError('BLOQUEO DE EMAIL: Usa el "MODO TEST" abajo.');
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
    if (_nombreController.text.trim().isEmpty || 
        _dniController.text.trim().isEmpty || 
        _telefonoController.text.trim().isEmpty ||
        _emergenciaNombreController.text.trim().isEmpty ||
        _emergenciaTelefonoController.text.trim().isEmpty) {
      _showError('Por favor completa los campos obligatorios y de emergencia (para aviso en caso de accidente).');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMsg = 'Validando referido y activando cuenta...';
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

      final pescador = Pescador(
        id: Supabase.instance.client.auth.currentUser?.id ?? _currentUserId,
        nombre: _nombreController.text.trim(),
        dni: _dniController.text.trim(),
        localidad: _localidadController.text.trim(), 
        provincia: _provinciaController.text.trim(),
        calle: _calleController.text.trim(),
        altura: _alturaController.text.trim(),
        email: _emailController.text.trim(),
        cp: _cpController.text.trim(),
        telefono: _telefonoController.text.trim(),
        dniUrl: _dniUrl,
        avatarUrl: _avatarUrl,
        referido: codigoReferidoFinal,
        bioPescador: 'Emergencia: ${_emergenciaNombreController.text.trim()} (Tel: ${_emergenciaTelefonoController.text.trim()})',
      );

      // Metadatos adicionales de tipo de viaje y servicios
      final extras = {
        'salida_pesca_embarcada': _haceSalidaPescaEmbarcada,
        'traslado_ida_vuelta_isla': _haceTraslado,
        'ofrece_cabana': _ofreceCabana,
        'tiene_bano': _tieneBano,
        if (_cabanaFotoUrl != null) 'foto_cabana_url': _cabanaFotoUrl,
        if (_banoFotoUrl != null) 'foto_bano_url': _banoFotoUrl,
      };

      print('📝 DEBUG DB PESCADOR: ${jsonEncode(pescador.toMap())}');
      await SupabaseService.guardarPescador(pescador, referidoId: comisionistaId);

      // Guardar extras de tipo de viaje y servicios en profiles
      try {
        await Supabase.instance.client
            .from('profiles')
            .update(extras)
            .eq('user_id', pescador.id!);
      } catch (e) {
        debugPrint('⚠️ No se pudieron guardar extras del pescador: $e');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('¡Bienvenido! Registro completado.', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const PortalPescadorScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Error al activar perfil: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF000B21),
      body: Stack(
        children: [
          // Capa 0: Gradiente de Fondo Ultra Premium (Diseño Sistema)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF000B21), // Azul medianoche ultra oscuro
                  Color(0xFF0A192F), // Azul marino militar
                  Color(0xFF172A45), // Azul cobalto profundo
                ],
              ),
            ),
          ),
          
          // Capa 1: Orbes Luminosos de Fondo para Profundidad Tridimensional
          Positioned(
            top: -120,
            right: -120,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.18),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90.0, sigmaY: 90.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.cyanAccent.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 70.0, sigmaY: 70.0),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Capa 2: Contenido
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Cabecera Corporativa de EL GUIA YA
                    _buildHeader(),
                    const SizedBox(height: 28),
                    
                    // Card Glassmorphic de Pasos
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      switchInCurve: Curves.easeIn,
                      switchOutCurve: Curves.easeOut,
                      child: _currentStep == RegistroStep.auth ? _buildAuthStep() : _buildProfileStep(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.blue.withOpacity(0.2)),
          ),
          child: const Icon(
            Icons.anchor_rounded,
            color: Colors.blueAccent,
            size: 38,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'EL GUIA YA',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Inscripción de Pescadores Deportivos',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthStep() {
    return _buildGlassCard(
      key: const ValueKey('auth_step_pescador_modern'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PASO 1: CREDENCIALES DE ACCESO',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildModernField(
            _emailController,
            'Correo Electrónico',
            Icons.email_outlined,
            hintText: 'usuario@ejemplo.com',
            type: TextInputType.emailAddress,
          ),
          
          _buildModernField(
            _passwordController,
            'Contraseña',
            Icons.lock_open_rounded,
            isPassword: true,
            obscure: _obscurePassword,
            onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
            hintText: 'Crea una contraseña segura',
          ),
          
          _buildModernField(
            _confirmPasswordController,
            'Confirmar Contraseña',
            Icons.lock_outline_rounded,
            isPassword: true,
            obscure: _obscureConfirmPassword,
            onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            hintText: 'Repite tu contraseña',
          ),
          
          // CAMPO DE REFERIDO OPCIONAL (Pedido por el usuario)
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
                activeColor: Colors.blueAccent,
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
            _buildModernField(
              _referidoController,
              'Código de Promotor',
              Icons.card_giftcard_rounded,
              hintText: 'Ej: PROMO-5678',
            ),
          ],
          
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_isLoading || _cooldownSeconds > 0) ? null : _avanzarAlPerfil,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
                shadowColor: Colors.blueAccent.withOpacity(0.3),
              ),
              child: _cooldownSeconds > 0 
                  ? Text('ESPERA ($_cooldownSeconds s)', style: const TextStyle(fontWeight: FontWeight.bold))
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('AVANZAR AL PERFIL', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16),
                      ],
                    ),
            ),
          ),
          
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: _isLoading ? null : _entrarComoInvitadoTest,
              child: Text(
                'Entrar en Modo Test (Bypass)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 12,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileStep() {
    return _buildGlassCard(
      key: const ValueKey('profile_step_pescador_modern'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_pin_rounded, color: Colors.blueAccent, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'PASO 2: DATOS PERSONALES Y DOMICILIO',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          _buildModernField(
            _nombreController,
            'Nombre Completo',
            Icons.person_outline_rounded,
            hintText: 'Ej: Juan Pérez',
          ),
          
          Row(
            children: [
              Expanded(
                child: _buildModernField(
                  _dniController,
                  'DNI',
                  Icons.badge_outlined,
                  hintText: 'Ej: 38455667',
                  type: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernField(
                  _telefonoController,
                  'Teléfono',
                  Icons.phone_iphone_rounded,
                  hintText: 'Ej: 1123456789',
                  type: TextInputType.phone,
                ),
              ),
            ],
          ),
          
          const Text(
            'Dirección de Domicilio',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildModernField(
                  _calleController,
                  'Calle',
                  Icons.add_road_rounded,
                  hintText: 'Calle',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: _buildModernField(
                  _alturaController,
                  'N°',
                  null,
                  hintText: 'N°',
                  type: TextInputType.number,
                ),
              ),
            ],
          ),
          
          Row(
            children: [
              Expanded(
                child: _buildModernField(
                  _localidadController,
                  'Localidad',
                  Icons.location_city_rounded,
                  hintText: 'Localidad',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernField(
                  _provinciaController,
                  'Provincia',
                  Icons.map_rounded,
                  hintText: 'Provincia',
                ),
              ),
            ],
          ),
          
          _buildModernField(
            _cpController,
            'Código Postal',
            Icons.pin_drop_rounded,
            hintText: 'Ej: 1425',
            type: TextInputType.number,
            maxLength: 4,
          ),
          
          const SizedBox(height: 8),
          const Divider(color: Colors.white10),
          const SizedBox(height: 8),

          const Text(
            'Contacto de Emergencia (Aviso de Accidentes)',
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          _buildModernField(
            _emergenciaNombreController,
            'Nombre del Contacto Referente',
            Icons.contact_phone_outlined,
            hintText: 'Ej: María Pérez (Madre / Esposa)',
          ),

          _buildModernField(
            _emergenciaTelefonoController,
            'Teléfono de Emergencia',
            Icons.emergency_outlined,
            hintText: 'Ej: 1198765432',
            type: TextInputType.phone,
          ),
          
          const SizedBox(height: 8),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // ── TIPO DE VIAJE ─────────────────────────────────────────
          const Text(
            'TIPO DE VIAJE CON LA EMBARCACIÓN',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Declaración obligatoria para calificación de comportamiento',
            style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            label: 'Salida de Pesca Embarcada',
            subtitle: 'Salida al río para pesca deportiva con el capitán',
            icon: Icons.directions_boat_rounded,
            value: _haceSalidaPescaEmbarcada,
            onChanged: (val) => setState(() => _haceSalidaPescaEmbarcada = val),
          ),

          _buildSwitchTile(
            label: 'Traslado ida y vuelta a la Isla',
            subtitle: 'Servicio de transferencia de pescadores a la isla',
            icon: Icons.swap_horiz_rounded,
            value: _haceTraslado,
            onChanged: (val) => setState(() => _haceTraslado = val),
          ),

          const SizedBox(height: 8),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // ── SERVICIOS ADICIONALES ─────────────────────────────────
          const Text(
            'SERVICIOS ADICIONALES',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),

          _buildSwitchTile(
            label: 'Ofrece Cabaña',
            subtitle: 'El capitán dispone de cabaña para los pescadores',
            icon: Icons.cottage_rounded,
            value: _ofreceCabana,
            onChanged: (val) => setState(() {
              _ofreceCabana = val;
              if (!val) _cabanaFotoUrl = null;
            }),
          ),

          if (_ofreceCabana) ...[
            const SizedBox(height: 8),
            CameraPicker(
              userId: _currentUserId,
              tipoDoc: 'foto_cabana',
              titulo: 'Foto de la Cabaña',
              icono: Icons.photo_camera_rounded,
              onImageSelected: (_) {},
              onUrlGenerated: (url) => setState(() => _cabanaFotoUrl = url),
            ),
            const SizedBox(height: 8),
          ],

          _buildSwitchTile(
            label: 'Tiene Baño',
            subtitle: 'Dispone de instalaciones sanitarias en el punto de embarque',
            icon: Icons.wc_rounded,
            value: _tieneBano,
            onChanged: (val) => setState(() {
              _tieneBano = val;
              if (!val) _banoFotoUrl = null;
            }),
          ),

          if (_tieneBano) ...[
            const SizedBox(height: 8),
            CameraPicker(
              userId: _currentUserId,
              tipoDoc: 'foto_bano',
              titulo: 'Foto del Baño',
              icono: Icons.photo_camera_rounded,
              onImageSelected: (_) {},
              onUrlGenerated: (url) => setState(() => _banoFotoUrl = url),
            ),
            const SizedBox(height: 8),
          ],

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // ── FOTO DE PERFIL Y DOCUMENTO ────────────────────────────
          const Text(
            'FOTO DE PERFIL Y DOCUMENTO',
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),
          
          CameraPicker(
            userId: _currentUserId,
            tipoDoc: Documento.FOTO_PERFIL_PESCADOR,
            titulo: 'Fotografía de Perfil',
            icono: Icons.face_rounded,
            onImageSelected: (_) {},
            onUrlGenerated: (url) => setState(() => _avatarUrl = url),
          ),
          const SizedBox(height: 12),
          CameraPicker(
            userId: _currentUserId,
            tipoDoc: Documento.DNI_PESCADOR,
            titulo: 'DNI (Frente)',
            icono: Icons.portrait_rounded,
            onImageSelected: (_) {},
            onUrlGenerated: (url) => setState(() => _dniUrl = url),
          ),
          
          const SizedBox(height: 28),
          
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: (_isLoading || _dniUrl == null) ? null : _finalizarRegistro,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E676), // Verde esmeralda náutico premium
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF00E676).withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: const Color(0xFF00E676).withOpacity(0.3),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text(
                    '¡LISTO PARA NAVEGAR!',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          if (_dniUrl == null)
            Center(
              child: Text(
                '⚠️ Debes subir la foto de tu DNI para finalizar',
                style: TextStyle(color: Colors.orangeAccent.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child, required Key key}) {
    return Container(
      key: key,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildModernField(
    TextEditingController controller, 
    String label, 
    IconData? icon, {
      bool isPassword = false, 
      bool? obscure, 
      VoidCallback? onToggle, 
      TextInputType type = TextInputType.text, 
      int? maxLength,
      String? hintText,
    }
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: isPassword ? (obscure ?? true) : false,
            keyboardType: type,
            maxLength: maxLength,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
              filled: true,
              fillColor: Colors.white.withOpacity(0.04),
              prefixIcon: icon != null ? Icon(icon, color: Colors.white.withOpacity(0.4), size: 20) : null,
              suffixIcon: isPassword ? IconButton(
                icon: Icon(obscure! ? Icons.visibility : Icons.visibility_off, color: Colors.white.withOpacity(0.4), size: 20),
                onPressed: onToggle,
              ) : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
              ),
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.blueAccent),
            const SizedBox(height: 24),
            Text(
              _statusMsg,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String label,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? Colors.blueAccent.withOpacity(0.08)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? Colors.blueAccent.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value
                  ? Colors.blueAccent.withOpacity(0.15)
                  : Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: value ? Colors.blueAccent : Colors.white38,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: value ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: Colors.blueAccent,
            activeTrackColor: Colors.blueAccent.withOpacity(0.3),
            inactiveThumbColor: Colors.white30,
            inactiveTrackColor: Colors.white.withOpacity(0.08),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
