

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/pedido.dart';
import '../models/pedido_item.dart';
import '../models/usuario_comprador.dart';

class TicketPrinter {
  static String generarTicketTexto({
    required Pedido pedido,
    required UsuarioComprador usuario,
    required List<PedidoItem> items,
  }) {
    final buffer = StringBuffer();
    
    // Header del ticket
    buffer.writeln('================================');
    buffer.writeln('      EL GUIA YA - TICKET      ');
    buffer.writeln('================================');
    buffer.writeln('');
    
    // Informacion del pedido
    buffer.writeln('PEDIDO: #${pedido.id.substring(0, 8).toUpperCase()}');
    buffer.writeln('FECHA: ${_formatDateTime(pedido.createdAt)}');
    buffer.writeln('ESTADO: ${pedido.estadoNombre.toUpperCase()}');
    buffer.writeln('');
    
    // Informacion del cliente
    buffer.writeln('DATOS DEL CLIENTE:');
    buffer.writeln('Nombre: ${usuario.nombreMostrar}');
    buffer.writeln('Email: ${usuario.email}');
    if (usuario.telefono != null && usuario.telefono!.isNotEmpty) {
      buffer.writeln('Telefono: ${usuario.telefono}');
    }
    buffer.writeln('');
    
    // Direccion de envio
    buffer.writeln('DIRECCION DE ENVIO:');
    buffer.writeln(pedido.direccionEnvio);
    buffer.writeln('');
    
    // Productos
    buffer.writeln('PRODUCTOS:');
    buffer.writeln('--------------------------------');
    
    for (final item in items) {
      final producto = item.producto;
      if (producto != null) {
        buffer.writeln('${item.cantidad}x ${producto.nombre}');
        buffer.writeln('   ${item.precioUnitarioFormateado} c/u = ${item.subtotalFormateado}');
        buffer.writeln('');
      }
    }
    
    buffer.writeln('--------------------------------');
    
    // Totales
    buffer.writeln('SUBTOTAL: ${pedido.totalFormateado}');
    buffer.writeln('IVA (21%): \$${(pedido.total * 0.21).toStringAsFixed(2)}');
    buffer.writeln('TOTAL: \$${(pedido.total * 1.21).toStringAsFixed(2)}');
    buffer.writeln('');
    
    // Pie del ticket
    buffer.writeln('================================');
    buffer.writeln('     ¡GRACIAS POR SU COMPRA!     ');
    buffer.writeln('================================');
    buffer.writeln('');
    buffer.writeln('Para consultas sobre su pedido:');
    buffer.writeln('Email: soporte@elguiaya.com');
    buffer.writeln('Telefono: +54 11 1234-5678');
    buffer.writeln('');
    buffer.writeln('Estado actual: ${pedido.estadoEnvioNombre}');
    buffer.writeln('Actualizado: ${_formatDateTime(DateTime.now())}');
    buffer.writeln('');
    buffer.writeln('================================');
    buffer.writeln('           FIN DEL TICKET           ');
    buffer.writeln('================================');
    
    return buffer.toString();
  }

