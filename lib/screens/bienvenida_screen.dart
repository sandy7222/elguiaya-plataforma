

import 'dart:async';

import 'package:flutter/material.dart';

import '../services/branding_service.dart';
import '../utils/cya_styles.dart';
import 'admin_dashboard_screen.dart';
import 'portal_capitan_screen.dart';
import 'portal_pescador_screen.dart';
import 'registro_pescador_screen.dart';
import 'registro_screen.dart';

class BienvenidaScreen extends StatefulWidget {
  const BienvenidaScreen({super.key});

  @override
  State<BienvenidaScreen> createState() => _BienvenidaScreenState();
}

class _BienvenidaScreenState extends State<BienvenidaScreen> {
  String? _backgroundUrl;
  double _opacity = 0.2;
  double _brightness = 1.0;
  bool _isLoading = true;
  bool _esLogin = true; // Switch: true = Login, false = Inscripcion
  String _rolSeleccionado = 'pescador'; // 'pescador' o 'capitan'
  StreamSubscription? _configSubscription;

  // Controladores para formulario
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isProcessing = false;
  
  // Textos legales por defecto
  String _textoTerminos = 'Terminos y Condiciones de El Guia YA\n\n'
      '1. Aceptacion de los Terminos\n'
      'Al usar El Guia YA, aceptas estos terminos y condiciones.\n\n'
      '2. Descripcion del Servicio\n'
      'El Guia YA es una plataforma que conecta pescadores con capitanes '
      'para experiencias de pesca unicas.\n\n'
      '3. Responsabilidades del Usuario\n'
      'Los usuarios deben proporcionar informacion veraz y utilizar '
      'la plataforma de manera responsable.\n\n'
      '4. Pagos y Reembolsos\n'
      'Los pagos se procesan a traves de plataformas seguras. '
      'Los reembolsos estan sujetos a las politicas de cada capitan.\n\n'
      '5. Privacidad\n'
      'Respetamos tu privacidad y protegemos tus datos personales '
      'de acuerdo con nuestra politica de privacidad.\n\n'
      '6. Propiedad Intelectual\n'
      'Todo el contenido de El Guia YA esta protegido por derechos '
      'de propiedad intelectual.\n\n'
      '7. Modificacion del Servicio\n'
      'Nos reservamos el derecho de modificar o suspender el servicio '
      'en cualquier momento.\n\n'
      '8. Limitacion de Responsabilidad\n'
      'El Guia YA no es responsable por danos directos o indirectos '
      'derivados del uso del servicio.\n\n'
      '9. Ley Aplicable\n'
      'Estos terminos se rigen por las leyes de Argentina.\n\n'
      '10. Contacto\n'
      'Para cualquier duda, contacta a: legal@El Guia YA.com';

