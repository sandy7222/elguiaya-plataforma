// Importación / Exportación (admin): casilla "Seleccionar todos" para el catálogo a exportar.
// Pedido del dueño: hoy hay que tildar producto por producto. La casilla tiene tres estados: todos, ninguno o algunos (guion).

import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/utils/seleccion_catalogo.dart';

void main() {
  final ids = ['a', 'b', 'c'];

  group('estado de la casilla "Seleccionar todos"', () {
    test('ninguno seleccionado → false', () => expect(SeleccionCatalogo.estado({}, ids), isFalse));
    test('todos seleccionados → true', () => expect(SeleccionCatalogo.estado({'a', 'b', 'c'}, ids), isTrue));
    test('algunos → null (guion)', () => expect(SeleccionCatalogo.estado({'a'}, ids), isNull));
    test('lista vacía → false', () => expect(SeleccionCatalogo.estado({'a'}, const []), isFalse));
    test('ignora seleccionados que ya no están en el catálogo', () {
      expect(SeleccionCatalogo.estado({'a', 'b', 'c', 'zzz'}, ids), isTrue);
      expect(SeleccionCatalogo.estado({'zzz'}, ids), isFalse);
    });
  });

  group('alternar', () {
    test('desde ninguno: selecciona todos', () {
      expect(SeleccionCatalogo.alternarTodos({}, ids), {'a', 'b', 'c'});
    });
    test('desde algunos: selecciona todos', () {
      expect(SeleccionCatalogo.alternarTodos({'a'}, ids), {'a', 'b', 'c'});
    });
    test('desde todos: deja ninguno', () {
      expect(SeleccionCatalogo.alternarTodos({'a', 'b', 'c'}, ids), isEmpty);
    });
    test('al sacar todos no toca selecciones de productos que no están en la lista', () {
      expect(SeleccionCatalogo.alternarTodos({'a', 'b', 'c', 'otro'}, ids), {'otro'});
    });
    test('no modifica el conjunto original', () {
      final original = {'a'};
      SeleccionCatalogo.alternarTodos(original, ids);
      expect(original, {'a'});
    });
  });

  group('cuántos se van a exportar', () {
    test('sin selección se exporta todo el catálogo (comportamiento de hoy)', () {
      expect(SeleccionCatalogo.cantidadAExportar({}, ids), 3);
    });
    test('con selección, solo los tildados', () {
      expect(SeleccionCatalogo.cantidadAExportar({'a', 'c'}, ids), 2);
    });
  });
}
