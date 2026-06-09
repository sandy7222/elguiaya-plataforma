

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/branding_service.dart';
import '../services/supabase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  StreamSubscription? _configSubscription;

  // Controladores y Estados
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Variables de Branding dinamico
  String? _backgroundUrl;
  double _opacity = 0.5;
  double _brightness = 1.0;
  final Color _primaryColor = const Color(0xFF0D47A1);
  final String _welcomeText = 'Bienvenido a El Guia YA';

  @override
  void initState() {
    super.initState();
    // Suscripcion a los cambios de configuracion de branding en tiempo real
    _configSubscription = BrandingService.getLoginConfigStream().listen((config) {
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
          _brightness = config.brightness;
        });
      }
    });
  }

  @override
  void dispose() {
    _configSubscription?.cancel(); //
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          _buildFormContent(),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    if (_backgroundUrl != null && _backgroundUrl!.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Filtro de brillo aplicado directamente a los pixeles de la imagen
          ColorFiltered(
            colorFilter: ColorFilter.matrix(<double>[
              _brightness, 0, 0, 0, 0,
              0, _brightness, 0, 0, 0,
              0, 0, _brightness, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            child: Image.network(
              _backgroundUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
            ),
          ),
          // Capa de opacidad (Overlay)[cite: 1]
          Container(
            color: Colors.black.withOpacity(_opacity),
          ),
        ],
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_primaryColor, Colors.black],
        ),
      ),
    );
  }

  Widget _buildFormContent() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/logo_elguiaya.png', height: 100),
              const SizedBox(height: 20),
              Text(
                _welcomeText,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField(
                controller: _emailController,
                hint: 'Email',
                icon: Icons.email_outlined,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                hint: 'Contrasena',
                icon: Icons.lock_outline,
                isPassword: true,
              ),
              const SizedBox(height: 30),
              _buildLoginButton(),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/registro'),
                child: const Text(
                  '¿No tienes cuenta? Registrate',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword && !_isPasswordVisible,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.white70),
        suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.white70,
              ),
              onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
            )
          : null,
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Por favor completa todos los campos'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      // ✅ Apagar el spinner del botón aquí mismo —
      // el SessionWrapper (main.dart) ya escucha onAuthStateChange
      // y mostrará su propio spinner mientras carga el perfil y hace el routing.
      if (mounted) setState(() => _isLoading = false);

      if (response.user != null && mounted) {
        final userId = response.user!.id;
        
        // 1. Obtener el perfil del usuario
        final profile = await SupabaseService.supabase
            .from('profiles')
            .select('*')
            .eq('user_id', userId)
            .single();

        // 2. Verificar estado de aprobación
        if (profile['estado'] == 'pendiente') {
          await SupabaseService.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tu perfil todavía está en revisión. Te avisaremos por email cuando sea habilitado.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // 3. Ruteo según rol y estado
        // (el SessionWrapper también enrutará automáticamente,
        //  pero mantenemos esto como fallback explícito)
        if (mounted) {
          if (profile['es_admin'] == true || _emailController.text.trim().toLowerCase() == 'admin@El Guia YA.com') {
            Navigator.pushReplacementNamed(context, '/admin/dashboard');
          } else if (profile['es_capitan'] == true) {
            Navigator.pushReplacementNamed(context, '/portal/capitan');
          } else {
            Navigator.pushReplacementNamed(context, '/portal/pescador');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error al iniciar sesion';
        
        if (e.toString().contains('Invalid login credentials')) {
          errorMessage = 'Email o contrasena incorrectos';
        } else if (e.toString().contains('Email not confirmed')) {
          errorMessage = 'Por favor confirma tu email antes de iniciar sesion';
        } else if (e.toString().contains('User not found')) {
          errorMessage = 'Usuario no encontrado';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Garantía: si por algún error no se apagó antes, lo apagamos aquí
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'INGRESAR',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
      ),
    );
  }
}
