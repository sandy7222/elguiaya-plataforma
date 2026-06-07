
class Atributo {
  final String id;
  final String nombre;
  final String? unidad;
  final String? rubroId;

  Atributo({
    required this.id,
    required this.nombre,
    this.unidad,
    this.rubroId,
  });

  factory Atributo.fromSupabase(Map<String, dynamic> map) {
    return Atributo(
      id: map['id']?.toString() ?? '',
      nombre: map['nombre']?.toString() ?? '',
      unidad: map['unidad']?.toString(),
      rubroId: map['rubro_id']?.toString(),
    );
  }

  static Atributo empty() => Atributo(id: '', nombre: '');
}
