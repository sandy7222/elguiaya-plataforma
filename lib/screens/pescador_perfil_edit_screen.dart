
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/voice_service.dart';
import '../widgets/guia_overlay.dart';

class PescadorPerfilEditScreen extends StatefulWidget {
  const PescadorPerfilEditScreen({super.key});

  @override
  State<PescadorPerfilEditScreen> createState() => _PescadorPerfilEditScreenState();
}

class _PescadorPerfilEditScreenState extends State<PescadorPerfilEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controladores de Registro (Precargados)
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _calleController = TextEditingController();
  final _alturaController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  
  // Controladores de Identidad Pescador
  final _bioController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();
  
  // Estados
  bool _traeEquipo = true;
  String? _avatarUrl;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _guiaActivo = false;
  bool _guiaSilenciado = false;
  bool _guiaMicActivo = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
    GuiaOverlayController.activo.addListener(_onGuiaPrefsChanged);
    GuiaOverlayController.silenciado.addListener(_onGuiaPrefsChanged);
    GuiaOverlayController.micActivo.addListener(_onGuiaPrefsChanged);
  }

  @override
  void dispose() {
    GuiaOverlayController.activo.removeListener(_onGuiaPrefsChanged);
    GuiaOverlayController.silenciado.removeListener(_onGuiaPrefsChanged);
    GuiaOverlayController.micActivo.removeListener(_onGuiaPrefsChanged);
    super.dispose();
  }

  void _onGuiaPrefsChanged() {
    if (!mounted) return;
    setState(() {
      _guiaActivo = GuiaOverlayController.activo.value;
      _guiaSilenciado = GuiaOverlayController.silenciado.value;
      _guiaMicActivo = GuiaOverlayController.micActivo.value;
    });
  }

  Future<void> _cargarDatos() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final perfil = await Supabase.instance.client
          .from('profiles')
          .select('*')
          .eq('user_id', user.id)
          .single();

      // Cargar preferencia del Guía ANTES del setState (await no puede ir dentro)
      final prefs = await SharedPreferences.getInstance();
      final guiaActivo = prefs.getBool('guia_activo_${user.id}') ?? prefs.getBool('guia_activo') ?? false;
      final guiaSilenciado = prefs.getBool('guia_silenciado_${user.id}') ?? prefs.getBool('guia_silenciado') ?? false;
      final guiaMicActivo = prefs.getBool('guia_mic_activo_${user.id}') ?? prefs.getBool('guia_mic_activo') ?? true;

      if (mounted) {
        setState(() {
          // Datos de Registro
          _nombreController.text = perfil['nombre'] ?? '';
          _telefonoController.text = perfil['telefono'] ?? '';
          _emailController.text = perfil['email'] ?? '';
          _calleController.text = perfil['direccion_calle'] ?? '';
          _alturaController.text = perfil['direccion_numero'] ?? '';
          _localidadController.text = perfil['localidad'] ?? '';
          _provinciaController.text = perfil['provincia'] ?? '';
          _avatarUrl = perfil['avatar_url'];

          // Datos de Pescador
          final bioRaw = perfil['bio_pescador'] ?? '';
          if (bioRaw.toString().startsWith('{')) {
            try {
              final jsonBio = jsonDecode(bioRaw.toString());
              _bioController.text = jsonBio['bio'] ?? '';
            } catch (_) {
              _bioController.text = bioRaw.toString();
            }
          } else {
            _bioController.text = bioRaw.toString();
          }
          _cantidadController.text = (perfil['cantidad_pescadores_frecuentes'] ?? 1).toString();
          _traeEquipo = perfil['trae_equipo_propio'] ?? true;

          // Preferencia del Guía
          _guiaActivo = guiaActivo;
          _guiaSilenciado = guiaSilenciado;
          _guiaMicActivo = guiaMicActivo;

          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error al cargar perfil pescador: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Validar y actualizar contraseña si se ingresó algo
      final newPass = _passwordController.text.trim();
      final confirmPass = _confirmarPasswordController.text.trim();
      
      if (newPass.isNotEmpty) {
        if (newPass.length < 6) {
          throw Exception('La contraseña debe tener al menos 6 caracteres.');
        }
        if (newPass != confirmPass) {
          throw Exception('Las contraseñas ingresadas no coinciden.');
        }
        
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPass),
        );
      }

      // 2. Validar y actualizar Email en Autenticación de Supabase si cambió
      final newEmail = _emailController.text.trim();
      final currentEmail = user.email;
      bool emailChanged = false;
      
      if (newEmail.isNotEmpty && newEmail != currentEmail) {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(email: newEmail),
        );
        emailChanged = true;
      }

      // Conservar guia_memoria si ya existía en bio_pescador
      dynamic bioPescadorValue = _bioController.text.trim();
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
            bioPescadorValue = jsonEncode({
              'bio': _bioController.text.trim(),
              'guia_memoria': jsonBio['guia_memoria'],
            });
          }
        }
      } catch (_) {}

      // 3. Actualizar datos en la tabla profiles (Master)
      final data = {
        'nombre': _nombreController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'email': newEmail,
        'direccion_calle': _calleController.text.trim(),
        'direccion_numero': _alturaController.text.trim(),
        'localidad': _localidadController.text.trim(),
        'provincia': _provinciaController.text.trim(),
        'bio_pescador': bioPescadorValue,
        'cantidad_pescadores_frecuentes': int.tryParse(_cantidadController.text) ?? 1,
        'trae_equipo_propio': _traeEquipo,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('profiles').update(data).eq('user_id', user.id);

      if (mounted) {
        String successMsg = '¡Tu Identidad de Pescador ha sido actualizada!';
        if (emailChanged) {
          successMsg += ' Se envió un enlace de confirmación a tu nuevo email.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg), 
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        // Limpiar campos de contraseña para seguridad
        _passwordController.clear();
        _confirmarPasswordController.clear();
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: ${e.toString().replaceAll('Exception: ', '')}'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF001529),
      appBar: AppBar(
        title: const Text('MI IDENTIDAD PESCADOR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
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
                      // Header con Avatar
                      Center(
                        child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 55,
                            backgroundColor: const Color(0xFF00E676).withOpacity(0.2),
                            backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                            child: _avatarUrl == null ? const Icon(Icons.person, color: Colors.white, size: 50) : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF00E676),
                              child: IconButton(
                                icon: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                                onPressed: () { /* Proximamente: Cambiar foto */ },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Toggle Gu-IA ──────────────────────────────────────
                    GestureDetector(
                      onTap: () async {
                        final newVal = !_guiaActivo;
                        setState(() => _guiaActivo = newVal);
                        await GuiaOverlayController.setActivo(newVal);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                newVal
                                    ? '🤖 ¡El Guía está listo! Aparecerá flotando en tu app.'
                                    : '🔕 El Guía fue desactivado.',
                              ),
                              backgroundColor: newVal ? const Color(0xFF00E676) : Colors.grey[800],
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: _guiaActivo
                                ? const Color(0xFF00E676).withOpacity(0.12)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _guiaActivo
                                  ? const Color(0xFF00E676).withOpacity(0.5)
                                  : Colors.white.withOpacity(0.15),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icono del robot
                              Image.asset(
                                'assets/images/guia_icon.png',
                                width: 32,
                                height: 32,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.smart_toy_rounded,
                                  color: _guiaActivo ? const Color(0xFF00E676) : Colors.white54,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'ACTIVA TU ASISTENTE',
                                    style: TextStyle(
                                      color: Color(0xFF00E676),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _guiaActivo
                                          ? const Color(0xFF00E676)
                                          : Colors.white.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _guiaActivo ? 'ACTIVADO' : 'DESACTIVADO',
                                      style: TextStyle(
                                        color: _guiaActivo ? Colors.black : Colors.white54,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Switch(
                                value: _guiaActivo,
                                onChanged: (val) async {
                                  setState(() => _guiaActivo = val);
                                  await GuiaOverlayController.setActivo(val);
                                },
                                activeColor: const Color(0xFF00E676),
                                activeTrackColor: const Color(0xFF00E676).withOpacity(0.3),
                                inactiveThumbColor: Colors.white38,
                                inactiveTrackColor: Colors.white12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_guiaActivo) ...[
                      const SizedBox(height: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'AJUSTES DE VOZ DEL GUÍA',
                              style: TextStyle(
                                color: Color(0xFF00E676),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Switch 1: Altavoz (guia_silenciado)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _guiaSilenciado ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                                      color: _guiaSilenciado ? Colors.white38 : const Color(0xFF00E676),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Altavoz del Asistente',
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Permite que el Guía hable en voz alta',
                                          style: TextStyle(color: Colors.white38, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: !_guiaSilenciado,
                                  onChanged: (val) async {
                                    await GuiaOverlayController.setSilenciado(!val);
                                  },
                                  activeColor: const Color(0xFF00E676),
                                  activeTrackColor: const Color(0xFF00E676).withOpacity(0.3),
                                  inactiveThumbColor: Colors.white38,
                                  inactiveTrackColor: Colors.white12,
                                ),
                              ],
                            ),
                            const Divider(color: Colors.white10, height: 20),
                            // Switch 2: Micrófono / Comandos de voz (guia_mic_activo)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _guiaMicActivo ? Icons.mic_rounded : Icons.mic_off_rounded,
                                      color: _guiaMicActivo ? const Color(0xFF00E676) : Colors.white38,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    const Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Comandos por Voz',
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          'Habilita el micrófono para navegar por voz',
                                          style: TextStyle(color: Colors.white38, fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Switch(
                                  value: _guiaMicActivo,
                                  onChanged: (val) async {
                                    if (val) {
                                      // Pedir permiso de micrófono en contexto
                                      // (el usuario acaba de activar 'Comandos por Voz')
                                      final status = await Permission.microphone.request();
                                      if (!status.isGranted) {
                                        // Si deniega, no activamos el mic
                                        if (mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Se necesita el micrófono para los comandos de voz. Activalo en los ajustes del celular.'),
                                              backgroundColor: Colors.redAccent,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                        return;
                                      }
                                      // Inicializar el STT ahora que tenemos permiso
                                      await VoiceService().initStt();
                                    }
                                    await GuiaOverlayController.setMicActivo(val);
                                  },
                                  activeColor: const Color(0xFF00E676),
                                  activeTrackColor: const Color(0xFF00E676).withOpacity(0.3),
                                  inactiveThumbColor: Colors.white38,
                                  inactiveTrackColor: Colors.white12,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                      const SizedBox(height: 32),
                      
                      _buildSectionTitle('DATOS PERSONALES'),
                      const SizedBox(height: 16),
                      _buildTextField('Nombre Completo', _nombreController, Icons.person),
                      const SizedBox(height: 12),
                      _buildTextField('Teléfono / WhatsApp', _telefonoController, Icons.phone),
                      const SizedBox(height: 12),
                      _buildTextField('Email', _emailController, Icons.email),
                      const SizedBox(height: 4),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text(
                          '* Si cambiás el email, recibirás un enlace de confirmación en tu nueva casilla.',
                          style: TextStyle(color: Colors.white30, fontSize: 10, fontStyle: FontStyle.italic),
                        ),
                      ),

                      const SizedBox(height: 32),
                      _buildSectionTitle('SEGURIDAD Y ACCESO'),
                      const SizedBox(height: 16),
                      _buildPasswordField('Nueva Contraseña (Opcional)', _passwordController, _obscurePassword, () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      }),
                      const SizedBox(height: 12),
                      _buildPasswordField('Confirmar Nueva Contraseña', _confirmarPasswordController, _obscureConfirmPassword, () {
                        setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                      }),

                      const SizedBox(height: 32),
                      _buildSectionTitle('DOMICILIO'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(flex: 3, child: _buildTextField('Calle', _calleController, Icons.location_on)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildTextField('N°', _alturaController, null)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Localidad', _localidadController, Icons.location_city),
                      const SizedBox(height: 12),
                      _buildTextField('Provincia', _provinciaController, Icons.explore),

                      const SizedBox(height: 32),
                      _buildSectionTitle('BIO Y PREFERENCIAS'),
                      const SizedBox(height: 8),
                      const Text(
                        'Esta información la verá el Capitán al recibir tu solicitud.',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      const SizedBox(height: 16),
                      _buildBioField(),
                      const SizedBox(height: 16),
                      _buildNumberField('¿Cuántas personas suelen acompañarte?', _cantidadController, Icons.group),
                      const SizedBox(height: 16),
                      _buildSwitchField('¿Traés tu propio equipo de pesca?', _traeEquipo, (val) {
                        setState(() => _traeEquipo = val);
                      }, Icons.phishing),

                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _guardar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00E676),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                          ),
                          child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text('GUARDAR MI IDENTIDAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ),
                      const SizedBox(height: 30),
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
      style: const TextStyle(color: Color(0xFF00E676), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
    );
  }

  Widget _buildBioField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: _bioController,
        maxLines: 4,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Ej: Soy un apasionado del Pejerrey y siempre voy con mis amigos de la peña...',
          hintStyle: TextStyle(color: Colors.white24),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData? icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF00E676), size: 18) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscureText, VoidCallback onToggleVisibility) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          prefixIcon: const Icon(Icons.lock, color: Color(0xFF00E676), size: 18),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility : Icons.visibility_off,
              color: Colors.white54,
              size: 18,
            ),
            onPressed: onToggleVisibility,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildLockedField(String label, TextEditingController controller, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextFormField(
        controller: controller,
        enabled: false,
        style: const TextStyle(color: Colors.white38, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
          prefixIcon: Icon(icon, color: Colors.white24, size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildNumberField(String label, TextEditingController controller, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
          prefixIcon: Icon(icon, color: const Color(0xFF00E676), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildSwitchField(String label, bool value, Function(bool) onChanged, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFF00E676), size: 20),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: const Color(0xFF00E676),
      ),
    );
  }
}