  static String generarTicketHTML({
    required Pedido pedido,
    required UsuarioComprador usuario,
    required List<PedidoItem> items,
  }) {
    final buffer = StringBuffer();
    
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html>');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln('<title>Ticket EL GUIA YA</title>');
    buffer.writeln('<style>');
    buffer.writeln('body { font-family: "Courier New", monospace; margin: 20px; }');
    buffer.writeln('.header { text-align: center; font-weight: bold; margin-bottom: 20px; }');
    buffer.writeln('.section { margin-bottom: 15px; }');
    buffer.writeln('.product { margin-bottom: 8px; }');
    buffer.writeln('.total { font-weight: bold; border-top: 1px solid #000; padding-top: 10px; margin-top: 10px; }');
    buffer.writeln('.footer { text-align: center; margin-top: 20px; font-size: 12px; }');
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    
    // Header
    buffer.writeln('<div class="header">');
    buffer.writeln('<h1>EL GUIA YA - TICKET</h1>');
    buffer.writeln('</div>');
    
    // Informacion del pedido
    buffer.writeln('<div class="section">');
    buffer.writeln('<strong>PEDIDO:</strong> #${pedido.id.substring(0, 8).toUpperCase()}<br>');
    buffer.writeln('<strong>FECHA:</strong> ${_formatDateTime(pedido.createdAt)}<br>');
    buffer.writeln('<strong>ESTADO:</strong> ${pedido.estadoNombre.toUpperCase()}');
    buffer.writeln('</div>');
    
    // Informacion del cliente
    buffer.writeln('<div class="section">');
    buffer.writeln('<strong>DATOS DEL CLIENTE:</strong><br>');
    buffer.writeln('Nombre: ${usuario.nombreMostrar}<br>');
    buffer.writeln('Email: ${usuario.email}<br>');
    if (usuario.telefono != null && usuario.telefono!.isNotEmpty) {
      buffer.writeln('Telefono: ${usuario.telefono}<br>');
    }
    buffer.writeln('</div>');
    
    // Direccion de envio
    buffer.writeln('<div class="section">');
    buffer.writeln('<strong>DIRECCION DE ENVIO:</strong><br>');
    buffer.writeln(pedido.direccionEnvio);
    buffer.writeln('</div>');
    
    // Productos
    buffer.writeln('<div class="section">');
    buffer.writeln('<strong>PRODUCTOS:</strong><br>');
    buffer.writeln('<hr>');
    
    for (final item in items) {
      final producto = item.producto;
      if (producto != null) {
        buffer.writeln('<div class="product">');
        buffer.writeln('${item.cantidad}x ${producto.nombre}<br>');
        buffer.writeln('   ${item.precioUnitarioFormateado} c/u = ${item.subtotalFormateado}');
        buffer.writeln('</div>');
      }
    }
    
    buffer.writeln('<hr>');
    buffer.writeln('</div>');
    
    // Totales
    buffer.writeln('<div class="section total">');
    buffer.writeln('SUBTOTAL: ${pedido.totalFormateado}<br>');
    buffer.writeln('IVA (21%): \$${(pedido.total * 0.21).toStringAsFixed(2)}<br>');
    buffer.writeln('<strong>TOTAL: \$${(pedido.total * 1.21).toStringAsFixed(2)}</strong>');
    buffer.writeln('</div>');
    
    // Pie del ticket
    buffer.writeln('<div class="footer">');
    buffer.writeln('<strong>¡GRACIAS POR SU COMPRA!</strong><br><br>');
    buffer.writeln('Para consultas sobre su pedido:<br>');
    buffer.writeln('Email: soporte@elguiaya.com<br>');
    buffer.writeln('Telefono: +54 11 1234-5678<br><br>');
    buffer.writeln('Estado actual: ${pedido.estadoEnvioNombre}<br>');
    buffer.writeln('Actualizado: ${_formatDateTime(DateTime.now())}');
    buffer.writeln('</div>');
    
    buffer.writeln('</body>');
    buffer.writeln('</html>');
    
    return buffer.toString();
  }

  static void imprimirTicket({
    required BuildContext context,
    required Pedido pedido,
    required UsuarioComprador usuario,
    required List<PedidoItem> items,
  }) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Imprimir Ticket'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Seleccione el formato de impresion:'),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _mostrarTicketTexto(context, pedido, usuario, items);
                },
                icon: const Icon(Icons.print),
                label: const Text('Impresora Termica'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _mostrarTicketHTML(context, pedido, usuario, items);
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  static void _mostrarTicketTexto(
    BuildContext context,
    Pedido pedido,
    UsuarioComprador usuario,
    List<PedidoItem> items,
  ) {
    final ticketTexto = generarTicketTexto(
      pedido: pedido,
      usuario: usuario,
      items: items,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ticket - Vista Previa'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              ticketTexto,
              style: const TextStyle(
                fontFamily: 'Courier New',
                fontSize: 12,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Aqui iria la logica de impresion real
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Center(child: Text('Enviando a impresora termica...')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Imprimir'),
          ),
        ],
      ),
    );
  }

  static void _mostrarTicketHTML(
    BuildContext context,
    Pedido pedido,
    UsuarioComprador usuario,
    List<PedidoItem> items,
  ) {
    final ticketHTML = generarTicketHTML(
      pedido: pedido,
      usuario: usuario,
      items: items,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ticket PDF - Vista Previa'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: SingleChildScrollView(
            child: Text(
              ticketHTML,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              // Aqui iria la logica de generacion de PDF
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Center(child: Text('Generando PDF...')),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Generar PDF'),
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
  }
}
