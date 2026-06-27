import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';

class CapitanIdentidadScreen extends StatefulWidget {
  const CapitanIdentidadScreen({super.key});

  @override
  State<CapitanIdentidadScreen> createState() => _CapitanIdentidadScreenState();
}

class _CapitanIdentidadScreenState extends State<CapitanIdentidadScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;

  // Controladores de Registro
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _dniController = TextEditingController();
  final _calleController = TextEditingController();
  final _alturaController = TextEditingController();
  final _localidadController = TextEditingController();
  final _provinciaController = TextEditingController();
  final _cbuController = TextEditingController();
  final _bancoController = TextEditingController();
  final _aseguradoraController = TextEditingController();
  final _tipoSeguroController = TextEditingController();
  String? _numeroCarnetAuto;
  String? _numeroPolizaAuto;
  final _passwordController = TextEditingController();
  final _confirmarPasswordController = TextEditingController();

  // Estados
  String? _avatarUrl;
  String? _seguroUrl;
  String? _carnetUrl;
  
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  // Nuevas fechas de vencimiento para auditoría y Centro de Cómputos
  DateTime? _vencimientoSeguro;
  DateTime? _vencimientoCarnet;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _dniController.dispose();
    _calleController.dispose();
    _alturaController.dispose();
    _localidadController.dispose();
    _provinciaController.dispose();
    _cbuController.dispose();
    _bancoController.dispose();
    _aseguradoraController.dispose();
    _tipoSeguroController.dispose();
    _passwordController.dispose();
    _confirmarPasswordController.dispose();
    super.dispose();
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
          
      // Obtener datos legacy de guias
      final guia = await Supabase.instance.client
          .from('guias')
          .select('*')
          .eq('id', user.id)
          .maybeSingle();

      final numeros = await SupabaseService.sincronizarDocumentacionContractualCapitan(user.id);

      if (mounted) {
        setState(() {
          _nombreController.text = perfil['nombre'] ?? '';
          _telefonoController.text = perfil['telefono'] ?? '';
          _emailController.text = perfil['email'] ?? '';
          _dniController.text = perfil['dni'] ?? '';
          _calleController.text = perfil['direccion_calle'] ?? '';
          _alturaController.text = perfil['direccion_numero'] ?? '';
          _localidadController.text = perfil['localidad'] ?? '';
          _provinciaController.text = perfil['provincia'] ?? '';
          
          if (guia != null) {
             _cbuController.text = guia['cbu'] ?? '';
             _bancoController.text = guia['banco_nombre'] ?? '';
          }
          
          _avatarUrl = perfil['avatar_url'];
          _seguroUrl = perfil['seguro_url'];
          _carnetUrl = perfil['carnet_url'];
          _numeroCarnetAuto = numeros['numero_carnet'] ??
              SupabaseService.resolverNumerosDocumentacionCapitan(
                profile: Map<String, dynamic>.from(perfil),
                guia: guia != null ? Map<String, dynamic>.from(guia) : null,
              )['numero_carnet'];
          _numeroPolizaAuto = numeros['numero_poliza'] ??
              SupabaseService.resolverNumerosDocumentacionCapitan(
                profile: Map<String, dynamic>.from(perfil),
                guia: guia != null ? Map<String, dynamic>.from(guia) : null,
              )['numero_poliza'];
          _aseguradoraController.text = perfil['aseguradora']?.toString() ?? '';
          _tipoSeguroController.text = perfil['tipo_seguro']?.toString() ?? '';
          
          // Cargar fechas de vencimiento de forma segura
          if (perfil['vencimiento_seguro'] != null) {
            _vencimientoSeguro = DateTime.parse(perfil['vencimiento_seguro']);
          }
          if (perfil['vencimiento_carnet'] != null) {
            _vencimientoCarnet = DateTime.parse(perfil['vencimiento_carnet']);
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar perfil capitan: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _seleccionarFechaSeguro(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _vencimientoSeguro ?? DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.black,
              surface: Color(0xFF001F3F),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _vencimientoSeguro) {
      setState(() {
        _vencimientoSeguro = picked;
      });
    }
  }

  Future<void> _seleccionarFechaCarnet(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _vencimientoCarnet ?? DateTime.now().add(const Duration(days: 180)),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              onPrimary: Colors.black,
              surface: Color(0xFF001F3F),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _vencimientoCarnet) {
      setState(() {
        _vencimientoCarnet = picked;
      });
    }
  }

  Future<void> _cambiarDocumento(String tipo) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery, 
      imageQuality: 60,
      maxWidth: 1600,
      maxHeight: 1600,
    );
    
    if (image == null) return;
    
    setState(() => _isSaving = true);
    
    try {
      final userId = SupabaseService.currentUserId;
      if (userId == null) return;
      
      final url = await StorageService.uploadAdminDocument(
        file: image,
        folder: userId,
        prefix: tipo,
      );
      
      if (url != null) {
        // Actualizar en DB
        await Supabase.instance.client.from('profiles').update({
          '${tipo}_url': url,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('user_id', userId);

        if (tipo == 'avatar') {
          await Supabase.instance.client.from('guias').update({
            'avatar_url': url,
          }).eq('id', userId);
        }
        
        setState(() {
          if (tipo == 'avatar') _avatarUrl = url;
          if (tipo == 'seguro') _seguroUrl = url;
          if (tipo == 'carnet') _carnetUrl = url;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Documento actualizado exitosamente'), backgroundColor: Colors.green),
          );
        }
      }
    } catch(e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir documento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

      // 3. Actualizar datos en profiles (con tolerancia si faltan las columnas en Supabase)
      final data = {
        'nombre': _nombreController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'email': newEmail,
        'direccion_calle': _calleController.text.trim(),
        'direccion_numero': _alturaController.text.trim(),
        'localidad': _localidadController.text.trim(),
        'provincia': _provinciaController.text.trim(),
        'vencimiento_seguro': _vencimientoSeguro?.toIso8601String(),
        'vencimiento_carnet': _vencimientoCarnet?.toIso8601String(),
        'aseguradora': _aseguradoraController.text.trim(),
        'tipo_seguro': _tipoSeguroController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      try {
        await Supabase.instance.client.from('profiles').update(data).eq('user_id', user.id);
        await SupabaseService.sincronizarDocumentacionContractualCapitan(user.id);
      } catch (dbError) {
        // Fallback si las nuevas columnas no se crearon en Supabase todavía
        debugPrint('⚠️ Columnas contractuales/vencimiento faltantes en Supabase, reintentando sin ellas: $dbError');
        data.remove('vencimiento_seguro');
        data.remove('vencimiento_carnet');
        data.remove('aseguradora');
        data.remove('tipo_seguro');
        await Supabase.instance.client.from('profiles').update(data).eq('user_id', user.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Se guardó el perfil. Carnet/seguro y fechas de vencimiento requieren migración SQL en Supabase.'),
              backgroundColor: Colors.amber,
              duration: Duration(seconds: 6),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // 4. Actualizar CBU y Banco en guias
      await Supabase.instance.client.from('guias').update({
        'cbu': _cbuController.text.trim(),
        'banco_nombre': _bancoController.text.trim(),
        'email': newEmail,
      }).eq('id', user.id);

      if (mounted) {
        String successMsg = '¡Tu Identidad ha sido actualizada!';
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
      backgroundColor: const Color(0xFF001F3F),
      appBar: AppBar(
        title: const Text('MI IDENTIDAD CAPITÁN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.5)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.orange))
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
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                              child: _avatarUrl == null ? const Icon(Icons.sailing, color: Colors.white, size: 50) : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.orange,
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 18, color: Colors.black),
                                  onPressed: () => _cambiarDocumento('avatar'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      _buildSectionTitle('DATOS PERSONALES'),
                      const SizedBox(height: 16),
                      _buildTextField('Nombre y Apellido', _nombreController, Icons.person),
                      const SizedBox(height: 12),
                      _buildTextField('DNI (No editable)', _dniController, Icons.badge, enabled: false),
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
                      _buildSectionTitle('DOMICILIO DECLARADO'),
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
                      _buildSectionTitle('DATOS BANCARIOS'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(flex: 3, child: _buildTextField('CBU / CVU / Alias', _cbuController, Icons.account_balance)),
                          const SizedBox(width: 12),
                          Expanded(flex: 2, child: _buildTextField('Banco / Entidad', _bancoController, Icons.account_balance_outlined)),
                        ],
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
                      _buildSectionTitle('DOCUMENTACIÓN Y CONTROL DE VENCIMIENTOS'),
                      const SizedBox(height: 8),
                      Text(
                        'N° de carnet y póliza se sincronizan solos desde tu habilitación náutica registrada. '
                        'Solo completá aseguradora y tipo de cobertura si aún no están cargados.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      _buildReadOnlyDocField(
                        'N° Carnet de Timonel',
                        _numeroCarnetAuto,
                        Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildReadOnlyDocField(
                        'N° de póliza de seguro',
                        _numeroPolizaAuto,
                        Icons.description_outlined,
                      ),
                      const SizedBox(height: 12),
                      _buildTextField('Aseguradora', _aseguradoraController, Icons.shield_outlined),
                      const SizedBox(height: 12),
                      _buildTextField(
                        'Tipo / cobertura de póliza',
                        _tipoSeguroController,
                        Icons.policy_outlined,
                      ),
                      const SizedBox(height: 20),
                      
                      // Seguro de embarcación y su vencimiento
                      _buildDocStatusCard('Seguro de Embarcación', _seguroUrl, () => _cambiarDocumento('seguro')),
                      const SizedBox(height: 8),
                      _buildDatePickerField(
                        'Fecha de Vencimiento de Seguro',
                        _vencimientoSeguro,
                        () => _seleccionarFechaSeguro(context),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Carnet de Timonel y su vencimiento
                      _buildDocStatusCard('Carnet de Timonel', _carnetUrl, () => _cambiarDocumento('carnet')),
                      const SizedBox(height: 8),
                      _buildDatePickerField(
                        'Fecha de Vencimiento de Registro de Timonel',
                        _vencimientoCarnet,
                        () => _seleccionarFechaCarnet(context),
                      ),

                      const SizedBox(height: 40),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSaving ? null : _guardar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                          ),
                          child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.black)
                            : const Text('GUARDAR IDENTIDAD', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
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
      style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
    );
  }

  Widget _buildReadOnlyDocField(String label, String? value, IconData icon) {
    final display = (value != null && value.trim().isNotEmpty) ? value.trim() : 'Pendiente — registrá el número al inscribirte o contactá soporte';
    final ok = value != null && value.trim().isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: ok ? Colors.green.withValues(alpha: 0.35) : Colors.orange.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: ok ? Colors.greenAccent : Colors.orange, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  display,
                  style: TextStyle(
                    color: ok ? Colors.white : Colors.orange.shade200,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.sync_lock_rounded, color: Colors.white.withValues(alpha: 0.35), size: 18),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData? icon, {bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(enabled ? 0.05 : 0.02),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(enabled ? 0.1 : 0.05)),
      ),
      child: TextFormField(
        controller: controller,
        enabled: enabled,
        style: TextStyle(color: enabled ? Colors.white : Colors.white38, fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: enabled ? Colors.white54 : Colors.white24, fontSize: 12),
          prefixIcon: icon != null ? Icon(icon, color: enabled ? Colors.orange : Colors.white24, size: 18) : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Widget _buildDatePickerField(String label, DateTime? date, VoidCallback onTap) {
    final formattedDate = date != null 
        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
        : 'Seleccionar Fecha 📅';
        
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: Colors.white38, fontSize: 10)),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: date != null ? Colors.white : Colors.orangeAccent,
                    fontSize: 13,
                    fontWeight: date != null ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
            Icon(Icons.calendar_today_rounded, color: date != null ? Colors.white54 : Colors.orange, size: 18),
          ],
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
          prefixIcon: const Icon(Icons.lock, color: Colors.orange, size: 18),
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

  Widget _buildDocStatusCard(String title, String? url, VoidCallback onUpdate) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(
            url != null ? Icons.verified : Icons.error_outline,
            color: url != null ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                Text(
                  url != null ? 'Documento al día' : 'Requiere actualización',
                  style: TextStyle(color: url != null ? Colors.white70 : Colors.orange, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: _isSaving ? null : onUpdate,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('RENOVAR', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
