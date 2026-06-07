

class Documento {
  final String id;
  final String usuarioId;
  final String tipoDoc;
  final String urlStorage;
  final String estado;
  final DateTime createdAt;
  final DateTime updatedAt;

  Documento({
    required this.id,
    required this.usuarioId,
    required this.tipoDoc,
    required this.urlStorage,
    required this.estado,
    required this.createdAt,
    required this.updatedAt,
  });

  // Constructor para crear desde Supabase
  factory Documento.fromSupabase(Map<String, dynamic> data) {
    return Documento(
      id: data['id']?.toString() ?? '',
      usuarioId: data['usuario_id']?.toString() ?? '',
      tipoDoc: data['tipo_doc']?.toString() ?? '',
      urlStorage: data['url_storage']?.toString() ?? '',
      estado: data['estado']?.toString() ?? 'pendiente',
      createdAt: DateTime.tryParse(data['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(data['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  // Convertir a Map para Supabase
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'usuario_id': usuarioId,
      'tipo_doc': tipoDoc,
      'url_storage': urlStorage,
      'estado': estado,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Tipos de documento permitidos
  static const String DNI_CAPITAN = 'dni_capitan';
  static const String MATRICULA = 'matricula';
  static const String SEGURO = 'seguro';
  static const String FOTO_EMBARCACION = 'foto_embarcacion';
  static const String FOTO_PERFIL_CAPITAN = 'foto_perfil_capitan';
  static const String CARNET_TIMONEL = 'carnet_timonel';
  
  static const String DNI_PESCADOR = 'dni_pescador';
  static const String DNI_INVITADO = 'dni_invitado';
  static const String FOTO_PERFIL_PESCADOR = 'foto_perfil_pescador';
  
  static const String FACTURA = 'factura';
  static const String LIQUIDACION = 'liquidacion';
  static const String TICKET_ENVIO = 'ticket_envio';

  // Estados permitidos
  static const String ESTADO_PENDIENTE = 'pendiente';
  static const String ESTADO_APROBADO = 'aprobado';
  static const String ESTADO_RECHAZADO = 'rechazado';

  // Obtener bucket segun tipo de documento
  static String getBucketForType(String tipoDoc) {
    switch (tipoDoc) {
      case FOTO_PERFIL_CAPITAN:
      case FOTO_PERFIL_PESCADOR:
        return 'fotos_perfil'; // Publico
      default:
        return 'documentacion_privada'; // Privado
    }
  }

  // Obtener bucket para administracion
  static String getBucketForAdmin(String tipoDoc) {
    switch (tipoDoc) {
      case FACTURA:
      case LIQUIDACION:
      case TICKET_ENVIO:
        return 'administracion_archivos'; // Privado
      default:
        return 'documentacion_privada'; // Privado
    }
  }
}
