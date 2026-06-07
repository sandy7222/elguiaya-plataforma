
import 'atributo.dart';

class ProductoAtributo {
  final String id;
  final String productoId;
  final String atributoId;
  String valor;
  final Atributo? detalle; // Info del atributo (nombre, unidad)

  ProductoAtributo({
    required this.id,
    required this.productoId,
    required this.atributoId,
    required this.valor,
    this.detalle,
  });

  factory ProductoAtributo.fromSupabase(Map<String, dynamic> map) {
    return ProductoAtributo(
      id: map['id'] ?? '',
      productoId: map['producto_id'] ?? '',
      atributoId: map['atributo_id'] ?? '',
      valor: map['valor'] ?? '',
      detalle: map['atributos'] != null ? Atributo.fromSupabase(map['atributos']) : null,
    );
  }

  String get displayValue => detalle?.unidad != null ? '$valor ${detalle!.unidad}' : valor;
}
