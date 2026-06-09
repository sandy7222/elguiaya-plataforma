import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:El Guia YA_master/services/branding_service.dart';
import 'package:El Guia YA_master/services/seguridad_service.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';
import 'package:El Guia YA_master/services/translation_service.dart';
import 'package:El Guia YA_master/screens/admin_dashboard_screen.dart';
import 'package:El Guia YA_master/screens/portal_capitan_screen.dart';
import 'package:El Guia YA_master/screens/portal_pescador_screen.dart';
import 'package:El Guia YA_master/screens/registro_maestro_screen.dart';
import 'package:El Guia YA_master/widgets/failsafe_background.dart';
import 'package:El Guia YA_master/utils/cya_styles.dart';

class BienvenidaDefinitivaScreen extends StatefulWidget {
  const BienvenidaDefinitivaScreen({super.key});

  @override
  State<BienvenidaDefinitivaScreen> createState() =>
      _BienvenidaDefinitivaScreenState();
}

class _BienvenidaDefinitivaScreenState extends State<BienvenidaDefinitivaScreen> {
  // Variables dinamicas de configuracion para administrador
  String? _backgroundUrl; // Se cargara desde Supabase
  String? _logoUrl; // URL dinamica del logo desde Supabase
  double _opacity = 0.5; // Opacidad del overlay - controlable por administrador
  double _brightness = 1.0; // Brillo de la imagen - controlable por administrador
  bool _isLoading = true;
  bool _sessionChecked = false; // true cuando ya verificamos la sesion
  final bool _isImageLoading = false; // Estado especifico para carga de imagen
  final bool _esLogin = true; // Switch: true = Login, false = Registro
  String _rolSeleccionado = 'pescador'; // 'pescador' o 'capitan'
  StreamSubscription? _configSubscription;

  // Controladores para formulario
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isProcessing = false;
  bool _showCredentials = true; // Hardcodeado para que los campos siempre sean visibles

  // Textos legales (se cargan dinamicamente desde Supabase)
  String _textoAyuda = 'Cargando informacion de ayuda...';
  String _textoTerminos = 'Cargando terminos y condiciones...';

