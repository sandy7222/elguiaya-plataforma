

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/branding_service.dart';
import '../services/supabase_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _brandingService = BrandingService();
  StreamSubscription? _configSubscription;

  // Controladores y Estados
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  String _selectedRole = 'Pescador';

  // Variables de Branding dinamico
  String? _backgroundUrl;
  double _opacity = 0.5;
  double _brightness = 1.0;
  Color _primaryColor = const Color(0xFF0D47A1);
  String _welcomeText = 'Crea tu cuenta en El Guia YA';

  @override
  void initState() {
    super.initState();
    // Suscripcion a los cambios de configuracion en tiempo real
    _configSubscription = BrandingService.getLoginConfigStream().listen((config) {
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
          _brightness = config.brightness;
          _primaryColor = _parseColor('#0D47A1');
          _welcomeText = 'Crea tu cuenta en El Guia YA';
        });
      }
    });
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xff')));
    } catch (e) {
      return const Color(0xFF0D47A1);
    }
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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
          // Capa de opacidad (Overlay)
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
              const Icon(Icons.anchor, size: 80, color: Colors.white),
              const SizedBox(height: 20),
              Text(
                _welcomeText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField(
                controller: _nameController,
                hint: 'Nombre Completo',
                icon: Icons.person_outline,
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
              _buildRoleSelector(),
              const SizedBox(height: 30),
              _buildRegisterButton(),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                child: const Text(
                  '¿Ya tienes cuenta? Ingresa aqui',
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

  Widget _buildRoleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedRole,
          dropdownColor: Colors.black87,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          items: const [
            DropdownMenuItem(value: 'Pescador', child: Text('Pescador')),
            DropdownMenuItem(value: 'Guia Nautico', child: Text('Guia Nautico')),
          ],
          onChanged: (value) {
            setState(() {
              _selectedRole = value!;
            });
          },
        ),
      ),
    );
  }

  Future<void> _handleRegister() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty) {
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

    if (_passwordController.text.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La contrasena debe tener al menos 6 caracteres'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await SupabaseService.supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {
          'nombre_completo': _nameController.text.trim(),
          'rol': _selectedRole,
        },
      );

      if (response.user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Cuenta creada exitosamente! ${_selectedRole == 'Pescador' ? 'Revisa tu correo para confirmar la cuenta.' : 'Ya puedes iniciar sesion.'}'
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Si es pescador, esperar confirmacion de email
        if (_selectedRole == 'Pescador') {
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        } else {
          // Si es guia, redirigir directamente al home
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error al crear cuenta';
        
        if (e.toString().contains('User already registered')) {
          errorMessage = 'El email ya esta registrado';
        } else if (e.toString().contains('weak_password')) {
          errorMessage = 'La contrasena es muy debil';
        } else if (e.toString().contains('invalid_email')) {
          errorMessage = 'El email no es valido';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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

  Widget _buildRegisterButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleRegister,
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _isLoading 
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'REGISTRARSE',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
      ),
    );
  }
}
