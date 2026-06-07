



import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/documento.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class PerfilScreen extends StatefulWidget {
  final String userId;
  final String rol; // 'capitan' o 'pescador'

  const PerfilScreen({
    super.key,
    required this.userId,
    required this.rol,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  File? _profileImage;
  bool _isLoading = false;
  List<Documento> _documentos = [];

  @override
  void initState() {
    super.initState();
    _cargarDocumentos();
  }

  Future<void> _cargarDocumentos() async {
    try {
      final documentos = await SupabaseService.getDocumentosPorUsuario(widget.userId);
      setState(() {
        _documentos = documentos;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar documentos: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _capturarFoto() async {
    try {
      setState(() => _isLoading = true);

      final XFile? image = await StorageService.captureImageFromCamera();
      
      if (image != null) {
        setState(() => _profileImage = File(image.path));
        
        // Subir imagen directamente al bucket perfiles
        final tipoDocumento = widget.rol == 'capitan' 
            ? Documento.FOTO_PERFIL_CAPITAN 
            : Documento.FOTO_PERFIL_PESCADOR;
        
        final imageUrl = await StorageService.uploadProfileImage(
          file: image,
          userId: widget.userId,
          tipoDoc: tipoDocumento,
        );

        // Guardar referencia en la tabla documentos
        final documento = Documento(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          usuarioId: widget.userId,
          tipoDoc: tipoDocumento,
          urlStorage: imageUrl,
          estado: Documento.ESTADO_PENDIENTE,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await SupabaseService.guardarDocumento(documento);
        
        // Recargar documentos
        await _cargarDocumentos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Center(child: Text('¡Foto de perfil actualizada con exito!')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al capturar foto: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _subirDocumento(String tipoDocumento, String descripcion) async {
    try {
      setState(() => _isLoading = true);

      final XFile? image = await StorageService.pickImageFromGallery();
      
      if (image != null) {
        // Subir al bucket correspondiente
        String imageUrl;
        
        if (tipoDocumento == Documento.FOTO_PERFIL_CAPITAN || tipoDocumento == Documento.FOTO_PERFIL_PESCADOR) {
          imageUrl = await StorageService.uploadProfileImage(
            file: image,
            userId: widget.userId,
            tipoDoc: tipoDocumento,
          );
        } else {
          imageUrl = await StorageService.uploadUserDocument(
            file: image,
            userId: widget.userId,
            tipoDoc: tipoDocumento,
          );
        }

        // Guardar referencia en la tabla documentos
        final documento = Documento(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          usuarioId: widget.userId,
          tipoDoc: tipoDocumento,
          urlStorage: imageUrl,
          estado: Documento.ESTADO_PENDIENTE,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await SupabaseService.guardarDocumento(documento);
        
        // Recargar documentos
        await _cargarDocumentos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Center(child: Text('$descripcion subido con exito')),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir documento: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildProfileImage() {
    final profileDoc = _documentos.where((doc) => 
      doc.tipoDoc == Documento.FOTO_PERFIL_CAPITAN || 
      doc.tipoDoc == Documento.FOTO_PERFIL_PESCADOR
    ).firstOrNull;

    return GestureDetector(
      onTap: _capturarFoto,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.grey[200],
          border: Border.all(color: const Color(0xFF0D47A1), width: 3),
        ),
        child: _profileImage != null
            ? ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover))
            : profileDoc != null
                ? ClipOval(child: Image.network(profileDoc.urlStorage, fit: BoxFit.cover))
                : const Icon(Icons.camera_alt, size: 40, color: Color(0xFF0D47A1)),
      ),
    );
  }

  List<Widget> _buildDocumentButtons() {
    if (widget.rol == 'capitan') {
      return [
        _buildDocumentButton(
          'DNI',
          Icons.badge_outlined,
          Documento.DNI_CAPITAN,
          'DNI del Capitan',
        ),
        _buildDocumentButton(
          'Matricula',
          Icons.card_membership,
          Documento.MATRICULA,
          'Matricula de la embarcacion',
        ),
        _buildDocumentButton(
          'Seguro',
          Icons.security,
          Documento.SEGURO,
          'Seguro de la embarcacion',
        ),
        _buildDocumentButton(
          'Embarcacion',
          Icons.sailing,
          Documento.FOTO_EMBARCACION,
          'Foto de la embarcacion',
        ),
      ];
    } else {
      return [
        _buildDocumentButton(
          'DNI',
          Icons.badge_outlined,
          Documento.DNI_PESCADOR,
          'DNI del Pescador',
        ),
        _buildDocumentButton(
          'DNI Invitado',
          Icons.group_add,
          Documento.DNI_INVITADO,
          'DNI de invitados',
        ),
      ];
    }
  }

  Widget _buildDocumentButton(String title, IconData icon, String tipo, String descripcion) {
    final doc = _documentos.where((d) => d.tipoDoc == tipo).firstOrNull;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: () => _subirDocumento(tipo, descripcion),
        icon: Icon(icon, color: doc != null ? Colors.green : const Color(0xFF0D47A1)),
        label: Text(
          doc != null ? '$title ✓' : title,
          style: TextStyle(
            color: doc != null ? Colors.green : const Color(0xFF0D47A1),
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF0D47A1),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: doc != null ? Colors.green : const Color(0xFF0D47A1),
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'Perfil ${widget.rol == 'capitan' ? 'Capitan' : 'Pescador'}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Foto de perfil
                  Center(
                    child: Column(
                      children: [
                        _buildProfileImage(),
                        const SizedBox(height: 10),
                        const Text(
                          'Toca para actualizar foto',
                          style: TextStyle(
                            color: Color(0xFF0D47A1),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  // Documentos requeridos
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Documentos',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Botones de documentos
                  ..._buildDocumentButtons(),
                ],
              ),
            ),
    );
  }
}
