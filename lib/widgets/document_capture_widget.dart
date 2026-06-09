
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:El Guia YA_master/services/storage_service.dart';
import 'package:El Guia YA_master/services/supabase_service.dart';
import 'package:El Guia YA_master/screens/custom_camera_screen.dart';
import 'package:El Guia YA_master/screens/custom_crop_screen.dart';

class DocumentCaptureWidget extends StatefulWidget {
  final String label;
  final String tipoDoc;
  final String? initialUrl;
  final Function(String url) onUploadComplete;
  final bool isCircular;
  final IconData icon;

  const DocumentCaptureWidget({
    super.key,
    required this.label,
    required this.tipoDoc,
    this.initialUrl,
    required this.onUploadComplete,
    this.isCircular = false,
    this.icon = Icons.camera_alt_outlined,
  });

  @override
  State<DocumentCaptureWidget> createState() => _DocumentCaptureWidgetState();
}

class _DocumentCaptureWidgetState extends State<DocumentCaptureWidget> {
  String? _currentUrl;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.initialUrl;
    _recuperarDatosPerdidos();
  }

  Future<void> _recuperarDatosPerdidos() async {
    try {
      final LostDataResponse response = await _picker.retrieveLostData();
      if (response.isEmpty) return;
      if (response.file != null) {
        _processXFile(response.file!);
      }
    } catch (e) {
      print('ℹ️ Recuperación de datos perdidos no disponible en esta plataforma: $e');
    }
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
        maxWidth: 1280,  
        maxHeight: 1280,
      );

      if (pickedFile != null) {
        await _processXFile(pickedFile);
      } else {
        setState(() => _isUploading = false);
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _processXFile(XFile pickedFile) async {
    try {
      if (!mounted) return;
      setState(() {
        _isUploading = true;
        _error = null;
        _uploadProgress = 0.2;
      });

      // Leer bytes directamente (Seguro para Web)
      final Uint8List originalBytes = await pickedFile.readAsBytes();

      // 1. Recorte Personalizado pasando BYTES
      final Uint8List? croppedData = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CustomCropScreen(
            imageData: originalBytes,
            isCircular: widget.isCircular,
          ),
        ),
      );

      if (croppedData == null) {
        setState(() => _isUploading = false);
        return;
      }

      setState(() => _uploadProgress = 0.3);

      // 2. Subida directa
      final userId = SupabaseService.currentUserId ?? 'temp_${DateTime.now().millisecondsSinceEpoch}';
      
      setState(() => _uploadProgress = 0.5);
      
      String url;
      // Usamos el metodo uploadBinary que restauramos en StorageService
      url = await StorageService.uploadBinary(
        bytes: croppedData,
        bucket: widget.tipoDoc == 'avatar' ? 'fotos_perfil' : 'documentacion_privada',
        folderPath: userId,
        fileName: '${widget.tipoDoc}.jpg',
        fileNamePrefix: widget.tipoDoc,
      );

      setState(() {
        _currentUrl = url;
        _isUploading = false;
        _uploadProgress = 1.0;
      });

      widget.onUploadComplete(url);

    } catch (e) {
      setState(() {
        _isUploading = false;
        _error = 'Error: ${e.toString()}';
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al subir ${widget.label}: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF001F3F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title: const Text('Tomar Foto', style: TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                final XFile? photo = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CustomCameraScreen(
                      title: 'Capturar ${widget.label}',
                      isDocument: widget.tipoDoc != 'avatar',
                    ),
                  ),
                );
                
                if (photo != null) {
                  await _processXFile(photo);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: const Text('Elegir de Galería', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _pickAndProcess(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _isUploading ? null : _showPickerOptions,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: _error != null 
                    ? Colors.red.withOpacity(0.5) 
                    : (_currentUrl != null ? Colors.green.withOpacity(0.5) : Colors.white24),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                if (_currentUrl != null && !_isUploading)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(_currentUrl!, fit: BoxFit.cover),
                    ),
                  ),
                
                Center(
                  child: _isUploading
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(color: Color(0xFF00E676)),
                            const SizedBox(height: 10),
                            Text(
                              'Subiendo... ${( _uploadProgress * 100).toInt()}%',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        )
                      : (_currentUrl == null 
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(widget.icon, color: Colors.white38, size: 40),
                                const SizedBox(height: 8),
                                const Text('Toca para capturar', style: TextStyle(color: Colors.white38, fontSize: 12)),
                              ],
                            )
                          : Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green, size: 16),
                                  SizedBox(width: 6),
                                  Text('Listo', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            )),
                ),
                
                if (_currentUrl != null && !_isUploading)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.edit, color: Colors.white, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 4),
            child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 10)),
          ),
      ],
    );
  }
}
