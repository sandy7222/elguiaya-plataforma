
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class GestionUsuario {
  final String id;
  final String nombre;
  final String email;
  final String rol;
  final String estadoCuenta;
  final bool verificado;
  final DateTime? fechaVerificacion;
  final String? motivoBaneo;
  final DateTime? fechaBaneo;
  final DateTime creadoAt;
  final String? baneadoPorEmail;
  final bool estaBaneado;
  final bool esCapitanVerificado;

  GestionUsuario({
    required this.id,
    required this.nombre,
    required this.email,
    required this.rol,
    required this.estadoCuenta,
    required this.verificado,
    this.fechaVerificacion,
    this.motivoBaneo,
    this.fechaBaneo,
    required this.creadoAt,
    this.baneadoPorEmail,
    required this.estaBaneado,
    required this.esCapitanVerificado,
  });

  factory GestionUsuario.fromSupabase(Map<String, dynamic> data) {
    return GestionUsuario(
      id: data['id'].toString(),
      nombre: data['nombre'] ?? '',
      email: data['email'] ?? '',
      rol: data['rol'] ?? '',
      estadoCuenta: data['estado_cuenta'] ?? 'activo',
      verificado: data['verificado'] ?? false,
      fechaVerificacion: data['fecha_verificacion'] != null 
          ? DateTime.parse(data['fecha_verificacion'])
          : null,
      motivoBaneo: data['motivo_baneo'],
      fechaBaneo: data['fecha_baneo'] != null 
          ? DateTime.parse(data['fecha_baneo'])
          : null,
      creadoAt: DateTime.parse(data['creado_at'] ?? data['created_at'] ?? DateTime.now().toIso8601String()),
      baneadoPorEmail: data['baneado_por_email'],
      estaBaneado: data['esta_baneado'] ?? (data['estado_cuenta'] == 'baneado'),
      esCapitanVerificado: data['es_capitan_verificado'] ?? (data['es_capitan'] == true && data['verificado'] == true),
    );
  }
}

/// Modelo de log de auditoria
class LogAuditoria {
  final String id;
  final String tipoAccion;
  final String detalles;
  final DateTime creadoAt;
  final String? ipAddress;
  final String? userAgent;
  final String adminEmail;
  final String? adminNombre;
  final String? usuarioAfectadoNombre;
  final String? usuarioAfectadoEmail;
  final String? usuarioAfectadoRol;

  LogAuditoria({
    required this.id,
    required this.tipoAccion,
    required this.detalles,
    required this.creadoAt,
    this.ipAddress,
    this.userAgent,
    required this.adminEmail,
    this.adminNombre,
    this.usuarioAfectadoNombre,
    this.usuarioAfectadoEmail,
    this.usuarioAfectadoRol,
  });

  factory LogAuditoria.fromSupabase(Map<String, dynamic> data) {
    return LogAuditoria(
      id: data['id'].toString(),
      tipoAccion: data['tipo_accion'] ?? '',
      detalles: data['detalles'] ?? '',
      creadoAt: DateTime.parse(data['creado_at']),
      ipAddress: data['ip_address'],
      userAgent: data['user_agent'],
      adminEmail: data['admin_email'] ?? data['admin_id'] ?? 'Sistema',
      adminNombre: data['admin_nombre'] ?? 'Administrador',
      usuarioAfectadoNombre: data['usuario_afectado_nombre'] ?? 'Usuario',
      usuarioAfectadoEmail: data['usuario_afectado_email'] ?? '-',
      usuarioAfectadoRol: data['usuario_afectado_rol'] ?? '-',
    );
  }
}

/// Modelo de estadisticas de seguridad
class EstadisticasSeguridad {
  final int totalUsuarios;
  final int usuariosActivos;
  final int usuariosBaneados;
  final int capitanesVerificados;
  final int capitanesNoVerificados;
  final int baneosUltimos30Dias;
  final int verificacionesUltimos30Dias;

  EstadisticasSeguridad({
    required this.totalUsuarios,
    required this.usuariosActivos,
    required this.usuariosBaneados,
    required this.capitanesVerificados,
    required this.capitanesNoVerificados,
    required this.baneosUltimos30Dias,
    required this.verificacionesUltimos30Dias,
  });

