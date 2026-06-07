



import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/documento.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';

class CameraPicker extends StatefulWidget {
  final String userId;
  final String tipoDoc;
  final String titulo;
  final IconData icono;
  final Function(File?) onImageSelected;
  final Function(String)? onDocumentoCreado;
  final Function(String)? onUrlGenerated;
  final Future<bool> Function()? onBeforeUpload;

  const CameraPicker({
    super.key,
    required this.userId,
    required this.tipoDoc,
    required this.titulo,
    required this.icono,
    required this.onImageSelected,
    this.onDocumentoCreado,
    this.onUrlGenerated,
    this.onBeforeUpload,
  });

  @override
  State<CameraPicker> createState() => _CameraPickerState();
}

class _CameraPickerState extends State<CameraPicker> {
  File? _selectedImage;
  bool _isLoading = false;
  bool _hasDocument = false;

  @override
  void initState() {
    super.initState();
    _verificarDocumentoExistente();
    _recuperarFotoPerdida();
  }

  Future<void> _recuperarFotoPerdida() async {
    try {
      final File? lostImage = await StorageService.retrieveLostData();
      if (lostImage != null) {
        debugPrint('📸 [CAMERA_PICKER] Recuperando foto perdida para ${widget.titulo}');
        setState(() {
          _selectedImage = lostImage;
          _isLoading = true; // Iniciamos la subida de lo recuperado
        });
        // Intentamos subirla automaticamente como si acabara de ser sacada
        _procesarImagen(lostImage);
      }
    } catch (e) {
      debugPrint('ℹ️ Recuperación de fotos perdidas no disponible en esta plataforma: $e');
    }
  }

  // Refactorizamos la subida para que sea reusable por la recuperacion
  Future<void> _procesarImagen(File image) async {
    try {
      // 1. Compresión Previa
      final File compressedFile = await StorageService.compressImage(image);

      // 2. Subida Inmediata
      String url = '';
      if (widget.tipoDoc == Documento.FOTO_PERFIL_CAPITAN || widget.tipoDoc == Documento.FOTO_PERFIL_PESCADOR) {
        url = await StorageService.uploadProfileImage(
          file: compressedFile,
          userId: widget.userId,
          tipoDoc: widget.tipoDoc,
        );
      } else if (widget.tipoDoc == Documento.DNI_PESCADOR) {
        url = await StorageService.uploadPescadorDocument(
          file: compressedFile,
          userId: widget.userId,
          tipoDoc: widget.tipoDoc,
        );
      } else {
        url = await StorageService.uploadUserDocument(
          file: compressedFile,
          userId: widget.userId,
          tipoDoc: widget.tipoDoc,
        );
      }

      setState(() {
        _hasDocument = true;
        _isLoading = false;
        _selectedImage = compressedFile;
      });

      // 3. Notificar
      widget.onImageSelected(compressedFile);
      if (widget.onUrlGenerated != null) {
        widget.onUrlGenerated!(url);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      // ... manejo de errores ...
    }
  }

  Future<void> _verificarDocumentoExistente() async {
    try {
      final documentos = await SupabaseService.getDocumentosPorUsuario(widget.userId);
      final existe = documentos.any((doc) => doc.tipoDoc == widget.tipoDoc);
      setState(() => _hasDocument = existe);
    } catch (e) {
      // Silenciar error en verificacion inicial
    }
  }

  Future<void> _capturarDesdeCamara() async {
    try {
      final XFile? xfile = await StorageService.captureImageFromCamera();
      if (xfile == null) return;
      final File image = File(xfile.path);

      if (widget.onBeforeUpload != null) {
        final ok = await widget.onBeforeUpload!();
        if (!ok) return;
      }

      setState(() {
        _isLoading = true;
        _selectedImage = image;
      });

      await _procesarImagen(image);

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        if (e.toString().contains('PERMISSION_DENIED')) {
          _showPermissionDialog('camara');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Center(child: Text('Error al subir: $e')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _seleccionarDesdeGaleria() async {
    try {
      final XFile? xfile = await StorageService.pickImageFromGallery();
      if (xfile == null) return;
      final File image = File(xfile.path);

      // 0. Asegurar Autenticacion/Requisitos antes de empezar
      if (widget.onBeforeUpload != null) {
        final ok = await widget.onBeforeUpload!();
        if (!ok) return;
      }

      setState(() {
        _isLoading = true;
        _selectedImage = image;
      });

      // 1. Compresión Previa
      final File compressedFile = await StorageService.compressImage(image);

      // 2. Subida Inmediata
      String url = '';
      if (widget.tipoDoc == Documento.FOTO_PERFIL_CAPITAN || widget.tipoDoc == Documento.FOTO_PERFIL_PESCADOR) {
        url = await StorageService.uploadProfileImage(
          file: compressedFile,
          userId: widget.userId,
          tipoDoc: widget.tipoDoc,
        );
      } else if (widget.tipoDoc == Documento.DNI_PESCADOR) {
        url = await StorageService.uploadPescadorDocument(
          file: compressedFile,
          userId: widget.userId,
          tipoDoc: widget.tipoDoc,
        );
      } else {
        url = await StorageService.uploadUserDocument(
          file: compressedFile,
          userId: widget.userId,
          tipoDoc: widget.tipoDoc,
        );
      }

      setState(() {
        _hasDocument = true;
        _isLoading = false;
      });

      // 3. Notificar URLs y archivo
      widget.onImageSelected(compressedFile);
      if (widget.onUrlGenerated != null) {
        widget.onUrlGenerated!(url);
      }

    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        if (e.toString().contains('PERMISSION_DENIED')) {
          _showPermissionDialog('galeria');
        } else if (e.toString().contains('PERMISSION_PERMANENTLY_DENIED')) {
          _showPermanentDeniedDialog('galeria');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Center(child: Text('Error al subir: $e')), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showPermissionDialog(String tipo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permiso requerido'),
          content: Text('Para subir tu documentacion necesitamos acceso a la $tipo. Por favor, concede el permiso cuando te lo solicite Android.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Reintentar automaticamente
                if (tipo == 'camara') {
                  _capturarDesdeCamara();
                } else {
                  _seleccionarDesdeGaleria();
                }
              },
              child: Text('Intentar de nuevo'),
            ),
          ],
        );
      },
    );
  }

  void _showPermanentDeniedDialog(String tipo) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Permiso denegado permanentemente'),
          content: Text('Para subir tu documentacion necesitamos acceso a la $tipo. Podes activarlo en Ajustes > Aplicaciones > Capitanya > Permisos.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Entendido'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Abrir configuracion de la app
                openAppSettings();
              },
              child: Text('Ir a Ajustes'),
            ),
          ],
        );
      },
    );
  }

  void _mostrarOpciones() {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Seleccionar imagen',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Tomar foto'),
                onTap: () {
                  Navigator.of(context).pop();
                  _capturarDesdeCamara();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Seleccionar de galeria'),
                onTap: () {
                  Navigator.of(context).pop();
                  _seleccionarDesdeGaleria();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.titulo,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _mostrarOpciones,
            child: Container(
              width: double.infinity,
              height: 120,
              decoration: BoxDecoration(
                color: _hasDocument ? Colors.green[50] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _hasDocument ? Colors.green : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : _hasDocument
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.icono,
                                  size: 40,
                                  color: Colors.green,
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Documento subido ✓',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.icono,
                                  size: 40,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tocar para ${widget.tipoDoc == Documento.FOTO_PERFIL_CAPITAN ? 'tomar foto' : 'subir documento'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }
}
