import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:capitanya_master/models/producto.dart';

class ExportacionService {
  /// Genera un archivo Excel en formato MercadoLibre para subir al sitio
  static List<int> generarExcelML(List<Producto> productos) {
    final excel = Excel.createExcel();
    final sheet = excel['Publicaciones'];

    // Encabezado
    sheet.appendRow([
      TextCellValue('ITEM_ID'),
      TextCellValue('TITLE'),
      TextCellValue('QUANTITY'),
      TextCellValue('PRICE'),
      TextCellValue('CURRENCY_ID'),
      TextCellValue('CONDITION'),
      TextCellValue('STATUS'),
    ]);

    for (final p in productos) {
      sheet.appendRow([
        TextCellValue(''),                           // ITEM_ID (vacío para nuevas)
        TextCellValue(p.nombre),
        IntCellValue(p.stock),
        DoubleCellValue(p.precio),
        TextCellValue('ARS'),
        TextCellValue('Nuevo'),
        TextCellValue(p.activo ? 'Activa' : 'Inactiva'),
      ]);
    }

    final bytes = excel.encode();
    return bytes ?? [];
  }

  /// Genera un JSON estándar compatible con el formato de n8n/Ollama
  static String generarJSON(List<Producto> productos) {
    final lista = productos.map((p) => {
      'nombre': p.nombre,
      'descripcion': p.descripcion,
      'precio': p.precio,
      'stock': p.stock,
      'rubro': p.rubro,
      'categoria_id': p.categoriaId,
      'imagen_url': p.imagenUrl,
      'galeria_urls': p.galeriaUrls,
      'video_url': p.videoUrl,
      'activo': p.activo,
      'destacado': p.destacado,
    }).toList();

    return const JsonEncoder.withIndent('  ').convert({'productos': lista});
  }
}