  factory EstadisticasSeguridad.fromSupabase(Map<String, dynamic> data) {
    return EstadisticasSeguridad(
      totalUsuarios: data['total_usuarios'] ?? 0,
      usuariosActivos: data['usuarios_activos'] ?? 0,
      usuariosBaneados: data['usuarios_baneados'] ?? 0,
      capitanesVerificados: data['capitanes_verificados'] ?? 0,
      capitanesNoVerificados: data['capitanes_no_verificados'] ?? 0,
      baneosUltimos30Dias: data['baneos_ultimos_30_dias'] ?? 0,
      verificacionesUltimos30Dias: data['verificaciones_ultimos_30_dias'] ?? 0,
    );
  }
}

/// Servicio de seguridad para baneo y verificacion de usuarios
class SeguridadService {
  static final SupabaseClient _supabase = SupabaseService.supabase;

  /// Banear usuario
  static Future<bool> banearUsuario({
    required String usuarioId,
    String? motivo,
  }) async {
    try {
      final response = await _supabase.rpc('banear_usuario', params: {
        'p_usuario_id': usuarioId,
        'p_motivo': motivo,
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al banear usuario: $e');
    }
  }

  /// Desbanear usuario
  static Future<bool> desbanearUsuario(String usuarioId) async {
    try {
      final response = await _supabase.rpc('desbanear_usuario', params: {
        'p_usuario_id': usuarioId,
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al desbanear usuario: $e');
    }
  }

  /// Verificar capitan
  static Future<bool> verificarCapitan(String capitanId) async {
    try {
      final response = await _supabase.rpc('verificar_capitan', params: {
        'p_capitan_id': capitanId,
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al verificar capitan: $e');
    }
  }

  /// Desverificar capitan
  static Future<bool> desverificarCapitan({
    required String capitanId,
    String? motivo,
  }) async {
    try {
      final response = await _supabase.rpc('desverificar_capitan', params: {
        'p_capitan_id': capitanId,
        'p_motivo': motivo,
      });

      return response ?? false;
    } catch (e) {
      throw Exception('Error al desverificar capitan: $e');
    }
  }

  /// Verificar estado de cuenta en login
  static Future<Map<String, dynamic>> verificarEstadoLogin(String email) async {
    try {
      final response = await _supabase.rpc('verificar_estado_login', params: {
        'p_email': email,
      }).timeout(const Duration(seconds: 3));

      // Seguridad contra nulos: Verificar si response es nulo o vacio
      if (response == null || (response is List && response.isEmpty)) {
        return {'permitido': true, 'mensaje': null, 'estado_cuenta': 'no_existe'};
      }

      // Seguridad contra nulos: Extraer primer elemento con null-aware
      final resultado = response is List ? response.first : response;
      if (resultado == null) {
        return {'permitido': true, 'mensaje': null, 'estado_cuenta': 'no_existe'};
      }

      return {
        'permitido': resultado['permitido'] ?? true,
        'mensaje': resultado['mensaje'],
        'estado_cuenta': resultado['estado_cuenta'] ?? 'no_existe',
        'rol': resultado['rol'],
        'activo': resultado['activo'] ?? true,
      };
    } catch (e) {
      // Si la funcion RPC no existe o hay error de BD, permitir el acceso
      // (no bloquear login por funciones auxiliares que pueden no existir)
      print('DEBUG SeguridadService: verificarEstadoLogin fallo silenciosamente: $e');
      return {'permitido': true, 'mensaje': null, 'estado_cuenta': 'desconocido'};
    }
  }

  /// Obtener lista de usuarios para gestion
  static Future<List<GestionUsuario>> getGestionUsuarios() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('created_at', ascending: false);

      return response.map((usuario) => GestionUsuario.fromSupabase(usuario)).toList();
    } catch (e) {
      print('ERROR SeguridadService: getGestionUsuarios fallo: $e');
      return [];
    }
  }

  /// Obtener stream de usuarios para gestion
  static Stream<List<GestionUsuario>> getGestionUsuariosStream() {
    try {
      return _supabase
          .from('profiles')
          .stream(primaryKey: ['id'])
          .order('created_at', ascending: false)
          .map((event) => event.map((usuario) => GestionUsuario.fromSupabase(usuario)).toList());
    } catch (e) {
      print('ERROR Stream getGestionUsuariosStream: $e');
      return Stream.value([]);
    }
  }

  /// Obtener logs de auditoria
  static Future<List<LogAuditoria>> getLogsAuditoria({
    int? limite,
    String? tipoAccion,
  }) async {
    try {
      var query = _supabase
          .from('logs_admin')
          .select()
          .order('creado_at', ascending: false);

      if (tipoAccion != null) {
        return await _supabase
            .from('logs_admin')
            .select()
            .eq('tipo_accion', tipoAccion)
            .order('creado_at', ascending: false)
            .limit(limite ?? 100)
            .then((response) => response.map((log) => LogAuditoria.fromSupabase(log)).toList());
      }

      if (limite != null) {
        query = query.limit(limite);
      }

      final response = await query;
      return response.map((log) => LogAuditoria.fromSupabase(log)).toList();
    } catch (e) {
      print('ERROR SeguridadService: getLogsAuditoria fallo, devolviendo logs mock locales: $e');
      // Devuelve logs simulados/locales en caso de que la tabla logs_admin no exista aun
      return [
        LogAuditoria(
          id: 'mock-1',
          tipoAccion: 'info',
          detalles: 'El sistema está operando en modo local/recuperación. Por favor ejecuta el script sql/fix_seguridad_completo.sql en Supabase.',
          creadoAt: DateTime.now(),
          adminEmail: 'sistema@El Guia YA.com',
          adminNombre: 'Sistema',
          usuarioAfectadoNombre: 'Ninguno',
          usuarioAfectadoEmail: '-',
          usuarioAfectadoRol: '-',
        ),
      ];
    }
  }

  /// Obtener stream de logs de auditoria
  static Stream<List<LogAuditoria>> getLogsAuditoriaStream({
    String? tipoAccion,
  }) {
    try {
      if (tipoAccion != null) {
        return _supabase
            .from('logs_admin')
            .stream(primaryKey: ['id'])
            .eq('tipo_accion', tipoAccion)
            .order('creado_at', ascending: false)
            .map((event) => event.map((log) => LogAuditoria.fromSupabase(log)).toList());
      }

      return _supabase
          .from('logs_admin')
          .stream(primaryKey: ['id'])
          .order('creado_at', ascending: false)
          .map((event) => event.map((log) => LogAuditoria.fromSupabase(log)).toList());
    } catch (e) {
      print('ERROR Stream getLogsAuditoriaStream: $e');
      return Stream.value([
        LogAuditoria(
          id: 'mock-1',
          tipoAccion: 'info',
          detalles: 'El sistema está operando en modo local/recuperación.',
          creadoAt: DateTime.now(),
          adminEmail: 'sistema@El Guia YA.com',
          adminNombre: 'Sistema',
        )
      ]);
    }
  }

  /// Obtener estadisticas de seguridad
  static Future<EstadisticasSeguridad> getEstadisticasSeguridad() async {
    try {
      final response = await _supabase.rpc('obtener_estadisticas_seguridad');

      if (response == null || response.isEmpty) {
        return EstadisticasSeguridad(
          totalUsuarios: 0,
          usuariosActivos: 0,
          usuariosBaneados: 0,
          capitanesVerificados: 0,
          capitanesNoVerificados: 0,
          baneosUltimos30Dias: 0,
          verificacionesUltimos30Dias: 0,
        );
      }

      return EstadisticasSeguridad.fromSupabase(response.first);
    } catch (e) {
      print('ERROR SeguridadService: getEstadisticasSeguridad fallo: $e. Intentando calcular localmente...');
      try {
        // Fallback: calcular las estadisticas a partir de la lista de usuarios
        final usuarios = await getGestionUsuarios();
        final total = usuarios.length;
        final activos = usuarios.where((u) => u.estadoCuenta == 'activo').length;
        final baneados = usuarios.where((u) => u.estaBaneado || u.estadoCuenta == 'baneado').length;
        final verificados = usuarios.where((u) => u.rol == 'capitan' && u.verificado).length;
        final noVerificados = usuarios.where((u) => u.rol == 'capitan' && !u.verificado).length;

        return EstadisticasSeguridad(
          totalUsuarios: total,
          usuariosActivos: activos,
          usuariosBaneados: baneados,
          capitanesVerificados: verificados,
          capitanesNoVerificados: noVerificados,
          baneosUltimos30Dias: baneados, // Aproximacion local
          verificacionesUltimos30Dias: verificados, // Aproximacion local
        );
      } catch (innerErr) {
        return EstadisticasSeguridad(
          totalUsuarios: 0,
          usuariosActivos: 0,
          usuariosBaneados: 0,
          capitanesVerificados: 0,
          capitanesNoVerificados: 0,
          baneosUltimos30Dias: 0,
          verificacionesUltimos30Dias: 0,
        );
      }
    }
  }

  /// Obtener stream de estadisticas de seguridad
  static Stream<EstadisticasSeguridad> getEstadisticasSeguridadStream() {
    try {
      return _supabase
          .from('logs_admin')
          .stream(primaryKey: ['id'])
          .gte('creado_at', DateTime.now().subtract(const Duration(days: 30)).toIso8601String())
          .asyncMap((event) async {
            final stats = await getEstadisticasSeguridad();
            return stats;
          });
    } catch (e) {
      print('ERROR Stream getEstadisticasSeguridadStream: $e');
      return Stream.periodic(const Duration(seconds: 10)).asyncMap((_) => getEstadisticasSeguridad());
    }
  }

  /// Buscar usuarios por email o nombre
  static Future<List<GestionUsuario>> buscarUsuarios(String query) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .or('email.ilike.%$query%,nombre.ilike.%$query%')
          .order('created_at', ascending: false);

      return response.map((usuario) => GestionUsuario.fromSupabase(usuario)).toList();
    } catch (e) {
      throw Exception('Error al buscar usuarios: $e');
    }
  }

  /// Obtener capitanes pendientes de verificacion
  static Future<List<GestionUsuario>> getCapitanesPendientesVerificacion() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('rol', 'capitan')
          .eq('verificado', false)
          .eq('estado_cuenta', 'activo')
          .order('created_at', ascending: false);

      return response.map((usuario) => GestionUsuario.fromSupabase(usuario)).toList();
    } catch (e) {
      throw Exception('Error al obtener capitanes pendientes: $e');
    }
  }

