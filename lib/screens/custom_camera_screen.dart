

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CustomCameraScreen extends StatefulWidget {
  final String title;
  final bool isDocument;

  const CustomCameraScreen({
    super.key,
    this.title = 'Capturar Documento',
    this.isDocument = true,
  });

  @override
  State<CustomCameraScreen> createState() => _CustomCameraScreenState();
}

class _CustomCameraScreenState extends State<CustomCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  XFile? _capturedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera({CameraDescription? description}) async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        // Si no se pasa descripcion, intentar usar la frontal si es avatar
        final CameraDescription selectedCamera = description ?? 
            (_cameras!.any((c) => c.lensDirection == CameraLensDirection.front) && !widget.isDocument
                ? _cameras!.firstWhere((c) => c.lensDirection == CameraLensDirection.front)
                : _cameras![0]);

        _controller = CameraController(
          selectedCamera,
          ResolutionPreset.high,
          enableAudio: false,
        );

        await _controller!.initialize();
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      }
    } catch (e) {
      debugPrint('❌ Error al inicializar cámara: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) return;
    
    final lensDirection = _controller!.description.lensDirection;
    CameraDescription newDescription;
    
    if (lensDirection == CameraLensDirection.back) {
      newDescription = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => _cameras![0],
      );
    } else {
      newDescription = _cameras!.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras![0],
      );
    }

    setState(() => _isInitialized = false);
    await _controller?.dispose();
    await _initializeCamera(description: newDescription);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    if (cameraController == null || !cameraController.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera(description: cameraController.description);
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final XFile file = await _controller!.takePicture();
      setState(() => _capturedFile = file);
    } catch (e) {
      debugPrint('❌ Error al tomar foto: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Vista Previa o Foto Capturada
          Positioned.fill(
            child: _capturedFile == null 
                ? AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: CameraPreview(_controller!),
                  )
                : Image.network(_capturedFile!.path, fit: BoxFit.cover),
          ),

          // 2. Overlay de Encuadre (Solo si es documento)
          if (widget.isDocument && _capturedFile == null)
            _buildDocumentOverlay(),

          // 3. UI de Controles
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                const Spacer(),
                _buildBottomControls(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Text(
            widget.title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const Spacer(),
          if (_capturedFile == null && _cameras != null && _cameras!.length > 1)
            IconButton(
              icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 28),
              onPressed: _switchCamera,
            ),
        ],
      ),
    );
  }

  Widget _buildDocumentOverlay() {
    return Stack(
      children: [
        ColorFiltered(
          overlayColor: Colors.black.withOpacity(0.5),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  height: MediaQuery.of(context).size.width * 0.85 * 0.63, // Proporción DNI
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ),
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.width * 0.85 * 0.63,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF00E676), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.5 + (MediaQuery.of(context).size.width * 0.85 * 0.35),
          left: 0,
          right: 0,
          child: const Center(
            child: Text(
              'Alinee el documento con el recuadro',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.only(bottom: 40, top: 20), // Elevado para evitar botones del sistema
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.7), Colors.transparent],
        ),
      ),
      child: _capturedFile == null ? _buildShutterUI() : _buildActionUI(),
    );
  }

  Widget _buildShutterUI() {
    return Center(
      child: GestureDetector(
        onTap: _takePicture,
        child: Container(
          width: 80,
          height: 80,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.camera_alt, color: Colors.black, size: 30),
          ),
        ),
      ),
    );
  }

  Widget _buildActionUI() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Botón Reintentar
        _buildActionButton(
          icon: Icons.refresh,
          label: 'REPETIR',
          color: Colors.white24,
          onTap: () => setState(() => _capturedFile = null),
        ),
        // Botón Confirmar
        _buildActionButton(
          icon: Icons.check_circle,
          label: 'USAR FOTO',
          color: const Color(0xFF00E676),
          onTap: () => Navigator.pop(context, _capturedFile),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class ColorFiltered extends StatelessWidget {
  final Widget child;
  final Color overlayColor;

  const ColorFiltered({super.key, required this.child, required this.overlayColor});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) {
        return LinearGradient(colors: [overlayColor, overlayColor]).createShader(rect);
      },
      child: child,
    );
  }
}
