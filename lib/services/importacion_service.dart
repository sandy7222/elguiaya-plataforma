import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:capitanya_master/models/categoria.dart';
import 'package:capitanya_master/models/rubro.dart';

/// Representa un producto parseado desde Excel/JSON antes de ser guardado
class ProductoImportado {
  String nombre;
  String descripcion;
  double precio;
  int stock;
  String rubro;
  String? rubroId;
  String? categoriaId;
  String imagenUrl;
  String? videoUrl;
  bool activo;
  String? referenciaML;
  String? variante;
  List<String> errores;

  ProductoImportado({
    this.nombre = '',
    this.descripcion = '',
    this.precio = 0,
    this.stock = 0,
    this.rubro = '',
    this.rubroId,
    this.categoriaId,
    this.imagenUrl = '',
    this.videoUrl,
    this.activo = true,
    this.referenciaML,
    this.variante,
    this.errores = const [],
  });

  bool get esValido => errores.isEmpty && nombre.isNotEmpty && precio > 0;

  void validar() {
    errores = [];
    if (nombre.trim().isEmpty) errores.add('Nombre vacío');
    if (precio <= 0) errores.add('Precio inválido');
    if (stock < 0) errores.add('Stock negativo');
  }
}

class ImportacionService {
  static List<ProductoImportado> parsearExcelML(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    Sheet? sheet;
    for (final name in excel.tables.keys) {
      if (name.toLowerCase().contains('publicacion')) {
        sheet = excel.tables[name];
        break;
      }
    }
    sheet ??= excel.tables.values
        .firstWhere((s) => s.maxRows > 5, orElse: () => excel.tables.values.first);

    final List<ProductoImportado> productos = [];
    final Set<String> itemIdsVistos = {};

    for (int i = 0; i < sheet.maxRows; i++) {
      final row = sheet.row(i);
      if (row.isEmpty) continue;

      final itemIdRaw = row.length > 1 ? _cellValue(row[1]) : '';
      if (!itemIdRaw.startsWith('MLA')) continue;
      if (itemIdsVistos.contains(itemIdRaw)) continue;
      itemIdsVistos.add(itemIdRaw);

      final titulo = row.length > 4 ? _cellValue(row[4]) : '';
      if (titulo.isEmpty || titulo.startsWith('=')) continue;

      final variante = row.length > 5 ? _cellValue(row[5]) : '';
      final stockRaw = row.length > 6 ? _cellValue(row[6]) : '0';
      final precioRaw = row.length > 7 ? _cellValue(row[7]) : '0';
      final statusRaw = row.length > 11 ? _cellValue(row[11]) : '';

      final precio = double.tryParse(precioRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
      final stock = double.tryParse(stockRaw) ?? 0;
      final activo = statusRaw.toLowerCase().contains('activ') &&
          !statusRaw.toLowerCase().contains('inactiv');

      final nombreLimpio = titulo.replaceAll(RegExp(r'[\u0000-\u001F]'), '').trim();

      final producto = ProductoImportado(
        nombre: nombreLimpio,
        descripcion: nombreLimpio,
        precio: precio,
        stock: stock.toInt(),
        rubro: _inferirRubro(nombreLimpio),
        activo: activo,
        referenciaML: itemIdRaw,
        variante: (variante == '-' || variante == nombreLimpio) ? null : variante,
        imagenUrl: '',
        errores: [],
      );
      producto.validar();
      productos.add(producto);
    }

    return productos;
  }

  static List<ProductoImportado> parsearJSON(String jsonStr) {
    final List<ProductoImportado> productos = [];
    try {
      final data = jsonDecode(jsonStr);
      final List<dynamic> lista = data is List ? data : (data['productos'] ?? []);
      for (final item in lista) {
        if (item is! Map) continue;
        final producto = ProductoImportado(
          nombre: item['nombre']?.toString() ?? item['title']?.toString() ?? '',
          descripcion: item['descripcion']?.toString() ?? item['description']?.toString() ?? '',
          precio: ((item['precio'] ?? item['price'] ?? 0) as num).toDouble(),
          stock: ((item['stock'] ?? item['quantity'] ?? 0) as num).toInt(),
          rubro: item['rubro']?.toString() ?? item['category']?.toString() ?? '',
          imagenUrl: item['imagen_url']?.toString() ?? item['image_url']?.toString() ?? '',
          videoUrl: item['video_url']?.toString() ?? item['videoUrl']?.toString(),
          activo: item['activo'] ?? item['active'] ?? true,
          referenciaML: item['referencia_ml']?.toString() ?? item['item_id']?.toString(),
          errores: [],
        );
        producto.validar();
        productos.add(producto);
      }
    } catch (e) {
      throw FormatException('Error al parsear JSON: $e');
    }
    return productos;
  }

  static String _inferirRubro(String titulo) {
    final t = titulo.toLowerCase();
    if (t.contains('caña') || t.contains('pesca') || t.contains('anzuelo') ||
        t.contains('señuelo') || t.contains('linea') || t.contains('reel') ||
        t.contains('multifilamento') || t.contains('boga')) return 'Pesca';
    if (t.contains('camping') || t.contains('conservadora') || t.contains('termo') ||
        t.contains('colchón') || t.contains('inflable') || t.contains('mochila') ||
        t.contains('farol') || t.contains('linterna')) return 'Camping';
    if (t.contains('caza') || t.contains('camuflad') || t.contains('rifle') ||
        t.contains('binocular') || t.contains('flecha') || t.contains('arco') ||
        t.contains('canana') || t.contains('machete')) return 'Caza';
    if (t.contains('supervivencia') || t.contains('pulsera') || t.contains('brújula') ||
        t.contains('multiherramienta')) return 'Supervivencia';
    return 'General';
  }

  static String _cellValue(dynamic cell) {
    if (cell == null) return '';
    final v = cell is Data ? cell.value : cell;
    if (v == null) return '';
    final s = v.toString().trim();
    if (s == 'null') return '';
    return s;
  }

  static void asignarIdsDesdeNombres(
    List<ProductoImportado> productos,
    List<Rubro> rubros,
    List<Categoria> categorias,
  ) {
    for (final p in productos) {
      final rubroMatch = rubros.where(
        (r) => r.nombre.toLowerCase() == p.rubro.toLowerCase(),
      ).firstOrNull;
      if (rubroMatch != null) p.rubroId = rubroMatch.id;

      if (p.categoriaId == null) {
        final catMatch = categorias.where(
          (c) => c.nombre.toLowerCase().contains(p.rubro.toLowerCase()) ||
              p.rubro.toLowerCase().contains(c.nombre.toLowerCase()),
        ).firstOrNull;
        if (catMatch != null) p.categoriaId = catMatch.id;
      }
    }
  }
}
