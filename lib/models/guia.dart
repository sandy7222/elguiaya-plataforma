

class Guia {
  final String id;
  final String nombre;
  final String dni;
  final String localidad;
  final String provincia;
  final String calle;
  final String altura;
  final String email;
  final String especialidad;
  final String telefono;
  final String carnetTimonel;
  final String polizaSeguro;
  final String cbu;
  final String? bancoNombre;
  final String? avatarUrl;
  final String? seguroUrl;
  final String? embarcacionUrl;
  final String? carnetUrl;
  final String? dniUrl;
  final String? referido;

  Guia({
    required this.id,
    required this.nombre,
    required this.dni,
    required this.localidad,
    required this.provincia,
    required this.calle,
    required this.altura,
    required this.email,
    required this.especialidad,
    required this.telefono,
    required this.carnetTimonel,
    required this.polizaSeguro,
    required this.cbu,
    this.bancoNombre,
    this.avatarUrl,
    this.seguroUrl,
    this.embarcacionUrl,
    this.carnetUrl,
    this.dniUrl,
    this.referido,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'dni': int.tryParse(dni) ?? 0, // Convertir DNI a numero
      'localidad': localidad,
      'provincia': provincia,
      'calle': calle,
      'altura': altura,
      'email': email,
      'especialidad': especialidad,
      'telefono': telefono,
      'carnet_timonel': carnetTimonel,
      'poliza_seguro': polizaSeguro,
      'cbu': cbu,
      'banco_nombre': bancoNombre,
      'avatar_url': avatarUrl,
      'seguro_url': seguroUrl,
      'embarcacion_url': embarcacionUrl,
      'carnet_url': carnetUrl,
      'dni_url': dniUrl,
      'referido': referido,
    };
  }
}
