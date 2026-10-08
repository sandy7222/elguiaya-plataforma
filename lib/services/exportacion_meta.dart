import 'package:excel/excel.dart';
import 'package:capitanya_master/models/producto.dart';

/// Lo que devuelve [ExportacionMeta.generarExcel]: el archivo y los avisos (cosas que Meta podría rechazar).
class ResultadoExportMeta {
  final List<int> bytes;
  final List<String> avisos;
  const ResultadoExportMeta(this.bytes, this.avisos);
}

/// Excel para el catálogo de Meta (Commerce Manager, que alimenta el catálogo de WhatsApp Business).
///
/// A diferencia del "Excel ML" (formato de Mercado Libre, sin imágenes), acá van las columnas del feed de Meta. Las imágenes viajan como
/// ENLACES públicos (`image_link`, `additional_image_link`): Meta las descarga desde ahí; una foto pegada dentro de la celda no se lee.
/// Columnas según guías del feed de Meta (confirmar con la plantilla de Commerce Manager): id, title, description, availability, condition,
/// price (con moneda: "55000.00 ARS"), link, image_link, additional_image_link, brand, product_type.
class ExportacionMeta {
  static const List<String> encabezados = [
    'id', 'title', 'description', 'availability', 'condition', 'price', 'link', 'image_link', 'additional_image_link', 'brand', 'product_type',
  ];

  static const int _maxTitulo = 200;
  static const int _maxAdicionales = 10;

  static ResultadoExportMeta generarExcel(
    List<Producto> productos, {
    String marca = 'El Guía YA',
    String urlProducto = 'https://elguiaya.com/tienda',
    String moneda = 'ARS',
  }) {
    final libro = Excel.createExcel();
    final hoja = libro['catalogo'];
    libro.setDefaultSheet('catalogo');
    final avisos = <String>[];

    hoja.appendRow(encabezados.map((e) => TextCellValue(e)).toList());

    for (final p in productos) {
      final nombre = p.nombre.trim();
      if (nombre.length > _maxTitulo) {
        avisos.add('«${_corto(nombre)}»: el título se recortó a $_maxTitulo caracteres (límite de Meta).');
      }
      final f = fila(p, marca: marca, urlProducto: urlProducto, moneda: moneda);
      if (f['image_link']!.isEmpty) {
        avisos.add('«${_corto(nombre)}»: sin imagen (Meta pide una imagen por producto).');
      }
      if (_imagenes(p).any((u) => !u.toLowerCase().startsWith('https://'))) {
        avisos.add('«${_corto(nombre)}»: una imagen no es https; Meta no la va a poder abrir.');
      }
      if (p.precio <= 1) {
        avisos.add('«${_corto(nombre)}»: el precio es \$${p.precio.toStringAsFixed(2)}; ¿es un precio de prueba?');
      }
      if (f['availability'] == 'out of stock') {
        avisos.add('«${_corto(nombre)}»: sale como agotado (${p.activo ? 'sin stock' : 'producto inactivo'}).');
      }
      hoja.appendRow(encabezados.map((c) => TextCellValue(f[c]!)).toList());
    }

    // `Excel.createExcel()` crea una hoja "Sheet1" vacía: se la saca para que Meta lea la hoja del catálogo.
    if (libro.tables.containsKey('Sheet1')) libro.delete('Sheet1');

    return ResultadoExportMeta(libro.encode() ?? <int>[], avisos);
  }

  /// Enlace del producto. Si [base] trae `{id}` se reemplaza por el id; si termina en `/` se le suma el id (rutas por producto);
  /// si no, es un enlace fijo para todos (por ejemplo la tienda: `https://elguiaya.com/tienda`).
  static String _enlace(String base, String id) {
    if (base.contains('{id}')) return base.replaceAll('{id}', id);
    if (base.endsWith('/')) return '$base$id';
    return base;
  }

  /// Imágenes del producto sin repetir: la principal primero (o, si falta, la primera de la galería).
  static List<String> _imagenes(Producto p) {
    final todas = <String>[
      if (p.imagenUrl.trim().isNotEmpty) p.imagenUrl.trim(),
      ...p.galeriaUrls.map((u) => u.trim()).where((u) => u.isNotEmpty),
    ];
    final unicas = <String>[];
    for (final u in todas) {
      if (!unicas.contains(u)) unicas.add(u);
    }
    return unicas;
  }

  /// Una fila del feed de Meta (columna → valor). La misma regla vive en la función `feed-meta` (supabase/functions/feed-meta/feed_meta.ts);
  /// los dos se prueban con los casos de test/fixtures/feed_meta_casos.json.
  static Map<String, String> fila(
    Producto p, {
    String marca = 'El Guía YA',
    String urlProducto = 'https://elguiaya.com/tienda',
    String moneda = 'ARS',
  }) {
    final nombre = p.nombre.trim();
    final titulo = nombre.length > _maxTitulo ? nombre.substring(0, _maxTitulo) : nombre;
    final imagenes = _imagenes(p);
    final agotado = !p.activo || p.stock <= 0;
    return {
      'id': p.id,
      'title': titulo,
      'description': _descripcion(p, nombre),
      'availability': agotado ? 'out of stock' : 'in stock',
      'condition': 'new',
      'price': '${p.precio.toStringAsFixed(2)} $moneda',
      'link': _enlace(urlProducto, p.id),
      'image_link': imagenes.isEmpty ? '' : imagenes.first,
      'additional_image_link': imagenes.skip(1).take(_maxAdicionales).join(','),
      'brand': marca,
      'product_type': p.rubro,
    };
  }

  static String _corto(String t) => t.length > 40 ? '${t.substring(0, 40)}…' : t;

  /// Descripción + especificaciones; si no hay nada, el título (Meta no acepta descripciones vacías). Nunca deja el marcador interno.
  static String _descripcion(Producto p, String titulo) {
    var desc = p.descripcion;
    final i = desc.indexOf(Producto.specsMarker);
    var specs = p.especificaciones;
    if (i >= 0) {
      if (specs.trim().isEmpty) specs = desc.substring(i + Producto.specsMarker.length);
      desc = desc.substring(0, i);
    }
    final partes = [desc.trim(), specs.trim()].where((t) => t.isNotEmpty).toList();
    return partes.isEmpty ? titulo : partes.join('\n\n');
  }
}
