
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class StorageService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static final ImagePicker _imagePicker = ImagePicker();

  // Alias compatibles con SmartCheckout y otros flujos
  static Future<dynamic> pickDniImage() => pickImageFromGallery();
  static Future<dynamic> captureDniImage() => captureImageFromCamera();

  /// Capturar imagen desde la camara (Seguro para Web/Mobile)
  static Future<XFile?> captureImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
        maxWidth: 1600,
        maxHeight: 1600,
      );
      return image;
    } catch (e) {
      print('❌ Error capturando imagen: $e');
      return null;
    }
  }

  /// Seleccionar imagen desde la galeria (Seguro para Web/Mobile)
  static Future<XFile?> pickImageFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      return image;
    } catch (e) {
      print('❌ Error seleccionando imagen: $e');
      return null;
    }
  }

  /// Metodo Unico de Subida Binaria (El mas estable para Web)
  static Future<String> uploadXFile({
    required XFile xFile,
    required String bucket,
    required String folderPath,
    required String fileNamePrefix,
  }) async {
    try {
      final Uint8List bytes = await xFile.readAsBytes();
      
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = p.extension(xFile.name).toLowerCase().isEmpty ? '.jpg' : p.extension(xFile.name).toLowerCase();
      final String finalFileName = '${fileNamePrefix.toLowerCase()}_$timestamp$extension';
      final String fullPath = '$folderPath/$finalFileName';

      await _supabase.storage.from(bucket).uploadBinary(
        fullPath,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: 'image/jpeg',
        ),
      );

      return _supabase.storage.from(bucket).getPublicUrl(fullPath);
    } catch (e) {
      print('❌ ERROR UPLOAD: $e');
      rethrow;
    }
  }

  // Helper to convert dynamic File/XFile to XFile
  static XFile _convertToXFile(dynamic file) {
    if (file is XFile) return file;
    if (file is File) return XFile(file.path);
    throw 'Tipo de archivo no compatible: ${file.runtimeType}';
  }

  // Wrappers para compatibilidad con el resto de la app
  static Future<String> uploadProfileImage({required dynamic file, required String userId, required String tipoDoc}) async {
    final xFile = _convertToXFile(file);
    return await uploadXFile(xFile: xFile, bucket: 'fotos_perfil', folderPath: userId, fileNamePrefix: 'avatar');
  }

  static Future<String> uploadUserDocument({required dynamic file, required String userId, required String tipoDoc}) async {
    final xFile = _convertToXFile(file);
    return await uploadXFile(xFile: xFile, bucket: 'documentacion_privada', folderPath: userId, fileNamePrefix: tipoDoc);
  }

  static Future<String> uploadPescadorDocument({required dynamic file, required String userId, required String tipoDoc}) async {
    final xFile = _convertToXFile(file);
    return await uploadXFile(xFile: xFile, bucket: 'documentacion_privada', folderPath: userId, fileNamePrefix: tipoDoc);
  }

  /// Recupera fotos perdidas (Android)
  static Future<File?> retrieveLostData() async {
    try {
      final LostDataResponse response = await _imagePicker.retrieveLostData();
      if (response.isEmpty) return null;
      if (response.file != null) {
        return File(response.file!.path);
      }
    } catch (e) {
      print('❌ Error recuperando datos perdidos: $e');
    }
    return null;
  }

  /// Comprime una imagen usando flutter_image_compress
  static Future<File> compressImage(File file) async {
    try {
      final String dir = p.dirname(file.path);
      final String filename = p.basenameWithoutExtension(file.path);
      final String ext = p.extension(file.path);
      final String targetPath = '$dir/${filename}_compressed$ext';

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 70,
      );

      if (result != null) {
        return File(result.path);
      }
    } catch (e) {
      print('⚠️ Error en compresión de imagen, usando original: $e');
    }
    return file;
  }

  // Metodo para subir imagenes de productos al bucket PUBLICO 'productos'
  static Future<String> uploadProductImage({required XFile file, required String folder, required String prefix}) async {
    return await uploadXFile(
      xFile: file, 
      bucket: 'productos', 
      folderPath: folder, 
      fileNamePrefix: prefix
    );
  }

  // Métodos de compatibilidad con argumentos NOMBRADOS
  static Future<String> uploadAdminDocument({required dynamic file, required String folder, required String prefix}) async {
    final xFile = _convertToXFile(file);
    return await uploadXFile(xFile: xFile, bucket: 'documentacion_privada', folderPath: folder, fileNamePrefix: prefix);
  }

  static Future<String> uploadBinary({required dynamic bytes, required String fileName, required String bucket, required String folderPath, required String fileNamePrefix}) async {
    return await _supabase.storage.from(bucket).uploadBinary(
      '$folderPath/$fileName',
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    ).then((_) => _supabase.storage.from(bucket).getPublicUrl('$folderPath/$fileName'));
  }

  static Future<String> uploadDniViaje({required dynamic file, required String userId}) async {
    if (file is XFile) return await uploadXFile(xFile: file, bucket: 'documentacion_privada', folderPath: userId, fileNamePrefix: 'dni_viaje');
    throw 'Tipo de archivo no compatible';
  }

  static const String _bucketPrivado = 'documentacion_privada';

  /// Seleccionar comprobante desde el explorador de archivos local (imagen o PDF).
  static Future<XFile?> pickComprobanteArchivoLocal() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
        allowMultiple: false,
        withData: kIsWeb,
      );
      if (result == null || result.files.isEmpty) return null;

      final picked = result.files.first;
      if (picked.bytes != null) {
        return XFile.fromData(
          picked.bytes!,
          name: picked.name,
          mimeType: _mimeFromFileName(picked.name),
        );
      }
      if (picked.path != null) {
        return XFile(picked.path!, name: picked.name);
      }
      return null;
    } catch (e) {
      print('❌ Error al elegir archivo local: $e');
      rethrow;
    }
  }

  static String _mimeFromFileName(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    switch (ext) {
      case '.pdf':
        return 'application/pdf';
      case '.png':
        return 'image/png';
      case '.webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  /// Sube ticket MP de liquidación y devuelve la ruta interna (no URL pública).
  static Future<String> uploadLiquidacionComprobante({
    required XFile file,
    required String liquidacionId,
  }) async {
    final Uint8List bytes = await file.readAsBytes();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final String extension = p.extension(file.name).toLowerCase().isEmpty
        ? '.jpg'
        : p.extension(file.name).toLowerCase();
    final String fullPath =
        'liquidaciones/$liquidacionId/comprobante_mp_$timestamp$extension';
    final contentType = _mimeFromFileName(file.name);

    await _supabase.storage.from(_bucketPrivado).uploadBinary(
      fullPath,
      bytes,
      fileOptions: FileOptions(
        cacheControl: '3600',
        upsert: true,
        contentType: contentType,
      ),
    );

    return fullPath;
  }

  /// URL firmada temporal para ver comprobantes privados (solo admin).
  static Future<String> getSignedComprobanteUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    final signed = await _supabase.storage
        .from(_bucketPrivado)
        .createSignedUrl(storagePath, expiresInSeconds);
    return signed;
  }

  /// Elimina una imagen de banner usando su URL pública
  static Future<void> deleteBannerImage(String imageUrl) async {
    try {
      final uri = Uri.parse(imageUrl);
      final segments = uri.pathSegments;
      final int publicIdx = segments.indexOf('public');
      if (publicIdx != -1 && segments.length > publicIdx + 2) {
        final bucket = segments[publicIdx + 1];
        final relativePath = segments.sublist(publicIdx + 2).join('/');
        await _supabase.storage.from(bucket).remove([relativePath]);
      }
    } catch (e) {
      print('Error al eliminar imagen de banner: $e');
    }
  }
}