  // Colores El Guia YA
  static const Color _fondoPorDefecto = Color(0xFF0D47A1);
  static const Color _blancoPuro = Color(0xFFFFFFFF);
  static const Color _azulVibrante = Color(0xFF0066FF);
  static const Color _verdeBrillante = Color(0xFF00FF00);
  static const Color _naranjaIntenso = Color(0xFFFF6600);
  static const Color _grisMedio = Color(0xFF666666);

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionBranding();
    _escucharConfiguracionEnTiempoReal();
  }

  @override
  void dispose() {
    _configSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _cargarConfiguracionBranding() async {
    try {
      final config = await BrandingService.getLoginConfig();
      final textosLegales = await BrandingService.getTextosLegales();
      
      if (mounted) {
        setState(() {
          _backgroundUrl = config.backgroundUrl;
          _opacity = config.opacity;
          _brightness = config.brightness;
          
          if (textosLegales['texto_terminos']?.isNotEmpty == true) {
            _textoTerminos = textosLegales['texto_terminos']!;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
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

  Widget _buildBackground() {
    if (_backgroundUrl != null && _backgroundUrl!.isNotEmpty) {
      return Stack(
        children: [
          // Imagen de fondo con filtro de brillo
          ColorFiltered(
            colorFilter: ColorFilter.matrix(
              <double>[
                _brightness, 0, 0, 0, 0, // Red
                0, _brightness, 0, 0, 0, // Green
                0, 0, _brightness, 0, 0, // Blue
                0, 0, 0, 1, 0, // Alpha
              ],
            ),
            child: Image.network(
              _backgroundUrl!,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => _buildFallbackGradient(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return _buildFallbackGradient();
              },
            ),
          ),
          
          // Overlay con gradiente nautico (en lugar de capa negra solida para evitar el gris)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF001F3F).withOpacity(_opacity),
                  Colors.transparent,
                  const Color(0xFF001F3F).withOpacity(_opacity * 1.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
        ],
      );
    } else {
      return _buildFallbackGradient();
    }
  }

  Widget _buildFallbackGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF003366), // Azul Profundo
            Color(0xFF006699), // Azul Maritimo
            Color(0xFF0099CC), // Cyan Vibrante
          ],
        ),
      ),
    );
  }

  Widget _buildIdentityButtons() {
    final bool isPescadorSelected = _rolSeleccionado == 'pescador';
    final bool isCapitanSelected = _rolSeleccionado == 'capitan';

    return Column(
      children: [
        // Boton El Pescador
        Container(
          width: double.infinity,
          height: 60,
          decoration: isPescadorSelected
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CYAStyles.accentBlue, Color(0xFF00B0FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: CYAStyles.radiusMedium,
                  boxShadow: [
                    BoxShadow(
                      color: CYAStyles.accentBlue.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : CYAStyles.glassCard(opacity: 0.08),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _rolSeleccionado = 'pescador';
              });
            },
            icon: Icon(
              Icons.sailing,
              color: Colors.white,
              size: 24,
            ),
            label: const Text(
              'EL PESCADOR',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: CYAStyles.radiusMedium,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Boton El Capitan
        Container(
          width: double.infinity,
          height: 60,
          decoration: isCapitanSelected
              ? BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CYAStyles.accentOrange, Color(0xFFFF9100)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: CYAStyles.radiusMedium,
                  boxShadow: [
                    BoxShadow(
                      color: CYAStyles.accentOrange.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                )
              : CYAStyles.glassCard(opacity: 0.08),
          child: ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _rolSeleccionado = 'capitan';
              });
            },
            icon: Icon(
              Icons.anchor,
              color: Colors.white,
              size: 24,
            ),
            label: const Text(
              'EL CAPITAN',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: CYAStyles.radiusMedium,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFlowSwitches() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          // Opcion Login
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _esLogin = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _esLogin 
                      ? _azulVibrante.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.login,
                      color: _esLogin ? _azulVibrante : _blancoPuro.withOpacity(0.7),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Login',
                      style: TextStyle(
                        color: _esLogin ? _azulVibrante : _blancoPuro.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: _esLogin ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Divider vertical
          Container(
            height: 40,
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          
          // Opcion Inscripcion
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _esLogin = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_esLogin 
                      ? _verdeBrillante.withOpacity(0.3)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.person_add,
                      color: !_esLogin ? _verdeBrillante : _blancoPuro.withOpacity(0.7),
                      size: 24,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inscripcion',
                      style: TextStyle(
                        color: !_esLogin ? _verdeBrillante : _blancoPuro.withOpacity(0.7),
                        fontSize: 14,
                        fontWeight: !_esLogin ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm() {
    final bool isPescador = _rolSeleccionado == 'pescador';
    final Color accentColor = isPescador ? CYAStyles.accentBlue : CYAStyles.accentOrange;

    return Column(
      children: [
        // Campo de email
        TextField(
          controller: _emailController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: CYAStyles.inputDecoration(
            label: 'Email',
            icon: Icons.email_outlined,
            accentColor: accentColor,
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Campo de contrasena
        TextField(
          controller: _passwordController,
          obscureText: true,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: CYAStyles.inputDecoration(
            label: 'Contrasena',
            icon: Icons.lock_outline,
            accentColor: accentColor,
          ),
        ),
        
        const SizedBox(height: 28),
        
        // Boton de acceso
        CYAStyles.primaryButton(
          label: _esLogin ? 'INICIAR SESION' : 'CREAR CUENTA',
          onPressed: _procesarAcceso,
          isLoading: _isProcessing,
          gradientColors: !_esLogin
              ? const [CYAStyles.accentGreen, Color(0xFF69F0AE)]
              : isPescador
                  ? const [CYAStyles.accentBlue, Color(0xFF00B0FF)]
                  : const [CYAStyles.accentOrange, Color(0xFFFF9100)],
        ),
      ],
    );
  }

  Future<void> _procesarAcceso() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor completa todos los campos'),
          backgroundColor: _naranjaIntenso,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Simular autenticacion (en produccion usar Supabase Auth)
      await Future.delayed(const Duration(seconds: 2));

      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text;

      // Verificar si es administrador
      if (_esAdministrador(email, password)) {
        // Acceso admin - ignora rol seleccionado
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(),
            ),
          );
        }
        return;
      }

      if (_esLogin) {
        // Login - redirigir al portal correspondiente
        if (_rolSeleccionado == 'pescador') {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const PortalPescadorScreen(),
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => const PortalCapitanScreen(),
              ),
            );
          }
        }
      } else {
        // Inscripcion - redirigir al formulario de registro
        if (_rolSeleccionado == 'pescador') {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RegistroPescadorScreen(),
              ),
            );
          }
        } else {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const RegistroScreen(),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  bool _esAdministrador(String email, String password) {
    // En produccion, verificar contra base de datos
    // Por ahora, admin@capitanya.com / admin123
    return email == 'admin@capitanya.com' && password == 'admin123';
  }

  Widget _buildFooter() {
    return Positioned(
      bottom: 20,
      left: 0,
      right: 0,
      child: Center(
        child: GestureDetector(
          onTap: () {
            // Mostrar terminos y condiciones
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text('Terminos y Condiciones'),
                content: SingleChildScrollView(
                  child: Text(_textoTerminos),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cerrar'),
                  ),
                ],
              ),
            );
          },
          child: Text(
            'Terminos y Condiciones',
            style: TextStyle(
              color: _blancoPuro.withOpacity(0.5),
              fontSize: 10,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo con configuracion de branding
          _buildBackground(),
          
          // Contenido principal
          if (!_isLoading)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Header con logo
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.anchor,
                            size: 48,
                            color: _blancoPuro,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'EL GUIA YA',
                            style: TextStyle(
                              color: _blancoPuro,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            'Tu mejor amigo de pesca en Argentina',
                            style: TextStyle(
                              color: _blancoPuro.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Switches de flujo
                    _buildFlowSwitches(),
                    
                    const SizedBox(height: 32),
                    
                    // Botones de identidad
                    _buildIdentityButtons(),
                    
                    const SizedBox(height: 32),
                    
                    // Formulario de login/inscripcion
                    _buildLoginForm(),
                    
                    const Spacer(),
                    
                    // Espacio para el footer
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            )
          else
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(_blancoPuro),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando configuracion...',
                    style: TextStyle(
                      color: _blancoPuro.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          
          // Footer con terminos y condiciones
          _buildFooter(),
        ],
      ),
    );
  }
}
