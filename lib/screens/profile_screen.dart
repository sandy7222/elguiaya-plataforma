import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/safe_button.dart';

import '../models/user_profile.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with AutomaticKeepAliveClientMixin {
  final _formKey = GlobalKey<FormState>();
  
  final _dniController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _localidadController = TextEditingController();
  
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isSaving = false;
  dynamic _fotoDni;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  @override
  void dispose() {
    _dniController.dispose();
    _telefonoController.dispose();
    _calleController.dispose();
    _numeroController.dispose();
    _localidadController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfil() async {
    try {
      setState(() => _isLoading = true);
      
      // Usar user_id de prueba (sin validaciones de Auth)
      final testUserId = '00000000-0000-0000-0000-000000000000';
      final profile = await SupabaseService.getOrCreateProfile(testUserId);
      
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
      
      // Cargar datos en los controllers
      _dniController.text = profile.dni ?? '';
      _telefonoController.text = profile.telefono ?? '';
      _calleController.text = profile.direccionCalle ?? '';
      _numeroController.text = profile.direccionNumero ?? '';
      _localidadController.text = profile.localidad ?? '';
        } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al cargar perfil: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _guardarPerfil() async {
    // Sin validaciones estrictas - permitir guardar cualquier dato
    setState(() => _isSaving = true);

    try {
      String fotoDniUrl = _profile?.fotoDniUrl ?? '';
      
      // Si hay una nueva foto, subirla
      if (_fotoDni != null) {
        final testUserId = '00000000-0000-0000-0000-000000000000';
        fotoDniUrl = await SupabaseService.uploadProfileDni(_fotoDni!, testUserId);
      }

      // Crear perfil actualizado
      final perfilActualizado = UserProfile(
        id: _profile?.id ?? 'temp_${DateTime.now().millisecondsSinceEpoch}',
        userId: _profile?.userId ?? '00000000-0000-0000-0000-000000000000',
        dni: _dniController.text.trim().isEmpty ? null : _dniController.text.trim(),
        telefono: _telefonoController.text.trim().isEmpty ? null : _telefonoController.text.trim(),
        direccionCalle: _calleController.text.trim().isEmpty ? null : _calleController.text.trim(),
        direccionNumero: _numeroController.text.trim().isEmpty ? null : _numeroController.text.trim(),
        localidad: _localidadController.text.trim().isEmpty ? null : _localidadController.text.trim(),
        fotoDniUrl: fotoDniUrl.isEmpty ? null : fotoDniUrl,
        createdAt: _profile?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Guardar en Supabase
      await SupabaseService.saveProfile(perfilActualizado);
      
      // Recargar perfil
      await _cargarPerfil();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Center(child: Text('Perfil guardado correctamente')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al guardar perfil: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _seleccionarFotoDni() async {
    try {
      final File? foto = await StorageService.pickDniImage();
      if (foto != null) {
        setState(() => _fotoDni = foto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al seleccionar foto: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _tomarFotoDni() async {
    try {
      final dynamic foto = await StorageService.captureDniImage();
      if (foto != null) {
        setState(() => _fotoDni = foto);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Center(child: Text('Error al tomar foto: $e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Mi Perfil',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: _cargarPerfil,
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con informacion del perfil
                    _buildProfileHeader(),
                    
                    const SizedBox(height: 24),
                    
                    // Foto DNI
                    _buildFotoDniSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Datos personales
                    _buildDatosPersonalesSection(),
                    
                    const SizedBox(height: 24),
                    
                    // Direccion
                    _buildDireccionSection(),
                    
                    const SizedBox(height: 32),
                    
                    // Boton de guardar
                    _buildGuardarButton(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF0D47A1),
              child: Text(
                _profile?.nombreCompleto.substring(0, 2).toUpperCase() ?? 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _profile?.nombreCompleto ?? 'Usuario',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _profile?.hasCompleteData == true 
                        ? 'Perfil completo ✓'
                        : 'Perfil incompleto',
                    style: TextStyle(
                      fontSize: 14,
                      color: _profile?.hasCompleteData == true 
                          ? Colors.green[600]
                          : Colors.orange[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFotoDniSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Foto del DNI',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),
            
            Container(
              width: double.infinity,
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _fotoDni != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        children: [
                          Image.network(
                            _fotoDni is String ? _fotoDni : _fotoDni.path,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green[600],
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                onPressed: () => setState(() => _fotoDni = null),
                                icon: const Icon(Icons.delete, color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _profile?.hasFotoDni == true
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            _profile!.fotoDniUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[200],
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(Icons.error, color: Colors.red),
                              ),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.credit_card,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Agregar foto del DNI',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: SafeOutlinedIconButton(
  onPressed: _seleccionarFotoDni,
  icon: Icons.photo_library,
  label: 'Seleccionar de Galeria',
  style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0D47A1),
                      side: const BorderSide(color: Color(0xFF0D47A1)),
                    ),
),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SafeElevatedIconButton(
  onPressed: _tomarFotoDni,
  icon: Icons.camera_alt,
  label: 'Tomar Foto',
  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D47A1),
                      foregroundColor: Colors.white,
                    ),
),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatosPersonalesSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Datos Personales',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _dniController,
                    decoration: InputDecoration(
                      labelText: 'DNI',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    // Sin validaciones estrictas
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _telefonoController,
                    decoration: InputDecoration(
                      labelText: 'Telefono',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    // Sin validaciones estrictas
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDireccionSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Direccion',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _calleController,
                    decoration: InputDecoration(
                      labelText: 'Calle',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    // Sin validaciones estrictas
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _numeroController,
                    decoration: InputDecoration(
                      labelText: 'Numero',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    // Sin validaciones estrictas
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            TextFormField(
              controller: _localidadController,
              decoration: InputDecoration(
                labelText: 'Localidad',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              // Sin validaciones estrictas
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuardarButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _guardarPerfil,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0D47A1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 2,
        ),
        child: SafeButtonLoadingContent(
          loading: _isSaving,
          icon: Icons.save,
          idleLabel: 'Guardar perfil',
          loadingLabel: 'Guardando...',
          textStyle: const TextStyle(color: Colors.white),
          spinnerColor: Colors.white,
        ),
      ),
    );
  }
}