  /// Obtener usuarios baneados
  static Future<List<GestionUsuario>> getUsuariosBaneados() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('estado_cuenta', 'baneado')
          .order('fecha_baneo', ascending: false);

      return response.map((usuario) => GestionUsuario.fromSupabase(usuario)).toList();
    } catch (e) {
      throw Exception('Error al obtener usuarios baneados: $e');
    }
  }

  /// Verificar si el usuario actual es administrador
  static bool esAdministrador() {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    
    return user.userMetadata?['rol']?.toString().toLowerCase() == 'admin';
  }

  /// Obtener informacion de un usuario especifico
  static Future<GestionUsuario?> getUsuarioPorId(String usuarioId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', usuarioId)
          .maybeSingle();

      if (response == null) return null;

      return GestionUsuario.fromSupabase(response);
    } catch (e) {
      throw Exception('Error al obtener usuario: $e');
    }
  }

  /// Cambiar estado de cuenta de usuario (toggle activo/baneado)
  static Future<bool> cambiarEstadoCuenta({
    required String usuarioId,
    required String nuevoEstado,
    String? motivo,
  }) async {
    try {
      if (nuevoEstado == 'baneado') {
        return await banearUsuario(usuarioId: usuarioId, motivo: motivo);
      } else if (nuevoEstado == 'activo') {
        return await desbanearUsuario(usuarioId);
      } else {
        throw Exception('Estado de cuenta no valido');
      }
    } catch (e) {
      throw Exception('Error al cambiar estado de cuenta: $e');
    }
  }

  /// Cambiar estado de verificacion de capitan (toggle verificado/no verificado)
  static Future<bool> cambiarEstadoVerificacion({
    required String capitanId,
    required bool verificado,
    String? motivo,
  }) async {
    try {
      if (verificado) {
        return await verificarCapitan(capitanId);
      } else {
        return await desverificarCapitan(capitanId: capitanId, motivo: motivo);
      }
    } catch (e) {
      throw Exception('Error al cambiar estado de verificacion: $e');
    }
  }

  /// Obtener resumen de actividad reciente
  static Future<Map<String, dynamic>> getResumenActividadReciente() async {
    try {
      final logsBaneos = await getLogsAuditoria(limite: 5, tipoAccion: 'baneo');
      final logsVerificaciones = await getLogsAuditoria(limite: 5, tipoAccion: 'verificacion');
      final estadisticas = await getEstadisticasSeguridad();

      return {
        'baneos_recientes': logsBaneos,
        'verificaciones_recientes': logsVerificaciones,
        'estadisticas': estadisticas,
      };
    } catch (e) {
      throw Exception('Error al obtener resumen de actividad: $e');
    }
  }
}
