class Pescador {
  final String? id;
  final String nombre;
  final String dni;
  final String localidad;
  final String provincia;
  final String email;
  final String calle;
  final String altura;
  final String cp;
  final String telefono;
  final String? dniUrl;
  final String? avatarUrl;
  final String? referido;
  final String? bioPescador;

  Pescador({
    this.id,
    required this.nombre,
    required this.dni,
    required this.localidad,
    required this.provincia,
    required this.calle,
    required this.altura,
    required this.email,
    required this.cp,
    required this.telefono,
    this.dniUrl,
    this.avatarUrl,
    this.referido,
    this.bioPescador,
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
      'cp': int.tryParse(cp) ?? 0, // Convertir CP a numero
      'telefono': telefono,
      'dni_url': dniUrl, // URL del DNI subido
      'avatar_url': avatarUrl,
      'referido': referido,
      'bio_pescador': bioPescador,
    };
  }
}
