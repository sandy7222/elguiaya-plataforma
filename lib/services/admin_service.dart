

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/admin_user.dart';
import '../models/documento.dart';

class AdminService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  /// Aprobar documento de forma atomica
  static Future<bool> aprobarDocumento(String documentoId) async {
    try {
      // Iniciar transaccion atomica
      final response = await _supabase.rpc('aprobar_documento_atomico', 
        params: {
          'p_documento_id': documentoId,
          'p_admin_id': _supabase.auth.currentUser?.id,
        }
      );
      
      return response == true;
    } catch (e) {
      throw Exception('Error al aprobar documento: $e');
    }
  }

  /// Rechazar documento con motivo
  static Future<bool> rechazarDocumento(String documentoId, String motivo) async {
    try {
      final response = await _supabase.rpc('rechazar_documento_atomico', 
        params: {
          'p_documento_id': documentoId,
          'p_admin_id': _supabase.auth.currentUser?.id,
          'p_motivo': motivo,
        }
      );
      
      return response == true;
    } catch (e) {
      throw Exception('Error al rechazar documento: $e');
    }
  }

  /// Obtener documentos pendientes por tipo
  static Future<List<Documento>> getDocumentosPendientesPorTipo(String tipoDoc) async {
    try {
      final response = await _supabase
          .from('documentos_usuarios')
          .select('*')
          .eq('tipo_doc', tipoDoc)
          .eq('estado', Documento.ESTADO_PENDIENTE)
          .order('created_at', ascending: false);
      
      return List<Documento>.from(response.map((doc) => Documento.fromSupabase(doc)));
    } catch (e) {
      throw Exception('Error al obtener documentos pendientes: $e');
    }
  }

  /// Obtener estadisticas de documentos
  static Future<Map<String, int>> getEstadisticasDocumentos() async {
    try {
      final response = await _supabase
          .from('documentos_usuarios')
          .select('estado');
      
      Map<String, int> estadisticas = {};
      for (var doc in response) {
        final estado = doc['estado'] as String;
        estadisticas[estado] = (estadisticas[estado] ?? 0) + 1;
      }
      
      return estadisticas;
    } catch (e) {
      throw Exception('Error al obtener estadisticas: $e');
    }
  }

  /// Obtener documentos por periodo
  static Future<List<Documento>> getDocumentosPorPeriodo(
    DateTime inicio, 
    DateTime fin
  ) async {
    try {
      final response = await _supabase
          .from('documentos_usuarios')
          .select('*')
          .gte('created_at', inicio.toIso8601String())
          .lte('created_at', fin.toIso8601String())
          .order('created_at', ascending: false);
      
      return List<Documento>.from(response.map((doc) => Documento.fromSupabase(doc)));
    } catch (e) {
      throw Exception('Error al obtener documentos por periodo: $e');
    }
  }

  /// Verificar permisos de admin
  static Future<bool> verificarPermisoAdmin(String modulo) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('admin_users')
          .select('rol')
          .eq('id', userId)
          .eq('activo', true)
          .single();
      
      final rol = response['rol'] as String;
      
      switch (modulo) {
        case 'nautico':
          return rol == AdminUser.ROL_ADMIN_MASTER || 
                 rol == AdminUser.ROL_ADMIN_NAUTICO || 
                 rol == AdminUser.ROL_ADMIN_OPERACIONES;
        case 'ecommerce':
          return rol == AdminUser.ROL_ADMIN_MASTER || 
                 rol == AdminUser.ROL_ADMIN_ECOMMERCE || 
                 rol == AdminUser.ROL_ADMIN_OPERACIONES;
        case 'archivos':
          return rol == AdminUser.ROL_ADMIN_MASTER || 
                 rol == AdminUser.ROL_ADMIN_OPERACIONES;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }

  /// Obtener logs de actividad del admin
  static Future<List<Map<String, dynamic>>> getLogsActividad(
    String? adminId, 
    DateTime? inicio, 
    DateTime? fin
  ) async {
    try {
      var query = _supabase
          .from('admin_logs')
          .select('*');
      
      if (adminId != null) {
        query = query.eq('admin_id', adminId);
      }
      
      if (inicio != null) {
        query = query.gte('created_at', inicio.toIso8601String());
      }
      
      if (fin != null) {
        query = query.lte('created_at', fin.toIso8601String());
      }
      
      return await query.order('created_at', ascending: false);
    } catch (e) {
      throw Exception('Error al obtener logs de actividad: $e');
    }
  }

  /// Registrar accion del admin
  static Future<void> registrarAccion(
    String accion, 
    String? modulo, 
    String? entidadId, 
    Map<String, dynamic>? datos
  ) async {
    try {
      await _supabase.from('admin_logs').insert({
        'admin_id': _supabase.auth.currentUser?.id,
        'accion': accion,
        'modulo': modulo,
        'entidad_id': entidadId,
        'datos': datos,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Silenciar error en logging para no interrumpir flujo principal
      print('Error al registrar accion: $e');
    }
  }
}
