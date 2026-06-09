
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class PdfService {
  /// Función auxiliar para descargar imágenes desde una URL
  static Future<pw.MemoryImage?> _fetchImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return pw.MemoryImage(response.bodyBytes);
      }
    } catch (e) {
      print('Error descargando imagen para PDF: $e');
    }
    return null;
  }

  static Future<void> generarFichaSocio(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    // Cargar Logo
    pw.MemoryImage? logo;
    try {
      final logoData = await rootBundle.load('assets/images/logo_elguiaya.png');
      logo = pw.MemoryImage(logoData.buffer.asUint8List());
    } catch (e) {}

    // Descargar miniaturas (Avatar, DNI, Carnet)
    final avatarImg = await _fetchImage(data['avatar_url']);
    final dniImg = await _fetchImage(data['foto_dni_url'] ?? data['dni_url']);
    final carnetImg = await _fetchImage(data['carnet_url']);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Container(
            padding: const pw.EdgeInsets.all(30),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Encabezado Premium con Avatar
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        if (avatarImg != null) 
                          pw.Container(
                            width: 60,
                            height: 60,
                            decoration: pw.BoxDecoration(
                              shape: pw.BoxShape.circle,
                              image: pw.DecorationImage(image: avatarImg, fit: pw.BoxFit.cover),
                              border: pw.Border.all(color: PdfColors.blue900, width: 2),
                            ),
                          )
                        else
                          pw.Container(
                            width: 60,
                            height: 60,
                            decoration: const pw.BoxDecoration(shape: pw.BoxShape.circle, color: PdfColors.grey300),
                            child: pw.Center(child: pw.Text('USER', style: const pw.TextStyle(fontSize: 8))),
                          ),
                        pw.SizedBox(width: 15),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('EL GUIA YA', 
                              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            pw.Text('Legajo Administrativo de Socio', 
                              style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700, letterSpacing: 1.5)),
                          ],
                        ),
                      ],
                    ),
                    if (logo != null) pw.Image(logo, width: 50),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(thickness: 2, color: PdfColors.blue900),
                pw.SizedBox(height: 20),

                // Seccion de Datos en Tabla
                pw.Text('INFORMACIÓN PERSONAL', 
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 10),
                
                pw.TableHelper.fromTextArray(
                  context: context,
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
                  cellStyle: const pw.TextStyle(fontSize: 10),
                  data: <List<String>>[
                    <String>['Campo', 'Detalle'],
                    <String>['Nombre Completo', data['nombre'] ?? 'N/A'],
                    <String>['DNI / ID', data['dni']?.toString() ?? 'N/A'],
                    <String>['Legajo / Matrícula', data['expediente'] ?? 'PENDIENTE'],
                    <String>['Email', data['email'] ?? 'N/A'],
                    <String>['Teléfono', data['telefono'] ?? 'N/A'],
                    <String>['Ubicación', '${data['localidad'] ?? 'N/A'}, ${data['provincia'] ?? 'N/A'}'],
                    <String>['Dirección', '${data['direccion_calle'] ?? data['calle'] ?? ''} ${data['direccion_numero'] ?? data['altura'] ?? 'S/N'} (CP: ${data['cp'] ?? 'N/A'})'],
                  ],
                ),

                pw.SizedBox(height: 30),
                
                // SECCIÓN DE DOCUMENTACIÓN VISUAL
                pw.Text('DOCUMENTACIÓN VISUAL', 
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.SizedBox(height: 15),
                
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    // Columna DNI
                    pw.Column(
                      children: [
                        pw.Text('DNI (Identidad)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          width: 180,
                          height: 110,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(5),
                          ),
                          child: dniImg != null 
                              ? pw.Image(dniImg, fit: pw.BoxFit.cover)
                              : pw.Center(child: pw.Text('No disponible', style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                        ),
                      ],
                    ),
                    // Columna Carnet
                    pw.Column(
                      children: [
                        pw.Text('CARNET / LICENCIA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 5),
                        pw.Container(
                          width: 180,
                          height: 110,
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400),
                            borderRadius: pw.BorderRadius.circular(5),
                          ),
                          child: carnetImg != null 
                              ? pw.Image(carnetImg, fit: pw.BoxFit.cover)
                              : pw.Center(child: pw.Text('No disponible', style: const pw.TextStyle(color: PdfColors.grey400, fontSize: 8))),
                        ),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),

                // Pie de Pagina
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 10),
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.grey400))),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('Documento generado digitalmente por EL GUIA YA', 
                            style: pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
                          pw.Text('Sistema de Gestión de Flota - v1.0', 
                            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey400)),
                        ],
                      ),
                      pw.Text('Fecha: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}', 
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Legajo_Socio_${data['nombre']}.pdf',
    );
  }
}
