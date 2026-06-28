import 'package:flutter/material.dart';

import '../services/despacho_pna_service.dart';
import '../services/pdf_service.dart';
import '../widgets/safe_button.dart';

/// Botón para generar/imprimir/compartir el despacho PNA pre-rellenado.
class DescargarDespachoPnaButton extends StatefulWidget {
  final String pedidoId;
  final bool compact;

  const DescargarDespachoPnaButton({
    super.key,
    required this.pedidoId,
    this.compact = false,
  });

  @override
  State<DescargarDespachoPnaButton> createState() =>
      _DescargarDespachoPnaButtonState();
}

class _DescargarDespachoPnaButtonState extends State<DescargarDespachoPnaButton> {
  bool _generando = false;

  Future<void> _onPressed() async {
    if (_generando) return;
    setState(() => _generando = true);

    try {
      final resultado = await DespachoPnaService.cargarParaPedido(widget.pedidoId);
      if (!mounted) return;

      if (!resultado.puedeGenerar || resultado.data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(resultado.mensaje),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final data = resultado.data!;
      final accion = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF001F3F),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Despacho PNA',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Documento pre-completado con los datos del viaje. '
                  'Revisá, firmá y presentá si corresponde antes de zarpar.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),
                SafeElevatedIconButton(
                  onPressed: () => Navigator.pop(context, 'imprimir'),
                  icon: Icons.print_rounded,
                  label: 'Imprimir',
                ),
                const SizedBox(height: 10),
                SafeOutlinedIconButton(
                  onPressed: () => Navigator.pop(context, 'compartir'),
                  icon: Icons.share_rounded,
                  label: 'Compartir / Guardar PDF',
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00E676),
                    side: const BorderSide(color: Color(0xFF00E676)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      if (!mounted || accion == null) return;

      if (accion == 'imprimir') {
        await PdfService.generarDespachoPna(data);
      } else if (accion == 'compartir') {
        await PdfService.compartirDespachoPna(data);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo generar el despacho: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return SafeOutlinedIconButton(
        onPressed: _generando ? null : _onPressed,
        icon: Icons.description_outlined,
        label: _generando ? 'Generando...' : 'Despacho PNA',
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF1565C0),
          side: const BorderSide(color: Color(0xFF1565C0)),
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1565C0).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sailing_rounded, color: Color(0xFF1565C0), size: 20),
              SizedBox(width: 8),
              Text(
                'Servicio extra: Despacho PNA',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Descargá o imprimí el formulario de Prefectura pre-completado con los datos de tu viaje.',
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SafeElevatedIconButton(
            onPressed: _generando ? null : _onPressed,
            icon: Icons.picture_as_pdf_rounded,
            label: _generando ? 'Generando PDF...' : 'Generar Despacho PNA',
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