  // Colores El Guia YA - Modernizados (ahora mutables)
  final Color _fondoPorDefecto = const Color(0xFF0D47A1);
  final Color _blancoPuro = const Color(0xFFFFFFFF);
  Color _azulVibrante = const Color(0xFF0066FF);
  Color _verdeVibrante = const Color(0xFF00E676); // Verde El Guia YA Premium
  Color _naranjaIntenso = const Color(0xFF00E676);
  final Color _grisMedio = const Color(0xFF666666);
  final Color _rojoFuerte = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    TranslationService.initialize();
    _iniciarAppSeguro();
  }

  Future<void> _iniciarAppSeguro() async {
    try {
      // Verificar sesión INMEDIATAMENTE sin delay innecesario
      await _verificarSesionActiva();
      _cargarConfiguracionBranding();
      _escucharConfiguracionEnTiempoReal();
    } catch (e) {
      print('⚠️ [BIENVENIDA] Error en inicializacion silenciosa: $e');
      setState(() {
        _isLoading = false;
        _sessionChecked = true;
      });
    }
  }

  Future<void> _verificarSesionActiva() async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session != null) {
        print('🔐 [AUTH] Sesion persistente detectada. Redirigiendo...');
        if (mounted) {
          final userId = session.user.id;
          final email = session.user.email ?? '';
          
          final bool isHardcodedAdmin = email.toLowerCase().trim() == 'admin@El Guia YA.com';
          final bool isMetadataAdmin = session.user.userMetadata?['rol']?.toString().toLowerCase() == 'admin';

          if (isHardcodedAdmin || isMetadataAdmin) {
            print('👑 [AUTH] Administrador detectado. Redirigiendo a Dashboard...');
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const AdminDashboardScreen()));
            return;
          }

          final perfil = await Supabase.instance.client.from('profiles').select('es_capitan, estado').eq('user_id', userId).maybeSingle();
          if (perfil != null) {
            final bool esCapitan = perfil['es_capitan'] == true;
            final String estado = perfil['estado'] ?? 'pendiente';

            if (esCapitan && estado == 'pendiente') {
              print('⏳ [AUTH] Capitán pendiente. Manteniendo en bienvenida...');
              setState(() { _isLoading = false; _sessionChecked = true; });
              return;
            }

            if (esCapitan) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PortalCapitanScreen()));
            } else {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PortalPescadorScreen()));
            }
          } else {
            setState(() { _isLoading = false; _sessionChecked = true; });
          }
        }
      } else {
        setState(() { _isLoading = false; _sessionChecked = true; });
      }
    } catch (e) {
      print('⚠️ Error verificando sesion: $e');
      if (mounted) setState(() { _isLoading = false; _sessionChecked = true; });
    }
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _cargarConfiguracionBranding() async {
    final configStartTime = DateTime.now();
    
    try {
      final config = await BrandingService.getLoginConfig().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          return LoginConfig(
            backgroundUrl: 'https://images.weserv.nl/?url=ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/portada_inicio.jpg',
            opacity: 0.5,
            brightness: 1.0,
          );
        },
      );
      
      final textosLegales = await BrandingService.getTextosLegales();
      
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
          _brightness = config.brightness;
          if (textosLegales['texto_ayuda']?.isNotEmpty == true) _textoAyuda = textosLegales['texto_ayuda']!;
          if (textosLegales['texto_terminos']?.isNotEmpty == true) _textoTerminos = textosLegales['texto_terminos']!;
          _isLoading = false;
        });
      }

      final sub = BrandingService.getBrandingStream().listen((configs) {
        if (mounted) {
          setState(() {
            for (var config in configs) {
              if (config.clave == 'color_primario' && config.valor != null) {
                _azulVibrante = Color(int.parse(config.valor!.replaceFirst('#', '0xFF')));
              } else if (config.clave == 'color_secundario' && config.valor != null) {
                _naranjaIntenso = Color(int.parse(config.valor!.replaceFirst('#', '0xFF')));
              } else if (config.clave == 'color_acento' && config.valor != null) {
                _verdeVibrante = Color(int.parse(config.valor!.replaceFirst('#', '0xFF')));
              } else if (config.clave == 'logo_url' && config.valor != null && config.valor!.isNotEmpty) {
                _logoUrl = BrandingService.getSafeUrl(config.valor);
              }
            }
          });
        }
      });
      _configSubscription?.cancel();
      _configSubscription = sub;

    } catch (e) {
      if (mounted) {
        setState(() {
          _backgroundUrl = null;
          _opacity = 0.5;
          _brightness = 1.0;
          _isLoading = false;
          _showCredentials = true;
        });
      }
    }
  }

  void _escucharConfiguracionEnTiempoReal() {
    _configSubscription = BrandingService.getLoginConfigStream().listen((config) {
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
          _brightness = config.brightness;
          _isLoading = false;
        });
      }
    });
  }

  Widget _buildGlassContainer({required Widget child, double padding = 24}) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4), child: child),
      ),
    );
  }

  Widget _buildLoginAction() {
    return CYAStyles.primaryButton(
      label: 'ingresar'.t().toUpperCase(),
      onPressed: _procesarAcceso,
      isLoading: _isProcessing,
      gradientColors: const [CYAStyles.accentGreen, Color(0xFF69F0AE)],
    );
  }

  Widget _buildRegistrationSection() {
    return Column(
      children: [
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('¿NUEVO EN EL GUIA YA?', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildDirectRegisterButton(
                icon: Icons.sailing,
                title: 'PESCADOR',
                onTap: () {
                  setState(() => _rolSeleccionado = 'pescador');
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegistroMaestroScreen(initialRole: 'pescador')));
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildDirectRegisterButton(
                icon: Icons.anchor,
                title: 'CAPITÁN',
                onTap: () {
                  setState(() => _rolSeleccionado = 'capitan');
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const RegistroMaestroScreen(initialRole: 'capitan')));
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectRegisterButton({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: _verdeVibrante, size: 32),
            const SizedBox(height: 8),
            Text('REGISTRO', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialsForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: CYAStyles.glassCard(borderOpacity: 0.25),
      child: Column(
        children: [
          _buildInputField(controller: _emailController, label: 'email'.t(), icon: Icons.email_outlined, obscureText: false),
          const SizedBox(height: 16),
          _buildInputField(controller: _passwordController, label: 'password'.t(), icon: Icons.lock_outline, obscureText: !_showCredentials, showToggle: true),
        ],
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String label, required IconData icon, required bool obscureText, bool showToggle = false}) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white, fontSize: 16),
      decoration: CYAStyles.inputDecoration(
        label: label,
        icon: icon,
        accentColor: CYAStyles.accentGreen,
      ).copyWith(
        suffixIcon: showToggle ? IconButton(
          icon: Icon(
            _showCredentials ? Icons.visibility : Icons.visibility_off, 
            color: Colors.white70,
            size: 20,
          ), 
          onPressed: () => setState(() => _showCredentials = !_showCredentials),
        ) : null,
      ),
    );
  }

  Future<void> _procesarAcceso() async {
    final String email = _emailController.text.trim().toLowerCase();
    final String password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email y contrasena requeridos')));
      return;
    }
    
    setState(() => _isProcessing = true);
    
    try {
      // Autenticación estrictamente a través de Supabase
      final authResponse = await SupabaseService.supabase.auth.signInWithPassword(email: email, password: password);
      
      if (authResponse.session != null) {
        final userId = authResponse.user!.id;
        final email = authResponse.user!.email!;
        
        final bool isHardcodedAdmin = email.toLowerCase().trim() == 'admin@El Guia YA.com';
        final bool isMetadataAdmin = authResponse.user!.userMetadata?['rol']?.toString().toLowerCase() == 'admin';

        if (isHardcodedAdmin || isMetadataAdmin) {
          print('👑 [AUTH] Administrador detectado. Redirigiendo a Dashboard...');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          );
          return;
        }
        

        final estadoLogin = await SeguridadService.verificarEstadoLogin(email);
        final String estadoCuenta = estadoLogin['estado_cuenta'] ?? 'activo';
        if (!(estadoLogin['permitido'] ?? true) && estadoCuenta != 'suspendido') {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(estadoLogin['mensaje'] ?? 'Cuenta suspendida.'), backgroundColor: _rojoFuerte));
          await SupabaseService.supabase.auth.signOut();
          return;
        }

        // 2. Bypass de Roles: Buscar perfil, si no existe o falla, dejar pasar como Pescador
        Map<String, dynamic>? perfil;
        try {
          perfil = await SupabaseService.supabase.from('profiles').select('es_capitan, estado').eq('user_id', userId).maybeSingle();
        } catch (e) {
        }
        
        if (perfil != null) {
          final bool esCapitan = perfil['es_capitan'] == true;
          String estado = perfil['estado'] ?? 'pendiente';

          // --- MANIOBRA AUTO-PILOTO 48HS ---
          if (estado == 'pendiente') {
            await SupabaseService.verificarAutoAprobacion(userId);
            // Volver a consultar el estado por si cambió
            final nuevoPerfil = await SupabaseService.supabase.from('profiles').select('estado').eq('user_id', userId).single();
            estado = nuevoPerfil['estado'];
          }
          // ---------------------------------

          final String nombre = perfil['nombre'] ?? 'Usuario';
          

          if (esCapitan) {
            if (estado == 'pendiente') {
              // Si es capitán y está pendiente, NO dejar pasar y mostrar aviso
              setState(() => _isProcessing = false);
              _mostrarAvisoEstado(context, 'Pendiente de Aprobación', true);
              return;
            }
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PortalCapitanScreen()));
          } else {
            // Laura entra como Pescador aunque su estado sea pendiente
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PortalPescadorScreen()));
          }
        } else {
          Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const PortalPescadorScreen()));
        }
      }
    } on AuthException catch (e) {
      // 🚨 CAPTURADOR DETALLADO DE SUPABASE
      debugPrint('==================================================');
      debugPrint('🔥 [SUPABASE AUTH ERROR] Falla de Autenticación');
      debugPrint('📧 Correo evaluado: [$email]');
      debugPrint('🔑 Longitud del password: ${password.length}');
      debugPrint('❌ Código de Error: ${e.statusCode}');
      debugPrint('💬 Mensaje original: ${e.message}');
      debugPrint('==================================================');

      String errorMsg = 'Error de conexión. Verifica tus datos.';
      if (e.message.contains('Invalid login credentials')) {
        errorMsg = 'Usuario inexistente o contraseña incorrecta.';
      } else if (e.message.contains('Email not confirmed')) {
        errorMsg = 'Debes confirmar tu correo electrónico. Revisa tu bandeja de entrada.';
      } else {
        errorMsg = 'Error Auth (${e.statusCode}): ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(errorMsg), 
        backgroundColor: _rojoFuerte,
        duration: const Duration(seconds: 8),
      ));
    } catch (e) {
      debugPrint('🚨 [ERROR GENERAL LOGIN] $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error inesperado: $e'), 
        backgroundColor: _rojoFuerte,
        duration: const Duration(seconds: 5),
      ));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _mostrarAvisoEstado(BuildContext context, String estado, bool esCapitan) {
    String titulo = esCapitan ? 'Cuenta en Revisión' : 'Acceso Restringido';
    String mensaje = esCapitan ? '¡Hola Capitán! Tu documentación está siendo revisada.' : 'Tu cuenta se encuentra en estado "$estado".';
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ENTENDIDO'))],
      ),
    );
  }


  Widget _buildHeader() {
    return _buildGlassContainer(
      padding: 28,
      child: Column(
        children: [
          _logoUrl != null && _logoUrl!.isNotEmpty
              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_logoUrl!, height: 100, fit: BoxFit.contain, errorBuilder: (context, error, stackTrace) => Image.asset('assets/images/logo_elguiaya.png', height: 100)))
              : Image.asset('assets/images/logo_elguiaya.png', height: 100),
          const SizedBox(height: 16),
          Text('welcome_title'.t(), style: TextStyle(color: _blancoPuro, fontSize: 36, fontWeight: FontWeight.bold, letterSpacing: 3.5)),
          const SizedBox(height: 12),
          Text('welcome_subtitle'.t(), style: TextStyle(color: _blancoPuro.withOpacity(0.85), fontSize: 16, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        GestureDetector(onTap: () => _mostrarDialogo('help'.t(), _textoAyuda), child: Text('help'.t(), style: TextStyle(color: _blancoPuro.withOpacity(0.7), fontSize: 13, decoration: TextDecoration.underline))),
        const SizedBox(height: 16),
        GestureDetector(onTap: () => _mostrarDialogo('terms_conditions'.t(), _textoTerminos), child: Text('terms_conditions'.t(), style: TextStyle(color: _blancoPuro.withOpacity(0.7), fontSize: 13, decoration: TextDecoration.underline))),
      ],
    );
  }

  void _mostrarDialogo(String titulo, String contenido) {
    showDialog(context: context, builder: (context) => AlertDialog(title: Text(titulo), content: SingleChildScrollView(child: Text(contenido)), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))]));
  }

  @override
  Widget build(BuildContext context) {
    // ── SPLASH DE CARGA (mientras verificamos sesión) ──
    if (!_sessionChecked) {
      return Scaffold(
        backgroundColor: const Color(0xFF001429),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(
                'https://ymgsxwfwntbqvguvbhoa.supabase.co/storage/v1/object/public/branding/logo_El Guia YA.png',
                height: 90,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.anchor_rounded,
                  color: Color(0xFF00E676),
                  size: 72,
                ),
              ),
              const SizedBox(height: 32),
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Color(0xFF00E676),
                  strokeWidth: 2.5,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'VERIFICANDO SESIÓN...',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── PANTALLA DE LOGIN NORMAL ──
    return Scaffold(
      backgroundColor: Colors.black,
      body: FailsafeBackground(
        imageUrl: _backgroundUrl,
        opacity: _opacity,
        overlayColor: const Color(0xFF001F3F),
        brightness: _brightness,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 20, bottom: 60), 
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildHeader(),
                const SizedBox(height: 32),
                _buildCredentialsForm(),
                const SizedBox(height: 24),
                _buildLoginAction(),
                const SizedBox(height: 48),
                _buildRegistrationSection(),
                const SizedBox(height: 48),
                _buildFooter(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
