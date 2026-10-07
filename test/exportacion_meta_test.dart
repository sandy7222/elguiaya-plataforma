// Exportar el catálogo para Meta (catálogo de WhatsApp Business, Commerce Manager): un Excel con las columnas del feed de Meta.
//
// Pedido del dueño: el "Excel ML" es el formato de Mercado Libre y no trae imágenes, descripción ni nada de lo que pide Meta. Meta recibe las
// imágenes como ENLACES (columna image_link) y la planilla puede ser Excel. Las columnas salen de guías del feed de Meta (id, title, description,
// availability, condition, price con moneda, link, image_link, additional_image_link, brand); hay que confirmarlas con la plantilla de Commerce Manager.

import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:capitanya_master/models/producto.dart';
import 'package:capitanya_master/services/exportacion_meta.dart';

Producto _p({
  String id = 'a1b2c3d4-0000-4000-8000-000000000001',
  String nombre = 'La caña Kushiro de 3.6 metros (Acción Pesada)',
  String descripcion = 'Caña de pesca de acción pesada.',
  String especificaciones = '',
  double precio = 55000,
  int stock = 15,
  String rubro = 'Pesca Deportiva',
  String imagenUrl = 'https://x.supabase.co/storage/v1/object/public/productos/a.jpg',
  List<String> galeria = const [],
  bool activo = true,
}) =>
    Producto(
      id: id,
      nombre: nombre,
      descripcion: descripcion,
      especificaciones: especificaciones,
      precio: precio,
      stock: stock,
      rubro: rubro,
      categoriaId: 'cat',
      imagenUrl: imagenUrl,
      galeriaUrls: galeria,
      activo: activo,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

/// Filas de la hoja (la primera es el encabezado), como texto.
List<List<String>> _leer(List<int> bytes) {
  final libro = Excel.decodeBytes(bytes);
  final hoja = libro.tables.values.first;
  return hoja.rows.map((fila) => fila.map((c) => c?.value?.toString() ?? '').toList()).toList();
}

Map<String, String> _fila(List<List<String>> filas, int i) => {
      for (var c = 0; c < filas[0].length; c++) filas[0][c]: filas[i][c],
    };

void main() {
  // Casos compartidos con la función feed-meta (supabase/functions/feed-meta): las dos tienen que dar exactamente lo mismo.
  group('paridad con la función feed-meta (test/fixtures/feed_meta_casos.json)', () {
    final casos = (jsonDecode(File('test/fixtures/feed_meta_casos.json').readAsStringSync())['casos'] as List).cast<Map<String, dynamic>>();
    for (final c in casos) {
      test(c['nombre_caso'] as String, () {
        final p = Producto.fromSupabase(Map<String, dynamic>.from(c['row'] as Map));
        final fila = ExportacionMeta.fila(p);
        final esperado = (c['esperado'] as Map).map((k, v) => MapEntry(k as String, v as String));
        expect(fila, esperado);
      });
    }
  });

  group('columnas', () {
    test('el encabezado trae las columnas del feed de Meta', () {
      final r = ExportacionMeta.generarExcel([_p()]);
      final filas = _leer(r.bytes);
      expect(filas.first, [
        'id', 'title', 'description', 'availability', 'condition', 'price', 'link', 'image_link', 'additional_image_link', 'brand', 'product_type',
      ]);
    });
    test('hay una fila por producto', () {
      final r = ExportacionMeta.generarExcel([_p(id: 'a'), _p(id: 'b'), _p(id: 'c')]);
      expect(_leer(r.bytes).length, 4);
    });
    test('sin productos: solo el encabezado', () {
      expect(_leer(ExportacionMeta.generarExcel([]).bytes).length, 1);
    });
  });

  group('valores de una fila', () {
    final r = ExportacionMeta.generarExcel([_p(galeria: ['https://x/b.jpg', 'https://x/c.jpg'])]);
    final f = _fila(_leer(r.bytes), 1);

    test('id y título', () {
      expect(f['id'], 'a1b2c3d4-0000-4000-8000-000000000001');
      expect(f['title'], 'La caña Kushiro de 3.6 metros (Acción Pesada)');
    });
    test('precio con moneda y dos decimales', () => expect(f['price'], '55000.00 ARS'));
    test('hay stock → in stock', () => expect(f['availability'], 'in stock'));
    test('condición nuevo', () => expect(f['condition'], 'new'));
    test('marca por defecto', () => expect(f['brand'], 'El Guía YA'));
    test('rubro como product_type', () => expect(f['product_type'], 'Pesca Deportiva'));
    test('enlace a la página del producto', () {
      expect(f['link'], 'https://app.elguiaya.com/#/producto/a1b2c3d4-0000-4000-8000-000000000001');
    });
    test('imagen principal como enlace', () {
      expect(f['image_link'], 'https://x.supabase.co/storage/v1/object/public/productos/a.jpg');
    });
    test('imágenes adicionales separadas por coma', () {
      expect(f['additional_image_link'], 'https://x/b.jpg,https://x/c.jpg');
    });
  });

  group('casos', () {
    test('sin stock → out of stock', () {
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(stock: 0)]).bytes), 1);
      expect(f['availability'], 'out of stock');
    });
    test('producto inactivo → out of stock', () {
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(activo: false)]).bytes), 1);
      expect(f['availability'], 'out of stock');
    });
    test('sin descripción se usa el título (Meta la exige)', () {
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(descripcion: '  ')]).bytes), 1);
      expect(f['description'], 'La caña Kushiro de 3.6 metros (Acción Pesada)');
    });
    test('las especificaciones se suman a la descripción', () {
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(especificaciones: 'Largo: 3.6 m')]).bytes), 1);
      expect(f['description'], contains('Caña de pesca de acción pesada.'));
      expect(f['description'], contains('Largo: 3.6 m'));
    });
    test('el marcador interno de especificaciones nunca llega al archivo', () {
      final f = _fila(
          _leer(ExportacionMeta.generarExcel([_p(descripcion: 'Texto${Producto.specsMarker}Largo: 3.6 m')]).bytes), 1);
      expect(f['description'], isNot(contains('ESPECIFICACIONES')));
      expect(f['description'], isNot(contains('<!--')));
    });
    test('el título se recorta a 200 caracteres (límite de Meta)', () {
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(nombre: 'x' * 250)]).bytes), 1);
      expect(f['title']!.length, 200);
    });
    test('sin imagen principal pero con galería: la primera pasa a ser la principal y no se repite', () {
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(imagenUrl: '', galeria: ['https://x/b.jpg', 'https://x/c.jpg'])]).bytes), 1);
      expect(f['image_link'], 'https://x/b.jpg');
      expect(f['additional_image_link'], 'https://x/c.jpg');
    });
    test('la imagen principal no se repite en las adicionales', () {
      final f = _fila(
          _leer(ExportacionMeta.generarExcel([_p(imagenUrl: 'https://x/a.jpg', galeria: ['https://x/a.jpg', 'https://x/b.jpg'])]).bytes), 1);
      expect(f['additional_image_link'], 'https://x/b.jpg');
    });
    test('hasta 10 imágenes adicionales', () {
      final galeria = [for (var i = 0; i < 15; i++) 'https://x/$i.jpg'];
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(galeria: galeria)]).bytes), 1);
      expect(f['additional_image_link']!.split(',').length, 10);
    });
    test('marca y enlace base se pueden cambiar', () {
      final r = ExportacionMeta.generarExcel([_p()], marca: 'Kushiro', urlProducto: 'https://otra.com/p/');
      final f = _fila(_leer(r.bytes), 1);
      expect(f['brand'], 'Kushiro');
      expect(f['link'], startsWith('https://otra.com/p/'));
    });
    test('el precio no depende del idioma ni usa coma decimal', () {
      final f = _fila(_leer(ExportacionMeta.generarExcel([_p(precio: 16224.5)]).bytes), 1);
      expect(f['price'], '16224.50 ARS');
    });
  });

  group('avisos (cosas que Meta podría rechazar)', () {
    test('un archivo sano no tiene avisos', () {
      expect(ExportacionMeta.generarExcel([_p()]).avisos, isEmpty);
    });
    test('producto sin ninguna imagen', () {
      final r = ExportacionMeta.generarExcel([_p(nombre: 'Reel Sin Foto', imagenUrl: '')]);
      expect(r.avisos.join(' '), contains('Reel Sin Foto'));
      expect(r.avisos.join(' ').toLowerCase(), contains('sin imagen'));
    });
    test('precio de 1 peso o menos (¿de prueba?)', () {
      final r = ExportacionMeta.generarExcel([_p(nombre: 'Reel Frontal Kushiro Limay-3000', precio: 1)]);
      expect(r.avisos.join(' '), contains('Reel Frontal Kushiro Limay-3000'));
      expect(r.avisos.join(' ').toLowerCase(), contains('precio'));
    });
    test('imagen que no es https (Meta no la va a poder abrir)', () {
      final r = ExportacionMeta.generarExcel([_p(nombre: 'Farol', imagenUrl: 'http://x/a.jpg')]);
      expect(r.avisos.join(' ').toLowerCase(), contains('https'));
    });
    test('título recortado', () {
      final r = ExportacionMeta.generarExcel([_p(nombre: 'y' * 250)]);
      expect(r.avisos.join(' ').toLowerCase(), contains('recort'));
    });
    test('producto sin stock avisa que sale como agotado', () {
      final r = ExportacionMeta.generarExcel([_p(nombre: 'Anafe', stock: 0)]);
      expect(r.avisos.join(' ').toLowerCase(), contains('agotado'));
    });
  });
}
