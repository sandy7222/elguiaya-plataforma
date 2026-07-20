import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class PostulacionesService {
  static const String _apiBase = 'https://www.elguiaya.com/api/postulaciones';
  static const String _bucket = 'postulaciones-cv';
  static const int maxBytes = 5 * 1024 * 1024;
  static const Set<String> allowedExt = {'pdf', 'doc', 'docx'};

  static SupabaseClient get _sb => SupabaseService.supabase;

  static String? validarArchivo({required String fileName, required int sizeBytes}) {
    final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
    if (!allowedExt.contains(ext)) {
      return 'Solo se permiten archivos PDF, DOC o DOCX.';
    }
    if (sizeBytes <= 0 || sizeBytes > maxBytes) {
      return 'El CV debe pesar como máximo 5 MB.';
    }
    return null;
  }

  static String mimeFromExt(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  /// Flujo completo: preparar → subir CV → finalizar.
  static Future<void> enviarPostulacion({
    required String nombre,
    required String email,
    required String telefono,
    required String areaInteres,
    String? presentacion,
    required bool aceptaDatos,
    required String fileName,
    required Uint8List fileBytes,
    String? fileMime,
  }) async {
    final err = validarArchivo(fileName: fileName, sizeBytes: fileBytes.length);
    if (err != null) throw Exception(err);
    if (!aceptaDatos) {
      throw Exception('Debés aceptar el tratamiento de datos laborales.');
    }

    final mime = (fileMime != null && fileMime.isNotEmpty)
        ? fileMime
        : mimeFromExt(fileName);

    final prepRes = await http.post(
      Uri.parse(_apiBase),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'preparar',
        'nombre': nombre,
        'email': email,
        'telefono': telefono,
        'area_interes': areaInteres,
        'presentacion': presentacion ?? '',
        'acepta_datos': true,
        'file_name': fileName,
        'file_size': fileBytes.length,
        'file_mime': mime,
      }),
    );
    final prep = _asMap(prepRes.body);
    if (prepRes.statusCode < 200 || prepRes.statusCode >= 300) {
      throw Exception(prep['error']?.toString() ?? 'No se pudo preparar la postulación');
    }

    final uploadUrl = prep['upload_url'] as String?;
    final token = prep['token'] as String?;
    final postulacionId = prep['postulacion_id'] as String?;
    final contentType = (prep['content_type'] as String?) ?? mime;
    if (uploadUrl == null || postulacionId == null) {
      throw Exception('Respuesta incompleta del servidor.');
    }

    final headers = <String, String>{'Content-Type': contentType};
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    var up = await http.put(Uri.parse(uploadUrl), headers: headers, body: fileBytes);
    if (up.statusCode < 200 || up.statusCode >= 300) {
      up = await http.post(
        Uri.parse(uploadUrl),
        headers: {...headers, 'x-upsert': 'true'},
        body: fileBytes,
      );
    }
    if (up.statusCode < 200 || up.statusCode >= 300) {
      throw Exception('No se pudo subir el CV (${up.statusCode}).');
    }

    final finRes = await http.post(
      Uri.parse(_apiBase),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'finalizar',
        'postulacion_id': postulacionId,
      }),
    );
    final fin = _asMap(finRes.body);
    if (finRes.statusCode < 200 || finRes.statusCode >= 300) {
      throw Exception(fin['error']?.toString() ?? 'No se pudo finalizar la postulación');
    }
  }

  static Future<List<Map<String, dynamic>>> listarAdmin({
    String? estado,
    String? area,
    String? busqueda,
    int limit = 50,
    int offset = 0,
  }) async {
    var q = _sb.from('postulaciones').select().neq('estado', 'pendiente_cv');

    if (estado != null && estado.isNotEmpty && estado != 'todas') {
      q = q.eq('estado', estado);
    }
    if (area != null && area.isNotEmpty && area != 'todas') {
      q = q.eq('area_interes', area);
    }
    if (busqueda != null && busqueda.trim().isNotEmpty) {
      final b = busqueda.trim();
      q = q.or('nombre.ilike.%$b%,email.ilike.%$b%,telefono.ilike.%$b%');
    }

    final rows = await q
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  static Future<int> contarNuevas() async {
    try {
      final rows = await _sb.from('postulaciones').select('id').eq('estado', 'nueva');
      return (rows as List).length;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> actualizarEstado({
    required String id,
    required String estado,
    String? notasAdmin,
  }) async {
    final payload = <String, dynamic>{
      'estado': estado,
      'revisada_por': _sb.auth.currentUser?.id,
      'revisada_at': DateTime.now().toIso8601String(),
    };
    if (notasAdmin != null) payload['notas_admin'] = notasAdmin;
    await _sb.from('postulaciones').update(payload).eq('id', id);
  }

  static Future<String> urlCvFirmada(String cvPath, {int expiresIn = 300}) async {
    return await _sb.storage.from(_bucket).createSignedUrl(cvPath, expiresIn);
  }

  static Map<String, dynamic> _asMap(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return <String, dynamic>{};
  }
}
