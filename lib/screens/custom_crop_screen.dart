
import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

class CustomCropScreen extends StatefulWidget {
  final Uint8List imageData;
  final bool isCircular;

  const CustomCropScreen({
    super.key,
    required this.imageData,
    this.isCircular = false,
  });

  @override
  State<CustomCropScreen> createState() => _CustomCropScreenState();
}

class _CustomCropScreenState extends State<CustomCropScreen> {
  final _cropController = CropController();
  bool _isCropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('RECORTAR IMAGEN', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Crop(
              image: widget.imageData,
              controller: _cropController,
              onCropped: (image) {
                Navigator.pop(context, image);
              },
              aspectRatio: widget.isCircular ? 1 : null,
              initialRectBuilder: InitialRectBuilder.withBuilder((viewportRect, imageRect) {
                return Rect.fromLTRB(
                  viewportRect.left + (viewportRect.width * 0.1),
                  viewportRect.top + (viewportRect.height * 0.1),
                  viewportRect.right - (viewportRect.width * 0.1),
                  viewportRect.bottom - (viewportRect.height * 0.1),
                );
              }),
              maskColor: Colors.black.withOpacity(0.8),
              baseColor: Colors.black,
              withCircleUi: widget.isCircular,
              cornerDotBuilder: (size, edgeAlignment) => const DotControl(
                color: Color(0xFF00E676),
                padding: 8,
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
            decoration: const BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ajuste los bordes para encuadrar',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 65,
                  child: ElevatedButton(
                    onPressed: _isCropping 
                        ? null 
                        : () {
                            setState(() => _isCropping = true);
                            _cropController.crop();
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 8,
                    ),
                    child: _isCropping
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.crop, size: 28),
                              SizedBox(width: 15),
                              Text(
                                'FINALIZAR RECORTE',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
